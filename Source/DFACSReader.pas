{*******************************************************************************
  TDFACSReader
  VCL component: ACS / ACR (PC/SC) kart UID okuma.

  VB.NET UIDtoKeyboard ile ayni APDU: FF CA 00 00 Le
  Windows winscard.dll uzerinden calisir. PCSC.dll / PCSC.Iso7816.dll gerekmez.

  Website: delphifan.com
  Email:   adsdelphi@gmail.com
*******************************************************************************}
unit DFACSReader;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  Winapi.Windows,
  DFWinSCard;

type
  TDFACSReadingMode = (
    rmUID4Hex,
    rmUID4HexReversed,
    rmUID7Hex,
    rmUID7HexReversed,
    rmUID4DecReversed,
    rmUID4Dec
  );

  TDFACSUidEvent = procedure(Sender: TObject; const UID: string) of object;
  TDFACSErrorEvent = procedure(Sender: TObject; const Message: string; Code: LONG) of object;
  TDFACSReaderEvent = procedure(Sender: TObject; const ReaderName: string) of object;

  TDFACSReader = class;

  TDFACSMonitorThread = class(TThread)
  private
    FOwner: TDFACSReader;
    FReaderName: string;
    FContext: TSCARDCONTEXT;
    FHasContext: Boolean;
  protected
    procedure Execute; override;
    procedure DoCardInserted;
  public
    constructor Create(AOwner: TDFACSReader; const AReaderName: string);
    destructor Destroy; override;
    procedure RequestStop;
  end;

  [ComponentPlatformsAttribute(pidWin32 or pidWin64)]
  TDFACSReader = class(TComponent)
  private
    FActive: Boolean;
    FReaderName: string;
    FReadingMode: TDFACSReadingMode;
    FDuplicateBlockMs: Integer;
    FMonitorTimeoutMs: DWORD;
    FMonitorThread: TDFACSMonitorThread;
    FOnUIDRead: TDFACSUidEvent;
    FOnError: TDFACSErrorEvent;
    FOnCardInserted: TDFACSReaderEvent;
    FOnCardRemoved: TDFACSReaderEvent;
    FOnStarted: TNotifyEvent;
    FOnStopped: TNotifyEvent;
    FLastUid: string;
    FLastUidTick: UInt64;
    FUidLock: TCriticalSection;
    procedure SetActive(const Value: Boolean);
    procedure SetReaderName(const Value: string);
    procedure SetReadingMode(const Value: TDFACSReadingMode);
    procedure SetDuplicateBlockMs(const Value: Integer);
    procedure InternalStop(Wait: Boolean);
    procedure HandleCardInserted;
    procedure ReportError(const Msg: string; Code: LONG);
    function ShouldSkipDuplicate(const UID: string): Boolean;
    function DoReadUID(const AReaderName: string; AMode: TDFACSReadingMode): string;
    class function FormatUid(const Data: TBytes; AMode: TDFACSReadingMode): string; static;
    class function BytesToHex(const Data: TBytes; Reversed: Boolean): string; static;
    class function BytesToDec(const Data: TBytes; Reversed: Boolean): string; static;
    class function ReverseBytes(const Data: TBytes): TBytes; static;
  protected
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function GetReaders: TArray<string>;
    procedure LoadReaders(Dest: TStrings; SelectFirst: Boolean = True);
    function ReadUID: string; overload;
    function ReadUID(const AReaderName: string; AMode: TDFACSReadingMode): string; overload;
    procedure Start;
    procedure Stop;
  published
    property Active: Boolean read FActive write SetActive default False;
    property ReaderName: string read FReaderName write SetReaderName;
    property ReadingMode: TDFACSReadingMode read FReadingMode write SetReadingMode default rmUID4Hex;
    property DuplicateBlockMs: Integer read FDuplicateBlockMs write SetDuplicateBlockMs default 400;
    property OnUIDRead: TDFACSUidEvent read FOnUIDRead write FOnUIDRead;
    property OnError: TDFACSErrorEvent read FOnError write FOnError;
    property OnCardInserted: TDFACSReaderEvent read FOnCardInserted write FOnCardInserted;
    property OnCardRemoved: TDFACSReaderEvent read FOnCardRemoved write FOnCardRemoved;
    property OnStarted: TNotifyEvent read FOnStarted write FOnStarted;
    property OnStopped: TNotifyEvent read FOnStopped write FOnStopped;
  end;

implementation

const
  UID_RECV_LEN = 256;

function MultiSzToArray(P: PWideChar): TArray<string>;
var
  List: TList<string>;
  S: string;
begin
  List := TList<string>.Create;
  try
    if P <> nil then
    begin
      while P^ <> #0 do
      begin
        S := P;
        List.Add(S);
        Inc(P, Length(S) + 1);
      end;
    end;
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

{ TDFACSMonitorThread }

constructor TDFACSMonitorThread.Create(AOwner: TDFACSReader; const AReaderName: string);
begin
  inherited Create(False);
  FreeOnTerminate := False;
  FOwner := AOwner;
  FReaderName := AReaderName;
  FHasContext := False;
end;

destructor TDFACSMonitorThread.Destroy;
begin
  if FHasContext then
  begin
    SCardReleaseContext(FContext);
    FHasContext := False;
  end;
  inherited;
end;

procedure TDFACSMonitorThread.RequestStop;
begin
  Terminate;
  if FHasContext then
    SCardCancel(FContext);
end;

procedure TDFACSMonitorThread.DoCardInserted;
begin
  if Assigned(FOwner) then
    FOwner.HandleCardInserted;
end;

procedure TDFACSMonitorThread.Execute;
var
  State: TSCARD_READERSTATEW;
  Rv, ErrCode: LONG;
  LastState, EventState: DWORD;
  WasPresent, IsPresent: Boolean;
  NameBuf: UnicodeString;
begin
  NameBuf := FReaderName;
  Rv := SCardEstablishContext(SCARD_SCOPE_SYSTEM, nil, nil, FContext);
  if Rv <> SCARD_S_SUCCESS then
  begin
    ErrCode := Rv;
    TThread.Queue(nil,
      procedure
      begin
        if Assigned(FOwner) then
          FOwner.ReportError('SCardEstablishContext: ' + DFWinSCardErrorText(ErrCode), ErrCode);
      end);
    Exit;
  end;
  FHasContext := True;

  FillChar(State, SizeOf(State), 0);
  State.szReader := PWideChar(NameBuf);
  State.dwCurrentState := SCARD_STATE_UNAWARE;
  LastState := SCARD_STATE_UNAWARE;
  WasPresent := False;

  while not Terminated do
  begin
    FillChar(State, SizeOf(State), 0);
    State.szReader := PWideChar(NameBuf);
    State.dwCurrentState := LastState;

    Rv := SCardGetStatusChangeW(FContext, FOwner.FMonitorTimeoutMs, @State, 1);
    if Terminated then
      Break;

    if Rv = SCARD_E_TIMEOUT then
      Continue;
    if Rv = SCARD_E_CANCELLED then
      Break;
    if Rv <> SCARD_S_SUCCESS then
    begin
      ErrCode := Rv;
      TThread.Queue(nil,
        procedure
        begin
          if Assigned(FOwner) then
            FOwner.ReportError('SCardGetStatusChange: ' + DFWinSCardErrorText(ErrCode), ErrCode);
        end);
      Break;
    end;

    EventState := State.dwEventState and not SCARD_STATE_CHANGED;
    IsPresent := (EventState and SCARD_STATE_PRESENT) <> 0;

    if IsPresent and not WasPresent then
      Synchronize(DoCardInserted)
    else if (not IsPresent) and WasPresent then
    begin
      TThread.Queue(nil,
        procedure
        begin
          if Assigned(FOwner) and Assigned(FOwner.FOnCardRemoved) then
            FOwner.FOnCardRemoved(FOwner, FOwner.FReaderName);
        end);
    end;

    WasPresent := IsPresent;
    LastState := EventState;
  end;
end;

{ TDFACSReader }

constructor TDFACSReader.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FReadingMode := rmUID4Hex;
  FDuplicateBlockMs := 400;
  FMonitorTimeoutMs := 500;
  FUidLock := TCriticalSection.Create;
end;

destructor TDFACSReader.Destroy;
begin
  InternalStop(True);
  FUidLock.Free;
  inherited;
end;

procedure TDFACSReader.Loaded;
begin
  inherited;
  if FActive and not (csDesigning in ComponentState) then
  begin
    FActive := False;
    SetActive(True);
  end;
end;

procedure TDFACSReader.SetDuplicateBlockMs(const Value: Integer);
begin
  if Value < 0 then
    FDuplicateBlockMs := 0
  else
    FDuplicateBlockMs := Value;
end;

procedure TDFACSReader.SetReaderName(const Value: string);
var
  WasActive: Boolean;
begin
  if FReaderName = Value then
    Exit;
  WasActive := FActive and not (csDesigning in ComponentState);
  if WasActive then
    InternalStop(True);
  FReaderName := Value;
  if WasActive then
    SetActive(True);
end;

procedure TDFACSReader.SetReadingMode(const Value: TDFACSReadingMode);
begin
  FReadingMode := Value;
end;

procedure TDFACSReader.SetActive(const Value: Boolean);
begin
  if FActive = Value then
    Exit;
  if csDesigning in ComponentState then
  begin
    FActive := Value;
    Exit;
  end;
  if Value then
    Start
  else
    Stop;
end;

procedure TDFACSReader.Start;
begin
  if csDesigning in ComponentState then
  begin
    FActive := True;
    Exit;
  end;
  if FActive then
    Exit;
  if Trim(FReaderName) = '' then
  begin
    ReportError('ReaderName bos. Once LoadReaders veya ReaderName atayin.', SCARD_E_NO_READERS_AVAILABLE);
    Exit;
  end;
  FMonitorThread := TDFACSMonitorThread.Create(Self, FReaderName);
  FActive := True;
  if Assigned(FOnStarted) then
    FOnStarted(Self);
end;

procedure TDFACSReader.InternalStop(Wait: Boolean);
begin
  if FMonitorThread <> nil then
  begin
    FMonitorThread.RequestStop;
    if Wait then
      FMonitorThread.WaitFor;
    FreeAndNil(FMonitorThread);
  end;
  FActive := False;
end;

procedure TDFACSReader.Stop;
begin
  if not FActive and (FMonitorThread = nil) then
    Exit;
  InternalStop(True);
  if Assigned(FOnStopped) then
    FOnStopped(Self);
end;

procedure TDFACSReader.ReportError(const Msg: string; Code: LONG);
begin
  if Assigned(FOnError) then
    FOnError(Self, Msg, Code);
end;

function TDFACSReader.ShouldSkipDuplicate(const UID: string): Boolean;
var
  NowTick: UInt64;
begin
  FUidLock.Enter;
  try
    NowTick := GetTickCount64;
    Result := (UID <> '') and SameText(UID, FLastUid) and
      (FDuplicateBlockMs > 0) and ((NowTick - FLastUidTick) < UInt64(FDuplicateBlockMs));
    if not Result then
    begin
      FLastUid := UID;
      FLastUidTick := NowTick;
    end;
  finally
    FUidLock.Leave;
  end;
end;

procedure TDFACSReader.HandleCardInserted;
var
  UID: string;
begin
  if Assigned(FOnCardInserted) then
    FOnCardInserted(Self, FReaderName);
  try
    UID := DoReadUID(FReaderName, FReadingMode);
  except
    on E: Exception do
    begin
      ReportError('UID okuma hatasi: ' + E.Message, -1);
      Exit;
    end;
  end;
  if UID = '' then
    Exit;
  if ShouldSkipDuplicate(UID) then
    Exit;
  if Assigned(FOnUIDRead) then
    FOnUIDRead(Self, UID);
end;

function TDFACSReader.GetReaders: TArray<string>;
var
  Ctx: TSCARDCONTEXT;
  Rv: LONG;
  Len: DWORD;
  Buf: UnicodeString;
begin
  SetLength(Result, 0);
  Rv := SCardEstablishContext(SCARD_SCOPE_SYSTEM, nil, nil, Ctx);
  if Rv <> SCARD_S_SUCCESS then
    raise Exception.Create('SCardEstablishContext: ' + DFWinSCardErrorText(Rv));
  try
    Len := 0;
    Rv := SCardListReadersW(Ctx, nil, nil, Len);
    if (Rv = SCARD_E_NO_READERS_AVAILABLE) or (Len = 0) then
      Exit;
    if (Rv <> SCARD_S_SUCCESS) and (Rv <> SCARD_E_INSUFFICIENT_BUFFER) then
      raise Exception.Create('SCardListReaders: ' + DFWinSCardErrorText(Rv));

    SetLength(Buf, Len);
    Rv := SCardListReadersW(Ctx, nil, PWideChar(Buf), Len);
    if Rv = SCARD_E_NO_READERS_AVAILABLE then
      Exit;
    if Rv <> SCARD_S_SUCCESS then
      raise Exception.Create('SCardListReaders: ' + DFWinSCardErrorText(Rv));
    Result := MultiSzToArray(PWideChar(Buf));
  finally
    SCardReleaseContext(Ctx);
  end;
end;

procedure TDFACSReader.LoadReaders(Dest: TStrings; SelectFirst: Boolean);
var
  Readers: TArray<string>;
  I: Integer;
begin
  if Dest = nil then
    raise Exception.Create('Dest is nil');
  Dest.BeginUpdate;
  try
    Dest.Clear;
    Readers := GetReaders;
    for I := 0 to High(Readers) do
      Dest.Add(Readers[I]);
    if SelectFirst and (Length(Readers) > 0) then
      FReaderName := Readers[0];
  finally
    Dest.EndUpdate;
  end;
end;

class function TDFACSReader.ReverseBytes(const Data: TBytes): TBytes;
var
  I, N: Integer;
begin
  N := Length(Data);
  SetLength(Result, N);
  for I := 0 to N - 1 do
    Result[I] := Data[N - 1 - I];
end;

class function TDFACSReader.BytesToHex(const Data: TBytes; Reversed: Boolean): string;
var
  Work: TBytes;
  I: Integer;
begin
  if Reversed then
    Work := ReverseBytes(Data)
  else
    Work := Data;
  Result := '';
  for I := 0 to High(Work) do
    Result := Result + IntToHex(Work[I], 2);
end;

class function TDFACSReader.BytesToDec(const Data: TBytes; Reversed: Boolean): string;
var
  Work: TBytes;
  Value: Cardinal;
begin
  if Length(Data) < 4 then
    Exit('');
  SetLength(Work, 4);
  Move(Data[0], Work[0], 4);
  if Reversed then
    Work := ReverseBytes(Work);
  Move(Work[0], Value, SizeOf(Value));
  Result := UIntToStr(Value);
end;

class function TDFACSReader.FormatUid(const Data: TBytes; AMode: TDFACSReadingMode): string;
begin
  case AMode of
    rmUID4Hex:
      Result := BytesToHex(Copy(Data, 0, 4), False);
    rmUID4HexReversed:
      Result := BytesToHex(Copy(Data, 0, 4), True);
    rmUID7Hex:
      Result := BytesToHex(Copy(Data, 0, 7), False);
    rmUID7HexReversed:
      Result := BytesToHex(Copy(Data, 0, 7), True);
    rmUID4DecReversed:
      Result := BytesToDec(Data, True);
    rmUID4Dec:
      Result := BytesToDec(Data, False);
  else
    Result := '';
  end;
end;

function TDFACSReader.DoReadUID(const AReaderName: string; AMode: TDFACSReadingMode): string;
var
  Ctx: TSCARDCONTEXT;
  Card: TSCARDHANDLE;
  Protocol: DWORD;
  Rv: LONG;
  Send: TBytes;
  Recv: array[0..UID_RECV_LEN - 1] of Byte;
  RecvLen: DWORD;
  DataLen: Integer;
  Data: TBytes;
  Le: Byte;
begin
  Result := '';
  if AMode in [rmUID7Hex, rmUID7HexReversed] then
    Le := 7
  else
    Le := 4;

  Rv := SCardEstablishContext(SCARD_SCOPE_SYSTEM, nil, nil, Ctx);
  if Rv <> SCARD_S_SUCCESS then
    raise Exception.Create(DFWinSCardErrorText(Rv));
  try
    Rv := SCardConnectW(Ctx, PWideChar(AReaderName), SCARD_SHARE_SHARED,
      SCARD_PROTOCOL_ANY, Card, Protocol);
    if Rv <> SCARD_S_SUCCESS then
      raise Exception.Create('SCardConnect: ' + DFWinSCardErrorText(Rv));
    try
      Rv := SCardBeginTransaction(Card);
      if Rv <> SCARD_S_SUCCESS then
        raise Exception.Create('SCardBeginTransaction: ' + DFWinSCardErrorText(Rv));
      try
        SetLength(Send, 5);
        Send[0] := $FF;
        Send[1] := $CA;
        Send[2] := $00;
        Send[3] := $00;
        Send[4] := Le;
        RecvLen := UID_RECV_LEN;
        Rv := SCardTransmit(Card, DFWinSCardPci(Protocol), @Send[0], Length(Send),
          nil, @Recv[0], RecvLen);
        if Rv <> SCARD_S_SUCCESS then
          raise Exception.Create('SCardTransmit: ' + DFWinSCardErrorText(Rv));
        if RecvLen < 2 then
          raise Exception.Create('UID yaniti cok kisa');
        if (Recv[RecvLen - 2] <> $90) or (Recv[RecvLen - 1] <> $00) then
          raise Exception.Create(Format('APDU SW=%2.2X%2.2X', [Recv[RecvLen - 2], Recv[RecvLen - 1]]));
        DataLen := Integer(RecvLen) - 2;
        SetLength(Data, DataLen);
        if DataLen > 0 then
          Move(Recv[0], Data[0], DataLen);
        Result := FormatUid(Data, AMode);
      finally
        SCardEndTransaction(Card, SCARD_LEAVE_CARD);
      end;
    finally
      SCardDisconnect(Card, SCARD_LEAVE_CARD);
    end;
  finally
    SCardReleaseContext(Ctx);
  end;
end;

function TDFACSReader.ReadUID: string;
begin
  Result := DoReadUID(FReaderName, FReadingMode);
end;

function TDFACSReader.ReadUID(const AReaderName: string; AMode: TDFACSReadingMode): string;
begin
  Result := DoReadUID(AReaderName, AMode);
end;

end.
