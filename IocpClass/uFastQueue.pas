unit uFastQueue;

//用来保存 accept 得到的 socket 句柄

{TQueue 是基于 TList 的.

TList 类实际上就是一个可以存储指针的容器类，提供了一系列的方法和属性来添加，删除，
重排，定位，存取和排序容器中的类，它是基于数组的机制来实现的容器，比较类似于C++中
的Vector和Java中的ArrayList，TList 经常用来保存一组对象列表，基于数组实现的机制使
得用下标存取容器中的对象非常快，但是随着容器中的对象的增多，插入和删除对象速度会
直线下降，因此不适合频繁添加和删除对象的应用场景.
}

{所以需要重写一个高速的先进先出队列,实现思想是:
1.一次性开辟所需内存,所以直接使用数组.
2.一个读取位置一个写入位置,当写入位置到了数组末尾时从头开始.
3.如果当前写入位置超过了读取位置,那么就是空间已满,需要等待读取处理掉一些元素先.
}

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  winsock2,{WinSock,}ComCtrls,Contnrs,  
  uThreadLock,
  //Contnrs,//TQueue 性能不行
  Dialogs;

type
  PIntList = ^TIntList;//^TStringItemList;
  TIntList = array[0..MaxListSize] of Integer;


type
  TFastQueue = class(TObject)
  private
    FData:PIntList;//PINT;
    FReadPos:Integer;
    FWritePos:Integer;
    MaxCount:Integer;
    FCount: Integer;

    function GetNextPos(cur: Integer): Integer;
    function GetNextWritePos: Integer;
    function GetNextReadPos: Integer;

  public
    property Count:Integer read FCount;

    constructor Create(maxCount:Integer); //override;
    destructor Destroy; override;

    function Write(value:Integer):Boolean;
    function Read(var value:Integer):Boolean;

  end;

implementation

{ TFastQueue }

constructor TFastQueue.Create(maxCount:Integer);
begin
  inherited Create;

  Self.MaxCount := maxCount;
  FData := GetMemory(MaxCount * SizeOf(Integer));
  FReadPos := 0;
  FWritePos := 0;
  FCount := 0;

end;

//取下一个位置
function TFastQueue.GetNextPos(cur:Integer):Integer;
begin
  Inc(cur);
  if cur >= MaxCount then cur := 0;
  Result := cur;
end;

//可检查是否已经写满了//正常情况下返回下一个写入位置
function TFastQueue.GetNextWritePos:Integer;
var
  tmp:Integer;
begin
  result := -1;
  tmp := GetNextPos(FWritePos);
  if tmp = FReadPos then
  begin
    Result := -1;//test
    exit;//队列已经满了
  end;

  Result := tmp;
end;

//可检查是否还有数据可读取//正常情况下返回下一个读取位置
function TFastQueue.GetNextReadPos:Integer;
var
  tmp:Integer;
begin
  result := -1;

  if FReadPos = FWritePos then exit;//队列已经满了
  

  tmp := GetNextPos(FReadPos);
//  if tmp = FWritePos then exit;//队列已经满了

  Result := tmp;
end;


destructor TFastQueue.Destroy;
begin
  FreeMem(FData);

  inherited;
end;


function TFastQueue.Read(var value: Integer): Boolean;
var
  pos:Integer;
begin
  Result := False;
  pos := GetNextReadPos;
  if pos = -1 then Exit;

  value := FData[pos];
  FReadPos := pos;
  Dec(FCount);

  Result := True;
end;

function TFastQueue.Write(value: Integer): Boolean;
var
  pos:Integer;
begin
  Result := False;
  pos := GetNextWritePos;
  if pos = -1 then//队列写满了
  begin
    Result := False;//test
    Exit;
  end;   

  FData[pos] := value;
  FWritePos := pos;
  Inc(FCount);

  Result := True;
end;


end.


