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
  winsock2,WinSock,ComCtrls,Contnrs, //iocpInterface,
  uThreadLock,
  Math,
  Dialogs;

type
  TRecvHelper = class(TObject)
  private
    // 2015/4/2 14:20:49 ��һ�����Ա�־,�����ڴ��쳣ʱ����Ƿ��Ƿǳ��ڴ�
    iDebugTag:Byte;

  public
    FMemory:TMemoryStream;
    OuterFlag:Integer;//�����ⲿ���ӱ�־//Ϊ����ԭ�� iocp �ӿ�,�����������̺߳����д��ݵĲ���
    //��������ʱȡ�õ�,��Ϊ���ý������ֹ��ܵĻ����ֻ�ռ�� OuterFlag, ����������һ���ط������ⲿ���ݽ����� OuterFlag
    
    constructor Create; //override;
    destructor Destroy; override;


    procedure OnRecv(Socket: TSocket; buf:PChar; bufLen:Integer);//���ջ���
    //����ѽ��յ�����//dataLen ���Ѵ�������ݳ���,��Ҫ�ӻ�������ɾ����ô��,�ϲ�Ӧ��Ӧ���ж��Ѿ����յ��������Ƿ��ж����
    //Ӧ�������ܵĴ�������Ȼ��ɾ�����Ѵ���������ݳ���
    class procedure ClearData(helper:TRecvHelper; dataLen:Integer);
  end;

implementation

{ TRecvHelper }

//��������,����õ��Ĳ�������,�ͷ������˵Ĵ�����һ����
//class procedure TThreadSafeSocket.ClearData(var FMemory:TMemoryStream; dataLen:Integer);
procedure ClearData_Fun(var FMemory:TMemoryStream; dataLen:Integer);
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

constructor TRecvHelper.Create;
begin
  inherited;
  
  FMemory:=TMemoryStream.Create;//���ջ���
  FMemory.SetSize(1024);// 2015/4/7 14:55:33 test Ԥ�����ڴ�������?
  FMemory.SetSize(0);// 2015/4/7 14:55:33 test Ԥ�����ڴ�������?
  iDebugTag := 111; // 2015/4/2 14:22:04 ��һ�����Ա�־,�����ڴ��쳣ʱ����Ƿ��Ƿǳ��ڴ�
end;

destructor TRecvHelper.Destroy;
begin
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

end.
 
