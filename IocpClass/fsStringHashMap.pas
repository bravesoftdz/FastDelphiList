
unit fsStringHashMap;

//功能同 fsIntegerHashList 只是元素直接为 string

{$R-,T-,H+,X+}
//Range Checking                    {$R}
//Typed @ Operator                  {$T}
//Huge Strings                      {$H}
//Extended Syntax                   {$X}

interface

uses SysUtils, Classes, fsList, fsListString, Dialogs, IniFiles;


type

  TStringHashMap = class
  private
    //Buckets: array of PHashItem;
    FHashList:TStringHash;


    //clq 遍历索引而已
    //FList:TFastList;
    FList:TFastListString;
    //索引位与 FList 相同,并且必须相同//只是用来保存与 FList 对应的 key 而已,因为原始的 TStringHash 没有提供这个接口
    FKeyList:TFastListString;
    //clq 遍历索引而已
    function Get(Index: Integer): string;
    function GetKey(Index: Integer): string;
    function GetValue(const Name: string): string;
    procedure SetValue(const Name, Value: string);

  protected
    function Find(const Key: string): Integer;
    //function HashOf(const Key: Integer): Cardinal; virtual;
  public
    constructor Create(Size: Cardinal = 65536); //256);//65535 还是 65536 ?
    destructor Destroy; override;
    procedure Add(const Key: string; Value: string);
    procedure Clear;
    procedure Remove(const Key: string);
    function Modify(const Key: string; Value: string): Boolean;
    function ValueOf(const Key: string): string;

  public//新加的遍历接口
    function Count: Integer;
    //因为只是用来遍历的,所以就不允许写入了,虽然写入也是可以的,但这里的值主要用来存放指针所以还是不要改的好
    property Items[Index: Integer]: string {即前面的 Value: Integer} read Get;
    //因为只是用来遍历的,所以就不允许写入了,虽然写入也是可以的,但这里的值主要用来存放指针所以还是不要改的好
    property Keys[Index: Integer]: string {即前面的 Key: Integer} read GetKey;

    property Values[const Name: string]: string read GetValue write SetValue;

  end;

implementation

{ TStringHashMap }

procedure TStringHashMap.Add(const Key: string; Value: string);
var
  //Hash: Integer;
  index:Integer;
begin
  Remove(Key); //因为此实现是不可重入的,所以要先删除旧的, integer 的 hashmap 因为效率的关系没有加这步,要自己加上
  //对性能的影响还是比较大的,可能还是要想办法一次只 find 一次(其实也就是 find 了一次)
  //Find(Key);//如果是初始化不要这个可以快 3 到 5 倍,不过实际上已经非常快了,可以不做这步优化

  index := FList.Add(Value); //先存起来得到位置索引

  FHashList.Add(Key, index); //把 value 对应的位置索引记下来与 key 关联

  //FList[index] := Value;
  FKeyList.Add(Value);
  FKeyList[index] := Key;

end;

procedure TStringHashMap.Clear;
begin

  FHashList.Clear;
  //--------------------------------------------------
  FList.Clear;

end;

function TStringHashMap.Count: Integer;
begin
  Result := FList.Count;
end;

constructor TStringHashMap.Create(Size: Cardinal);
begin
  inherited Create;
  //SetLength(Buckets, Size);
  FHashList := TStringHash.Create(Size);


  //--------------------------------------------------
  FList := TFastListString.Create(Size);
  FKeyList := TFastListString.Create(Size);
end;

destructor TStringHashMap.Destroy;
begin
  Clear;

  FHashList.Clear;
  //--------------------------------------------------
  FList.Free;

  inherited Destroy;
end;

function TStringHashMap.Find(const Key: string): Integer; //这是内部查找索引位置的,所以返回 integer
begin

  Result := FHashList.ValueOf(Key); //找不到的话是 -1

end;

function TStringHashMap.Get(Index: Integer): string;
begin
  Result := FList[Index]; //clq 指针不会错的,错就有问题了
end;

function TStringHashMap.GetKey(Index: Integer): string;
begin
  //Result := PHashItem(FList[Index]).Key; //clq 指针不会错的,错就有问题了
  //这里的 key 和 value 是分离的,所以两者位置一定要算准确了

  Result := FKeyList[Index];

end;



function TStringHashMap.GetValue(const Name: string): string;
begin
  Result := ValueOf(Name);
end;

function TStringHashMap.Modify(const Key: string; Value: string): Boolean;
var
  index: Integer;
begin

  index := FHashList.ValueOf(Key); //找不到的话是 -1

  if index <> -1 then
  begin
    FList[index] := Value;
    FKeyList[index] := Key;

    Result := True;
  end
  else
    Result := False;
end;

procedure TStringHashMap.Remove(const Key: string);
var
  P: PHashItem;
  Prev: PPHashItem;
  index:Integer; //clq 节点在遍历数组中的索引而已
  MoveIndex:Integer;//clq 被移动的遍历数组的元素索引[目前算法是最后一个元素补充到当前元素位置上来]

  oldKeyIndex, oldValueIndex:Integer; //因为删除时移动了最后一个节点,所以与最后一个节点对应的 kv 值要重新设置
  oldKey, oldValue:string; //因为删除时移动了最后一个节点,所以与最后一个节点对应的 kv 值要重新设置
begin
  index := Find(Key);

  if index <> -1 then
  begin
    oldKeyIndex := FList.Delete(index);
    oldValueIndex := FKeyList.Delete(index);

    if oldKeyIndex<>-1 then //对被移动的旧节点(其实是最后一个节点)进行索引值更新,返回值为 -1 表示最后一个,就不要进行了
    begin

      oldKey := FKeyList[oldKeyIndex];
      oldValue := FKeyList[oldValueIndex];

      //FHashList.Remove(oldKey); //这个是被改变了的,要删除//这样其实有一点危险,必须要保证这里删除的索引正确
      //--------------------------------------------------
      //加上这些合法性判断对性能几乎无影响[测试计算量为 2000000]

      //if  FHashList.ValueOf(oldKey)<>oldKeyIndex
      if  FHashList.ValueOf(oldKey)<>FList.Count //这时候被 移动的索引应该是最后一个
      then ShowMessage('TStringHashMap.Remove 底层队列实现索引有误.');

      if  oldValueIndex<>oldKeyIndex
      then ShowMessage('TStringHashMap.Remove 底层队列实现索引有误2.');


      //--------------------------------------------------
      //更新被删除的索引

      //FHashList.Remove(oldKey);
      //FHashList.Add(oldKey, index); //被移动到这个节点的元素索引要更新
      FHashList.Modify(oldKey, index); //被移动到这个节点的元素索引要更新

    end;

    //--------------------------------------------------
    FHashList.Remove(Key); //这一个是肯定要进行的
  end;
end;

procedure TStringHashMap.SetValue(const Name, Value: string);
begin
//  Remove(name); //不能重入的,即 key 不能重复,重复就要先删除旧的//对性能影响还是比较大的
  Add(Name, Value);
end;

function TStringHashMap.ValueOf(const Key: string): string;
var
  index:Integer; //clq 节点在遍历数组中的索引而已
begin
  index := Find(Key);

  if index <> -1 then
    Result := FList[index]
  else
    Result := '';
end;


end.

