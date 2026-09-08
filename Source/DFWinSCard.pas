{*******************************************************************************
  DFWinSCard
  Windows PC/SC (winscard.dll) bindings for ACS / ACR readers.

  Website: delphifan.com
  Email:   adsdelphi@gmail.com
*******************************************************************************}
unit DFWinSCard;

interface

uses
  System.SysUtils,
  Winapi.Windows;

const
  WINSCARD_DLL = 'winscard.dll';

  SCARD_S_SUCCESS = 0;
  SCARD_E_CANCELLED = Integer($80100002);
  SCARD_E_INSUFFICIENT_BUFFER = Integer($80100008);
  SCARD_E_NO_SMARTCARD = Integer($8010000C);
  SCARD_E_NO_SERVICE = Integer($8010001D);
  SCARD_E_NO_READERS_AVAILABLE = Integer($8010002E);
  SCARD_E_TIMEOUT = Integer($8010000A);
  SCARD_W_REMOVED_CARD = Integer($80100069);

  SCARD_SCOPE_USER = 0;
  SCARD_SCOPE_TERMINAL = 1;
  SCARD_SCOPE_SYSTEM = 2;

  SCARD_SHARE_EXCLUSIVE = 1;
  SCARD_SHARE_SHARED = 2;
  SCARD_SHARE_DIRECT = 3;

  SCARD_PROTOCOL_UNDEFINED = 0;
  SCARD_PROTOCOL_T0 = 1;
  SCARD_PROTOCOL_T1 = 2;
  SCARD_PROTOCOL_RAW = 4;
  SCARD_PROTOCOL_ANY = SCARD_PROTOCOL_T0 or SCARD_PROTOCOL_T1;

  SCARD_LEAVE_CARD = 0;
  SCARD_RESET_CARD = 1;
  SCARD_UNPOWER_CARD = 2;
  SCARD_EJECT_CARD = 3;

  SCARD_STATE_UNAWARE = $0000;
  SCARD_STATE_IGNORE = $0001;
  SCARD_STATE_CHANGED = $0002;
  SCARD_STATE_UNKNOWN = $0004;
  SCARD_STATE_UNAVAILABLE = $0008;
  SCARD_STATE_EMPTY = $0010;
  SCARD_STATE_PRESENT = $0020;
  SCARD_STATE_ATRMATCH = $0040;
  SCARD_STATE_EXCLUSIVE = $0080;
  SCARD_STATE_INUSE = $0100;
  SCARD_STATE_MUTE = $0200;
  SCARD_STATE_UNPOWERED = $0400;

  SCARD_AUTOALLOCATE = DWORD(-1);

type
  TSCARDCONTEXT = THandle;
  TSCARDHANDLE = THandle;
  PSCARDCONTEXT = ^TSCARDCONTEXT;
  PSCARDHANDLE = ^TSCARDHANDLE;

  TSCARD_IO_REQUEST = record
    dwProtocol: DWORD;
    cbPciLength: DWORD;
  end;
  PSCARD_IO_REQUEST = ^TSCARD_IO_REQUEST;

  TSCARD_READERSTATEW = record
    szReader: PWideChar;
    pvUserData: Pointer;
    dwCurrentState: DWORD;
    dwEventState: DWORD;
    cbAtr: DWORD;
    rgbAtr: array[0..35] of Byte;
  end;
  PSCARD_READERSTATEW = ^TSCARD_READERSTATEW;

function SCardEstablishContext(dwScope: DWORD; pvReserved1, pvReserved2: Pointer;
  out phContext: TSCARDCONTEXT): LONG; stdcall;
  external WINSCARD_DLL name 'SCardEstablishContext';

function SCardReleaseContext(hContext: TSCARDCONTEXT): LONG; stdcall;
  external WINSCARD_DLL name 'SCardReleaseContext';

function SCardIsValidContext(hContext: TSCARDCONTEXT): LONG; stdcall;
  external WINSCARD_DLL name 'SCardIsValidContext';

function SCardListReadersW(hContext: TSCARDCONTEXT; mszGroups: PWideChar;
  mszReaders: PWideChar; var pcchReaders: DWORD): LONG; stdcall;
  external WINSCARD_DLL name 'SCardListReadersW';

function SCardConnectW(hContext: TSCARDCONTEXT; szReader: PWideChar;
  dwShareMode, dwPreferredProtocols: DWORD; out phCard: TSCARDHANDLE;
  out pdwActiveProtocol: DWORD): LONG; stdcall;
  external WINSCARD_DLL name 'SCardConnectW';

function SCardDisconnect(hCard: TSCARDHANDLE; dwDisposition: DWORD): LONG; stdcall;
  external WINSCARD_DLL name 'SCardDisconnect';

function SCardBeginTransaction(hCard: TSCARDHANDLE): LONG; stdcall;
  external WINSCARD_DLL name 'SCardBeginTransaction';

function SCardEndTransaction(hCard: TSCARDHANDLE; dwDisposition: DWORD): LONG; stdcall;
  external WINSCARD_DLL name 'SCardEndTransaction';

function SCardTransmit(hCard: TSCARDHANDLE; pioSendPci: PSCARD_IO_REQUEST;
  pbSendBuffer: Pointer; cbSendLength: DWORD; pioRecvPci: PSCARD_IO_REQUEST;
  pbRecvBuffer: Pointer; var pcbRecvLength: DWORD): LONG; stdcall;
  external WINSCARD_DLL name 'SCardTransmit';

function SCardGetStatusChangeW(hContext: TSCARDCONTEXT; dwTimeout: DWORD;
  rgReaderStates: PSCARD_READERSTATEW; cReaders: DWORD): LONG; stdcall;
  external WINSCARD_DLL name 'SCardGetStatusChangeW';

function SCardCancel(hContext: TSCARDCONTEXT): LONG; stdcall;
  external WINSCARD_DLL name 'SCardCancel';

function SCardFreeMemory(hContext: TSCARDCONTEXT; pvMem: Pointer): LONG; stdcall;
  external WINSCARD_DLL name 'SCardFreeMemory';

function DFWinSCardPci(Protocol: DWORD): PSCARD_IO_REQUEST;
function DFWinSCardErrorText(Code: LONG): string;

implementation

function PciSymbol(const Symbol: AnsiString): PSCARD_IO_REQUEST;
var
  ModHandle: HMODULE;
begin
  ModHandle := GetModuleHandle(WINSCARD_DLL);
  if ModHandle = 0 then
    ModHandle := LoadLibrary(WINSCARD_DLL);
  Result := GetProcAddress(ModHandle, PAnsiChar(Symbol));
end;

function DFWinSCardPci(Protocol: DWORD): PSCARD_IO_REQUEST;
begin
  if (Protocol and SCARD_PROTOCOL_T0) <> 0 then
    Result := PciSymbol('g_rgSCardT0Pci')
  else if (Protocol and SCARD_PROTOCOL_T1) <> 0 then
    Result := PciSymbol('g_rgSCardT1Pci')
  else
    Result := PciSymbol('g_rgSCardRawPci');
end;

function DFWinSCardErrorText(Code: LONG): string;
begin
  case DWORD(Code) of
    DWORD(SCARD_S_SUCCESS): Result := 'Success';
    DWORD(SCARD_E_CANCELLED): Result := 'Cancelled';
    DWORD(SCARD_E_INSUFFICIENT_BUFFER): Result := 'Insufficient buffer';
    DWORD(SCARD_E_NO_SMARTCARD): Result := 'No smart card';
    DWORD(SCARD_E_NO_SERVICE): Result := 'Smart Card service is not running';
    DWORD(SCARD_E_NO_READERS_AVAILABLE): Result := 'No readers available';
    DWORD(SCARD_E_TIMEOUT): Result := 'Timeout';
    DWORD(SCARD_W_REMOVED_CARD): Result := 'Card removed';
  else
    Result := 'PC/SC error 0x' + IntToHex(DWORD(Code), 8);
  end;
end;

end.
