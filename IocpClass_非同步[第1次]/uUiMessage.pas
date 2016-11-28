unit uUiMessage;

//辅助的 ui 消息处理单元,因为和客户端的同步处理不同,服务端不能直接操作 UI ,发送 SendMessage 也有可能死锁

//{$DEFINE DEBUG_DIS_TRY}//有 try 的地方异常位置无法确定,不过在本例中无效

interface
uses
  IniFiles, SysUtils, DateUtils, Windows,
  uThreadLock,
  Classes;


//初始化
procedure InitUiMessage();
//加入日志消息
procedure LogUiMessage(const s:string);
//取日志消息
function GetUiMessage:string;

implementation

var
  GUiMessageList:TStringList;
  GUiMessageList_lock:TThreadLock;

procedure InitUiMessage();
begin
  GUiMessageList := TStringList.Create;
  GUiMessageList_lock := TThreadLock.Create(nil);

end;  

//加入日志消息
procedure LogUiMessage(const s:string);
begin
  try
    GUiMessageList_lock.Lock('LogUiMessage');
    GUiMessageList.Add(s);

  finally
    GUiMessageList_lock.UnLock;
  end;


end;

//取日志消息
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





