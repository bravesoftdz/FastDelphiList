unit uFastQueue;

//�������� accept �õ��� socket ���

{TQueue �ǻ��� TList ��.

TList ��ʵ���Ͼ���һ�����Դ洢ָ��������࣬�ṩ��һϵ�еķ�������������ӣ�ɾ����
���ţ���λ����ȡ�����������е��࣬���ǻ�������Ļ�����ʵ�ֵ��������Ƚ�������C++��
��Vector��Java�е�ArrayList��TList ������������һ������б���������ʵ�ֵĻ���ʹ
�����±��ȡ�����еĶ���ǳ��죬�������������еĶ�������࣬�����ɾ�������ٶȻ�
ֱ���½�����˲��ʺ�Ƶ����Ӻ�ɾ�������Ӧ�ó���.
}

{������Ҫ��дһ�����ٵ��Ƚ��ȳ�����,ʵ��˼����:
1.һ���Կ��������ڴ�,����ֱ��ʹ������.
2.һ����ȡλ��һ��д��λ��,��д��λ�õ�������ĩβʱ��ͷ��ʼ.
3.�����ǰд��λ�ó����˶�ȡλ��,��ô���ǿռ�����,��Ҫ�ȴ���ȡ�����һЩԪ����.
}

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  winsock2,{WinSock,}ComCtrls,Contnrs,  
  uThreadLock,
  //Contnrs,//TQueue ���ܲ���
  Dialogs;

type
  PIntList = ^TIntList;//^TStringItemList;
  TIntList = array[0..MaxListSize] of Integer;


type
  TFastQueue = class(TObject)
  private
    FData:PIntList;//PINT;
    FReadPos:Integer;
    FWritePos:Integer;
    MaxCount:Integer;
    FCount: Integer;

    function GetNextPos(cur: Integer): Integer;
    function GetNextWritePos: Integer;
    function GetNextReadPos: Integer;

  public
    property Count:Integer read FCount;

    constructor Create(maxCount:Integer); //override;
    destructor Destroy; override;

    function Write(value:Integer):Boolean;
    function Read(var value:Integer):Boolean;

  end;

implementation

{ TFastQueue }

constructor TFastQueue.Create(maxCount:Integer);
begin
  inherited Create;

  Self.MaxCount := maxCount;
  FData := GetMemory(MaxCount * SizeOf(Integer));
  FReadPos := 0;
  FWritePos := 0;
  FCount := 0;

end;

//ȡ��һ��λ��
function TFastQueue.GetNextPos(cur:Integer):Integer;
begin
  Inc(cur);
  if cur >= MaxCount then cur := 0;
  Result := cur;
end;

//�ɼ���Ƿ��Ѿ�д����//��������·�����һ��д��λ��
function TFastQueue.GetNextWritePos:Integer;
var
  tmp:Integer;
begin
  result := -1;
  tmp := GetNextPos(FWritePos);
  if tmp = FReadPos then
  begin
    Result := -1;//test
    exit;//�����Ѿ�����
  end;

  Result := tmp;
end;

//�ɼ���Ƿ������ݿɶ�ȡ//��������·�����һ����ȡλ��
function TFastQueue.GetNextReadPos:Integer;
var
  tmp:Integer;
begin
  result := -1;

  if FReadPos = FWritePos then exit;//�����Ѿ�����
  

  tmp := GetNextPos(FReadPos);
//  if tmp = FWritePos then exit;//�����Ѿ�����

  Result := tmp;
end;


destructor TFastQueue.Destroy;
begin
  FreeMem(FData);

  inherited;
end;


function TFastQueue.Read(var value: Integer): Boolean;
var
  pos:Integer;
begin
  Result := False;
  pos := GetNextReadPos;
  if pos = -1 then Exit;

  value := FData[pos];
  FReadPos := pos;
  Dec(FCount);

  Result := True;
end;

function TFastQueue.Write(value: Integer): Boolean;
var
  pos:Integer;
begin
  Result := False;
  pos := GetNextWritePos;
  if pos = -1 then//����д����
  begin
    Result := False;//test
    Exit;
  end;   

  FData[pos] := value;
  FWritePos := pos;
  Inc(FCount);

  Result := True;
end;


end.


