unit uUiMessage;

//������ ui ��Ϣ����Ԫ,��Ϊ�Ϳͻ��˵�ͬ������ͬ,����˲���ֱ�Ӳ��� UI ,���� SendMessage Ҳ�п�������

//{$DEFINE DEBUG_DIS_TRY}//�� try �ĵط��쳣λ���޷�ȷ��,�����ڱ�������Ч

interface
uses
  IniFiles, SysUtils, DateUtils, Windows,
  uThreadLock,
  Classes;


//��ʼ��
procedure InitUiMessage();
//������־��Ϣ
procedure LogUiMessage(const s:string);
//ȡ��־��Ϣ
function GetUiMessage:string;
//�ͷ�// 2015/4/22 11:21:34
procedure FreeUiMessage();

var
  GUiMessageList:TStringList;
  GUiMessageList_lock:TThreadLock;

implementation



procedure InitUiMessage();
begin
  GUiMessageList := TStringList.Create;
  GUiMessageList_lock := TThreadLock.Create(nil);

end;

procedure FreeUiMessage();
begin
  GUiMessageList.Free;
  GUiMessageList_lock.Free;

end;   

//������־��Ϣ
procedure LogUiMessage(const s:string);
begin
  try
    GUiMessageList_lock.Lock('LogUiMessage');

    //--------------------------------------------------
    // 2015/4/29 10:09:53 //clq ��˵��־��ĳЩ����»�ռ�� 150m �ڴ�,���������������һ��
    if GUiMessageList.Count>200 then
    begin
      GUiMessageList.Clear;
      GUiMessageList.Add('[...��־���ʡ��...]');
    end;  

    //--------------------------------------------------


    GUiMessageList.Add(s);

  finally
    GUiMessageList_lock.UnLock;
  end;


end;

//ȡ��־��Ϣ
function GetUiMessage:string;
begin
  Result := '';
  try
    GUiMessageList_lock.Lock('GetUiMessage');

    //GUiMessageList.Add(s);
    Result := PChar(GUiMessageList.Text);
    GUiMessageList.Clear;

  finally
    GUiMessageList_lock.UnLock;
  end;


end;


end.





