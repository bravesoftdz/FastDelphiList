unit uFastHashSocketQueue_v3;

//uFastHashSocketQueue.pas ����汾,���ÿɱ����� hashmap ʵ��

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms, IniFiles,
  winsock2_v2,{WinSock,}ComCtrls, Contnrs, fsHashMap, fsIntegerHashList, uTIntegerHash,

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
    //FData:TStringHash;
    // 2015/4/27 14:20:49 ���ÿɱ�����ʵ��
    FData:TIntegerHashList;


    function CheckIndex(index:integer):Boolean;
    //���� var ��Ϊ�˷������
    function GetIndex(var socket: TSocket): Integer;

    function SetItemBak(socket: TSocket; data:Pointer): Boolean;
    function DeleteItemBak(socket: TSocket): Boolean;
    function GetItemBak(socket: TSocket; var data:Pointer): Boolean;
  public
    function debug_count:Integer;

    property Count:Integer read FCount;

    constructor Create; //override;
    destructor Destroy; override;

    function SetItem(socket: TSocket; data:Pointer): Boolean;
    function DeleteItem(socket: TSocket): Boolean;
    function GetItem(socket: TSocket; var data:Pointer): Boolean;
    //������������ȡһ��,ֻ���ڱ���
    function GetItemFromIndex(arrIndex:Integer):Pointer;

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

  FData := TIntegerHashList.Create(65535);//�����޸�Ϊ 65535 �Ļ����ܻ��о޴�����

end;

function TFastHashSocketQueue.debug_count: Integer;
begin
  Result := Self.FData.Count;
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

  FData.Remove(socket);

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


//������������ȡһ��,ֻ���ڱ���
function TFastHashSocketQueue.GetItemFromIndex(arrIndex:Integer):Pointer;
//  var data: Pointer): Boolean;
var
  index:Integer;
begin
  Result := nil;

  index := FData.Items[arrIndex];//FData.ValueOf(socket);


//  if index = -1 then
//  begin
//    //MessageBox(0, 'hash ��ͻ', '', 0);//hash ʧ��,��ʵ�ǲ����ܵ�
//    Result := False;
//    Exit;
//  end;

//�����Ĳ�Ӧ�ó���

  //data := Pointer(index);
  Result := Pointer(index);


end;


function TFastHashSocketQueue.GetItem(socket: TSocket;
  var data: Pointer): Boolean;
var
  index:Integer;
begin
  Result := True;

  index := FData.ValueOf(socket);


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

  FData.Add(socket, Integer(data));

  Inc(FCount);

end;

function TFastHashSocketQueue.SetItemBak(socket: TSocket;
  data: Pointer): Boolean;
begin

end;

end.
