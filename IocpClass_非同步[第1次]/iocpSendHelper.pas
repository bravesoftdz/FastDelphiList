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

  public
    //FMemory:TMemoryStream;
    //OuterFlag:Integer;//�����ⲿ���ӱ�־//Ϊ����ԭ�� iocp �ӿ�,�����������̺߳����д��ݵĲ���
    //��������ʱȡ�õ�,��Ϊ�������ֹ��ܵĻ����ֻ�ռ�� OuterFlag, ����������һ���ط������ⲿ���ݽ����� OuterFlag
    socket:TSocket;
    sendDataList:TList;//Ҫ���͵������б�,ÿ������ MakeSendHelperIoData ��� PerIoData, ��ֻ���ɶ���δ����
    threadLock:TThreadLock;//�߳���,�ⲿ�����,��Ҫ�Լ�����

    constructor Create; //override;
    destructor Destroy; override;

    function PopSendData(var PerIoData : LPPER_IO_OPERATION_DATA):Boolean;//ȡ��һ��Ҫ���͵����� FIFO ����

  end;
  
type
  //��Ӧ io ���� ExtInfo 
  PSendPack = ^TSendPack;
  TSendPack = record//ֻ���ڳ����д���,û�й�����,���Բ���ѹ���ṹ��
    Data:pchar;         //����ָ��
    DataLen:Integer;    //���ݳ���
    SendLen:Integer;    //�Ѿ����͵ĳ���
  end;

//����һ�������õ� io �ṹ
function MakeSendHelperIoData(Socket: TSocket; buf:PChar; bufLen:Integer; OuterFlag:Integer):LPPER_IO_OPERATION_DATA;
//�ͷ� io �ṹ
procedure FreeSendHelperIoData(PerIoData : LPPER_IO_OPERATION_DATA);

//���õ�һ������ io ���ݽṹ
procedure IoDataGetFirst(PerIoData : LPPER_IO_OPERATION_DATA);
//ȡ��һ��Ҫ���͵�����Ҫ��� io �ṹ//BytesTransferred �ǵ�ǰ���ͳɹ����ֽ���,��ʵ��Ŀǰ���㷨���� DATA_BUFSIZE
function IoDataGetNext(PerIoData : LPPER_IO_OPERATION_DATA; BytesTransferred:Integer):Boolean;

//һ����������,ֻ�����ڻ��� iocp ��ĵط�
procedure SendData(Socket: TSocket; buf: PChar; bufLen: Integer; OuterFlag: Integer);



implementation

procedure SendData(Socket: TSocket; buf: PChar; bufLen: Integer; OuterFlag: Integer);
var
  PerIoData : LPPER_IO_OPERATION_DATA;
begin
  //SendBuf(Socket, buf, bufLen, OuterFlag, );
  PerIoData := MakeSendHelperIoData(Socket, buf, bufLen, OuterFlag);

  if PerIoData=nil then Exit;

  SendBuf(Socket, PerIoData);

end;

//����һ�������õ� io �ṹ
function MakeSendHelperIoData(Socket: TSocket; buf:PChar; bufLen:Integer; OuterFlag:Integer):LPPER_IO_OPERATION_DATA;
var
    PerIoData : LPPER_IO_OPERATION_DATA;//�������Լ��õ���ʱ����
    SendBytes:DWORD;
    Flags:DWORD;
    userData:PChar;
    pack:PSendPack;
begin
    result := nil;

    //--------------------------------------------------
    //1.�ȸ����ⲿ����
    userData := PChar(GlobalAlloc(GPTR, bufLen));//��Ϊ��������һ������,������Ҫ iocp ����ɾ��,ͬʱ�ϲ�Ӧ�ÿ��������ͷ���Դ
    if (userData = nil) then
    begin
      MessageBox(0, 'GlobalAlloc', '�������ڲ�����', 0);
      exit;
    end;
    CopyMemory(userData, buf, bufLen);

    //--------------------------------------------------
    //2.������չ��Ϣ
    pack := PSendPack(GlobalAlloc(GPTR, SizeOf(TSendPack)));//���Ҳ��Ҫ iocp ����ɾ��
    if (pack = nil) then
    begin
      MessageBox(0, 'GlobalAlloc', '�������ڲ�����(GlobalAlloc)', 0);
      exit;
    end;
    pack.Data := userData;
    pack.DataLen := bufLen;
    pack.SendLen := 0;

    //--------------------------------------------------

    //����һ������IO���ݽṹ�����н� PerIoData.OpCode ���ó�1��˵���ˡ���IO���ݽṹ�����������͵ġ�
    PerIoData := LPPER_IO_OPERATION_DATA(GlobalAlloc(GPTR, sizeof(PER_IO_OPERATION_DATA)));
    if (PerIoData = nil) then
    begin
      MessageBox(0, 'GlobalAlloc', '�������ڲ�����(GlobalAlloc)', 0);
      exit;
    end;

    //if bufLen>DATA_BUFSIZE then Exit;//���ܳ��� iocp �����С//ÿ��ֻ����һ����,�������ڿ��Գ�����������С

    ZeroMemory(@PerIoData.Overlapped, sizeof(OVERLAPPED));
    PerIoData.BytesSEND := 0;
    PerIoData.BytesRECV := 0;
    //PerIoData.DataBuf.len := bufLen;//1024;//����ȡ�������ḳֵ��
    //PerIoData.DataBuf.buf := @PerIoData.Buf;//����ȡ�������ḳֵ��
    PerIoData.OpCode := 1;//��־,�����õ�
    PerIoData.Socket := Socket;//�����ؼ��ֵĻ�,���������ȫ
    PerIoData.OuterFlag := OuterFlag;
    PerIoData.ExtInfo := Integer(pack);//ExtInfo;
    Flags := 0;

    //--------------------------------------------------
    IoDataGetFirst(PerIoData);//ȡ��һ����

    //--------------------------------------------------
    {
    //�ôˡ���IO���ݽṹ��������Acceptsc�׽��ֵ����ݡ�
    //if (WSARecv(Acceptsc, @(PerIoData.DataBuf), 1, @RecvBytes, @Flags,@(PerIoData.Overlapped), nil) = SOCKET_ERROR) then
    if (WSASend(Socket, @(PerIoData.DataBuf), 1, @SendBytes, Flags, @(PerIoData.Overlapped), nil) = SOCKET_ERROR) then
    begin
       if (WSAGetLastError() <> ERROR_IO_PENDING) then
       begin
          exit;
       end
    end;
    }

    result := PerIoData;
end;

//�ͷ� io �ṹ
procedure FreeSendHelperIoData(PerIoData : LPPER_IO_OPERATION_DATA);
var
  pack:PSendPack;

begin
  if PerIoData.OpCode = 0 then Exit;//���ջ�����û����չ���ݵ�

  //--------------------------------------------------
  //ȡ��չ��Ϣ
  pack := PSendPack(PerIoData.ExtInfo);//���Ҳ��Ҫ iocp ����ɾ��
  if (pack = nil) then
  begin
     exit;
  end;
  //--------------------------------------------------


  //GlobalFree(DWORD(PerIoData));//����ɾ�� io �ṹ����,ԭ�е� iocp �ܹ��Ѿ�ɾ����,ֻ��Ҫɾ����չ����//��,����ͳһɾ����

  GlobalFree(DWORD(pack.Data));
  GlobalFree(DWORD(pack));

  GlobalFree(DWORD(PerIoData));

end;

//���õ�һ������ io ���ݽṹ
procedure IoDataGetFirst(PerIoData : LPPER_IO_OPERATION_DATA);
var
    pack:PSendPack;
begin
    //--------------------------------------------------
    //ȡ��չ��Ϣ
    pack := PSendPack(PerIoData.ExtInfo);//���Ҳ��Ҫ iocp ����ɾ��
    if (pack = nil) then
    begin
       exit;
    end;
    //--------------------------------------------------

    //���ܳ��� iocp �����С
    //if pack.DataLen>DATA_BUFSIZE then PerIoData.DataBuf.len := DATA_BUFSIZE;

    PerIoData.DataBuf.len := Min(pack.DataLen, DATA_BUFSIZE);
    PerIoData.DataBuf.buf := pack.Data;

    ZeroMemory(@PerIoData.Overlapped, sizeof(OVERLAPPED));
    PerIoData.BytesSEND := 0;
    PerIoData.BytesRECV := 0;
//    PerIoData.DataBuf.len := bufLen;//1024;
//    PerIoData.DataBuf.buf := @PerIoData.Buf;
//    PerIoData.OpCode := 1;//��־,�����õ�
//    PerIoData.Socket := Socket;//�����ؼ��ֵĻ�,���������ȫ
//    PerIoData.OuterFlag := OuterFlag;
//    PerIoData.ExtInfo := ExtInfo;

    //--------------------------------------------------
    //�������
    //�����ٸ���,ֱ��ʹ���ϲ�Ӧ�õ� CopyMemory(PerIoData.DataBuf.buf, buf, bufLen);
    PerIoData.BufLen := pack.DataLen;//pack.DataLen - pack.SendLen;//bufLen;
    //--------------------------------------------------
end;


//ȡ��һ��Ҫ���͵�����Ҫ��� io �ṹ//BytesTransferred �ǵ�ǰ���ͳɹ����ֽ���,��ʵ��Ŀǰ���㷨���� DATA_BUFSIZE
function IoDataGetNext(PerIoData : LPPER_IO_OPERATION_DATA; BytesTransferred:Integer):Boolean;
var
  pack:PSendPack;
  curDataPoint:PChar;//��ǰҪ���͵����ݵ�λ��
  remainlen:Integer;//ʣ������ݳ���
begin
  result := False;

  //--------------------------------------------------
  //ȡ��չ��Ϣ
  pack := PSendPack(PerIoData.ExtInfo);//���Ҳ��Ҫ iocp ����ɾ��
  if (pack = nil) then
  begin
     exit;
  end;

  pack.SendLen := pack.SendLen + BytesTransferred;
  curDataPoint := pack.Data + pack.sendLen;
  remainlen := pack.DataLen - pack.SendLen;

  //û��Ҫ���͵İ���,��ȫ�����������
  if remainlen <= 0 then
  begin
    remainlen := 0;//��ȫ���
    result := False;
    Exit;
  end;
  //--------------------------------------------------

  //���ܳ��� iocp �����С
  //if pack.DataLen>DATA_BUFSIZE then PerIoData.DataBuf.len := DATA_BUFSIZE;

  PerIoData.DataBuf.len := Min(remainlen, DATA_BUFSIZE);
  PerIoData.DataBuf.buf := curDataPoint;

  ZeroMemory(@PerIoData.Overlapped, sizeof(OVERLAPPED));
  PerIoData.BytesSEND := 0;
  PerIoData.BytesRECV := 0;
//    PerIoData.DataBuf.len := bufLen;//1024;
//    PerIoData.DataBuf.buf := @PerIoData.Buf;
//    PerIoData.OpCode := 1;//��־,�����õ�
//    PerIoData.Socket := Socket;//�����ؼ��ֵĻ�,���������ȫ
//    PerIoData.OuterFlag := OuterFlag;
//    PerIoData.ExtInfo := ExtInfo;

  //--------------------------------------------------
  //�������
  //�����ٸ���,ֱ��ʹ���ϲ�Ӧ�õ� CopyMemory(PerIoData.DataBuf.buf, buf, bufLen);
  PerIoData.BufLen := pack.DataLen - pack.SendLen;//bufLen;
  //--------------------------------------------------

  result := True;
  
end;

{ TSendHelper }

constructor TSendHelper.Create;
begin
  sendDataList := TList.Create;
  
end;

destructor TSendHelper.Destroy;
var
  i:Integer;
  PerIoData: LPPER_IO_OPERATION_DATA;
begin
  for i := 0 to sendDataList.Count-1 do
  begin
    PerIoData := sendDataList[i];
    //GlobalFree(DWORD(PerIoData));
    FreeSendHelperIoData(PerIoData);

  end;

  sendDataList.Free;

  inherited;
end;

function TSendHelper.PopSendData(
  var PerIoData: LPPER_IO_OPERATION_DATA): Boolean;
begin
  Result := False;
  if sendDataList.Count = 0 then Exit;

  PerIoData := sendDataList[0];
  sendDataList.Delete(0);

  Result :=True;
end;

end.
