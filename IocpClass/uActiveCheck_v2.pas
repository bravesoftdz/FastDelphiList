unit uActiveCheck_v2;

//检测连接是否活动的类//换 hashmap 来实现

//{$DEFINE DEBUG_DIS_TRY}//有 try 的地方异常位置无法确定,不过在本例中无效

interface
uses
  IniFiles, SysUtils, DateUtils, Windows, Forms,
  //uFastHashedStringList,
  uThreadLock, fsHashMap,
  //uFastHashSocketQueue,
  uFastHashSocketQueue_v2,
  uFastList, iocpInterfaceClass,
  //winsock2,{WinSock,}
  Classes;

type
  TActiveCheckObj = class(TComponent)//(TObject)// 2015/4/14 9:03:17 为检测内存泄漏,用 TComponent 比较好
  private
    //threadLock:TThreadLock;//不用锁定了,现在都在 iocp 中线程锁定了// 2015/4/28 10:31:21

  public
    //socket 的更新时间(最近一次有活动时间)
    acTimeList:THashMap;//TFastHashSocketQueue;
    //data:TList;//用于快速索引访问,这个用于遍历//不能用 TList ,那个也是整体移动的
    //data:TFastList;
    //连接不活动被断开的超时值
    timeOutSec:Integer;

    //constructor Create; //override;
    //--------------------------------------------------
    // 2015/4/14 9:02:12 为了检测内存泄漏还是加构造函数的好
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;


    //更新一个 socket 的活动时间
    procedure UpdateActiveTime(const so:TSocket);
    procedure StartService;
    //不开线程了,直接在 iocp 的模拟定时器事件中遍历就行
    procedure OnTimer;
    //手工清理测试
    procedure ClearForMemoeryTest;
  end;


//只有一个监听时可以这样用,否则每个监听带一个这个类实例
procedure StartCheckActiveSocket;//要首先调用这个函数来生成相关的类
procedure StopCheckActiveSocket;

//更新一个 socket 的最新活动时间
procedure UpdateActiveTime(const so:TSocket);
//不活动连接的超时值,单位秒
procedure SetActiveTimeOut(const timeOutSec:Integer);

var
  GActiveCheckObj:TActiveCheckObj;

implementation



{ TActiveCheck }

//constructor TActiveCheckObj.Create;
 // 2015/4/14 9:02:12 为了检测内存泄漏还是加构造函数的好
constructor TActiveCheckObj.Create(AOwner: TComponent); //override;
begin
  acTimeList := THashMap.Create;

  timeOutSec := 10;
end;


//实际上是不释放的
destructor TActiveCheckObj.Destroy;
begin
  //data.Free;
  acTimeList.Free;
  
  inherited;
end;


procedure TActiveCheckObj.UpdateActiveTime(const so: TSocket);
var
  p:Pointer;
  v:Integer;
begin

  v := acTimeList.ValueOf(so);

  if v = -1
  then acTimeList.Add(so, DateTimeToUnix(now))
  else acTimeList.Modify(so, DateTimeToUnix(now))

end;

//不开线程了,直接在 iocp 的模拟定时器事件中遍历就行
procedure TActiveCheckObj.OnTimer;
var
  i:Integer;
  t:Integer;
  k,v:Integer;
  Removes:IntArr;//哪些是要删除的
begin
  {$R+} //Range Checking 有动态数组的地方最好校验一下


  //不用循环也不用锁定,也不用 try , iocp 接口中全部做好了

  SetMax(Removes, acTimeList.Count);
  //pos := 0;

  for i := 0 to acTimeList.Count-1 do
  begin
    v := acTimeList.Items[i];
    k := acTimeList.Keys[i];

    t := DateTimeToUnix(now )- v;

    //小于 0 以防错
    //if (t > 10)or(t < 0) then
    if (t > self.timeOutSec)or(t < 0) then
    begin
      closesocket(k);
      //self.acTimeList.Remove(k);
      //Removes[pos] := k; Inc(pos); //不能在循环里删除,先记下来
      Add(Removes, k);
    end;

  end;

  //Removes[3] := 2;

  //不能在上面的循环删除
  for i := 0 to Count(Removes)-1 do
  begin
    self.acTimeList.Remove(Removes[i]);
  end;

  //也不要 sleep//Sleep(3 * 1000);//3 秒检查一次,不能太密集

  {$R-} //Range Checking
end;

//手工清理测试//需要先 iocp 锁定
procedure TActiveCheckObj.ClearForMemoeryTest;
var
  i:Integer;
  t:Integer;
begin

  //算了,不锁定了,还要出接口,在调用时 iocp 锁定即可//Self.threadLock.Lock('TThreadActiveCheck.Execute');
  acTimeList.Clear;

end;


procedure TActiveCheckObj.StartService;
begin
//  checkThread := TThreadActiveCheck.Create(True);
//  checkThread.acObj := Self;
//
//  checkThread.Resume;

end;

//只有一个监听时可以这样用,否则每个监听带一个这个类实例
procedure StartCheckActiveSocket;
//var
//  GActiveCheckObj:TActiveCheckObj;
begin
  GActiveCheckObj := TActiveCheckObj.Create(Application);
  GActiveCheckObj.StartService;

  //iocpServer.AddOnTimerEvent

end;

procedure StopCheckActiveSocket;
begin
  if GActiveCheckObj=nil then Exit;

//  GActiveCheckObj.checkThread.Terminate;
//  GActiveCheckObj.checkThread.WaitFor;
//  GActiveCheckObj.checkThread.Free;

  GActiveCheckObj.Free;
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





