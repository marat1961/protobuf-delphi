unit Oz.Pb.Tab;

interface

uses
  System.Classes, System.SysUtils, System.Rtti, Generics.Collections,
  Oz.Cocor.Utils, Oz.Cocor.Lib, pbPublic;

{$SCOPEDENUMS on}

{$Region 'Forward declarations'}

type

  TpbTable = class;  // Parsing context
  TModule = class;   // .proto file
  TAux = class;      // object options

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

{$Region 'TQualIdent: User defined type'}

  TQualIdent = record
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

{$Region 'TMode, TTypeMode, PObj, TObjDesc, PType, TTypeDesc'}

  // Obj mode
  TMode = (
    mUnknown,
    mHead,
    mModule,    // proto file
    mVar,       // variable declaration
    mPar,       // procedure parameter
    mConst,     // constant declaration
    mField,     // record field
    mType,      // type
    mProc,      // procedure
    mPackage,   // proto package
    mOption,    // proto option
    // todo: standart procedure
    mService,   // service declaration
    mRpc);      // RPC declaration

  // Type mode
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

    // User defined types
    tmEnum,     // enumeration
    tmMessage,  // message
    tmArray,    // array
    tmMap,      // map
    tmUnion);   // union (oneOf)

  TEmbeddedTypes = TTypeMode.tmUnknown .. TTypeMode.tmSint64;

  PObj = ^TObjDesc;
  PType = ^TTypeDesc;

  TObjDesc = record
  var
    cls: TMode;
    lev: Integer;
    next, dsc: PObj;
    typ: PType;
    name: string;
    val: TValue;
    idx: Integer;
    aux: TAux;
  public
    // Get delphi name
    function DelphiName: string;
    // Get delphi type
    function AsType: string;
  end;

  TTypeDesc = record
    form: TTypeMode;
    declaration: PObj;    // type declaration
    dsc: PObj;            // fields, enum values, map tuple <key, value>
    base: PType;
    size, len: Integer;
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
  TpbPackage = class
    Name: string;
    Types: PType;
  end;

{$EndRegion}

{$Region 'TpbOption: can be used in proto files, messages, fields, enums and services'}

  TpbOption = record
    Name: string;
    Cval: TConst;
  end;

{$EndRegion}

{$Region 'TAux: auxiliary data for object'}

  // All additional attributes of the object are placed in auxilary data:
  //  - comments;
  //  - options;
  //  - additional object fields;
  //  - position in the file for the object declaration.
  TAux = class
  var
    Obj: PObj;
  public
    constructor Create(Obj: PObj);
    procedure Update(const Name: string; const Value: TConst); virtual;
  end;

{$EndRegion}

{$Region 'TMessageOptions: message options'}

  TMessageOptions = class(TAux)
  var
    Reserved: TIntSet;
    ReservedFields: TStringList;
  public
    constructor Create(Obj: PObj);
    destructor Destroy; override;
  end;

{$EndRegion}

{$Region 'TFieldOptions: field options'}

  // Rules for fields in .proto files
  TFieldRule = (Singular, Optional, Repeated);

  TFieldOptions = class(TAux)
  type
    TOptionKind = (
      foDefault, foMapType, foPacked, foAccess, foDeprecated, foTransient, foReadOnly);
  const
    KindNames: array [TOptionKind] of string = (
      'default', 'mapType', 'packed', 'access', 'deprecated', 'transient', 'readonly');
  var
    Msg: PObj;
    Tag: Integer;
    Rule: TFieldRule;
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
  public
    constructor Create(Obj: PObj; Tag: Integer; Rule: TFieldRule);
  end;

{$EndRegion}

{$Region 'TRpcOptions'}

  TRpcOptions = class(TAux)
  var
    request, response: PType;
  public
    constructor Create(Obj: PObj; request, response: PType);
  end;

{$EndRegion}

{$Region 'TEnumOptions'}

  // Enum options kind
  TEnumOptionKind = (foNamespace, foAllowAlias);

  TEnumOptions = class(TAux)
  var
    foAllowAlias: Boolean;
  end;

{$EndRegion}

{$Region 'TMapOptions'}

  TMapOptions = class(TAux)
  var
    foAllowAlias: Boolean;
  end;

{$EndRegion}

{$Region 'TModule: translation unit'}

  // Importing definition
  // import = "import" [ "weak" | "public" ] strLit ";"
  TModule = class(TAux)
  private
    FName: string;
    FTab: TpbTable;
    FWeak: Boolean;
    FSyntax: TSyntaxVersion;
    FImport: TList<TModule>;
    FCurrentPackage: TpbPackage;
    FMessages: TList<PObj>;
    FEnums: TList<PObj>;
    function GetNameSpace: string;
  protected
    constructor Create(Tab: TpbTable; const Name: string; Weak: Boolean);
  public
    destructor Destroy; override;
    // Properties
    property Weak: Boolean read FWeak;
    property Syntax: TSyntaxVersion read FSyntax write FSyntax;
    property Import: TList<TModule> read FImport;
    property NameSpace: string read GetNameSpace;
    property Messages: TList<PObj> read FMessages;
    property Enums: TList<PObj> read FEnums;
  end;

{$EndRegion}

{$Region 'TpbTable: '}

  // Uses the singleton pattern for its creation.
  TpbTable = class(TCocoPart)
  private
    FTopScope: PObj;
    FUniverse: PObj;
    FGuard: PObj;
    UnknownType: PType;
    // root node for the .proto file
    FModule: TModule;
    // predefined types
    FEmbeddedTypes: array [TEmbeddedTypes] of PType;
    // Fill predefined elements
    procedure InitSystem;
  public
    constructor Create(Parser: TBaseParser);
    destructor Destroy; override;
    // Add new declaration
    procedure NewObj(var obj: PObj; const id: string; cls: TMode);
    // Add new type
    function NewType(const obj: PObj; form: TTypeMode): PType;
    // Find identifier
    procedure Find(var obj: PObj; const id: string);
    // Open scope
    procedure OpenScope;
    // Open scope
    procedure CloseScope;
    // Enter
    procedure Enter(cls: TMode; n: Integer; name: string; typ: PType);
    // Find type
    function FindType(const id: TQualIdent): PType;
    // Find message type
    function FindMessageType(id: TQualIdent): PType;
    // Get embedded type by kind
    function GetBasisType(kind: TTypeMode): PType;
    // Update option value
    procedure AddOption(const name: string; const val: TConst);
    // Open and read module from file
    function OpenModule(const Name: string; Weak: Boolean): TModule;
    // Convert string to Integer
    function ParseInt(const s: string; base: Integer): Integer;
    function Dump: string;
    function GenScript: string;
    property TopScope: PObj read FTopScope;
    property Module: TModule read FModule write FModule;
  end;

{$EndRegion}

function GetWireType(tm: TTypeMode): TWireType;

const
  EmbeddedTypes: array [TEmbeddedTypes] of string = (
    'unknown', 'double', 'float', 'int64', 'uint64', 'int32',
    'fixed64', 'fixed32', 'bool', 'string', 'bytes',
    'uint32', 'sfixed32', 'sfixed64', 'sint32', 'sint64');
const
  DelphiEmbeddedTypes: array [TEmbeddedTypes] of string = (
    'Unknown', 'Double', 'Single', 'Int64', 'UIint64', 'Integer',
    'UInt64', 'UInt32', 'Boolean', 'string', 'bytes',
    'UInt32', 'UInt32', 'Int64', 'Integer', 'Int64');

implementation

uses
  Oz.Pb.Parser;

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

{$Region 'TObjDesc'}

function TObjDesc.DelphiName: string;
begin
  Result := AsCamel(name);
end;

function TObjDesc.AsType: string;
begin
  if Typ.form in [TTypeMode.tmUnknown .. TTypeMode.tmSint64] then
    Result := DelphiName
  else
    Result := 'T' + DelphiName;
end;

{$EndRegion}

{$Region 'TModule'}

constructor TModule.Create(Tab: TpbTable; const Name: string; Weak: Boolean);
begin
  inherited Create(Name);
  FImport := TIdents<TModule>.Create;
end;

destructor TModule.Destroy;
begin
  FImport.Free;
  inherited;
end;

function TModule.GetNameSpace: string;
begin
  Result := 'Example1';
end;

{$EndRegion}

{$Region 'TpbTable'}

constructor TpbTable.Create(Parser: TBaseParser);
begin
  inherited;
  FModule := TModule.Create(Self, 'import', {weak=}True);
  FUnknownTypes := TList<TUnknownType>.Create;
  InitSystem;
end;

destructor TpbTable.Destroy;
begin
  FModule.Free;
  FUnknownTypes.Free;
  inherited;
end;

procedure TpbTable.InitSystem;
var
  t: TTypeMode;
begin
  New(FGuard);
  FGuard.cls := TMode.mUnknown; FGuard.val := 0;
  FTopScope := nil;
  OpenScope;
  FUniverse := FTopScope;
  for t := TTypeMode.tmUnknown to TTypeMode.tmSint64 do
    Enter(TMode.mType, Ord(t), EmbeddedTypes[t], FEmbeddedTypes[t]);
  FGuard.typ := FEmbeddedTypes[TTypeMode.tmUnknown];
end;

procedure TpbTable.NewObj(var obj: PObj; const id: string; cls: TMode);
var
  x, n: PObj;
begin
  x := FTopScope;
  FGuard.name := id;
  while x.next.name <> id do x := x.next;
  if x.next = FGuard then
  begin
    New(n); n.name := id; n.cls := cls; n.next := FGuard;
    x.next := n; obj := n;
  end
  else
  begin
    obj := x.next;
    parser.SemError(1);
  end;
end;

function TpbTable.NewType(const obj: PObj; form: TTypeMode): PType;
begin
  New(typ);
  typ.form := form;
  typ.declaration := obj;
  obj.typ := typ;
end;

procedure TpbTable.Find(var obj: PObj; const id: string);
var
  s, x: PObj;
begin
  s := FTopScope; FGuard.name := id;
  repeat
    x := s.next;
    while x.name <> id do x := x.next;
    if x.next <> FGuard then exit;
    if s = FUniverse then
    begin
      obj := x;
      exit;
    end;
    s := s.dsc;
  until false;
end;

procedure TpbTable.OpenScope;
var s: PObj;
begin
  New(s);
  s.cls := TMode.mHead;
  s.dsc := FTopScope;
  s.next := FGuard;
  FTopScope := s;
end;

procedure TpbTable.CloseScope;
begin
  FTopScope := FTopScope.dsc;
end;

procedure TpbTable.Enter(cls: TMode; n: Integer; name: string; typ: PType);
var obj: PObj;
begin
  New(obj);
  obj.cls := cls; obj.val := n; obj.name := name; obj.typ := typ;
  obj.dsc := nil;
  obj.next := FTopScope.next;
  FTopScope.next := obj;
end;

function TpbTable.GetBasisType(kind: TTypeMode): PType;
begin
  Result := FEmbeddedTypes[kind];
end;

function TpbTable.FindType(const id: TQualIdent): PType;
var
  obj: PObj;
begin
  if id.Package = '' then
    Find(obj, id)
  else
  begin
    // искать пакет, а уже в нём тип
    Find(obj, id.Package);
    if obj.cls = TMode.mPackage then
      Find(obj, id);
  end;
  if obj.cls = TMode.mType then
    Result := obj.typ
  else if Result.form = TTypeMode.tmUnknown then
    parser.SemError(2)
  else
    parser.SemError(5);
end;

function TpbTable.FindMessageType(id: TQualIdent): PType;
var
  obj: PObj;
begin
  Find(obj, id);
  Assert(obj.cls = TMode.mType );
  Result := obj.typ;
end;

procedure TpbTable.AddOption(const name: string; const val: TConst);
var obj: PObj;
begin
  obj := TopScope;
  if obj.aux = nil then
  begin
    case obj.cls of
      TMode.mModule: obj.aux := tab.Module;
      TMode.mRpc: obj.aux := TRpcOptions.Create(obj);
      TMode.mField: obj.aux := TFieldOptions.Create(obj);
      TMode.mType:
        case obj.typ.form of
          TTypeMode.tmEnum: obj.aux := TEnumOptions.Create(obj);
          TTypeMode.tmMessage: obj.aux := TMessageOptions.Create(obj);
          TTypeMode.tmMap: obj.aux := TMapOptions.Create(obj);
          TTypeMode.tmUnion:
            obj.aux := TAux.Create(obj);
          else
            raise Exception.Create('AddOption error');

        end;
      else
        raise Exception.Create('AddOption error');
    end;
  end;
  obj.aux.Update(name, val);
end;

function TpbTable.OpenModule(const Name: string; Weak: Boolean): TModule;
begin
  Result := TModule.Create(Self, Name, Weak);
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

