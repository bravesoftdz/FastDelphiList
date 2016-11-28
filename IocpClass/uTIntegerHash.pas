
unit uTIntegerHash;

{$R-,T-,H+,X+}
//Range Checking                    {$R}
//Typed @ Operator                  {$T}
//Huge Strings                      {$H}
//Extended Syntax                   {$X}

interface

uses SysUtils, Classes;

//ֻ�޸� TStringHash ������,��Ҫ�Ķ�������

type
  { TStringHash - used internally by TMemIniFile to optimize searches. }

  PPHashItem = ^PHashItem;
  PHashItem = ^THashItem;
  THashItem = record
    Next: PHashItem;
    //Key: string;
    Key: Integer;//clq ����ֻ���������
    Value: Integer;
  end;

  TIntegerHash = class
  private
    Buckets: array of PHashItem;
  protected
    function Find(const Key: Integer): PPHashItem;
    function HashOf(const Key: Integer): Cardinal; virtual;
  public
    constructor Create(Size: Cardinal = 65536); //256);//65535 ���� 65536 ?
    destructor Destroy; override;
    procedure Add(const Key: Integer; Value: Integer);
    procedure Clear;
    procedure Remove(const Key: Integer);
    function Modify(const Key: Integer; Value: Integer): Boolean;
    function ValueOf(const Key: Integer): Integer;
  end;

implementation
{ TIntegerHash }

procedure TIntegerHash.Add(const Key: Integer; Value: Integer);
var
  Hash: Integer;
  Bucket: PHashItem;
begin
  Hash := HashOf(Key) mod Cardinal(Length(Buckets));

  //Hash := Key and 65535;
  //Hash := Hash and $7FFFFFFF;


  //��˵ C++ ���� Result := h and (len - 1); �� mod ����Ҫ��,���������Ļ����Ⱦͱ����� 2 �� n �η�
  //���ǻ� and �㷨�Ļ���Ҫ�پ�ȷ���������ĳ���,����ɾ��ʱ��������߼������Ժ��Բ������Ի���ֱ�� mod ����
  //--------------------------------------------------

  New(Bucket);
  Bucket^.Key := Key;
  Bucket^.Value := Value;
  Bucket^.Next := Buckets[Hash];
  Buckets[Hash] := Bucket;
end;

procedure TIntegerHash.Clear;
var
  I: Integer;
  P, N: PHashItem;
begin
  for I := 0 to Length(Buckets) - 1 do
  begin
    P := Buckets[I];
    while P <> nil do
    begin
      N := P^.Next;
      Dispose(P);
      P := N;
    end;
    Buckets[I] := nil;
  end;
end;

constructor TIntegerHash.Create(Size: Cardinal);
begin
  inherited Create;
  SetLength(Buckets, Size);
end;

destructor TIntegerHash.Destroy;
begin
  Clear;
  inherited Destroy;
end;

function TIntegerHash.Find(const Key: Integer): PPHashItem;
var
  Hash: Integer;
begin
  Hash := HashOf(Key) mod Cardinal(Length(Buckets));
  //Hash := Key and 65535;
  //Hash := Hash and $7FFFFFFF;

  Result := @Buckets[Hash];
  while Result^ <> nil do
  begin
    if Result^.Key = Key then
      Exit
    else
      Result := @Result^.Next;
  end;
end;

function TIntegerHash.HashOf(const Key: Integer): Cardinal;
var
  I: Integer;
begin
  //clq ��Ϊ������,ԭ�����ؾ�����
  Result := Key;

  Exit;
  //--------------------------------------------------
//  Result := 0;
//  for I := 1 to Length(Key) do
//    Result := ((Result shl 2) or (Result shr (SizeOf(Result) * 8 - 2))) xor
//      Ord(Key[I]);
end;

function TIntegerHash.Modify(const Key: Integer; Value: Integer): Boolean;
var
  P: PHashItem;
begin
  P := Find(Key)^;
  if P <> nil then
  begin
    Result := True;
    P^.Value := Value;
  end
  else
    Result := False;
end;

procedure TIntegerHash.Remove(const Key: Integer);
var
  P: PHashItem;
  Prev: PPHashItem;
begin
  Prev := Find(Key);
  P := Prev^;
  if P <> nil then
  begin
    Prev^ := P^.Next;
    Dispose(P);
  end;
end;

function TIntegerHash.ValueOf(const Key: Integer): Integer;
var
  P: PHashItem;
begin
  P := Find(Key)^;
  if P <> nil then
    Result := P^.Value
  else
    Result := -1;
end;


end.

