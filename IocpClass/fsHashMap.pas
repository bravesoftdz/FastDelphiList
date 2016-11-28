
unit fsHashMap;

//�������� hash ���� key �б�//�����ϵ�ͬ�ڴ�ͳ C++ �����ϵ� hashmap,�������� multimap һ���������ֵ,���Բ���ǰӦ���ж��Ƿ�����ͬ�ļ���
//�Ӵ�ͳ����� hashmap ��˵Ӧ�����Լ��ж��ظ���,����Ϊ�˼��� delphi ԭ���� TStringHash ������������,���Ҿ��������޸�ԭ�㷨����

{$R-,T-,H+,X+}
//Range Checking                    {$R}
//Typed @ Operator                  {$T}
//Huge Strings                      {$H}
//Extended Syntax                   {$X}

interface

uses SysUtils, Classes, fsList, fsIntegerHashList, IniFiles;

type
  THashMap = TIntegerHashList;

  //��ʵ����������� TIntegerHashList �Ϳ��Բ�Ҫ string2integer �� hash ʵ����,ֻҪ��ȡֵǰ��һ�� hash ֵ�Ϳ�����
  //�ϸ���˵���ǲ���,��Ϊ string hash ����г�ͻ��
  function HashOf(const Key: string): Cardinal;

  //--------------------------------------------------
  //ɾ���õķ����Ժ���//��Ϊ����ֱ���� for ��ʱ��ɾ��
  type IntArr = array of Integer;
  procedure SetMax(var arr:IntArr; MaxLength: Integer);
  procedure Add(arr:IntArr; value:Integer);
  function Count(arr:IntArr):Integer;


implementation

function HashOf(const Key: string): Cardinal;
//���� function TStringHash.HashOf(const Key: string): Cardinal;
var
  I: Integer;
begin
  Result := 0;
  for I := 1 to Length(Key) do
    Result := ((Result shl 2) or (Result shr (SizeOf(Result) * 8 - 2))) xor
      Ord(Key[I]);
end;

//--------------------------------------------------
//ɾ���õķ����Ժ���//��Ϊ����ֱ���� for ��ʱ��ɾ��

{$R+} //Range Checking �ж�̬����ĵط����У��һ��//���� IniFiles.pas ���ǹرյ�,������Ӱ������ 

procedure SetMax(var arr:IntArr; MaxLength: Integer);
begin
  SetLength(arr, MaxLength+1);//���һ��Ԫ�����������
end;

procedure Add(arr:IntArr; value:Integer);
var
  count:Integer;
begin
  count := arr[Length(arr)-1];//���һ��Ԫ�����������
  Inc(count);

  arr[count-1] := value;

  arr[Length(arr)-1] := count;//���һ��Ԫ�����������

end;

function Count(arr:IntArr):Integer;
var
  count:Integer;
begin
  count := arr[Length(arr)-1];//���һ��Ԫ�����������

  result := count;
end;

{$R-} //Range Checking

//-------------------------------------------------- 

end.