unit Oz.Protoc.Test;

interface

uses
  System.SysUtils, System.Math, System.TypInfo, TestFramework,
  Oz.Pb.StrBuffer, Oz.Pb.Classes, Oz.SGL.Collections;

{$T+}

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
    class procedure GetFields(var fp: TFieldParams); static;
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
    class procedure GetFields(var fp: TFieldParams); static;
    // properties
    property Name: string read FName write FName;
    property Id: Integer read FId write FId;
    property Email: string read FEmail write FEmail;
    property Phones: TsgRecordList<TPhoneNumber> read FPhones;
    property MyPhone: TPhoneNumber read FMyPhone write FMyPhone;
  end;

(*

procedure TMetaRegister.InitAddressBookMeta;
var
  AddressBook: TAddressBook;
  offset: Integer;
begin
  PersonMeta := TObjMeta.From<TPerson>;
  offset := PByte(@AddressBook.FPeoples) - PByte(@AddressBook);
  PersonMeta.Add<TPhoneNumber>(TAddressBook.ftPeoples, 'Peoples', offset);
end;



*)
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

{$Region 'TMetaRegister: Meta for save & load data'}

  TMetaRegister = record
  private
    PhoneMeta: TObjMeta;
    PersonMeta: TObjMeta;
    AddressBookMeta: TObjMeta;
  public
    // Create metadata
    procedure Init;
    // Generate data for test
    procedure GenData(var AddressBook: TAddressBook);
    // Dump data
    procedure Dump(var AddressBook: TAddressBook);
    // Returns phone meta
    function GetPhoneMeta: PObjMeta; inline;
    // Returns person meta
    function GetPersonMeta: PObjMeta; inline;
    // Returns address book meta
    function GetAddressBookMeta: PObjMeta; inline;
    // Save data to protocol buffer
    procedure SaveTo(const S: TpbSaver; var AddressBook: TAddressBook);
    // Load data from protocol buffer
    procedure LoadFrom(const L: TpbLoader; var obj);
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
    procedure TestMeta;
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

class procedure TPhoneNumber.GetFields(var fp: TFieldParams);
var
  v: TPhoneNumber;
begin
  fp.Add(ftNumber, PByte(@v.FNumber) - PByte(@v), 'Number');
  fp.Add(ftType, PByte(@v.FType) - PByte(@v), 'Type');
end;

{$EndRegion}

{$Region 'TPerson'}

class procedure TPerson.GetFields(var fp: TFieldParams);
var
  v: TPerson;
begin
  fp.Add(ftName, PByte(@v.FName) - PByte(@v), 'Name');
  fp.Add(ftId, PByte(@v.FEmail) - PByte(@v), 'Id');
  fp.Add(ftEmail, PByte(@v.FName) - PByte(@v), 'Email');
  fp.Add(ftPhones, PByte(@v.FPhones) - PByte(@v), 'Phones');
  fp.Add(ftName, PByte(@v.MyPhone) - PByte(@v), 'MyPhone');
end;

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

{$Region 'TMetaRegister'}

procedure TMetaRegister.Init;
var
  fp: TFieldParams;
begin
  TPhoneNumber.GetFields(fp);
  PhoneMeta.Init(fp);
//  InitPersonMeta;
//  InitAddressBookMeta;
end;

procedure TMetaRegister.GenData(var AddressBook: TAddressBook);
var
  Person: TPerson;
  Phone: TPhoneNumber;
begin
  AddressBook.Init;
  // data
  Person.Init;
  Person.Name := 'Oz Grock';
  Person.Id := 1;
  Person.Email := 'oz@mail.com';

  // home phones
  Phone.Init;
  Phone.&Type := TPhoneType.HOME;
  Phone.Number := '+7 382 224 99999';
  Person.Phones.Add(@Phone);

  Phone.Init;
  Phone.&Type := TPhoneType.MOBILE;
  Phone.Number := '999999';
  Person.Phones.Add(@Phone);
  AddressBook.Peoples.Add(@Person);

  // data
  Person.Init;
  Person.Name := 'Marat Shaimardanov';
  Person.Id := 2;
  Person.Email := 'marat.sh.1961@gmail.com';

  // single message
  Phone.Init;
  Phone.Number := 'qwerty';
  Person.MyPhone := Phone;

  // home phones
  Phone.Init;
  Phone.&Type := TPhoneType.HOME;
  Phone.Number := '+7 382 224 3699';

  // mobile phone
  Phone.Init;
  Phone.&Type := TPhoneType.MOBILE;
  Phone.Number := '+7 913 826 2144';
  Person.Phones.Add(@Phone);
  AddressBook.Peoples.Add(@Person);
end;

function TMetaRegister.GetPhoneMeta: PObjMeta;
begin
  Result := @PhoneMeta;
end;

function TMetaRegister.GetPersonMeta: PObjMeta;
begin
  Result := @PersonMeta;
end;

function TMetaRegister.GetAddressBookMeta: PObjMeta;
begin
  Result := @AddressBookMeta;
end;

procedure TMetaRegister.Dump(var AddressBook: TAddressBook);
var
  Person: PPerson;
  PhoneNumber: PPhoneNumber;
  i: Integer;
begin
  for i := 0 to AddressBook.Peoples.Count - 1 do
  begin
    Person := AddressBook.Peoples.Items[i];
    // write to console
    Writeln('Name   : ', Person.Name);
    Writeln('Id     : ', IntToStr(Person.Id));
    Writeln('e-mail : ', Person.Email);
    Writeln('phone  : ', Person.MyPhone.Number);
    for PhoneNumber in Person.Phones do
    begin
      Writeln('  Number: ', PhoneNumber.Number);
      Writeln('  Type: ', GetEnumName(TypeInfo(TPhoneType),
        Integer(PhoneNumber.&Type)));
    end;
  end;
  Readln;
end;

procedure TMetaRegister.SaveTo(const S: TpbSaver; var AddressBook: TAddressBook);
begin
end;

procedure TMetaRegister.LoadFrom(const L: TpbLoader; var obj);
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
  r: TBytes;
  fp: TFieldParams;
begin
  // Create metadata for TPhoneNumber
  PhoneMeta := TObjMeta.From<TPhoneNumber>;
  TPhoneNumber.GetFields(fp);
  PhoneMeta.Add<string>(fp.Fields[0]);
  PhoneMeta.Add<TPhoneType>(fp.Fields[1]);

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

procedure TPbTest.TestMeta;
var
  meta: TMetaRegister;
  AddressBook: TAddressBook;
  S: TpbSaver;
  L: TpbLoader;
  r: TBytes;
begin
  meta.Init;
  // Init address book data
  meta.GenData(AddressBook);
  // Save address book data to pb
  S.Init;
  meta.SaveTo(S, AddressBook);
  r := S.Pb.GetBytes;
  S.Free;

  // Load address book data from pb
  L.Pb^ := TpbInput.From(r);
  meta.LoadFrom(L, AddressBook);
  L.Free;

//  CheckTrue(Phone.Number = LoadedPhone.Number);
//  CheckTrue(Phone.&Type = LoadedPhone.&Type);
end;

{$EndRegion}

initialization

  RegisterTest(TPbTest.Suite);

end.
