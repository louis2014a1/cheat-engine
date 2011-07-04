unit formChangedAddresses;

{$MODE Delphi}

interface

uses
  windows, LCLIntf, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls,CEFuncProc, ExtCtrls, ComCtrls, Menus, NewKernelHandler, LResources,
  disassembler, symbolhandler, byteinterpreter, CustomTypeHandler, maps, math;

type
  TAddressEntry=class
  public
    address: ptruint; //for whatever reason it could be used in the future
    context: TContext;
    stack: record
      stack: pbyte;
      savedsize: dword;
    end;
    count: integer;

    procedure savestack;
    destructor destroy; override;
  end;


  { TfrmChangedAddresses }

  TfrmChangedAddresses = class(TForm)
    lblInfo: TLabel;
    micbShowAsHexadecimal: TMenuItem;
    Panel1: TPanel;
    OKButton: TButton;
    Changedlist: TListView;
    cbDisplayType: TComboBox;
    Timer1: TTimer;
    PopupMenu1: TPopupMenu;
    Showregisterstates1: TMenuItem;
    Browsethismemoryregion1: TMenuItem;
    procedure ChangedlistColumnClick(Sender: TObject; Column: TListColumn);
    procedure ChangedlistCompare(Sender: TObject; Item1, Item2: TListItem;
      Data: Integer; var Compare: Integer);
    procedure micbShowAsHexadecimalClick(Sender: TObject);
    procedure OKButtonClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormShow(Sender: TObject);
    procedure ChangedlistDblClick(Sender: TObject);
    procedure PopupMenu1Popup(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure Showregisterstates1Click(Sender: TObject);
    procedure Browsethismemoryregion1Click(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
    addresslist: TMap;
    procedure refetchValues(specificaddress: ptruint=0);
  public
    { Public declarations }
    procedure AddRecord;
  end;


implementation


uses CEDebugger, MainUnit, frmRegistersunit, MemoryBrowserFormUnit, debughelper, debugeventhandler;

resourcestring
  rsStop='Stop';
  rsClose='Close';
  rsNoDescription = 'No Description';

destructor TAddressEntry.destroy;
begin
  if stack.stack<>nil then
    freemem(stack.stack);

  inherited destroy;
end;

procedure TAddressEntry.savestack;
begin
  getmem(stack.stack, savedStackSize);
  ReadProcessMemory(processhandle, pointer(context.{$ifdef cpu64}Rsp{$else}esp{$endif}), stack.stack, savedStackSize, stack.savedsize);
end;


procedure TfrmChangedAddresses.AddRecord;
var s: string;
haserror: boolean;
address: ptrUint;
 i: integer;
 li: tlistitem;
 currentthread: TDebugThreadHandler;

 x: TaddressEntry;
begin
  //the debuggerthread is idle at this point
  currentThread:=debuggerthread.CurrentThread;
  if currentthread<>nil then
  begin
    //get the instruction address
    address:=currentThread.context.{$ifdef cpu64}Rip{$else}eip{$endif};
    s:=disassemble(address);
    i:=pos('[',s)+1;
    s:=copy(s,i,pos(']',s)-i);

    address:=symhandler.getAddressFromName(s, false, haserror, currentthread.context);

    if not hasError then
    begin
      //check if this address is already in the list
      if addresslist.GetData(address, x) then
      begin
        inc(x.count);
        refetchValues(x.address);
        exit;
      end;

      s:=inttohex(address,8);

      //and if not, add it


      li:=changedlist.Items.add;
      li.caption:=s;
      li.SubItems.Add('');
      li.subitems.add('1');


      x:=TAddressEntry.create;
      x.context:=currentthread.context^;
      x.address:=address;
      x.count:=1;
      x.savestack;


      li.Data:=x;

      addresslist.Add(address, x);
      refetchValues(x.address);
    end;
  end;
end;

procedure TfrmChangedAddresses.OKButtonClick(Sender: TObject);
var temp: dword;
    i: integer;

begin

  if OKButton.caption=rsStop then
  begin
    debuggerthread.FindWhatCodeAccessesStop(self);
    okButton.Caption:=rsClose;
  end
  else
    close;

end;

procedure TfrmChangedAddresses.micbShowAsHexadecimalClick(Sender: TObject);
begin
  refetchvalues;
end;

procedure TfrmChangedAddresses.ChangedlistColumnClick(Sender: TObject;
  Column: TListColumn);
begin
  changedlist.SortColumn:=Column.Index;
  changedlist.SortType:=stData;
end;

procedure TfrmChangedAddresses.ChangedlistCompare(Sender: TObject; Item1,
  Item2: TListItem; Data: Integer; var Compare: Integer);
var i1, i2: TAddressEntry;
    hex, hex2: qword;
    x: dword;
    varsize: integer;
begin
  compare:=0;
  i1:=item1.data;
  i2:=item2.data;

  if (i1=nil) or (i2=nil) then exit;

  case changedlist.SortColumn of
    0: //sort by address
    begin
      compare:=CompareValue(i1.address, i2.address);
    end;


    1: //sort by value
    begin
      hex:=0;
      hex2:=0;
      case cbDisplayType.itemindex of
        0: varsize:=1;
        1: varsize:=2;
        2: varsize:=4;
        3: varsize:=4;
        4: varsize:=8;
        else
        begin
          Compare:=0;
          exit;
        end;
      end;

      if not ReadProcessMemory(processhandle, pointer(i1.address), @hex, VarSize, x) then
      begin
        compare:=-1;//1<2
        exit;
      end;

      if not ReadProcessMemory(processhandle, pointer(i2.address), @hex2, VarSize, x) then
      begin
        compare:=1;//1>2
        exit;
      end;

      if micbShowAsHexadecimal.checked then
      begin
        compare:=hex-hex2;
      end
      else
      begin
        case cbDisplayType.itemindex of
          0: compare:=byte(hex)-byte(hex2);
          1: compare:=word(hex)-word(hex2);
          2: compare:=dword(hex)-dword(hex2);
          3: if psingle(@hex)^>psingle(@hex2)^ then
               compare:=1
             else
             if psingle(@hex)^=psingle(@hex2)^ then
               compare:=0
             else
               compare:=-1;

          4: if pdouble(@hex)^>pdouble(@hex2)^ then
               compare:=1
             else
             if pdouble(@hex)^=pdouble(@hex2)^ then
               compare:=0
             else
               compare:=-1;
        end;
      end;
    end;

    2: //sort by count
    begin
      compare:=CompareValue(i1.count, i2.count);
    end;
  end;
end;

procedure TfrmChangedAddresses.FormClose(Sender: TObject;
  var Action: TCloseAction);
var temp:dword;
    i: integer;
    ae: TAddressEntry;
begin
  action:=caFree;


  for i:=0 to changedlist.Items.Count-1 do
  begin
    ae:=TAddressEntry(changedlist.Items[i].Data);
    ae.free;
  end;

  if OKButton.caption=rsStop then
    OKButton.Click;
end;

procedure TfrmChangedAddresses.FormShow(Sender: TObject);
begin
  OKButton.Caption:=rsStop;
end;

procedure TfrmChangedAddresses.ChangedlistDblClick(Sender: TObject);
var i: integer;
    ad: dword;
begin
  if changedlist.Selected<>nil then
    mainform.addresslist.addaddress(rsNoDescription,
      changedlist.selected.caption, [], 0, OldVarTypeToNewVarType(
      cbDisplayType.itemindex));
end;

procedure TfrmChangedAddresses.PopupMenu1Popup(Sender: TObject);
begin
  Showregisterstates1.enabled:=changedlist.selected<>nil;
  Browsethismemoryregion1.enabled:=changedlist.selected<>nil;
end;

procedure TfrmChangedAddresses.refetchValues(specificaddress: ptruint=0);
var i: integer;
    s: string;
    handled: boolean;
    startindex: integer;
    stopindex: integer;
begin
  if changedlist.Items.Count>0 then
  begin
    if Changedlist.TopItem=nil then exit;

    startindex:=Changedlist.TopItem.Index;
    stopindex:=min(Changedlist.TopItem.Index+changedlist.VisibleRowCount, Changedlist.Items.Count-1);

    for i:=startindex to stopindex do
    begin

      if (specificaddress<>0) and (TAddressEntry(changedlist.items[i].Data).address <> specificaddress) then //check if this is the line to update, if not, don't read and parse
        continue;


      case cbDisplayType.ItemIndex of
        0: s:=ReadAndParseAddress(TAddressEntry(changedlist.items[i].Data).address, vtByte,  nil, micbShowAsHexadecimal.checked);
        1: s:=ReadAndParseAddress(TAddressEntry(changedlist.items[i].Data).address, vtWord,  nil, micbShowAsHexadecimal.checked);
        2: s:=ReadAndParseAddress(TAddressEntry(changedlist.items[i].Data).address, vtDWord, nil, micbShowAsHexadecimal.checked);
        3: s:=ReadAndParseAddress(TAddressEntry(changedlist.items[i].Data).address, vtSingle,nil, micbShowAsHexadecimal.checked);
        4: s:=ReadAndParseAddress(TAddressEntry(changedlist.items[i].Data).address, vtDouble,nil, micbShowAsHexadecimal.checked);
        else
        begin
          //custom type
          s:=ReadAndParseAddress(TAddressEntry(changedlist.items[i].Data).address, vtCustom, TCustomType(cbDisplayType.Items.Objects[cbDisplayType.ItemIndex]), micbShowAsHexadecimal.checked);
        end;
      end;



      while Changedlist.Items[i].SubItems.Count<2 do
        Changedlist.Items[i].SubItems.Add('');


      changedlist.items[i].SubItems[1]:=inttostr(TAddressEntry(changedlist.items[i].Data).count);



      Changedlist.Items[i].SubItems[0]:=s;
    end;
  end;
end;

procedure TfrmChangedAddresses.Timer1Timer(Sender: TObject);
begin
  refetchValues;
end;

procedure TfrmChangedAddresses.Showregisterstates1Click(Sender: TObject);
var ae: TAddressEntry;
begin
  if changedlist.Selected<>nil then
  begin
    with TRegisters.create(self) do
    begin
      borderstyle:=bsSingle;

      ae:=TAddressEntry(changedlist.Selected.Data);

      SetContextPointer(@ae.context, ae.stack.stack, ae.stack.savedsize);

      show;
    end;
  end;
end;

procedure TfrmChangedAddresses.Browsethismemoryregion1Click(
  Sender: TObject);
begin
  if changedlist.Selected<>nil then
  begin
    memorybrowser.memoryaddress:=StrToQWordEx('$'+changedlist.Selected.Caption);
    if not memorybrowser.visible then
      memorybrowser.show;
  end;
end;

procedure TfrmChangedAddresses.FormDestroy(Sender: TObject);
begin
  saveformposition(self,[]);
  if addresslist<>nil then
    addresslist.Free;
end;

procedure TfrmChangedAddresses.FormCreate(Sender: TObject);
var x: array of integer;
    i: integer;
begin
  okbutton.caption:=rsStop;

  setlength(x, 0);
  loadformposition(self,x);

  //fill in the custom types
  for i:=0 to customTypes.count-1 do
    cbDisplayType.Items.AddObject(TCustomType(customTypes[i]).name, customTypes[i]);

  addresslist:=TMap.Create(ituPtrSize,sizeof(pointer));
end;

initialization
  {$i formChangedAddresses.lrs}

end.

