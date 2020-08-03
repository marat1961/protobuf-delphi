unit Oz.Pb.Options;

interface

uses
  System.SysUtils, System.Classes;

type

  // Настройки компиляции
  TOptions = class
  private
    FProtoPath: string;
    FOutPath: string;
    FListing: TStrings;
  public
    property Listing: TStrings read FListing write FListing;
    // Specify the directory in which to search for imports.
    // May be specified multiple times; directories will be searched in order.
    // If not given, the current working directory is used.
    property ProtoPath: string read FProtoPath write FProtoPath;
    // Path for generated delphi files
    property OutPath: string read FOutPath write FOutPath;
  end;

// sigleton для доступа к текущим параметрам компиляции
function GetOptions: TOptions;

implementation

var
  FOptions: TOptions = nil;

function GetOptions: TOptions;
begin
  if FOptions = nil then
    FOptions := TOptions.Create;
  result := FOptions;
end;

end.
