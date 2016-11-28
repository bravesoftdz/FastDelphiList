unit iocpSendHelper;

//�ϲ�Ӧ�ð��ķ������ֺ���
//Ϊ����ԭ�� iocp �ӿ�//Ҳ��Ϊ����֪��һ���ϲ��ȫ�����ͺ�����
{
1.Ϊ�����ϲ�Ӧ��֪��taҪ���͵�һ����ʲôʱ�������.
2.���ϲ�Ӧ��֪������һ�������������.(������Ҫ��������ԭʼ��Ϣ,�����Ļ������ڲ�
  �ֳ� iocp ���ǾͲ��������µ��ڴ���,ֱ����ԭ�а������л��ֳ�ָ�뼴��.����ͬʱ
  �����������)
}

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  winsock2,WinSock,ComCtrls,Contnrs, iocpInterface,
  uThreadLock,
  Math,
  Dialogs;

type
  //SendDataSafe ʹ�õ����ݽṹ
  TSendHelper = class(TObject)
  private
    FParentConnect:TObject;

  public
    //ÿ������ֻ��һ��,�� iocp ���ڴ����
    FPerIoData : LPPER_IO_OPERATION_DATA;
    //��Ϊ���͵� periodata һ����Ҫ�Լ��ͷŵ�,�����ͷ�ʱҪ��־һ��,����Ҳ�п��ܻ�
    PerIoData_IsFree:Boolean;

    
    SendMemory:TMemoryStream;
    //FMemory:TMemoryStream;
    //OuterFlag:Integer;//�����ⲿ���ӱ�־//Ϊ����ԭ�� iocp �ӿ�,�����������̺߳����д��ݵĲ���
    //��������ʱȡ�õ�,��Ϊ�������ֹ��ܵĻ����ֻ�ռ�� OuterFlag, ����������һ���ط������ⲿ���ݽ����� OuterFlag
    socket:TSocket;
    threadLock:TThreadLock;//�߳���,�ⲿ�����,��Ҫ�Լ�����

    // 2015/5/8 14:39:57 �Ƿ���� iocp ,���û�еĻ�����ֻ���ȼ��뵽��������,�󶨺����ֹ���������
    isBindIocp:Boolean;
    atSend:Boolean;//�Ƿ����ڷ���

    // 2015/5/12 11:04:38 ÿ�ζ����Ч��̫��,�����ȼ�¼һ��
    BytesTransferred_Total:Integer;

    constructor Create(parentConnect:TObject); //override;
    destructor Destroy; override;

    //�� PerIoData ���б�ᵼ�� iocp ����̫��������,Ӧ���ŵ����Ӧ��,����Ҫ����Ϊ��ǰû�пɿ��� socket �б�����������
    //���ڸĳɷŵ�һ�� �ڴ��� �о�����,��Ȼ�����и�������ǵ�Ҫ���Ͷ�����ļ�ʱ���ƶ��������ڴ�,�������ļ�����Ҳ��Ӧ��һ��ȫ��װ��
    //��ӵ����ͻ�����
    procedure AddSendBuf(buf:PAnsiChar; buflen:Integer);
    //ȡ��һ��Ҫ���͵�����Ҫ��� io �ṹ//BytesTransferred �ǵ�ǰ���ͳɹ����ֽ���,��ʵ��Ŀǰ���㷨���� DATA_BUFSIZE
    function IoDataGetNext(PerIoData : LPPER_IO_OPERATION_DATA; BytesTransferred:Integer):Boolean;
    //�������еķ��ͳ�ȥ
    procedure DoSendBuf(Socket: TSocket);

  end;



//����һ�������õ� io �ṹ
//function MakeSendHelperIoData(Socket: TSocket; buf:PChar; bufLen:Integer; OuterFlag:Integer):LPPER_IO_OPERATION_DATA;

//���õ�һ������ io ���ݽṹ
//procedure IoDataGetFirst(PerIoData : LPPER_IO_OPERATION_DATA);
//ȡ��һ��Ҫ���͵�����Ҫ��� io �ṹ//BytesTransferred �ǵ�ǰ���ͳɹ����ֽ���,��ʵ��Ŀǰ���㷨���� DATA_BUFSIZE
//function IoDataGetNext(PerIoData : LPPER_IO_OPERATION_DATA; BytesTransferred:Integer):Boolean;

//һ����������,ֻ�����ڻ��� iocp ��ĵط�
//procedure SendData(Socket: TSocket; buf: PChar; bufLen: Integer; OuterFlag: Integer);



implementation

uses iocpInterfaceClass, iocpRecvHelper;



//ȡ��һ��Ҫ���͵�����Ҫ��� io �ṹ//BytesTransferred �ǵ�ǰ���ͳɹ����ֽ���,��ʵ��Ŀǰ���㷨���� DATA_BUFSIZE
function TSendHelper.IoDataGetNext(PerIoData : LPPER_IO_OPERATION_DATA; BytesTransferred:Integer):Boolean;
var
  curDataPoint:PChar;//��ǰҪ���͵����ݵ�λ��
  remainlen:Integer;//ʣ������ݳ���
  //buf:PChar;
  //bufLen:Integer;
begin
  Result := False;
  
  //--------------------------------------------------
  //������Ѿ����͵�����
  BytesTransferred_Total := BytesTransferred_Total + BytesTransferred;

  //ÿ�ζ����Ч��̫����,��Ŀǰ�������cpu����,1M����һ���ǱȽϺ��ʵ�
  //if BytesTransferred_Total>1*1024*1024 then //���ļ�ʱ��Ȼ��Ǻ
  if (BytesTransferred_Total>1*1024*1024)and(BytesTransferred_Total > SendMemory.Size div 2) then //�Ӹ��۰��㷨����� 4 ������
  begin
    //ClearData_Fun(self.SendMemory, BytesTransferred);//���ʹ��ļ�ʱ,���Ч��̫����
    ClearData_Fun(self.SendMemory, BytesTransferred_Total);//���ʹ��ļ�ʱ,���Ч��̫����
    BytesTransferred_Total := 0;

    //������Ļ����ԭ���� iocp ���ܺܽӽ�,���������Ҫ��ס�����ְ�,�߼�̫����


  end;
  //Sleep(100);//sleep �����ܼ�ǿ����.Ŀǰ�����ܼ�ǿͨ���ԵĲ���Ϊ
  //1. DATA_BUFSIZE,Ĭ��Ϊ 1K ,���Լӵ��� windowsһ���� 4k,�����ӵ� 1M�Ļ���߲�������;
  //2. BytesTransferred_Total �������̵ļ������ 20m ���ҵ��ļ�Ч���ǳ�����,���� 100M ��Ļ�Ҫ��������������;
  //3. g_IOCP_Synchronize_Event �������� http ���ļ������ؼ���û��Ӱ��(�Ƚ����˳Ծ�);
  //���ڳ�������˵ BytesTransferred_Total �͹���,����������˵ DATA_BUFSIZE ������� 50%
  //��������˵,������ cpu �Ļ� BytesTransferred_Total �Ӵ�Ҳ�ܼ���ķ�������
  //���ԱȽϺõķ�ʽ�Ǹ���Ҫ���͵İ���С��̬�޸� DATA_BUFSIZE Ҫ��Ϊ 1K ,Ҫ��Ϊ 1M,������
  //����Ŀǰ�õĳ�������˵, 1M ��BytesTransferred_Total �� 1K �� DATA_BUFSIZE ���ܾͷǳ�����
  //--------------------------------------------------


  //self.SendMemory.Position := 0;
  self.SendMemory.Position := BytesTransferred_Total;

  //FPerIoData.BufLen := SendMemory.Read(FPerIoData.Buf, DATA_BUFSIZE);
  PerIoData.BufLen := SendMemory.Read(PerIoData.Buf, DATA_BUFSIZE);

  if PerIoData.BufLen<1 then Exit;//Result := False;//û��ȡ������

  //--------------------------------------------------

  //if bufLen>DATA_BUFSIZE then bufLen := DATA_BUFSIZE;

  //CopyMemory(@PerIoData.Buf, buf, bufLen);

  ZeroMemory(@PerIoData.Overlapped, sizeof(OVERLAPPED));//ÿ�ζ�Ҫ������?
  //PerIoData.BytesSEND := 0;//ÿ�ζ�Ҫ����
  //PerIoData.BytesRECV := 0;
  PerIoData.BufInfo.len := PerIoData.BufLen;//bufLen;//1024;//ÿ�ζ�Ҫ����
  PerIoData.BufInfo.buf := @PerIoData.Buf;//��ʵ��β�����Ҳ����

  Result := True;

end;

{ TSendHelper }

// 2015/5/8 9:44:33 ����һ�����ظ�ʹ�õķ��� iodata �������ɼ�ǿ����,�������ж��Ƿ����������ڷ���
//����һ�������õ� io �ṹ
function CreateSendHelperIoData(Socket: TSocket):LPPER_IO_OPERATION_DATA;
var
  PerIoData : LPPER_IO_OPERATION_DATA;//�������Լ��õ���ʱ����

begin
  result := nil;

  //����һ������IO���ݽṹ�����н� PerIoData.OpCode ���ó�1��˵���ˡ���IO���ݽṹ�����������͵ġ�
  PerIoData := LPPER_IO_OPERATION_DATA(IocpAlloc(sizeof(PER_IO_OPERATION_DATA)));
  if (PerIoData = nil) then
  begin
    MessageBox(0, 'GlobalAlloc', '�������ڲ�����(GlobalAlloc)', 0); //û��ȡ���ڴ�
    exit;
  end;

  ZeroMemory(PerIoData, sizeof(PER_IO_OPERATION_DATA));

  ZeroMemory(@PerIoData.Overlapped, sizeof(OVERLAPPED));
  //PerIoData.BytesSEND := 0;
  //PerIoData.BytesRECV := 0;
  //PerIoData.DataBuf.len := bufLen;//1024;//����ȡ�������ḳֵ��
  //PerIoData.DataBuf.buf := @PerIoData.Buf;//����ȡ�������ḳֵ��
  PerIoData.OpCode := 1;//��־,�����õ�
  PerIoData.Socket := Socket;//�����ؼ��ֵĻ�,���������ȫ
  //PerIoData.OuterFlag := OuterFlag;
  //PerIoData.ExtInfo := Integer(pack);//ExtInfo;


  result := PerIoData;

end;




constructor TSendHelper.Create(parentConnect:TObject);
begin
  inherited Create;

  FParentConnect := parentConnect;

  atSend := False;
  isBindIocp := False;
  //sendDataList := TList.Create;
  SendMemory := TMemoryStream.Create;

  BytesTransferred_Total := 0;

  //iocp ���������ﴴ��,����������������,ԭ�����п����ڽ����¼��з��ֹرն���ǰ�ͷ��� self ����//�����ͷ�ʱֻ���ñ�־,�÷����õ� iocp �����Լ�����
  FPerIoData := CreateSendHelperIoData(0{Socket}{, 0{OuterFlag});
  FPerIoData.atWork := 0;
  FPerIoData.conFree := 0;

  PerIoData_IsFree := False;
  //TConnectClass(FParentConnect).iocpClass.perIoDataList.Add(Integer(FPerIoData), 0);//�����ɵ� periodata ����¼����

end;

destructor TSendHelper.Destroy;
var
  i:Integer;
begin

  if PerIoData_IsFree = False then
  begin
    FPerIoData.conFree := 1; //���� iocp �е�,�Լ�������..�����Լ��ͷ��ڴ�//��Ϊ���߳�ͬ����,���Բ����ǹؼ������޷�

    //if FPerIoData.atWork = 0 then
    //if FPerIoData.atWork <> 1 then //����ʧ��ʱΪ 999
    if (FPerIoData.atWork = 0)or(FPerIoData.atWork = 999) then //����ʧ��ʱΪ 999
    begin
      PerIoData_IsFree := True;

      //TConnectClass(FParentConnect).iocpClass.perIoDataList.Remove(Integer(FPerIoData));//�����ɵ� periodata ����¼����

      IocpFree(FPerIoData, 3);//���� iocp �еľͿ���ֱ���ͷ���
      FPerIoData := nil;

    end
    else
    begin //test ֱ�Ӽ�鿴��//ȷʵ��������,��˵��Ҫ���� GetQueuedCompletionStatus ֮��
//      if CheckPerIoDataComplete(FPerIoData) then
//      begin
//        PerIoData_IsFree := True;
//
//        //TConnectClass(FParentConnect).iocpClass.perIoDataList.Remove(Integer(FPerIoData));//�����ɵ� periodata ����¼����
//
//        IocpFree(FPerIoData, 4);//���� iocp �еľͿ���ֱ���ͷ���
//        FPerIoData := nil;
//      end;
    end;

  end;


  //sendDataList.Free;

  SendMemory.Clear;
  SendMemory.Free;

  inherited;
end;


//��ӵ����ͻ�����
procedure TSendHelper.AddSendBuf(buf:PAnsiChar; buflen:Integer);
begin
  //ע��д��ķ�ʽ�������ָ��
  //SendMemory.Position := SendMemory.Size;
  SendMemory.Seek(0, soFromEnd); //ȷʵ������,ǧ������
  SendMemory.WriteBuffer(buf^, bufLen{, connect.Iocp_OuterFlag});

end;

//�������еķ��ͳ�ȥ
procedure TSendHelper.DoSendBuf(Socket: TSocket);
begin
  //FPerIoData := CreateSendHelperIoData(Socket, OuterFlag);

  if atSend = True then Exit;  //���ڷ���
  if IoDataGetNext(FPerIoData, 0) = False then Exit;   //û�а���

  atSend := True;

  FPerIoData.Socket := Socket;
  //FPerIoData.OuterFlag := OuterFlag;
  SendBuf(Socket, FPerIoData);


end;


end.
