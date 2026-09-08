# DF ACS Reader

VCL component for reading UID from ACS / ACR contactless readers on Windows.

It talks to the Windows Smart Card API (`winscard.dll` / PC/SC).

UID is requested with the PC/SC Escape APDU used by ACS readers:

```
FF CA 00 00 Le
```

`Le` is `04` for 4-byte UIDs and `07` for 7-byte UIDs.

| | |
|---|---|
| Component | `TDFACSReader` |
| Palette | **DF ACS** |
| Platforms | VCL Win32 / Win64 |
| Website | [delphifan.com](https://delphifan.com) |
| Email | adsdelphi@gmail.com |

## Requirements

- Delphi 10.3 Rio or later
- Windows Smart Card service running
- ACS / ACR (or other PC/SC) reader driver installed
- Reader plugged in

## Folder layout

```
Delphi/
  Source/
    DFWinSCard.pas          WinSCard API
    DFACSReader.pas         TDFACSReader
    DFACSReaderReg.pas      palette registration
    DFACSReader.dpk         optional runtime package
    dclDFACSReader.dpk      design-time package (Install)
  Demo/
    DFACSReaderDemo.dpr     VCL demo
    uMain.pas / uMain.dfm
  DFACSReader.groupproj
  README.md
```

## Install on the Tool Palette

The component appears next to other VCL controls **only after** the design-time package is installed.

1. Open `Source\dclDFACSReader.dpk` in Delphi.
2. Right-click the package → **Install**.
3. Open a VCL form.
4. Open the Tool Palette and find the **DF ACS** category, or search for `DFACSReader`.
5. Drop **TDFACSReader** on the form.

If the category is missing: **Component → Install Packages**, confirm `dclDFACSReader` is checked.

Installing the demo project from source does **not** register the palette item. Palette registration comes only from **Install**.

## Quick start

```pascal
procedure TForm1.FormCreate(Sender: TObject);
begin
  ACSReader.LoadReaders(cbxReaders.Items, True);
  ACSReader.ReadingMode := rmUID4Hex;
  ACSReader.Active := True;
end;

procedure TForm1.ACSReaderUIDRead(Sender: TObject; const UID: string);
begin
  EditUID.Text := UID;
end;
```

Typical flow:

1. Call `LoadReaders` (or set `ReaderName` yourself).
2. Set `ReadingMode`.
3. Assign `OnUIDRead`.
4. Set `Active := True` (or call `Start`).
5. Present a card. The component raises `OnCardInserted`, then reads the UID and raises `OnUIDRead`.

## Properties

| Property | Type | Default | Description |
|---|---|---|---|
| `Active` | `Boolean` | `False` | Starts / stops card insert monitoring. Safe at design time (no PC/SC I/O). |
| `ReaderName` | `string` | `''` | PC/SC reader name, e.g. `ACS ACR122 0`. Changing it while active restarts the monitor. |
| `ReadingMode` | `TDFACSReadingMode` | `rmUID4Hex` | UID format (see table below). |
| `DuplicateBlockMs` | `Integer` | `400` | Ignore the same UID if it is reported again within this many milliseconds. `0` disables. |

## Methods

| Method | Description |
|---|---|
| `GetReaders` | Returns connected PC/SC reader names. |
| `LoadReaders(Dest, SelectFirst)` | Fills a `TStrings` / combo. If `SelectFirst` is true, sets `ReaderName` to the first reader. |
| `ReadUID` | Reads UID now from `ReaderName` using `ReadingMode`. Card must already be on the reader. |
| `ReadUID(ReaderName, Mode)` | Same, with explicit reader and mode. |
| `Start` / `Stop` | Same as `Active := True` / `False`. |

## Events

| Event | When |
|---|---|
| `OnUIDRead` | UID was read after a card insert (duplicate filter applied). |
| `OnCardInserted` | Card present after empty (before UID read). |
| `OnCardRemoved` | Card taken off the reader. |
| `OnError` | PC/SC or APDU error. `Code` is the raw `LONG` status. |
| `OnStarted` | Monitor thread started. |
| `OnStopped` | Monitor stopped. |

`OnUIDRead` and the card events run on the main thread.

## Reading modes

Compatible with the original VB.NET UIDtoKeyboard modes 1–6.

| Enum | VB mode | Output |
|---|---|---|
| `rmUID4Hex` | 1 | 4-byte UID, hex, as reported (`A1B2C3D4`) |
| `rmUID4HexReversed` | 2 | 4-byte UID, hex, byte-reversed |
| `rmUID7Hex` | 3 | 7-byte UID, hex |
| `rmUID7HexReversed` | 4 | 7-byte UID, hex, byte-reversed |
| `rmUID4DecReversed` | 5 | first 4 bytes reversed, then unsigned 32-bit decimal |
| `rmUID4Dec` | 6 | first 4 bytes as little-endian `UInt32` decimal |

Hex strings are uppercase, no separators.

## Demo

Open `Demo\DFACSReaderDemo.dpr`.

- **Yenile** — refresh reader list  
- **Reading mode** — modes 1–6  
- **Başlat / Durdur** — start / stop monitoring  
- **Bir kez oku** — read UID immediately  

You can compile the demo without installing the package; the demo links `DFACSReader.pas` directly.

## Using in your own project

**With palette (recommended)**

1. Install `dclDFACSReader.dpk`.
2. Drop `TDFACSReader` on a form.
3. Wire events in the Object Inspector.

**Without palette**

Add these units to the project:

- `Source\DFWinSCard.pas`
- `Source\DFACSReader.pas`

Create the component in code:

```pascal
ACSReader := TDFACSReader.Create(Self);
ACSReader.OnUIDRead := ACSReaderUIDRead;
ACSReader.LoadReaders(cbxReaders.Items, True);
ACSReader.Active := True;
```

## Runtime package (optional)

`DFACSReader.dpk` is a run-only package if you prefer linking against a BPL instead of compiling the units into each EXE. Most VCL apps can ignore it and compile the units statically.

## How it works

1. `SCardEstablishContext` / `SCardListReadersW` — enumerate readers  
2. Background `SCardGetStatusChangeW` — wait for card insert / remove  
3. `SCardConnectW` + `SCardTransmit` — send `FF CA 00 00 Le`  
4. Status words `90 00` — UID bytes are everything before SW1/SW2  

The old .NET libraries only wrapped this same Windows API. This component calls `winscard.dll` from Delphi.

## Troubleshooting

| Symptom | What to check |
|---|---|
| No readers | Driver installed, reader powered, Smart Card service (`SCardSvr`) running. Click refresh after plugging in. |
| `No smart card` on ReadUID | Card is not on the antenna, or the card is not ISO 14443. |
| APDU SW not `9000` | Reader/firmware may not support GET DATA UID, or the card needs a different Le. |
| Component missing from palette | Install `dclDFACSReader.dpk`. Search the palette for `DFACSReader`. |
| Duplicate UID events | Increase `DuplicateBlockMs`. |

## License / contact

Copyright DelphiFan.  
Website: https://delphifan.com  
Email: adsdelphi@gmail.com
