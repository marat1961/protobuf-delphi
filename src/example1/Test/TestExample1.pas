unit TestExample1;

interface

uses
  TestFramework, SysUtils, Example1, pbPublic, pbOutput, Contnrs, pbInput;

type

  // Test methods for class TPhoneNumber
  TestTPhoneNumber = class(TTestCase)
  strict private
    FPhoneNumber: TPhoneNumber;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  end;

  // Test methods for class TPerson
  TestTPerson = class(TTestCase)
  strict private
    FPerson: TPerson;
  public
    procedure SetUp; override;
    procedure TearDown; override;
    procedure TestAddPhone;
  end;

  // Test methods for class TPersonBuilder
  TestTPersonBuilder = class(TTestCase)
  strict private
    FPersonBuilder: TPersonBuilder;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestGetBuf;
    procedure TestWrite;
  end;

  // Test methods for class TPersonReader
  TestTPersonReader = class(TTestCase)
  strict private
    FPersonReader: TPersonReader;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestGetBuf;
    procedure TestLoad;
  end;

implementation

procedure TestTPhoneNumber.SetUp;
begin
  FPhoneNumber := TPhoneNumber.Create;
end;

procedure TestTPhoneNumber.TearDown;
begin
  FPhoneNumber.Free;
  FPhoneNumber := nil;
end;

procedure TestTPerson.SetUp;
begin
  FPerson := TPerson.Create;
  FPerson.Name := 'Marat Shaymardanov';
  FPerson.Id := 1;
  FPerson.Email := 'marat-sh@sibmail.com';
  FPerson.AddPhone('+7 392 224 3699');
end;

procedure TestTPerson.TearDown;
begin
  FPerson.Free;
  FPerson := nil;
end;

procedure TestTPerson.TestAddPhone;
var
  Phone: TPhoneNumber;
begin
  Check(FPerson.PhonesCount = 1, 'Should be one phone');
  Phone := FPerson.Phones[0];
  Check(Phone.Number = '+7 392 224 3699', 'This is a phone with number 8 392 224 3699');
  Check(Phone.Typ = ptHOME, 'This is a home phone');

  FPerson.AddPhone('+7 913 826 2144', ptMOBILE);
  Check(FPerson.PhonesCount = 2, 'Should have two phone');
  Phone := FPerson.Phones[1];
  Check(Phone.Number = '+7 913 826 2144', 'This is a phone with number 913 826 2144');
  Check(Phone.Typ = ptMOBILE, 'This is a mobile phone');
end;

procedure TestTPersonBuilder.SetUp;
begin
  FPersonBuilder := TPersonBuilder.Create;
end;

procedure TestTPersonBuilder.TearDown;
begin
  FPersonBuilder.Free;
  FPersonBuilder := nil;
end;

procedure TestTPersonBuilder.TestGetBuf;
var
  ReturnValue: TProtoBufOutput;
begin
  ReturnValue := FPersonBuilder.GetBuf;
  Check(ReturnValue <> nil);
end;

procedure TestTPersonBuilder.TestWrite;
var
  Person: TPerson;
begin
  Person := TPerson.Create;
  try
    Person.Name := 'Marat Shaymardanov';
    Person.Id := 1;
    Person.Email := 'marat-sh@sibmail.com';
    Person.AddPhone('+7 392 224 3699');
    Person.AddPhone('+7 913 826 2144', ptMOBILE);
    FPersonBuilder.Write(Person);
    FPersonBuilder.GetBuf.SaveToFile('person.pb');
  finally
    Person.Free;
  end;
end;

procedure TestTPersonReader.SetUp;
begin
  FPersonReader := TPersonReader.Create;
end;

procedure TestTPersonReader.TearDown;
begin
  FPersonReader.Free;
  FPersonReader := nil;
end;

procedure TestTPersonReader.TestGetBuf;
var
  ReturnValue: TProtoBufInput;
begin
  ReturnValue := FPersonReader.GetBuf;
  Check(ReturnValue <> nil);
end;

procedure TestTPersonReader.TestLoad;
var
  Person: TPerson;
  Phone: TPhoneNumber;
begin
  Person := TPerson.Create;
  FPersonReader.GetBuf.LoadFromFile('person.pb');
  FPersonReader.Load(Person);

  Check(Person.Name = 'Marat Shaymardanov', 'test Name');
  Check(Person.Id = 1, 'Good Id');
  Check(Person.Email = 'marat-sh@sibmail.com', 'test Email');

  Check(person.PhonesCount = 2, 'Should have two phone');

  Phone := Person.Phones[0];
  Check(Phone.Number = '+7 392 224 3699', 'This is a phone with number +7 392 224 3699');
  Check(Phone.Typ = ptHOME, 'This is a home phone');

  Phone := person.Phones[1];
  Check(Phone.Number = '+7 913 826 2144', 'This is a phone with number +7 913 826 2144');
  Check(Phone.Typ = ptMOBILE, 'This is a mobile phone');
end;

initialization
  RegisterTest(TestTPhoneNumber.Suite);
  RegisterTest(TestTPerson.Suite);
  RegisterTest(TestTPersonBuilder.Suite);
  RegisterTest(TestTPersonReader.Suite);

end.

