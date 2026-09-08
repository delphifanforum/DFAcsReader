program DFACSReaderDemo;

uses
  Vcl.Forms,
  uMain in 'uMain.pas' {frmMain},
  DFWinSCard in '..\Source\DFWinSCard.pas',
  DFACSReader in '..\Source\DFACSReader.pas';

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'DF ACS Reader Demo';
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
