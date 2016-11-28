unit uFastHashSocketQueue_v2;

//uFastHashSocketQueue.pas �İ�ȫ�汾,�ٶȲ���,���������ڰ�ȫ����

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms, IniFiles,
  winsock2_v2,{WinSock,}ComCtrls,Contnrs,
  
  //Contnrs,//TQueue ���ܲ���
  Dialogs;

const
  MaxSocketListSize = 65536;//������ 2 �� n �η�,���� hash �����ﲻ�����ٵ�����,������ͼ� hash ����

type
  //PSocketRecord = ^TSocketRecord;
  TSocketRecord = record
    IsSet:Byte;//�Ƿ��Ѿ�ʹ����

    key:Integer;//��ʵ���� socket ����,Ҳ��������
    data:Pointer;//Integer;//����,ָ��һ���ⲿ����Ķ���
  end;

type
  PSocketList = ^TSocketList;//^TStringItemList;
  TSocketList = array[0..MaxSocketListSize] of TSocketRecord;



type
  TFastHashSocketQueue = class(TObject)
  private
    FCount: Integer;
    FData:TStringHash;


    function CheckIndex(index:integer):Boolean;
    //���� var ��Ϊ�˷������
    function GetIndex(var socket: TSocket): Integer;

    function SetItemBak(socket: TSocket; data:Pointer): Boolean;
    function DeleteItemBak(socket: TSocket): Boolean;
    function GetItemBak(socket: TSocket; var data:Pointer): Boolean;
  public
    property Count:Integer read FCount;

    constructor Create; //override;
    destructor Destroy; override;

    //ע����������ʼ���ǿ������,����һ��Ҫ��ʹ��ǰ�ж��Ƿ�ԭ������ͬ�� socket ����еĻ�Ҫ��ɾ��
    function SetItem(socket: TSocket; data:Pointer): Boolean;
    function DeleteItem(socket: TSocket): Boolean;
    //����������,����ֻ��ȡ������һ��,�����ǵ�һ���������һ��Ҫ������ʵ����,����ĳЩ���ʵ�ֻ����쳣,����Ӧ����ͬ key ֻ����һ��
    function GetItem(socket: TSocket; var data:Pointer): Boolean;
  end;

implementation

{ TFastHashSocketQueue }

function TFastHashSocketQueue.CheckIndex(index: integer): Boolean;
begin
  Result := True;
  
//  if (index < 0)or(index > MaxSocketListSize-1) then
//    Result := False;
end;

constructor TFastHashSocketQueue.Create;
begin
  inherited Create;

  FData := TStringHash.Create(65535);//�����޸�Ϊ 65535 �Ļ����ܻ��о޴�����

end;

function TFastHashSocketQueue.DeleteItem(socket: TSocket): Boolean;
var
  index:Integer;
  i:Integer;
begin
  Result := True;

  index := GetIndex(socket);
  if not CheckIndex(index) then
  begin
    Result := False;
    Exit;
  end;

  FData.Remove(IntToStr(socket));

  Dec(FCount);


end;

function TFastHashSocketQueue.DeleteItemBak(socket: TSocket): Boolean;
begin

end;

destructor TFastHashSocketQueue.Destroy;
begin

  FData.Free;
  //FreeAndNil(FData);

  inherited;
end;

function TFastHashSocketQueue.GetIndex(var socket: TSocket): Integer;
//function indexFor(h:Integer; length:Integer)
var
  h:Integer;
  len:Integer;
begin
  //�����Լ� hash ��,����ֱ�ӷ��ؾ���
  Result := socket;

  Exit;
  //--------------------------------------------------

  //return h & (length-1);

  h := socket;
  //h := BKDRHash_Int(socket);//test

  len := MaxSocketListSize;//������ 2 �� n �η�

  //Result := h;//��ʵ������Ŀǰ�� win32 �� socket ������Ҳ��
  Result := h and (len - 1);

//  Result := 0;//test ���Խڵ��ظ�ʹ��ʱ
//  socket := 0;//test ���Խڵ��ظ�ʹ��ʱ
end;

function TFastHashSocketQueue.GetItem(socket: TSocket;
  var data: Pointer): Boolean;
var
  index:Integer;
begin
  Result := True;

  index := FData.ValueOf(IntToStr(socket));// 2015/4/23 17:16:47 delphi �� hash ʵ�������������,������д��ʱһ��Ҫ�ж���ͬ�� socket �Ƿ���ֵ��,��������ȡ����ֻ�ǵ�һ��ֵ����


  if index = -1 then
  begin
    //MessageBox(0, 'hash ��ͻ', '', 0);//hash ʧ��,��ʵ�ǲ����ܵ�
    Result := False;
    Exit;
  end;

  data := Pointer(index);


end;

function TFastHashSocketQueue.GetItemBak(socket: TSocket;
  var data: Pointer): Boolean;
begin

end;

function TFastHashSocketQueue.SetItem(socket: TSocket;
  data: Pointer): Boolean;
begin

  FData.Add(IntToStr(socket), Integer(data));

  Inc(FCount);

end;

function TFastHashSocketQueue.SetItemBak(socket: TSocket;
  data: Pointer): Boolean;
begin

end;

end.

