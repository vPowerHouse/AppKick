unit AppList;

interface
uses
  Classes, Menus, Winapi.Windows, System.Generics.Collections, Vcl.Grids,
  Vcl.Controls, Vcl.StdCtrls, Vcl.CheckLst, StrUtils, Graphics, ExtCtrls;
const
  hour2dot3 ='hr %2.3f ';
  hour2dot3wS ='hr %2.3f %s';

  selfClass = 'TDesksKick';
  //Not necessary
  TAppClass = 'TApplication';
  GoodApps: Tarray<string> = [ TAppClass,{'TfmGrepResult','TfmPeInformation',} 'Shell_TrayWnd','Notepad', 'TAppBuilder', 'Window',
   'Chrome_WidgetWin_1', 'Notepad++', selfClass ];
//  AppStates: TArray<string> = ['Running','Stopped','Whatnot'];

type

  TappHandles = Tlist<NativeUInt>;

  ptrApp = ^TApp;
  TApp = record
    Handle: HWnd;
    ClassName: string;
    Name: string;
    sVersion: string;
    Title: string;
    sgRow: Integer;
    Used,
    MarkTick,
    AcculmTick : Uint64;
    Icon: TIcon;
  end;

  TptrApps = class(Tlist<ptrApp>)
  private
    phState: string;
    bAllwindows: Boolean;
    SB: TPanel;
    SBSubject: string;
    ChBxs: TCheckListBox;
//    Skippers: TArray<string>;
    DesiredExes: TArray<string>;
    bEverything: Boolean;
//    AppBuilderCount: Integer;   used if want First started last out
//    popup: TPopupMenu;
//    IconList: TImageList;
    Handles: TappHandles;
    AppTimer: TTimer;

    procedure SGdrawCell(Sender: TObject; ACol, ARow: Integer;
                                    Rect: TRect; State: TGridDrawState);
  public
    sgGrid: TStringGrid;
    slLog: TStrings;
    procedure AddNewExe(const aHndl: Hwnd; const aClassName, aTitle, aHour: string);
    procedure ChangeExesList(Sender: TObject);
    procedure ChangeState(Sender: TObject);
    destructor Destroy; override;
//    procedure EnumApps(passedHandle: HWND);
//    procedure EnumApps2(passedHandle: HWND);
//    function ENumWindowsProc(wHandle: HWND; inSG: TStringGrid): BOOL; //stdcall; //just added
    procedure RemoveStaleItems;
    procedure CheckForeGroundWindows(const inHandle: Hwnd);
    procedure CheckforActiveAppTitleChange;
    function getVersionasString(inAppName: string): string;

class function HookInUI(inSG: TStringGrid; inLog: TStrings;  inChBxs: TcheckListBox; inBanner: TPanel): TptrApps;
//class procedure OpenLocalFile(Path, Params: String);
    procedure GetSomeWindows(Sender: TObject);//(WantedApps: TArray<string>);
    procedure Pulse(Sender: TObject);
    procedure StringGridDblClick(Sender: Tobject);
    procedure updateSG(inTool: ptrApp; inRow: Integer);
    //property SBSubject: string;
  end;

implementation

uses
  System.SysUtils, Winapi.Messages, Winapi.PsAPI, ShellAPI, WinApi.ShlObj;
var
  //allocate mem for focusedApp to let lastapp row to be set at start         for hour meters to work and reduced overwrites
  // cacheApp changes when active or focused window changes
  cacheApp : TApp;

  focusedApp: ptrApp;

  type
    PHICON = ^HICON;

  function ExtractIconEx(lpszFile: LPCWSTR; nIconIndex: Integer;
    phiconLarge, phiconSmall: PHICON; nIcons: UINT): UINT; stdcall; external 'shell32.dll' name 'ExtractIconExW';

/// <remarks> SO answer David Heffernan May 20, 2013 at 17:15 </remarks>
function GetSmallIconFromExecutableFile(const FileName: string): TIcon;
var
  Icon: HICON;
  ExtractedIconCount: UINT;
begin
  Result := nil;
  try
    ExtractedIconCount := ExtractIconEx(
      PChar(FileName),
      0,   //was 0
      nil,
      @Icon,
      1
    );
    if
      {$IFDEF CPU32BITS}
            Win32Check(ExtractedIconCount=1)
      {$ELSE}
       (ExtractedIconCount > 0)
      {$ENDIF}

    then begin
      Result := TIcon.Create;
      Result.Handle := Icon;
    end
  except
    Result.Free;
    Result := nil;
  end;
end;


function AppActivate(WindowHandle: HWND): boolean;// overload;
begin
   try
      SendMessage(WindowHandle, WM_SYSCOMMAND, SC_HOTKEY, WindowHandle);
      SendMessage(WindowHandle, WM_SYSCOMMAND, SC_ARRANGE, WindowHandle);
      result := SetForegroundWindow(WindowHandle);
   except
      on Exception do Result := false;
   end;
end;

/// <remarks> source aehimself uBdsLauncher2.pas</remarks>
function GetWindowExeName(wHandle: HWND): string;
var
  PID: DWORD;
  hProcess: THandle;
  nTemp: Cardinal;
  Modules: array [0 .. 255] of THandle;
  Buffer: array [0 .. 4095] of char;
begin
  Result := '';
  if GetWindowThreadProcessId(wHandle, PID) <> 0 then
  begin
    hProcess := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, False, PID);
    if hProcess <> 0 then
      if EnumProcessModules(hProcess, @Modules[0], Length(Modules), nTemp) then
        if GetModuleFileNameEx(hProcess, 0, Buffer, SizeOf(Buffer)) > 0 then
          Result := Buffer;
  end;
end;

{ TptrApps }

procedure TptrApps.AddNewExe(const aHndl: HWnd;const aClassName, aTitle, aHour: string);
var
  lpApp: ptrApp;
begin
  New(lpApp);
  Add(lpApp);
  lpApp.Name := GetWindowExeName(aHndl);
  lpApp.Icon := nil;
  if lpApp.Name <> '' then
    try
      lpApp.Icon := GetSmallIconFromExecutableFile(lpApp.Name);
    except
      lpApp.Icon := nil;
    end;

  lpApp.sVersion := getVersionasString(lpApp.Name);
  lpApp.Name := ExtractFileName(lpApp.Name);
  lpApp.Handle := aHndl;
  lpApp.AcculmTick := 0;
  lpApp.MarkTick := GetTickCount64;
  lpApp.Used := 1;
  lpApp.Title := aTitle;
  lpApp.sgRow := Count;
  lpApp.ClassName := aClassName;
  if aClassName = 'Shell_TrayWnd'
     then begin
            lpApp.Title := 'Show';   { TODO -oPat : add to title check too }
            lpApp.Name := 'Taskbar';
          end;
  // UX here
  updateSG(lpApp, Count);
  SBSubject := lpApp.Name + ' opened.';
  slLog.add(aHour + ' '  + lpApp.Name + ' ' +
    aTitle  + ' ' + ' opened.');//lpApp.AcculmTick.ToString);
end;

procedure TptrApps.ChangeExesList(Sender: TObject);
var
  CXs: TCheckListBox;
  se,
  de: Integer;
  I: Integer;  { TODO -oPat :    Add logic that set checked if the running programs
   are on the list when program is started or when a everthing is selected the self
   doesn't needed so uncheck or leave off list. done }
begin
  se := 0;
  de := 0;
  CXs := Sender as TCheckListBox;
  setlength(DesiredExes,CXs.Items.Count);
//  setlength(Skippers,CXs.Items.Count);
  for I := 0 to CXs.Items.Count - 1 do
    if CXs.Checked[I] then  //
      begin
        DesiredExes[de] := CXs.Items[I];
        Inc(de);
      end;
//    else
//      begin
//        Skippers[se] := CXs.Items[I];
//        Inc(se);
//      end;

  SetLength(DesiredExes, de);
//  SetLength(Skippers,se);
end;

procedure TptrApps.CheckForeGroundWindows(const inHandle: Hwnd);
var
  awn: HWnd;
  sHour: string;
  Title, ClassName: Array [0 .. 255] Of char;
  sClassName: string;
  ii: Integer;
  lpApp: ptrApp;
  ChosenApp: Boolean;
begin

  If inHandle > 0 then
      awn  := inHandle
  else
      // cut out OpenProcess(PROCESS_ALL_ACCESS, False, inPID)
      awn  := GetForegroundWindow;

  if awn = 0 then
    SBSubject := 'Not a foreground window'
  else if awn <> focusedApp.Handle then
    Try
      cacheApp.Handle := awn;
      GetClassName(awn, ClassName, 255);
      GetWindowText(awn, Title, 255);
      cacheApp.Title := Title;
      sHour := Format (hour2dot3, [24 * Time]);
      sClassName := Trim(ClassName);
//      if IndexText(sClassName, Skippers) >= 0
//          then exit;

      chosenApp := IndexText(sClassName, DesiredExes) >= 0;
      if bAllwindows or chosenApp then
        begin
          for ii := 0 to Count - 1 do
            if awn = Items[ii].Handle then
              begin
                lpApp := items[ii];
                lpApp.Title := Title;
///                lpApp.sTime := sHour;
                Inc(lpApp.Used);
                updateSG (lpApp, ii + 1);
                slLog.Append(sHour + Title);
                SBsubject := lpApp.Name + ' focused.';
                // update text and log not checkbox
                // ChBxs.Items.Append(sHour + Title);
                focusedApp := lpApp;
                focusedApp.MarkTick := GetTickCount64;
                exit
              end;

          AddNewExe(awn, classname, Title, sHour);
        end;
    Except
      On E: Exception Do
      begin
        SBSubject := (E.ClassName + ': ' + E.Message); // begin
      end;
    End;
end;

destructor TptrApps.Destroy;
begin
  AppTimer.Enabled := False;
  Apptimer.Free;
  for var App: ptrApp in list do
    if Assigned(App)  then
       begin
          if App.Icon <> nil then
            App.Icon.Free;
         dispose(App);
       end;
  Handles.Free;
  inherited;
end;

procedure TptrApps.ChangeState(Sender: TObject);
begin
  if Sender = self then
    AppTimer.Enabled := false
  else
  begin
    var
      Tag := TControl(Sender).Tag;
    Case Tag of
      1:
        AppTimer.Enabled := True;
      2:
        AppTimer.Enabled := false;
      3:
        begin
          bAllwindows := not bAllWindows;
          ChBxs.Visible := bAllWindows;
          if ChBxs.Showing then ChBxs.BringToFront;

        end;
      4:
        GetSomeWindows(Sender);
      // 3:
      // begin
      // AppTimer.Enabled := false;
      // Pulse(nil);
      // end;
    end;
  end;
end;

procedure TptrApps.CheckforActiveAppTitleChange;
var
  Title: Array [0 .. 255] Of char;
  S, sTitle: string;
  AppTotalHrTicks: Integer;

begin
  // Update running all App hours ran
  with focusedApp^ do begin
     AppTotalHrTicks := AcculmTick + GetTickCount64 - MarkTick;
     sgGrid.Cells[4, sgRow] := Format('%1.5f', [AppTotalHrTicks / 3600_000]);
     if title = '' then begin
      sgGrid.Cells[1, sgRow] := 'Not showing xxx';
      if IsWindowVisible(Handle) then sgGrid.Cells[1, sgRow] := 'Showing xxx';
      exit
     end;
  end;
  begin
    GetWindowText(focusedApp.Handle, Title, 255);
    sTitle := Trim(Title);
    if focusedApp.Title <> sTitle then
      begin
        focusedApp.Title := sTitle;
        S := Format('hr %2.5f %s', [24 * Time, sTitle]);
        slLog.Add(S);
        SB.Caption := S; //SBSubject
      end;
  end
end;

{ TODO -oPat :    Add logic to check
   if the running programs are on the list when self is started or
   when a everthing is selected the self doesn't needed so
   uncheck or leave off list. 3/4 done

   save hourage icon and paths of desiredApps in DB
   }
var lastWindowName:string = '';
function EnumWindowsCallBack64(Handle: hWnd; Hs:TappHandles): BOOL; stdcall;
const
  C_FileNameLength = 256;
var
  WinFileName: string;
  PID, hProcess: DWORD;
  Len: Byte;
  style: DWORD;
  testS: string;
begin
  SetLength(WinFileName, C_FileNameLength);
  GetWindowThreadProcessId(Handle, PID);
  hProcess := OpenProcess(PROCESS_ALL_ACCESS, false, PID);
  style := GetWindowLongPtr(Handle, GWL_STYLE);
  if (style and WS_VISIBLE <> 0) then
  begin
    Len := GetModuleFileNameEx(hProcess, 0, PChar(WinFileName),
      C_FileNameLength);
    if Len > 0 then
    begin
      setlength(WinFileName, Len);
      testS := copy(WinfileName, len - 10, 10);
      if testS = lastWindowName then exit;
      lastWindowName := testS;
      Hs.add(handle);
    end;
  end;
  Result := True;
end;

function EnumWindowsProc32(wHandle: HWND;var Hs:TappHandles): BOOL; stdcall;
begin
  if IsWindowVisible(wHandle) then
    Hs.Add(wHandle);
  Result := True;
end;

procedure TptrApps.GetSomeWindows(Sender: TObject);//(WantedApps: TArray<string>);
var
  i,j: NativeUInt;
begin
  {$IFDEF CPU32BITS}
      EnumWindows(@EnumWindowsProc32, LParam(@Handles));
  {$ELSE}
      EnumWindows(@EnumWindowsCallback64, LParam(Handles));
  {$ENDIF}

  with Handles do
  begin
    for  i := 0 to Count - 1 do
      for  j := Count - 1 downto i + 1 do
        if Items[j] = Items[i] then
            Remove(Items[j]);
  end;
  sgGrid.BeginUpdate;
  for var X := 0 to Handles.Count - 1 do
  CheckForeGroundWindows(Handles[X]);
  sgGrid.EndUpdate;
  // why not work DesiredExes := DesiredExes - [selfClass];
//  setLength(DesiredExes,Length(DesiredExes) - 1);
end;

function TptrApps.getVersionasString(inAppName: string): string;
var
  Major, Minor, Build: Cardinal;
begin
  Try
    Major := 0;
    Minor := 0;
    Build := 0;
    Result := 'NA';
    if inAppName = '' then
      exit;

    GetProductVersion(inAppName, Major, Minor, Build);
    SBSubject := inAppName;
    Result := Format('%d.%d.%d', [Major, Minor, Build]);
  Except
    on E: Exception do
      Result := E.ClassName + ':' + E.Message
      // else
      // Result := 'AbbyNormal Error';   //seen DP for use on other exceptions
  End;
end;

class function TptrApps.HookInUI(inSG: TStringGrid; inLog: TStrings; inChBxs: TcheckListBox;
     inBanner: TPanel): TptrApps;
begin
  cacheApp.sgRow := 1;
  cacheApp.AcculmTick := GetTickCount64;
  focusedApp := @cacheApp;

  var R := TptrApps.Create;
  R.ChBxs := inChBxs;
  R.ChBxs.OnClick := R.changeExesList;
  R.ChBxs.Items.Clear;
  R.bEveryThing := False;
  R.Handles := TappHandles.Create;
  for var I := Low(goodApps) to High(goodApps) do
    begin
      R.ChBxs.Items.add(goodApps[I]);
      R.ChBxs.Checked[I] := True;
       { TODO -oPat :    +1 was needed to hard switch the Everything switch may
        add a freeze or snapshoot or pause to get more windows }
    end;
  R.changeExesList(R.ChBxs); //pre-use or prime the Exelist with update procedure
  R.SB := inBanner;
  R.SBSubject := 'Inited';
  R.slLog := inLog;
  R.sgGrid := inSG;
  R.sgGrid.OnClick := R.StringGridDblClick;
  R.sgGrid.OnEnter := R.StringGridDblClick;
  R.sgGrid.OnDrawCell := R.SGdrawCell;
  R.sgGrid.Rows[0].CommaText := 'Name, Title, Class, Used, Hours, Version';
  R.sgGrid.ColWidths[0] := 180;
  R.sgGrid.ColWidths[1] := 236;
  R.sgGrid.ColWidths[2] := 160;
  R.sgGrid.ColWidths[3] :=  60;
  R.sgGrid.ColWidths[4] :=  90;

  R.bAllWindows := False;
  R.phState:= 'Starting';
  R.AppTimer := TTimer.Create(nil);
  R.appTimer.OnTimer := R.Pulse;
  R.appTimer.Enabled := True;
  Result := R;
//Need to add restarter
 { TODO : Add self healing code }
end;



var Busycount: Integer = 0;
var Counter: Integer = 0;
procedure TptrApps.Pulse(Sender: TObject);
begin
  if Busycount > 0 then
  begin
    Inc(BusyCount);

    slLog.add(' busy count ' + busyCount.ToString);

    if Busycount < 5
      then exit;
  end;
  BusyCount := 1;
  AppTimer.Enabled := False;
  CheckForeGroundWindows(0);
  var sHour := Format ('hr %2.4f', [24 * Time]);
  Inc(Counter);
  if Counter > 5 then
  begin
    Counter := 0;
    RemoveStaleItems;
    CheckforActiveAppTitleChange;
  end;
  //old Combobox was using text and insert[0]here.
  //slLog.Strings[sllog.Count -1] := sHour + ' - ' + SB.Caption;//     ptrS^;
  SB.Caption := sHour + ' ' + SBSubject;// + ' ' + copy(SB.Caption,8,length(SB.Caption));
  AppTimer.Enabled := True;
  BusyCount := 0;
end;

Type
  TKrackSG = class (TcustomGrid)
end;

procedure TptrApps.RemoveStaleItems;
var
  isStaleQ: ptrApp;
  sRemoved: string;
begin
  isStaleQ := nil;
  try
    for var i := Count - 1 downto 0 do
    begin
      isStaleQ := List[i];
      if not IsWindow(isStaleQ.Handle) then
        begin
          TKrackSG(sgGrid).DeleteRow(i + 1);     //Remy
          sRemoved := sRemoved + isStaleQ.Name + ' ';
          isStaleQ.Icon.Free;
          Remove(isStaleQ);
          Dispose(isStaleQ);
        end;
    end;
    if SRemoved <> '' then
      begin
        sRemoved := Format(hour2dot3,[Time*24]) + sRemoved + ' closed';
        SBSubject := sRemoved;
        slLog.Add(sRemoved);
      end;

  except
    On E: Exception do if assigned(isStaleQ) then
        slLog.Append(isStaleQ.Name + ' ' + E.ClassName + ': ' + E.Message); // begin
//    else
//        slLog.Append('Frittle Fraddle');
  end;
end;

procedure TptrApps.SGdrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect;
  State: TGridDrawState);
begin
  if (ACol = 0) and (ARow > 0) then
  begin
    var SG1 := Sender as TStringGrid;
//    SG1.Canvas.Brush.Color := clWindowFrame;
    //SG1.Canvas.font.Color := clLime;

//    if focusedApp.sgRow = ARow
//      then SG1.Canvas.Brush.Color := clWindowText;
    SG1.Canvas.FillRect(Rect);
    if Count >= ARow then
      begin
        SG1.Canvas.TextRect(Rect,Items[Arow-1].Name,[tfCenter, tfRight]);
        SG1.Canvas.Draw(Rect.Left+3,Rect.Top+3, Items[Arow-1].Icon);
      end;
  end;
end;

procedure TptrApps.StringGridDblClick(Sender: Tobject);
begin
  var Idx :=  sgGrid.Selection.Top - 1;
  if Idx < Count then
  AppActivate (List[Idx].Handle);
end;

procedure TptrApps.updateSG(inTool: ptrApp; inRow: Integer);
begin
  if sgGrid.RowCount < inRow then
  sgGrid.RowCount := inRow + 1;
  var
    i := InRow;
  sgGrid.Cells[0, i] := inTool.Name;
  sgGrid.Cells[1, i] := inTool.Title;
  sgGrid.Cells[2, i] := inTool.ClassName;
  sgGrid.Cells[3, i] := inTool.Used.ToString;
  sgGrid.Cells[5, i] := inTool.sVersion;
end;

// additional UI for smaller jobs 16 put overlay on check group

//  R.popup := inPopup;
//  inPopUpParent.popupMenu := R.Popup;

//        for var m := popup.items.Count - 1 downto 0 do
//        begin
//          MItem := popup.items[m];
//          if MItem.Tag = isStaleQ.Handle then
//          begin
//            //if assigned(mItem.Bitmap) then MItem.Bitmap.Free;
//            MItem.Free;
//            // Freeandnil(mitem);
//            break;
//          end;
//        end;


//var AppBuilderCount: Integer = 0;
(***
procedure TptrApps.AddToolUpdateUI(inApp: ptrApp; aMenuItemClick: TnotifyEvent);
var
 // i: Integer;
  Icon: TIcon;
begin
  //if inApp.ClassName = 'TAppBuilder' then
  begin
    Inc(AppBuilderCount);
    inApp.MenuItem := TMenuItem.Create(popup);
//    inApp.menu.Caption := AppBuilderCount.ToString + '_Delphi' + ' ' +
//      inApp.sVersion;
    inApp.MenuItem.Caption := inApp.Name + ' ' + inApp.sVersion;
    inApp.MenuItem.Tag := inApp.Handle;
    inApp.MenuItem.OnClick := aMenuItemClick;
    popup.items.Add(inApp.MenuItem);
//    icon := GetSmallIconFromExecutableFile(inApp.Name);
//    inApp.MenuItem.Bitmap.Assign(icon);
//    IconList.Add(inApp.MenuItem.Bitmap,nil);
//    inApp.MenuItem.Bitmap.SaveToFile(ExtractFileName(inApp.Name)+'.Bmp');
  end;
end;
***)
(***
procedure TptrApps.appsMenuclick(Sender: TObject);
var
  Hndl: HWnd;
begin
  Hndl := (Sender as TMenuItem).Tag;
  AppActivate(Hndl);
end;
***)

end.
