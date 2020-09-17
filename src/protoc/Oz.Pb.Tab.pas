unit Oz.Pb.Tab;

interface

uses
  System.Classes, System.SysUtils, System.Rtti, Generics.Collections, System.IOUtils,
  Oz.Cocor.Utils, Oz.Cocor.Lib, Oz.Pb.Classes;

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
    mHead,      // open scope head
    mModule,    // proto file
    mVar,       // variable declaration
    mPar,       // procedure parameter
    mConst,     // constant declaration
    mField,     // record field
    mType,      // type
    mProc,      // procedure
    mPackage);  // proto package

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
  class var
    Keywords: TStringList;
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
    class function GetInstance(cls: TMode): PObj; static;
    // Get delphi name
    function DelphiName: string;
    // Get delphi field
    function AsField: string;
    // Get delphi type
    function AsType: string;
    // Check if options are created if it does not create them.
    // Then check the validity of the name and value,
    // if all ok then update the option value.
    procedure AddOption(const name: string; const val: TConst);
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
  //  - additional object fields;
  //  - position in the file for the object declaration.
  TAux = class
  var
    Obj: PObj;
    comments: string;
  protected
    procedure UpdateOption(const id: string; const cv: TConst); virtual;
  public
    constructor Create(Obj: PObj);
    procedure Update(const id: string; const cv: TConst);
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
    constructor Create(Obj, Msg: PObj; Tag: Integer; Rule: TFieldRule);
  end;

{$EndRegion}

{$Region 'TRpcOptions'}

  TRpcOptions = class(TAux)
  var
    requestStream: Boolean;
    responseStream: Boolean;
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
    FWeak: Boolean;
    FSyntax: TSyntaxVersion;
    FImport: PObj;
    FCurrentPackage: TpbPackage;
    function GetNameSpace: string;
  public
    constructor Create(Obj: PObj; const Name: string; Weak: Boolean);
    destructor Destroy; override;
    // Properties
    property Name: string read FName;
    property Weak: Boolean read FWeak;
    property Syntax: TSyntaxVersion read FSyntax write FSyntax;
    property Import: PObj read FImport;
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
    // root node for the .proto file
    FModule: TModule;
    FModId: string;
    // predefined types
    FEmbeddedTypes: array [TEmbeddedTypes] of PType;
    // Fill predefined elements
    procedure InitSystem;
    function GetUnknownType: PType;
  public
    constructor Create;
    destructor Destroy; override;
    // Add new declaration
    procedure NewObj(var obj: PObj; const id: string; cls: TMode);
    // Add new type
    procedure NewType(const obj: PObj; form: TTypeMode);
    // Find identifier
    procedure Find(var obj: PObj; const id: string);
    // Open scope
    procedure OpenScope;
    // Open scope
    procedure CloseScope;
    // Enter
    procedure Enter(cls: TMode; n: Integer; name: string; var typ: PType);
    // Concatenate a := a + TopScope.next (without head)
    procedure Concatenate(var a: PObj);
    // Find type
    function FindType(const id: TQualIdent): PType;
    // Find message type
    function FindMessageType(id: TQualIdent): PType;
    // Get embedded type by kind
    function GetBasisType(kind: TTypeMode): PType;
    // Open and read module from file
    procedure OpenProto(const id: string; Weak: Boolean);
    // Import module
    procedure Import(const id: string; Weak: Boolean);
    // Convert string to Integer
    function ParseInt(const s: string; base: Integer): Integer;
    function Dump: string;
    function GenScript: string;
    // properties
    property TopScope: PObj read FTopScope;
    property Guard: PObj read FGuard;
    property ModId: string read FModId;
    property Module: TModule read FModule write FModule;
    property UnknownType: PType read GetUnknownType;
  end;

{$EndRegion}

function GetWireType(tm: TTypeMode): TWireType;

const
  // type name in proto file
  EmbeddedTypes: array [TEmbeddedTypes] of string = (
    'unknown', 'double', 'float', 'int64', 'uint64', 'int32',
    'fixed64', 'fixed32', 'bool', 'string', 'bytes',
    'uint32', 'sfixed32', 'sfixed64', 'sint32', 'sint64');
  // type name in delphi
  DelphiEmbeddedTypes: array [TEmbeddedTypes] of string = (
    'Unknown', 'Double', 'Single', 'Int64', 'UIint64', 'Integer',
    'UInt64', 'UInt32', 'Boolean', 'string', 'bytes',
    'UInt32', 'UInt32', 'Int64', 'Integer', 'Int64');
  DelphiKeywords: array [0 .. 64] of string = (
    'and', 'array', 'as', 'asm', 'begin', 'case', 'class', 'const',
    'constructor', 'destructor', 'dispinterface', 'div', 'do', 'downto',
    'else', 'end', 'except', 'exports', 'file', 'finalization', 'finally',
    'for', 'function', 'goto', 'if',  'implementation', 'in', 'inherited',
    'initialization', 'inline', 'interface', 'is', 'label', 'library',
    'mod', 'nil', 'not', 'object', 'of', 'or', 'out', 'packed', 'procedure',
    'program', 'property', 'raise', 'record', 'repeat', 'resourcestring',
    'set', 'shl', 'shr', 'string', 'then', 'threadvar', 'to', 'try',
    'type', 'unit', 'until', 'uses', 'var', 'while', 'with', 'xor');

implementation

uses
  Oz.Pb.Scanner,
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
begin
  Result := LowerCase(Value) = 'true';
  typ := TConstType.cBool;
  val := Result;
end;

{$EndRegion}

{$Region 'TObjDesc'}

class function TObjDesc.GetInstance(cls: TMode): PObj;
begin
  New(Result);
  Result^ := Default(TObjDesc);
  Result.cls := TMode.mUnknown;
end;

function TObjDesc.DelphiName: string;
begin
  Result := AsCamel(name);
  if Keywords.IndexOf(Result) >= 0 then
    Result := '&' + Result;
end;

function TObjDesc.AsField: string;
begin
  Result := 'F' + AsCamel(name);
  if Keywords.IndexOf(Result) >= 0 then
    Result := '&' + Result;
end;

function TObjDesc.AsType: string;
begin
  if Typ.form in [TTypeMode.tmUnknown .. TTypeMode.tmSint64] then
    Result := DelphiEmbeddedTypes[Typ.form]
  else
  begin
    Result := 'T' + AsCamel(typ.declaration.name);
    if Keywords.IndexOf(Result) >= 0 then
      Result := '&' + Result;
  end;
end;

procedure TObjDesc.AddOption(const name: string; const val: TConst);
begin
  if aux = nil then
    case cls of
      TMode.mType:
        case typ.form of
          TTypeMode.tmEnum: aux := TEnumOptions.Create(@Self);
          TTypeMode.tmMessage: aux := TMessageOptions.Create(@Self);
          TTypeMode.tmMap: aux := TMapOptions.Create(@Self);
          TTypeMode.tmUnion: aux := TAux.Create(@Self);
        end;
    end;
  if aux = nil then
    raise Exception.Create('AddOption error');
  aux.Update(name, val);
end;

{$EndRegion}

{$Region 'TAux'}

constructor TAux.Create(Obj: PObj);
begin
  inherited Create;
  Self.Obj := Obj;
end;

procedure TAux.Update(const id: string; const cv: TConst);
begin
  UpdateOption(LowerCase(id), cv);
end;

procedure TAux.UpdateOption(const id: string; const cv: TConst);
begin
  if id = 'comment' then
    comments := cv.val.AsString;
end;

{$EndRegion}

{$Region 'TMessageOptions'}

constructor TMessageOptions.Create(Obj: PObj);
begin
  inherited;
  Reserved := TIntSet.Create;
  ReservedFields := TStringList.Create;
end;

destructor TMessageOptions.Destroy;
begin
  Reserved.Free;
  ReservedFields.Free;
  inherited;
end;

{$EndRegion}

{$Region 'TFieldOptions'}

constructor TFieldOptions.Create(Obj, Msg: PObj; Tag: Integer; Rule: TFieldRule);
begin
  inherited Create(Obj);
  Self.Msg := Msg;
  Self.Tag := Tag;
  Self.Rule := Rule;
end;

{$EndRegion}

{$Region 'TModule'}

constructor TModule.Create(Obj: PObj; const Name: string; Weak: Boolean);
begin
  inherited Create(Obj);
  FName := Name;
  FWeak := Weak;
end;

destructor TModule.Destroy;
var p, q: PObj;
begin
  p := FImport;
  while p <> nil do
  begin
    q := p.next; Dispose(p);
    p := q;
  end;
  inherited;
end;

function TModule.GetNameSpace: string;
begin
  Result := 'Example1';
end;

{$EndRegion}

{$Region 'TpbTable'}

constructor TpbTable.Create;
var
  i: Integer;
begin
  inherited Create(nil);
  TObjDesc.Keywords := TStringList.Create;
  for i := Low(DelphiKeywords) to High(DelphiKeywords) do
    TObjDesc.Keywords.Add(DelphiKeywords[i]);
  TObjDesc.Keywords.Sorted := True;
  InitSystem;
end;

destructor TpbTable.Destroy;
begin
  TObjDesc.Keywords.Free;
  // todo: start using memory regions
  inherited;
end;

procedure TpbTable.InitSystem;
var
  t: TTypeMode;
begin
  FGuard := TObjDesc.GetInstance(TMode.mUnknown);
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
    n := TObjDesc.GetInstance(cls);
    n.name := id; n.cls := cls; n.next := FGuard;
    x.next := n; obj := n;
  end
  else
  begin
    obj := x.next;
    parser.SemError(1);
  end;
end;

procedure TpbTable.Concatenate(var a: PObj);
var x: PObj;
begin
  if a = nil then
    a := FTopScope.next
  else
  begin
    x := a;
    while x.next <> FGuard do x := x.next;
    x.next := FTopScope.next;
  end;
end;

procedure TpbTable.NewType(const obj: PObj; form: TTypeMode);
var
  typ: PType;
begin
  New(typ); typ^ := Default(TTypeDesc);
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
    while x.name <> id do
      x := x.next;
    if x <> FGuard then
    begin
      obj := x;
      exit;
    end;
    if s = FUniverse then
    begin
      obj := x; parser.SemError(2);
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

procedure TpbTable.Enter(cls: TMode; n: Integer; name: string; var typ: PType);
var
  obj: PObj;
begin
  New(obj);
  obj.cls := cls; obj.val := n; obj.name := name;
  NewType(obj, TTypeMode(n)); typ := obj.typ;
  obj.dsc := nil;
  obj.next := FTopScope.next;
  FTopScope.next := obj;
end;

function TpbTable.GetBasisType(kind: TTypeMode): PType;
begin
  Result := FEmbeddedTypes[kind];
end;

function TpbTable.GetUnknownType: PType;
begin
  Result := FEmbeddedTypes[TTypeMode.tmUnknown];
end;

function TpbTable.FindType(const id: TQualIdent): PType;
var
  obj: PObj;
begin
  if id.Package = '' then
    Find(obj, id.Name)
  else
  begin
    // search for a package, and already in it the type
    Find(obj, id.Package);
    if obj.cls = TMode.mPackage then
      Find(obj, id.Name);
  end;
  Result := UnknownType;
  if obj.cls = TMode.mType then
    Result := obj.typ
  else if Result.form = TTypeMode.tmUnknown then
    parser.SemError(2)
  else
    parser.SemError(6);
end;

function TpbTable.FindMessageType(id: TQualIdent): PType;
var
  typ: PType;
begin
  typ := FindType(id);
  if typ.form <> TTypeMode.tmMessage then
    parser.SemError(5);
  Result := typ;
end;

procedure TpbTable.OpenProto(const id: string; Weak: Boolean);
var
  str: TStringList;
  src, stem, filename: string;
begin
  FModId := id;
  try
    str := TStringList.Create;
    try
      str.LoadFromFile(id);
      src := str.Text;
    finally
      str.Free;
    end;
    str := TStringList.Create;
    FParser := TpbParser.Create(Self, TpbScanner.Create(src), str);
    try
      parser.Parse;
      Writeln(parser.errors.count, ' errors detected');
      parser.PrintErrors;
      stem := TPath.GetFilenameWithoutExtension(id);
      filename := TPath.Combine(options.srcDir, stem + '.lst');
      str.SaveToFile(filename);
      if parser.errors.count = 0 then
      begin
        parser.gen.GenerateCode;
        str.Text := parser.gen.Code;
        filename := TPath.Combine(options.srcDir, stem + '.pas');
        str.SaveToFile(filename);
      end;
    finally
      str.Free;
      FreeAndNil(FParser);
    end;
  except
    on e: FatalError do Writeln('-- ', e.Message);
  end;
end;

procedure TpbTable.Import(const id: string; Weak: Boolean);
const
  // This is a predefined module describing embedded structures and types.
  PredefinedModule = 'google/protobuf/descriptor.proto';
var
  tm: TModule;
begin
  if LowerCase(id) = PredefinedModule then exit;
  tm := FModule;
  try
    OpenProto(id, Weak);
  finally
    FModule := tm;
  end;
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

