unit uMain;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  DFACSReader,
  DFWinSCard;

type
  TfrmMain = class(TForm)
    ACSReader: TDFACSReader;
    pnlTop: TPanel;
    cbxReaderList: TComboBox;
    btnRefresh: TButton;
    btnStart: TButton;
    btnStop: TButton;
    lblMode: TLabel;
    cbxMode: TComboBox;
    btnReadOnce: TButton;
    memLog: TMemo;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnRefreshClick(Sender: TObject);
    procedure btnStartClick(Sender: TObject);
    procedure btnStopClick(Sender: TObject);
    procedure btnReadOnceClick(Sender: TObject);
    procedure cbxReaderListChange(Sender: TObject);
    procedure cbxModeChange(Sender: TObject);
    procedure ACSReaderUIDRead(Sender: TObject; const UID: string);
    procedure ACSReaderError(Sender: TObject; const Message: string; Code: LONG);
    procedure ACSReaderCardInserted(Sender: TObject; const ReaderName: string);
    procedure ACSReaderCardRemoved(Sender: TObject; const ReaderName: string);
    procedure ACSReaderStarted(Sender: TObject);
    procedure ACSReaderStopped(Sender: TObject);
  private
    procedure Log(const Level, Msg: string);
    procedure RefreshReaders;
    procedure ApplyModeFromCombo;
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

procedure TfrmMain.Log(const Level, Msg: string);
begin
  memLog.Lines.Add(Format('[%s] %s %s', [FormatDateTime('dd.MM.yyyy HH:nn:ss', Now), Level, Msg]));
  memLog.SelStart := Length(memLog.Text);
  SendMessage(memLog.Handle, EM_SCROLLCARET, 0, 0);
end;

procedure TfrmMain.ApplyModeFromCombo;
begin
  ACSReader.ReadingMode := TDFACSReadingMode(cbxMode.ItemIndex);
end;

procedure TfrmMain.RefreshReaders;
begin
  try
    ACSReader.LoadReaders(cbxReaderList.Items, True);
    if cbxReaderList.Items.Count > 0 then
    begin
      cbxReaderList.ItemIndex := cbxReaderList.Items.IndexOf(ACSReader.ReaderName);
      if cbxReaderList.ItemIndex < 0 then
        cbxReaderList.ItemIndex := 0;
      ACSReader.ReaderName := cbxReaderList.Text;
      Log('INFO', 'Okuyucu bulundu: ' + ACSReader.ReaderName);
    end
    else
      Log('WARN', 'Okuyucu bulunamadi. ACS okuyucuyu takin, Smart Card servisinin acik oldugundan emin olun.');
  except
    on E: Exception do
      Log('ERROR', E.Message);
  end;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  cbxMode.ItemIndex := 0;
  ApplyModeFromCombo;
  RefreshReaders;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  ACSReader.Active := False;
end;

procedure TfrmMain.btnRefreshClick(Sender: TObject);
begin
  RefreshReaders;
end;

procedure TfrmMain.btnStartClick(Sender: TObject);
begin
  if Trim(cbxReaderList.Text) = '' then
  begin
    Log('ERROR', 'Okuyucu secilmedi.');
    Exit;
  end;
  ACSReader.ReaderName := cbxReaderList.Text;
  ApplyModeFromCombo;
  ACSReader.Active := True;
end;

procedure TfrmMain.btnStopClick(Sender: TObject);
begin
  ACSReader.Active := False;
end;

procedure TfrmMain.btnReadOnceClick(Sender: TObject);
var
  UID: string;
begin
  if Trim(cbxReaderList.Text) = '' then
  begin
    Log('ERROR', 'Okuyucu secilmedi.');
    Exit;
  end;
  ACSReader.ReaderName := cbxReaderList.Text;
  ApplyModeFromCombo;
  try
    UID := ACSReader.ReadUID;
    Log('INFO', 'Anlik UID: ' + UID);
  except
    on E: Exception do
      Log('ERROR', E.Message);
  end;
end;

procedure TfrmMain.cbxReaderListChange(Sender: TObject);
begin
  ACSReader.ReaderName := cbxReaderList.Text;
end;

procedure TfrmMain.cbxModeChange(Sender: TObject);
begin
  ApplyModeFromCombo;
end;

procedure TfrmMain.ACSReaderUIDRead(Sender: TObject; const UID: string);
begin
  Log('INFO', 'UID: ' + UID);
end;

procedure TfrmMain.ACSReaderError(Sender: TObject; const Message: string; Code: LONG);
begin
  Log('ERROR', Message + ' (0x' + IntToHex(DWORD(Code), 8) + ')');
end;

procedure TfrmMain.ACSReaderCardInserted(Sender: TObject; const ReaderName: string);
begin
  Log('INFO', 'Kart takildi: ' + ReaderName);
end;

procedure TfrmMain.ACSReaderCardRemoved(Sender: TObject; const ReaderName: string);
begin
  Log('INFO', 'Kart cikarildi: ' + ReaderName);
end;

procedure TfrmMain.ACSReaderStarted(Sender: TObject);
begin
  btnStart.Enabled := False;
  btnStop.Enabled := True;
  Log('INFO', 'Izleme basladi.');
end;

procedure TfrmMain.ACSReaderStopped(Sender: TObject);
begin
  btnStart.Enabled := True;
  btnStop.Enabled := False;
  Log('INFO', 'Izleme durdu.');
end;

end.
