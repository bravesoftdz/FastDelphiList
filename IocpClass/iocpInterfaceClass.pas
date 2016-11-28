unit iocpInterfaceClass;

//iocp 的单独放在这里.
//封装成 delphi 类的,因为添加了 delphi 一些特有的东西,有可能性能下降一些.
//注意:原始的 iocp 在 socket 关闭后仍然会发生 "数据发送完成" 这样的事件,这样就难于决定什么时候释放资源
//为方便起见调用者应当在连接事件中分配资源,在关闭事件中释放资源,在这之外发生的事件由 iocp 实现类过滤掉
//但实现类要保证连接和关闭事件必须成对出现,并且只产生一次.

//内部资源分配/释放原则:
//"单句柄数据结构"与接收的"单IO数据结构"都对一个连接只产生一次,并且同时产生同时释放
//发送用的"单IO数据结构"自己释放,并且在事件中不要使用 "单句柄数据结构" 中的内容,需要用到的 socket 句柄
//直接在生成时附带.这样就可以避免资源释放的混乱.

// 2015/4/3 15:52:10 外部调用问题比较多,先弄一个统一加锁的版本让其形成类似于 indy 的单线程情况,以后有要求再做性能切换

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  //winsock2,
  Winsock2_v2,
  //IdWinSock2,
  //WinSock,

  ComCtrls,Contnrs, iocpInterface, iocpRecvHelper, iocpSendHelper, uIocpTimerThread, 
  uThreadLock,
  //Contnrs,//TQueue 性能不行
  uFastQueue, fsHashMap,
  //uFastHashSocketQueue_v2,
  uFastHashSocketQueue_v3, // 2015/4/27 14:20:49 换用可遍历的实现
  Dialogs;

type
  TSocket = Cardinal;//u_int;//clq //c 语言原型里的确是无符号的//TSocket 兼容性修正//IdWinSock2 中有误

type
  //连接到达
  TOnSocketConnectProc = procedure (Socket: TSocket; var OuterFlag:Integer{供外部设置连接标志}) of object;
  //接收一块完成
  TOnRecvProc = procedure (Socket: TSocket; buf:PChar; bufLen:Integer; OuterFlag:Integer) of object;

  //与 TOnRecvProc 相同,但可以得到整个通信过程中的完整数据,TOnRecvProc 中只是当前收到的块
  //必须返回 useDataLen(在此事件处理/使用了多个字节的数据,iocp 框架类会清除这部分,否则 iocp 框架类会保留太多的接收数据)
  TOnRecvDataProc = procedure (Socket: TSocket; buf:PChar; bufLen:Integer; OuterFlag:Integer; var useDataLen:Integer) of object;
  //发送一块完成//与接收不同的是,这个是全部发送才产生一次事件
  TOnSendProc = procedure (Socket: TSocket; OuterFlag:Integer) of object;
  //发送一个上层应用包完成//与 TOnSendProc 不同的是,这个是一个上层应用包全部发送才产生一次事件
  //TOnSendOverProc = procedure (Socket: TSocket; OuterFlag:Integer) of object;
  //关闭客户端 socket 时
  TOnSocketCloseProc = procedure (Socket: TSocket; OuterFlag:Integer) of object;


type
  TAcceptThread = class;
  TServerWorkerThread = class;
  TAcceptFastThread = class;
  TConnectClass = class;
  //TIocpTimerThread = class;

  //封装 iocp 的类
  TIocpClass = class(TComponent)//(TObject)// 2015/4/14 9:03:17 为检测内存泄漏,用 TComponent 比较好
  private
    acceptThread:TAcceptThread;

    //workThread:TServerWorkerThread;
    //工作线程其实有多个
    workThread:array of TServerWorkerThread;

    acceptFastThread:TAcceptFastThread;

    //模拟定时器线程
    timerThread:TIocpTimerThread;
    //上次检查的时间
    lastCheckDoClose:Integer;



    function GetConnect(Socket: TSocket; var connect:TConnectClass):Boolean;
    function SetConnect(Socket: TSocket; connect:TConnectClass):Boolean;
    function DeleteConnect(Socket: TSocket): Boolean;
    procedure SendDataSafe_NoLock(Socket: TSocket; buf: PChar; bufLen: Integer);
    procedure ClearIoData(PerIoData: LPPER_IO_OPERATION_DATA);

  public
    ListenPort:Integer;
    threadLock:TThreadLock;
    acceptLock:TThreadLock;
    acceptList:TFastQueue;//接收的 socket 列表

    socketList:TFastHashSocketQueue;//连接的 socket 管理列表,原来只用于判断某个 socket 是否已经释放
    //perIoDataList:THashMap;//因为接收与发送的 perIoData 不可能同时释放,所以还要单独记录它们以便独立释放
    // 2015/6/30 9:12:03 而 FPerIoData 的过程没有必要保留,因为现在每个连接是固定两个 iodata 完全是可控的.

    //--------------------------------------------------
    //合并到 socketList//sendSocketList:TFastHashSocketQueue;//正在发送的 socket 管理列表,目前只能于判断某个 socket 是否处于发送状态,如果是则要等待后再发送
    sendLock:TThreadLock;// 2015/4/14 11:45:49 这个是主线程同步版本,暂时不用加锁定了

    //--------------------------------------------------

    OnRecv:TOnRecvProc;
    OnClose:TOnSocketCloseProc;
    OnSend:TOnSendProc;
    OnConnect:TOnSocketConnectProc;
    OnRecvData:TOnRecvDataProc;//特殊事件

    //增加一个定时器处理事件
    procedure AddOnTimerEvent(EventName:string; OnTimer:TOnIocpTimerProc; Interval:Cardinal);
    //CoInitialize, CoUninitialize 这样的函数必须在线程起始,终止时唯一调用,所以要在这两个地方可以执行代码
    procedure SetOnTimerEvent_ThreadFun(OnThreadBegin:TOnIocpTimerProc; OnThreadEnd:TOnIocpTimerProc);


    // 2015/5/7 11:03:26 简化内存管理,外部标志不写入内存块,直接与 socket 关联好了//现在连这个都不用了
    //function GetOuterFlag(Socket: TSocket):Integer;


    //触发事件的各函数
    procedure DoConnect(Socket: TSocket; var OuterFlag:Integer); //virtual;
    procedure DoRecv(Socket: TSocket; buf:PChar; bufLen:Integer); //virtual;
    procedure DoSend(Socket: TSocket); //virtual;
    procedure DoClose(Socket: TSocket); //virtual;

    //检查没有在 iocp 中报告的关闭事件//只能内部调用
    procedure CheckDoClose;

    procedure StartService();
    
    procedure StartOnTimerEvent();
    class procedure InitSock;

    //完成端口发送//兼容接口
    //procedure SendData(Socket: TSocket; buf: PChar; bufLen: Integer; OuterFlag: Integer);

    //线程安全的同步发送,调用者不需要考虑同步问题,简单地直接调用就行了//高性能模式下,在其他线程中调用需要自己加锁,在事件中调用不需要
    procedure SendDataSafe(Socket: TSocket; buf: PChar; bufLen: Integer; User_OuterFlag: Integer);

    //发送下一块,只能是内部调用//不用,集成在 IoDataGetNext 中了
    //procedure SendDataSafe_Next(Socket: TSocket; OuterFlag: Integer);

    //只能用于内部调用//取下一个要发送的数据要填充 io 结构//BytesTransferred 是当前发送成功的字节数,其实照目前的算法就是 DATA_BUFSIZE
    function IoDataGetNext(PerIoData : LPPER_IO_OPERATION_DATA; BytesTransferred:Integer):Boolean;

    //--------------------------------------------------
    //方便性的函数

    //用于在 OnRecvData 取 buf 为字符串,因为没有 #0 结尾直接将 buf 当做字符串是很危险的
    function GetBufString_OnRecvData(buf: PChar; bufLen: Integer):string;

    //与 TIdUDPServer.ThreadedEvent 相同,为 true 时事件在线程中触发,用于高性能要求环境,但要求用户自己做线程同步
    class procedure ThreadedEvent(EventInThread:Boolean);


    //--------------------------------------------------
    // 2015/4/14 9:02:12 为了检测内存泄漏还是加构造函数的好
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;


  end;


  //工作线程
  TServerWorkerThread = class(TThread)
  private
    procedure Run;
    procedure ClearSocket(PerIoData: LPPER_IO_OPERATION_DATA; so: TSocket; connect:TConnectClass);

  private
    //--------------------------------------------------
    //DoOne 中所用的同步变量
    BytesTransferred: DWORD;
    PerIoData : LPPER_IO_OPERATION_DATA;//这里是自己用的临时变量
    bSleep:Boolean; // 2015/4/3 15:59:53 是否让循环等待一下
    bGet:BOOL; //GetQueuedCompletionStatus 的返回值
    lpCompletionKey: DWORD;
    connect:TConnectClass;

    procedure DoOne;
    //--------------------------------------------------
  protected
    procedure Execute; override;
  public
    iocpClass:TIocpClass;

    threadLock:TThreadLock;

    CompletionPort : THandle;

    //调用同步事件
  end;

  //创建及接收 socket 线程
  TAcceptThread = class(TThread)
  private
    procedure CreateServer;
    { Private declarations }
  protected
    procedure Execute; override;
  public
    iocpClass:TIocpClass;
    threadLock:TThreadLock;
    acceptLock:TThreadLock;
    acceptList:TFastQueue;//接收的 socket 列表

    //监听的 socket ,关闭程序时要 closesocket
    Listensc :Integer;
    //完成端口的句柄似乎也要关闭
    CompletionPort : THandle;

//    OnConnect_thread:TOnSocketConnectProc;

    //CompletionPort : THandle;
  end;

  //为加快 accept 的过程,从 TAcceptThread 分离出来
  TAcceptFastThread = class(TThread)
  private
    function NewConnect(Socket: TSocket; var connect:TConnectClass; var oldConnect:TConnectClass):Boolean;
    procedure Run;

  private
    //--------------------------------------------------
    //DoOne 中所用的同步变量

    Acceptsc:Integer;
    PerIoData : LPPER_IO_OPERATION_DATA;//这里是自己用的临时变量

    //OuterFlag:Integer;
    haveSocket:Boolean;
    re:Boolean;
    bindErr:Boolean;
    newcon:TConnectClass;

    bSleep:Boolean; // 2015/4/3 15:59:53 是否让循环等待一下

    CompletionKey: DWORD;

    procedure DoOne;

    //--------------------------------------------------

  protected
    procedure Execute; override;
  public
    CompletionPort : THandle;
    iocpClass:TIocpClass;
    threadLock:TThreadLock;
    acceptLock:TThreadLock;
    acceptList:TFastQueue;//接收的 socket 列表
    //Listensc : THandle;//test

//    OnConnect_thread:TOnSocketConnectProc;

  end;


  //连接管理类,因为之前把接收助手和发送助手分开虽然性能很强,但太不容易管理了,现在要求稳定性// 2015/4/14 11:26:29
  TConnectClass = class(TObject)
  private

  public
    User_OuterFlag: Integer; //用户事件里的标志
    //Iocp_OuterFlag: Integer; //iocp 类内部使用的标志,过去为 TRecvHelp 现在就是 TConnectClass 自身//现在不用了,直接与 socket 关联
    recvHelper:TRecvHelper;
    sendHelper:TSendHelper;

    iocpClass:TIocpClass;

    //debugTag:Integer; //调试标志

    //constructor Create; //override;
    constructor Create(iocp:TIocpClass); //override;
    destructor Destroy; override;

  end;


var
  g_IOCP_Synchronize_Event:Boolean = True; // 2015/4/3 8:46:06 是否使用 Synchronize 的方式调用事件函数//对于界面操作比较多的时使用;对发生要求非常高的地方禁用

  g_IOCP_SendSize_test:Int64 = 0;// 2015/4/13 17:20:29 看看发送内存占用多少
  g_IOCP_MemSize_test:Int64 = 0;// 2015/4/13 17:20:29 看看全部分配的内存占用多少


//--------------------------------------------------
//方便性的函数

//用于在 OnRecvData 取 buf 为字符串,因为没有 #0 结尾直接将 buf 当做字符串是很危险的
function GetBufString(buf: PChar; bufLen: Integer):string;

//--------------------------------------------------
//只是为了调试在哪关闭的
function closesocket(const s: TSocket): Integer; //stdcall;

implementation

uses
  uLogMemSta,
  uLogFile;


//只是为了调试在哪关闭的
function closesocket(const s: TSocket): Integer; //stdcall;
begin
  //Result := Winsock2_v2.closesocket(s);
  Result := iocpInterface.closesocket(s);
end;


//uses uThreadLock;

//用于在 OnRecvData 取 buf 为字符串,因为没有 #0 结尾直接将 buf 当做字符串是很危险的
function GetBufString(buf: PChar; bufLen: Integer):string;
begin
  SetLength(Result, 0);//这样安全点
  SetLength(Result, bufLen);
  CopyMemory(@Result[1], buf, bufLen);
end;



//创建服务
procedure TAcceptThread.CreateServer;
var
  i:Integer;
  Acceptsc:Integer;
  //PerHandleData : LPPER_HANDLE_DATA;//这个应该是可更改的
  sto:sockaddr_in;
  //Listensc :Integer;
  LocalSI:TSystemInfo;
  //CompletionPort : THandle;

  //thread:TServerWorkerThread;
  //OuterFlag:Integer;
  //threadFast:TAcceptFastThread;
  err:Integer;

begin

  TIocpClass.InitSock(); // 2015/5/7 9:24:07 改类函数好了

  //创建一个完成端口。
  CompletionPort := CreateIOCompletionPort(INVALID_HANDLE_VALUE,0,0,0);

  //根据CPU的数量创建CPU*2数量的工作者线程。
  GetSystemInfo(LocalSI);

  SetLength(iocpClass.workThread, LocalSI.dwNumberOfProcessors * 2);

  //for i:=0 to LocalSI.dwNumberOfProcessors * 2 -1 do
  for i:=0 to Length(iocpClass.workThread) -1 do
  begin
      {
      //delphi 要用 BeginThread 代替 CreateThread
      //hThread := CreateThread(nil, 0, @ServerWorkerThread, Pointer(CompletionPort),0, ThreadID);
      //奇怪,这里不能用 BeginThread,否则 cpu 会非常高(调用等细节不同,算了,用 CreateThread 好了)
      IsMultiThread := TRUE;//用这个后也可以用 CreateThread
      hThread := CreateThread(nil, 0, @ServerWorkerThread, Pointer(CompletionPort),0, ThreadID);
      if (hThread = 0) then
      begin
          Exit;
      end;
      CloseHandle(hThread);
      }
      iocpClass.workThread[i] := TServerWorkerThread.Create(True);
      iocpClass.workThread[i].CompletionPort := CompletionPort;

      iocpClass.workThread[i].iocpClass := Self.iocpClass;

      //这些变量最好是直接赋值不要经过 iocpClass,这样更安全
      iocpClass.workThread[i].threadLock := iocpClass.threadLock;
      //iocpClass.workThread[i].OnRecv_thread     := iocpClass.DoRecv;//OnRecv;
      //iocpClass.workThread[i].OnClose_thread    := iocpClass.DoClose;//OnClose;
      //iocpClass.workThread[i].OnSend_thread     := iocpClass.DoSend;//OnSend;

      iocpClass.workThread[i].Resume;

  end;

  //--------------------------------------------------
  //创建 accept 处理线程
  iocpClass.acceptFastThread := TAcceptFastThread.Create(True);
  iocpClass.acceptFastThread.CompletionPort := CompletionPort;
  iocpClass.acceptFastThread.iocpClass := Self.iocpClass;
  //iocpClass.acceptFastThread.Listensc := Listensc;//test,可以在另一个线程中使用吗

  //这些变量最好是直接赋值不要经过 iocpClass,这样更安全
  iocpClass.acceptFastThread.threadLock := iocpClass.threadLock;
  iocpClass.acceptFastThread.acceptLock := iocpClass.acceptLock;
  iocpClass.acceptFastThread.acceptList := iocpClass.acceptList;
//  iocpClass.acceptFastThread.OnConnect_thread := iocpClass.DoConnect;//OnConnect;
  iocpClass.acceptFastThread.Resume;

  //--------------------------------------------------


  //创建一个套接字，将此套接字和一个端口绑定并监听此端口。
  Listensc:=WSASocket(AF_INET,SOCK_STREAM,0,Nil,0,WSA_FLAG_OVERLAPPED);
  if Listensc=SOCKET_ERROR then
  begin
    MessageBox(0, PChar('端口 ' + inttostr(iocpClass.ListenPort) + ' 监听失败[socket未建立]'), '错误', 0);
    closesocket(Listensc);
    WSACleanup();
  end;
  sto.sin_family:=AF_INET;
  sto.sin_port := htons(iocpClass.ListenPort);//htons(5500);
  sto.sin_addr.s_addr:=htonl(INADDR_ANY);
  if bind(Listensc,@sto,sizeof(sto))=SOCKET_ERROR then
  begin
    MessageBox(0, PChar('端口 ' + inttostr(iocpClass.ListenPort) + ' 监听失败'), '错误', 0);
    closesocket(Listensc);
  end;
  //listen(Listensc,20);         SOMAXCONN
  //listen(Listensc, SOMAXCONN);
  //listen(Listensc, $7fffffff);//WinSock2.SOMAXCONN);

  if g_IOCP_Synchronize_Event = False then //高性能状态
  listen(Listensc, WinSock2_v2.SOMAXCONN)
  else

  listen(Listensc, 1);//WinSock2.SOMAXCONN);// 2015/4/3 15:03:26 太大的话其实也是有问题的,会导致程序停止响应时客户端仍然可以连接上,并且大量的占用

  //--------------------------------------------------
  //while (TRUE) do
  while (not Self.Terminated) do
  begin
    LogFileMem('1');

    //当客户端有连接请求的时候，WSAAccept函数会新创建一个套接字Acceptsc。这个套接字就是和客户端通信的时候使用的套接字。
    Acceptsc := WSAAccept(Listensc, nil, nil, nil, 0);

    SetNonBlock(Acceptsc);//设置一下非阻塞比较好


    LogFileMem('2');


    //判断Acceptsc套接字创建是否成功，如果不成功则退出。
    if (Acceptsc = SOCKET_ERROR) then
    begin
      err := WSAGetLastError();  //WSAENOTSOCK =10038 WSAEMFILE     ERROR_IO_PENDING
      LogFileMem('WSAGetLastError: ' + IntToStr(err)); //目前在 xp 上的测试基本上是 10038
      //if (WSAGetLastError() <> ERROR_IO_PENDING) then

      //--------------------------------------------------
      // 2015/4/21 8:39:20 这时候 Listensc 可能被误关闭了,要重建//不重建的话在极端情况下某些 xp 系统 WSAAccept 会一直死锁
      closesocket(Listensc);
      Listensc:=WSASocket(AF_INET,SOCK_STREAM,0,Nil,0,WSA_FLAG_OVERLAPPED);
      if Listensc=SOCKET_ERROR then
      begin
        //closesocket(Listensc);
        LogFileMem('2 重建 socket 失败');
      end;

      if bind(Listensc,@sto,sizeof(sto))=SOCKET_ERROR then
      begin
        LogFileMem('2 重建 bind 失败');
        closesocket(Listensc);
      end;
      listen(Listensc, 1);

      //--------------------------------------------------

      Sleep(1);
      Continue;

      // 2015/4/7 14:03:50 不一定要退出,有可能是内存暂时性不足
      //closesocket(Listensc);
      //exit;
    end;

    //--------------------------------------------------
    //用另外的线程处理 onconnect 事件的话有一个问题,就是 onconnect 事件有可能会在 onrecv 事件后发生//应该也不会,因为 CreateIoCompletionPort 还没调用

    LogFileMem('3');

    try
      acceptLock.Lock('acceptLock.Lock');//很简单,不用 try 了// 2015/4/3 13:48:29  还是要的,因为 lock 本身分异常
      //acceptList.Write(Acceptsc);
      if acceptList.Write(Acceptsc) = False
      then closesocket(Acceptsc); // 2015/4/22 15:52:11 满队列关闭,应该非常少见
    finally
      acceptLock.UnLock;
    end;
    //acceptList.Read(Acceptsc);


    Continue;

  end;

end;



constructor TIocpClass.Create(AOwner: TComponent);
begin
  //inherited;
  inherited Create(AOwner);

  //模拟定时器线程在创建时即生成,因为还要加事件
  timerThread := TIocpTimerThread.Create(True);
  timerThread.iocpClass := Self;

  //perIoDataList := THashMap.Create();


  //在测试时发现,这一步并不可靠,如果关闭正常可不需要这一检测(在 7.3 的登录服务器中检测的话反而会引起异常,估计是与 iocp 自身的内存释放冲突了)
  Self.AddOnTimerEvent('CheckDoClose', Self.CheckDoClose, 1*1000);//定时检查一下未在 iocp 中通知的关闭事件

end;

destructor TIocpClass.Destroy;
var
  i:Integer;
begin
  //各个线程应当不用释放//似乎还是手动释放的好

  //--------------------------------------------------

  //接收线程还是要手工关闭
//  acceptThread := TAcceptThread.Create(True);
  acceptThread.Terminate;
  closesocket(acceptThread.Listensc);//不关闭,WSAAccept 会一直阻塞
  //CloseHandle(acceptThread.CompletionPort);//完成端口不能这样关闭,要调用 PostQueuedCompletionStatus(m_hCompletionPort, 0, 0, NULL); 多次(与发起线程数一致)

  LogFile('acceptThread.WaitFor');
  acceptThread.WaitFor;
  acceptThread.Free;

  //工作线程有多个
  for i:=0 to Length(self.workThread) -1 do
  begin
    workThread[i].Terminate;//PostQueuedCompletionStatus 的结果不一定作用在本线程上,所以应当另外有一个循环全部关闭线程标志先

    //PostQueuedCompletionStatus(m_hCompletionPort, 0, 0, NULL); 多次(与发起线程数一致)
    //PostQueuedCompletionStatus(acceptThread.CompletionPort, 0, 0, 0);
    PostQueuedCompletionStatus(self.workThread[i].CompletionPort, 0, 0, 0);
  end;

  for i:=0 to Length(self.workThread) -1 do
  begin
    //workThread[i].Terminate;//PostQueuedCompletionStatus 的结果不一定作用在本线程上,所以应当另外有一个循环全部关闭线程标志先

    //PostQueuedCompletionStatus(m_hCompletionPort, 0, 0, NULL); 多次(与发起线程数一致)
    //PostQueuedCompletionStatus(acceptThread.CompletionPort, 0, 0, 0);
    //PostQueuedCompletionStatus(self.workThread[i].CompletionPort, 0, 0, 0);

    //closesocket(acceptThread.Listensc);//不关闭,WSAAccept 会一直阻塞
    LogFile('workThread[i].WaitFor');
    workThread[i].WaitFor;
    workThread[i].Free;

  end;

  //模拟定时器线程在创建时即生成,因为还要加事件
  timerThread.Terminate;
  LogFile('timerThread.WaitFor');
  timerThread.WaitFor;
  timerThread.Free;


  //--------------------------------------------------
  //最好先关闭接收线程再关闭这个
  acceptFastThread.Terminate;
  Self.acceptLock.TerminateInThread;//需要先退出线程锁
  Self.threadLock.TerminateInThread;
  LogFile('acceptFastThread.WaitFor');
  acceptFastThread.WaitFor;
  acceptFastThread.Free;


  acceptLock.Free;//现在需要自己释放
  threadLock.Free;

  //--------------------------------------------------
  //数据结构应当放在最后释放
  //Self.threadLock := TThreadLock.Create(Application);
  //acceptLock := TThreadLock.Create(Application);
//  acceptList := TFastQueue.Create(20000);//20000//其实 2000 就足够了
  acceptList.Free;
//  socketList := TFastHashSocketQueue.Create();
  socketList.Free;
  //perIoDataList.Free;

//  sendDataList := TList.Create;
  //sendDataList.Free;
  //sendSocketList := TFastHashSocketQueue.Create();
  //sendSocketList.Free;
  sendLock.Free;


  LogFile('TIocpClass.Destroy');

  inherited;
end;


//特殊情况下对没有响应 iocp 事件的已断开连接进行补刀
procedure TIocpClass.CheckDoClose;
var
  tmpcon:TConnectClass;
  tmp:Pointer;
  i:Integer;

  FPerIoData : LPPER_IO_OPERATION_DATA;
  TickCount:DWORD;
begin   //  Exit;//奇怪,即使后面的程序等待多时仍然有可能引发异常//可能应该改为确认 socket 不存在后 1 分钟后强制关闭
  TickCount := GetTickCount();

  if Abs(TickCount - lastCheckDoClose) < 10*1000 then Exit;

  lastCheckDoClose := TickCount;//GetTickCount();

  {$ifndef EXCEPT_DEBUG}//调试异常的情况下屏蔽
  try
  {$endif}

      {
      //--------------------------------------------------
      //取他们的 iocp data 看看是为什么iocp没报告关闭事件//不知为何始终是有,有可能是内存异常引起的?
      for i := 0 to (perIoDataList.Count)-1 do  //如果只是检测内存泄漏的话,每次处理几个就行了,全部处理的话 cpu 压力太大//从实际测试来看 10000 连接以内还是不要紧的
      begin

        //因为有删除动作,所以还要再判断一次//索引超过了要重置
        if i > perIoDataList.Count-1 then Exit;


        //FPerIoData := LPPER_IO_OPERATION_DATA(perIoDataList.Items[i]);
        FPerIoData := LPPER_IO_OPERATION_DATA(perIoDataList.Keys[i]);

        if Abs(TickCount - FPerIoData.TickCount)<60*1000 then Continue; //如果最后操作时间不到1分钟,不处理


        if CheckPerIoDataComplete(FPerIoData) = True then
        begin
          FPerIoData.atWork := 888 //让它能被销毁

          self.DoClose(FPerIoData.Socket);
          if tmpcon = nil then Self.ClearIoData(FPerIoData); //没有连接的要自己删除


          closesocket(FPerIoData.Socket);

        end;



      end;
      }

  {$ifndef EXCEPT_DEBUG}//调试异常的情况下屏蔽
  except//必须用 except 去掉异常,否则后面的数据接收不响应
  end;
  {$endif}


end;


procedure TIocpClass.DoClose(Socket: TSocket);
var
  //helper:TRecvHelper;
  connect,tmpcon:TConnectClass;
  tmp:Pointer;
  i:Integer;
begin

  {$ifndef EXCEPT_DEBUG}//调试异常的情况下屏蔽
  try
  {$endif}
    //close 事件比较特殊,已经加锁了//threadLock.Lock;//线程引发的,必须锁定

    try
      //if socketList.GetItem(Socket, tmp) = False then
      if GetConnect(Socket, connect) = False then //没有这个连接
      begin
        //if DebugHook<>0 then MessageBox(0, '连接已释放!', '内部服务器错误', 0);//这种情况下未连接就关闭时很多
        Exit;
      end;

      //--------------------------------------------------
      if Assigned(OnClose) then OnClose(Socket, connect.User_OuterFlag);//必须在 free 前调用
      //--------------------------------------------------


      //socketList.DeleteItem(Socket);//记录
      DeleteConnect(Socket);

      LogFileMem('当前连接数:' + IntToStr(self.socketList.Count) + ' '
        + '当前连接数 debug_count:' + IntToStr(self.socketList.debug_count)
        );

      //--------------------------------------------------

    finally
    //close 事件比较特殊,已经加锁了//  threadLock.UnLock;
    end;

  {$ifndef EXCEPT_DEBUG}//调试异常的情况下屏蔽
  except//必须用 except 去掉异常,否则后面的数据接收不响应
  end;
  {$endif}


end;



//释放一个连接,与一个 socket 相关联,只在关闭事件中使用
function TIocpClass.DeleteConnect(Socket: TSocket):Boolean;
var
  tmp:Pointer;
  oldcon:TConnectClass;
begin
  Result := True;

  if socketList.GetItem(Socket, tmp) then
  begin
    //LogFile('上次的关闭还未完成. ' + IntToStr(Socket));

    oldcon := tmp;
    oldcon.Free;//必须删除旧连接,因为新连接已经创建了,不放入就会内存泄漏

    socketList.DeleteItem(Socket);

  end;


end;


//设置一个连接,与一个 socket 相关联,只在连接事件中使用
function TIocpClass.SetConnect(Socket: TSocket; connect:TConnectClass):Boolean;
var
  tmp:Pointer;
  oldcon:TConnectClass;
begin
  Result := True;

  if socketList.GetItem(Socket, tmp) then
  begin
    LogFile('上次的关闭还未完成. ' + IntToStr(Socket));

    oldcon := tmp;
    oldcon.Free;//必须删除旧连接,因为新连接已经创建了,不放入就会内存泄漏

    socketList.DeleteItem(Socket); //// 2015/4/23 17:16:47 delphi 的 hash 实现是允许重入的,所以在写入时一定要判断相同的 socket 是否有值了,否则取到的只是第一个值而已

  end;

  socketList.SetItem(Socket, connect);//记录,要判断一下原来的是否存在,否则就是重复设置 socket 了会报错的

end;

//安全的取得一个 socket ,并比较指针与列表中取得的结果是否一致
function TIocpClass.GetConnect(Socket: TSocket; var connect:TConnectClass):Boolean;
var
  tmp:Pointer;
begin
  Result := False;
  connect := nil;

  if socketList.GetItem(Socket, tmp) = True then
  begin
    connect := tmp;

    Result := True;

  end;

end;

procedure TIocpClass.DoConnect(Socket: TSocket; var OuterFlag: Integer);
var
  //helper:TRecvHelper;
  //sendHelper:TSendHelper;
  PerIoData : LPPER_IO_OPERATION_DATA;
  //tmp:Pointer;

begin
  //CheckDoClose();//test


  //事件中都加了这但加 except 后性能下降比较厉害

  //特别是在 accept 表现得特别明显,我的机器发送 1000 个连接原来是全部接收的现在只接收了 600 个,所以 onconnet 事件里不要用 except 异常,并且用户事件中也要快速通过.


  {$ifndef EXCEPT_DEBUG}//调试异常的情况下屏蔽
  try
  {$endif}

    try
      //threadLock.Lock('TIocpClass.DoConnect');//线程引发的,必须锁定


      //--------------------------------------------------

      //应当放到后面去,因为事件中也会用到连接,所以要在连接生成后触发事件//if Assigned(OnConnect) then OnConnect(Socket, OuterFlag);

      LogFile('debug 2: OnConnect(Socket, OuterFlag);');

      if Assigned(OnConnect) then OnConnect(Socket, OuterFlag);



    finally
      //threadLock.UnLock;
      //LogFile('debug 3: threadLock.UnLock;');
    end;
    LogFile('debug 4: end;');

  {$ifndef EXCEPT_DEBUG}//调试异常的情况下屏蔽
  except//必须用 except 去掉异常,否则后面的数据接收不响应
  end;
  {$endif}

end;

procedure TIocpClass.DoRecv(Socket: TSocket; buf: PChar; bufLen: Integer);
var
  //helper:TRecvHelper;
  connect:TConnectClass;
  useDataLen:Integer;

begin

  {$ifndef EXCEPT_DEBUG}//调试异常的情况下屏蔽
  try
  {$endif}

    try
      //threadLock.Lock('TIocpClass.DoRecv');//线程引发的,必须锁定

      //connect := connect(OuterFlag);
      if GetConnect(Socket, connect) = False then //没有这个连接
      begin
        //MessageBox(0, '连接已释放!', '内部服务器错误', 0);//这种情况下未连接就关闭时很多
        Exit;
      end;
      

      //OuterFlag := connect.User_OuterFlag;//恢复占用的外部标识

      //这里有问题,会导致后面的recv不产生 iocp 事件,看一下可能是有内存越界等
      if Assigned(OnRecv) then OnRecv(Socket, buf, bufLen, connect.User_OuterFlag);

      connect.recvHelper.OnRecv(Socket, buf, bufLen);

      useDataLen := 0;
      //注意这里传入全部数据
      if Assigned(OnRecvData)
      then OnRecvData(Socket, connect.recvHelper.FMemory.Memory, connect.recvHelper.FMemory.Size, connect.User_OuterFlag, useDataLen)
      else useDataLen := bufLen;//没有用户事件的话就全部清理掉好了

      //TRecvHelper.ClearData(helper, 2);//test
      //清除用户在事件中处理过了的数据
      TRecvHelper.ClearData(connect.recvHelper, useDataLen);



    finally
      //threadLock.UnLock;
    end;

  {$ifndef EXCEPT_DEBUG}//调试异常的情况下屏蔽
  except//必须用 except 去掉异常,否则后面的数据接收不响应
  end;
  {$endif}



end;

procedure TIocpClass.DoSend(Socket: TSocket);
var
  //helper:TRecvHelper;
  connect:TConnectClass;
  tmp:Pointer;
begin

  {$ifndef EXCEPT_DEBUG}//调试异常的情况下屏蔽
  try
  {$endif}

    try
      //threadLock.Lock('TIocpClass.DoSend');//线程引发的,必须锁定

      //句柄已经释放了就不要再触发事件给上层了
      if GetConnect(Socket, connect) = False then //没有这个连接
      begin
        //MessageBox(0, '连接已释放!', '内部服务器错误', 0);//这种情况下未连接就关闭时很多
        Exit;
      end;
      

      if Assigned(OnSend) then OnSend(Socket, connect.User_OuterFlag);

    finally
      //threadLock.UnLock;
    end;

  {$ifndef EXCEPT_DEBUG}//调试异常的情况下屏蔽
  except//必须用 except 去掉异常,否则后面的数据接收不响应
  end;
  {$endif}


end;

function TIocpClass.GetBufString_OnRecvData(buf: PChar;
  bufLen: Integer): string;
begin
  Result := GetBufString(buf, bufLen)
end;

class procedure TIocpClass.InitSock;
var
  wsData: TWSAData;
begin
  if WSAStartUp($202, wsData) <> 0 then
  begin
      WSACleanup();
  end;

end;


//procedure ClearSocket(PerIoData : LPPER_IO_OPERATION_DATA);
//procedure ClearSocket(PerIoData : LPPER_IO_OPERATION_DATA; PerHandleData : LPPER_HANDLE_DATA);
procedure TServerWorkerThread.ClearSocket(PerIoData : LPPER_IO_OPERATION_DATA; so:TSocket; connect:TConnectClass);
begin

  if (PerIoData <> nil) then
  begin
    if so <> PerIoData.Socket then MessageBox(0, ' socket 对应错误', '', 0); //有可能吗

    PerIoData.debugtag := 4;

    //发送的自删除标志
    if (PerIoData.OpCode = 1)and(connect <> nil) then connect.sendHelper.PerIoData_IsFree := True;
    //接收的自删除标志
    if (PerIoData.OpCode = 0)and(connect <> nil) then connect.recvHelper.PerIoData_IsFree := True;

    iocpClass.ClearIoData(PerIoData);//IocpFree(PerIoData, 200); // 2015/6/1 11:24:46 这个位置 iodata 是一定可以删除的,而且后面的 DoClose 还有复杂的逻辑,所以先在这里删除好了

  end;

  //GlobalFree(DWORD(PerHandleData));
  iocpClass.DoClose(so); //有校验的,参数错误也不要紧,不过 PerIoData 一般是被销毁破坏了,所以清空了就不要再走后面的流程了
  closesocket(so); //补一刀,以免非关闭的错误留下死连接,不过以后最好放到 DoClose 里,以免误杀
  //Winsock2_v2.closesocket(so);
  Exit;



end;

procedure TIocpClass.ClearIoData(PerIoData: LPPER_IO_OPERATION_DATA);//代替 GlobalFree(DWORD(PerIoData));
begin
  PerIoData.debugtag := 6;


  // 2015/5/11 9:24:55 现在由连接类统一管理,只有当连接类不存在时(已先行关闭)才需要自己释放
  //if PerIoData.ConFree = 1 then
  begin
    //self.perIoDataList.Remove(Integer(PerIoData));//把生成的 periodata 都记录下来
    IocpFree(PerIoData, 2);

  end;

end;



//--------------------------------------------------

//工作线程//有一个问题是怎么知道所有的 PerIoData 和 PerHandleData 都正确释放而没有内存泄漏呢
procedure TServerWorkerThread.Run;//CompletionPortID:Pointer):Integer;stdcall;
var
//  BytesTransferred: DWORD;
//  PerIoData : LPPER_IO_OPERATION_DATA;//这里是自己用的临时变量
//  bSleep:Boolean; // 2015/4/3 15:59:53 是否让循环等待一下
//  bGet:BOOL; //GetQueuedCompletionStatus 的返回值
//  lpCompletionKey: DWORD;
//  connect:TConnectClass;

//GetQueuedCompletionStatus 涉及到的都应该用临时变量,取到后在加锁后再赋值
  F_PerIoData : LPPER_IO_OPERATION_DATA;
  F_bGet:BOOL;
  F_BytesTransferred: DWORD;
  F_lpCompletionKey: DWORD;

  __dwFlags:DWORD;
  __err:Integer;

begin
  BytesTransferred := 0;

  bSleep := False;

    //CompletionPort:=THANDLE(CompletionPortID);
    //得到创建线程是传递过来的IOCP
    //while(True) do
    while (not Self.Terminated) do // 2015/4/14 9:28:57
    begin

      if bSleep then
      begin
        Sleep(1);
        bSleep := False;
      end;

      //--------------------------------------------------
      //PerHandleData.IsFree := 3;//test GetQueuedCompletionStatus 失败的时候会有无效的 PerHandleData 值?(确实如此,它会保持 PerHandleData 本身的值不变)
      //PerHandleData := nil;//test GetQueuedCompletionStatus 失败的时候会有无效的 PerHandleData 值?(确实如此,它会保持 PerHandleData 本身的值不变)
      //lpCompletionKey := INVALID_SOCKET;// 0;
      //PerIoData := nil;
      F_lpCompletionKey := INVALID_SOCKET;// 0;
      F_PerIoData := nil;

      //工作者线程会停止到GetQueuedCompletionStatus函数处，直到接受到数据为止
      //if (GetQueuedCompletionStatus(CompletionPort, BytesTransferred, DWORD(PerHandleData), POverlapped(PerIoData), INFINITE) = False) then
      //bGet := GetQueuedCompletionStatus(CompletionPort, BytesTransferred, DWORD(PerHandleData), POverlapped(PerIoData), INFINITE);
      //bGet := GetQueuedCompletionStatus(CompletionPort, BytesTransferred, lpCompletionKey, POverlapped(PerIoData), INFINITE);
      F_bGet := GetQueuedCompletionStatus(CompletionPort, F_BytesTransferred, F_lpCompletionKey, POverlapped(F_PerIoData), INFINITE);

      //if F_PerIoData<>nil then F_PerIoData.atWork := -1;

      if Self.Terminated then Exit;//可能是 PostQueuedCompletionStatus 引起的

      //if F_bGet = False then MessageBox(0, 'F_bGet = False', '',0); //用迅雷下载一个 4m 的文件居然就会很多

      //--------------------------------------------------
      if F_bGet = False then
      begin
        if FALSE = WSAGetOverlappedResult(CompletionPort,
          @F_PerIoData.Overlapped, @F_BytesTransferred, false{False,微软即是 false}{是否等待挂起的重叠操作结束}, @__dwFlags) then//错误原因
        begin
          __err := WSAGetLastError();
          LogFile('CheckPerIoDataComplete :' + IntToStr(__err));

          if WSAENOTSOCK = __err then
          begin
            //从目前来看,如果检测到 socket 已经不存在了,可以判定是完成了,不过如果是其他情况呢

            //Result := True;
          end;

          //if WSA_IO_INCOMPLETE <> __err then
          if WSA_IO_INCOMPLETE = __err then
          begin
            if DebugHook<>0 then MessageBox(0, 'F_bGet = False : WSA_IO_INCOMPLETE', '',0);

            //Result := True;
            Continue;

          end;

        end;
      end;
      //--------------------------------------------------

      try
        threadLock.Lock('TServerWorkerThread.Run');

        if F_PerIoData<>nil then F_PerIoData.atWork := -1; // 2015/6/29 14:47:12 应当放到锁中,因为有判断这个值并销毁的代码

        //--------------------------------------------------
        //GetQueuedCompletionStatus 的临时变量传递
        Self.PerIoData        := F_PerIoData        ;
        Self.bGet             := F_bGet             ;
        Self.BytesTransferred := F_BytesTransferred ;
        Self.lpCompletionKey  := F_lpCompletionKey  ;

        //--------------------------------------------------

        //if (F_PerIoData<>nil)and(F_PerIoData.atWork <> -1)
        //then MessageBox(0, pchar(' <>-1: ' + inttostr(F_PerIoData.atWork)),'',0);//取到但还没锁定时被其他的地方处理了

        if g_IOCP_Synchronize_Event
        then Synchronize(DoOne)
        else DoOne();


        Continue;// 2015/5/14 14:51:38  test

      finally
        threadLock.UnLock();
      end;
    end;

end;


//取得一个包后的处理,要能在线程中和主进程同步完成的
procedure TServerWorkerThread.DoOne;
begin

    //各个参数是从这里得到的
    //bGet := GetQueuedCompletionStatus(CompletionPort, BytesTransferred, lpCompletionKey, POverlapped(PerIoData), INFINITE);

    if PerIoData = nil then
    begin
      if DebugHook<>0 then MessageBox(0, 'PerIoData == nil', '', 0); //调试时显示一下
      bSleep := True;
      Exit;//Continue;
      //如果 PerIoData 为空根本没有必要向下走,因为这里不可能的,除非是出错了//退出程序时出现过
    end;

    //这个判断很重要
    //if iocpClass.perIoDataList.ValueOf(Integer(PerIoData)) = -1 then Exit; //这个结构已经销毁了,或者是野指针
    if IocpCheck(PerIoData) = False then Exit; //这个结构已经销毁了,或者是野指针



    //接收成功后仍然后发这里的事件//if PerIoData.debugtag = 111 then MessageBox(0, 'debugtag == 111', '', 0); //调试时显示一下
    PerIoData.first := 1;

    PerIoData.atWork := 0; //先打一个退出 iocp 处理线程的标记//这时候 PerIoData 已经不是空了

    //可以马上取对应 PerIoData 和 lpCompletionKey 的连接,如果发现自己的连接不在了才需要自己释放
    //连接不上的判断除了队列中找不到以外,找到的情况下也有可能是重用了 socket 号的,所以还要判断 PerIoData 与 连接的接收或者发送数据指针是否相同
    //不同的情况下也是要自己释放,因为自己应该是上次 socket 的数据

    //取连接,看看要不要自己释放
    if iocpClass.GetConnect(PerIoData.Socket, connect) = False then //没有这个连接
    begin
      //这个在登录服务器压力测试中非常多//if DebugHook<>0 then MessageBox(0, '连接已释放! TServerWorkerThread.DoOne', '内部服务器错误', 0);//自己的连接不在了,就要释放

      iocpClass.ClearIoData(PerIoData);

      bSleep := True;
      Exit;//Continue;
    end;

    if (connect.sendHelper.FPerIoData <> PerIoData)and(connect.recvHelper.FPerIoData <> PerIoData) then
    begin
      //MessageBox 连接中的数据并不是自己也是要释放的//大量连接时这个也很多
      //if DebugHook<>0 then MessageBox(0, '连接中的数据并不是自己也是要释放的', '内部服务器错误', 0);//自己的连接不在了,就要释放

      iocpClass.ClearIoData(PerIoData);

      bSleep := True;
      Exit;//Continue;
    end;

    //if PerIoData.ConFree = 1
    //then IocpFree(PerIoData, 2);

    //能找到自己连接的都不用释放,因为关闭连接时会一起释放的

    //bGet := GetQueuedCompletionStatus ...
    if (bGet = False) then
    begin
      //当客户端连接断开或者客户端调用closesocket函数的时候,函数GetQueuedCompletionStatus会返回错误。如果我们加入心跳后，在这里就可以来判断套接字是否依然在连接。
      //调用函数的参数错误时也会到这里,这个就不用管了,关闭 socket 好了
      ClearSocket(PerIoData, lpCompletionKey, connect);

      bSleep := True;
      Exit;//continue;
    end;


    //--------------------------------------------------
    //当客户端调用shutdown函数来从容断开的时候，我们可以在这里进行处理。
//    if (BytesTransferred = 0) then
    if (BytesTransferred <= 0) then //微软文档中是小于 0 也同样处理,不知是否有影响
    begin
//            shutdown(lpCompletionKey, 1);
      ClearSocket(PerIoData, lpCompletionKey, connect);

      Exit;//continue;
    end;

    //--------------------------------------------------
    //这里才开始正常的处理
    //在上一篇中我们说到IOCP可以接受来自客户端的数据和自己发送出去的数据，两种数据的区别在于我们定义的结构成员...

    //当是接受来自客户端的数据是，我们进行数据的处理。
    if (PerIoData.OpCode = 0) then
    begin
      //用户事件
      iocpClass.DoRecv(PerIoData.Socket, PerIoData.BufInfo.buf, BytesTransferred);
      //--------------------------------------------------

      //当我们将数据处理完毕以后，应该将此套接字设置为结束状态，同时初始化和它绑定在一起的数据结构。
      ZeroMemory(@PerIoData.Overlapped, sizeof(OVERLAPPED));
      PerIoData.BufInfo.len := DATA_BUFSIZE;
      ZeroMemory(@PerIoData.Buf, sizeof(PerIoData.Buf));
      PerIoData.BufInfo.buf := @PerIoData.Buf;

      //再次投递一个接收请求
      //if (WSARecv(PerIoData.Socket, @PerIoData.BufInfo, 1, tmpRecvBytes, Flags, @PerIoData.Overlapped, nil) = SOCKET_ERROR) then
      if iocpInterface.RecvBuf(PerIoData.Socket, PerIoData) = False then
      begin
        ClearSocket(PerIoData, lpCompletionKey, connect); //里面会手工调用关闭事件
        //IocpFree(PerIoData);//ClearIoData(PerIoData);//失败的话是要自己释放的//统一在连接中处理
        Exit;//continue;
      end;
      PerIoData.debugtag := 222;

    end
    //--------------------------------------------------
    //**************************************************
    //--------------------------------------------------
    //当我们判断出来接受的数据是我们发送出去的数据的时候，在这里我们清空我们申请的内存空间
    else//发送的情况
    begin
      g_IOCP_SendSize_test := g_IOCP_SendSize_test - BytesTransferred; // 2015/4/13 17:28:54 test

      //取下一个包内容
      if iocpClass.IoDataGetNext(PerIoData, BytesTransferred) = True then
      begin
        //WSASend(PerIoData.Socket, @PerIoData.BufInfo, 1{这个应该指的是缓冲结构的个数,固定为1}, tmpSendBytes, Flags, @(PerIoData.Overlapped), nil);
        iocpInterface.SendBuf(PerIoData.Socket, PerIoData);

      end
      else//全部发送成功了
      begin
        // 2015/4/3 11:01:27 用户事件//分片的优点是可以知道哪一块发送成功了,但从实际的情况来看用户并不需要管理,只管发送就行了
        //目前来说只有 http 的情况需要知道已经发送完成,然后关闭 socket

        //if Assigned(OnSend_thread) then OnSend_thread(PerIoData.Socket, PerIoData.OuterFlag);
        iocpClass.DoSend(PerIoData.Socket);

        //这时候才能直接发起另一个发送
        connect.sendHelper.atSend := False;

      end;//是否还有包发送


    end;//是否发送包


end;


{ TServerWorkerThread }

procedure TServerWorkerThread.Execute;
begin
  inherited;

  if DebugHook=0 then //运行时可以用 except ,调试时用就看不到错误地点了
  begin

    {$ifndef EXCEPT_DEBUG}//调试异常的情况下屏蔽
    try
    {$endif}

      Run();
      Exit;

    {$ifndef EXCEPT_DEBUG}//调试异常的情况下屏蔽
    except//必须用 except 去掉异常,否则后面的数据接收不响应
      MessageBox(0, 'TServerWorkerThread.Execute 已退出.', '', 0);
    end;
    {$endif}
  end;  

  try

    Run;
  finally
    LogFileMem('TServerWorkerThread.Execute 已退出.');

  end;

  LogFile('TServerWorkerThread.Execute 已退出.');//记录下,是否异常退出

end;


{ TCreateServerThread }

procedure TAcceptThread.Execute;
begin
  inherited;

  try

    CreateServer;
  finally
    LogFileMem('TAcceptThread.Execute 已退出.');
  end;

  LogFile('TAcceptThread.Execute 已退出.');//记录下,是否异常退出


end;

{ TIocpClass }

//procedure TIocpClass.SendData(Socket: TSocket; buf: PChar; bufLen: Integer; OuterFlag: Integer);
//begin
//  iocpSendHelper.SendData(Socket, buf, bufLen, OuterFlag);
//
//end;


//线程安全的同步发送,调用者不需要考虑同步问题,简单地直接调用就行了
procedure TIocpClass.SendDataSafe_NoLock(Socket: TSocket; buf: PChar; bufLen:Integer);
var
  helper:TSendHelper;
  PerIoData: LPPER_IO_OPERATION_DATA;
  connect:TConnectClass;
begin
  // 2015/4/14 13:13:06 注意,由于现在没有加锁定,所以不能在线程中调用//因为事件是锁定后才触发的,所以在事件中可以安全的使用

  try
    sendLock.Lock('TIocpClass.SendDataSafe');

    if GetConnect(Socket, connect) = False then Exit; //没有这个连接

    g_IOCP_SendSize_test := g_IOCP_SendSize_test + bufLen;// 2015/4/13 17:26:20 test

    helper := nil;

    helper := connect.sendHelper;

    //添加到发送缓冲中
    helper.AddSendBuf(buf, buflen);

    if (helper.isBindIocp = True)and(helper.atSend = False) then  // 2015/5/8 16:51:51 瑞加个绑定 iocp 后才能发送,因为不绑定的话无法在事件中处理,而且效果未知
    begin//没有正在发送的话,发送
      //helper.atSend := True;
      helper.DoSendBuf(Socket);
      //SendData(Socket, buf, bufLen, connect.Iocp_OuterFlag);//因为这块数据立即发送了,所以不用放在缓冲中
    end;


  finally
    sendLock.UnLock;
  end;

end;

//线程安全的同步发送,调用者不需要考虑同步问题,简单地直接调用就行了
procedure TIocpClass.SendDataSafe(Socket: TSocket; buf: PChar; bufLen,
  User_OuterFlag: Integer);
begin

  //根据不同的运行模式加锁定//线程模式下不用锁定,因为都是在线程中加锁定调用的,即线程模式下不能在主进程中调用.原来是可以的,但现在减少了锁所以要求要高
  if g_IOCP_Synchronize_Event = False then
  begin
    SendDataSafe_NoLock(Socket, buf, bufLen);

    Exit;
  end;

  //判断是否在主线程中,如果是
  if (GetWindowThreadProcessId(Application.Handle, nil) = GetCurrentThreadId) then
    SendDataSafe_NoLock(Socket, buf, bufLen)
  else MessageBox(0, '请在主进程中调用', '', 0);  



end;


//取下一个要发送的数据要填充 io 结构//BytesTransferred 是当前发送成功的字节数,其实照目前的算法就是 DATA_BUFSIZE
function TIocpClass.IoDataGetNext(PerIoData : LPPER_IO_OPERATION_DATA; BytesTransferred:Integer):Boolean;
var
  sendHelper:TSendHelper;
  //PerIoData: LPPER_IO_OPERATION_DATA;
  con:TConnectClass;
begin
  if GetConnect(PerIoData.Socket, con) = False then Exit; //没有这个连接

  Result := con.sendHelper.IoDataGetNext(PerIoData, BytesTransferred);


end;


procedure TIocpClass.StartService;
//var
//  thread:TAcceptThread;

begin
  //Self.threadLock := TThreadLock.Create(Application);// 2015/4/14 10:41:06 现在需要自己释放
  Self.threadLock := TThreadLock.Create(nil);// 2015/4/14 10:41:06 现在需要自己释放
  //acceptLock := TThreadLock.Create(Application);
  acceptLock := TThreadLock.Create(nil);// 2015/4/14 10:41:06 现在需要自己释放
  acceptList := TFastQueue.Create(20000);//20000//其实 2000 就足够了
  socketList := TFastHashSocketQueue.Create();
  //ckeyList := TFastHashSocketQueue.Create();
  //Count := 0;
  //Count2 := 0;

  //sendDataList := TList.Create;
//  sendSocketList := TFastHashSocketQueue.Create();
  //sendLock := TThreadLock.Create(Application);
  sendLock := TThreadLock.Create(nil);//自己释放好了


  acceptThread := TAcceptThread.Create(True);
  acceptThread.iocpClass := Self;

  //这些变量最好是直接赋值不要经过 iocpClass,这样更安全
  acceptThread.threadLock := Self.threadLock;
  acceptThread.acceptLock := Self.acceptLock;
  acceptThread.acceptList := Self.acceptList;
//  acceptThread.OnConnect_thread := Self.DoConnect;//OnConnect;
  acceptThread.Resume;

  //--------------------------------------------------
  //timerThread.Resume;// 2015/6/10 9:35:48 改成手工启动才好控制


end;


procedure TIocpClass.StartOnTimerEvent;
begin

  timerThread.Resume;// 2015/6/10 9:35:48 改成手工启动才好控制


end;

{ TAcceptFastThread }

//--------------------------------------------------

//新连接生成非常复杂还是应当独立出来,也不要在 iocp 主类中进行,因为很容易逻辑混乱
function TAcceptFastThread.NewConnect(Socket: TSocket; var connect:TConnectClass; var oldConnect:TConnectClass):Boolean;
var
  //helper:TRecvHelper;
  //sendHelper:TSendHelper;
  PerIoData : LPPER_IO_OPERATION_DATA;
  tmp:Pointer;
  oldcon:TConnectClass;//原来这个 socket 号对应的连接类
  newcon:TConnectClass;//要换新的连接类
  OuterFlag: Integer;

begin

  Result := False;
  connect := nil;

    //if iocpClass.GetConnect(Socket, OuterFlag, oldcon) then
    if iocpClass.socketList.GetItem(Socket, tmp) then
    begin
      oldConnect := tmp;
      //oldcon.ClearSendData; //有正在发送的话
      //如果有旧连接的话应当退出,如果是僵死的连接会有超时判断过程将其去掉,这种情况只会发生在一个连接被迅速关闭的情况下
      //因为后继有很多操作都依赖连接的生存期
      LogFile('TAcceptFastThread.NewConnect 发现socket被占用');
      Exit;
    end;

    //--------------------------------------------------

    //应当放到后面去,因为事件中也会用到连接,所以要在连接生成后触发事件//if Assigned(OnConnect) then OnConnect(Socket, OuterFlag);
    newcon := TConnectClass.Create(iocpClass);

    //先生成连接再触发事件,因为事件也要用连接对象
    iocpClass.SetConnect(Socket, newcon);

    //触发事件去取得用户的标志//后面再加同步
    //OuterFlag := 0;
    //iocpClass.DoConnect(Socket, OuterFlag);

    //--------------------------------------------------
    OuterFlag := 0;//clq // 2015/4/2 13:29:32 这里初始化一下比较好

    iocpClass.DoConnect(Socket, OuterFlag);


    //--------------------------------------------------

    newcon.User_OuterFlag := OuterFlag;//这里一般修改过了,所以要重新赋值

    //newcon.Iocp_OuterFlag := Integer(newcon);


  connect := newcon;
  Result := True;
end;


procedure TAcceptFastThread.DoOne;
var
  oldcon:TConnectClass;
begin


    if Self.Terminated then exit; // 2015/4/14 10:20:53 有可能是关闭引起的

    //这个时候 Acceptsc 有可能是已经被关闭了的
    if Self.NewConnect(Acceptsc, newcon, oldcon) = False then
    begin
      bSleep := True;

      iocpClass.DoClose(Acceptsc); //目前的逻辑有可能前面的得不到关闭事件,所以再关闭一下.因为有连接管理,所以这个重复调用是不要紧的
      //测试 iocp 超时断开检测时可以不做这个检测,因为这里算是手工关闭了,就没法判断是否是 iocp 的判断完整了
      //攻击时非常多//if DebugHook<>0 then MessageBox(0, 'PerIoData == nil', '', 0); //调试时显示一下

      closesocket(Acceptsc);//感觉还是应当关闭,否则会成为死连接
      //Winsock2_v2.closesocket(Acceptsc);//不是这里

      LogFile('上次的关闭还未完成. ' + IntToStr(Acceptsc), False);//如果连接太多太快的情况下是可能的,因为被关闭的那个又被重用了
      Exit;//Continue;
    end;

    //--------------------------------------------------

    //用户事件,如果需要用户会传入一个外部标识

    //必须先触发 connect 事件,因为有很多初始化工作要做

    //如果这时候客户端关闭 socket 的话是不会触发 iocp 事件的,那怎么知道对方关闭了呢?//哦,绑定时会提示失败的

    //--------------------------------------------------
    //原来的清理失败过程太复杂了,正确的步骤应当是:
    //1.绑定后才接收. 绑定后是必须加接收动作的,否则 iocp 工作线程不会触发,除非对方先发数据.
    //2.绑定失败, iocp 按道理是不可能触发的,所以要手工清理相关资源,同时手工触发关闭事件.
    //3.绑定后的第一个接收失败怎么办呢,以前是同样手工触发关闭事件,但按道理来说只要关闭 socket 就行了,
    //  因为完成端口是成功绑定了的,关闭事件应当触发,就算没有也不管了因为理论应当如此,
    //  可以用别的方法清理内存,例如记录所有的 socket 不过不论怎么都不要在这里修改这些理论了
    //  因为去猜测 iocp 的触发条件是不可取,应当就认为是这样的理论流程,然后对流程外的资源补加清理过程就行了

    //创建一个“单句柄数据结构”将Acceptsc套接字绑定。
    //PerHandleData := nil; //重置一下比较好
    CompletionKey := INVALID_SOCKET;//重置一下比较好

    CompletionKey := Acceptsc;



    //将套接字、完成端口和“单句柄数据结构”三者绑定在一起。//注意,这里其实不是创建而是把接收到的 socket 与已经创建好的完成端口句柄绑定
    bindErr := False;
    //if (CreateIoCompletionPort(Acceptsc, CompletionPort, DWORD(PerHandleData), 0) = 0) then
    if (CreateIoCompletionPort(Acceptsc, CompletionPort, CompletionKey, 0) = 0) then
    begin
      bSleep := True;

      LogFile('完成端口绑定失败.' + SysErrorMessage(GetLastError()));//"参数不正确" 的时候是重复绑定了一个端口
      //这时候 Acceptsc 是可能已经被关闭了的
      //closesocket(Acceptsc);//Continue;//以前做关闭处理,实际上不用,在外部加超时连接判断会处理的
      closesocket(Acceptsc);//Continue;//因为没有绑定,所以关闭也是可以的,因为完成端口的事件是不会触发的
      //Winsock2_v2.closesocket(Acceptsc);

      bindErr := True;

      //MessageBox(0, '完成端口绑定失败', '服务器内部错误', 0);
      //MessageBox(0, PChar('完成端口绑定失败.' + SysErrorMessage(GetLastError())), '服务器内部错误', 0);
      //exit;

      //因为这时已经触发连接事件了,所以要手工触发关闭
      iocpClass.DoClose(Acceptsc);

      Exit;//Continue;
    end;

    //绑定成功后才能发数据,否则数据虽然能发出去但 iocp 事件是不会触发的,所以后面还要补一个发送的动作

    //Continue;// test 不接收会触发关闭吗? 确实不会

    //开始接收数据
    PerIoData := nil;//重置一下

    re := iocpInterface.RecvBuf(Acceptsc, newcon.recvHelper.GetIoData(Acceptsc));

    // 2013-3-7 15:29:31 目前认为是绑定失败的才需要自己处理,如果成功绑定的 iocp 应当会有反应
    //--------------------------------------------------

    if re = False then
    begin
      bSleep := True;

      //--------------------------------------------------
      closesocket(Acceptsc);//先关闭 socket 比较安全,以免再次触发 iocp 事件(似乎还是会触发)
      //Winsock2_v2.closesocket(Acceptsc);

      //有可能在这里释放以后, iocp 事件又在触发引起 as 错误//不过理论上说接收动作没完成是不会触发的
      iocpClass.DoClose(Acceptsc);

      Exit;//Continue;

    end;//if

    //--------------------------------------------------
    //都没问题了就要看看连接事件里而有没有要发送的东西//出错的话就不要走这里,困为前面可能清空这个连接了
    try
    iocpClass.sendLock.Lock('TIocpClass.SendDataSafe');
    newcon.sendHelper.isBindIocp := True;
    newcon.sendHelper.DoSendBuf(Acceptsc);

    finally
    iocpClass.sendLock.UnLock;
    end;



end;



procedure TAcceptFastThread.Run;
begin
  inherited;

  bSleep := False;

  //while(TRUE) do
  while (not Self.Terminated) do
  begin

    if bSleep then
    begin
      Sleep(1);
      bSleep := False;
    end;


    //--------------------------------------------------
    try
      acceptLock.Lock('acceptLock.Lock');//很简单,不用 try 了// 2015/4/3 13:48:29  还是要的,因为 lock 本身分异常

      if Self.Terminated then exit; // 2015/4/14 10:20:53 有可能是关闭引起的

      //acceptList.Write(Acceptsc);
      haveSocket := acceptList.Read(Acceptsc);
    finally
      acceptLock.UnLock;
    end;

    if haveSocket = False then
    begin
      bSleep := True;

      Continue;//没有未处理的了
    end;

    //--------------------------------------------------
    try
      iocpClass.threadLock.Lock('TAcceptFastThread.Execute');

      if Self.Terminated then exit; // 2015/4/14 10:20:53 有可能是关闭引起的

      if g_IOCP_Synchronize_Event
      then Synchronize(DoOne)
      else DoOne();

      Continue;


    finally
      iocpClass.threadLock.UnLock;
    end;


  end;//while

  LogFile('TAcceptFastThread.Execute 已退出.');//记录下,是否异常退出


end;

procedure TAcceptFastThread.Execute;
begin

  if DebugHook=0 then //运行时可以用 except ,调试时用就看不到错误地点了
  begin

    {$ifndef EXCEPT_DEBUG}//调试异常的情况下屏蔽
    try
    {$endif}

      Run();
      Exit;

    {$ifndef EXCEPT_DEBUG}//调试异常的情况下屏蔽
    except//必须用 except 去掉异常,否则后面的数据接收不响应
      MessageBox(0, 'TAcceptFastThread.Execute 已退出.', '', 0);
    end;
    {$endif}


  end;  

  try
    Run();
  finally
    
  LogFile('TAcceptFastThread.Execute 已退出.');//记录下,是否异常退出

  end;   

end;

{ TConnectClass }


//constructor TConnectClass.Create;
constructor TConnectClass.Create(iocp:TIocpClass);
begin
  //inherited;
  inherited Create;

  iocpClass := iocp;

  sendHelper := TSendHelper.Create(Self);
  recvHelper := TRecvHelper.Create(Self);

  //把生成的 periodata 都记录下来
  //iocpClass.perIoDataList.Add(Integer(recvHelper.FPerIoData), 0);
  //iocpClass.perIoDataList.Add(Integer(sendHelper.FPerIoData), 0);

end;

destructor TConnectClass.Destroy;
begin
  FreeAndNil(recvHelper);
  FreeAndNil(sendHelper);

  inherited;
end;

procedure TIocpClass.AddOnTimerEvent(EventName: string;
  OnTimer: TOnIocpTimerProc; Interval: Cardinal);
begin
  //增加一个定时器处理事件
  Self.timerThread.AddOnTimerEvent(EventName, OnTimer, Interval);

end;

procedure TIocpClass.SetOnTimerEvent_ThreadFun(OnThreadBegin,
  OnThreadEnd: TOnIocpTimerProc);
begin
  Self.timerThread.SetOnTimerEvent_ThreadFun(OnThreadBegin, OnThreadEnd);
end;


//在线程中响应事件的高性能模式.默认在主进程中处理事件,性能略差//和上面的参数作用一样,方便与 TIdUDPServer.ThreadedEvent 同理解而已
class procedure TIocpClass.ThreadedEvent(EventInThread:Boolean);
begin
  g_IOCP_Synchronize_Event := not EventInThread;
end;


end.


