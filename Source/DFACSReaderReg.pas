{*******************************************************************************
  TDFACSReader design-time registration
  Website: delphifan.com
  Email:   adsdelphi@gmail.com
*******************************************************************************}
unit DFACSReaderReg;

interface

procedure Register;

implementation

uses
  System.Classes,
  DFACSReader;

procedure Register;
begin
  RegisterComponents('DF ACS', [TDFACSReader]);
end;

end.
