
unit uMemLeaks;


//EurekaLog �� ELeaks.pas ���Ǻܿɿ�,�����Լ����һ���ظ��ͷ�
//��Ϊ���Ⱥ�С��ֱ���� delphi ��ϲ���õ� TRTLCriticalSection ʵ����������,��ǿ�ɿ���

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  ComCtrls, Contnrs, fsHashMap,
  uThreadLock,
  Dialogs;


procedure AddMem(mem:Integer);

//lastpos �� 0,1 ��������;,����Ҫ���ڵ��� 2,Ҳ�����Ǹ���
procedure DelMem(mem:Integer; lastpos:Integer);
//һ���򵥵ļ��ָ���Ƿ�Ϸ�
function CheckMem(mem:Integer):Boolean;



implementation

uses iocpInterface;

const
  //�Ƿ���ʾ���ɾ��λ��,��ʽ������Ҫ����,��Ϊ������������
  //GShowDebugPos:Boolean = True;
  GShowDebugPos:Boolean = False;

var
  GMemList:THashMap;
  GMemLock:TRTLCriticalSection;  //ȫ���ٽ�������

//
procedure AddMem(mem:Integer);
begin
  EnterCriticalSection(GMemLock);    //�����ٽ���
  try
    GMemList.Add(mem, 1);

  finally
    LeaveCriticalSection(GMemLock);  //�뿪�ٽ���
  end;
end;

//lastpos �� 0,1 ��������;,����Ҫ���ڵ��� 2,Ҳ�����Ǹ���
procedure DelMem(mem:Integer; lastpos:Integer);
var
  v:Integer;
begin
  EnterCriticalSection(GMemLock);    //�����ٽ���
  try
    v := GMemList.ValueOf(mem);
    //if GMemList.ValueOf(mem) = -1 then
    if v = -1 then
    begin
      MessageBox(0, '��Чָ��,�������ظ��ͷ�', '', 0);
      Exit;
    end;
    
    if v > 255 then
    begin
      MessageBox(0, PChar('��Чָ��,�������ظ��ͷ�.���λ��:' + pchar(v)), '', 0);
      Exit;
    end;

    if v > 1 then
    begin
      MessageBox(0, PChar('��Чָ��,�������ظ��ͷ�.���λ��:' + inttostr(v)), '', 0);
      Exit;
    end;

    if lastpos <= 1 then
    begin
      MessageBox(0, '���λ�ò���С�ڻ����1', '', 0);
      Exit;
    end;


    //GMemList.Modify(mem, v+1);//������治ɾ���Ļ����Լ���ظ��ͷ��˶��ٴ�
    GMemList.Modify(mem, lastpos);//��¼����ͷŵ�λ��
    if GShowDebugPos = False then GMemList.Remove(mem);//ע�͵�������Բ鿴�ظ��ͷŵĵط�

  finally
    LeaveCriticalSection(GMemLock);  //�뿪�ٽ���
  end;
end;

//һ���򵥵ļ��ָ���Ƿ�Ϸ�
function CheckMem(mem:Integer):Boolean;
var
  v:Integer;
begin
  Result := True;
  v := 0;

  EnterCriticalSection(GMemLock);    //�����ٽ���
  try
    v := GMemList.ValueOf(mem);
    //if GMemList.ValueOf(mem) = -1 then
    if v = -1 then
    begin
      Result := False;
//      MessageBox(0, '��Чָ��,�������ڴ��Ѿ��ƻ�.������������.', '', 0);
//      Exit;
    end;

  finally
    LeaveCriticalSection(GMemLock);  //�뿪�ٽ���
  end;

  //�ŵ�������������ʾ
  if v = -1 then
  begin
    MessageBox(0, 'CheckMem: ��Чָ��,�������ڴ��Ѿ��ƻ�.������������.', '', 0);
    Exit;
  end;
  

end;


var
  i:Integer;
  PerIoData:LPPER_IO_OPERATION_DATA;

initialization

  InitializeCriticalSection(GMemLock);  //��ʼ��
  GMemList := THashMap.Create;

finalization
  if DebugHook<>0 then if GMemList.Count>0 then MessageBox(0, '��δ�ͷŵ��ڴ�', 'uMemLeaks.pas', 0);

  //--------------------------------------------------
  //test ֻ�ǲ��Կ�����ʲô�����ڴ�û���������

  for i := 0 to GMemList.Count-1 do
  begin
    PerIoData := LPPER_IO_OPERATION_DATA(GMemList.Keys[i]);
    PerIoData.TickCount := 0;
    //������������,����б��������ٵ�//IocpFree(PerIoData, 4);//test

    //test ֱ�Ӽ�鿴��
    if CheckPerIoDataComplete(PerIoData) then
    begin
      IocpFree(PerIoData, 4);//���� iocp �еľͿ���ֱ���ͷ���

    end;


  end;

  if DebugHook<>0 then if GMemList.Count>0 then MessageBox(0, '��δ�ͷŵ��ڴ�2', 'uMemLeaks.pas', 0);


  //--------------------------------------------------

  if GShowDebugPos = True then MessageBox(0, 'GShowDebugPos ����ʱ��δ�ͷŵ��ڴ���������,�ɽ���', 'uMemLeaks.pas', 0);
  GMemList.Free;
  DeleteCriticalSection(GMemLock);   //ɾ��


end.
