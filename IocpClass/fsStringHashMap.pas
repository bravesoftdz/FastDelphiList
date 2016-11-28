
unit fsStringHashMap;

//����ͬ fsIntegerHashList ֻ��Ԫ��ֱ��Ϊ string

{$R-,T-,H+,X+}
//Range Checking                    {$R}
//Typed @ Operator                  {$T}
//Huge Strings                      {$H}
//Extended Syntax                   {$X}

interface

uses SysUtils, Classes, fsList, fsListString, Dialogs, IniFiles;


type

  TStringHashMap = class
  private
    //Buckets: array of PHashItem;
    FHashList:TStringHash;


    //clq ������������
    //FList:TFastList;
    FList:TFastListString;
    //����λ�� FList ��ͬ,���ұ�����ͬ//ֻ������������ FList ��Ӧ�� key ����,��Ϊԭʼ�� TStringHash û���ṩ����ӿ�
    FKeyList:TFastListString;
    //clq ������������
    function Get(Index: Integer): string;
    function GetKey(Index: Integer): string;
    function GetValue(const Name: string): string;
    procedure SetValue(const Name, Value: string);

  protected
    function Find(const Key: string): Integer;
    //function HashOf(const Key: Integer): Cardinal; virtual;
  public
    constructor Create(Size: Cardinal = 65536); //256);//65535 ���� 65536 ?
    destructor Destroy; override;
    procedure Add(const Key: string; Value: string);
    procedure Clear;
    procedure Remove(const Key: string);
    function Modify(const Key: string; Value: string): Boolean;
    function ValueOf(const Key: string): string;

  public//�¼ӵı����ӿ�
    function Count: Integer;
    //��Ϊֻ������������,���ԾͲ�����д����,��Ȼд��Ҳ�ǿ��Ե�,�������ֵ��Ҫ�������ָ�����Ի��ǲ�Ҫ�ĵĺ�
    property Items[Index: Integer]: string {��ǰ��� Value: Integer} read Get;
    //��Ϊֻ������������,���ԾͲ�����д����,��Ȼд��Ҳ�ǿ��Ե�,�������ֵ��Ҫ�������ָ�����Ի��ǲ�Ҫ�ĵĺ�
    property Keys[Index: Integer]: string {��ǰ��� Key: Integer} read GetKey;

    property Values[const Name: string]: string read GetValue write SetValue;

  end;

implementation

{ TStringHashMap }

procedure TStringHashMap.Add(const Key: string; Value: string);
var
  //Hash: Integer;
  index:Integer;
begin
  Remove(Key); //��Ϊ��ʵ���ǲ��������,����Ҫ��ɾ���ɵ�, integer �� hashmap ��ΪЧ�ʵĹ�ϵû�м��ⲽ,Ҫ�Լ�����
  //�����ܵ�Ӱ�컹�ǱȽϴ��,���ܻ���Ҫ��취һ��ֻ find һ��(��ʵҲ���� find ��һ��)
  //Find(Key);//����ǳ�ʼ����Ҫ������Կ� 3 �� 5 ��,����ʵ�����Ѿ��ǳ�����,���Բ����ⲽ�Ż�

  index := FList.Add(Value); //�ȴ������õ�λ������

  FHashList.Add(Key, index); //�� value ��Ӧ��λ�������������� key ����

  //FList[index] := Value;
  FKeyList.Add(Value);
  FKeyList[index] := Key;

end;

procedure TStringHashMap.Clear;
begin

  FHashList.Clear;
  //--------------------------------------------------
  FList.Clear;

end;

function TStringHashMap.Count: Integer;
begin
  Result := FList.Count;
end;

constructor TStringHashMap.Create(Size: Cardinal);
begin
  inherited Create;
  //SetLength(Buckets, Size);
  FHashList := TStringHash.Create(Size);


  //--------------------------------------------------
  FList := TFastListString.Create(Size);
  FKeyList := TFastListString.Create(Size);
end;

destructor TStringHashMap.Destroy;
begin
  Clear;

  FHashList.Clear;
  //--------------------------------------------------
  FList.Free;

  inherited Destroy;
end;

function TStringHashMap.Find(const Key: string): Integer; //�����ڲ���������λ�õ�,���Է��� integer
begin

  Result := FHashList.ValueOf(Key); //�Ҳ����Ļ��� -1

end;

function TStringHashMap.Get(Index: Integer): string;
begin
  Result := FList[Index]; //clq ָ�벻����,�����������
end;

function TStringHashMap.GetKey(Index: Integer): string;
begin
  //Result := PHashItem(FList[Index]).Key; //clq ָ�벻����,�����������
  //����� key �� value �Ƿ����,��������λ��һ��Ҫ��׼ȷ��

  Result := FKeyList[Index];

end;



function TStringHashMap.GetValue(const Name: string): string;
begin
  Result := ValueOf(Name);
end;

function TStringHashMap.Modify(const Key: string; Value: string): Boolean;
var
  index: Integer;
begin

  index := FHashList.ValueOf(Key); //�Ҳ����Ļ��� -1

  if index <> -1 then
  begin
    FList[index] := Value;
    FKeyList[index] := Key;

    Result := True;
  end
  else
    Result := False;
end;

procedure TStringHashMap.Remove(const Key: string);
var
  P: PHashItem;
  Prev: PPHashItem;
  index:Integer; //clq �ڵ��ڱ��������е���������
  MoveIndex:Integer;//clq ���ƶ��ı��������Ԫ������[Ŀǰ�㷨�����һ��Ԫ�ز��䵽��ǰԪ��λ������]

  oldKeyIndex, oldValueIndex:Integer; //��Ϊɾ��ʱ�ƶ������һ���ڵ�,���������һ���ڵ��Ӧ�� kv ֵҪ��������
  oldKey, oldValue:string; //��Ϊɾ��ʱ�ƶ������һ���ڵ�,���������һ���ڵ��Ӧ�� kv ֵҪ��������
begin
  index := Find(Key);

  if index <> -1 then
  begin
    oldKeyIndex := FList.Delete(index);
    oldValueIndex := FKeyList.Delete(index);

    if oldKeyIndex<>-1 then //�Ա��ƶ��ľɽڵ�(��ʵ�����һ���ڵ�)��������ֵ����,����ֵΪ -1 ��ʾ���һ��,�Ͳ�Ҫ������
    begin

      oldKey := FKeyList[oldKeyIndex];
      oldValue := FKeyList[oldValueIndex];

      //FHashList.Remove(oldKey); //����Ǳ��ı��˵�,Ҫɾ��//������ʵ��һ��Σ��,����Ҫ��֤����ɾ����������ȷ
      //--------------------------------------------------
      //������Щ�Ϸ����ж϶����ܼ�����Ӱ��[���Լ�����Ϊ 2000000]

      //if  FHashList.ValueOf(oldKey)<>oldKeyIndex
      if  FHashList.ValueOf(oldKey)<>FList.Count //��ʱ�� �ƶ�������Ӧ�������һ��
      then ShowMessage('TStringHashMap.Remove �ײ����ʵ����������.');

      if  oldValueIndex<>oldKeyIndex
      then ShowMessage('TStringHashMap.Remove �ײ����ʵ����������2.');


      //--------------------------------------------------
      //���±�ɾ��������

      //FHashList.Remove(oldKey);
      //FHashList.Add(oldKey, index); //���ƶ�������ڵ��Ԫ������Ҫ����
      FHashList.Modify(oldKey, index); //���ƶ�������ڵ��Ԫ������Ҫ����

    end;

    //--------------------------------------------------
    FHashList.Remove(Key); //��һ���ǿ϶�Ҫ���е�
  end;
end;

procedure TStringHashMap.SetValue(const Name, Value: string);
begin
//  Remove(name); //���������,�� key �����ظ�,�ظ���Ҫ��ɾ���ɵ�//������Ӱ�컹�ǱȽϴ��
  Add(Name, Value);
end;

function TStringHashMap.ValueOf(const Key: string): string;
var
  index:Integer; //clq �ڵ��ڱ��������е���������
begin
  index := Find(Key);

  if index <> -1 then
    Result := FList[index]
  else
    Result := '';
end;


end.

