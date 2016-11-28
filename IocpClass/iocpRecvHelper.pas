unit iocpRecvHelper;

//������ iocpSendHelper,��������ڽ���
{
Ŀ����:
1. ���ϲ�Ӧ��֪���������չ�����ȡ�õ���������.
2. ���ϲ�Ӧ�ÿ��Ծ���ʲôʱ������һ����������.��ʱ�ϲ�Ӧ�ÿ���ɾ���Ѿ��յ�������
   ��(����һֱ����,����������¹��ܿ�д��,���������ݶൽһ���̶�ʱӦ���쳣).
}

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  winsock2,WinSock,ComCtrls,Contnrs, iocpInterface,
  uThreadLock,
  Math,
  Dialogs;

type
  TRecvHelper = class(TObject)
  private
    // 2015/4/2 14:20:49 ��һ�����Ա�־,�����ڴ��쳣ʱ����Ƿ��Ƿǳ��ڴ�
    iDebugTag:Byte;
    FParentConnect:TObject;

    function CreateRecvHelperIoData(Socket: TSocket): LPPER_IO_OPERATION_DATA;

  public
    //ÿ������ֻ��һ��,�� iocp ���ڴ����
    FPerIoData : LPPER_IO_OPERATION_DATA;
    //��Ϊ���͵� periodata һ����Ҫ�Լ��ͷŵ�,�����ͷ�ʱҪ��־һ��,����Ҳ�п��ܻ�
    PerIoData_IsFree:Boolean;
    
    FMemory:TMemoryStream;
    OuterFlag:Integer;//�����ⲿ���ӱ�־//Ϊ����ԭ�� iocp �ӿ�,�����������̺߳����д��ݵĲ���
    //��������ʱȡ�õ�,��Ϊ���ý������ֹ��ܵĻ����ֻ�ռ�� OuterFlag, ����������һ���ط������ⲿ���ݽ����� OuterFlag


    constructor Create(parentConnect:TObject); //override;
    destructor Destroy; override;
    

    //function CreateRecvHelperIoData(Socket: TSocket; OuterFlag:Integer):LPPER_IO_OPERATION_DATA;
    function GetIoData(Socket: TSocket): LPPER_IO_OPERATION_DATA;


    procedure OnRecv(Socket: TSocket; buf:PChar; bufLen:Integer);//���ջ���
    //����ѽ��յ�����//dataLen ���Ѵ�������ݳ���,��Ҫ�ӻ�������ɾ����ô��,�ϲ�Ӧ��Ӧ���ж��Ѿ����յ��������Ƿ��ж����
    //Ӧ�������ܵĴ�������Ȼ��ɾ�����Ѵ���������ݳ���
    class procedure ClearData(helper:TRecvHelper; dataLen:Integer);
  end;

procedure ClearData_Fun(var FMemory:TMemoryStream; dataLen:Integer);

implementation

uses
  iocpInterfaceClass;

{ TRecvHelper }

procedure ClearData_Fun2(var FMemory:TMemoryStream; dataLen:Integer);
var
  tmp:TMemoryStream;
begin
//  Move(Pointer(Longint(FMemory.Memory) + 0)^, Pointer(Longint(FMemory.Memory) + FMemory.Position)^,
//
//  FMemory.Size - FMemory.Position);

  if (dataLen<=0) or (dataLen>FMemory.Size) then Exit;

  if FMemory.Size = dataLen then
  begin
    FMemory.Clear;
    Exit;
  end;

//  Move(Pointer(Longint(FMemory.Memory) + 0)^, Pointer(Longint(FMemory.Memory) + dataLen)^,
//
//  dataLen);
//
//  FMemory.SetSize(FMemory.Size - dataLen);

  tmp := TMemoryStream.Create;

  try

    tmp.SetSize(FMemory.Size - dataLen);
    FMemory.Seek(dataLen, soFromBeginning); //FMemory.Seek(0, soFromBeginning);
    FMemory.ReadBuffer(tmp.Memory^, FMemory.Size - dataLen);
    //FMemory.SaveToStream(tmp);

  finally

    FMemory.Free;
    FMemory := tmp;
  end;

end;

//��������,����õ��Ĳ�������,�ͷ������˵Ĵ�����һ����//��������ʱ��������ܷǳ���,�ڷ�������Ӧ���Ż�ʹ��
//class procedure TThreadSafeSocket.ClearData(var FMemory:TMemoryStream; dataLen:Integer);
procedure ClearData_Fun1(var FMemory:TMemoryStream; dataLen:Integer);
var
  tmp:TMemoryStream;
  p:PAnsiChar;
  clearSize:Integer;
begin
  if (dataLen<=0) or (dataLen>FMemory.Size) then Exit;

  if (dataLen = FMemory.Size) then//ȫ������Ļ���վ�����
  begin
    FMemory.Clear;
    Exit;
  end;

  clearSize := FMemory.Size - dataLen;
  if (clearSize > 200 * 1024 * 1024) then
  begin
    MessageBox(0, PChar('�ͷų����쳣 [' + IntToStr(dataLen) + ']'), '', 0);
    FMemory.Clear;
    Exit;
  end;

  tmp := TMemoryStream.Create;


//  helper.FMemory.Seek(dataLen, soBeginning);//û���������Ǳ���ȫ��
  FMemory.SaveToStream(tmp);

  //p := PAnsiChar(FMemory.Memory);
  p := PAnsiChar(tmp.Memory);
  p := p + dataLen;

  //tmp.WriteBuffer(p, helper.FMemory.Size - dataLen);//������쳣
  //tmp.WriteBuffer(p^, FMemory.Size - dataLen);//ע������ ָ����÷�

  FMemory.Clear;
  FMemory.WriteBuffer(p^, tmp.Size - dataLen);//ע������ ָ����÷�


//  FMemory.Free;
//  FMemory := tmp;
  tmp.Free;
end;

procedure ClearData_Fun(var FMemory:TMemoryStream; dataLen:Integer);
begin
  //ClearData_Fun1(FMemory, dataLen);
  ClearData_Fun2(FMemory, dataLen);//��ſ� 50%

end;  

class procedure TRecvHelper.ClearData(helper: TRecvHelper; dataLen:Integer);
var
  tmp:TMemoryStream;
  p:PAnsiChar;
begin
  ClearData_Fun(helper.FMemory, dataLen);
  {
  if (dataLen<=0) or (dataLen>helper.FMemory.Size) then Exit;

  if (dataLen = helper.FMemory.Size) then//ȫ������Ļ���վ�����
  begin
    helper.FMemory.Clear;
    Exit;
  end;

  tmp := TMemoryStream.Create;


//  helper.FMemory.Seek(dataLen, soBeginning);//û���������Ǳ���ȫ��
  helper.FMemory.SaveToStream(tmp);//������������������

  p := PAnsiChar(helper.FMemory.Memory);
  p := p + dataLen;

  //tmp.WriteBuffer(p, helper.FMemory.Size - dataLen);//������쳣
  tmp.WriteBuffer(p^, helper.FMemory.Size - dataLen);//ע������ ָ����÷�


  helper.FMemory.Free;
  helper.FMemory := tmp;
  }
end;

constructor TRecvHelper.Create(parentConnect:TObject);
begin
  inherited Create;

  FParentConnect := parentConnect;
  
  FMemory:=TMemoryStream.Create;//���ջ���
  FMemory.SetSize(1024);// 2015/4/7 14:55:33 test Ԥ�����ڴ�������?
  FMemory.SetSize(0);// 2015/4/7 14:55:33 test Ԥ�����ڴ�������?
  iDebugTag := 111; // 2015/4/2 14:22:04 ��һ�����Ա�־,�����ڴ��쳣ʱ����Ƿ��Ƿǳ��ڴ�

  //iocp ���������ﴴ��,����������������,ԭ�����п����ڽ����¼��з��ֹرն���ǰ�ͷ��� self ����//�����ͷ�ʱֻ���ñ�־,�÷����õ� iocp �����Լ�����
  FPerIoData := CreateRecvHelperIoData(0{Socket}{, 0{OuterFlag});
  FPerIoData.atWork := 0;
  FPerIoData.conFree := 0;

  PerIoData_IsFree := False;
  
  //TConnectClass(FParentConnect).iocpClass.perIoDataList.Add(Integer(FPerIoData), 0);//�����ɵ� periodata ����¼����


end;

destructor TRecvHelper.Destroy;
begin

  if PerIoData_IsFree = False then
  begin
    FPerIoData.conFree := 1; //���� iocp �е�,�Լ�������..�����Լ��ͷ��ڴ�//��Ϊ���߳�ͬ����,���Բ����ǹؼ������޷�

    //if FPerIoData.atWork = -1 then MessageBox(0, 'FPerIoData.atWork =-1','',0);//ȡ������û���� 

    if FPerIoData.atWork = 0 then  //����Ӧ��Ϊ 0 ��ʱ����ͷ�
    //if FPerIoData.atWork <> 1 then
    begin
      PerIoData_IsFree := True;
      //TConnectClass(FParentConnect).iocpClass.perIoDataList.Remove(Integer(FPerIoData));//�����ɵ� periodata ����¼����
      IocpFree(FPerIoData, 100);//���� iocp �еľͿ���ֱ���ͷ���

    end;

  end;


  FMemory.Free;

  inherited;
end;

procedure TRecvHelper.OnRecv(Socket: TSocket; buf: PChar; bufLen: Integer);
begin
  FMemory.Seek(0, soFromEnd);//ȷ��������������ĩβ

  //ע�ⲻ���� FMemory.WriteBuffer(buf, bufLen); ����˵����������ָ��,Ҳ���ڲ���ת��һ��ָ��?
  FMemory.WriteBuffer(buf^, bufLen);

  if FMemory.Size > 1024 * 1024 * 2 then
  begin
    MessageBox(0, '�������Ӵӿͻ��˽�����̫�����ݶ�δ����', '�������ڲ�����', 0);

//    raise Exception.Create('���մ����쳣. '#13#10
//      + '�������Ӵӿͻ��˽�����̫�����ݶ�δ����,���� OnRecvData �¼����жϽ�����һ���������ݰ���,'#13#10
//      + '���� TRecvHelper.ClearData(helper) ����ѽ��յ�����!');

  end;

end;

//��ɶ˿ڿ�ʼ���յ�һ����,��ʵֻ��һ���ط�����
//function RecvNewBuf(Socket: TSocket; OuterFlag:Integer; var PerIoData:LPPER_IO_OPERATION_DATA):Boolean;

function TRecvHelper.CreateRecvHelperIoData(Socket: TSocket):LPPER_IO_OPERATION_DATA;
var
  PerIoData : LPPER_IO_OPERATION_DATA;//�������Լ��õ���ʱ����
begin
  Result := nil;

  PerIoData := nil;


  //����һ������IO���ݽṹ�����н�PerIoData.BytesSEND ��PerIoData.BytesRECV �����ó�0��˵���ˡ���IO���ݽṹ�����������ܵġ�
  PerIoData := LPPER_IO_OPERATION_DATA(IocpAlloc(sizeof(PER_IO_OPERATION_DATA)));
  if (PerIoData = nil) then
  begin
    PerIoData := nil; //û��ȡ���ڴ�
    //Sleep(1);//test//�ŵ��ⲿ������ sleep �������
    exit;
  end;

  ZeroMemory(@PerIoData.Overlapped, sizeof(OVERLAPPED));
  //PerIoData.BytesSEND := 0;
  //PerIoData.BytesRECV := 0;
  PerIoData.BufInfo.len := DATA_BUFSIZE;//1024;
  PerIoData.BufInfo.buf := @PerIoData.Buf;
  PerIoData.OpCode := 0;//�����õ�
  PerIoData.Socket := Socket;//�����ؼ��ֵĻ�,���������ȫ
  //PerIoData.OuterFlag := OuterFlag;//�����ؼ��ֵĻ�,���������ȫ

  Result := PerIoData;

end;

function TRecvHelper.GetIoData(Socket: TSocket):LPPER_IO_OPERATION_DATA;
var
  PerIoData : LPPER_IO_OPERATION_DATA;//�������Լ��õ���ʱ����
begin
  Result := self.FPerIoData;

  PerIoData := self.FPerIoData;

  ZeroMemory(@PerIoData.Overlapped, sizeof(OVERLAPPED));
  //PerIoData.BytesSEND := 0;
  //PerIoData.BytesRECV := 0;
  PerIoData.BufInfo.len := DATA_BUFSIZE;//1024;
  PerIoData.BufInfo.buf := @PerIoData.Buf;
  PerIoData.OpCode := 0;//�����õ�
  PerIoData.Socket := Socket;//�����ؼ��ֵĻ�,���������ȫ
  //PerIoData.OuterFlag := OuterFlag;//�����ؼ��ֵĻ�,���������ȫ

  //--------------------------------------------------
  FPerIoData.atWork := 0;
  FPerIoData.conFree := 0;

  Result := PerIoData;

end;


end.
 
