unit Oz.Pb.Tab;

interface

uses
  System.Classes, System.SysUtils, System.Rtti, Generics.Collections,
  Oz.Cocor.Utils, Oz.Cocor.Lib, pbPublic;

{$SCOPEDENUMS on}

{$Region 'Forward declarations'}

type

  TpbTable = class;          // Parsing context
  TpbModule = class;         // .proto file
  TpbOption = class;

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

{$Region 'TUserType: User defined type'}

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

  // Obj mode
  TMode = (
    mUnknown,
    mHead,
    mVar,        // variable definition
    mPar,        // procedure parameter
    mConst,      // constant declaration
    mField,      // record field
    mType,       // type
    mProc,       // procedure
    mEnum,       // enum definition
    mEnumValue); // enum value

//    mOneOf,     // proto OnOf
//    mModule,    // proto file
//    mPackage,   // proto package
//    mOption,    // proto option
//    mService,   // service definition
//    mRpc,       // service definition
//    mRecord,    // message definition

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
    tmEnum,     // Integer
    tmMessage,  // message
    tmMap);     // Map

  TEmbeddedTypes = TTypeMode.tmUnknown .. TTypeMode.tmSint64;

  PObj = ^TObjDesc;
  PType = ^TTypeDesc;

  TObjDesc = record
    cls: TMode;
    lev: Integer;
    next, dsc: PObj;
    typ: PType;
    name: string;
    val: TValue;
    idx: Integer;
    // Get delphi name
    function DelphiName: string;
    // Get delphi type
    function AsType: string;
  end;

  TTypeDesc = record
    form: TTypeMode;
    fields: PObj;
    base: PType;
    size, len: Integer;
  end;

{$Region 'TIdent: base class for creating all other objects'}

  TIdent = class
  private
    FName: string;
  public
    constructor Create(const Name: string);
    function AddOption(const Name: string; const Value: TConst): TpbOption; virtual;
    property Name: string read FName;
  end;

{$EndRegion}

{$Region 'TUnknownType'}

  TUnknownType = record
    obj: PObj;
    typ: TUserType;
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
    constructor Create(const Name: string; const Value: TConst);
    property Value: TValue read FCval.val;
    property Typ: TConstType read FCval.typ;
  end;

  // Rules for fields in .proto files
  TFieldRule = (Singular, Optional, Repeated);

  TpbField = record
    Typ: PType;
    Tag: Integer;
    Rule: TFieldRule;
    Pos: TPosition;
    Options: TFieldOptions;
  end;

{$EndRegion}

{$Region 'TEnumOptions'}

  // Enum options kind
  TEnumOptionKind = (foNamespace, foAllowAlias);

  PEnumOptions = ^TEnumOptions;
  TEnumOptions = record
    Namespace: string;
    foAllowAlias: Boolean;
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
    // Search the module recursively
    function FindImport(const Name: string): TpbModule;
    function GetNameSpace: string;
  protected
    constructor Create(Tab: TpbTable; const Name: string; Weak: Boolean);
  public
    destructor Destroy; override;
    // Search the module recursively and if not found then open the file
    function LookupImport(const Name: string; Weak: Boolean): TpbModule;
    // Add module option
    function AddOption(const Name: string; const Value: TConst): TpbOption; override;
    // Properties
    property Weak: Boolean read FWeak;
    property Syntax: TSyntaxVersion read FSyntax write FSyntax;
    property Import: TIdents<TpbModule> read FImport;
    property Options: TIdents<TpbOption> read FOptions;
    property NameSpace: string read GetNameSpace;
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
    FModule: TpbModule;
    FUnknownTypes: TList<TUnknownType>;
    // predefined types
    FEmbeddedTypes: array [TEmbeddedTypes] of PType;
    // Fill predefined elements
    procedure InitSystem;
  public
    constructor Create(Parser: TBaseParser);
    destructor Destroy; override;
    // Add new declaration
    procedure NewObj(var obj: PObj; const id: string; cls: TMode);
    // Find
    procedure Find(var obj: PObj; const id: string);
    // Open scope
    procedure OpenScope;
    // Open scope
    procedure CloseScope;
    // Enter
    procedure Enter(cls: TMode; n: Integer; name: string; typ: PType);
    // Get embedded type by kind
    function GetBasisType(kind: TTypeMode): PType;
    // Àdd stub type tmUnknown
    function AddUnknown(Typ: TUserType): PType;
    // Open and read module from file
    function OpenModule(const Name: string; Weak: Boolean): TpbModule;
    // Convert string to Integer
    function ParseInt(const s: string; base: Integer): Integer;
    function Dump: string;
    function GenScript: string;
    property Module: TpbModule read FModule write FModule;
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

{$Region 'TIdent'}

constructor TIdent.Create(const Name: string);
begin
  inherited Create;
  FName := Name;
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

constructor TpbOption.Create(const Name: string; const Value: TConst);
begin
  inherited Create(Name);
  Self.FCval := Value;
end;

{$EndRegion}

{$Region 'TpbModule'}

constructor TpbModule.Create(Tab: TpbTable; const Name: string; Weak: Boolean);
begin
  inherited Create(Name);
  FImport := TIdents<TpbModule>.Create;
end;

destructor TpbModule.Destroy;
begin
  FImport.Free;
  inherited;
end;

function TpbModule.LookupImport(const Name: string; Weak: Boolean): TpbModule;
begin
  // If the module has already been read and is in memory,
  // then do not read it again
  Result := FindImport(Name);
  if Result = nil then
    Result := FTab.OpenModule(Name, Weak);
end;

function TpbModule.AddOption(const Name: string; const Value: TConst): TpbOption;
begin
  Result := TpbOption.Create(Name, Value);
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

function TpbModule.GetNameSpace: string;
begin
  Result := 'Example1';
end;

{$EndRegion}

{$Region 'TpbTable'}

constructor TpbTable.Create(Parser: TBaseParser);
begin
  inherited;
  FModule := TpbModule.Create(Self, 'import', {weak=}True);
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
  end;
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

function TpbTable.AddUnknown(Typ: TUserType): PType;
var
  u: TUnknownType;
begin
  Result := UnknownType;
  u.obj := nil;
  u.typ := Typ;
  FUnknownTypes.Add(u);
end;

function TpbTable.OpenModule(const Name: string; Weak: Boolean): TpbModule;
begin
  Result := TpbModule.Create(Self, Name, Weak);
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

