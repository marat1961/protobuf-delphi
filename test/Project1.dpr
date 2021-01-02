(* Protocol buffer code generator, for Delphi
 * Copyright (c) 2020 Marat Shaimardanov
 *
 * This file is part of Protocol buffer code generator, for Delphi
 * is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this file. If not, see <https://www.gnu.org/licenses/>.
 *)

program Project1;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  TypInfo,
  Oz.Pb.Classes in '..\src\proto\Oz.Pb.Classes.pas',
  Oz.Pb.StrBuffer in '..\src\proto\Oz.Pb.StrBuffer.pas',
  Oz.SGL.Collections in '..\..\Oz-SGL\src\Oz.SGL.Collections.pas',
  Oz.SGL.HandleManager in '..\..\Oz-SGL\src\Oz.SGL.HandleManager.pas',
  Oz.SGL.Heap in '..\..\Oz-SGL\src\Oz.SGL.Heap.pas',
  Person in '..\data\Person.pas';

{$T+}

{$R *.RES}

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
  Phone.Init;
  Phone.Number := 'qwerty';
  Oz.MyPhone := Phone;

  // my home phones
  Phone.Init;
  Phone.&Type := TPhoneType.HOME;
  Phone.Number := '+7 382 224 3699';

  // my mobile phone
  Phone.Init;
  Phone.&Type := TPhoneType.MOBILE;
  Phone.Number := '+7 913 826 2144';
  Oz.Phones.Add(@Phone);
end;

// save data to proto file
procedure SaveData(var Oz: TPerson);
var
  Saver: TpbSaver;
begin
  // save data
  Saver.Init;
  try
    Saver.SavePerson(@Oz);
    Saver.Pb.SaveToFile('person.pb');
  finally
    Saver.Free;
  end;
end;

procedure ReadDataAndDump;
var
  Oz: TPerson;
  PhoneNumber: PPhoneNumber;
  Loader: TpbLoader;
begin
  Loader.Init;
  try
    Loader.Pb.LoadFromFile('person.pb');
    Oz.Init;
    try
      Loader.LoadPerson(@Oz);
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
  Oz.Init;
  try
    Writeln('Run Protocol Buffer Tests');
    GenData(Oz);
    SaveData(Oz);
  finally
    Oz.Free;
  end;
  ReadDataAndDump;
end;

begin
  TestPerson;
end.
