unit fsListString;

//fs ǰ׺Ϊ����ԭ delphi7 ��֮ǰ�汾���ݽṹ�����ĸ����ܰ汾

//�� fsList һ�����㷨,�ƶ����һ��Ԫ��,��Ԫ��ֱ���� string

interface

uses SysUtils, Classes;


type

  TFastListString = class(TObject) //class //��ʵ��д����� (TObject) Ҳ��һ����
  private
    FList: array of string;//TList;
    FCount: Integer;
    FCapacity: Integer;
    function Get(Index: Integer): string;
    procedure Put(Index: Integer; const Value: string);

    //����һ�����ݽṹ,ע�����ڲ������ڴ��//̫����,�ݲ�ʵ��
    //procedure Add(Item: Pointer);
    function AddItem(SizeOfItem:Integer):Pointer;

    //ɾ��һ�����ݽṹ,ע��ֻ����ɾ���ڲ������ڴ��//̫����,�ݲ�ʵ��
    procedure RemoveItem(Item: Pointer);

    //���� procedure TList.Grow; ԭ�㷨�ܸ�Ч,����ֱ����
    procedure Grow;
  public
    //Count:Integer;

    constructor Create(Capacity: Integer = 0);
    destructor Destroy; override;
    procedure Clear;
    //�ջ�ɾ���������õ��ڴ�,��ʵ���� TList �� Capacity property.//����������û�б�Ҫ������
    procedure FreeMemoryForDelete;


    //��ͳ������һ���ⲿָ��//Ҳ������ TList һ������һ��ǿ��ת��Ϊָ�������ֵ//�������� RemoveItem ��ɾ��,ֻ��ʹ��ָ�������� Delete
    //����ֵΪ��Ԫ���������е�����(Ŀǰ�� TList һ������Ϊʼ�������һ��)
    function Add(const Item: string):Integer;

    //��ͳɾ��//�� Add ��Ӧ//�� TList ���������б��е�Ԫ��˳��ᱻ����,������ sort ���Ĵ�ͳ TList
    //����ֵΪ��Ӱ���Ԫ������//�� TList ��������, TList �ڲ���λ�ú��Ԫ������ֵȫ��Ҫ����,������ֻ��Ӱ��һ��Ԫ��,����ֱ�ӷ������������ž����� 
    function Delete(Index: Integer):Integer;

    property Count: Integer read FCount;// write SetCount;
    property Items[Index: Integer]: string read Get write Put; default;

  end;

implementation


{ TFastListString }

function TFastListString.Add(const Item: string):Integer;
begin
  inc(FCount);

  //Result := FList.Add(Item); //�������������е�λ��// 2015/4/27 16:55:54 ����ֱ�Ӽ��Ϻ���,��Ϊɾ��ʱ���ܻ����пհ�
  //Exit; //ll// ������ hashmap ��ʵ�ּ� bug �߼�

  //���������²�������:
  //1.������ 1..10
  //2.ɾ�� ��6�� �� list[5],�����Ҳȫ��ɾ��
  //3.�ټ�һ�� 6,�� list[5],��ʱ���ӡ�ᷢ�����ֶԲ��ϵ�,��Ϊ FList ��ûɾ��,��ʱ�� 6 �ӵ� list[10] ����
  //4.�����ټ� 6..20 ��ȫ����ӡ�ǲ������ 1..20 ��

  if FCount>Length(FList) //FList.Count //��������������ټ�,��Ϊ�ϴ�ɾ���Ŀ��ܻ��пռ�
  then begin Grow; FList[FCount - 1] := Item; end //FList.Add(Item) //���� procedure TList.Grow; ԭ�㷨�ܸ�Ч,����ֱ����
  else FList[FCount - 1] := Item;

  Result := FCount - 1; //���Բ��۵ײ㴰�����,����һ���Ƿ������һ��Ԫ�زŶ�

end;

//���� procedure TList.Grow; ԭ�㷨�ܸ�Ч,����ֱ����
procedure TFastListString.Grow;
var
  Delta: Integer;
begin
  if FCapacity > 64 then
    Delta := FCapacity div 4
  else
    if FCapacity > 8 then
      Delta := 16
    else
      Delta := 4;

  //SetCapacity(FCapacity + Delta);
  FCapacity := FCapacity + Delta;
  SetLength(FList, FCapacity);
end;

function TFastListString.AddItem(SizeOfItem: Integer): Pointer;
begin

end;

procedure TFastListString.Clear;
begin
  SetLength(FList, 0);//FList.Clear;
  FCapacity := 0;
  FCount := 0;
  
end;

constructor TFastListString.Create(Capacity: Integer = 0);
begin
  //Self.FList := TList.Create;

  FCapacity := Capacity;//1024 * 1024;
  SetLength(FList, FCapacity);

end;

function TFastListString.Delete(Index: Integer):Integer;
begin
  //Dec(FCount);//���滹Ҫ�õ�

  //�㷨�Ƚϼ�,��������ɾ��,ֻ�ǽ����һ��Ԫ����䵽Ҫɾ����λ�ü���
  FList[index] := FList[FCount-1];

  //���� PackMem ʱ�ͷŶ����ڴ�

  Dec(FCount);
  //FList.Count := FCount+1;//test //����������Խ�����
  //FList.Capacity := FCount+1;//test //����������Խ�����

  Result := Index;//ע��,���ɾ���������һ��Ԫ��,����ֵ�ᳬ��������,��Ȼ���ᳬ���ײ�����

  if Index = FCount then Result := -1; //���һ��Ԫ��ɾ���Ļ����Ǳ���˵���ô����

end;

destructor TFastListString.Destroy;
begin
  Self.Clear;
  //FList.Clear;
  //FList.Free;

  inherited;
end;

procedure TFastListString.FreeMemoryForDelete;
begin
  SetLength(FList, FCount); //FList.Count := FCount;// 2015/5/12 14:20:50 ���Ҳ������
  FCapacity := FCount; //�ͷ������ڴ�//������˵ÿ�ζ��ӵ����;ÿ�ζ��ƶ�����Ԫ��,Ӧ���ǲ���ɾ������Ԫ�صĿռ��,������δ����
end;

function TFastListString.Get(Index: Integer): string;
//resourcestring
const
  SListIndexError = 'TFastListString: List index out of bounds (%d) . count: %d [�����������һ��Ԫ��]';
begin
  if (Index < 0) or (Index >= FCount) then
    raise Exception.CreateFmt(SListIndexError, [index, FCount]);


  Result := FList[index];
end;

procedure TFastListString.Put(Index: Integer; const Value: string);
begin
  FList[index] := Value;

end;

procedure TFastListString.RemoveItem(Item: Pointer);
begin

end;


end.
