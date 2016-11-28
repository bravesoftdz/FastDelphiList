unit iocpInterfaceClass;

//iocp �ĵ�����������.
//��װ�� delphi ���,��Ϊ������ delphi һЩ���еĶ���,�п��������½�һЩ.
//ע��:ԭʼ�� iocp �� socket �رպ���Ȼ�ᷢ�� "���ݷ������" �������¼�,���������ھ���ʲôʱ���ͷ���Դ
//Ϊ�������������Ӧ���������¼��з�����Դ,�ڹر��¼����ͷ���Դ,����֮�ⷢ�����¼��� iocp ʵ������˵�
//��ʵ����Ҫ��֤���Ӻ͹ر��¼�����ɶԳ���,����ֻ����һ��.

//�ڲ���Դ����/�ͷ�ԭ��:
//"��������ݽṹ"����յ�"��IO���ݽṹ"����һ������ֻ����һ��,����ͬʱ����ͬʱ�ͷ�
//�����õ�"��IO���ݽṹ"�Լ��ͷ�,�������¼��в�Ҫʹ�� "��������ݽṹ" �е�����,��Ҫ�õ��� socket ���
//ֱ��������ʱ����.�����Ϳ��Ա�����Դ�ͷŵĻ���.

// 2015/4/3 15:52:10 �ⲿ��������Ƚ϶�,��Ūһ��ͳһ�����İ汾�����γ������� indy �ĵ��߳����,�Ժ���Ҫ�����������л�

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  //winsock2,
  Winsock2_v2,
  //IdWinSock2,
  //WinSock,

  ComCtrls,Contnrs, iocpInterface, iocpRecvHelper, iocpSendHelper, uIocpTimerThread, 
  uThreadLock,
  //Contnrs,//TQueue ���ܲ���
  uFastQueue, fsHashMap,
  //uFastHashSocketQueue_v2,
  uFastHashSocketQueue_v3, // 2015/4/27 14:20:49 ���ÿɱ�����ʵ��
  Dialogs;

type
  TSocket = Cardinal;//u_int;//clq //c ����ԭ�����ȷ���޷��ŵ�//TSocket ����������//IdWinSock2 ������

type
  //���ӵ���
  TOnSocketConnectProc = procedure (Socket: TSocket; var OuterFlag:Integer{���ⲿ�������ӱ�־}) of object;
  //����һ�����
  TOnRecvProc = procedure (Socket: TSocket; buf:PChar; bufLen:Integer; OuterFlag:Integer) of object;

  //�� TOnRecvProc ��ͬ,�����Եõ�����ͨ�Ź����е���������,TOnRecvProc ��ֻ�ǵ�ǰ�յ��Ŀ�
  //���뷵�� useDataLen(�ڴ��¼�����/ʹ���˶���ֽڵ�����,iocp ����������ⲿ��,���� iocp �����ᱣ��̫��Ľ�������)
  TOnRecvDataProc = procedure (Socket: TSocket; buf:PChar; bufLen:Integer; OuterFlag:Integer; var useDataLen:Integer) of object;
  //����һ�����//����ղ�ͬ����,�����ȫ�����ͲŲ���һ���¼�
  TOnSendProc = procedure (Socket: TSocket; OuterFlag:Integer) of object;
  //����һ���ϲ�Ӧ�ð����//�� TOnSendProc ��ͬ����,�����һ���ϲ�Ӧ�ð�ȫ�����ͲŲ���һ���¼�
  //TOnSendOverProc = procedure (Socket: TSocket; OuterFlag:Integer) of object;
  //�رտͻ��� socket ʱ
  TOnSocketCloseProc = procedure (Socket: TSocket; OuterFlag:Integer) of object;


type
  TAcceptThread = class;
  TServerWorkerThread = class;
  TAcceptFastThread = class;
  TConnectClass = class;
  //TIocpTimerThread = class;

  //��װ iocp ����
  TIocpClass = class(TComponent)//(TObject)// 2015/4/14 9:03:17 Ϊ����ڴ�й©,�� TComponent �ȽϺ�
  private
    acceptThread:TAcceptThread;

    //workThread:TServerWorkerThread;
    //�����߳���ʵ�ж��
    workThread:array of TServerWorkerThread;

    acceptFastThread:TAcceptFastThread;

    //ģ�ⶨʱ���߳�
    timerThread:TIocpTimerThread;
    //�ϴμ���ʱ��
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
    acceptList:TFastQueue;//���յ� socket �б�

    socketList:TFastHashSocketQueue;//���ӵ� socket �����б�,ԭ��ֻ�����ж�ĳ�� socket �Ƿ��Ѿ��ͷ�
    //perIoDataList:THashMap;//��Ϊ�����뷢�͵� perIoData ������ͬʱ�ͷ�,���Ի�Ҫ������¼�����Ա�����ͷ�
    // 2015/6/30 9:12:03 �� FPerIoData �Ĺ���û�б�Ҫ����,��Ϊ����ÿ�������ǹ̶����� iodata ��ȫ�ǿɿص�.

    //--------------------------------------------------
    //�ϲ��� socketList//sendSocketList:TFastHashSocketQueue;//���ڷ��͵� socket �����б�,Ŀǰֻ�����ж�ĳ�� socket �Ƿ��ڷ���״̬,�������Ҫ�ȴ����ٷ���
    sendLock:TThreadLock;// 2015/4/14 11:45:49 ��������߳�ͬ���汾,��ʱ���ü�������

    //--------------------------------------------------

    OnRecv:TOnRecvProc;
    OnClose:TOnSocketCloseProc;
    OnSend:TOnSendProc;
    OnConnect:TOnSocketConnectProc;
    OnRecvData:TOnRecvDataProc;//�����¼�

    //����һ����ʱ�������¼�
    procedure AddOnTimerEvent(EventName:string; OnTimer:TOnIocpTimerProc; Interval:Cardinal);
    //CoInitialize, CoUninitialize �����ĺ����������߳���ʼ,��ֹʱΨһ����,����Ҫ���������ط�����ִ�д���
    procedure SetOnTimerEvent_ThreadFun(OnThreadBegin:TOnIocpTimerProc; OnThreadEnd:TOnIocpTimerProc);


    // 2015/5/7 11:03:26 ���ڴ����,�ⲿ��־��д���ڴ��,ֱ���� socket ��������//�����������������
    //function GetOuterFlag(Socket: TSocket):Integer;


    //�����¼��ĸ�����
    procedure DoConnect(Socket: TSocket; var OuterFlag:Integer); //virtual;
    procedure DoRecv(Socket: TSocket; buf:PChar; bufLen:Integer); //virtual;
    procedure DoSend(Socket: TSocket); //virtual;
    procedure DoClose(Socket: TSocket); //virtual;

    //���û���� iocp �б���Ĺر��¼�//ֻ���ڲ�����
    procedure CheckDoClose;

    procedure StartService();
    
    procedure StartOnTimerEvent();
    class procedure InitSock;

    //��ɶ˿ڷ���//���ݽӿ�
    //procedure SendData(Socket: TSocket; buf: PChar; bufLen: Integer; OuterFlag: Integer);

    //�̰߳�ȫ��ͬ������,�����߲���Ҫ����ͬ������,�򵥵�ֱ�ӵ��þ�����//������ģʽ��,�������߳��е�����Ҫ�Լ�����,���¼��е��ò���Ҫ
    procedure SendDataSafe(Socket: TSocket; buf: PChar; bufLen: Integer; User_OuterFlag: Integer);

    //������һ��,ֻ�����ڲ�����//����,������ IoDataGetNext ����
    //procedure SendDataSafe_Next(Socket: TSocket; OuterFlag: Integer);

    //ֻ�������ڲ�����//ȡ��һ��Ҫ���͵�����Ҫ��� io �ṹ//BytesTransferred �ǵ�ǰ���ͳɹ����ֽ���,��ʵ��Ŀǰ���㷨���� DATA_BUFSIZE
    function IoDataGetNext(PerIoData : LPPER_IO_OPERATION_DATA; BytesTransferred:Integer):Boolean;

    //--------------------------------------------------
    //�����Եĺ���

    //������ OnRecvData ȡ buf Ϊ�ַ���,��Ϊû�� #0 ��βֱ�ӽ� buf �����ַ����Ǻ�Σ�յ�
    function GetBufString_OnRecvData(buf: PChar; bufLen: Integer):string;

    //�� TIdUDPServer.ThreadedEvent ��ͬ,Ϊ true ʱ�¼����߳��д���,���ڸ�����Ҫ�󻷾�,��Ҫ���û��Լ����߳�ͬ��
    class procedure ThreadedEvent(EventInThread:Boolean);


    //--------------------------------------------------
    // 2015/4/14 9:02:12 Ϊ�˼���ڴ�й©���Ǽӹ��캯���ĺ�
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;


  end;


  //�����߳�
  TServerWorkerThread = class(TThread)
  private
    procedure Run;
    procedure ClearSocket(PerIoData: LPPER_IO_OPERATION_DATA; so: TSocket; connect:TConnectClass);

  private
    //--------------------------------------------------
    //DoOne �����õ�ͬ������
    BytesTransferred: DWORD;
    PerIoData : LPPER_IO_OPERATION_DATA;//�������Լ��õ���ʱ����
    bSleep:Boolean; // 2015/4/3 15:59:53 �Ƿ���ѭ���ȴ�һ��
    bGet:BOOL; //GetQueuedCompletionStatus �ķ���ֵ
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

    //����ͬ���¼�
  end;

  //���������� socket �߳�
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
    acceptList:TFastQueue;//���յ� socket �б�

    //������ socket ,�رճ���ʱҪ closesocket
    Listensc :Integer;
    //��ɶ˿ڵľ���ƺ�ҲҪ�ر�
    CompletionPort : THandle;

//    OnConnect_thread:TOnSocketConnectProc;

    //CompletionPort : THandle;
  end;

  //Ϊ�ӿ� accept �Ĺ���,�� TAcceptThread �������
  TAcceptFastThread = class(TThread)
  private
    function NewConnect(Socket: TSocket; var connect:TConnectClass; var oldConnect:TConnectClass):Boolean;
    procedure Run;

  private
    //--------------------------------------------------
    //DoOne �����õ�ͬ������

    Acceptsc:Integer;
    PerIoData : LPPER_IO_OPERATION_DATA;//�������Լ��õ���ʱ����

    //OuterFlag:Integer;
    haveSocket:Boolean;
    re:Boolean;
    bindErr:Boolean;
    newcon:TConnectClass;

    bSleep:Boolean; // 2015/4/3 15:59:53 �Ƿ���ѭ���ȴ�һ��

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
    acceptList:TFastQueue;//���յ� socket �б�
    //Listensc : THandle;//test

//    OnConnect_thread:TOnSocketConnectProc;

  end;


  //���ӹ�����,��Ϊ֮ǰ�ѽ������ֺͷ������ַֿ���Ȼ���ܺ�ǿ,��̫�����׹�����,����Ҫ���ȶ���// 2015/4/14 11:26:29
  TConnectClass = class(TObject)
  private

  public
    User_OuterFlag: Integer; //�û��¼���ı�־
    //Iocp_OuterFlag: Integer; //iocp ���ڲ�ʹ�õı�־,��ȥΪ TRecvHelp ���ھ��� TConnectClass ����//���ڲ�����,ֱ���� socket ����
    recvHelper:TRecvHelper;
    sendHelper:TSendHelper;

    iocpClass:TIocpClass;

    //debugTag:Integer; //���Ա�־

    //constructor Create; //override;
    constructor Create(iocp:TIocpClass); //override;
    destructor Destroy; override;

  end;


var
  g_IOCP_Synchronize_Event:Boolean = True; // 2015/4/3 8:46:06 �Ƿ�ʹ�� Synchronize �ķ�ʽ�����¼�����//���ڽ�������Ƚ϶��ʱʹ��;�Է���Ҫ��ǳ��ߵĵط�����

  g_IOCP_SendSize_test:Int64 = 0;// 2015/4/13 17:20:29 ���������ڴ�ռ�ö���
  g_IOCP_MemSize_test:Int64 = 0;// 2015/4/13 17:20:29 ����ȫ��������ڴ�ռ�ö���


//--------------------------------------------------
//�����Եĺ���

//������ OnRecvData ȡ buf Ϊ�ַ���,��Ϊû�� #0 ��βֱ�ӽ� buf �����ַ����Ǻ�Σ�յ�
function GetBufString(buf: PChar; bufLen: Integer):string;

//--------------------------------------------------
//ֻ��Ϊ�˵������Ĺرյ�
function closesocket(const s: TSocket): Integer; //stdcall;

implementation

uses
  uLogMemSta,
  uLogFile;


//ֻ��Ϊ�˵������Ĺرյ�
function closesocket(const s: TSocket): Integer; //stdcall;
begin
  //Result := Winsock2_v2.closesocket(s);
  Result := iocpInterface.closesocket(s);
end;


//uses uThreadLock;

//������ OnRecvData ȡ buf Ϊ�ַ���,��Ϊû�� #0 ��βֱ�ӽ� buf �����ַ����Ǻ�Σ�յ�
function GetBufString(buf: PChar; bufLen: Integer):string;
begin
  SetLength(Result, 0);//������ȫ��
  SetLength(Result, bufLen);
  CopyMemory(@Result[1], buf, bufLen);
end;



//��������
procedure TAcceptThread.CreateServer;
var
  i:Integer;
  Acceptsc:Integer;
  //PerHandleData : LPPER_HANDLE_DATA;//���Ӧ���ǿɸ��ĵ�
  sto:sockaddr_in;
  //Listensc :Integer;
  LocalSI:TSystemInfo;
  //CompletionPort : THandle;

  //thread:TServerWorkerThread;
  //OuterFlag:Integer;
  //threadFast:TAcceptFastThread;
  err:Integer;

begin

  TIocpClass.InitSock(); // 2015/5/7 9:24:07 ���ຯ������

  //����һ����ɶ˿ڡ�
  CompletionPort := CreateIOCompletionPort(INVALID_HANDLE_VALUE,0,0,0);

  //����CPU����������CPU*2�����Ĺ������̡߳�
  GetSystemInfo(LocalSI);

  SetLength(iocpClass.workThread, LocalSI.dwNumberOfProcessors * 2);

  //for i:=0 to LocalSI.dwNumberOfProcessors * 2 -1 do
  for i:=0 to Length(iocpClass.workThread) -1 do
  begin
      {
      //delphi Ҫ�� BeginThread ���� CreateThread
      //hThread := CreateThread(nil, 0, @ServerWorkerThread, Pointer(CompletionPort),0, ThreadID);
      //���,���ﲻ���� BeginThread,���� cpu ��ǳ���(���õ�ϸ�ڲ�ͬ,����,�� CreateThread ����)
      IsMultiThread := TRUE;//�������Ҳ������ CreateThread
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

      //��Щ���������ֱ�Ӹ�ֵ��Ҫ���� iocpClass,��������ȫ
      iocpClass.workThread[i].threadLock := iocpClass.threadLock;
      //iocpClass.workThread[i].OnRecv_thread     := iocpClass.DoRecv;//OnRecv;
      //iocpClass.workThread[i].OnClose_thread    := iocpClass.DoClose;//OnClose;
      //iocpClass.workThread[i].OnSend_thread     := iocpClass.DoSend;//OnSend;

      iocpClass.workThread[i].Resume;

  end;

  //--------------------------------------------------
  //���� accept �����߳�
  iocpClass.acceptFastThread := TAcceptFastThread.Create(True);
  iocpClass.acceptFastThread.CompletionPort := CompletionPort;
  iocpClass.acceptFastThread.iocpClass := Self.iocpClass;
  //iocpClass.acceptFastThread.Listensc := Listensc;//test,��������һ���߳���ʹ����

  //��Щ���������ֱ�Ӹ�ֵ��Ҫ���� iocpClass,��������ȫ
  iocpClass.acceptFastThread.threadLock := iocpClass.threadLock;
  iocpClass.acceptFastThread.acceptLock := iocpClass.acceptLock;
  iocpClass.acceptFastThread.acceptList := iocpClass.acceptList;
//  iocpClass.acceptFastThread.OnConnect_thread := iocpClass.DoConnect;//OnConnect;
  iocpClass.acceptFastThread.Resume;

  //--------------------------------------------------


  //����һ���׽��֣������׽��ֺ�һ���˿ڰ󶨲������˶˿ڡ�
  Listensc:=WSASocket(AF_INET,SOCK_STREAM,0,Nil,0,WSA_FLAG_OVERLAPPED);
  if Listensc=SOCKET_ERROR then
  begin
    MessageBox(0, PChar('�˿� ' + inttostr(iocpClass.ListenPort) + ' ����ʧ��[socketδ����]'), '����', 0);
    closesocket(Listensc);
    WSACleanup();
  end;
  sto.sin_family:=AF_INET;
  sto.sin_port := htons(iocpClass.ListenPort);//htons(5500);
  sto.sin_addr.s_addr:=htonl(INADDR_ANY);
  if bind(Listensc,@sto,sizeof(sto))=SOCKET_ERROR then
  begin
    MessageBox(0, PChar('�˿� ' + inttostr(iocpClass.ListenPort) + ' ����ʧ��'), '����', 0);
    closesocket(Listensc);
  end;
  //listen(Listensc,20);         SOMAXCONN
  //listen(Listensc, SOMAXCONN);
  //listen(Listensc, $7fffffff);//WinSock2.SOMAXCONN);

  if g_IOCP_Synchronize_Event = False then //������״̬
  listen(Listensc, WinSock2_v2.SOMAXCONN)
  else

  listen(Listensc, 1);//WinSock2.SOMAXCONN);// 2015/4/3 15:03:26 ̫��Ļ���ʵҲ���������,�ᵼ�³���ֹͣ��Ӧʱ�ͻ�����Ȼ����������,���Ҵ�����ռ��

  //--------------------------------------------------
  //while (TRUE) do
  while (not Self.Terminated) do
  begin
    LogFileMem('1');

    //���ͻ��������������ʱ��WSAAccept�������´���һ���׽���Acceptsc������׽��־��ǺͿͻ���ͨ�ŵ�ʱ��ʹ�õ��׽��֡�
    Acceptsc := WSAAccept(Listensc, nil, nil, nil, 0);

    SetNonBlock(Acceptsc);//����һ�·������ȽϺ�


    LogFileMem('2');


    //�ж�Acceptsc�׽��ִ����Ƿ�ɹ���������ɹ����˳���
    if (Acceptsc = SOCKET_ERROR) then
    begin
      err := WSAGetLastError();  //WSAENOTSOCK =10038 WSAEMFILE     ERROR_IO_PENDING
      LogFileMem('WSAGetLastError: ' + IntToStr(err)); //Ŀǰ�� xp �ϵĲ��Ի������� 10038
      //if (WSAGetLastError() <> ERROR_IO_PENDING) then

      //--------------------------------------------------
      // 2015/4/21 8:39:20 ��ʱ�� Listensc ���ܱ���ر���,Ҫ�ؽ�//���ؽ��Ļ��ڼ��������ĳЩ xp ϵͳ WSAAccept ��һֱ����
      closesocket(Listensc);
      Listensc:=WSASocket(AF_INET,SOCK_STREAM,0,Nil,0,WSA_FLAG_OVERLAPPED);
      if Listensc=SOCKET_ERROR then
      begin
        //closesocket(Listensc);
        LogFileMem('2 �ؽ� socket ʧ��');
      end;

      if bind(Listensc,@sto,sizeof(sto))=SOCKET_ERROR then
      begin
        LogFileMem('2 �ؽ� bind ʧ��');
        closesocket(Listensc);
      end;
      listen(Listensc, 1);

      //--------------------------------------------------

      Sleep(1);
      Continue;

      // 2015/4/7 14:03:50 ��һ��Ҫ�˳�,�п������ڴ���ʱ�Բ���
      //closesocket(Listensc);
      //exit;
    end;

    //--------------------------------------------------
    //��������̴߳��� onconnect �¼��Ļ���һ������,���� onconnect �¼��п��ܻ��� onrecv �¼�����//Ӧ��Ҳ����,��Ϊ CreateIoCompletionPort ��û����

    LogFileMem('3');

    try
      acceptLock.Lock('acceptLock.Lock');//�ܼ�,���� try ��// 2015/4/3 13:48:29  ����Ҫ��,��Ϊ lock �������쳣
      //acceptList.Write(Acceptsc);
      if acceptList.Write(Acceptsc) = False
      then closesocket(Acceptsc); // 2015/4/22 15:52:11 �����йر�,Ӧ�÷ǳ��ټ�
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

  //ģ�ⶨʱ���߳��ڴ���ʱ������,��Ϊ��Ҫ���¼�
  timerThread := TIocpTimerThread.Create(True);
  timerThread.iocpClass := Self;

  //perIoDataList := THashMap.Create();


  //�ڲ���ʱ����,��һ�������ɿ�,����ر������ɲ���Ҫ��һ���(�� 7.3 �ĵ�¼�������м��Ļ������������쳣,�������� iocp �������ڴ��ͷų�ͻ��)
  Self.AddOnTimerEvent('CheckDoClose', Self.CheckDoClose, 1*1000);//��ʱ���һ��δ�� iocp ��֪ͨ�Ĺر��¼�

end;

destructor TIocpClass.Destroy;
var
  i:Integer;
begin
  //�����߳�Ӧ�������ͷ�//�ƺ������ֶ��ͷŵĺ�

  //--------------------------------------------------

  //�����̻߳���Ҫ�ֹ��ر�
//  acceptThread := TAcceptThread.Create(True);
  acceptThread.Terminate;
  closesocket(acceptThread.Listensc);//���ر�,WSAAccept ��һֱ����
  //CloseHandle(acceptThread.CompletionPort);//��ɶ˿ڲ��������ر�,Ҫ���� PostQueuedCompletionStatus(m_hCompletionPort, 0, 0, NULL); ���(�뷢���߳���һ��)

  LogFile('acceptThread.WaitFor');
  acceptThread.WaitFor;
  acceptThread.Free;

  //�����߳��ж��
  for i:=0 to Length(self.workThread) -1 do
  begin
    workThread[i].Terminate;//PostQueuedCompletionStatus �Ľ����һ�������ڱ��߳���,����Ӧ��������һ��ѭ��ȫ���ر��̱߳�־��

    //PostQueuedCompletionStatus(m_hCompletionPort, 0, 0, NULL); ���(�뷢���߳���һ��)
    //PostQueuedCompletionStatus(acceptThread.CompletionPort, 0, 0, 0);
    PostQueuedCompletionStatus(self.workThread[i].CompletionPort, 0, 0, 0);
  end;

  for i:=0 to Length(self.workThread) -1 do
  begin
    //workThread[i].Terminate;//PostQueuedCompletionStatus �Ľ����һ�������ڱ��߳���,����Ӧ��������һ��ѭ��ȫ���ر��̱߳�־��

    //PostQueuedCompletionStatus(m_hCompletionPort, 0, 0, NULL); ���(�뷢���߳���һ��)
    //PostQueuedCompletionStatus(acceptThread.CompletionPort, 0, 0, 0);
    //PostQueuedCompletionStatus(self.workThread[i].CompletionPort, 0, 0, 0);

    //closesocket(acceptThread.Listensc);//���ر�,WSAAccept ��һֱ����
    LogFile('workThread[i].WaitFor');
    workThread[i].WaitFor;
    workThread[i].Free;

  end;

  //ģ�ⶨʱ���߳��ڴ���ʱ������,��Ϊ��Ҫ���¼�
  timerThread.Terminate;
  LogFile('timerThread.WaitFor');
  timerThread.WaitFor;
  timerThread.Free;


  //--------------------------------------------------
  //����ȹرս����߳��ٹر����
  acceptFastThread.Terminate;
  Self.acceptLock.TerminateInThread;//��Ҫ���˳��߳���
  Self.threadLock.TerminateInThread;
  LogFile('acceptFastThread.WaitFor');
  acceptFastThread.WaitFor;
  acceptFastThread.Free;


  acceptLock.Free;//������Ҫ�Լ��ͷ�
  threadLock.Free;

  //--------------------------------------------------
  //���ݽṹӦ����������ͷ�
  //Self.threadLock := TThreadLock.Create(Application);
  //acceptLock := TThreadLock.Create(Application);
//  acceptList := TFastQueue.Create(20000);//20000//��ʵ 2000 ���㹻��
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


//��������¶�û����Ӧ iocp �¼����ѶϿ����ӽ��в���
procedure TIocpClass.CheckDoClose;
var
  tmpcon:TConnectClass;
  tmp:Pointer;
  i:Integer;

  FPerIoData : LPPER_IO_OPERATION_DATA;
  TickCount:DWORD;
begin   //  Exit;//���,��ʹ����ĳ���ȴ���ʱ��Ȼ�п��������쳣//����Ӧ�ø�Ϊȷ�� socket �����ں� 1 ���Ӻ�ǿ�ƹر�
  TickCount := GetTickCount();

  if Abs(TickCount - lastCheckDoClose) < 10*1000 then Exit;

  lastCheckDoClose := TickCount;//GetTickCount();

  {$ifndef EXCEPT_DEBUG}//�����쳣�����������
  try
  {$endif}

      {
      //--------------------------------------------------
      //ȡ���ǵ� iocp data ������Ϊʲôiocpû����ر��¼�//��֪Ϊ��ʼ������,�п������ڴ��쳣�����?
      for i := 0 to (perIoDataList.Count)-1 do  //���ֻ�Ǽ���ڴ�й©�Ļ�,ÿ�δ�������������,ȫ�������Ļ� cpu ѹ��̫��//��ʵ�ʲ������� 10000 �������ڻ��ǲ�Ҫ����
      begin

        //��Ϊ��ɾ������,���Ի�Ҫ���ж�һ��//����������Ҫ����
        if i > perIoDataList.Count-1 then Exit;


        //FPerIoData := LPPER_IO_OPERATION_DATA(perIoDataList.Items[i]);
        FPerIoData := LPPER_IO_OPERATION_DATA(perIoDataList.Keys[i]);

        if Abs(TickCount - FPerIoData.TickCount)<60*1000 then Continue; //���������ʱ�䲻��1����,������


        if CheckPerIoDataComplete(FPerIoData) = True then
        begin
          FPerIoData.atWork := 888 //�����ܱ�����

          self.DoClose(FPerIoData.Socket);
          if tmpcon = nil then Self.ClearIoData(FPerIoData); //û�����ӵ�Ҫ�Լ�ɾ��


          closesocket(FPerIoData.Socket);

        end;



      end;
      }

  {$ifndef EXCEPT_DEBUG}//�����쳣�����������
  except//������ except ȥ���쳣,�����������ݽ��ղ���Ӧ
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

  {$ifndef EXCEPT_DEBUG}//�����쳣�����������
  try
  {$endif}
    //close �¼��Ƚ�����,�Ѿ�������//threadLock.Lock;//�߳�������,��������

    try
      //if socketList.GetItem(Socket, tmp) = False then
      if GetConnect(Socket, connect) = False then //û���������
      begin
        //if DebugHook<>0 then MessageBox(0, '�������ͷ�!', '�ڲ�����������', 0);//���������δ���Ӿ͹ر�ʱ�ܶ�
        Exit;
      end;

      //--------------------------------------------------
      if Assigned(OnClose) then OnClose(Socket, connect.User_OuterFlag);//������ free ǰ����
      //--------------------------------------------------


      //socketList.DeleteItem(Socket);//��¼
      DeleteConnect(Socket);

      LogFileMem('��ǰ������:' + IntToStr(self.socketList.Count) + ' '
        + '��ǰ������ debug_count:' + IntToStr(self.socketList.debug_count)
        );

      //--------------------------------------------------

    finally
    //close �¼��Ƚ�����,�Ѿ�������//  threadLock.UnLock;
    end;

  {$ifndef EXCEPT_DEBUG}//�����쳣�����������
  except//������ except ȥ���쳣,�����������ݽ��ղ���Ӧ
  end;
  {$endif}


end;



//�ͷ�һ������,��һ�� socket �����,ֻ�ڹر��¼���ʹ��
function TIocpClass.DeleteConnect(Socket: TSocket):Boolean;
var
  tmp:Pointer;
  oldcon:TConnectClass;
begin
  Result := True;

  if socketList.GetItem(Socket, tmp) then
  begin
    //LogFile('�ϴεĹرջ�δ���. ' + IntToStr(Socket));

    oldcon := tmp;
    oldcon.Free;//����ɾ��������,��Ϊ�������Ѿ�������,������ͻ��ڴ�й©

    socketList.DeleteItem(Socket);

  end;


end;


//����һ������,��һ�� socket �����,ֻ�������¼���ʹ��
function TIocpClass.SetConnect(Socket: TSocket; connect:TConnectClass):Boolean;
var
  tmp:Pointer;
  oldcon:TConnectClass;
begin
  Result := True;

  if socketList.GetItem(Socket, tmp) then
  begin
    LogFile('�ϴεĹرջ�δ���. ' + IntToStr(Socket));

    oldcon := tmp;
    oldcon.Free;//����ɾ��������,��Ϊ�������Ѿ�������,������ͻ��ڴ�й©

    socketList.DeleteItem(Socket); //// 2015/4/23 17:16:47 delphi �� hash ʵ�������������,������д��ʱһ��Ҫ�ж���ͬ�� socket �Ƿ���ֵ��,����ȡ����ֻ�ǵ�һ��ֵ����

  end;

  socketList.SetItem(Socket, connect);//��¼,Ҫ�ж�һ��ԭ�����Ƿ����,��������ظ����� socket �˻ᱨ����

end;

//��ȫ��ȡ��һ�� socket ,���Ƚ�ָ�����б���ȡ�õĽ���Ƿ�һ��
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


  //�¼��ж������⵫�� except �������½��Ƚ�����

  //�ر����� accept ���ֵ��ر�����,�ҵĻ������� 1000 ������ԭ����ȫ�����յ�����ֻ������ 600 ��,���� onconnet �¼��ﲻҪ�� except �쳣,�����û��¼���ҲҪ����ͨ��.


  {$ifndef EXCEPT_DEBUG}//�����쳣�����������
  try
  {$endif}

    try
      //threadLock.Lock('TIocpClass.DoConnect');//�߳�������,��������


      //--------------------------------------------------

      //Ӧ���ŵ�����ȥ,��Ϊ�¼���Ҳ���õ�����,����Ҫ���������ɺ󴥷��¼�//if Assigned(OnConnect) then OnConnect(Socket, OuterFlag);

      LogFile('debug 2: OnConnect(Socket, OuterFlag);');

      if Assigned(OnConnect) then OnConnect(Socket, OuterFlag);



    finally
      //threadLock.UnLock;
      //LogFile('debug 3: threadLock.UnLock;');
    end;
    LogFile('debug 4: end;');

  {$ifndef EXCEPT_DEBUG}//�����쳣�����������
  except//������ except ȥ���쳣,�����������ݽ��ղ���Ӧ
  end;
  {$endif}

end;

procedure TIocpClass.DoRecv(Socket: TSocket; buf: PChar; bufLen: Integer);
var
  //helper:TRecvHelper;
  connect:TConnectClass;
  useDataLen:Integer;

begin

  {$ifndef EXCEPT_DEBUG}//�����쳣�����������
  try
  {$endif}

    try
      //threadLock.Lock('TIocpClass.DoRecv');//�߳�������,��������

      //connect := connect(OuterFlag);
      if GetConnect(Socket, connect) = False then //û���������
      begin
        //MessageBox(0, '�������ͷ�!', '�ڲ�����������', 0);//���������δ���Ӿ͹ر�ʱ�ܶ�
        Exit;
      end;
      

      //OuterFlag := connect.User_OuterFlag;//�ָ�ռ�õ��ⲿ��ʶ

      //����������,�ᵼ�º����recv������ iocp �¼�,��һ�¿��������ڴ�Խ���
      if Assigned(OnRecv) then OnRecv(Socket, buf, bufLen, connect.User_OuterFlag);

      connect.recvHelper.OnRecv(Socket, buf, bufLen);

      useDataLen := 0;
      //ע�����ﴫ��ȫ������
      if Assigned(OnRecvData)
      then OnRecvData(Socket, connect.recvHelper.FMemory.Memory, connect.recvHelper.FMemory.Size, connect.User_OuterFlag, useDataLen)
      else useDataLen := bufLen;//û���û��¼��Ļ���ȫ������������

      //TRecvHelper.ClearData(helper, 2);//test
      //����û����¼��д������˵�����
      TRecvHelper.ClearData(connect.recvHelper, useDataLen);



    finally
      //threadLock.UnLock;
    end;

  {$ifndef EXCEPT_DEBUG}//�����쳣�����������
  except//������ except ȥ���쳣,�����������ݽ��ղ���Ӧ
  end;
  {$endif}



end;

procedure TIocpClass.DoSend(Socket: TSocket);
var
  //helper:TRecvHelper;
  connect:TConnectClass;
  tmp:Pointer;
begin

  {$ifndef EXCEPT_DEBUG}//�����쳣�����������
  try
  {$endif}

    try
      //threadLock.Lock('TIocpClass.DoSend');//�߳�������,��������

      //����Ѿ��ͷ��˾Ͳ�Ҫ�ٴ����¼����ϲ���
      if GetConnect(Socket, connect) = False then //û���������
      begin
        //MessageBox(0, '�������ͷ�!', '�ڲ�����������', 0);//���������δ���Ӿ͹ر�ʱ�ܶ�
        Exit;
      end;
      

      if Assigned(OnSend) then OnSend(Socket, connect.User_OuterFlag);

    finally
      //threadLock.UnLock;
    end;

  {$ifndef EXCEPT_DEBUG}//�����쳣�����������
  except//������ except ȥ���쳣,�����������ݽ��ղ���Ӧ
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
    if so <> PerIoData.Socket then MessageBox(0, ' socket ��Ӧ����', '', 0); //�п�����

    PerIoData.debugtag := 4;

    //���͵���ɾ����־
    if (PerIoData.OpCode = 1)and(connect <> nil) then connect.sendHelper.PerIoData_IsFree := True;
    //���յ���ɾ����־
    if (PerIoData.OpCode = 0)and(connect <> nil) then connect.recvHelper.PerIoData_IsFree := True;

    iocpClass.ClearIoData(PerIoData);//IocpFree(PerIoData, 200); // 2015/6/1 11:24:46 ���λ�� iodata ��һ������ɾ����,���Һ���� DoClose ���и��ӵ��߼�,������������ɾ������

  end;

  //GlobalFree(DWORD(PerHandleData));
  iocpClass.DoClose(so); //��У���,��������Ҳ��Ҫ��,���� PerIoData һ���Ǳ������ƻ���,��������˾Ͳ�Ҫ���ߺ����������
  closesocket(so); //��һ��,����ǹرյĴ�������������,�����Ժ���÷ŵ� DoClose ��,������ɱ
  //Winsock2_v2.closesocket(so);
  Exit;



end;

procedure TIocpClass.ClearIoData(PerIoData: LPPER_IO_OPERATION_DATA);//���� GlobalFree(DWORD(PerIoData));
begin
  PerIoData.debugtag := 6;


  // 2015/5/11 9:24:55 ������������ͳһ����,ֻ�е������಻����ʱ(�����йر�)����Ҫ�Լ��ͷ�
  //if PerIoData.ConFree = 1 then
  begin
    //self.perIoDataList.Remove(Integer(PerIoData));//�����ɵ� periodata ����¼����
    IocpFree(PerIoData, 2);

  end;

end;



//--------------------------------------------------

//�����߳�//��һ����������ô֪�����е� PerIoData �� PerHandleData ����ȷ�ͷŶ�û���ڴ�й©��
procedure TServerWorkerThread.Run;//CompletionPortID:Pointer):Integer;stdcall;
var
//  BytesTransferred: DWORD;
//  PerIoData : LPPER_IO_OPERATION_DATA;//�������Լ��õ���ʱ����
//  bSleep:Boolean; // 2015/4/3 15:59:53 �Ƿ���ѭ���ȴ�һ��
//  bGet:BOOL; //GetQueuedCompletionStatus �ķ���ֵ
//  lpCompletionKey: DWORD;
//  connect:TConnectClass;

//GetQueuedCompletionStatus �漰���Ķ�Ӧ������ʱ����,ȡ�����ڼ������ٸ�ֵ
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
    //�õ������߳��Ǵ��ݹ�����IOCP
    //while(True) do
    while (not Self.Terminated) do // 2015/4/14 9:28:57
    begin

      if bSleep then
      begin
        Sleep(1);
        bSleep := False;
      end;

      //--------------------------------------------------
      //PerHandleData.IsFree := 3;//test GetQueuedCompletionStatus ʧ�ܵ�ʱ�������Ч�� PerHandleData ֵ?(ȷʵ���,���ᱣ�� PerHandleData ������ֵ����)
      //PerHandleData := nil;//test GetQueuedCompletionStatus ʧ�ܵ�ʱ�������Ч�� PerHandleData ֵ?(ȷʵ���,���ᱣ�� PerHandleData ������ֵ����)
      //lpCompletionKey := INVALID_SOCKET;// 0;
      //PerIoData := nil;
      F_lpCompletionKey := INVALID_SOCKET;// 0;
      F_PerIoData := nil;

      //�������̻߳�ֹͣ��GetQueuedCompletionStatus��������ֱ�����ܵ�����Ϊֹ
      //if (GetQueuedCompletionStatus(CompletionPort, BytesTransferred, DWORD(PerHandleData), POverlapped(PerIoData), INFINITE) = False) then
      //bGet := GetQueuedCompletionStatus(CompletionPort, BytesTransferred, DWORD(PerHandleData), POverlapped(PerIoData), INFINITE);
      //bGet := GetQueuedCompletionStatus(CompletionPort, BytesTransferred, lpCompletionKey, POverlapped(PerIoData), INFINITE);
      F_bGet := GetQueuedCompletionStatus(CompletionPort, F_BytesTransferred, F_lpCompletionKey, POverlapped(F_PerIoData), INFINITE);

      //if F_PerIoData<>nil then F_PerIoData.atWork := -1;

      if Self.Terminated then Exit;//������ PostQueuedCompletionStatus �����

      //if F_bGet = False then MessageBox(0, 'F_bGet = False', '',0); //��Ѹ������һ�� 4m ���ļ���Ȼ�ͻ�ܶ�

      //--------------------------------------------------
      if F_bGet = False then
      begin
        if FALSE = WSAGetOverlappedResult(CompletionPort,
          @F_PerIoData.Overlapped, @F_BytesTransferred, false{False,΢������ false}{�Ƿ�ȴ�������ص���������}, @__dwFlags) then//����ԭ��
        begin
          __err := WSAGetLastError();
          LogFile('CheckPerIoDataComplete :' + IntToStr(__err));

          if WSAENOTSOCK = __err then
          begin
            //��Ŀǰ����,�����⵽ socket �Ѿ���������,�����ж��������,������������������

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

        if F_PerIoData<>nil then F_PerIoData.atWork := -1; // 2015/6/29 14:47:12 Ӧ���ŵ�����,��Ϊ���ж����ֵ�����ٵĴ���

        //--------------------------------------------------
        //GetQueuedCompletionStatus ����ʱ��������
        Self.PerIoData        := F_PerIoData        ;
        Self.bGet             := F_bGet             ;
        Self.BytesTransferred := F_BytesTransferred ;
        Self.lpCompletionKey  := F_lpCompletionKey  ;

        //--------------------------------------------------

        //if (F_PerIoData<>nil)and(F_PerIoData.atWork <> -1)
        //then MessageBox(0, pchar(' <>-1: ' + inttostr(F_PerIoData.atWork)),'',0);//ȡ������û����ʱ�������ĵط�������

        if g_IOCP_Synchronize_Event
        then Synchronize(DoOne)
        else DoOne();


        Continue;// 2015/5/14 14:51:38  test

      finally
        threadLock.UnLock();
      end;
    end;

end;


//ȡ��һ������Ĵ���,Ҫ�����߳��к�������ͬ����ɵ�
procedure TServerWorkerThread.DoOne;
begin

    //���������Ǵ�����õ���
    //bGet := GetQueuedCompletionStatus(CompletionPort, BytesTransferred, lpCompletionKey, POverlapped(PerIoData), INFINITE);

    if PerIoData = nil then
    begin
      if DebugHook<>0 then MessageBox(0, 'PerIoData == nil', '', 0); //����ʱ��ʾһ��
      bSleep := True;
      Exit;//Continue;
      //��� PerIoData Ϊ�ո���û�б�Ҫ������,��Ϊ���ﲻ���ܵ�,�����ǳ�����//�˳�����ʱ���ֹ�
    end;

    //����жϺ���Ҫ
    //if iocpClass.perIoDataList.ValueOf(Integer(PerIoData)) = -1 then Exit; //����ṹ�Ѿ�������,������Ұָ��
    if IocpCheck(PerIoData) = False then Exit; //����ṹ�Ѿ�������,������Ұָ��



    //���ճɹ�����Ȼ��������¼�//if PerIoData.debugtag = 111 then MessageBox(0, 'debugtag == 111', '', 0); //����ʱ��ʾһ��
    PerIoData.first := 1;

    PerIoData.atWork := 0; //�ȴ�һ���˳� iocp �����̵߳ı��//��ʱ�� PerIoData �Ѿ����ǿ���

    //��������ȡ��Ӧ PerIoData �� lpCompletionKey ������,��������Լ������Ӳ����˲���Ҫ�Լ��ͷ�
    //���Ӳ��ϵ��жϳ��˶������Ҳ�������,�ҵ��������Ҳ�п����������� socket �ŵ�,���Ի�Ҫ�ж� PerIoData �� ���ӵĽ��ջ��߷�������ָ���Ƿ���ͬ
    //��ͬ�������Ҳ��Ҫ�Լ��ͷ�,��Ϊ�Լ�Ӧ�����ϴ� socket ������

    //ȡ����,����Ҫ��Ҫ�Լ��ͷ�
    if iocpClass.GetConnect(PerIoData.Socket, connect) = False then //û���������
    begin
      //����ڵ�¼������ѹ�������зǳ���//if DebugHook<>0 then MessageBox(0, '�������ͷ�! TServerWorkerThread.DoOne', '�ڲ�����������', 0);//�Լ������Ӳ�����,��Ҫ�ͷ�

      iocpClass.ClearIoData(PerIoData);

      bSleep := True;
      Exit;//Continue;
    end;

    if (connect.sendHelper.FPerIoData <> PerIoData)and(connect.recvHelper.FPerIoData <> PerIoData) then
    begin
      //MessageBox �����е����ݲ������Լ�Ҳ��Ҫ�ͷŵ�//��������ʱ���Ҳ�ܶ�
      //if DebugHook<>0 then MessageBox(0, '�����е����ݲ������Լ�Ҳ��Ҫ�ͷŵ�', '�ڲ�����������', 0);//�Լ������Ӳ�����,��Ҫ�ͷ�

      iocpClass.ClearIoData(PerIoData);

      bSleep := True;
      Exit;//Continue;
    end;

    //if PerIoData.ConFree = 1
    //then IocpFree(PerIoData, 2);

    //���ҵ��Լ����ӵĶ������ͷ�,��Ϊ�ر�����ʱ��һ���ͷŵ�

    //bGet := GetQueuedCompletionStatus ...
    if (bGet = False) then
    begin
      //���ͻ������ӶϿ����߿ͻ��˵���closesocket������ʱ��,����GetQueuedCompletionStatus�᷵�ش���������Ǽ���������������Ϳ������ж��׽����Ƿ���Ȼ�����ӡ�
      //���ú����Ĳ�������ʱҲ�ᵽ����,����Ͳ��ù���,�ر� socket ����
      ClearSocket(PerIoData, lpCompletionKey, connect);

      bSleep := True;
      Exit;//continue;
    end;


    //--------------------------------------------------
    //���ͻ��˵���shutdown���������ݶϿ���ʱ�����ǿ�����������д�����
//    if (BytesTransferred = 0) then
    if (BytesTransferred <= 0) then //΢���ĵ�����С�� 0 Ҳͬ������,��֪�Ƿ���Ӱ��
    begin
//            shutdown(lpCompletionKey, 1);
      ClearSocket(PerIoData, lpCompletionKey, connect);

      Exit;//continue;
    end;

    //--------------------------------------------------
    //����ſ�ʼ�����Ĵ���
    //����һƪ������˵��IOCP���Խ������Կͻ��˵����ݺ��Լ����ͳ�ȥ�����ݣ��������ݵ������������Ƕ���Ľṹ��Ա...

    //���ǽ������Կͻ��˵������ǣ����ǽ������ݵĴ�����
    if (PerIoData.OpCode = 0) then
    begin
      //�û��¼�
      iocpClass.DoRecv(PerIoData.Socket, PerIoData.BufInfo.buf, BytesTransferred);
      //--------------------------------------------------

      //�����ǽ����ݴ�������Ժ�Ӧ�ý����׽�������Ϊ����״̬��ͬʱ��ʼ����������һ������ݽṹ��
      ZeroMemory(@PerIoData.Overlapped, sizeof(OVERLAPPED));
      PerIoData.BufInfo.len := DATA_BUFSIZE;
      ZeroMemory(@PerIoData.Buf, sizeof(PerIoData.Buf));
      PerIoData.BufInfo.buf := @PerIoData.Buf;

      //�ٴ�Ͷ��һ����������
      //if (WSARecv(PerIoData.Socket, @PerIoData.BufInfo, 1, tmpRecvBytes, Flags, @PerIoData.Overlapped, nil) = SOCKET_ERROR) then
      if iocpInterface.RecvBuf(PerIoData.Socket, PerIoData) = False then
      begin
        ClearSocket(PerIoData, lpCompletionKey, connect); //������ֹ����ùر��¼�
        //IocpFree(PerIoData);//ClearIoData(PerIoData);//ʧ�ܵĻ���Ҫ�Լ��ͷŵ�//ͳһ�������д���
        Exit;//continue;
      end;
      PerIoData.debugtag := 222;

    end
    //--------------------------------------------------
    //**************************************************
    //--------------------------------------------------
    //�������жϳ������ܵ����������Ƿ��ͳ�ȥ�����ݵ�ʱ�������������������������ڴ�ռ�
    else//���͵����
    begin
      g_IOCP_SendSize_test := g_IOCP_SendSize_test - BytesTransferred; // 2015/4/13 17:28:54 test

      //ȡ��һ��������
      if iocpClass.IoDataGetNext(PerIoData, BytesTransferred) = True then
      begin
        //WSASend(PerIoData.Socket, @PerIoData.BufInfo, 1{���Ӧ��ָ���ǻ���ṹ�ĸ���,�̶�Ϊ1}, tmpSendBytes, Flags, @(PerIoData.Overlapped), nil);
        iocpInterface.SendBuf(PerIoData.Socket, PerIoData);

      end
      else//ȫ�����ͳɹ���
      begin
        // 2015/4/3 11:01:27 �û��¼�//��Ƭ���ŵ��ǿ���֪����һ�鷢�ͳɹ���,����ʵ�ʵ���������û�������Ҫ����,ֻ�ܷ��;�����
        //Ŀǰ��˵ֻ�� http �������Ҫ֪���Ѿ��������,Ȼ��ر� socket

        //if Assigned(OnSend_thread) then OnSend_thread(PerIoData.Socket, PerIoData.OuterFlag);
        iocpClass.DoSend(PerIoData.Socket);

        //��ʱ�����ֱ�ӷ�����һ������
        connect.sendHelper.atSend := False;

      end;//�Ƿ��а�����


    end;//�Ƿ��Ͱ�


end;


{ TServerWorkerThread }

procedure TServerWorkerThread.Execute;
begin
  inherited;

  if DebugHook=0 then //����ʱ������ except ,����ʱ�þͿ���������ص���
  begin

    {$ifndef EXCEPT_DEBUG}//�����쳣�����������
    try
    {$endif}

      Run();
      Exit;

    {$ifndef EXCEPT_DEBUG}//�����쳣�����������
    except//������ except ȥ���쳣,�����������ݽ��ղ���Ӧ
      MessageBox(0, 'TServerWorkerThread.Execute ���˳�.', '', 0);
    end;
    {$endif}
  end;  

  try

    Run;
  finally
    LogFileMem('TServerWorkerThread.Execute ���˳�.');

  end;

  LogFile('TServerWorkerThread.Execute ���˳�.');//��¼��,�Ƿ��쳣�˳�

end;


{ TCreateServerThread }

procedure TAcceptThread.Execute;
begin
  inherited;

  try

    CreateServer;
  finally
    LogFileMem('TAcceptThread.Execute ���˳�.');
  end;

  LogFile('TAcceptThread.Execute ���˳�.');//��¼��,�Ƿ��쳣�˳�


end;

{ TIocpClass }

//procedure TIocpClass.SendData(Socket: TSocket; buf: PChar; bufLen: Integer; OuterFlag: Integer);
//begin
//  iocpSendHelper.SendData(Socket, buf, bufLen, OuterFlag);
//
//end;


//�̰߳�ȫ��ͬ������,�����߲���Ҫ����ͬ������,�򵥵�ֱ�ӵ��þ�����
procedure TIocpClass.SendDataSafe_NoLock(Socket: TSocket; buf: PChar; bufLen:Integer);
var
  helper:TSendHelper;
  PerIoData: LPPER_IO_OPERATION_DATA;
  connect:TConnectClass;
begin
  // 2015/4/14 13:13:06 ע��,��������û�м�����,���Բ������߳��е���//��Ϊ�¼���������Ŵ�����,�������¼��п��԰�ȫ��ʹ��

  try
    sendLock.Lock('TIocpClass.SendDataSafe');

    if GetConnect(Socket, connect) = False then Exit; //û���������

    g_IOCP_SendSize_test := g_IOCP_SendSize_test + bufLen;// 2015/4/13 17:26:20 test

    helper := nil;

    helper := connect.sendHelper;

    //���ӵ����ͻ�����
    helper.AddSendBuf(buf, buflen);

    if (helper.isBindIocp = True)and(helper.atSend = False) then  // 2015/5/8 16:51:51 ��Ӹ��� iocp ����ܷ���,��Ϊ���󶨵Ļ��޷����¼��д���,����Ч��δ֪
    begin//û�����ڷ��͵Ļ�,����
      //helper.atSend := True;
      helper.DoSendBuf(Socket);
      //SendData(Socket, buf, bufLen, connect.Iocp_OuterFlag);//��Ϊ�����������������,���Բ��÷��ڻ�����
    end;


  finally
    sendLock.UnLock;
  end;

end;

//�̰߳�ȫ��ͬ������,�����߲���Ҫ����ͬ������,�򵥵�ֱ�ӵ��þ�����
procedure TIocpClass.SendDataSafe(Socket: TSocket; buf: PChar; bufLen,
  User_OuterFlag: Integer);
begin

  //���ݲ�ͬ������ģʽ������//�߳�ģʽ�²�������,��Ϊ�������߳��м��������õ�,���߳�ģʽ�²������������е���.ԭ���ǿ��Ե�,�����ڼ�����������Ҫ��Ҫ��
  if g_IOCP_Synchronize_Event = False then
  begin
    SendDataSafe_NoLock(Socket, buf, bufLen);

    Exit;
  end;

  //�ж��Ƿ������߳���,�����
  if (GetWindowThreadProcessId(Application.Handle, nil) = GetCurrentThreadId) then
    SendDataSafe_NoLock(Socket, buf, bufLen)
  else MessageBox(0, '�����������е���', '', 0);  



end;


//ȡ��һ��Ҫ���͵�����Ҫ��� io �ṹ//BytesTransferred �ǵ�ǰ���ͳɹ����ֽ���,��ʵ��Ŀǰ���㷨���� DATA_BUFSIZE
function TIocpClass.IoDataGetNext(PerIoData : LPPER_IO_OPERATION_DATA; BytesTransferred:Integer):Boolean;
var
  sendHelper:TSendHelper;
  //PerIoData: LPPER_IO_OPERATION_DATA;
  con:TConnectClass;
begin
  if GetConnect(PerIoData.Socket, con) = False then Exit; //û���������

  Result := con.sendHelper.IoDataGetNext(PerIoData, BytesTransferred);


end;


procedure TIocpClass.StartService;
//var
//  thread:TAcceptThread;

begin
  //Self.threadLock := TThreadLock.Create(Application);// 2015/4/14 10:41:06 ������Ҫ�Լ��ͷ�
  Self.threadLock := TThreadLock.Create(nil);// 2015/4/14 10:41:06 ������Ҫ�Լ��ͷ�
  //acceptLock := TThreadLock.Create(Application);
  acceptLock := TThreadLock.Create(nil);// 2015/4/14 10:41:06 ������Ҫ�Լ��ͷ�
  acceptList := TFastQueue.Create(20000);//20000//��ʵ 2000 ���㹻��
  socketList := TFastHashSocketQueue.Create();
  //ckeyList := TFastHashSocketQueue.Create();
  //Count := 0;
  //Count2 := 0;

  //sendDataList := TList.Create;
//  sendSocketList := TFastHashSocketQueue.Create();
  //sendLock := TThreadLock.Create(Application);
  sendLock := TThreadLock.Create(nil);//�Լ��ͷź���


  acceptThread := TAcceptThread.Create(True);
  acceptThread.iocpClass := Self;

  //��Щ���������ֱ�Ӹ�ֵ��Ҫ���� iocpClass,��������ȫ
  acceptThread.threadLock := Self.threadLock;
  acceptThread.acceptLock := Self.acceptLock;
  acceptThread.acceptList := Self.acceptList;
//  acceptThread.OnConnect_thread := Self.DoConnect;//OnConnect;
  acceptThread.Resume;

  //--------------------------------------------------
  //timerThread.Resume;// 2015/6/10 9:35:48 �ĳ��ֹ������źÿ���


end;


procedure TIocpClass.StartOnTimerEvent;
begin

  timerThread.Resume;// 2015/6/10 9:35:48 �ĳ��ֹ������źÿ���


end;

{ TAcceptFastThread }

//--------------------------------------------------

//���������ɷǳ����ӻ���Ӧ����������,Ҳ��Ҫ�� iocp �����н���,��Ϊ�������߼�����
function TAcceptFastThread.NewConnect(Socket: TSocket; var connect:TConnectClass; var oldConnect:TConnectClass):Boolean;
var
  //helper:TRecvHelper;
  //sendHelper:TSendHelper;
  PerIoData : LPPER_IO_OPERATION_DATA;
  tmp:Pointer;
  oldcon:TConnectClass;//ԭ����� socket �Ŷ�Ӧ��������
  newcon:TConnectClass;//Ҫ���µ�������
  OuterFlag: Integer;

begin

  Result := False;
  connect := nil;

    //if iocpClass.GetConnect(Socket, OuterFlag, oldcon) then
    if iocpClass.socketList.GetItem(Socket, tmp) then
    begin
      oldConnect := tmp;
      //oldcon.ClearSendData; //�����ڷ��͵Ļ�
      //����о����ӵĻ�Ӧ���˳�,����ǽ��������ӻ��г�ʱ�жϹ��̽���ȥ��,�������ֻ�ᷢ����һ�����ӱ�Ѹ�ٹرյ������
      //��Ϊ����кܶ�������������ӵ�������
      LogFile('TAcceptFastThread.NewConnect ����socket��ռ��');
      Exit;
    end;

    //--------------------------------------------------

    //Ӧ���ŵ�����ȥ,��Ϊ�¼���Ҳ���õ�����,����Ҫ���������ɺ󴥷��¼�//if Assigned(OnConnect) then OnConnect(Socket, OuterFlag);
    newcon := TConnectClass.Create(iocpClass);

    //�����������ٴ����¼�,��Ϊ�¼�ҲҪ�����Ӷ���
    iocpClass.SetConnect(Socket, newcon);

    //�����¼�ȥȡ���û��ı�־//�����ټ�ͬ��
    //OuterFlag := 0;
    //iocpClass.DoConnect(Socket, OuterFlag);

    //--------------------------------------------------
    OuterFlag := 0;//clq // 2015/4/2 13:29:32 �����ʼ��һ�±ȽϺ�

    iocpClass.DoConnect(Socket, OuterFlag);


    //--------------------------------------------------

    newcon.User_OuterFlag := OuterFlag;//����һ���޸Ĺ���,����Ҫ���¸�ֵ

    //newcon.Iocp_OuterFlag := Integer(newcon);


  connect := newcon;
  Result := True;
end;


procedure TAcceptFastThread.DoOne;
var
  oldcon:TConnectClass;
begin


    if Self.Terminated then exit; // 2015/4/14 10:20:53 �п����ǹر������

    //���ʱ�� Acceptsc �п������Ѿ����ر��˵�
    if Self.NewConnect(Acceptsc, newcon, oldcon) = False then
    begin
      bSleep := True;

      iocpClass.DoClose(Acceptsc); //Ŀǰ���߼��п���ǰ��ĵò����ر��¼�,�����ٹر�һ��.��Ϊ�����ӹ���,��������ظ������ǲ�Ҫ����
      //���� iocp ��ʱ�Ͽ����ʱ���Բ���������,��Ϊ���������ֹ��ر���,��û���ж��Ƿ��� iocp ���ж�������
      //����ʱ�ǳ���//if DebugHook<>0 then MessageBox(0, 'PerIoData == nil', '', 0); //����ʱ��ʾһ��

      closesocket(Acceptsc);//�о�����Ӧ���ر�,������Ϊ������
      //Winsock2_v2.closesocket(Acceptsc);//��������

      LogFile('�ϴεĹرջ�δ���. ' + IntToStr(Acceptsc), False);//�������̫��̫���������ǿ��ܵ�,��Ϊ���رյ��Ǹ��ֱ�������
      Exit;//Continue;
    end;

    //--------------------------------------------------

    //�û��¼�,�����Ҫ�û��ᴫ��һ���ⲿ��ʶ

    //�����ȴ��� connect �¼�,��Ϊ�кܶ��ʼ������Ҫ��

    //�����ʱ��ͻ��˹ر� socket �Ļ��ǲ��ᴥ�� iocp �¼���,����ô֪���Է��ر�����?//Ŷ,��ʱ����ʾʧ�ܵ�

    //--------------------------------------------------
    //ԭ��������ʧ�ܹ���̫������,��ȷ�Ĳ���Ӧ����:
    //1.�󶨺�Ž���. �󶨺��Ǳ���ӽ��ն�����,���� iocp �����̲߳��ᴥ��,���ǶԷ��ȷ�����.
    //2.��ʧ��, iocp �������ǲ����ܴ�����,����Ҫ�ֹ����������Դ,ͬʱ�ֹ������ر��¼�.
    //3.�󶨺�ĵ�һ������ʧ����ô����,��ǰ��ͬ���ֹ������ر��¼�,����������˵ֻҪ�ر� socket ������,
    //  ��Ϊ��ɶ˿��ǳɹ����˵�,�ر��¼�Ӧ������,����û��Ҳ��������Ϊ����Ӧ�����,
    //  �����ñ�ķ��������ڴ�,�����¼���е� socket ����������ô����Ҫ�������޸���Щ������
    //  ��Ϊȥ�²� iocp �Ĵ��������ǲ���ȡ,Ӧ������Ϊ����������������,Ȼ������������Դ�����������̾�����

    //����һ������������ݽṹ����Acceptsc�׽��ְ󶨡�
    //PerHandleData := nil; //����һ�±ȽϺ�
    CompletionKey := INVALID_SOCKET;//����һ�±ȽϺ�

    CompletionKey := Acceptsc;



    //���׽��֡���ɶ˿ں͡���������ݽṹ�����߰���һ��//ע��,������ʵ���Ǵ������ǰѽ��յ��� socket ���Ѿ������õ���ɶ˿ھ����
    bindErr := False;
    //if (CreateIoCompletionPort(Acceptsc, CompletionPort, DWORD(PerHandleData), 0) = 0) then
    if (CreateIoCompletionPort(Acceptsc, CompletionPort, CompletionKey, 0) = 0) then
    begin
      bSleep := True;

      LogFile('��ɶ˿ڰ�ʧ��.' + SysErrorMessage(GetLastError()));//"��������ȷ" ��ʱ�����ظ�����һ���˿�
      //��ʱ�� Acceptsc �ǿ����Ѿ����ر��˵�
      //closesocket(Acceptsc);//Continue;//��ǰ���رմ���,ʵ���ϲ���,���ⲿ�ӳ�ʱ�����жϻᴦ����
      closesocket(Acceptsc);//Continue;//��Ϊû�а�,���Թر�Ҳ�ǿ��Ե�,��Ϊ��ɶ˿ڵ��¼��ǲ��ᴥ����
      //Winsock2_v2.closesocket(Acceptsc);

      bindErr := True;

      //MessageBox(0, '��ɶ˿ڰ�ʧ��', '�������ڲ�����', 0);
      //MessageBox(0, PChar('��ɶ˿ڰ�ʧ��.' + SysErrorMessage(GetLastError())), '�������ڲ�����', 0);
      //exit;

      //��Ϊ��ʱ�Ѿ����������¼���,����Ҫ�ֹ������ر�
      iocpClass.DoClose(Acceptsc);

      Exit;//Continue;
    end;

    //�󶨳ɹ�����ܷ�����,����������Ȼ�ܷ���ȥ�� iocp �¼��ǲ��ᴥ����,���Ժ��滹Ҫ��һ�����͵Ķ���

    //Continue;// test �����ջᴥ���ر���? ȷʵ����

    //��ʼ��������
    PerIoData := nil;//����һ��

    re := iocpInterface.RecvBuf(Acceptsc, newcon.recvHelper.GetIoData(Acceptsc));

    // 2013-3-7 15:29:31 Ŀǰ��Ϊ�ǰ�ʧ�ܵĲ���Ҫ�Լ�����,����ɹ��󶨵� iocp Ӧ�����з�Ӧ
    //--------------------------------------------------

    if re = False then
    begin
      bSleep := True;

      //--------------------------------------------------
      closesocket(Acceptsc);//�ȹر� socket �Ƚϰ�ȫ,�����ٴδ��� iocp �¼�(�ƺ����ǻᴥ��)
      //Winsock2_v2.closesocket(Acceptsc);

      //�п����������ͷ��Ժ�, iocp �¼����ڴ������� as ����//����������˵���ն���û����ǲ��ᴥ����
      iocpClass.DoClose(Acceptsc);

      Exit;//Continue;

    end;//if

    //--------------------------------------------------
    //��û�����˾�Ҫ���������¼������û��Ҫ���͵Ķ���//�����Ļ��Ͳ�Ҫ������,��Ϊǰ�����������������
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
      acceptLock.Lock('acceptLock.Lock');//�ܼ�,���� try ��// 2015/4/3 13:48:29  ����Ҫ��,��Ϊ lock �������쳣

      if Self.Terminated then exit; // 2015/4/14 10:20:53 �п����ǹر������

      //acceptList.Write(Acceptsc);
      haveSocket := acceptList.Read(Acceptsc);
    finally
      acceptLock.UnLock;
    end;

    if haveSocket = False then
    begin
      bSleep := True;

      Continue;//û��δ��������
    end;

    //--------------------------------------------------
    try
      iocpClass.threadLock.Lock('TAcceptFastThread.Execute');

      if Self.Terminated then exit; // 2015/4/14 10:20:53 �п����ǹر������

      if g_IOCP_Synchronize_Event
      then Synchronize(DoOne)
      else DoOne();

      Continue;


    finally
      iocpClass.threadLock.UnLock;
    end;


  end;//while

  LogFile('TAcceptFastThread.Execute ���˳�.');//��¼��,�Ƿ��쳣�˳�


end;

procedure TAcceptFastThread.Execute;
begin

  if DebugHook=0 then //����ʱ������ except ,����ʱ�þͿ���������ص���
  begin

    {$ifndef EXCEPT_DEBUG}//�����쳣�����������
    try
    {$endif}

      Run();
      Exit;

    {$ifndef EXCEPT_DEBUG}//�����쳣�����������
    except//������ except ȥ���쳣,�����������ݽ��ղ���Ӧ
      MessageBox(0, 'TAcceptFastThread.Execute ���˳�.', '', 0);
    end;
    {$endif}


  end;  

  try
    Run();
  finally
    
  LogFile('TAcceptFastThread.Execute ���˳�.');//��¼��,�Ƿ��쳣�˳�

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

  //�����ɵ� periodata ����¼����
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
  //����һ����ʱ�������¼�
  Self.timerThread.AddOnTimerEvent(EventName, OnTimer, Interval);

end;

procedure TIocpClass.SetOnTimerEvent_ThreadFun(OnThreadBegin,
  OnThreadEnd: TOnIocpTimerProc);
begin
  Self.timerThread.SetOnTimerEvent_ThreadFun(OnThreadBegin, OnThreadEnd);
end;


//���߳�����Ӧ�¼��ĸ�����ģʽ.Ĭ�����������д����¼�,�����Բ�//������Ĳ�������һ��,������ TIdUDPServer.ThreadedEvent ͬ�������
class procedure TIocpClass.ThreadedEvent(EventInThread:Boolean);
begin
  g_IOCP_Synchronize_Event := not EventInThread;
end;


end.

