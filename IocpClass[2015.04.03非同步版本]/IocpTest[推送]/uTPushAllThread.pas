unit uTPushAllThread;

//�����߳�ʾ��.�� TPushThread ��ͬ,������һ���߳����������ݸ�ȫ���ͻ���

interface

uses
  Classes,
  iocpInterfaceClass, Windows, uThreadLock,
  forms;

type
  //�����߳�
  TPushAllThread = class(TThread)
  private
    { Private declarations }
  protected
    procedure Execute; override;
  public
    iocpServer:TIocpClass;
    threadLock:TThreadLock;

    //Socket: TSocket;
    //OuterFlag: Integer;
    clientList:TList;
  end;

implementation

uses IocpTestMain;

{ Important: Methods and properties of objects in visual components can only be
  used in a method called using Synchronize, for example,

      Synchronize(UpdateCaption);

  and UpdateCaption could look like,

    procedure TPushThread.UpdateCaption;
    begin
      Form1.Caption := 'Updated in a thread';
    end; }

{ TPushAllThread }

procedure TPushAllThread.Execute;
var
  //data:AnsiString;
  data:TMemoryStream;
  t:TTestClass;

  Socket: TSocket;
  OuterFlag: Integer;

  i:Integer;
  sleepCount:Integer;//�����˶����˯��һ��,����ռ��̫�� cpu

begin
  //data := 'init.��ʼ������'#13#10;
  data := TMemoryStream.Create;
  sleepCount := 0;


  //t := TTestClass(OuterFlag);

  while not Application.Terminated do
  begin
    //if t.exit then Break;

    //if t.data<>'' then data := 'recv.��������:' + t.data + #13#10;

    //--------------------------------------------------
    //ȡ��Ҫ���͵�����
    threadLock.Lock();
    try
      if GPushData.Size = 0 then Continue;//û�����ݾͲ�������

      data.Clear();
      data.WriteBuffer(GPushData.memory^, GPushData.Size);

    finally
      threadLock.UnLock();
    end;

    //--------------------------------------------------

    iocpServer.threadLock.Lock();
    try
      for i := 0 to clientList.Count-1 do
      begin
        t := TTestClass(clientList.Items[i]);
        OuterFlag := Integer(t);
        Socket := t.Socket;
        
        if t.exit then Continue;

        //iocpServer.SendDataSafe(Socket, PChar(data), Length(data), OuterFlag);
        iocpServer.SendDataSafe(Socket, data.Memory, data.Size, OuterFlag);

        Inc(sleepCount);
        if sleepCount > 600 then
        begin
          sleepCount := 0;
          Sleep(1);
        end;

      end;
    finally
      iocpServer.threadLock.UnLock()
    end;

    //iocpServer.SendDataSafe(Socket, PChar(data), Length(data), OuterFlag);

    sleep(1000);
  end;

end;

end.
 
