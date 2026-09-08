object frmMain: TfrmMain
  Left = 0
  Top = 0
  Caption = 'DF ACS Reader Demo'
  ClientHeight = 430
  ClientWidth = 460
  Color = clBtnFace
  Font.Charset = TURKISH_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 460
    Height = 145
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblMode: TLabel
      Left = 16
      Top = 52
      Width = 70
      Height = 15
      Caption = 'Okuma modu'
    end
    object cbxReaderList: TComboBox
      Left = 16
      Top = 16
      Width = 300
      Height = 23
      Style = csDropDownList
      TabOrder = 0
      OnChange = cbxReaderListChange
    end
    object btnRefresh: TButton
      Left = 328
      Top = 15
      Width = 116
      Height = 25
      Caption = 'Yenile'
      TabOrder = 1
      OnClick = btnRefreshClick
    end
    object cbxMode: TComboBox
      Left = 16
      Top = 71
      Width = 300
      Height = 23
      Style = csDropDownList
      TabOrder = 2
      OnChange = cbxModeChange
      Items.Strings = (
        '1 - UID 4 byte HEX'
        '2 - UID 4 byte HEX ters'
        '3 - UID 7 byte HEX'
        '4 - UID 7 byte HEX ters'
        '5 - UID 4 byte DEC ters'
        '6 - UID 4 byte DEC')
    end
    object btnStart: TButton
      Left = 16
      Top = 108
      Width = 140
      Height = 25
      Caption = 'Baslat'
      TabOrder = 3
      OnClick = btnStartClick
    end
    object btnStop: TButton
      Left = 162
      Top = 108
      Width = 140
      Height = 25
      Caption = 'Durdur'
      Enabled = False
      TabOrder = 4
      OnClick = btnStopClick
    end
    object btnReadOnce: TButton
      Left = 328
      Top = 70
      Width = 116
      Height = 25
      Caption = 'Bir kez oku'
      TabOrder = 5
      OnClick = btnReadOnceClick
    end
  end
  object memLog: TMemo
    Left = 0
    Top = 145
    Width = 460
    Height = 285
    Align = alClient
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 1
  end
  object ACSReader: TDFACSReader
    DuplicateBlockMs = 400
    OnUIDRead = ACSReaderUIDRead
    OnError = ACSReaderError
    OnCardInserted = ACSReaderCardInserted
    OnCardRemoved = ACSReaderCardRemoved
    OnStarted = ACSReaderStarted
    OnStopped = ACSReaderStopped
    Left = 392
    Top = 168
  end
end
