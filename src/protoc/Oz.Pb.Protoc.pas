unit Oz.Pb.Protoc;
// Protocol buffer code generator, for Delphi
// Copyright (c) 2020 Tomsk, Marat Shaimardanov

interface

uses
  System.Classes, System.SysUtils, System.IOUtils,
  Oz.Cocor.Lib, Oz.Pb.Options, Oz.Pb.Scanner, Oz.Pb.Parser, Oz.Pb.Tab, Oz.Pb.Gen;

procedure Run;

implementation

procedure Run;
var
  options: TOptions;
  tab: TpbTable;
begin
  options := GetOptions;
  Writeln(options.GetVersion);
  options.ParseCommandLine;
  if (ParamCount = 0) or (options.SrcName = '') then
    options.Help
  else
  begin
    options.srcDir := TPath.GetDirectoryName(options.SrcName);
    tab := TpbTable.Create;
    tab.OpenProto(options.SrcName, False);
    tab.Free;
  end;
end;

end.
