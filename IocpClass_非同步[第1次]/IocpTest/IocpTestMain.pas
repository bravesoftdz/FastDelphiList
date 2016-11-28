unit IocpTestMain;

interface
                                
uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  iocpInterfaceClass,
  Dialogs, StdCtrls;

const
  WM_USER_GUI = WM_USER + 2001;//�߳��в�������������Ϣ

  //WParam ����
  WP_GUI_LOG = 101;//��־����  

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

    //����������¼�
    //procedure OnRecvClass(Socket: TSocket; buf: PChar; bufLen: Integer; OuterFlag:Integer);
    procedure OnRecvDataClass(Socket: TSocket; buf:PChar; bufLen:Integer; OuterFlag:Integer; var useDataLen:Integer);
    procedure OnCloseClass(Socket: TSocket; OuterFlag:Integer);
    procedure OnSendClass(Socket: TSocket; OuterFlag:Integer);
    //���ӵ���
    procedure OnConnectClass(Socket: TSocket; var OuterFlag:Integer);

  end;

var
  Form1: TForm1;
  gGuiMessageHandle:THandle = 0;

  //������־��Ϣ
  procedure LogMessage(s:string);

implementation

{$R *.dfm}


procedure TForm1.btnStartClick(Sender: TObject);
begin
  btnStart.Enabled := False;
  
  iocpServer := TIocpClass.Create;

  iocpServer.InitSock();
  iocpServer.ListenPort := 8080;
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
  t := TTestClass(OuterFlag);
  MessageBox(0, PChar('"' + t.data + '"'), '', 0);//�������߳��м����,�� showmessage �Ļ����п��ܳ���,���Բο� LogMessage ����Ϣ�ķ�ʽ�����ݴ��͵����߳���ʹ��

  t.Free;

  LogMessage('�Ͽ�...');

end;

//������־��Ϣ
procedure LogMessage(s:string);
begin

  //��ʵֱ���� Handle Ҳ�ǲ���ȫ��,Ӧ����һ����������صĶ������

  SendMessage(gGuiMessageHandle, WM_USER_GUI, WP_GUI_LOG, Integer(PChar(s)));

end;

procedure TForm1.OnConnectClass(Socket: TSocket; var OuterFlag: Integer);
var
  t:TTestClass;
begin
  t := TTestClass.Create;
  t.data := '';

  OuterFlag := Integer(t);

  LogMessage('����...');
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
  sl := TStringList.Create;
  sl.LoadFromFile(ExtractFilePath(Application.ExeName) + '1.html');

  iocpServer.SendDataSafe(Socket, PChar(sl.Text), Length(sl.Text), OuterFlag);

  useDataLen := bufLen;//һ��Ҫ�����

  sl.Free;

  //--------------------------------------------------
  t := TTestClass(OuterFlag);
  buf[bufLen] := #0;
  t.data := t.data + buf;
  //MessageBox(0, PChar(t.data), '', 0);
  //--------------------------------------------------
  LogMessage('��������...:' + buf);

end;

procedure TForm1.OnSendClass(Socket: TSocket; OuterFlag: Integer);
begin
  //�������һ�����ݺ���¼�,���ʹ�� SendDataSafe() �������ݵĻ�һ�㲻�ô���
  
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





