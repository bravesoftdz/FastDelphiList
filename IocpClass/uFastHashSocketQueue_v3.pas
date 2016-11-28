unit uFastHashSocketQueue_v3;

//uFastHashSocketQueue.pas 替代版本,换用可遍历的 hashmap 实现

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms, IniFiles,
  winsock2_v2,{WinSock,}ComCtrls, Contnrs, fsHashMap, fsIntegerHashList, uTIntegerHash,

  //Contnrs,//TQueue 性能不行
  Dialogs;

const
  MaxSocketListSize = 65536;//必须是 2 的 n 次方,否则 hash 函数达不到高速的意义,具体解释见 hash 理论

type
  //PSocketRecord = ^TSocketRecord;
  TSocketRecord = record
    IsSet:Byte;//是否已经使用了

    key:Integer;//其实就是 socket 本身,也就是数据
    data:Pointer;//Integer;//数据,指向一个外部定义的对象
  end;

type
  PSocketList = ^TSocketList;//^TStringItemList;
  TSocketList = array[0..MaxSocketListSize] of TSocketRecord;



type
  TFastHashSocketQueue = class(TObject)
  private
    FCount: Integer;
    //FData:TStringHash;
    // 2015/4/27 14:20:49 换用可遍历的实现
    FData:TIntegerHashList;


    function CheckIndex(index:integer):Boolean;
    //参数 var 是为了方便测试
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
    //从数组索引中取一个,只用于遍历
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

  FData := TIntegerHashList.Create(65535);//容量修改为 65535 的话性能会有巨大的提高

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
  //这里自己 hash 了,所以直接返回就行
  Result := socket;

  Exit;
  //--------------------------------------------------

  //return h & (length-1);

  h := socket;
  //h := BKDRHash_Int(socket);//test

  len := MaxSocketListSize;//必须是 2 的 n 次方

  //Result := h;//其实这样在目前的 win32 的 socket 环境下也行
  Result := h and (len - 1);

//  Result := 0;//test 测试节点重复使用时
//  socket := 0;//test 测试节点重复使用时
end;


//从数组索引中取一个,只用于遍历
function TFastHashSocketQueue.GetItemFromIndex(arrIndex:Integer):Pointer;
//  var data: Pointer): Boolean;
var
  index:Integer;
begin
  Result := nil;

  index := FData.Items[arrIndex];//FData.ValueOf(socket);


//  if index = -1 then
//  begin
//    //MessageBox(0, 'hash 冲突', '', 0);//hash 失败,其实是不可能的
//    Result := False;
//    Exit;
//  end;

//遍历的不应该出错

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
    //MessageBox(0, 'hash 冲突', '', 0);//hash 失败,其实是不可能的
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

