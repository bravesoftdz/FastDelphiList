unit htestmain1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Math, WinSock,
  Dialogs, StdCtrls;

type
  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    Button4: TButton;
    Button5: TButton;
    procedure FormCreate(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

uses uHashList, uLinkList, uLinkListFun;

{$R *.dfm}


procedure InitSocket();
var
  rWSAData: TWSADATA;
  wSockVer: Word;
begin


  wSockVer := MAKEWORD(2,0);
  if Winsock.WSAStartup( wSockVer, rWSAData ) <> 0 then
  begin
    //Memo.Lines.Add( 'WSAStartUp Failed!' );
    Exit;
  end;


end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  //TMemoryStream

  InitSocket();
  
end;

procedure TForm1.Button4Click(Sender: TObject);
begin
  ShowMessage(IntToStr(Trunc(Log2(2000))))  ;
end;

procedure TForm1.Button1Click(Sender: TObject);
var
  list:THashList;
  i:Integer;
begin

  Init_IntHashList(list);
  SetCapacity_HashList(list, 80000);//ֻռ��Լ 2m �ڴ�


  //for i := 0 to 20000 do
  for i := -1000 to 2000 do
  begin
    Put_HashList(list, i, i); //�����ɢ���ܺ�,�ܼ����ɵ������ֻ��Ҫ������������������

//    Put_HashList(list, socket(AF_INET, SOCK_STREAM, IPPROTO_IP), i);//������ܼ����� socket �Ļ�ɢ��Ҳ�ܺ�,��������������������4��,��ʱ��ͻ����Ϊ 0 !

  end;

  SetLength(list.list, 0);

end;

procedure TForm1.Button3Click(Sender: TObject);

type
  TStringRecTest = record
    str:string;
    i:Integer;
  end;

var
  list:TStrHashList;
  i:Integer;
  str:string;
  str2:TStringRecTest;
  vi:Integer;
begin

  FillChar(str2, SizeOf(str2), 0);
  ShowMessage(str2.str);

  Init_StrHashList(list);
  SetCapacity_StrHashList(list, 40000);


  for i := 0 to 10000 do
  //for i := -1000 to 2000 do
  begin
    //str := IntToStr(i);//��� 2 ��������ʱ��ͺܺ�

    str := {str + }IntToStr(i);//��� 4 ��������ʱ��Ҳ��̫��,��ͻֻ�Ǵ� 500 ���Ϊ 200 ��,���ݵ����岻��,�������ַ��� hash ������ԭ��
    //10000 �Ļ�Ҫ�� 16 ���Ĳź�,�����ڴ�ռ�ú�С,���Կ���һ������Ҳ��Ҫ��

    Put_StrHashList(list, str, i);
    //Break;
  end;

  if Get_StrHashList(list, '10000', vi)<>-1
  then ShowMessage(IntToStr(vi));

end;

procedure TForm1.Button5Click(Sender: TObject);
var
  head, node:PLinkNode;
begin
  head := nil;//��Ա�����Ż��ʼ��,�ֲ����������//ȫ�ֱ���Ҳ��
//  node := AllocMem(SizeOf(TLinkNode));

//  Add_LinkList(head, node);
  node := AddData_LinkList(head, 3);
  AddData_LinkList(head, 3);//�������������

  ShowMessage(IntToStr(head.data));
  FreeNode_LinkList(head, node);

end;

end.
