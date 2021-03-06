unit IocpTestMain;

interface
                                
uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  iocpInterfaceClass,
  Dialogs, StdCtrls;

const
  WM_USER_GUI = WM_USER + 2001;//线程中操作界面必须过消息

  //WParam 部分
  WP_GUI_LOG = 101;//日志内容  

type
  TTestClass = class(TObject)
  public
    data:string;

  end;

type
  TForm1 = class(TForm)
    btnStart: TButton;
    MemoLog: TMemo;
    procedure btnStartClick(Sender: TObject);
  private
    procedure WMThreadGui(var msg: TMessage);  message WM_USER_GUI;
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
  gConCount_test:Integer=0;//测试下连接释放完没有
  gConCount_test1:Integer=0;//测试下连接释放完没有//连接数
  gConCount_test2:Integer=0;//测试下连接释放完没有//断开数

  //加入日志消息
  procedure LogMessage(s:string);

implementation

{$R *.dfm}


procedure TForm1.btnStartClick(Sender: TObject);
begin
  btnStart.Enabled := False;
  
  iocpServer := TIocpClass.Create(Self);

  iocpServer.InitSock();
  iocpServer.ListenPort := 30130;//8080;
  //iocpServer.OnRecv := Self.OnRecvClass;
  iocpServer.OnRecvData := Self.OnRecvDataClass;
  iocpServer.OnClose := Self.OnCloseClass;
  iocpServer.OnSend := Self.OnSendClass;
  iocpServer.OnConnect := Self.OnConnectClass;

  iocpServer.StartService;




  gGuiMessageHandle := Handle;
end;

procedure TForm1.OnCloseClass(Socket: TSocket; OuterFlag: Integer);
var
  t:TTestClass;
begin
  Dec(gConCount_test);
  inc(gConCount_test2);
  t := TTestClass(OuterFlag);
//  MessageBox(0, PChar('"' + t.data + '"'), '', 0);//这是在线程中激活的,用 showmessage 的话会有可能出错,可以参考 LogMessage 用消息的方式将数据传送到主线程中使用

  t.Free;

  LogMessage('断开...');
  LogMessage('断开...' + IntToStr(Trunc(g_IOCP_SendSize_test / 1024)) + 'k');
  LogMessage('断开 连接数...' + IntToStr(gConCount_test) + ' 连接数 ' + IntToStr(gConCount_test1) + ' 断开数 ' + IntToStr(gConCount_test2));

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
  Inc(gConCount_test);
  Inc(gConCount_test1);
  t := TTestClass.Create;
  t.data := '';

  OuterFlag := Integer(t);

  LogMessage('连接...');
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
  i:Integer;

begin
  try
  sl := TStringList.Create;
  sl.LoadFromFile(ExtractFilePath(Application.ExeName) + '1.html');

  // 2015/4/13 16:57:21 形成一个超大文件测试

  iocpServer.SendDataSafe(Socket, PChar(sl.Text), Length(sl.Text), OuterFlag);

  for i:= 0 to 100 do
  begin
    sl.Text := sl.Text + sl.Text + 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
  end;

  useDataLen := bufLen;//一定要有这个

//  sl.Free;

  //--------------------------------------------------
  t := TTestClass(OuterFlag);
  buf[bufLen] := #0;
  t.data := t.data + buf;
  //MessageBox(0, PChar(t.data), '', 0);
  //--------------------------------------------------
  LogMessage('接收数据...:' + buf);

  finally
    sl.Free;
  end;
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

end.





