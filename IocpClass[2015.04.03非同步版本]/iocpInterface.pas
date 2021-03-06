unit iocpInterface;

//iocp 的单独放在这里
//不要直接使用此单元,请使用 iocpInterfaceClass 中定义的类

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  winsock2,
  //IdWinSock2,
  //WinSock,

  ComCtrls,Contnrs,
  Dialogs;

type
  TSocket = Cardinal;//u_int;//clq //c 语言原型里的确是无符号的//TSocket 兼容性修正//IdWinSock2 中有误    

const
  DATA_BUFSIZE = 1024;//8192;

type
  //回调函数指针
  //OnRecvProc = procedure (Socket: TSocket; buf:PChar; bufLen:Integer);
  //接收一块完成
  TOnRecvProc = procedure (Socket: TSocket; buf:PChar; bufLen:Integer) of object;
  //发送一块完成//与接收不同的是,这个是全部发送才产生一次事件
  TOnSendProc = procedure (Socket: TSocket) of object;
  //关闭客户端 socket 时
  TOnSocketCloseProc = procedure (Socket: TSocket) of object;

type

   //单IO数据结构

   LPVOID = Pointer;
   LPPER_IO_OPERATION_DATA = ^ PER_IO_OPERATION_DATA ;
   PER_IO_OPERATION_DATA = packed record
     Overlapped: OVERLAPPED;
     DataBuf: WSABUF;//iocp 内部的数据表示,包括缓冲区和缓冲长度,这个是可以按用户定义在完成一次异步操作后改变的
     //Buffer: array [0..1024] of CHAR;
     Buf: array [0..DATA_BUFSIZE] of CHAR;//用户要操作的缓冲区,在这个生存期是不变的
     BufLen: DWORD;//用户要操作的缓冲区长度,在这个生存期是不变的
     BytesSEND: DWORD;//已完成的多少
     BytesRECV: DWORD;//已完成的多少
     OpCode: Integer;//0 - 表示是接收用的缓冲, 1 - 表示是发送用的缓冲
     Socket: TSocket;//其实 socket 保存在这里在释放时更安全//当然如果不用 socket 作为关键字去标识一个连接而是直接关联到一个指针的话
                     //那还是应该放在 PER_HANDLE_DATA 中并加计数器
     OuterFlag:Integer;//传出外部连接标志//为兼容原有 iocp 接口,作用类似于线程函数中传递的参数
     ExtInfo:Integer;//扩展信息,通常是一个指针
   end;

   //“单句柄数据结构”

   LPPER_HANDLE_DATA = ^ PER_HANDLE_DATA;
   PER_HANDLE_DATA = packed record
     Socket: TSocket;
     IsFree : Integer;//确实是需要判断 PER_HANDLE_DATA 是否已经删除了//仅用于测试
     //isFirst : Integer;//第一个包,用来减轻 accept 的压力
     OuterFlag:Integer;//传出外部连接标志//为兼容原有 iocp 接口,作用类似于线程函数中传递的参数
   end;

var
//  wsData: TWSAData;
  IocpOnRecv:TOnRecvProc=nil;
  IocpOnClose:TOnSocketCloseProc=nil;
  IocpOnSend:TOnSendProc=nil;




//工作线程
function ServerWorkerThread(CompletionPortID:Pointer):Integer;stdcall;
//创建服务的线程
function CreateServerThread(CompletionPortID:Pointer):Integer;stdcall;

//接受 socket 是需要线程的
procedure CreateThreadAccept;

procedure InitSock;

//完成端口接收
function RecvBuf(Socket: TSocket):Integer;overload;
function RecvBuf(Socket: TSocket; OuterFlag:Integer):Integer;overload;
//完成端口发送
procedure SendBuf(Socket: TSocket; buf:PChar; bufLen:Integer);overload;
procedure SendBuf(Socket: TSocket; buf:PChar; bufLen:Integer; OuterFlag:Integer; ExtInfo:Integer{扩展信息,通常是一个指针});overload;
procedure SendBuf(Socket: TSocket; PerIoData : LPPER_IO_OPERATION_DATA);overload;



implementation

uses uThreadLock;



//创建服务
procedure CreateServer;
var
  i:Integer;
  Acceptsc:Integer;
  PerHandleData : LPPER_HANDLE_DATA;//这个应该是可更改的
  sto:sockaddr_in;
  Listensc :Integer;
  ThreadID:THandle;
  hThread:THandle;
  LocalSI:TSystemInfo;
  CompletionPort : THandle;

begin
  //InitSock();

  //创建一个完成端口。
  CompletionPort := CreateIOCompletionPort(INVALID_HANDLE_VALUE,0,0,0);

  //根据CPU的数量创建CPU*2数量的工作者线程。
  GetSystemInfo(LocalSI);
  for i:=0 to LocalSI.dwNumberOfProcessors * 2 -1 do
  begin
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
  end;


  //创建一个套接字，将此套接字和一个端口绑定并监听此端口。
  Listensc:=WSASocket(AF_INET,SOCK_STREAM,0,Nil,0,WSA_FLAG_OVERLAPPED);
  if Listensc=SOCKET_ERROR then
  begin
       closesocket(Listensc);
       WSACleanup();
  end;
  sto.sin_family:=AF_INET;
  sto.sin_port:=htons(5500);
  sto.sin_addr.s_addr:=htonl(INADDR_ANY);
  if bind(Listensc,@sto,sizeof(sto))=SOCKET_ERROR then
  begin
      closesocket(Listensc);
  end;
  //listen(Listensc,20);         SOMAXCONN
  //listen(Listensc, SOMAXCONN);
  listen(Listensc, $7fffffff);//WinSock2.SOMAXCONN);

  //--------------------------------------------------
  while (TRUE) do
  begin
    //当客户端有连接请求的时候，WSAAccept函数会新创建一个套接字Acceptsc。这个套接字就是和客户端通信的时候使用的套接字。
    Acceptsc:= WSAAccept(Listensc, nil, nil, nil, 0);


    //判断Acceptsc套接字创建是否成功，如果不成功则退出。
    if (Acceptsc= SOCKET_ERROR) then
    begin
       closesocket(Listensc);
       exit;
    end;

    //创建一个“单句柄数据结构”将Acceptsc套接字绑定。
    PerHandleData := LPPER_HANDLE_DATA (GlobalAlloc(GPTR, sizeof(PER_HANDLE_DATA)));
    if (PerHandleData = nil) then
    begin
       exit;
    end;
    PerHandleData.Socket := Acceptsc;
    PerHandleData.isFree := 0;//test

    //将套接字、完成端口和“单句柄数据结构”三者绑定在一起。
    if (CreateIoCompletionPort(Acceptsc, CompletionPort, DWORD(PerHandleData), 0) = 0) then
    begin
       exit;
    end;

    //接收数据
    //完成端口接收
    RecvBuf(Acceptsc);



  end;

end;


//完成端口接收
function RecvBuf(Socket: TSocket):Integer;
begin
  Result := RecvBuf(Socket, 0);
end;



//完成端口接收
function RecvBuf(Socket: TSocket; OuterFlag:Integer):Integer;
var
  PerIoData : LPPER_IO_OPERATION_DATA;//这里是自己用的临时变量
  RecvBytes:DWORD;//接收到的字节数
  Flags:DWORD;
  errno:Integer;
begin
    Result := 0;

    //创建一个“单IO数据结构”其中将PerIoData.BytesSEND 和PerIoData.BytesRECV 均设置成0。说明此“单IO数据结构”是用来接受的。
    PerIoData := LPPER_IO_OPERATION_DATA(GlobalAlloc(GPTR, sizeof(PER_IO_OPERATION_DATA)));
    if (PerIoData = nil) then
    begin
      result := -1;//未知错误
      Sleep(1);//test
      exit;
    end;
    ZeroMemory(@PerIoData.Overlapped, sizeof(OVERLAPPED));
    PerIoData.BytesSEND := 0;
    PerIoData.BytesRECV := 0;
    PerIoData.DataBuf.len := DATA_BUFSIZE;//1024;
    PerIoData.DataBuf.buf := @PerIoData.Buf;
    PerIoData.OpCode := 0;//接收用的
    PerIoData.Socket := Socket;//用做关键字的话,放这里更安全
    PerIoData.OuterFlag := OuterFlag;//用做关键字的话,放这里更安全
    Flags := 0;


    //用此“单IO数据结构”来接受Acceptsc套接字的数据。
    //if (WSARecv(Socket, @(PerIoData.DataBuf), 1, @RecvBytes, @Flags,@(PerIoData.Overlapped), nil) = SOCKET_ERROR) then
    if (WSARecv(Socket, @(PerIoData.DataBuf), 1, RecvBytes, Flags,@(PerIoData.Overlapped), nil) = SOCKET_ERROR) then
    begin
       errno := WSAGetLastError();       //WSAENOTSOCK
       //if (WSAGetLastError() <> ERROR_IO_PENDING) then
       if (errno <> ERROR_IO_PENDING) then
       begin
         result := errno;
//         exit;
       end
    end;

end;

//完成端口发送
procedure SendBuf(Socket: TSocket; buf:PChar; bufLen:Integer);
begin
  SendBuf(Socket, buf, bufLen, 0, 0);
end;

//完成端口发送//这里一定要传入外部标志
procedure SendBuf(Socket: TSocket; buf:PChar; bufLen:Integer; OuterFlag:Integer; ExtInfo:Integer);overload;
var
    PerIoData : LPPER_IO_OPERATION_DATA;//这里是自己用的临时变量
    SendBytes:DWORD;
    Flags:DWORD;
    re:u_int;
begin
    //创建一个“单IO数据结构”其中将PerIoData.BytesSEND 和PerIoData.BytesRECV 均设置成0。说明此“单IO数据结构”是用来接受的。
    PerIoData := LPPER_IO_OPERATION_DATA(GlobalAlloc(GPTR, sizeof(PER_IO_OPERATION_DATA)));
    if (PerIoData = nil) then
    begin
       exit;
    end;

    if bufLen>DATA_BUFSIZE then Exit;//不能超过 iocp 缓冲大小

    ZeroMemory(@PerIoData.Overlapped, sizeof(OVERLAPPED));
    PerIoData.BytesSEND := 0;
    PerIoData.BytesRECV := 0;
    PerIoData.DataBuf.len := bufLen;//1024;
    PerIoData.DataBuf.buf := @PerIoData.Buf;
    PerIoData.OpCode := 1;//标志,发送用的
    PerIoData.Socket := Socket;//用做关键字的话,放这里更安全
    PerIoData.OuterFlag := OuterFlag;
    PerIoData.ExtInfo := ExtInfo;
    Flags := 0;

    //--------------------------------------------------
    //填充一些测试数据
    //CopyMemory(PerIoData.DataBuf.buf, PChar('aaa'#13#10), 5);
    CopyMemory(PerIoData.DataBuf.buf, buf, bufLen);
    PerIoData.BufLen := bufLen;
    //--------------------------------------------------

    SendBuf(Socket, PerIoData);

    {
    //用此“单IO数据结构”来接受Acceptsc套接字的数据。
    //if (WSARecv(Acceptsc, @(PerIoData.DataBuf), 1, @RecvBytes, @Flags,@(PerIoData.Overlapped), nil) = SOCKET_ERROR) then
    re := WSASend(Socket, @(PerIoData.DataBuf), 1, @SendBytes, Flags, @(PerIoData.Overlapped), nil);
    if (re = SOCKET_ERROR) then
    begin
       if (WSAGetLastError() <> ERROR_IO_PENDING) then
       begin
         //MessageBox(0, '发送失败', '', 0);//这种情况也是有的
         closesocket(Socket);
         exit;
       end
    end;
    }

end;

//完成端口发送
procedure SendBuf(Socket: TSocket; PerIoData : LPPER_IO_OPERATION_DATA);overload;
var
    //dwFlags: DWORD;
    //PerIoData : LPPER_IO_OPERATION_DATA;//这里是自己用的临时变量
    SendBytes:DWORD;
    Flags:DWORD;
begin

    Flags := 0;

    //--------------------------------------------------

    //用此“单IO数据结构”来接受Acceptsc套接字的数据。
    //if (WSARecv(Acceptsc, @(PerIoData.DataBuf), 1, @RecvBytes, @Flags,@(PerIoData.Overlapped), nil) = SOCKET_ERROR) then
    if (WSASend(Socket, @(PerIoData.DataBuf), 1, SendBytes, Flags, @(PerIoData.Overlapped), nil) = SOCKET_ERROR) then
    begin
       if (WSAGetLastError() <> ERROR_IO_PENDING) then
       begin
         //MessageBox(0, '发送失败', '', 0);//这种情况也是有的
         closesocket(Socket);//目前的架构下会触发 iocp 事件使释放事件完整,不过以后还是应当自己来处理
         exit;
       end
    end;

end;


procedure InitSock;
var
  wsData: TWSAData;
begin
  if WSAStartUp($202, wsData) <> 0 then
  begin
      WSACleanup();
  end;

end;

//创建服务的线程
function CreateServerThread(CompletionPortID:Pointer):Integer;stdcall;
begin
  CreateServer;
end;

procedure Lock();
begin
  //threadLock.Lock;//线程引发的,必须锁定
end;

procedure UnLock();
begin
  //threadLock.unLock;//线程引发的,必须锁定
end;  

//工作线程//有一个问题是怎么知道所有的 PerIoData 和 PerHandleData 都正确释放而没有内存泄漏呢
function ServerWorkerThread(CompletionPortID:Pointer):Integer;stdcall;
var
    BytesTransferred: DWORD;
    PerIoData : LPPER_IO_OPERATION_DATA;//这里是自己用的临时变量
    TempSc:Integer;
    PerHandleData : LPPER_HANDLE_DATA;
    SendBytes:DWORD;
    RecvBytes:DWORD;//接收到的字节数
    Flags:DWORD;
    CompletionPort : THandle;

    procedure ClearSocket();
    begin
      closesocket(PerHandleData.Socket);
      
      if Assigned(IocpOnClose) then IocpOnClose(PerHandleData.Socket);//必须在 free 前调用

      //GlobalFree(DWORD(PerHandleData));

      //--------------------------------------------------
      Lock;//threadLock.Lock;//线程引发的,必须锁定

      try
        if PerHandleData.isFree = 1 then
        begin
          ShowMessage('access violation');//实际上确实是 access violation 错误
        end;  

        //根据目前的业务逻辑只有一个接收 iodata 并且是一直在接收的,所以 socket 的销毁可以和接收 io 绑定在一起
        //而发送包事件中就不要销毁 socket 了,以免 as 错误
        if PerIoData.OpCode = 0 then
        begin
          PerHandleData.isFree := 1;
          GlobalFree(DWORD(PerHandleData));
        end;

      finally
        UnLock;//threadLock.UnLock;
      end;

    end;

    procedure ClearIoData();//代替 GlobalFree(DWORD(PerIoData));
    begin
      
      //if Assigned(IocpOnClose) then IocpOnClose(PerHandleData.Socket);//必须在 free 前调用

      //GlobalFree(DWORD(PerIoData));

      Lock();//threadLock.Lock;//线程引发的,必须锁定

      try
        GlobalFree(DWORD(PerIoData));

      finally
        UnLock;// threadLock.UnLock;
      end;
    end;

begin
    BytesTransferred := 0;

    CompletionPort:=THANDLE(CompletionPortID);
    //得到创建线程是传递过来的IOCP
    while(TRUE) do
    begin
         //工作者线程会停止到GetQueuedCompletionStatus函数处，直到接受到数据为止
         if (GetQueuedCompletionStatus(CompletionPort, BytesTransferred,DWORD(PerHandleData), POverlapped(PerIoData), INFINITE) = False) then
         begin
           //当客户端连接断开或者客户端调用closesocket函数的时候,函数GetQueuedCompletionStatus会返回错误。如果我们加入心跳后，在这里就可以来判断套接字是否依然在连接。
           if PerHandleData<>nil then
           begin
             //closesocket(PerHandleData.Socket);
             //GlobalFree(DWORD(PerHandleData));
             ClearSocket();
           end;
           if PerIoData<>nil then
           begin
             //GlobalFree(DWORD(PerIoData));
             ClearIoData();
           end;
           continue;
         end;
         
         //当客户端调用shutdown函数来从容断开的时候，我们可以在这里进行处理。
         if (BytesTransferred = 0) then
         begin
            if PerHandleData<>nil then
            begin
              TempSc:=PerHandleData.Socket;
              shutdown(PerHandleData.Socket, 1);
              //closesocket(PerHandleData.Socket);
              //GlobalFree(DWORD(PerHandleData));
              ClearSocket;
            end;
            if PerIoData<>nil then
            begin
              //GlobalFree(DWORD(PerIoData));
              ClearIoData();
            end;
            continue;
         end;

         //--------------------------------------------------
         //这里才开始正常的处理
         //在上一篇中我们说到IOCP可以接受来自客户端的数据和自己发送出去的数据，两种数据的区别在于我们定义的结构成员...

         //当是接受来自客户端的数据是，我们进行数据的处理。
         if (PerIoData.OpCode = 0) then
         begin
           PerIoData.DataBuf.buf := PerIoData.Buf + PerIoData.BytesSEND;
           PerIoData.DataBuf.len := PerIoData.BytesRECV - PerIoData.BytesSEND;
           //这时变量PerIoData.Buffer就是接受到的客户端数据。数据的长度是PerIoData.DataBuf.len 你可以对数据进行相关的处理了。
           //.......

           //--------------------------------------------------
           //发送一些测试数据
           //SendBuf_test(PerHandleData.Socket);
           //SendBuf(PerHandleData.Socket, 'aaa'#13#10, 5);
           //正规做法应当是触发一个事件或是回调函数,由上层应用决定是否发送

           //if Assigned(IocpOnRecv) then IocpOnRecv(PerHandleData.Socket, PerIoData.DataBuf.buf, PerIoData.DataBuf.len);
           //PerIoData.DataBuf.len 里没有值?
           if Assigned(IocpOnRecv) then IocpOnRecv(PerHandleData.Socket, PerIoData.DataBuf.buf, BytesTransferred);

           //--------------------------------------------------
          
           //当我们将数据处理完毕以后，应该将此套接字设置为结束状态，同时初始化和它绑定在一起的数据结构。
           ZeroMemory(@(PerIoData.Overlapped), sizeof(OVERLAPPED));
           PerIoData.BytesRECV := 0;
           Flags := 0;
           ZeroMemory(@(PerIoData.Overlapped), sizeof(OVERLAPPED));
           PerIoData.DataBuf.len := DATA_BUFSIZE;
           ZeroMemory(@PerIoData.Buf,sizeof(@PerIoData.Buf));
           PerIoData.DataBuf.buf := @PerIoData.Buf;

           //再次投递一个接收请求
//           if (WSARecv(PerHandleData.Socket, @(PerIoData.DataBuf), 1, @RecvBytes, @Flags,@(PerIoData.Overlapped), nil) = SOCKET_ERROR) then
//           begin
//             if (WSAGetLastError() <> ERROR_IO_PENDING) then
//             begin
//               if PerHandleData<>nil then
//               begin
//                 TempSc:=PerHandleData.Socket;
//                 //closesocket(PerHandleData.Socket);
//                 //GlobalFree(DWORD(PerHandleData));
//                 ClearSocket;
//               end;
//               if PerIoData<>nil then
//               begin
//                 //GlobalFree(DWORD(PerIoData));
//                 ClearIoData();
//               end;
//               continue;
//             end;
//           end;

           //投递失败的情况下应当也是不删除的 
           WSARecv(PerHandleData.Socket, @(PerIoData.DataBuf), 1, RecvBytes, Flags,@(PerIoData.Overlapped), nil);
         end
         //当我们判断出来接受的数据是我们发送出去的数据的时候，在这里我们清空我们申请的内存空间
         else
         begin
           //应当要判断一下是否发送完了,再决定是否删除//也可以不删除,让它们跟着 socket ,不过有可能 socket 删除了,这个还在触发事件
           PerIoData.BytesSEND := PerIoData.BytesSEND + BytesTransferred;

           //发送完毕了
           if PerIoData.BytesSEND >= PerIoData.BufLen then
           begin
             //这里是不能保证 PerHandleData 没有释放的,因为接收出错可能在前,那么这时候 PerHandleData.Socket 实际上是不可用的
             //其实可以把 PerHandleData.Socket 放到 PerIoData 中
             //if Assigned(IocpOnSend) then IocpOnSend(PerHandleData.Socket);
             if Assigned(IocpOnSend) then IocpOnSend(PerIoData.Socket);

             //GlobalFree(DWORD(PerIoData));
             ClearIoData();
             Continue;
           end;

           //移动缓冲位置(跳过已发送的数据)继续发送剩余的部分//另,接收部分没有必要多次,接收到多少报告上层调用者就行了,由上层决定是否继续接收
           PerIoData.DataBuf.buf := PerIoData.Buf + PerIoData.BytesSEND;
           PerIoData.DataBuf.len := PerIoData.BufLen - PerIoData.BytesSEND;

           Flags := 0;//有时候不一定是 0 ,要再赋值//可能是 delphi 初始化 bug ? 按道理 delphi 是会初始化变量的
           //WSASend(PerHandleData.Socket, @(PerIoData.DataBuf), 1{这个应该指的是缓冲结构的个数,固定为1}, @SendBytes, Flags, @(PerIoData.Overlapped), nil);
           WSASend(PerIoData.Socket, @(PerIoData.DataBuf), 1{这个应该指的是缓冲结构的个数,固定为1}, SendBytes, Flags, @(PerIoData.Overlapped), nil);
         end;
    end;

end;

//接受 socket 是需要线程的
procedure CreateThreadAccept;
var
  hThread:THandle;
  ThreadID:THandle;
begin

//  hThread := CreateThread(nil, 0, @ServerWorkerThread, Pointer(CompletionPort),0, ThreadID);
//  if (hThread = 0) then
//  begin
//      Exit;
//  end;
//  CloseHandle(hThread);

  //delphi 要用 BeginThread 代替 CreateThread
  //BeginThread(nil, 0, @ServerWorkerThread, Pointer(CompletionPort),0, ThreadID);

  IsMultiThread := TRUE;//用这个后也可以用 CreateThread
  hThread := CreateThread(nil, 0, @CreateServerThread, nil, 0, ThreadID);
  if (hThread = 0) then
  begin
      Exit;
  end;
  CloseHandle(hThread);
  
end;

end.
