unit uActiveCheck;

//检测连接是否活动的类

//{$DEFINE DEBUG_DIS_TRY}//有 try 的地方异常位置无法确定,不过在本例中无效

interface
uses
  IniFiles, SysUtils, DateUtils, Windows,
  uFastHashedStringList, uThreadLock, uFastHashSocketQueue, uFastList,
  winsock2,{WinSock,}
  Classes;

type
  //socket 的活动时间结构
  PSocketACTime = ^TSocketACTime;
  TSocketACTime = record
    itor:TFastListItem;//迭代器
    so:TSocket;
    dt:TDateTime;
    dt_sec:Int64;//秒数
    data_index:Integer;//在遍历数组中的位置,从 0 开始//因为有单个的删除,所以其实是无效的,只能用来记录添加时的总数
    debugTag:Int64;

  end;

type
  TThreadActiveCheck = class;
  TActiveCheckObj = class(TObject)

  private
    checkThread:TThreadActiveCheck;
    threadLock:TThreadLock;

  public
    //socket 的更新时间(最近一次有活动时间)
    acTimeList:TFastHashSocketQueue;
    //data:TList;//用于快速索引访问,这个用于遍历//不能用 TList ,那个也是整体移动的
    data:TFastList;
    //连接不活动被断开的超时值
    timeOutSec:Integer;

    constructor Create; //override;
    destructor Destroy; override;

    //--------------------------------------------------
    //生成队列需要的时间指针
    function CreateTime(const so:TSocket; const dt:TDateTime):Pointer;
    procedure FreeTime(const p:Pointer);
    function GetTime(const p:Pointer):TDateTime;
    //--------------------------------------------------

    //更新一个 socket 的活动时间
    procedure UpdateActiveTime(const so:TSocket);
    procedure StartService;
  end;

  TThreadActiveCheck = class(TThread)
  private
    //threadLock:TThreadLock;

    //procedure Lock;
    //procedure UnLock;
    { Private declarations }
  protected
    procedure Execute; override;
  public
//    threadLock:TThreadLock;
    isTest:Boolean;
    acObj:TActiveCheckObj;

    constructor Create(CreateSuspended: Boolean);
    destructor Destroy; override;

  end;



//只有一个监听时可以这样用,否则每个监听带一个这个类实例
procedure StartCheckActiveSocket;//要首先调用这个函数来生成相关的类
//更新一个 socket 的最新流动时间
procedure UpdateActiveTime(const so:TSocket);
//不活动连接的超时值,单位秒
procedure SetActiveTimeOut(const timeOutSec:Integer);

var
  GActiveCheckObj:TActiveCheckObj;

implementation

constructor TThreadActiveCheck.Create(CreateSuspended: Boolean);
begin
  inherited Create(CreateSuspended);

  //threadLock := TThreadLock.Create(nil);
  //acObj := TActiveCheckObj.Create;
end;

destructor TThreadActiveCheck.Destroy;
begin
  //threadLock.Free;
  acObj.Free;
  inherited;
end;

procedure TThreadActiveCheck.Execute;
var
  i:Integer;
  pac:PSocketACTime;
  t:Integer;
  //item:PSocketACTime;
  item, next:PFastListItem;
begin
  inherited;

  while (True) do
  begin
{$IFNDEF DEBUG_DIS_TRY}
    try
{$ENDIF}
      acObj.threadLock.Lock('TThreadActiveCheck.Execute');

      item := acObj.data.GetFirst;

      i := 0;
      //for i := 0 to acObj.data.Count-1 do
      while i<acObj.data.Count do
      begin
        if item = nil then Break;
        next := acObj.data.GetNext(item);

        //pac := acObj.data.Items[i];
        pac := PSocketACTime(item);

        t := DateTimeToUnix(now)-pac.dt_sec;

        //小于 0 以防错
        //if (t > 10)or(t < 0) then
        if (t > acObj.timeOutSec)or(t < 0) then
        begin
          try
          closesocket(pac.so);
          acObj.acTimeList.DeleteItem(pac.so);
          acObj.FreeTime(pac);//这个释放内存了,要放在最后
          except
            MessageBox(0, PChar(IntToStr(acObj.data.Count)), '', 0);
          end;
        end;

        item := next;//acObj.data.GetNext(item);
        Inc(i);
      end;

{$IFNDEF DEBUG_DIS_TRY}
    finally
{$ENDIF}

      acObj.threadLock.UnLock();

{$IFNDEF DEBUG_DIS_TRY}
    end;
{$ENDIF}

    //Sleep(1);
    Sleep(3 * 1000);//3 秒检查一次,不能太密集
  end;

end;

//procedure TThreadActiveCheck.Lock();
//begin
//  threadLock.Lock;//线程引发的,必须锁定
//end;
//
//procedure TThreadActiveCheck.UnLock();
//begin
//  threadLock.unLock;//线程引发的,必须锁定
//end;




{ TActiveCheck }

constructor TActiveCheckObj.Create;
begin
  threadLock := TThreadLock.Create(nil);
  acTimeList := TFastHashSocketQueue.Create;
  //data := TList.Create;
  data := TFastList.Create;

  timeOutSec := 10;
end;


//实际上是不释放的
destructor TActiveCheckObj.Destroy;
begin
  data.Free;
  acTimeList.Free;
  threadLock.Free;
  inherited;
end;

procedure TActiveCheckObj.FreeTime(const p: Pointer);
var
  pac:PSocketACTime;
begin
  pac := p;

  if pac.debugTag<>0
  then MessageBox(0, '内存访问异常', '内部错误', 0);//一个简单的出错判断

  pac.debugTag := 1;

  //data.Delete(pac.data_index);//不能这样删除,因为第一次删除后各个的索引就不同了
  data.Delete(PFastListItem(pac));

  //Dispose(p);//不能直接释放,要转换为正确的类型
  Dispose(pac);
  
end;

function TActiveCheckObj.CreateTime(const so:TSocket; const dt: TDateTime): Pointer;
var
  pac:PSocketACTime;
begin
  //Result := Pointer(DateTimeToUnix(dt));
  //Result := AllocMem(SizeOf(TSocketACTime))
  Result := nil;
  new(pac);
  data.InitForNew(PFastListItem(pac));//有问题 new 出来的东西并没有自己初始化,所以要一个初始化的过程

  pac.so := so;
  pac.dt := dt;
  pac.dt_sec := DateTimeToUnix(dt);

  pac.data_index := data.Count;//注意,用来删除的//不用了

  //--------------------------------------------------
  //有问题 new 出来的东西并没有自己初始化
  pac.debugTag := 0;
  //pac.itor.l := nil;
  //pac.itor.r := nil;
  //pac.itor.data := nil;
  //pac.itor.delete := 0;

  //--------------------------------------------------
  data.Add(PFastListItem(pac));

  Result := pac;

end;


function TActiveCheckObj.GetTime(const p: Pointer): TDateTime;
var
  i:Int64;
begin
  i := Int64(p);
  Result := UnixToDateTime(i);

end;

procedure TActiveCheckObj.UpdateActiveTime(const so: TSocket);
var
  p:Pointer;
begin
{$IFNDEF DEBUG_DIS_TRY}
  try
{$ENDIF}
    threadLock.Lock('TActiveCheckObj.UpdateActiveTime');

    //先删除旧的
    if acTimeList.GetItem(so, p) then
    begin
      acTimeList.DeleteItem(so);
      FreeTime(p);

    end;

    //再加入新的
    p := CreateTime(so, Now);
    acTimeList.SetItem(so, p);

{$IFNDEF DEBUG_DIS_TRY}
  finally
{$ENDIF}

    threadLock.UnLock;
    
{$IFNDEF DEBUG_DIS_TRY}
  end;
{$ENDIF}


end;

procedure TActiveCheckObj.StartService;
begin
  checkThread := TThreadActiveCheck.Create(True);
  checkThread.acObj := Self;

  checkThread.Resume;

end;

//只有一个监听时可以这样用,否则每个监听带一个这个类实例
procedure StartCheckActiveSocket;
//var
//  GActiveCheckObj:TActiveCheckObj;
begin
  GActiveCheckObj := TActiveCheckObj.Create;
  GActiveCheckObj.StartService;

end;

//只有一个监听时可以这样用,否则每个监听带一个这个类实例
procedure UpdateActiveTime(const so:TSocket);
begin
  //Exit;
  GActiveCheckObj.UpdateActiveTime(so);  //ll 断点有异常,去掉 try 试试

end;

//不活动连接的超时值,单位秒
procedure SetActiveTimeOut(const timeOutSec:Integer);
begin
  //Exit;
  GActiveCheckObj.timeOutSec := timeOutSec;
  
end;


end.





