unit uActiveCheck_v2;

//��������Ƿ�����//�� hashmap ��ʵ��

//{$DEFINE DEBUG_DIS_TRY}//�� try �ĵط��쳣λ���޷�ȷ��,�����ڱ�������Ч

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
  TActiveCheckObj = class(TComponent)//(TObject)// 2015/4/14 9:03:17 Ϊ����ڴ�й©,�� TComponent �ȽϺ�
  private
    //threadLock:TThreadLock;//����������,���ڶ��� iocp ���߳�������// 2015/4/28 10:31:21

  public
    //socket �ĸ���ʱ��(���һ���лʱ��)
    acTimeList:THashMap;//TFastHashSocketQueue;
    //data:TList;//���ڿ�����������,������ڱ���//������ TList ,�Ǹ�Ҳ�������ƶ���
    //data:TFastList;
    //���Ӳ�����Ͽ��ĳ�ʱֵ
    timeOutSec:Integer;

    //constructor Create; //override;
    //--------------------------------------------------
    // 2015/4/14 9:02:12 Ϊ�˼���ڴ�й©���Ǽӹ��캯���ĺ�
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;


    //����һ�� socket �Ļʱ��
    procedure UpdateActiveTime(const so:TSocket);
    procedure StartService;
    //�����߳���,ֱ���� iocp ��ģ�ⶨʱ���¼��б�������
    procedure OnTimer;
    //�ֹ���������
    procedure ClearForMemoeryTest;
  end;


//ֻ��һ������ʱ����������,����ÿ��������һ�������ʵ��
procedure StartCheckActiveSocket;//Ҫ���ȵ������������������ص���
procedure StopCheckActiveSocket;

//����һ�� socket �����»ʱ��
procedure UpdateActiveTime(const so:TSocket);
//������ӵĳ�ʱֵ,��λ��
procedure SetActiveTimeOut(const timeOutSec:Integer);

var
  GActiveCheckObj:TActiveCheckObj;

implementation



{ TActiveCheck }

//constructor TActiveCheckObj.Create;
 // 2015/4/14 9:02:12 Ϊ�˼���ڴ�й©���Ǽӹ��캯���ĺ�
constructor TActiveCheckObj.Create(AOwner: TComponent); //override;
begin
  acTimeList := THashMap.Create;

  timeOutSec := 10;
end;


//ʵ�����ǲ��ͷŵ�
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

//�����߳���,ֱ���� iocp ��ģ�ⶨʱ���¼��б�������
procedure TActiveCheckObj.OnTimer;
var
  i:Integer;
  t:Integer;
  k,v:Integer;
  Removes:IntArr;//��Щ��Ҫɾ����
begin
  {$R+} //Range Checking �ж�̬����ĵط����У��һ��


  //����ѭ��Ҳ��������,Ҳ���� try , iocp �ӿ���ȫ��������

  SetMax(Removes, acTimeList.Count);
  //pos := 0;

  for i := 0 to acTimeList.Count-1 do
  begin
    v := acTimeList.Items[i];
    k := acTimeList.Keys[i];

    t := DateTimeToUnix(now )- v;

    //С�� 0 �Է���
    //if (t > 10)or(t < 0) then
    if (t > self.timeOutSec)or(t < 0) then
    begin
      closesocket(k);
      //self.acTimeList.Remove(k);
      //Removes[pos] := k; Inc(pos); //������ѭ����ɾ��,�ȼ�����
      Add(Removes, k);
    end;

  end;

  //Removes[3] := 2;

  //�����������ѭ��ɾ��
  for i := 0 to Count(Removes)-1 do
  begin
    self.acTimeList.Remove(Removes[i]);
  end;

  //Ҳ��Ҫ sleep//Sleep(3 * 1000);//3 ����һ��,����̫�ܼ�

  {$R-} //Range Checking
end;

//�ֹ���������//��Ҫ�� iocp ����
procedure TActiveCheckObj.ClearForMemoeryTest;
var
  i:Integer;
  t:Integer;
begin

  //����,��������,��Ҫ���ӿ�,�ڵ���ʱ iocp ��������//Self.threadLock.Lock('TThreadActiveCheck.Execute');
  acTimeList.Clear;

end;


procedure TActiveCheckObj.StartService;
begin
//  checkThread := TThreadActiveCheck.Create(True);
//  checkThread.acObj := Self;
//
//  checkThread.Resume;

end;

//ֻ��һ������ʱ����������,����ÿ��������һ�������ʵ��
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

//ֻ��һ������ʱ����������,����ÿ��������һ�������ʵ��
procedure UpdateActiveTime(const so:TSocket);
begin
  //Exit;
  GActiveCheckObj.UpdateActiveTime(so);  //ll �ϵ����쳣,ȥ�� try ����

end;

//������ӵĳ�ʱֵ,��λ��
procedure SetActiveTimeOut(const timeOutSec:Integer);
begin
  //Exit;
  GActiveCheckObj.timeOutSec := timeOutSec;
  
end;


end.




