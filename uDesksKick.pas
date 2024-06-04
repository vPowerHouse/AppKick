unit uDesksKick;

interface

uses
  Classes,
  Windows,
  Forms,
  Controls,
  Vcl.StdCtrls,
  vcl.extCtrls,
  Vcl.Buttons,
  Vcl.ComCtrls,
  Vcl.CheckLst,
  Vcl.Grids;

Type
  // TSideKickMain = class (TForm);     TDesktopGotoMain need a good name for
  TDesksKick = class(TForm) // set 2023Oct16
    procedure AppLaunch(Sender: TObject);
    procedure StartClick(Sender: TObject);
//    procedure StepClick(Sender: TObject);
//    procedure StopClick(Sender: TObject);
    procedure SetState(Sender: TObject);
  protected
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormResize(Sender: TObject);
  public
    Banner: TPanel;
    btnSet: TButton;
    cbLog: TMemo;
    chkLB: TCheckListBox;
    Everything: TCheckBox;
    SG: TStringGrid;
    BDE: TButton;
    Start: TButton;
    Step: TButton;
    Stop: TButton;
    destructor Destroy; override;
    procedure LoadNew(AnOwner: TApplication);
  end;

implementation


uses
//  aeThreadedTimer, //   uses one of your samples with run,step/freeze,stop verbs added
  AppList,
  StrUtils, System.SysUtils;

var
 // ptrKickString, ptrS: PunicodeString;
  AppWindows: TptrApps;
//  appTmr: TThreadedTimer; //TTimer;//TThreadedTimer; //TTimer;
 // Counter: Integer = 0;

procedure TDesksKick.AppLaunch(Sender: TObject);
begin
  // if BDE then
  var sbde := 'C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\bds.exe';
  var pms :=  '-pDelphi';
  TptrApps.OpenLocalFile(sbde, pms);
end;

destructor TDesksKick.Destroy;
begin
  //Setlength(Appwindows.desiredExes,0);
//  if assigned(AppWindows) then
//  begin
   // for var I := 0 to Appwindows.Count - 1 do
   //   dispose(AppWindows.Items[I]);
    AppWindows.Free;
//  end;
  inherited;
end;

procedure TDesksKick.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
try
  AppWindows.ChangeState(nil);
//  apptmr.Enabled := False;  //this disabled the frame
  AppWindows.slLog.SaveToFile('C:\_tickers\machinelog'   //todo use truncate(1/1/present year) some how
       + Format ('023.Dy%d.hr%2.3f%s', [Trunc(Date - 44926 + 365), 24 * Time, '.log']));
except
  Raise
end;
  CanClose := True;


end;

procedure TDesksKick.FormResize(Sender: TObject);
begin
  if Assigned(AppWindows) then

  AppWindows.sgGrid.Colwidths[1] := width div 2;
end;

procedure TDesksKick.SetState(Sender: TObject);
begin
  if not assigned(AppWindows) then
  begin
    AppWindows := TptrApps.HookInUI(SG, cblog.Lines, chkLB, Banner);
  end;

  AppWindows.ChangeState(Sender);
end;

procedure TDesksKick.LoadNew(AnOwner: TApplication);
const
  skTopOfs = 12;
begin
//  Self := TDesksKick.Create(AnOwner);
  BDE := TButton.Create(Self);
  Start := TButton.Create(Self);
  Stop := TButton.Create(Self);
  Step := TButton.Create(Self);
  chkLB := TCheckListBox.Create(Self);
  cbLog := TMemo.Create(Self);
  SG := TStringGrid.Create(Self);
  Banner:= TPanel.Create(Self);

  Name := 'FrmBoss';
  //Parent := AOwner as Tcomponent;
  Left := 0;
  Top := 0;
  Width := 950;//2720;
  Height := 550;//2 * 1662 div 3;
  Color := 5079325;
  ParentBackground := False;
  ParentColor := False;
  //ParentFont := True;
  font := application.defaultfont;
  TabOrder := 0;
  OnResize := FormResize;

  BDE.Parent := Self;
  BDE.Left := 27;
  BDE.Top := skTopOfs + 25 * 3;
  BDE.Width := 75;
  BDE.Height := 25;
  BDE.Caption := 'Load';
  BDE.TabOrder := 0;
  BDE.Tag := 4;
  BDE.OnClick :=  SetState;//Self.GetAnyRunningDesiredApps;//AppLaunch;

  Start.Parent := Self;
  Start.Left := 27;
  Start.Top := skTopOfs;
  Start.Width := 75;
  Start.Height := 25;
  Start.Caption := 'Start';
  Start.TabOrder := 0;
  Start.Tag := 1;
  Start.OnClick := SetState;

  Stop.Name := 'Stop';
  Stop.Parent := Self;
  Stop.Left := 27;
  Stop.Top := skTopOfs + 25 * 1;
  Stop.Width := 75;
  Stop.Height := 25;
  Stop.Caption := 'Stop';
  Stop.TabOrder := 1;
  Stop.Tag := 2;
  Stop.OnClick := SetState;
  Stop.Show;

  Step.Name := 'Step';
  Step.Parent := Self;
  Step.Left := 27;
  Step.Top := skTopOfs + 25 * 2;
  Step.Width := 75;
  Step.Height := 25;
  Step.Caption := 'tog';
  Step.Tag := 3;
  Step.TabOrder := 3;
  Step.OnClick := SetState;

  chkLB.Name := 'chkLB';
  chkLB.Parent := Self;
  chkLB.Left := 12;
  chkLB.Top := skTopOfs + 230;
  chkLB.Width := 150;
  chkLB.Height := 220;
  chkLB.Anchors := [akLeft, akTop];
  chkLB.Columns := 0;
  chkLB.ItemHeight := 85;//32;
  chkLB.Items.Clear;
  chkLB.TabOrder := 3;
  chkLB.Hide;

  cbLog.Name := 'cbLog';
  cbLog.Parent := Self;
  cbLog.Left := 16;
  cbLog.Top := skTopOfs * 2 + 300;
  cbLog.Width := 850;//2400;//2666;
  cbLog.WordWrap := False;
  cbLog.Height := 108;
  cbLog.Anchors := [akLeft, akTop, akRight, akBottom];
  cbLog.TabOrder := 4;

  SG.Name := 'SG';
  SG.Parent := Self;
  SG.Left := 120;
  SG.Top := skTopOfs;
  SG.Width := 759;//2666;
  SG.Height := 300;
  SG.Anchors := [akLeft, akTop, akRight];//, akBottom];
  SG.ColCount := 6;
  SG.DefaultColWidth := 72;
  SG.FixedCols := 0;
  SG.TabOrder := 5;


  Banner.Parent := Self;
  Banner.Align := alBottom;
  Banner.Height := 27;
  Banner.BorderWidth := 0;
  Banner.Color := $F0FBFF;//2123112;
  //Banner.ParentColor := False;
  Banner.ParentBackground := False;
  Banner.Caption := 'Banner';

  Showmodal;
    if not assigned(AppWindows) then
  begin
    AppWindows := TptrApps.HookInUI(SG, cblog.Lines, chkLB, Banner);
  end;

end;

procedure TDesksKick.StartClick(Sender: TObject);
begin
  if not assigned(AppWindows) then
  begin
    AppWindows := TptrApps.HookInUI(SG, cblog.Lines, chkLB, Banner);
  end;

//  if assigned(appTmr) then
////    appTmr.Destroy;
//  TTimer
//  AppTmr := TThreadedTimer.Create(self);//TTimer.Create(self); //TThreadedTimer.Create(self);
//  appTmr.OnTimer := AppWindows.Pulse;
//  //appTmr.start;
//  appTmr.Enabled := True;
end;

//procedure TDesksKick.StepClick(Sender: TObject);
//begin
//  //thrTmr.Step;
//  (Sender as TControl).Tag := 1;
//  AppWindows.ChangeState(Sender);
//  //apptmr.Enabled := False;  //this disabled the frame
//  AppWindows.Pulse(Sender);
//end;
//
//procedure TDesksKick.StopClick(Sender: TObject);
//begin
//  appTmr.Enabled := False;
//end;


//
//initialization
//  New(ptrS);
//  New(ptrKickString);
//  ptrS^ := 'New';
////  New(ptrEveryThing);
//Finalization
//  Dispose(ptrS);
//  Dispose(ptrKickString);

end.
//procedure TDesksKick.btnSetClick(Sender: TObject);
//var
//  lC: TControl;
//begin
// source based on frame used by dropping into designwindow from the palette but needs more sub
//subforms { TODO -oPat :  }

//  for var C := 0 to ComponentCount - 1 do
//    begin
//      lC := Components[C] as TControl;    // Parent is windows draw inside owner
//      lC.Parent := Parent;
//   // TControl(Components[C]).Parent := Parent;
//  //Free;  must need to set controls owner as well
//  //hide;
//    end;
//   hide;

//end;

//constructor TDesksKick.Create(AOwner: TComponent);
//begin
//  inherited;
//end;

