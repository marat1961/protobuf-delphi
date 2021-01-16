unit Oz.Protoc.Test;

interface

uses
  System.SysUtils, TestFramework, Oz.Pb.StrBuffer, Oz.Pb.Classes;

{$Region 'TPhoneNumber'}

type
  TPhoneType = (
    MOBILE = 0,
    HOME = 1,
    WORK = 2);

  PPhoneNumber = ^TPhoneNumber;
  TPhoneNumber = record
  const
    ftNumber = 1;
    ftType = 2;
  private
    FNumber: string;
    FType: TPhoneType;
  public
    procedure Init;
    procedure Free;
    // properties
    property Number: string read FNumber write FNumber;
    property &Type: TPhoneType read FType write FType;
  end;

{$EndRegion}

{$Region 'TPbTest'}

  TPbTest = class(TTestCase)
  public
    S: TpbSaver;
    L: TpbLoader;
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestByte;
    procedure TestInt;
    procedure TestReal;
    procedure TestString;
  end;

{$EndRegion}

implementation

{$Region 'TPhoneNumber'}

procedure TPhoneNumber.Init;
begin
  Self := Default(TPhoneNumber);
end;

procedure TPhoneNumber.Free;
begin
end;

{$EndRegion}

{$Region 'TPbTest'}

procedure TPbTest.SetUp;
begin
  S.Init;
  L.Init;
end;

procedure TPbTest.TearDown;
begin
  S.Free;
  L.Free;
end;

procedure TPbTest.TestByte;
var
  Io: TpbIoProc;
  a, b: Byte;
  r: TBytes;
begin
  Io := TpbIoProc.From<Byte>;
  a := 123;
  Io.Save(S, a);
  r := S.Pb.GetBytes;
  L.Pb^ := TpbInput.From(r);
  Io.Load(L, b);
  CheckTrue(a = b);
end;

procedure TPbTest.TestInt;
var
  ByteIo, WordIo, Int32Io, Int64Io: TpbIoProc;
begin
  ByteIo := TpbIoProc.From<Byte>;
  WordIo := TpbIoProc.From<Word>;
  Int32Io := TpbIoProc.From<Integer>;
  Int64Io := TpbIoProc.From<Int64>;
end;

procedure TPbTest.TestReal;
var
  SingleIo, DoubleIo, ExtendedIo, CurrencyIo: TpbIoProc;
begin
  SingleIo := TpbIoProc.From<Single>;
  DoubleIo := TpbIoProc.From<Double>;
  ExtendedIo := TpbIoProc.From<Extended>;
  CurrencyIo := TpbIoProc.From<Currency>;
end;

procedure TPbTest.TestString;
var
  StringIo: TpbIoProc;
begin
  StringIo := TpbIoProc.From<string>;
end;

{$EndRegion}

initialization

  RegisterTest(TPbTest.Suite);

end.
