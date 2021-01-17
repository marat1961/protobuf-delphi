unit Oz.Protoc.Test;

interface

uses
  System.SysUtils, System.Math, TestFramework, Oz.Pb.StrBuffer, Oz.Pb.Classes;

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
    procedure Test<T>(const a: T; var b: T);
  published
    procedure TestByte;
    procedure TestWord;
    procedure TestInteger;
    procedure TestInt64;
    procedure TestSingle;
    procedure TestDouble;
    procedure TestExtended;
    procedure TestCurrency;
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

procedure TPbTest.Test<T>(const a: T; var b: T);
var
  Io: TpbIoProc;
  r: TBytes;
begin
  S.Clear;
  Io := TpbIoProc.From<T>;
  Io.Save(S, a);
  r := S.Pb.GetBytes;
  L.Pb^ := TpbInput.From(r);
  Io.Load(L, b);
end;

procedure TPbTest.TestByte;
var
  a, b: Byte;
begin
  a := 123;
  Test<Byte>(a, b);
  CheckTrue(a = b);
end;

procedure TPbTest.TestWord;
var
  a, b: Word;
begin
  a := 4567;
  Test<Word>(a, b);
  CheckTrue(a = b);
  a := 65535;
  Test<Word>(a, b);
  CheckTrue(a = b);
end;

procedure TPbTest.TestInteger;
var
  a, b: Integer;
begin
  a := 1234567;
  Test<Integer>(a, b);
  CheckTrue(a = b);
  a := -754567;
  Test<Integer>(a, b);
  CheckTrue(a = b);
end;

procedure TPbTest.TestInt64;
var
  a, b: Int64;
begin
  a := 123456745654;
  Test<Int64>(a, b);
  CheckTrue(a = b);
  a := -75456712;
  Test<Int64>(a, b);
  CheckTrue(a = b);
end;

procedure TPbTest.TestSingle;
var
  a, b: Single;
begin
  a := 1.25E15;
  Test<Single>(a, b);
  CheckTrue(a = b);
  a := -7.5456712E23;
  Test<Single>(a, b);
  CheckTrue(a = b);
end;

procedure TPbTest.TestDouble;
var
  a, b: Double;
begin
  a := 1.25E+23;
  Test<Double>(a, b);
  CheckTrue(a = b);
  a := -7.5456712E+8;
  Test<Double>(a, b);
  CheckTrue(a = b);
end;

procedure TPbTest.TestExtended;
var
  a, b: Extended;
begin
  a := 1.25E+23;
  Test<Extended>(a, b);
  CheckTrue(SameValue(a, b));
  a := -7.5456712E+8;
  Test<Extended>(a, b);
  CheckTrue(SameValue(a, b));
end;

procedure TPbTest.TestCurrency;
var
  a, b: Currency;
begin
  a := 456451.25;
  Test<Currency>(a, b);
  CheckTrue(a = b);
  a := -7.5456;
  Test<Currency>(a, b);
  CheckTrue(a = b);
end;

procedure TPbTest.TestString;
var
  a, b: string;
begin
  a := '123 15° ▲ qwerty';
  Test<string>(a, b);
  CheckTrue(a = b);
end;

{$EndRegion}

initialization

  RegisterTest(TPbTest.Suite);

end.
