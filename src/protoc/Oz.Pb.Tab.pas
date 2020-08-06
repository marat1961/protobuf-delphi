unit Oz.Pb.Tab;

interface

uses
  System.Classes, System.SysUtils, System.Contnrs, Generics.Collections,
  Oz.Cocor.Lib, pbPublic;

{$SCOPEDENUMS on}

type

  TpbMessage = class;

{$Region 'TStringValue'}

  TStringValue = type string;
  TStringValueHelper = record helper for TStringValue
    function AsFloat: Double;
    function AsInteger: Integer;
    function AsString: string;
    function AsBoolean: Boolean;
  end;

{$EndRegion}

{$Region 'Enums: TSyntaxVersion, TAccessModifier, TPackageKind'}

  // The first line of the file specifies that you're using proto3 syntax:
  // if you don't do this the protocol buffer compiler will assume
  // you are using proto2.
  TSyntaxVersion = (Proto2, Proto3);

  // Access modifier, used for fields
  TAccessModifier = (
    acsPublic,
    acsProtected,
    acsPrivate);

  // Generated package kind
  TPackageKind = (
    pkClass,
    pkRecord,
    pkInterface);

{$EndRegion}

{$Region 'TpbImport: Importing definition'}

  TpbImport = class
  private
    FValue: string;
    FWeak: Boolean;
  public
    // import = "import" [ "weak" | "public" ] strLit ";"
    constructor Create(const Value: string; Weak: Boolean = True);
    property Value: string read FValue;
    property Weak: Boolean read FWeak;
  end;

{$EndRegion}

{$Region 'TIdent: base class for creating all other objects'}

  // Ident mode
  TMode = (
    mUnknown,
    mModule,    // proto file
    mPackage,   // package
    mRecord,    // message
    mEnum,      // enum definition
    mField,     // message field
    mType,      // embedded type
    mConst,     // constant declaration
    mOption);   // option

  TIdent = class
  private
    FName: string;
    FMode: TMode;
    FScope: TIdent;
  protected
    function GenScript: string; virtual;
    constructor Create(Scope: TIdent; const Name: string; Mode: TMode);
  public
    function Dump: string; virtual;
    property Name: string read FName;
    // Type of object
    property Mode: TMode read FMode;
    // The scope where this object can be found.
    property Scope: TIdent read FScope;
  end;

{$EndRegion}

{$Region 'TpbOption: can be used in proto files, messages, enums and services'}

  TpbOption = class(TIdent)
  private
    FValue: TStringValue;
  public
    property Value: TStringValue read FValue;
  end;

{$EndRegion}

{$Region 'TpbPackage: Package specifier to a .proto file'}

  // prevent name clashes between protocol message types
  TpbPackage = class(TIdent)
  private
    FValue: string;
  public
    constructor Create(Scope: TIdent; const Name, Value: string);
    property Value: string read FValue;
  end;

{$EndRegion}

{$Region 'TpbConstant: named integer, float, string or boolean value'}

  TConstantType = (
    cInt = 0,
    cFloat = 1,
    cStr = 2,
    cBool = 3);

  TpbConstant = class(TIdent)
  private
    FValue: TStringValue;
    FTyp: TConstantType;
  public
    constructor Create(const Name: string; Typ: TConstantType; Value: string);
    property Value: TStringValue read FValue;
  end;

{$EndRegion}

{$Region 'TpbType: Base class for all data types'}

  // Type mode
  TTypeMode = (
    tmDouble,   // Double
    tmFloat,    // Single
    tmInt32,    // Integer
    tmInt64,    // Int64
    tmUint32,   // UInt32
    tmUint64,   // UIint64
    tmSint32,   // Integer
    tmSint64,   // Int64
    tmFixed32,  // UInt32
    tmFixed64,  // UInt64
    tmSfixed32, // UInt32
    tmSfixed64, // Int64
    tmBool,     // Boolean
    tmString,   // string
    tmBytes,    // bytes
    tmEnum,     // Integer
    tmRecord,   // Message
    tmMap);     // Map

  TEmbeddedTypes = TTypeMode.tmDouble .. TTypeMode.tmBytes;

  TpbType = class(TIdent)
  private
    FTypeMode: TTypeMode;
    FDesc: string;
  protected
    constructor Create(Scope: TIdent; const Name: string;
      TypeMode: TTypeMode; const Desc: string = '');
  public
    property TypMode: TTypeMode read FTypeMode write FTypeMode;
    property Desc: string read FDesc;
  end;

  TpbEmbeddedType = class(TpbType)
  public
    constructor Create(Scope: TpbMessage; const Name: string;
      TypMode: TEmbeddedTypes);
  end;

{$EndRegion}

{$Region 'TpbField'}

  // Field options kind
  TFieldOptionKind = (foAccess, foPacked, foDeprecated, foTransient,
    foReadOnly, foDefault);

  PFieldOptions = ^TFieldOptions;
  TFieldOptions = record
    Access: TAccessModifier;
    &Packed: Boolean;
    &Deprecated: Boolean;
    ReadOnly: Boolean;
    // Code will not be generated for this field
    Transient: Boolean;
    // The default value for field
    Default: string;
  end;

  // Rules for fields in .proto files
  TFieldRule = (Singular, Optional, Repeated);

  TpbField = class(TIdent)
  private
    FType: TpbType;
    FTag: Integer;
    FRule: TFieldRule;
    FPos: TPosition;
    FOptions: TFieldOptions;
    function GetPos: PPosition;
    function GetOptions: PFieldOptions;
  public
    constructor Create(Scope: TpbMessage; const Name: string; Typ: TpbType;
      Tag: Integer; Rule: TFieldRule);
    // Add field option
    function AddOption(option: TpbOption; fo: TFieldOptionKind): Boolean;
    function ToString: string; override;
    property Typ: TpbType read FType;
    property Tag: Integer read FTag;
    property Rule: TFieldRule read FRule;
    property Pos: PPosition read GetPos;
    property Options: PFieldOptions read GetOptions;
  end;

{$EndRegion}

{$Region 'TpbEnum'}

  // Enum options kind
  TEnumOptionKind = (foNamespace, foAllowAlias);

  PEnumOptions = ^TEnumOptions;
  TEnumOptions = record
    Namespace: string;
    foAllowAlias: Boolean;
  end;

  TEnumValue = record
    Ident: string;
    IntVal: Integer;
    Comment: string;
  end;

  TpbEnum = class(TpbType)
  private
    FEnums: TList<TEnumValue>;
    FOptions: TEnumOptions;
    function GetOptions: PEnumOptions;
  public
    constructor Create(Scope: TpbMessage; const Name: string);
    destructor Destroy; override;
    property Options: PEnumOptions read GetOptions;
  end;

{$EndRegion}

{$Region 'TpbMessage'}

  // —ообщение - единица компил€ции и описани€ модели данных
  TpbMessage = class(TpbType)
  public const
    WireType = TWire.LENGTH_DELIMITED;
  private
    FFields: TList<TpbField>;
    FMessages: TList<TpbMessage>;
    FEnums: TList<TpbEnum>;
    // If all fields are constant then this message is constant too
    function GetWireSize: Integer;
  public
    constructor Create(Scope: TIdent; const Name, Package: string);
    destructor Destroy; override;
    property WireSize: Integer read GetWireSize;
  end;

{$EndRegion}

{$Region 'TpbModule: search tree root'}

  TpbModule = class(TIdent)
  end;

{$EndRegion}

{$Region 'TpbTable: '}

  // Uses the singleton pattern for its creation.
  TpbTable = class(TCocoPart)
  private
    FSyntax: TSyntaxVersion;
    // root node for the .proto file
    FModule: TpbModule;
    // root node for predefined elements
    FSystem: TpbModule;
    function OpenModule(const id: string): TpbMessage;
    function FindImport(const id: string): TpbMessage;
  public
    constructor Create(Parser: TBaseParser);
    destructor Destroy; override;
    function Find(const id: string): TIdent;
    function Import(const id: string): TpbMessage;
    procedure AddPackage(package: TpbPackage);
    procedure AddImport(const import: TpbImport);
    procedure AddOption(const option: TpbOption);
    procedure AddMessage(const msg: TpbMessage);
    function Dump: string;
    function GenScript: string;
    property Syntax: TSyntaxVersion read FSyntax write FSyntax;
    property Module: TpbModule read FModule write FModule;
  end;

{$EndRegion}

function GetWireType(tm: TTypeMode): TWireType;

implementation

function GetWireType(tm: TTypeMode): TWireType;
begin
  case tm of
    // int32, int64, uint32, uint64, sint32, sint64, bool, enum
    TTypeMode.tmInt32, TTypeMode.tmInt64,
    TTypeMode.tmUint32, TTypeMode.tmUint64,
    TTypeMode.tmSint32, TTypeMode.tmSint64,
    TTypeMode.tmBool, TTypeMode.tmEnum:
      Result := TWire.VARINT;
    // fixed64, sfixed64, double
    TTypeMode.tmFixed64, TTypeMode.tmSfixed64, TTypeMode.tmDouble:
      Result := TWire.FIXED64;
    // fixed32, SFixed32, float
    TTypeMode.tmSfixed32, TTypeMode.tmFixed32, TTypeMode.tmFloat:
      Result := TWire.FIXED32;
    // string, bytes, embedded messages, !packed repeated fields
    TTypeMode.tmString, TTypeMode.tmBytes, TTypeMode.tmRecord, TTypeMode.tmMap:
      Result := TWire.LENGTH_DELIMITED;
  end;
end;

{$Region ''}

function TStringValueHelper.AsFloat: Double;
var code: Integer;
begin
  Val(Self, Result, code);
end;

function TStringValueHelper.AsInteger: Integer;
var code: Integer;
begin
  Val(Self, Result, code);
end;

function TStringValueHelper.AsString: string;
begin
  Result := Self;
end;

function TStringValueHelper.AsBoolean: Boolean;
begin
  Result := LowerCase(Self) = 'true';
end;

{$EndRegion}

{$Region 'TpbImport'}

constructor TpbImport.Create(const Value: string; Weak: Boolean);
begin
  inherited Create;
  FValue := Value;
  FWeak := Weak;
end;

{$EndRegion}

{$Region 'TIdent'}

constructor TIdent.Create(Scope: TIdent; const Name: string; Mode: TMode);
begin
  inherited Create;
  FScope := Scope;
  FName := Name;
  FMode := Mode;
end;

function TIdent.GenScript: string;
begin
end;

function TIdent.Dump: string;
begin
end;

{$EndRegion}

{$Region 'TpbPackage'}

constructor TpbPackage.Create(Scope: TIdent; const Name, Value: string);
begin
  inherited Create(Scope, Name, TMode.mPackage);
  FValue := Value;
end;

{$EndRegion}

{$Region 'TpbConstant'}

constructor TpbConstant.Create(const Name: string; Typ: TConstantType; Value: string);
begin

end;

{$EndRegion}

{$Region 'TpbType'}

constructor TpbType.Create(Scope: TIdent; const Name: string;
  TypeMode: TTypeMode; const Desc: string = '');
begin
  inherited Create(Scope, Name, TMode.mType);
  FTypeMode := TypeMode;
  FDesc := Desc;
end;

constructor TpbEmbeddedType.Create(Scope: TpbMessage; const Name: string;
  TypMode: TEmbeddedTypes);
begin
  inherited Create(Scope, Name, TypMode, '');
end;

{$EndRegion}

{$Region 'TpbField'}

constructor TpbField.Create(Scope: TpbMessage; const Name: string; Typ: TpbType;
  Tag: Integer; Rule: TFieldRule);
begin
  inherited Create(Scope, Name, TMode.mField);
  FType := Typ;
  FTag := Tag;
  FRule := Rule;
end;

function TpbField.AddOption(option: TpbOption; fo: TFieldOptionKind): Boolean;
var
  s: string;
begin
  // Field options kind
  case fo of
    TFieldOptionKind.foAccess:
      begin
        s := LowerCase(option.Value);
        if s = 'public' then
          FOptions.Access := TAccessModifier.acsPublic
        else if s = 'protected' then
          FOptions.Access := TAccessModifier.acsProtected
        else if s = 'private' then
          FOptions.Access := TAccessModifier.acsPrivate;
      end;
    TFieldOptionKind.foPacked:
      FOptions.&Packed := option.Value.AsBoolean;
    TFieldOptionKind.foDeprecated:
      FOptions.Deprecated := option.Value.AsBoolean;
    TFieldOptionKind.foTransient:
      FOptions.Transient := option.Value.AsBoolean;
    TFieldOptionKind.foReadOnly:
      FOptions.ReadOnly := option.Value.AsBoolean;
    TFieldOptionKind.foDefault:
      FOptions.Default := option.Value;
  end;
end;

function TpbField.ToString: string;
begin
  Result := Format('%s %s = %d;', [Typ.Name, Name, Tag]);
end;

function TpbField.GetPos: PPosition;
begin
  Result := @FPos;
end;

function TpbField.GetOptions: PFieldOptions;
begin
  Result := @FOptions;
end;

{$EndRegion}

{$Region 'TpbType'}

constructor TpbEnum.Create(Scope: TpbMessage; const Name: string);
begin
  inherited Create(Scope, Name, TTypeMode.tmEnum);
  FEnums := TList<TEnumValue>.Create;
end;

destructor TpbEnum.Destroy;
begin
  FEnums.Free;
  inherited;
end;

function TpbEnum.GetOptions: PEnumOptions;
begin
  Result := @FOptions;
end;

{$EndRegion}

{$Region 'TpbMessage'}

constructor TpbMessage.Create(Scope: TIdent; const Name, Package: string);
begin
  inherited Create(Scope, Name, TTypeMode.tmRecord);
  FFields := TList<TpbField>.Create;
  FMessages := TList<TpbMessage>.Create;
  FEnums := TList<TpbEnum>.Create;
end;

destructor TpbMessage.Destroy;
begin

  inherited;
end;

function TpbMessage.GetWireSize: Integer;
begin

end;

{$EndRegion}

{$Region 'TpbTable'}

constructor TpbTable.Create(Parser: TBaseParser);
begin
  inherited;

end;

destructor TpbTable.Destroy;
begin

  inherited;
end;

function TpbTable.Find(const id: string): TIdent;
begin

end;

procedure TpbTable.AddImport(const import: TpbImport);
begin

end;

procedure TpbTable.AddMessage(const msg: TpbMessage);
begin

end;

procedure TpbTable.AddOption(const option: TpbOption);
begin

end;

procedure TpbTable.AddPackage(package: TpbPackage);
begin

end;

function TpbTable.Dump: string;
begin

end;

function TpbTable.FindImport(const id: string): TpbMessage;
begin

end;

function TpbTable.GenScript: string;
begin

end;

function TpbTable.Import(const id: string): TpbMessage;
begin

end;

function TpbTable.OpenModule(const id: string): TpbMessage;
begin

end;

{$EndRegion}

end.
