unit TestMapSGL;

interface

uses
  System.SysUtils, System.TypInfo, Oz.Pb.StrBuffer, Oz.Pb.Classes, MapSGL;

{$T+}

procedure RunTest;

implementation

// generate data
procedure GenData(var Map: TMapFields);
begin
end;

// save data to proto file
procedure SaveData(var Map: TMapFields);
var
  Saver: TpbSaver;
begin
  // save data
  Saver.Init;
  try
    TpbSaver.SaveMapFields(Saver, Map);
    Saver.Pb.SaveToFile('map.pb');
  finally
    Saver.Free;
  end;
end;

procedure ReadDataAndDump;
var
  Map: TMapFields;
  Loader: TpbLoader;
  i: Integer;
begin
  Loader.Init;
  try
    Loader.Pb.LoadFromFile('map.pb');
    try
      Loader.LoadMapFields(Map);
      Readln;
    finally
      Map.Free;
    end;
  finally
    Loader.Free;
  end;
end;

procedure TestMap;
var
  Map: TMapFields;
begin
  Map.Init;
  try
    Writeln('Run Protocol Buffer Tests');
    GenData(Map);
    SaveData(Map);
  finally
    Map.Free;
  end;
  ReadDataAndDump;
end;

procedure RunTest;
begin

end;

end.
