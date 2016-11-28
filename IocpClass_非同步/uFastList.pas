unit uFastList;

//delphi 的 TList 是一次分配全部内存并整体移动的,并不是传统意义上的链表,是不能高速增删的
//不过从,高速索引那边的结果看,速度还能接受,主要是索引生成太久,所以暂时不用替换 TList

interface
uses
  IniFiles, SysUtils, Windows,
  DateUtils,
  Classes;

type
  PFastListItem = ^TFastListItem;
  //防止对齐引发的错误,都用压缩的好了
  TFastListItem = packed record
    l:PFastListItem;
    r:PFastListItem;
    data:Pointer;//Integer;//数据,指向一个外部定义的对象
    delete:Byte;//标志是否是删除的了,目前仅用于测试是否重复释放了一个节点
  end;

  TFastList = class(TObject)
  private
    //如首节点为空则整个队列为空
    first:PFastListItem;
    //必须要有尾节点,用来快速添加新节点
    last:PFastListItem;
  public
    Count:Integer;

    constructor Create; //override;
    destructor Destroy; override;

    //操作的 p 必须可以强制转换为 PFastListItem,即结构体的
    //procedure Add(const p:Pointer);
    procedure Add(const item:PFastListItem);
    procedure Delete(const item:PFastListItem);
    function GetFirst: PFastListItem;
    function GetNext(const item:PFastListItem):PFastListItem;
    //有问题 new 出来的东西并没有自己初始化,所以要一个初始化的过程
    //新加一个节点后要做的事情
    //procedure OnAfterNewItem();
    procedure InitForNew(var item:PFastListItem);
  end;

implementation


{ TFastList }

procedure TFastList.Add(const item: PFastListItem);
begin
  if item=nil then Exit;

  Count := Count + 1;

  if first=nil then//头尾同时存在
  begin
    first := item;
    last := item;
    Exit;
  end;

  if last=nil then//头尾同时存在
  begin
    first := item;
    last := item;
    Exit;
  end;

  begin
    item.l := last;
    last.r := item;
    last := item;
  end;
end;

constructor TFastList.Create;
begin
  first := nil;
  last := nil;
  Count := 0;

end;

procedure TFastList.Delete(const item: PFastListItem);
begin
  if item=nil then Exit;
  
  //item.delete := 1;
  Inc(item.delete);

  //只有一个节点的情况
  if first = last then
  begin
    first := nil;
    last := nil;
    Count := 0;
    Exit;
  end;

  if item = first then
  begin
    if first.r <> nil then first.r.l := nil;
    first := first.r;
    Count := Count -1;
    Exit;
  end;

  if item = last then
  begin
    last := last.l;
    Count := Count -1;
    Exit;
  end;

  //if item.l=nil then Exit;//不用做这个判断,如果出现了就是异常的
  if item.l=nil then
  begin
    MessageBox(0, PChar('节点删除严重错误![TFastList.Delete] ' + IntToStr(Count) + ' ' + IntToStr(item.delete)) , '', 0);
    Exit;//不用做这个判断,如果出现了就是异常的

  end;

  item.l.r := item.r;
  item.r.l := item.l;
  Count := Count -1;
end;

destructor TFastList.Destroy;
begin

  inherited;
end;

function TFastList.GetNext(const item: PFastListItem): PFastListItem;
begin
  Result := nil;
  if item=nil then Exit;

  Result := item.r;
end;

function TFastList.GetFirst: PFastListItem;
begin
  Result := first;
end;

procedure TFastList.InitForNew(var item: PFastListItem);
begin
  //--------------------------------------------------
  //有问题 new 出来的东西并没有自己初始化
  item.l := nil;
  item.r := nil;
  item.data := nil;
  item.delete := 0;

  //--------------------------------------------------
end;

end.





