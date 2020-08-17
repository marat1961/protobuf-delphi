unit Oz.Pb.Tab;

interface

uses
  System.Classes, System.SysUtils, System.Rtti,
  Oz.Cocor.Utils, Oz.Cocor.Lib, pbPublic;

{$SCOPEDENUMS on}

{$Region 'Forward declarations'}

type

  TpbTable = class;          // Parsing context
  TpbModule = class;         // .proto file
  TpbMessage = class;
  TpbOption = class;
  TpbService = class;
  TpbPackage = class;
  Tem = class;

{$EndRegion}

{$Region 'TConst: constant identifier, integer, float, string or boolean value'}

  TConstType = (
    cIdent = 0,   // for instance: true, false or null
    cInt = 1,
    cFloat = 2,
    cStr = 3,
    cBool = 4);

  TConst = record
  var
    typ: TConstType;
    val: TValue;
  public
    procedure AsIdent(const Value: string);
    procedure AsInt(const Value: Integer);
    procedure AsFloat(const Value: Double);
    procedure AsStr(const Value: string);
    function AsBool(const Value: string): Boolean;
  end;

{$EndRegion}

{$Region 'TUserType: messageType or enumType'}

  TUserType = record
    OutermostScope: Boolean;
    Package: string;
    Name: string;
  end;

{$EndRegion}

{$Region 'TSyntaxVersion, TAccessModifier, TPackageKind'}

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
    mEnumValue, // enum value
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
    function GetEm: Tem;
  protected
    function GenScript: string; virtual;
    constructor Create(Scope: TIdent; const Name: string; Mode: TMode);
  public
    function Dump: string; virtual;
    function AddOption(const Name: string; const Value: TConst): TpbOption; virtual;
    property Name: string read FName;
    // Type of object
    property Mode: TMode read FMode;
    // The scope where this object can be found.
    property Scope: TIdent read FScope;
    property em: Tem read GetEm;
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

  PFieldOptions = ^TFieldOptions;
  TFieldOptions = record
  type
    TOptionKind = (
      foDefault, foMapType, foPacked, foAccess, foDeprecated, foTransient, foReadOnly);
  const
    KindNames: array [TOptionKind] of string = (
      'default', 'mapType', 'packed', 'access', 'deprecated', 'transient', 'readonly');
  var
    Access: TAccessModifier;
    &Packed: Boolean;
    &Deprecated: Boolean;
    ReadOnly: Boolean;
    // Code will not be generated for this field
    Transient: Boolean;
    // Map type name or empty for anonymous type
    MapType: string;
    // The default value for field
    Default: string;
  end;

  TpbOption = class(TIdent)
  private
    FCval: TConst;
  public
    constructor Create(Scope: TIdent; const Name: string; const Value: TConst);
    property Value: TValue read FCval.val;
    property Typ: TConstType read FCval.typ;
  end;

{$EndRegion}

{$Region 'TpbType: Base class for all data types'}

  // Field type mode
  TTypeMode = (
    tmUnknown,  // Unknown
    // Embedded types
    tmDouble,   // Double
    tmFloat,    // Single
    tmInt64,    // Int64
    tmUint64,   // UIint64
    tmInt32,    // Integer
    tmFixed64,  // UInt64
    tmFixed32,  // UInt32
    tmBool,     // Boolean
    tmString,   // string
    tmBytes,    // bytes
    tmUint32,   // UInt32
    tmSfixed32, // UInt32
    tmSfixed64, // Int64
    tmSint32,   // Integer
    tmSint64,   // Int64
    // Proto2 syntax only, and deprecated.
    tmGroup,    // Field type group.
    // User defined types
    tmEnum,     // Integer
    tmMessage,  // message
    tmMap);     // Map

  TEmbeddedTypes = TTypeMode.tmDouble .. TTypeMode.tmSint64;

  TpbType = class(TIdent)
  private
    FTypeMode: TTypeMode;
    FDesc: string;
  protected
    constructor Create(Scope: TIdent; const Name: string;
      TypeMode: TTypeMode; const Desc: string = '');
  public
    // Get delphi name
    function DelphiName: string; virtual; abstract;
    property TypMode: TTypeMode read FTypeMode write FTypeMode;
    property Desc: string read FDesc;
  end;

  TpbEmbeddedType = class(TpbType)
  public
    constructor Create(Scope: TpbModule; TypMode: TEmbeddedTypes);
    // Get delphi name
    function DelphiName: string; override;
  end;

  TpbUnknownType = class(TpbType)
  private
    FTyp: TUserType;
  public
    constructor Create(Scope: TIdent; Typ: TUserType);
    // Get delphi name
    function DelphiName: string; override;
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
    FTypes: TIdents<TpbType>;
  public
    constructor Create(Scope: TpbModule; const Name: string);
    property Module: TpbModule read FModule;
    property Types: TIdents<TpbType> read FTypes;
  end;

{$EndRegion}

{$Region 'TpbField'}

  // Rules for fields in .proto files
  TFieldRule = (Singular, Optional, Repeated);

  TpbField = class(TIdent)
  private
    FType: TpbType;
    FTag: Integer;
    FRule: TFieldRule;
    FPos: TPosition;
    FOptions: TFieldOptions;
    function GetMsg: TpbMessage;
    function GetPos: PPosition;
    function GetOptions: PFieldOptions;
  public
    constructor Create(Scope: TpbMessage; const Name: string; Typ: TpbType;
      Tag: Integer; Rule: TFieldRule);
    function AddOption(const Name: string; const Value: TConst): TpbOption; override;
    function ToString: string; override;
    property Msg: TpbMessage read GetMsg;
    property Typ: TpbType read FType;
    property Tag: Integer read FTag;
    property Rule: TFieldRule read FRule;
    property Pos: PPosition read GetPos;
    property Options: PFieldOptions read GetOptions;
  end;

{$EndRegion}

{$Region 'TPbOneOf'}

  TPbOneOf = class(TIdent)
  private
    FMsg: TpbMessage;
    FVariantFields: TIdents<TpbField>;
  public
    constructor Create(Scope: TpbMessage; const Name: string);
    destructor Destroy; override;
    // Add variant field
    function AddField(const Name: string; Typ: TpbType; Tag: Integer): TpbField;
    property Msg: TpbMessage read FMsg;
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
  private
    FIntVal: Integer;
    FComment: string;
  public
    constructor Create(Scope: TIdent; const Name: string; IntVal: Integer);
    property IntVal: Integer read FIntVal;
    property Comment: string read FComment write FComment;
  end;

  TpbEnum = class(TpbType)
  private
    FPackage: TpbPackage;
    FEnums: TIdents<TEnumValue>;
    FOptions: TEnumOptions;
    function GetOptions: PEnumOptions;
  public
    constructor Create(Scope: TIdent; const Name: string; Package: TpbPackage);
    destructor Destroy; override;
    // Get delphi name
    function DelphiName: string; override;
    property EnumValues: TIdents<TEnumValue> read FEnums;
    property Options: PEnumOptions read GetOptions;
  end;

{$EndRegion}

{$Region 'TpbMapType'}

  TpbMapType = class(TpbType)
  private
    FPackage: TpbPackage;
    FKey: TpbType;
    FValue: TpbType;
    function GetModule: TpbModule;
  public
    constructor Create(Scope: TpbModule; const Name: string; Key, Value: TpbType);
    property Module: TpbModule read GetModule;
    // Get delphi name
    function DelphiName: string; override;
    property Key: TpbType read FKey;
    property Value: TpbType read FValue;
  end;

{$EndRegion}

{$Region 'TpbMessage'}

  TpbMessage = class(TpbType)
  public const
    WireType = TWire.LENGTH_DELIMITED;
  private
    FPackage: TpbPackage;
    FFields: TIdents<TpbField>;
    FOneOfs: TIdents<TPbOneOf>;
    Fem: Tem;
    FReserved: TIntSet;
    function GetWireSize: Integer;
  public
    constructor Create(Tab: TpbTable; Scope: TIdent;
      const Name: string; Package: TpbPackage);
    destructor Destroy; override;
    // Find message or enum type
    function FindUserType(const Typ: TUserType; Recursive: Boolean): TpbType;
    // Add Oneof to message
    function AddOneOf(const Name: string): TPbOneOf;
    // Get delphi name
    function DelphiName: string; override;
    // Reserved Fields
    property Reserved: TIntSet read FReserved;
    // Enum & message list
    property em: Tem read Fem;
    // Message fields
    property Fields: TIdents<TpbField> read FFields;
    // If all fields are constant then this message is constant too
    property WireSize: Integer read GetWireSize;
  end;

{$EndRegion}

{$Region 'Tem: Enum & message list '}

  Tem = class
  private
    FTab: TpbTable;
    FScope: TIdent;
    FMessages: TIdents<TpbMessage>;
    FEnums: TIdents<TpbEnum>;
  public
    constructor Create(Tab: TpbTable; Scope: TIdent);
    destructor Destroy; override;
    // Add message to module or meassge
    function AddMessage(Scope: TIdent; const Name: string): TpbMessage;
    // Add enum to module or meassge
    function AddEnum(Scope: TIdent; const Name: string): TpbEnum;
    // Add field to message
    function AddField(Scope: TpbMessage; const Name: string; Typ: TpbType;
      Tag: Integer; Rule: TFieldRule): TpbField;
    // Find message type for Rpc declaration
    function FindMessageType(Rpc: TIdent; Typ: TUserType): TpbType;
    // properties
    property Messages: TIdents<TpbMessage> read FMessages;
    property Enums: TIdents<TpbEnum> read FEnums;
  end;

{$EndRegion}

{$Region 'TpbRpc'}

  TpbRpc = class(TIdent)
  private
    FService: TpbService;
    FRequest: TpbType;
    FResponse: TpbType;
  public
    constructor Create(Scope: TpbService; const Name: string);
    function AddOption(const Name: string; const Value: TConst): TpbOption; override;
    property Service: TpbService read FService;
    property Request: TpbType read FRequest write FRequest;
    property Response: TpbType read FResponse write FResponse;
  end;

{$EndRegion}

{$Region 'TpbService'}

  TpbService = class(TIdent)
  private
    FModule: TpbModule;
    FRpcSystem: TIdents<TpbRpc>;
  public
    constructor Create(Scope: TpbModule; const Name: string);
    // Add Rpc (Remote procedure call) to service
    function AddRpc(const Name: string): TpbRpc;
    property Module: TpbModule read FModule;
    // Remote procedure ñall system
    property RpcSystem: TIdents<TpbRpc> read FRpcSystem;
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
    FCurrentPackage: TpbPackage;
    FPackages: TIdents<TpbPackage>;
    Fem: Tem;
    FMapTypes: TIdents<TpbMapType>;
    FServices: TIdents<TpbService>;
    // Search the module recursively
    function FindImport(const Name: string): TpbModule;
    function GetNameSpace: string;
  protected
    constructor Create(Tab: TpbTable; Scope: TIdent; const Name: string; Weak: Boolean);
  public
    destructor Destroy; override;
    // Search the module recursively and if not found then open the file
    function LookupImport(const Name: string; Weak: Boolean): TpbModule;
    // Search by map type name or the anonymous pair <KeyTyp, FieldType>
    // and if not found then create it
    function LookupMapType(const Name: string; Key, Value: TpbType): TpbMapType;
    // Add package and update its current value
    function AddPackage(const Name: string): TpbPackage;
    // Add module option
    function AddOption(const Name: string; const Value: TConst): TpbOption; override;
    // Find message or enum type
    function FindUserType(const Typ: TUserType; Recursive: Boolean): TpbType;
    // Properties
    property Weak: Boolean read FWeak;
    property Syntax: TSyntaxVersion read FSyntax write FSyntax;
    property Import: TIdents<TpbModule> read FImport;
    property Options: TIdents<TpbOption> read FOptions;
    property Packages: TIdents<TpbPackage> read FPackages;
    property MapTypes: TIdents<TpbMapType> read FMapTypes;
    property CurrentPackage: TpbPackage read FCurrentPackage;
    property NameSpace: string read GetNameSpace;
    // Declared enumerates and messages
    property Em: Tem read FEM;
    // Declared service
    property Services: TIdents<TpbService> read FServices;
  end;

{$EndRegion}

{$Region 'TpbTable: '}

  // Uses the singleton pattern for its creation.
  TpbTable = class(TCocoPart)
  private
    FEmbeddedTypes: array [TTypeMode.tmDouble .. TTypeMode.tmSint64] of TpbEmbeddedType;
    // root node for the .proto file
    FModule: TpbModule;
    // root node for predefined elements
    FSystem: TpbModule;
    // Unknown types
    FUnknownTypes: TIdents<TpbType>;
    // Fill predefined elements
    procedure InitSystem;
  public
    constructor Create(Parser: TBaseParser);
    destructor Destroy; override;
    // Get embedded type by kind
    function GetBasisType(kind: TTypeMode): TpbEmbeddedType;
    // Àdd stub type tmUnknown
    function AddUnknown(Scope: TIdent; Typ: TUserType): TpbType;
    // Open and read module from file
    function OpenModule(Scope: TpbModule; const Name: string; Weak: Boolean): TpbModule;
    // Convert string to Integer
    function ParseInt(const s: string; base: Integer): Integer;
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
    TTypeMode.tmString, TTypeMode.tmBytes, TTypeMode.tmMessage, TTypeMode.tmMap:
      Result := TWire.LENGTH_DELIMITED;
    else
      Result := TWire.LENGTH_DELIMITED;
  end;
end;

{$Region 'TConst'}

procedure TConst.AsIdent(const Value: string);
begin
  val := Value;
  typ := TConstType.cIdent;
end;

procedure TConst.AsInt(const Value: Integer);
begin
  val := Value;
  typ := TConstType.cInt;
end;

procedure TConst.AsFloat(const Value: Double);
begin
  val := Value;
  typ := TConstType.cFloat;
end;

procedure TConst.AsStr(const Value: string);
begin
  val := Value;
  typ := TConstType.cStr;
end;

function TConst.AsBool(const Value: string): Boolean;
var
  s: string;
begin
  s := LowerCase(Value);
  Result := True;
  if s = 'false' then
    val := False
  else if s = 'true' then
    val := True
  else
    Result := False;
  typ := TConstType.cBool;
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

function TIdent.GetEm: Tem;
begin
  case Mode of
    TMode.mModule: Result := TpbModule(Self).Em;
    TMode.mRecord: Result := TpbMessage(Self).Em;
    else raise FatalError.Create('Message: invalid scope');
  end;
end;

function TIdent.Dump: string;
begin
end;

function TIdent.AddOption(const Name: string; const Value: TConst): TpbOption;
begin
  Result := nil;
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

{$Region 'TpbType'}

constructor TpbType.Create(Scope: TIdent; const Name: string;
  TypeMode: TTypeMode; const Desc: string = '');
var
  m: TMode;
begin
  case TypeMode of
    TTypeMode.tmMessage: m := TMode.mRecord;
    TTypeMode.tmEnum: m := TMode.mEnum;
    else m := TMode.mType;
  end;
  inherited Create(Scope, Name, m);
  FTypeMode := TypeMode;
  FDesc := Desc;
end;

{$EndRegion}

{$Region 'TpbEmbeddedType'}

constructor TpbEmbeddedType.Create(Scope: TpbModule; TypMode: TEmbeddedTypes);
const
  Names: array [TEmbeddedTypes] of string = (
    'double', 'float', 'int64', 'uint64', 'int32',
    'fixed64', 'fixed32', 'bool', 'string', 'bytes',
    'uint32', 'sfixed32', 'sfixed64', 'sint32', 'sint64');
begin
  inherited Create(Scope, Names[TypMode], TypMode, '');
end;

function TpbEmbeddedType.DelphiName: string;
const
  Names: array [TEmbeddedTypes] of string = (
    'Double', 'Single', 'Int64', 'UIint64', 'Integer',
    'UInt64', 'UInt32', 'Boolean', 'string', 'bytes',
    'UInt32', 'UInt32', 'Int64', 'Integer', 'Int64');
begin
  Result := Names[TypMode];
end;

{$EndRegion}

{$Region 'TpbUnknownType'}

constructor TpbUnknownType.Create(Scope: TIdent; Typ: TUserType);
begin
  inherited Create(Scope, Typ.Name, TTypeMode.tmUnknown, '');
  FTyp := Typ;
end;

function TpbUnknownType.DelphiName: string;
begin
  Result := AsCamel(Name);
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

function TpbField.AddOption(const Name: string; const Value: TConst): TpbOption;
begin
  Result := nil;
end;

function TpbField.ToString: string;
begin
  Result := Format('%s %s = %d;', [Typ.Name, Name, Tag]);
end;

function TpbField.GetMsg: TpbMessage;
begin
  Result := TpbMessage(Scope);
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

{$Region 'TPbOneOf'}

constructor TPbOneOf.Create(Scope: TpbMessage; const Name: string);
begin
  inherited Create(Scope, Name, TMode.mOneOf);
  FVariantFields := TIdents<TpbField>.Create;
end;

destructor TPbOneOf.Destroy;
begin
  FVariantFields.Free;
  inherited;
end;

function TPbOneOf.AddField(const Name: string; Typ: TpbType; Tag: Integer): TpbField;
begin
  Result := TpbField.Create(Msg, Name, Typ, Tag, TFieldRule.Singular);
  FVariantFields.Add(Result);
end;

{$EndRegion}

{$Region 'TEnumValue'}

constructor TEnumValue.Create(Scope: TIdent; const Name: string; IntVal: Integer);
begin
  inherited Create(Scope, Name, TMode.mEnumValue);
  FIntVal := IntVal;
end;

{$EndRegion}

{$Region 'TpbType'}

constructor TpbEnum.Create(Scope: TIdent; const Name: string; Package: TpbPackage);
begin
  inherited Create(Scope, Name, TTypeMode.tmEnum);
  FEnums := TIdents<TEnumValue>.Create;
  FPackage := Package;
  if FPackage <> nil then
    FPackage.FTypes.Add(Self);
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

function TpbEnum.DelphiName: string;
begin
  Result := AsCamel(Name);
end;

{$EndRegion}

{$Region 'TpbMapType'}

constructor TpbMapType.Create(Scope: TpbModule; const Name: string;
  Key, Value: TpbType);
begin
  inherited Create(Scope, Name, TTypeMode.tmMap);
  FKey := Key;
  FValue := Value;
  FPackage := Scope.CurrentPackage;
  if FPackage <> nil then
    FPackage.FTypes.Add(Self);
end;

function TpbMapType.DelphiName: string;
begin
  Result := AsCamel(Name);
end;

function TpbMapType.GetModule: TpbModule;
begin
  Result := TpbModule(Scope);
end;

{$EndRegion}

{$Region 'TpbMessage'}

constructor TpbMessage.Create(Tab: TpbTable; Scope: TIdent;
  const Name: string; Package: TpbPackage);
begin
  inherited Create(Scope, Name, TTypeMode.tmMessage);
  FFields := TIdents<TpbField>.Create;
  Fem := Tem.Create(Tab, Self);
  FPackage := Package;
  if Package <> nil then
    Package.FTypes.Add(Self);
end;

destructor TpbMessage.Destroy;
begin
  FFields.Free;
  Fem.Free;
  inherited;
end;

type
  TFinder = record
  var
    Typ: TUserType;
    Recursive: Boolean;
  public
    function FindInEm(em: Tem): TpbType;
    function FindInMessage(msg: TpbMessage): TpbType;
    function FindInModule(module: TpbModule): TpbType;
  end;

function TFinder.FindInEm(em: Tem): TpbType;
var i: Integer;
begin
  // search in enumerations
  Result := em.Enums.Find(Typ.Name);
  if Result <> nil then exit;
  // search in messages
  Result := em.Messages.Find(Typ.Name);
  if (Result <> nil) or not Recursive then exit;
  // search recursive in messages
  for i := 0 to em.Messages.Count - 1 do
  begin
    Result := FindInMessage(em.Messages[i]);
    if Result <> nil then exit;
  end;
  Result := FindInEm(em.FTab.FModule.Em);
end;

function TFinder.FindInModule(module: TpbModule): TpbType;
var Package: TpbPackage;
begin
  if Typ.Package = '' then
    Result := FindInEm(module.em)
  else
  begin
    Package := module.Packages.Find(Typ.Package);
    Result := Package.Types.Find(Typ.Name);
  end;
end;

function TFinder.FindInMessage(msg: TpbMessage): TpbType;
begin
  if Typ.Name = msg.Name then
    Result := msg
  else
    Result := FindInEm(msg.em);
end;

function TpbMessage.FindUserType(const Typ: TUserType; Recursive: Boolean): TpbType;
var F: TFinder;
begin
  F.Typ := Typ;
  F.Recursive := Recursive;
  (*
  Realize type search according to the strategy:
   - start from the current visibility area and move to the outside;
   - in reverse order, we can use the same algorithm...
     without stopping for the first match.
  Adding a type in the current module:
   - type with a short name, put in module types;
   - type with composite name (name + package) duplicated in the list of packages.
  *)
  if FScope.Mode = TMode.mModule then
    Result := F.FindInModule(TpbModule(FScope))
  else
    Result := F.FindInMessage(Self);
  if Result = nil then
    // if type is not found add type to stub tmUnknown
    Result := Fem.FTab.AddUnknown(Self, Typ);
end;

function TpbMessage.AddOneOf(const Name: string): TPbOneOf;
begin
  Result := TPbOneOf.Create(Self, Name);
  FOneOfs.Add(Result);
end;

function TpbMessage.DelphiName: string;
begin
  Result := AsCamel(Name);
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

{$Region 'Tem'}

constructor Tem.Create(Tab: TpbTable; Scope: TIdent);
begin
  inherited Create;
  FTab := Tab;
  FScope := Scope;
  FMessages := TIdents<TpbMessage>.Create;
  FEnums := TIdents<TpbEnum>.Create;
end;

destructor Tem.Destroy;
begin
  FMessages.Free;
  FEnums.Free;
  inherited;
end;

function Tem.AddMessage(Scope: TIdent; const Name: string): TpbMessage;
var Package: TpbPackage;
begin
  if Scope.Mode = TMode.mModule then
    Package := TpbModule(Scope).CurrentPackage
  else
    Package := nil;
  Result := TpbMessage.Create(FTab, Scope, Name, Package);
  FMessages.Add(Result);
end;

function Tem.AddEnum(Scope: TIdent; const Name: string): TpbEnum;
var Package: TpbPackage;
begin
  if Scope.Mode = TMode.mModule then
    Package := TpbModule(Scope).CurrentPackage
  else
    Package := nil;
  Result := TpbEnum.Create(Scope, Name, Package);
  FEnums.Add(Result);
end;

function Tem.AddField(Scope: TpbMessage; const Name: string;
  Typ: TpbType; Tag: Integer; Rule: TFieldRule): TpbField;
begin
  Result := TpbField.Create(Scope, Name, Typ, Tag, Rule);
  Scope.FFields.Add(Result);
end;

function Tem.FindMessageType(Rpc: TIdent; Typ: TUserType): TpbType;
begin
  Result := Messages.Find(Typ.Name);
  if Result = nil then
    Result := FTab.AddUnknown(Rpc, Typ);
end;

{$EndRegion}

{$Region 'TpbPackage'}

constructor TpbService.Create(Scope: TpbModule; const Name: string);
begin
  inherited Create(Scope, Name, TMode.mService);
end;

function TpbService.AddRpc(const Name: string): TpbRpc;
begin
  Result := TpbRpc.Create(Self, Name);
  FRpcSystem.Add(Result);
end;

{$EndRegion}

{$Region 'TpbRpc'}

constructor TpbRpc.Create(Scope: TpbService; const Name: string);
begin
  inherited Create(Scope, Name, TMode.mRpc);
end;

function TpbRpc.AddOption(const Name: string; const Value: TConst): TpbOption;
begin
  Result := nil;
end;

{$EndRegion}

{$Region 'TpbModule'}

constructor TpbModule.Create(Tab: TpbTable; Scope: TIdent; const Name: string;
  Weak: Boolean);
begin
  inherited Create(Scope, Name, TMode.mModule);
  FImport := TIdents<TpbModule>.Create;
  FPackages := TIdents<TpbPackage>.Create;
  Fem := Tem.Create(Tab, Self);
  FMapTypes := TIdents<TpbMapType>.Create;
  FServices := TIdents<TpbService>.Create;
end;

destructor TpbModule.Destroy;
begin
  FImport.Free;
  FPackages.Free;
  Fem.Free;
  FMapTypes.Free;
  FServices.Free;
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

function TpbModule.LookupMapType(const Name: string; Key, Value: TpbType): TpbMapType;
var Id: string;
begin
  if Name <> '' then
    Id := Name
  else
    Id := Key.DelphiName + '_' + Value.DelphiName;
  Result := FMapTypes.Find(Id);
  if Result = nil then
  begin
    Result := TpbMapType.Create(Self, Name, Key, Value);
    FMapTypes.Add(Result);
  end;
end;

function TpbModule.AddPackage(const Name: string): TpbPackage;
begin
  Result := TpbPackage.Create(Self, Name);
  FCurrentPackage := Result;
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

function TpbModule.FindUserType(const Typ: TUserType; Recursive: Boolean): TpbType;
var F: TFinder;
begin
  F.Typ := Typ;
  F.Recursive := Recursive;
  Result := F.FindInModule(Self);
end;

function TpbModule.GetNameSpace: string;
begin
  Result := 'Example1';
end;

{$EndRegion}

{$Region 'TpbTable'}

constructor TpbTable.Create(Parser: TBaseParser);
begin
  inherited;
  FModule := TpbModule.Create(Self, nil, 'import', {weak=}True);
  FSystem := TpbModule.Create(Self, nil, 'System', {weak=}False);
  FUnknownTypes := TIdents<TpbType>.Create;
  InitSystem;
end;

destructor TpbTable.Destroy;
begin
  FModule.Free;
  FSystem.Free;
  FUnknownTypes.Free;
  inherited;
end;

procedure TpbTable.InitSystem;
var i: TTypeMode;
begin
  for i := Low(FEmbeddedTypes) to High(FEmbeddedTypes) do
    FEmbeddedTypes[i] := TpbEmbeddedType.Create(FSystem, i);
end;

function TpbTable.GetBasisType(kind: TTypeMode): TpbEmbeddedType;
begin
  Result := FEmbeddedTypes[kind];
end;

function TpbTable.AddUnknown(Scope: TIdent; Typ: TUserType): TpbType;
begin
  Result := TpbUnknownType.Create(Scope, Typ);
  FUnknownTypes.Add(Result);
end;

function TpbTable.OpenModule(Scope: TpbModule; const Name: string;
  Weak: Boolean): TpbModule;
begin
  Result := TpbModule.Create(Self, Scope, Name, Weak);
end;

function TpbTable.ParseInt(const s: string; base: Integer): Integer;
var
  sign: Integer;
  p: PChar;
  c: Char;
begin
  sign := 1;
  p := PChar(s);
  if p^ = '+' then
    Inc(p)
  else if p^ = '-' then
  begin
    sign := -1;
    Inc(p);
  end;
  Result := 0;
  repeat
    c := p^;
    if Between(c, '0', '9') then
      Result := Result * base + Ord(c) - Ord('0')
    else if Between(c, 'a', 'f') then
      Result := Result * base + Ord(c) - Ord('a') + 10
    else if Between(c, 'A', 'F') then
      Result := Result * base + Ord(c) - Ord('A') + 10
    else
      break;
    Inc(p);
  until False;
  Result := Result * sign;
end;

function TpbTable.Dump: string;
begin
  Result := '';
end;

function TpbTable.GenScript: string;
begin
  Result := '';
end;

{$EndRegion}

end.
