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
  Oz.Pb.StrBuffer in '..\src\proto\Oz.Pb.StrBuffer.pas',
  Oz.Pb.CustomGen in '..\src\protoc\Oz.Pb.CustomGen.pas',
  Oz.Pb.GenSGL in '..\src\protoc\Oz.Pb.GenSGL.pas',
  Oz.Pb.GenDC in '..\src\protoc\Oz.Pb.GenDC.pas',
  Oz.SGL.HandleManager in '..\..\Oz-SGL\src\Oz.SGL.HandleManager.pas',
  Oz.SGL.Hash in '..\..\Oz-SGL\src\Oz.SGL.Hash.pas',
  Oz.SGL.Heap in '..\..\Oz-SGL\src\Oz.SGL.Heap.pas',
  Oz.SGL.Collections in '..\..\Oz-SGL\src\Oz.SGL.Collections.pas';

begin
  try
    Run;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
