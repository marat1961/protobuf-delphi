unit Oz.Pb.Tab;

interface

uses
  System.Classes, System.SysUtils,
//  Generics.Collections,
  Oz.Cocor.Lib, pbPublic;

{$SCOPEDENUMS on}

type

  TpbTable = class;          // Parsing context
  TpbModule = class;         // .proto file
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

{$Region 'TConst: constant identifier, integer, float, string or boolean value'}

  TConstType = (
    cIdent = 0,   // for instance: true, false or null
    cInt = 1,
    cFloat = 2,
    cStr = 3,
    cBool = 4);

  TConst = record
    typ: TConstType;
    sign: Integer;
    value: TStringValue;
    procedure Init(const Value: string; Typ: TConstType);
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

{$Region 'TIdent: base class for creating all other objects'}

  // Ident mode
  TMode = (
    mUnknown,
    mModule,    // proto file
    mPackage,   // package
    mRecord,    // message definition
    mEnum,      // enum definition
    mService,   // service definition
    mRpc,       // service definition
    mOneOf,
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

{$Region 'TIdentList'}

  TIdentList = class
  private
    FList: TList;
    function GetCount: Integer;  inline;
    function Find(const Name: string): TIdent;
    procedure Add(Item: TIdent);
  public
    constructor Create;
    destructor Destroy; override;
    property Count: Integer read GetCount;
  end;

  TIdents<T: TIdent> = class(TIdentList)
  private
    function GetItem(Index: Integer): T;
  public
    function Find(const Name: string): T; inline;
    procedure Add(Item: T); inline;
    property Items[Index: Integer]: T read GetItem; default;
  end;

{$EndRegion}

{$Region 'TpbOption: can be used in proto files, messages, enums and services'}

  TpbOption = class(TIdent)
  private
    FCval: TConst;
  public
    constructor Create(Scope: TIdent; const Name: string; const Value: TConst);
    property Value: TStringValue read FCval.Value;
    property Typ: TConstType read FCval.Typ;
  end;

{$EndRegion}

{$Region 'TpbPackage: Package specifier'}

(*  Package Definition
    ------------------
    Within a single module, the Package Definition may occur from 0 to n.
    Some names of declarations may coincide in different modules.
    In principle, the names of declarations can coincide even within a single file.
    No one prohibits using the same name in nested messages.

    You can distinguish two different definitions by using a composite name
    (package name + definition name).
    By default, the package name is empty.

    Interpretation of the package value
    -----------------------------------
    The package definition can be placed several times anywhere in the module.
    If a package definition is encountered, the current package will be added
    when parsing the declaration. This is a side effect.
    Package is placed in each declared entity of the top-level module
    (message, enumerated type or service).
    All this means that there are two types of access to declarations in the module:
     - by short name;
     - by a composite name. *)
  TpbPackage = class(TIdent)
  private
    FModule: TpbModule;
  public
    constructor Create(Scope: TpbModule; const Name: string);
    property Module: TpbModule read FModule;
  end;

{$EndRegion}

{$Region 'TpbService'}

  TpbService = class(TIdent)
  private
    FModule: TpbModule;
  public
    constructor Create(Scope: TpbModule; const Name: string);
    property Module: TpbModule read FModule;
  end;

{$EndRegion}

{$Region 'TpbRpc'}

  TpbRpc = class(TIdent)
  private
    FService: TpbService;
  public
    constructor Create(Scope: TpbService; const Name: string);
    property Service: TpbService read FService;
  end;

{$EndRegion}

{$Region 'TPbOneOf'}

  TPbOneOf = class(TIdent)
  private
    FMsg: TpbMessage;
  public
    constructor Create(Scope: TpbMessage; const Name: string);
    property Msg: TpbMessage read FMsg;
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

  TEnumValue = class(TIdent)
  public
    IntVal: Integer;
    Comment: string;
  end;

  TpbEnum = class(TpbType)
  private
    FEnums: TIdents<TEnumValue>;
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
    FFields: TIdents<TpbField>;
    FMessages: TIdents<TpbMessage>;
    FEnums: TIdents<TpbEnum>;
    // If all fields are constant then this message is constant too
    function GetWireSize: Integer;
  public
    constructor Create(Scope: TIdent; const Name, Package: string);
    destructor Destroy; override;
    property WireSize: Integer read GetWireSize;
  end;

{$EndRegion}

{$Region 'TpbModule: translation unit'}

  // Importing definition
  // import = "import" [ "weak" | "public" ] strLit ";"
  TpbModule = class(TIdent)
  private
    FTab: TpbTable;
    FWeak: Boolean;
    FSyntax: TSyntaxVersion;
    FImport: TIdents<TpbModule>;
    FOptions: TIdents<TpbOption>;
    FCurrentPackage: string;
    FPackages: TIdents<TpbPackage>;
    FTypes: TIdents<TpbType>;
    // Search the module recursively
    function FindImport(const Name: string): TpbModule;
    function FindType(const Name: string): TpbType;
  protected
    constructor Create(Tab: TpbTable; Scope: TIdent; const Name: string; Weak: Boolean);
  public
    destructor Destroy; override;
    // Search the module recursively and if not found then open the file
    function LookupImport(const Name: string; Weak: Boolean): TpbModule;
    // Search by name recursively
    function Find(const Name: string): TIdent;
    // Add package and update its current value
    function AddPackage(const Name: string): TpbPackage;
    // Add module option
    function AddOption(const Name: string; const Value: TConst): TpbOption;
    // Properties
    property Weak: Boolean read FWeak;
    property Syntax: TSyntaxVersion read FSyntax write FSyntax;
    property Import: TIdents<TpbModule> read FImport;
    property Options: TIdents<TpbOption> read FOptions;
    property Packages: TIdents<TpbPackage> read FPackages;
    property CurrentPackage: string read FCurrentPackage;
    property Types: TIdents<TpbType> read FTypes;
  end;

{$EndRegion}

{$Region 'TpbTable: '}

  // Uses the singleton pattern for its creation.
  TpbTable = class(TCocoPart)
  private
    // root node for the .proto file
    FModule: TpbModule;
    // root node for predefined elements
    FSystem: TpbModule;
    function FindImport(const id: string): TpbMessage;
    // Fill predefined elements
    procedure InitSystem;
  public
    constructor Create(Parser: TBaseParser);
    destructor Destroy; override;
    // Search object by id
    function Find(const id: string): TIdent;
    // Open and read module from file
    function OpenModule(Scope: TpbModule; const Name: string; Weak: Boolean): TpbModule;
    function Dump: string;
    function GenScript: string;
    property Module: TpbModule read FModule write FModule;
  end;

{$EndRegion}

function GetWireType(tm: TTypeMode): TWireType;

implementation

function GetWireType(tm: TTypeMode): TWireType;
begin
  case tm of
    TTypeMode.tmInt32, TTypeMode.tmInt64,
    TTypeMode.tmUint32, TTypeMode.tmUint64,
    TTypeMode.tmSint32, TTypeMode.tmSint64,
    TTypeMode.tmBool, TTypeMode.tmEnum:
      Result := TWire.VARINT;
    TTypeMode.tmFixed64, TTypeMode.tmSfixed64, TTypeMode.tmDouble:
      Result := TWire.FIXED64;
    TTypeMode.tmSfixed32, TTypeMode.tmFixed32, TTypeMode.tmFloat:
      Result := TWire.FIXED32;
    // string, bytes, embedded messages, !packed repeated fields
    TTypeMode.tmString, TTypeMode.tmBytes, TTypeMode.tmRecord, TTypeMode.tmMap:
      Result := TWire.LENGTH_DELIMITED;
  end;
end;

{$Region 'TStringValueHelper'}

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

{$Region 'TConst'}

procedure TConst.Init(const Value: string; Typ: TConstType);
begin
  sign := 1;
  Self.value := Value;
  Self.typ := Typ;
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

{$Region 'TIdentList<T: TIdent>'}

constructor TIdentList.Create;
begin
  inherited;
  FList := TList.Create;
end;

destructor TIdentList.Destroy;
begin
  FList.Free;
  inherited;
end;

procedure TIdentList.Add(Item: TIdent);
begin
  FList.Add(Item);
end;

function TIdentList.GetCount: Integer;
begin
  Result := FList.Count;
end;

function TIdentList.Find(const Name: string): TIdent;
var
  i: Integer;
begin
  for i := 0 to FList.Count - 1 do
  begin
    Result := TIdent(FList.Items[i]);
    if Result.Name = Name then exit;
  end;
  Result := nil;
end;

function TIdents<T>.Find(const Name: string): T;
begin
  Result := T(inherited Find(Name));
end;

procedure TIdents<T>.Add(Item: T);
begin
  inherited Add(Item);
end;

function TIdents<T>.GetItem(Index: Integer): T;
begin
  Result := T(FList.Items[Index]);
end;

{$EndRegion}

{$Region 'TpbOption'}

constructor TpbOption.Create(Scope: TIdent; const Name: string; const Value: TConst);
begin
  inherited Create(Scope, Name, TMode.mOption);
  Self.FCval := Value;
end;

{$EndRegion}

{$Region 'TpbPackage'}

constructor TpbPackage.Create(Scope: TpbModule; const Name: string);
begin
  inherited Create(Scope, Name, TMode.mPackage);
end;

{$EndRegion}

{$Region 'TpbPackage'}

constructor TpbService.Create(Scope: TpbModule; const Name: string);
begin
  inherited Create(Scope, Name, TMode.mService);
end;

{$EndRegion}

{$Region 'TpbRpc'}

constructor TpbRpc.Create(Scope: TpbService; const Name: string);
begin
  inherited Create(Scope, Name, TMode.mRpc);
end;

{$EndRegion}

{$Region 'TpbRpc'}

constructor TPbOneOf.Create(Scope: TpbMessage; const Name: string);
begin
  inherited Create(Scope, Name, TMode.mOneOf);
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
  FEnums := TIdents<TEnumValue>.Create;
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
  FFields := TIdents<TpbField>.Create;
  FMessages := TIdents<TpbMessage>.Create;
  FEnums := TIdents<TpbEnum>.Create;
end;

destructor TpbMessage.Destroy;
begin
  FFields.Free;
  FMessages.Free;
  FEnums.Free;
  inherited;
end;

function TpbMessage.GetWireSize: Integer;
begin
  case WireType of
    TWire.FIXED64:
      Result := 8;
    TWire.Fixed32:
      Result := 4;
    else Result := -1;
  end;
end;

{$EndRegion}

{$Region 'TpbModule'}

constructor TpbModule.Create(Tab: TpbTable; Scope: TIdent; const Name: string;
  Weak: Boolean);
begin
  inherited Create(Scope, Name, TMode.mModule);
  FImport := TIdents<TpbModule>.Create;
  FPackages := TIdents<TpbPackage>.Create;
  FTypes := TIdents<TpbType>.Create;
end;

destructor TpbModule.Destroy;
begin
  FImport.Free;
  FPackages.Free;
  FTypes.Free;
  inherited;
end;

function TpbModule.LookupImport(const Name: string; Weak: Boolean): TpbModule;
begin
  // If the module has already been read and is in memory,
  // then do not read it again
  Result := FindImport(Name);
  if Result = nil then
    Result := FTab.OpenModule(Self, Name, Weak);
end;

function TpbModule.Find(const Name: string): TIdent;
begin
  Result := FindImport(Name);
  if Result <> nil then exit;
  Result := FindType(Name);
end;

function TpbModule.AddPackage(const Name: string): TpbPackage;
begin
  Result := TpbPackage.Create(Self, Name);
  FCurrentPackage := FCurrentPackage;
end;

function TpbModule.AddOption(const Name: string; const Value: TConst): TpbOption;
begin
  Result := TpbOption.Create(Scope, Name, Value);
end;

function TpbModule.FindImport(const Name: string): TpbModule;
var
  i: Integer;
begin
  Result := FImport.Find(Name);
  if Result <> nil then exit;
  for i := 0 to FImport.Count - 1 do
  begin
    Result := FImport[i].FindImport(Name);
    if Result <> nil then exit;
  end;
end;

function TpbModule.FindType(const Name: string): TpbType;
var
  i: Integer;
begin
  for i := 0 to FTypes.Count - 1 do
  begin
    Result := FTypes.Items[i];
    if Result.Name = Name then exit;
  end;
end;

{$EndRegion}

{$Region 'TpbTable'}

constructor TpbTable.Create(Parser: TBaseParser);
begin
  inherited;
  FModule := TpbModule.Create(Self, nil, 'import', {weak=}True);
  FSystem := TpbModule.Create(Self, nil, 'System', {weak=}False);
end;

destructor TpbTable.Destroy;
begin
  FModule.Free;
  FSystem.Free;
  inherited;
end;

procedure TpbTable.InitSystem;
begin

end;

function TpbTable.Find(const id: string): TIdent;
begin
  Result := FSystem.Find(id);
  if Result = nil then
    Result := FModule.Find(id);
end;

function TpbTable.OpenModule(Scope: TpbModule; const Name: string;
  Weak: Boolean): TpbModule;
begin
  Result := TpbModule.Create(Self, Scope, Name, Weak);
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

{$EndRegion}

end.
