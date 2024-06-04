
// Scope of TailWind
//  Move to different Taskbars to reveal programs using that taskbar

program TailWind;

{$weaklinkrtti on}
{$rtti explicit methods([]) properties([]) fields([])}

uses
  Vcl.Forms,
  Winapi.Windows,
  uDesksKick in 'uDesksKick.pas',
  Vcl.Themes,
  Vcl.Styles;

{$R *.res}

//const RunTimeFormName = 'DesksKick';
var
  Hnd: THandle = 0;
  DesksKick: TDesksKick;
begin
  //Hnd :=  findWindow('T'+ RunTimeformName, RunTimeformName);
  Hnd := FindWindow('TDesksKick', 'FrmBoss');//'Tailwind');
  if Hnd <> 0 then
  begin
    if IsIconic(Hnd) then
      ShowWindow(Hnd, SW_RESTORE);
    SetForegroundWindow(Hnd);
    exit;
  end;
  Application.Initialize;
//  Application.Title := 'PatsDesktopSmasher';
  ReportMemoryLeaksOnShutdown := True;
  TStyleManager.TrySetStyle('Windows10 Dark');
  Application.DefaultFont.Size := 13;
  Application.DefaultFont.Name := 'Palatino Linotype'; //'Segoe UI';//


//  Application.MainFormOnTaskbar := True;
  DesksKick := TDesksKick.CreateNew(Application);
  DesksKick.LoadNew(Application);
  Application.MainFormOnTaskbar := True;
//  DesksKick.Show;
end.
