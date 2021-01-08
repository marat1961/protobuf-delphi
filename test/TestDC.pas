unit TestDC;

interface

uses
  System.SysUtils, System.TypInfo, Oz.Pb.StrBuffer, Oz.Pb.Classes, PersonDC;

procedure RunTest;

implementation

// generate data
procedure GenData(var Oz: TPerson);
var
  Phone: TPhoneNumber;
begin
  // my data
  Oz.Name := 'Marat Shaimardanov';
  Oz.Id := 1;
  Oz.Email := 'marat.sh.1961@gmail.com';

  // single message
  Phone := TPhoneNumber.Create;
  Phone.Number := 'qwerty';
  Oz.MyPhone := Phone;

  // my home phones
  Phone := TPhoneNumber.Create;
  Phone.&Type := TPhoneType.HOME;
  Phone.Number := '+7 382 224 3699';

  // my mobile phone
  Phone := TPhoneNumber.Create;
  Phone.&Type := TPhoneType.MOBILE;
  Phone.Number := '+7 913 826 2144';
  Oz.Phones.Add(Phone);
end;

// save data to proto file
procedure SaveData(var Oz: TPerson);
var
  Saver: TpbSaver;
begin
  // save data
  Saver.Init;
  try
    TpbSaver.SavePerson(Saver, Oz);
    Saver.Pb.SaveToFile('person.pb');
  finally
    Saver.Free;
  end;
end;

procedure ReadDataAndDump;
var
  Oz: TPerson;
  PhoneNumber: TPhoneNumber;
  Loader: TpbLoader;
begin
  Loader.Init;
  try
    Loader.Pb.LoadFromFile('person.pb');
    Oz := TPerson.Create;
    try
      Loader.LoadPerson(Oz);
      // write to console
      Writeln('Name   : ', Oz.Name);
      Writeln('Id     : ', IntToStr(Oz.Id));
      Writeln('e-mail : ', Oz.Email);
      Writeln('phone  : ', Oz.MyPhone.Number);
      for PhoneNumber in Oz.Phones do
      begin
        Writeln('  Number: ', PhoneNumber.Number);
        Writeln('  Type: ', GetEnumName(TypeInfo(TPhoneType),
          Integer(PhoneNumber.&Type)));
      end;
      Readln;
    finally
      Oz.Free;
    end;
  finally
    Loader.Free;
  end;
end;

procedure TestPerson;
var
  Oz: TPerson;
begin
  Oz := TPerson.Create;
  try
    Writeln('Run Protocol Buffer Tests');
    GenData(Oz);
    SaveData(Oz);
  finally
    Oz.Free;
  end;
  ReadDataAndDump;
end;

procedure RunTest;
begin
  TestPerson;
end;

end.
