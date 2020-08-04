// Author this code - Marat Shaimardanov, Tomsk (2007..2020)
//
// Send any postcards with postage stamp to my address:
// Frunze 131/1, 56, Russia, Tomsk, 634021
// then you can use this code in self project.

program Project1;

{$APPTYPE CONSOLE}

uses
  FastMM4, // Always in the first place!
  SysUtils,
  TypInfo,
  Example1 in 'Example1.pas',
  UnitTest in '..\proto\UnitTest.pas',
  pbInput in '..\proto\pbInput.pas',
  pbOutput in '..\proto\pbOutput.pas',
  pbPublic in '..\proto\pbPublic.pas',
  StrBuffer in '..\proto\StrBuffer.pas';

{$R *.RES}

procedure WriteAndSave;
var
  Person: TPerson;
  PersonBuilder: TPersonBuilder;
begin
  Person := TPerson.Create;
  try
    Person.Name := 'Marat Shaimardanov';
    Person.Id := 1;
    Person.Email := 'marat.sh.1961@gmail.com';
    Person.AddPhone('+7 382 224 3699');
    Person.AddPhone('+7 913 826 2144', ptMOBILE);
    // write person and save to file
    PersonBuilder := TPersonBuilder.Create;
    try
      PersonBuilder.Write(Person);
      PersonBuilder.GetBuf.SaveToFile('person.pb');
    finally
      PersonBuilder.Free;
    end;
  finally
    Person.Free;
  end;
end;

procedure ReadAndDump;
var
  Person: TPerson;
  PhoneNumber: TPhoneNumber;
  PersonReader: TPersonReader;
  i: Integer;
begin
  PersonReader := TPersonReader.Create;
  try
    PersonReader.GetBuf.LoadFromFile('person.pb');
    Person := TPerson.Create;
    try
      PersonReader.Load(Person);
      // write to console
      Writeln('Name   : ', Person.Name);
      Writeln('Id     : ', IntToStr(Person.Id));
      Writeln('e-mail : ', Person.Email);
      for i := 0 to Person.PhonesCount - 1 do
      begin
        PhoneNumber := Person.Phones[i];
        Writeln('[', IntToStr(i + 1), ']');
        Writeln('  Number: ', PhoneNumber.Number);
        Writeln('  Type: ', GetEnumName(TypeInfo(TPhoneType),
          Integer(PhoneNumber.Typ)));
      end;
      Readln;
    finally
      Person.Free;
    end;
  finally
    PersonReader.Free;
  end;
end;

procedure TestPerson;
begin
  WriteAndSave;
  ReadAndDump;
end;

begin
  Writeln('Run Protocol Buffer Tests');
  TestAll;
  TestPerson;
end.
