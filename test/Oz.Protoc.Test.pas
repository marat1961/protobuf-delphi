unit Oz.Protoc.Test;

interface

uses
  System.SysUtils, System.Math, TestFramework,
  Oz.Pb.StrBuffer, Oz.Pb.Classes, Oz.SGL.Collections;

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

  PPerson = ^TPerson;
  TPerson = record
  const
    ftName = 1;
    ftId = 2;
    ftEmail = 3;
    ftPhones = 4;
    ftMyPhone = 5;
  private
    FName: string;
    FId: Integer;
    FEmail: string;
    FPhones: TsgRecordList<TPhoneNumber>;
    FMyPhone: TPhoneNumber;
  public
    procedure Init;
    procedure Free;
    // properties
    property Name: string read FName write FName;
    property Id: Integer read FId write FId;
    property Email: string read FEmail write FEmail;
    property Phones: TsgRecordList<TPhoneNumber> read FPhones;
    property MyPhone: TPhoneNumber read FMyPhone write FMyPhone;
  end;

  PAddressBook = ^TAddressBook;
  TAddressBook = record
  const
    ftPeoples = 1;
  private
    FPeoples: TsgRecordList<TPerson>;
  public
    procedure Init;
    procedure Free;
    // properties
    property Peoples: TsgRecordList<TPerson> read FPeoples;
  end;

{$EndRegion}

{$Region 'TPbTest'}

  TPbTest = class(TTestCase)
  public
    S: TpbSaver;
    L: TpbLoader;
    procedure SetUp; override;
    procedure TearDown; override;
    procedure Test<T>(tag: Integer; const a: T; var b: T);
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
    procedure TestIO;
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

{$Region 'TPerson'}

procedure TPerson.Init;
begin
  Self := Default(TPerson);
  FPhones := TsgRecordList<TPhoneNumber>.From(nil);
end;

procedure TPerson.Free;
begin
  FPhones.Free;
end;

{$EndRegion}

{$Region 'TAddressBook'}

procedure TAddressBook.Init;
begin
  Self := Default(TAddressBook);
  FPeoples := TsgRecordList<TPerson>.From(nil);
end;

procedure TAddressBook.Free;
begin
  FPeoples.Free;
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

procedure TPbTest.Test<T>(tag: Integer; const a: T; var b: T);
var
  Io: TpbIoProc;
  r: TBytes;
begin
  S.Clear;
  Io := TpbIoProc.From<T>(tag);
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
  Test<Byte>(1, a, b);
  CheckTrue(a = b);
end;

procedure TPbTest.TestWord;
var
  a, b: Word;
begin
  a := 4567;
  Test<Word>(1, a, b);
  CheckTrue(a = b);
  a := 65535;
  Test<Word>(1, a, b);
  CheckTrue(a = b);
end;

procedure TPbTest.TestInteger;
var
  a, b: Integer;
begin
  a := 1234567;
  Test<Integer>(1, a, b);
  CheckTrue(a = b);
  a := -754567;
  Test<Integer>(1, a, b);
  CheckTrue(a = b);
end;

procedure TPbTest.TestInt64;
var
  a, b: Int64;
begin
  a := 123456745654;
  Test<Int64>(1, a, b);
  CheckTrue(a = b);
  a := -75456712;
  Test<Int64>(1, a, b);
  CheckTrue(a = b);
end;

procedure TPbTest.TestSingle;
var
  a, b: Single;
begin
  a := 1.25E15;
  Test<Single>(1, a, b);
  CheckTrue(a = b);
  a := -7.5456712E23;
  Test<Single>(1, a, b);
  CheckTrue(a = b);
end;

procedure TPbTest.TestDouble;
var
  a, b: Double;
begin
  a := 1.25E+23;
  Test<Double>(1, a, b);
  CheckTrue(a = b);
  a := -7.5456712E+8;
  Test<Double>(1, a, b);
  CheckTrue(a = b);
end;

procedure TPbTest.TestExtended;
var
  a, b: Extended;
begin
  a := 1.25E+23;
  Test<Extended>(1, a, b);
  CheckTrue(SameValue(a, b));
  a := -7.5456712E+8;
  Test<Extended>(1, a, b);
  CheckTrue(SameValue(a, b));
end;

procedure TPbTest.TestCurrency;
var
  a, b: Currency;
begin
  a := 456451.25;
  Test<Currency>(1, a, b);
  CheckTrue(a = b);
  a := -7.5456;
  Test<Currency>(1, a, b);
  CheckTrue(a = b);
end;

procedure TPbTest.TestString;
var
  a, b: string;
begin
  a := '123 15° ▲ qwerty';
  Test<string>(1, a, b);
  CheckTrue(a = b);
end;

procedure TPbTest.TestIO;
var
  Phone, LoadedPhone: TPhoneNumber;
  PhoneMeta: TObjMeta;
  S: TpbSaver;
  L: TpbLoader;
  offset: Integer;
  r: TBytes;
begin
  // Create metadata for TPhoneNumber
  PhoneMeta := TObjMeta.From<TPhoneNumber>;
  offset := PByte(@Phone.Number) - PByte(@Phone);
  PhoneMeta.Add<string>(TPhoneNumber.ftNumber, 'Number', offset);
  offset := PByte(@Phone.&Type) - PByte(@Phone);
  PhoneMeta.Add<TPhoneType>(TPhoneNumber.ftType, 'Type', offset);

  // Init phone instance
  Phone.Number := '243699';
  Phone.&Type := HOME;

  // Save phone to pb
  S.Init;
  PhoneMeta.SaveTo(S, Phone);
  r := S.Pb.GetBytes;
  S.Free;

  // Load phone from pb
  L.Pb^ := TpbInput.From(r);
  LoadedPhone.Init;
  PhoneMeta.LoadFrom(L, LoadedPhone);
  L.Free;

  CheckTrue(Phone.Number = LoadedPhone.Number);
  CheckTrue(Phone.&Type = LoadedPhone.&Type);
end;

{$EndRegion}

initialization

  RegisterTest(TPbTest.Suite);

end.
