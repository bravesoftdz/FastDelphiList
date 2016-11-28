unit uThreadLock;

//�߳���

interface


uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  winsock2,WinSock,ComCtrls,Contnrs,
  IniFiles,
  Dialogs;

{$DEFINE USE_MUTEX}//�Ƿ�ʹ�û�����,���ɿ�,�ٶ���һ��//ʵ�ʲ����ٶȲ�����Ժ��Բ���

type
  TThreadLock = class(TComponent)

  private
    hMutex:THandle;
    hSemaphore:THandle;
    isLocked:Boolean;
    //useMutex:Boolean;//�Ƿ�ʹ�û�����,���ɿ�,�ٶ���һ��

    //�����ж�������λ��
    debugInfo1:string;
    debugInfo2:string;

    //��Ϊ�����˳�ʱ������ debugInfo1,debugInfo2 ,����Ҫ�ж�һ��
    isFree:Boolean;

    //�Ƿ��ֹ���ֹ��
    isTerminate:Boolean;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure Lock;overload;
    procedure Lock(const debugInfo:string);overload;

    procedure UnLock;

    //�߳��˳�ʱ��Ҫ�ſ�,��������,�����˲�������
    procedure TerminateInThread;

    //procedure InitLock();

    //�����ڵ�������ԭ��λ��
    procedure GetDebugInfo(var info1:string; var info2:string; var lock:Boolean);
    //�����ڵ���
    function TryLock_Test: Integer;

  end;

//var
//  threadLock:TThreadLock;

implementation

uses uLogFile;

{ TThreadLock }




constructor TThreadLock.Create(AOwner: TComponent);
begin
  inherited;
  isLocked := False;
  isFree := False;
  isTerminate := False;

  {$IFDEF USE_MUTEX}
  hMutex:=CreateMutex(nil,false,nil);
  {$ELSE}
  hSemaphore := CreateSemaphore(0, 1, 1, nil);
  {$ENDIF}
end;

//�߳��˳�ʱ��Ҫ�ſ�,��������,�����˲�������
procedure TThreadLock.TerminateInThread;
begin
  {$IFDEF USE_MUTEX}
  CloseHandle(hMutex);
  {$ELSE}
  CloseHandle(hSemaphore);
  {$ENDIF}

  //isFree := True;
  isTerminate := True;

  //inherited;
end;


destructor TThreadLock.Destroy;
begin
  if not isTerminate then //�ֹ��رյ�,��Ҫ�ٴιر���
  begin
    {$IFDEF USE_MUTEX}
    CloseHandle(hMutex);
    {$ELSE}
    CloseHandle(hSemaphore);
    {$ENDIF}

  end;

  isFree := True;

  inherited;
end;

procedure TThreadLock.Lock;
begin
  //���߳���
  //������?
  
  {$IFDEF USE_MUTEX}
  WaitForSingleObject(hMutex, INFINITE);
  {$ELSE}
  WaitForSingleObject(hSemaphore, INFINITE);
  {$ENDIF}

  while(isLocked = true) do
  begin
    //sleep(1000);//��ʵ�������ˣ���linux���ǽ��벻�������//windows �¿�����
    sleep(1);

    if isFree then Exit;//��ʵֻ�Ƿ�ֹ�����˳�ʱ���쳣,����ȷʵ��Ч

    {$IFDEF DEBUG_TTHREAD_LOCK}
    LogFile('isLocked = true'); Sleep(60*1000);
    {$ENDIF}
  end;

  isLocked := true;//Ҫ�ڽ�����ֵ
end;

procedure TThreadLock.Lock(const debugInfo:string);
var
  r:Integer;
begin
  //���߳���
  //������?

  if isTerminate then Exit; // 2015/4/14 10:59:42

  {$IFDEF USE_MUTEX}

    {$IFDEF DEBUG_TTHREAD_LOCK}
    //if WAIT_TIMEOUT = WaitForSingleObject(hMutex, 0)//IGNORE
    //if WAIT_OBJECT_0 <> WaitForSingleObject(hMutex, 5*1000) then
    r := WaitForSingleObject(hMutex, 50*1000);
    while (WAIT_OBJECT_0 <> r) do
    begin
      LogFile('isLocked = true r:' + IntToStr(r));
      LogFile('Self.debugInfo1: ' + Self.debugInfo1);
      LogFile('Self.debugInfo2: ' + Self.debugInfo2);
      Sleep(60*1000);

    end;
    {$ENDIF}


    r := WaitForSingleObject(hMutex, 50*1000);
    while (WAIT_OBJECT_0 <> r) do
    begin
      LogFile('isLocked = true r:' + IntToStr(r));     //clq ll  ����ϵ��ٿ���־��֪�����������
      LogFile('Self.debugInfo1: ' + Self.debugInfo1);
      LogFile('Self.debugInfo2: ' + Self.debugInfo2);
      Sleep(60*1000);

    end;

  {$ELSE}
    WaitForSingleObject(hSemaphore, INFINITE);
  {$ENDIF}

  while(isLocked = true) do
  begin
    //sleep(1000);//��ʵ�������ˣ���linux���ǽ��벻�������//windows �¿�����
    sleep(1);

    if isFree then Exit;//��ʵֻ�Ƿ�ֹ�����˳�ʱ���쳣,����ȷʵ��Ч

    {$IFDEF DEBUG_TTHREAD_LOCK}
    LogFile('isLocked = true'); Sleep(60*1000);
    {$ENDIF}
  end;

  isLocked := true;//Ҫ�ڽ�����ֵ

  {$IFDEF DEBUG_TTHREAD_LOCK}
  try
  {$ENDIF}

  debugInfo2 := PChar(debugInfo1);
  debugInfo1 := PChar(debugInfo);

  {$IFDEF DEBUG_TTHREAD_LOCK}
  except
    //������� TThreadLock.Create(Application) �������߳���,������ᱨ��,��Ϊ��ʱ������Ѿ��� Application �ͷ���
    LogFile('TThreadLock.Lock �����ͷ�.');
    MessageBox(0, '', '', 0);
    MessageBox(0, PChar(debugInfo1), '', 0);
  end;
  {$ENDIF}

end;

function TThreadLock.TryLock_Test:Integer;
begin
  Result := 0;

  Result := WaitForSingleObject(hMutex, 1);

  if Result = WAIT_OBJECT_0 then ReleaseMutex(hMutex);

end;

procedure TThreadLock.GetDebugInfo(var info1:string; var info2:string; var lock:Boolean);
begin
  info1 := PChar(debugInfo1);
  info2 := PChar(debugInfo2);
  lock := isLocked;
  
end;


procedure TThreadLock.UnLock;
begin
  islocked := false;//Ҫ�ڽ���ǰ��ֵ

  {$IFDEF USE_MUTEX}
  ReleaseMutex(hMutex);
  {$ELSE}
  ReleaseSemaphore(hSemaphore, 1, nil);
  {$ENDIF}
  
end;

//--------------------------------------------------
initialization
//  threadLock:=TThreadLock.Create(Application);

end.
