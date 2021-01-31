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

{$Region 'TMetaRegister: Meta for save & load data'}

  TMetaRegister = record
  private
    PhoneMeta: TObjMeta;
    PersonMeta: TObjMeta;
    AddressBookMeta: TObjMeta;
    class procedure InitPhone(var obj); static;
    class procedure InitPerson(var obj); static;
    class procedure InitAddressBook(var obj); static;
    procedure SetPhoneMeta;
    procedure SetPersonMeta;
    procedure SetAddressBookMeta;
  public
    // Create metadata
    procedure Init;
    // Generate data for test
    procedure GenData(var AddressBook: TAddressBook);
    // Checked the match with the generated data
    function CheckData(const AddressBook: TAddressBook): Boolean;
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
    procedure LoadFrom(const L: TpbLoader; var AddressBook: TAddressBook);
  end;

{$EndRegion}

{$Region 'TPbTest'}

  TPbTest = class(TTestCase)
  public
    S: TpbSaver;
    L: TpbLoader;
    procedure SetUp; override;
    procedure TearDown; override;
    procedure Test<T>(tag: Integer; var a: T; var b: T);
  published
    procedure TestIO;
    procedure TestMeta;
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

{$Region 'TMetaRegister'}

procedure TMetaRegister.Init;
begin
  SetPhoneMeta;
  SetPersonMeta;
  SetAddressBookMeta;
end;

class procedure TMetaRegister.InitPhone(var obj);
begin
  TPhoneNumber(obj).Init;
end;

class procedure TMetaRegister.InitPerson(var obj);
begin
  TPerson(obj).Init;
end;

class procedure TMetaRegister.InitAddressBook(var obj);
begin
  TAddressBook(obj).Init;
end;

procedure TMetaRegister.SetPhoneMeta;
var
  v: TPhoneNumber;
begin
  PhoneMeta := TObjMeta.From<TPhoneNumber>(InitPhone);
  PhoneMeta.Add<string>(TPhoneNumber.ftNumber, 'Number', PByte(@v.FNumber) - PByte(@v));
  PhoneMeta.Add<TPhoneType>(TPhoneNumber.ftType, 'Type', PByte(@v.FType) - PByte(@v));
end;

procedure TMetaRegister.SetPersonMeta;
var
  v: TPerson;
begin
  PersonMeta := TObjMeta.From<TPerson>(InitPerson);
  PersonMeta.Add<string>(TPerson.ftName, 'Name', PByte(@v.FName) - PByte(@v));
  PersonMeta.Add<Integer>(TPerson.ftId, 'Id', PByte(@v.FId) - PByte(@v));
  PersonMeta.Add<string>(TPerson.ftEmail, 'Email', PByte(@v.FEmail) - PByte(@v));
  PersonMeta.AddObj('Phones', PByte(@v.FPhones) - PByte(@v),
    TpbIoProc.From(TPerson.ftPhones, TpbFieldKind.fkObjList, @PhoneMeta));
  PersonMeta.Add<string>(TPerson.ftName, 'MyPhone', PByte(@v.MyPhone) - PByte(@v));
end;

procedure TMetaRegister.SetAddressBookMeta;
var
  v: TAddressBook;
begin
  AddressBookMeta := TObjMeta.From<TAddressBook>(InitAddressBook);
  AddressBookMeta.AddObj('Peoples', PByte(@v.FPeoples) - PByte(@v),
    TpbIoProc.From(TAddressBook.ftPeoples, TpbFieldKind.fkObjList, @PersonMeta));
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
  Phone.Number := '+7 382 000 0000';
  Person.Phones.Add(@Phone);

  // mobile phone
  Phone.Init;
  Phone.&Type := TPhoneType.MOBILE;
  Phone.Number := '+7 913 826 2144';
  Person.Phones.Add(@Phone);
  AddressBook.Peoples.Add(@Person);
end;

function TMetaRegister.CheckData(const AddressBook: TAddressBook): Boolean;
var
  Person: PPerson;
  Phone: PPhoneNumber;
begin
  Result := False;
  if AddressBook.Peoples.Count <> 2 then exit;

  Person := AddressBook.Peoples[0];
  if Person.Name <> 'Oz Grock' then exit;
  if Person.Id <> 1 then exit;
  if Person.Email <> 'oz@mail.com' then exit;

  Phone := @Person.MyPhone;
  if Phone.&Type <> TPhoneType.MOBILE then exit;
  if Phone.Number <> '' then exit;

  if Person.Phones.Count <> 2 then exit;
  Phone := Person.Phones[0];
  if Phone.&Type <> TPhoneType.HOME then exit;
  if Phone.Number <> '+7 382 224 99999' then exit;
  Phone := Person.Phones[1];
  if Phone.&Type <> TPhoneType.MOBILE then exit;
  if Phone.Number <> '999999' then exit;

  Person := AddressBook.Peoples[1];
  if Person.Name <> 'Marat Shaimardanov' then exit;
  if Person.Id <> 2 then exit;
  if Person.Email <> 'marat.sh.1961@gmail.com' then exit;

  Phone := @Person.MyPhone;
  if Phone.&Type <> TPhoneType.MOBILE then exit;
  if Phone.Number <> 'qwerty' then exit;

  if Person.Phones.Count <> 2 then exit;
  Phone := Person.Phones[0];
  if Phone.&Type <> TPhoneType.HOME then exit;
  if Phone.Number <> '+7 382 000 0000' then exit;

  Phone := Person.Phones[1];
  if Phone.&Type <> TPhoneType.MOBILE then exit;
  if Phone.Number <> '+7 913 826 2144' then exit;

  Result := True;
end;

procedure TMetaRegister.Dump(var AddressBook: TAddressBook);
var
  i: Integer;
  Person: PPerson;
  PhoneNumber: PPhoneNumber;
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

procedure TMetaRegister.SaveTo(const S: TpbSaver; var AddressBook: TAddressBook);
begin
  TObjMeta.SaveTo(@AddressBookMeta, S, AddressBook);
end;

procedure TMetaRegister.LoadFrom(const L: TpbLoader; var AddressBook: TAddressBook);
begin
  TObjMeta.LoadFrom(@AddressBookMeta, L, AddressBook);
end;

{$EndRegion}

{$Region 'TPbTest'}

procedure TPbTest.SetUp;
begin
  log.Init;
  S.Init;
  L.Init;
end;

procedure TPbTest.TearDown;
begin
  log.SaveToFile('dump.txt');
  S.Free;
  L.Free;
end;

procedure TPbTest.Test<T>(tag: Integer; var a: T; var b: T);
var
  Io: TpbIoProc;
  r: TBytes;
begin
  S.Clear;
  Io := TpbIoProc.From<T>(tag);
  Io.SaveTo(S, a);
  r := S.Pb.GetBytes;
  L.Pb^ := TpbInput.From(r);
  Io.LoadFrom(L, b);
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
  ms: TMetaRegister;
  S: TpbSaver;
  L: TpbLoader;
  r: TBytes;
begin
  // Create metadata for TPhoneNumber
  ms.Init;

  // Init phone instance
  Phone.Init;
  Phone.Number := '243699';
  Phone.&Type := HOME;

  // Save phone to pb
  S.Init;
  TObjMeta.SaveTo(@ms.PhoneMeta, S, Phone);
  r := S.Pb.GetBytes;
  S.Free;

  // Load phone from pb
  L.Pb^ := TpbInput.From(r);
  LoadedPhone.Init;
  TObjMeta.LoadFrom(@ms.PhoneMeta, L, LoadedPhone);
  L.Free;

  CheckTrue(Phone.Number = LoadedPhone.Number);
  CheckTrue(Phone.&Type = LoadedPhone.&Type);
end;

procedure TPbTest.TestMeta;
var
  meta: TMetaRegister;
  genBook, readedBook: TAddressBook;
  S: TpbSaver;
  L: TpbLoader;
  r: TBytes;
begin
  meta.Init;
  // Init address book data
  meta.GenData(genBook);
  Check(meta.CheckData(genBook));
  // Save address book data to pb
  S.Init;
  meta.SaveTo(S, genBook);
  S.Pb.SaveToFile('book.pb');
  r := S.Pb.GetBytes;
  S.Free;

  // Load address book data from pb
  L.Init;
  L.Pb^ := TpbInput.From(r);
  meta.LoadFrom(L, readedBook);
  Check(meta.CheckData(readedBook));
  L.Free;
end;

{$EndRegion}

initialization

  RegisterTest(TPbTest.Suite);

end.
