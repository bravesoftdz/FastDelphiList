unit uFastHashSocketQueue;

//������ uFastQueue ,���� uFastQueue ֻ�� FIFO ����� hashmap
//��Ȼ���ֱ��ʹ�� TSocket ��Ϊ�����Ų�������,��Ȼ���� socket ֵ�Ƚ�С���й����� 66000 �� socket ֵ

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
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
    FData:PSocketList;//PINT;
    FReadPos:Integer;
    FWritePos:Integer;
    //MaxCount:Integer;
    FCount: Integer;
    FCountBak: Integer;//���ݶ����е���Ч����

    FBakList:PSocketList;//TList;//��ͻʱ�ı����б�,����Ǽ򵥵�˳���б�

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

    function SetItem(socket: TSocket; data:Pointer): Boolean;
    function DeleteItem(socket: TSocket): Boolean;
    function GetItem(socket: TSocket; var data:Pointer): Boolean;
  end;

implementation




{ TFastHashSocketQueue }

function TFastHashSocketQueue.CheckIndex(index: integer): Boolean;
begin
  Result := True;
  
  if (index < 0)or(index > MaxSocketListSize-1) then
    Result := False;

end;

//�ַ���Ϊ hash ��������ת��
function BKDRHash(const str:string):Integer;
var
  i:Integer;
begin
  Result := 0;

  for i := 1 to Length(str) do
  begin
    Result := Result * 131 + ord(str[i]);//java ������ 31// Ҳ���Գ���31��131��1313��13131��131313..
  end;

  result := result and $7FFFFFFF;//��Щ�㷨�������,��Ϊ��ȥ������λ?

end;

//���������Ͽ���
function BKDRHash_Int(const Data:Integer):Integer;
var
  i:Integer;
  p:PByte;
begin
  Result := 0;
  p := @data;

  for i := 0 to 3 do
  begin
    Result := Result * 131 + p^;//java ������ 31// Ҳ���Գ���31��131��1313��13131��131313..
    Inc(p);
  end;

  result := result and $7FFFFFFF;//��Щ�㷨�������,��Ϊ��ȥ������λ?

end;


function TFastHashSocketQueue.GetIndex(var socket:TSocket):Integer;
//function indexFor(h:Integer; length:Integer)
var
  h:Integer;
  len:Integer;
begin
  //return h & (length-1);

  h := socket;
  //h := BKDRHash_Int(socket);//test

  len := MaxSocketListSize;//������ 2 �� n �η�

  //Result := h;//��ʵ������Ŀǰ�� win32 �� socket ������Ҳ��
  Result := h and (len - 1);

//  Result := 0;//test ���Խڵ��ظ�ʹ��ʱ
//  socket := 0;//test ���Խڵ��ظ�ʹ��ʱ
end;


constructor TFastHashSocketQueue.Create();
begin
  inherited Create;

  //FData := GetMemory(MaxCount * SizeOf(Integer));
  //FData := GetMemory(MaxSocketListSize * SizeOf(TSocketRecord));
  FData := AllocMem(MaxSocketListSize * SizeOf(TSocketRecord));//���� GetMem

  FBakList := AllocMem(MaxSocketListSize * SizeOf(TSocketRecord));//���� GetMem

//  FReadPos := 0;
//  FWritePos := 0;
  FCount := 0;
  FCountBak := 0;
end;

destructor TFastHashSocketQueue.Destroy;
begin
  FreeMem(FData);
  FreeMem(FBakList);


  inherited;
end;

function TFastHashSocketQueue.GetItem(socket: TSocket; var data:Pointer): Boolean;
var
  index:Integer;
begin
  Result := True;
  index := GetIndex(socket);
  if not CheckIndex(index) then
  begin
    Result := False;
    Exit;
  end;

  if (FData[index].key <> socket) then//hash ��ͻ
  begin
    if GetItemBak(socket,data) = False then
    begin
      //MessageBox(0, 'hash ��ͻ', '', 0);//hash ʧ��,��ʵ�ǲ����ܵ�
      Result := False;
    end;

    Exit;
  end;

  data := FData[index].data;

  if FData[index].IsSet = 0 then
  begin
    Result := False;
    Exit;
  end;


end;

function TFastHashSocketQueue.SetItem(socket: TSocket; data:Pointer): Boolean;
var
  index:Integer;
begin
  Result := True;

  index := GetIndex(socket);
  if not CheckIndex(index) then
  begin
    Result := False;
    Exit;
  end;

  if (FData[index].IsSet = 1) then//hash ��ͻ
  begin
    if (FData[index].key = socket) then//�ظ�������//������,������һ��
    begin
      MessageBox(0, PChar('�ظ�����,����ɾ��ԭ����ֵ. index=' + inttostr(index) + ' socket=' + inttostr(socket) + ' key=' + inttostr(FData[index].key)), '', 0);//hash ʧ��,��ʵ�ǲ����ܵ�
      Result := False;
      Exit;
    end;
    
    //��ͻ��,�ñ��ݱ���
    if SetItemBak(socket, data) = False then
    begin
      MessageBox(0, PChar('hash ��ͻ ' + inttostr(index) + ' socket=' + inttostr(socket) + ' key=' + inttostr(FData[index].key)), '', 0);//hash ʧ��,��ʵ�ǲ����ܵ�
      Result := False;
    end;

    Exit;
  end;

  FData[index].data := data;
  FData[index].key := socket;
  FData[index].IsSet := 1;

  Inc(FCount);
end;

//��ʵֻ������һ����־,�����޸�
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

  if (FData[index].key <> socket) then//hash ��ͻ
  begin
    if DeleteItemBak(socket) = False then
    begin
      MessageBox(0, 'hash ��ͻ', '', 0);//hash ʧ��,��ʵ�ǲ����ܵ�//���п��ܲ�����
      Result := False;
    end;

    Exit;
  end;


  FData[index].data := nil;//data;
  FData[index].key := 0;//socket;
  FData[index].IsSet := 0;

  Dec(FCount);
end;


function TFastHashSocketQueue.DeleteItemBak(socket: TSocket): Boolean;
var
  index:Integer;
  i:Integer;
begin
  Result := False;
  for i := 0 to MaxSocketListSize-1 do
  begin
    if FBakList[i].key = socket then
    begin
      FBakList[i].data := nil;//data;
      FBakList[i].key := 0;//socket;
      FBakList[i].IsSet := 0;

      Dec(FCount);
      Dec(FCountBak);

      Result := True;

      Break;
    end;
  end;

end;

function TFastHashSocketQueue.GetItemBak(socket: TSocket;
  var data: Pointer): Boolean;
var
  index:Integer;
  i:Integer;
  setcount:Integer;//���ҵ��е�ֵ�ĸ���
begin
  Result := False;
  setcount := 0;
  
  for i := 0 to MaxSocketListSize-1 do
  begin
    if setcount = FCountBak then Break;//Ϊ���ٶ�ֻ�� FCountBak ����Чֵ
    if FBakList[i].IsSet = 1 then Inc(setcount);

    if (FBakList[i].key = socket) then
    begin
      data := FBakList[i].data;

      Result := True;

      Break;
    end;

  end;

end;

function TFastHashSocketQueue.SetItemBak(socket: TSocket;
  data: Pointer): Boolean;
var
  index:Integer;
  i:Integer;
begin
  Result := False;
  for i := 0 to MaxSocketListSize-1 do
  begin
    if (FBakList[i].IsSet = 0) then//�ҵ���һ����λ�����,���õ����к���
    begin
      FBakList[i].data := data;
      FBakList[i].key := socket;
      FBakList[i].IsSet := 1;

      Inc(FCount);
      Inc(FCountBak);

      Result := True;

      Break;
    end;
  end;


end;

end.
