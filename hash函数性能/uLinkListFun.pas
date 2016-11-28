unit uLinkListFun;

//��Ϊ�õ��� SysUtils ,����һЩ�����޷�ʵ��,��˳����Ĺ�����Ĺ���������ʵ��//ʵ������ uLinkList ����չ

interface

uses
  SysUtils, uLinkList;

type
  TLinkListRec = record//TLinkList �������������
    head:PLinkNode;
    count:Integer;//��ֱ���� PLinkNode ���,��ʵֻ��Ϊ��Ҫ count ������Σ�յ� while ѭ��

  end;


//���ĺ���������  
//procedure Add_LinkList(var head:PLinkNode; var node:PLinkNode);
//procedure Del_LinkList(var head:PLinkNode; var node:PLinkNode);
//--------------------------------------------------
//�������������漰�ڴ����,ʵ���϶Ը����ܳ�����˵�ǲ��õ�
function AddData_LinkList(var head:PLinkNode; data:Integer):PLinkNode;overload;
procedure FreeNode_LinkList(var head:PLinkNode; var node:PLinkNode);overload;

function AddData_LinkList(var list:TLinkListRec; data:Integer):PLinkNode;overload;
procedure FreeNode_LinkList(var list:TLinkListRec; var node:PLinkNode);overload;

implementation



//--------------------------------------------------
//�������������漰�ڴ����,ʵ���϶Ը����ܳ�����˵�ǲ��õ�
function AddData_LinkList(var head:PLinkNode; data:Integer):PLinkNode;
var
  node:PLinkNode;
begin
  node := AllocMem(SizeOf(TLinkNode));

  node.data := data;

  Add_LinkList(head, node);

  Result := node;
end;

procedure FreeNode_LinkList(var head:PLinkNode; var node:PLinkNode);
begin
  Del_LinkList(head, node);

  if node = nil then Exit;

  //FreeAndNil(node);//��Դ�뿴��������,�����Լ�д��

  FreeMem(node);
  node := nil;
end;

function AddData_LinkList(var list:TLinkListRec; data:Integer):PLinkNode;overload;
begin
  Inc(list.count);

  Result := AddData_LinkList(list.head, data);
end;

procedure FreeNode_LinkList(var list:TLinkListRec; var node:PLinkNode);overload;
begin
  Inc(list.count, -1);

  FreeNode_LinkList(list.head, node);
end;  



end.
