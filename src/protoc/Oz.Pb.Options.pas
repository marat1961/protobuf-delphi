unit Oz.Pb.Options;

interface

uses
  System.SysUtils, System.Classes;

type

{$Region 'TOptions: Compilation settings'}

  TOptions = class
  const
    Version = '1.0 (for Delphi)';
    ReleaseDate = '11 August 2020';
  private
    FSrcName: string;
    FSrcDir: string;
    FOutPath: string;
    FListing: TStrings;
  public
    constructor Create;
    function GetVersion: string;
    procedure Help;
    property Listing: TStrings read FListing write FListing;
    // Get options from the command line
    procedure ParseCommandLine;
    // Set option
    procedure SetOption(const s: string);
    // Name of the proto file (including path)
    property SrcName: string read FSrcName;
    // Specify the directory in which to search for imports.
    // May be specified multiple times; directories will be searched in order.
    // If not given, the current working directory is used.
    property SrcDir: string read FSrcDir write FSrcDir;
    // Path for generated delphi files
    property OutPath: string read FOutPath write FOutPath;
  end;

{$EndRegion}

// Return current settings (sigleton)
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

procedure FreeOptions;
begin
  FreeAndNil(FOptions);
end;

{$Region 'TOptions'}

constructor TOptions.Create;
begin

end;

function TOptions.GetVersion: string;
begin
  Result := Format(
    'Protoc - Protocîl buffer code generator, V%s'#13#10 +
    'Delphi version by Marat Shaimardanov %s'#13#10,
    [Version, ReleaseDate]);
end;

procedure TOptions.Help;
begin
  WriteLn('Usage: Protoc file.proto {Option}');
  WriteLn('Options:');
  WriteLn('  -proto <protoFilesDirectory>');
  WriteLn('  -o     <outputDirectory>');
end;

procedure TOptions.ParseCommandLine;
var
  i: Integer;
  p: string;

  function GetParam: Boolean;
  begin
    Result := i < ParamCount;
    if Result then
    begin
      Inc(i);
      p := ParamStr(i).Trim;
    end;
  end;

begin
  i := 0;
  while GetParam do
  begin
    if (p = '-proto') and GetParam then
      FSrcDir := p
    else if (p = '-o') and GetParam then
      FOutPath := p
    else
      FSrcName := p;
  end;
  if FOutPath = '' then
    FOutPath := FSrcDir;
end;

procedure TOptions.SetOption(const s: string);
var
  name, value: string;
  option: TArray<string>;
begin
  option := s.Split(['=', ' '], 2);
  name := option[0];
  value := option[1];
end;

{$EndRegion}

initialization

finalization
  FreeOptions;

end.
