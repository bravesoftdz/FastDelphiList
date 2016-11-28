
unit fsIntegerHashList;

//�������� hash ���� key �б�//�����ϵ�ͬ�ڴ�ͳ C++ �����ϵ� hashmap,�������� multimap һ���������ֵ,���Բ���ǰӦ���ж��Ƿ�����ͬ�ļ���
//�Ӵ�ͳ����� hashmap ��˵Ӧ�����Լ��ж��ظ���,����Ϊ�˼��� delphi ԭ���� TStringHash ������������,���Ҿ��������޸�ԭ�㷨����

{$R-,T-,H+,X+}
//Range Checking                    {$R}
//Typed @ Operator                  {$T}
//Huge Strings                      {$H}
//Extended Syntax                   {$X}

interface

uses SysUtils, Classes, fsList, Dialogs;

//ֻ�޸� TStringHash ������,��Ҫ�Ķ�������//�� uTIntegerHash �Ļ����ϼ��� TFastList �ĸ��ٱ����б�����,��ʵ�����ڽڵ��м��˸����ڱ����б��е�����//��ʵ�ñ�׼ TList ʵ�ֲ���ֻ�滻���һ��Ԫ��Ҳ��һ����

type
  { TStringHash - used internally by TMemIniFile to optimize searches. }

  PPHashItem = ^PHashItem;
  PHashItem = ^THashItem;
  THashItem = record
    Next: PHashItem;
    //Key: string;
    Key: Integer;//clq ����ֻ���������
    Value: Integer;
    Index:Integer;//clq ֻ�����ڱ��������е���������
    isDel:Integer;//ttt
  end;

  TIntegerHashList = class
  private
    Buckets: array of PHashItem;

    //clq ������������
    //FList:TFastList;
    FList:TFastList;
    //clq ������������
    function Get(Index: Integer): Integer;
    function GetKey(Index: Integer): Integer;

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

  public//�¼ӵı����ӿ�
    function Count: Integer;
    //��Ϊֻ������������,���ԾͲ�����д����,��Ȼд��Ҳ�ǿ��Ե�,�������ֵ��Ҫ�������ָ�����Ի��ǲ�Ҫ�ĵĺ�
    property Items[Index: Integer]: Integer {��ǰ��� Value: Integer} read Get;
    //��Ϊֻ������������,���ԾͲ�����д����,��Ȼд��Ҳ�ǿ��Ե�,�������ֵ��Ҫ�������ָ�����Ի��ǲ�Ҫ�ĵĺ�
    property Keys[Index: Integer]: Integer {��ǰ��� Key: Integer} read GetKey;

  end;

implementation
{ TIntegerHashList }

procedure TIntegerHashList.Add(const Key: Integer; Value: Integer);
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

  //--------------------------------------------------
  //�������������
  Bucket.Index := FList.Add(Bucket);
  Bucket.isDel := 0;

end;

procedure TIntegerHashList.Clear;
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

  //--------------------------------------------------
  FList.Clear;

end;

function TIntegerHashList.Count: Integer;
begin
  Result := FList.Count;
end;

constructor TIntegerHashList.Create(Size: Cardinal);
begin
  inherited Create;
  SetLength(Buckets, Size);

  //--------------------------------------------------
  FList := TFastList.Create(Size);

end;

destructor TIntegerHashList.Destroy;
begin
  Clear;

  //--------------------------------------------------
  FList.Free;

  inherited Destroy;
end;

function TIntegerHashList.Find(const Key: Integer): PPHashItem;
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

function TIntegerHashList.Get(Index: Integer): Integer;
begin
  Result := PHashItem(FList[Index]).Value; //clq ָ�벻�����,������������
end;

function TIntegerHashList.GetKey(Index: Integer): Integer;
begin
  Result := PHashItem(FList[Index]).Key; //clq ָ�벻�����,������������

end;

function TIntegerHashList.HashOf(const Key: Integer): Cardinal;
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

function TIntegerHashList.Modify(const Key: Integer; Value: Integer): Boolean;
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

procedure TIntegerHashList.Remove(const Key: Integer);
var
  P: PHashItem;
  Prev: PPHashItem;
  Index:Integer; //clq �ڵ��ڱ��������е���������
  MoveIndex:Integer;//clq ���ƶ��ı��������Ԫ������[Ŀǰ�㷨�����һ��Ԫ�ز��䵽��ǰԪ��λ������]
begin
  Prev := Find(Key);
  P := Prev^;

  if P <> nil then
  begin
    //--------------------------------------------------
    //���ͷ�ǰ����������
    Index := p^.Index;
    if Self.FList.Count=0 then
    showmessage('error111 TIntegerHashList.Remove');

    if p^.isDel = 1 then
    showmessage('error111 TIntegerHashList.Remove');

    p^.isDel := 1;

    //PHashItem(FList.Items[FList.Delete(P^.Index)]).Index := index; //���ƶ��Ľڵ�����������ҵ�����������,�����������һ����Ҳ�������,�����ײ�����ȫ��δ��
    MoveIndex := FList.Delete(P^.Index);
    if MoveIndex>=FList.Count
    then ShowMessage('TIntegerHashList.Remove �ײ����ʵ����������.');

    if MoveIndex<>-1 then //ɾ���ķ���ֵΪ -1 �Ļ�˵�������һ��Ԫ��,û�������˱��ƶ�,���ԾͲ�Ҫ������
    PHashItem(FList.Items[MoveIndex]).Index := index; //���ƶ��Ľڵ�����������ҵ�����������,�����������һ����Ҳ�������,�����ײ�����ȫ��δ��

    //������Щ�Ϸ����ж϶����ܼ�����Ӱ��[���Լ�����Ϊ 2000000]

    //------------------
    //�ͷ������ڴ�,�о�û�б�Ҫ����,��Ϊֻ�����������ʱ�Ż�Ӱ������,ÿ��ɾ������ʵ���һ��Ԫ������ǰ���˵�
    //FList.FreeMemoryForDelete;//�ƺ�������

    //--------------------------------------------------

    Prev^ := P^.Next;
    Dispose(P);
  end;
end;

function TIntegerHashList.ValueOf(const Key: Integer): Integer;
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
