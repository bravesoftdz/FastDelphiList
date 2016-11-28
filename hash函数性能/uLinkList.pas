unit uLinkList;

//���� umgr2 �Ѿ��ܳɹ���˫�������ʵ��

//��Ϊ�õ��� SysUtils ,����һЩ�����޷�ʵ��,��˳����Ĺ�����Ĺ����������ط�ʵ��//����: uLinkListFun,


interface

//uses
//  Windows;
//����������������Ԫ
function MessageBox(hWnd: THandle{HWND}; lpText, lpCaption: PAnsiChar; uType: LongWord{UINT}): Integer; stdcall;


const
  _LINK_LIST_AS_TAG_ : Byte = 111;//һ���򵥵� AS �����ڴ�����У��

type
  PLinkNode = ^TLinkNode;
  TLinkNode = packed record
    data: Integer;//ָ��Ҳת�������,������ַ����Ž�һ���ṹ�����
    next: PLinkNode;
    prev: PLinkNode;
    _tag:Byte;//������� _LINK_LIST_AS_TAG_,��Ϊ����ָ�����,����У��һ�µĺ�
    //count:integer;//�򵥻�,���ṩ count ���ڲ���,�ɵ��ýṹ��ʵ�־�����,����һ���ڵ�Ҳ���Ա�ʾһ������
    //���Ժ���Ȼ���Ǹ��Ƚ��ȳ��Ķ���,ֻҪ��סͷָ�������
  end;

//���ĺ���������  
procedure Add_LinkList(var head:PLinkNode; var node:PLinkNode);
procedure Del_LinkList(var head:PLinkNode; var node:PLinkNode);
//--------------------------------------------------
//�������������漰�ڴ����,ʵ���϶Ը����ܳ�����˵�ǲ��õ�
//��Ϊ�õ��� SysUtils ,����һЩ�����޷�ʵ��,��˳����Ĺ�����Ĺ����� uLinkListFun ʵ��
//procedure AddData_LinkList(var head:PLinkNode; data:Integer);
//procedure FreeNode_LinkList(var head:PLinkNode; var node:PLinkNode);


implementation

const
  user32    = 'user32.dll';
  
function MessageBox; external user32 name 'MessageBoxA';

procedure Add_LinkList(var head:PLinkNode; var node:PLinkNode);
begin
  //as У���־
  if head<>nil then head._tag := _LINK_LIST_AS_TAG_;
  if node<>nil then node._tag := _LINK_LIST_AS_TAG_;

  //--------------------------------------------------

  //if head = nil then head := node;

  if head<>nil then head.prev := node;
  //head.next ���ñ�

  //node.prev ���ñ�
  node.next := head;

  head := node;//�ӵ�ͷ��,����Ҫ�滻ͷ

end;

procedure Del_LinkList(var head:PLinkNode; var node:PLinkNode);
//var
//  node_old:n
begin
  if node = nil then Exit;

  //--------------------------------------------------
  //as У���־//��ʵ��ʱ messagebox �Ѿ�����ȫ,�����ڲ���
  if node._tag <> _LINK_LIST_AS_TAG_ then MessageBox(0, 'LinkList ˫������ָ�����!','error', 0);//System.Error(reAccessViolation);//RaiseException(EXCEPTION_STACK_OVERFLOW, 0, 0, 0);;

  //--------------------------------------------------

  //1. node ����һ���ڵ�
  if node.prev<>nil then
  begin
    //.prev ���ñ�
    node.prev.next := node.next;
  end;

  //2. node ����һ���ڵ�
  if node.next<>nil then
  begin
    node.next.prev := node.prev;
    //.next ���ñ�

  end;

  //3. ͷ�ڵ�
  if head<>nil then
  begin
    //.prev ���ñ�
    //.next ���ñ�

    //������Ҫ��
    if head = node  then head := node.next;//���ɾ������ͷ�ڵ�,��ͷ������һλ

  end;

end;





end.
