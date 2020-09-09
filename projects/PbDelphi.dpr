program PbDelphi;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Oz.Cocor.Lib in '..\src\protoc\Oz.Cocor.Lib.pas',
  Oz.Cocor.Utils in '..\src\protoc\Oz.Cocor.Utils.pas',
  Oz.Pb.Gen in '..\src\protoc\Oz.Pb.Gen.pas',
  Oz.Pb.Options in '..\src\protoc\Oz.Pb.Options.pas',
  Oz.Pb.Tab in '..\src\protoc\Oz.Pb.Tab.pas',
  Oz.Pb.Parser in '..\src\protoc\Oz.Pb.Parser.pas',
  Oz.Pb.Scanner in '..\src\protoc\Oz.Pb.Scanner.pas',
  Oz.Pb.Protoc in '..\src\protoc\Oz.Pb.Protoc.pas',
  Oz.Pb.Classes in '..\src\proto\Oz.Pb.Classes.pas',
  Oz.Pb.StrBuffer in '..\src\proto\Oz.Pb.StrBuffer.pas';

begin
  try
    Run;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
