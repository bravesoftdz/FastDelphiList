unit uFastHashSocketQueue_v2;

//uFastHashSocketQueue.pas 的安全版本,速度不如,不过可用于安全调试

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms, IniFiles,
  winsock2_v2,{WinSock,}ComCtrls,Contnrs,
  
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
    FData:TStringHash;


    function CheckIndex(index:integer):Boolean;
    //参数 var 是为了方便测试
    function GetIndex(var socket: TSocket): Integer;

    function SetItemBak(socket: TSocket; data:Pointer): Boolean;
    function DeleteItemBak(socket: TSocket): Boolean;
    function GetItemBak(socket: TSocket; var data:Pointer): Boolean;
  public
    property Count:Integer read FCount;

    constructor Create; //override;
    destructor Destroy; override;

    //注意这个函数最开始就是可重入的,所以一定要在使用前判断是否原来有相同的 socket 如果有的话要先删除
    function SetItem(socket: TSocket; data:Pointer): Boolean;
    function DeleteItem(socket: TSocket): Boolean;
    //如果多次设置,这里只会取到其中一个,至于是第一个还是最后一个要看具体实现类,而且某些类的实现还会异常,所以应当相同 key 只设置一次
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

  FData := TStringHash.Create(65535);//容量修改为 65535 的话性能会有巨大的提高

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

function TFastHashSocketQueue.GetItem(socket: TSocket;
  var data: Pointer): Boolean;
var
  index:Integer;
begin
  Result := True;

  index := FData.ValueOf(IntToStr(socket));// 2015/4/23 17:16:47 delphi 的 hash 实现是允许重入的,所以在写入时一定要判断相同的 socket 是否有值了,否则这里取到的只是第一个值而已


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

  FData.Add(IntToStr(socket), Integer(data));

  Inc(FCount);

end;

function TFastHashSocketQueue.SetItemBak(socket: TSocket;
  data: Pointer): Boolean;
begin

end;

end.

