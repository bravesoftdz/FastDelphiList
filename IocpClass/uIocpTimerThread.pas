
//ʵ��ʹ���з��ֺܶ���Ҫʹ�ö�ʱ��ȥ���� iocp ���ݵ����,���綨ʱ����ҷ�����,
//��ʱ����Ҫ����ͬ��,��������װһ���¼�ʹ���Զ�����
//����ָ������״̬�µķ�ͬ��ģʽ,���ͬ��ģʽ��ֱ�������������ö�ʱ��������

//���Լ����������¼�,ע���¼��в���ֱ�Ӳ��� gui �ؼ�

unit uIocpTimerThread;

interface


uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  ComCtrls,Contnrs, DateUtils,
  IniFiles, uThreadLock,
  Dialogs;

type
  //��ʱ�����¼�
  TOnIocpTimerProc = procedure ({Sender: TObject}) of object;


  //�¼��б��е�һ��
  TIocpTimerProcItem = record
    OnIocpTimerProc:TOnIocpTimerProc;
    //Ҫ�ȴ����ٺ��봥��һ��,�� sleep �Ĳ�����һ����
    Interval: Cardinal;
    //����Ĳ���
    Sender: TObject;
    //�ϴ����еĺ���
    lastTime:TDateTime;
    //�¼�����,��¼һ��,���ھ���
    name:string;
  end;

  //ģ��Ķ�ʱ���߳�
  TIocpTimerThread = class(TThread)
  private
  protected
    OnTimerProcList : array of TIocpTimerProcItem;

    FOnThreadBegin:TOnIocpTimerProc;
    FOnThreadEnd:TOnIocpTimerProc;

    procedure Execute; override;

  public
    iocpClass:TObject; //TIocpClass;
    threadLock:TThreadLock;

    //����һ����ʱ�������¼�
    procedure AddOnTimerEvent(EventName:string; OnTimer:TOnIocpTimerProc; Interval:Cardinal);

    //CoInitialize, CoUninitialize �����ĺ����������߳���ʼ,��ֹʱΨһ����,����Ҫ���������ط�����ִ�д���
    procedure SetOnTimerEvent_ThreadFun(OnThreadBegin:TOnIocpTimerProc; OnThreadEnd:TOnIocpTimerProc);

    constructor Create(CreateSuspended: Boolean);
    //destructor Destroy; override;


  end;



implementation

uses uLogFile, iocpInterfaceClass;




{ TIocpTimerThread }

//CoInitialize, CoUninitialize �����ĺ����������߳���ʼ,��ֹʱΨһ����,����Ҫ���������ط�����ִ�д���
procedure TIocpTimerThread.SetOnTimerEvent_ThreadFun(OnThreadBegin:TOnIocpTimerProc; OnThreadEnd:TOnIocpTimerProc);
begin

  FOnThreadBegin := OnThreadBegin;
  FOnThreadEnd := OnThreadEnd;

end;


//����һ����ʱ�������¼�
procedure TIocpTimerThread.AddOnTimerEvent(EventName:string; OnTimer:TOnIocpTimerProc; Interval:Cardinal);
var
  item:TIocpTimerProcItem;
  iocpClass:TIocpClass;

begin

  iocpClass := TIocpClass(self.iocpClass);

  try
    if iocpClass.threadLock<>nil then
    iocpClass.threadLock.Lock('TIocpTimerThread.Execute');

    item.name := EventName;
    item.OnIocpTimerProc := OnTimer;
    item.Interval := Interval;

    SetLength(OnTimerProcList, Length(OnTimerProcList) + 1);
    OnTimerProcList[Length(OnTimerProcList) - 1] := item;

  finally
    if iocpClass.threadLock<>nil then
    iocpClass.threadLock.UnLock();
  end;

end;

procedure TIocpTimerThread.Execute;
var
  iocpClass:TIocpClass;
  i:Integer;
  //lastTime:;//�ϴ����еĺ���
  tnow:TDateTime;
begin
  iocpClass := TIocpClass(self.iocpClass);

  if Assigned(FOnThreadBegin) then FOnThreadBegin(); //�̳߳�ʼ��,�� ole

  while (not Self.Terminated) do
  begin

    try
      iocpClass.threadLock.Lock('TIocpTimerThread.Execute');

      for i := 0 to Length(Self.OnTimerProcList)-1 do
      begin
        tnow := Now;

        //ʱ���˾ʹ���
        if Abs(MilliSecondOfTheDay(tnow - OnTimerProcList[i].lastTime)) > OnTimerProcList[i].Interval then
        begin

          {$ifndef EXCEPT_DEBUG}//�����쳣�����������
          try
          {$endif}

            if g_IOCP_Synchronize_Event then
              Self.Synchronize(Self.OnTimerProcList[i].OnIocpTimerProc) //UI ͬ���Ļ�
            else
              Self.OnTimerProcList[i].OnIocpTimerProc();

            //OnTimerProcList[i].lastTime := Now;

          {$ifndef EXCEPT_DEBUG}//�����쳣�����������
          except//������ except ȥ���쳣,�����������ݽ��ղ���Ӧ
            LogFile('error on OnIocpTimerProc �̶߳�ʱ����:' + OnTimerProcList[i].name);
          end;
          {$endif}

          OnTimerProcList[i].lastTime := Now;
        end;


      end;


    finally
      iocpClass.threadLock.UnLock();
    end;

    Sleep(10); //̫���ǲ��е�,Ҳû������
  end;

  if Assigned(FOnThreadEnd) then FOnThreadEnd(); //�̳߳�ʼ��,�� ole


end;


constructor TIocpTimerThread.Create(CreateSuspended: Boolean);
begin
  inherited Create(CreateSuspended);

  FOnThreadBegin := nil;
  FOnThreadEnd := nil;


end;

end.

