
unit fsIntegerHashList;

//带遍历的 hash 整数 key 列表//基本上等同于传统 C++ 意义上的 hashmap,但由于象 multimap 一样允许多键值,所以插入前应当判断是否有相同的键了
//从传统意义的 hashmap 来说应当是自己判断重复的,不过为了兼容 delphi 原来的 TStringHash 还是这样好了,而且尽量地少修改原算法代码

{$R-,T-,H+,X+}
//Range Checking                    {$R}
//Typed @ Operator                  {$T}
//Huge Strings                      {$H}
//Extended Syntax                   {$X}

interface

uses SysUtils, Classes, fsList, Dialogs;

//只修改 TStringHash 的类型,不要改动其他的//在 uTIntegerHash 的基础上加了 TFastList 的高速遍历列表而已,其实现是在节点中加了个其在遍历列表中的索引//其实用标准 TList 实现并且只替换最后一个元素也是一样的

type
  { TStringHash - used internally by TMemIniFile to optimize searches. }

  PPHashItem = ^PHashItem;
  PHashItem = ^THashItem;
  THashItem = record
    Next: PHashItem;
    //Key: string;
    Key: Integer;//clq 就是只换这个而已
    Value: Integer;
    Index:Integer;//clq 只是其在遍历数组中的索引而已
    isDel:Integer;//ttt
  end;

  TIntegerHashList = class
  private
    Buckets: array of PHashItem;

    //clq 遍历索引而已
    //FList:TFastList;
    FList:TFastList;
    //clq 遍历索引而已
    function Get(Index: Integer): Integer;
    function GetKey(Index: Integer): Integer;

  protected
    function Find(const Key: Integer): PPHashItem;
    function HashOf(const Key: Integer): Cardinal; virtual;
  public
    constructor Create(Size: Cardinal = 65536); //256);//65535 还是 65536 ?
    destructor Destroy; override;
    procedure Add(const Key: Integer; Value: Integer);
    procedure Clear;
    procedure Remove(const Key: Integer);
    function Modify(const Key: Integer; Value: Integer): Boolean;
    function ValueOf(const Key: Integer): Integer;

  public//新加的遍历接口
    function Count: Integer;
    //因为只是用来遍历的,所以就不允许写入了,虽然写入也是可以的,但这里的值主要用来存放指针所以还是不要改的好
    property Items[Index: Integer]: Integer {即前面的 Value: Integer} read Get;
    //因为只是用来遍历的,所以就不允许写入了,虽然写入也是可以的,但这里的值主要用来存放指针所以还是不要改的好
    property Keys[Index: Integer]: Integer {即前面的 Key: Integer} read GetKey;

  end;

implementation
{ TIntegerHashList }

procedure TIntegerHashList.Add(const Key: Integer; Value: Integer);
var
  Hash: Integer;
  Bucket: PHashItem;
begin
  Hash := HashOf(Key) mod Cardinal(Length(Buckets));

  //Hash := Key and 65535;
  //Hash := Hash and $7FFFFFFF;


  //据说 C++ 里面 Result := h and (len - 1); 比 mod 运算要快,不过那样的话长度就必须是 2 的 n 次方
  //但是换 and 算法的话就要再精确计算容器的长度,而且删除时的性能提高几乎可以忽略不计所以还是直接 mod 好了
  //--------------------------------------------------

  New(Bucket);
  Bucket^.Key := Key;
  Bucket^.Value := Value;
  Bucket^.Next := Buckets[Hash];
  Buckets[Hash] := Bucket;

  //--------------------------------------------------
  //加入遍历索引中
  Bucket.Index := FList.Add(Bucket);
  Bucket.isDel := 0;

end;

procedure TIntegerHashList.Clear;
var
  I: Integer;
  P, N: PHashItem;
begin
  for I := 0 to Length(Buckets) - 1 do
  begin
    P := Buckets[I];
    while P <> nil do
    begin
      N := P^.Next;
      Dispose(P);
      P := N;
    end;
    Buckets[I] := nil;
  end;

  //--------------------------------------------------
  FList.Clear;

end;

function TIntegerHashList.Count: Integer;
begin
  Result := FList.Count;
end;

constructor TIntegerHashList.Create(Size: Cardinal);
begin
  inherited Create;
  SetLength(Buckets, Size);

  //--------------------------------------------------
  FList := TFastList.Create(Size);

end;

destructor TIntegerHashList.Destroy;
begin
  Clear;

  //--------------------------------------------------
  FList.Free;

  inherited Destroy;
end;

function TIntegerHashList.Find(const Key: Integer): PPHashItem;
var
  Hash: Integer;
begin
  Hash := HashOf(Key) mod Cardinal(Length(Buckets));
  //Hash := Key and 65535;
  //Hash := Hash and $7FFFFFFF;

  Result := @Buckets[Hash];
  while Result^ <> nil do
  begin
    if Result^.Key = Key then
      Exit
    else
      Result := @Result^.Next;
  end;
end;

function TIntegerHashList.Get(Index: Integer): Integer;
begin
  Result := PHashItem(FList[Index]).Value; //clq 指针不会错的,错就有问题了
end;

function TIntegerHashList.GetKey(Index: Integer): Integer;
begin
  Result := PHashItem(FList[Index]).Key; //clq 指针不会错的,错就有问题了

end;

function TIntegerHashList.HashOf(const Key: Integer): Cardinal;
var
  I: Integer;
begin
  //clq 因为是整数,原样返回就行了
  Result := Key;

  Exit;
  //--------------------------------------------------
//  Result := 0;
//  for I := 1 to Length(Key) do
//    Result := ((Result shl 2) or (Result shr (SizeOf(Result) * 8 - 2))) xor
//      Ord(Key[I]);
end;

function TIntegerHashList.Modify(const Key: Integer; Value: Integer): Boolean;
var
  P: PHashItem;
begin
  P := Find(Key)^;
  if P <> nil then
  begin
    Result := True;
    P^.Value := Value;
  end
  else
    Result := False;
end;

procedure TIntegerHashList.Remove(const Key: Integer);
var
  P: PHashItem;
  Prev: PPHashItem;
  Index:Integer; //clq 节点在遍历数组中的索引而已
  MoveIndex:Integer;//clq 被移动的遍历数组的元素索引[目前算法是最后一个元素补充到当前元素位置上来]
begin
  Prev := Find(Key);
  P := Prev^;

  if P <> nil then
  begin
    //--------------------------------------------------
    //在释放前更新下索引
    Index := p^.Index;
    if Self.FList.Count=0 then
    showmessage('error111 TIntegerHashList.Remove');

    if p^.isDel = 1 then
    showmessage('error111 TIntegerHashList.Remove');

    p^.isDel := 1;

    //PHashItem(FList.Items[FList.Delete(P^.Index)]).Index := index; //被移动的节点的索引等于我的索引就行了,就算我是最后一个了也不会出错,因数底层数据全部未动
    MoveIndex := FList.Delete(P^.Index);
    if MoveIndex>=FList.Count
    then ShowMessage('TIntegerHashList.Remove 底层队列实现索引有误.');

    if MoveIndex<>-1 then //删除的返回值为 -1 的话说明是最后一个元素,没有其他人被移动,所以就不要处理了
    PHashItem(FList.Items[MoveIndex]).Index := index; //被移动的节点的索引等于我的索引就行了,就算我是最后一个了也不会出错,因数底层数据全部未动

    //加上这些合法性判断对性能几乎无影响[测试计算量为 2000000]

    //------------------
    //释放物理内存,感觉没有必要调用,因为只有最大数超过时才会影响性能,每次删除后其实最后一个元素是向前提了的
    //FList.FreeMemoryForDelete;//似乎有问题

    //--------------------------------------------------

    Prev^ := P^.Next;
    Dispose(P);
  end;
end;

function TIntegerHashList.ValueOf(const Key: Integer): Integer;
var
  P: PHashItem;
begin
  P := Find(Key)^;
  if P <> nil then
    Result := P^.Value
  else
    Result := -1;
end;


end.

