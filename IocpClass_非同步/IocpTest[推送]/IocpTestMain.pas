unit IocpTestMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  iocpInterfaceClass, uThreadLock,
  Dialogs, StdCtrls;

const
  WM_USER_GUI = WM_USER + 2001;//线程中操作界面必须过消息

  //WParam 部分
  WP_GUI_LOG = 101;//日志内容  

type
  TTestClass = class(TObject)
  public
    Socket: TSocket;
    data:string;
    exit:Boolean;

  end;

type
  TForm1 = class(TForm)
    btnStart: TButton;
    MemoLog: TMemo;
    procedure btnStartClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    procedure WMThreadGui(var msg: TMessage);  message WM_USER_GUI;
    procedure SetPushData(buf: PAnsiChar; bufLen: Integer);
    procedure SetPushString(data: AnsiString);
    procedure ClearPushData;
    { Private declarations }
  public
    { Public declarations }
    iocpServer:TIocpClass;
    port:Integer;

    //下面是类的事件
    //procedure OnRecvClass(Socket: TSocket; buf: PChar; bufLen: Integer; OuterFlag:Integer);
    procedure OnRecvDataClass(Socket: TSocket; buf:PChar; bufLen:Integer; OuterFlag:Integer; var useDataLen:Integer);
    procedure OnCloseClass(Socket: TSocket; OuterFlag:Integer);
    procedure OnSendClass(Socket: TSocket; OuterFlag:Integer);
    //连接到达
    procedure OnConnectClass(Socket: TSocket; var OuterFlag:Integer);

  end;

var
  Form1: TForm1;
  gGuiMessageHandle:THandle = 0;

  //加入日志消息
  procedure LogMessage(s:string);

var
  GPushData:TMemoryStream;  

implementation

uses uTPushAllThread;

{$R *.dfm}

var
  GPushThread:TPushAllThread;//推送线程


procedure TForm1.btnStartClick(Sender: TObject);
begin
  btnStart.Enabled := False;
  
  iocpServer := TIocpClass.Create;

  iocpServer.InitSock();
  iocpServer.ListenPort := 8090;
  //iocpServer.OnRecv := Self.OnRecvClass;
  iocpServer.OnRecvData := Self.OnRecvDataClass;
  iocpServer.OnClose := Self.OnCloseClass;
  iocpServer.OnSend := Self.OnSendClass;
  iocpServer.OnConnect := Self.OnConnectClass;

  iocpServer.StartService;




  gGuiMessageHandle := Handle;

  //--------------------------------------------------
  //启动推送线程
  GPushData := TMemoryStream.Create;

  GPushThread := TPushAllThread.Create(True);//推送线程

  GPushThread.iocpServer := Self.iocpServer;
  GPushThread.threadLock := TThreadLock.Create(Application);

//  PushThread.Socket := Socket;
//  PushThread.OuterFlag := OuterFlag;
  GPushThread.clientList := TList.Create;

  GPushThread.Resume;

  //--------------------------------------------------
  SetPushString('init.初始化数据'#13#10);
end;

procedure TForm1.OnCloseClass(Socket: TSocket; OuterFlag: Integer);
var
  t:TTestClass;
  //pos:Integer;
begin

  t := TTestClass(OuterFlag);
  t.exit := True;
  //MessageBox(0, PChar('"' + t.data + '"'), '', 0);//这是在线程中激活的,用 showmessage 的话会有可能出错,可以参考 LogMessage 用消息的方式将数据传送到主线程中使用

  //--------------------------------------------------
  //pos := GPushThread.clientList.IndexOf()
  //if pos >= 0 then
  GPushThread.clientList.Remove(t);

  //--------------------------------------------------

  t.Free;

  LogMessage('断开...');

end;

//加入日志消息
procedure LogMessage(s:string);
begin

  //其实直接用 Handle 也是不安全的,应当有一个不和类相关的独立句柄

  SendMessage(gGuiMessageHandle, WM_USER_GUI, WP_GUI_LOG, Integer(PChar(s)));

end;

procedure TForm1.OnConnectClass(Socket: TSocket; var OuterFlag: Integer);
var
  t:TTestClass;
begin
  t := TTestClass.Create;
  t.Socket := Socket;
  t.exit := False;
  t.data := '';

  OuterFlag := Integer(t);

  LogMessage('连接...');

  //--------------------------------------------------
//  thread := TPushThread.Create(True);
//  thread.iocpServer := Self.iocpServer;
//  thread.Socket := Socket;
//  thread.OuterFlag := OuterFlag;
//
//  thread.Resume;
  //--------------------------------------------------
  GPushThread.clientList.Add(t);

end;

//procedure TForm1.OnRecvClass(Socket: TSocket; buf: PChar; bufLen,
//  OuterFlag: Integer);
//begin
//
//end;

procedure TForm1.OnRecvDataClass(Socket: TSocket; buf: PChar; bufLen,
  OuterFlag: Integer; var useDataLen: Integer);
var
  sl:TStringList;
  t:TTestClass;

begin
//  sl := TStringList.Create;
//  sl.LoadFromFile(ExtractFilePath(Application.ExeName) + '1.html');
//
//  iocpServer.SendDataSafe(Socket, PChar(sl.Text), Length(sl.Text), OuterFlag);

  useDataLen := bufLen;//一定要有这个

//  sl.Free;

  //--------------------------------------------------
  t := TTestClass(OuterFlag);
  buf[bufLen] := #0;
  t.data := t.data + buf;
  //MessageBox(0, PChar(t.data), '', 0);
  //--------------------------------------------------
  SetPushString('最后收取的内容:' + buf + #13#10);
  //--------------------------------------------------
  LogMessage('接收数据...:' + buf);

end;

procedure TForm1.OnSendClass(Socket: TSocket; OuterFlag: Integer);
begin
  //发送完毕一块数据后的事件,如果使用 SendDataSafe() 发送数据的话一般不用处理
  
end;

procedure TForm1.WMThreadGui(var msg: TMessage);
var
  p:PAnsiChar;
begin
  if msg.WParam = WP_GUI_LOG then
  begin
    p := PChar(msg.LParam);

    if MemoLog.Lines.Count > 100 then MemoLog.Lines.Clear;
    MemoLog.Lines.Add(p);
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin

end;

//设置要推送的内容
procedure TForm1.SetPushData(buf:PAnsiChar; bufLen:Integer);
begin

  GPushThread.threadLock.Lock();
  try

    GPushData.Clear();
    GPushData.WriteBuffer(buf^, bufLen);


  finally
    GPushThread.threadLock.UnLock();
  end;

end;

//清空要推送的内容,,推送线程会停止发送.
procedure TForm1.ClearPushData;
begin

  GPushThread.threadLock.Lock();
  try

    GPushData.Clear();
    //GPushData.WriteBuffer(buf^, bufLen);


  finally
    GPushThread.threadLock.UnLock();
  end;

end;

//设置要推送的内容,字符串
procedure TForm1.SetPushString(data:AnsiString);
begin

  SetPushData(PAnsiChar(data), Length(data));

end;

end.





