unit Oz.Pb.Gen;

interface

uses
  System.Classes, System.SysUtils, System.Math,
  Oz.Cocor.Utils, Oz.Cocor.Lib, pbPublic, Oz.Pb.Tab;

const
  RepeatedCollection = 'TList<%s>';
  MapCollection = 'TDictionary<%s, %s>';

type

{$Region 'TGen: code generator for delphi'}

  TGen = class(TCocoPart)
  private
    IndentLevel: Integer;
    sb: TStringBuilder;
    function GetCode: string;
    // Wrappers for TStringBuilder
    procedure Wr(const s: string); overload;
    procedure Wr(const f: string; const Args: array of const); overload;
    procedure Wrln; overload;
    procedure Wrln(const s: string); overload;
    procedure Wrln(const f: string; const Args: array of const); overload;
    // Indent control
    procedure Indent;
    procedure Dedent;
    // Enum code
    procedure EnumDecl(obj: PObj);
    // Map code
    procedure MapDecl(obj: PObj);
    // Message code
    procedure MessageDecl(msg: PObj);
    procedure MessageImpl(msg: PObj);
    procedure MessageWrite(msg: PObj);
    procedure MessageRead(msg: PObj);

    procedure GenDataStructures;
    procedure GenIO;
    procedure GenComment(const ñ: string);
    procedure LoadMessage(msg: PObj);
    procedure WriterInterface(msg: PObj);
    procedure ReaderInterface(msg: PObj);
    procedure WriterImplementation(msg: PObj);
    procedure ReaderImplementation(msg: PObj);
  public
    constructor Create(Parser: TBaseParser);
    destructor Destroy; override;
    procedure GenerateCode;
    // Generated code
    property Code: string read GetCode;
  end;

{$EndRegion}

implementation

uses
  Oz.Pb.Parser;

{$Region 'TFieldHelper'}

type

  TFieldHelper = class helper for TFieldOptions
    // constant declarations for field tags
    procedure AsTagDeclarations(gen: TGen);
    // field declaration
    procedure AsDeclaration(gen: TGen);

    (* field property
       // here can be field comment
       Id: Integer read FId write FId;
    *)
    procedure AsProperty(gen: TGen);

    (* Initialize field value
       We set fields
       repeating fields
         FPhones := TList<TPhoneNumber>.Create;
       map fields
         FTags := TDictionary<Integer, TpbField>.Create;
       fields for which the default value is not empty.
         FTyp := ptHOME;
    *)
    procedure AsInit(gen: TGen);

    (* Free field *)
    procedure AsFree(gen: TGen);

    (* field read from buffer
       TPerson.ftName:
         begin
           Assert(wireType = TWire.LENGTH_DELIMITED);
           person.Name := pb.readString;
         end;
    *)
    procedure AsRead(gen: TGen);

    (* field read from buffer
       pb.writeString(TPerson.ftName, Person.Name);
     *)
    procedure AsWrite(gen: TGen);

    (* field reflection
       under consruction
    *)
    procedure AsReflection(gen: TGen);
  end;

{$EndRegion}

{$Region 'TFieldHelper'}

procedure TFieldHelper.AsTagDeclarations(gen: TGen);
var n: string;
begin
  n := obj.DelphiName;
  if Rule = TFieldRule.Repeated then
    n := Plural(n);
  // ftId = 1; ftPhones = 5;
  gen.Wrln('ft%s = %d;', [n, Tag]);
end;

procedure TFieldHelper.AsDeclaration(gen: TGen);
var n, t: string;
begin
  n := obj.DelphiName;
  t := obj.AsType;
  if Rule = TFieldRule.Repeated then
    t := Format(RepeatedCollection, [t]);
  gen.Wrln('F%s: %s;', [n, t]);
end;

procedure TFieldHelper.AsProperty(gen: TGen);
var
  n, t, s: string;
  ro: Boolean;
begin
  ro := ReadOnly;
  n := obj.DelphiName;
  t := obj.AsType;
  if Rule = TFieldRule.Repeated then
  begin
    ro := True;
    n := Plural(n);
    t := Format(RepeatedCollection, [t]);
  end;
  s := Format('%s: %s read F%s', [n, t, n]);
  if ro then
    s := s + ';'
  else
    s := s + Format(' write F%s;', [n]);
  gen.Wrln(s);
end;

procedure TFieldHelper.AsReflection(gen: TGen);
begin
  raise Exception.Create('under consruction');
end;

procedure TFieldHelper.AsInit(gen: TGen);
var
  n, t: string;
begin
  n := obj.DelphiName;
  t := obj.AsType;
  if Default <> '' then
    gen.Wrln('F%s := %s;', [n, Default])
  else if Rule = TFieldRule.Repeated then
    gen.Wrln('F%s := ' + RepeatedCollection + '.Create;', [n, t])
  else if obj.typ.form = TTypeMode.tmMap then
    gen.Wrln('F%s := %s.Create;', [n, t]);
end;

procedure TFieldHelper.AsFree(gen: TGen);
begin
  if (Rule = TFieldRule.Repeated) or (obj.typ.form = TTypeMode.tmMap) then
    gen.Wrln('F%s.Free;', [obj.DelphiName]);
end;

procedure TFieldHelper.AsRead(gen: TGen);
var
  m, n: string;
begin
  m := Msg.DelphiName;
  n := obj.AsType;
  gen.Wrln('%s.ft%s:', [m, n]);
  gen.Indent;
  try
    gen.Wrln('begin');
    gen.Indent;
    try
      gen.Wrln('Assert(wireType = WIRETYPE_LENGTH_DELIMITED);');
      gen.Wrln('person.Name := pb.readString;', []);
    finally
      gen.Dedent;
    end;
    gen.Wrln('end;');
  finally
    gen.Dedent;
  end;
end;

procedure TFieldHelper.AsWrite(gen: TGen);
var
  m, f: string;

  procedure Process;
  begin
    case obj.typ.form of
      TTypeMode.tmDouble .. TTypeMode.tmSint64: // Embedded types
        gen.Wrln('FPb.Write%s(%s.ft%s, %s.%s);',
          [obj.DelphiName, m, obj.Name, msg.Name, obj.Name]);
      TTypeMode.tmEnum:
        gen.Wrln('FPb.Write Enum');
      TTypeMode.tmMessage:
        gen.Wrln('FPb.Write Message');
      TTypeMode.tmMap:
        gen.Wrln('FPb.Write Map');
      else
        raise Exception.Create('unsupported field type');
    end;
  end;

begin
  m := AsCamel(msg.Name);
  f := obj.AsType;
  if Default = '' then
    Process
  else
  begin
    // if Phone.FTyp <> ptHOME then
    gen.Wrln('if %s.F%s <> %s then', [m, f]);
    gen.Indent;
    try
      Process;
    finally
      gen.Dedent;
    end;
  end;
end;

{$EndRegion}

{$Region 'TGen'}

constructor TGen.Create(Parser: TBaseParser);
begin
  inherited;
  sb := TStringBuilder.Create;
end;

destructor TGen.Destroy;
begin
  sb.Free;
  inherited;
end;

procedure TGen.GenerateCode;
var
  ns: string;
begin
  ns := Tab.Module.NameSpace;
  Wrln('unit %s;', [ns]);
  Wrln;
  Wrln('interface');
  Wrln;
  Wrln('uses');
  Wrln('  System.Classes, System.SysUtils, Generics.Collections,');
  Wrln('  pbPublic, pbInput, pbOutput;');
  Wrln;
  GenDataStructures;
  Wrln('end;');
end;

procedure TGen.GenIO;
begin

end;

procedure TGen.GenDataStructures;
var
  obj, x: PObj;
  typ: PType;
begin
  Wrln('type');
  Wrln;
  obj := tab.Module.Obj; // root proto file
  x := obj.dsc;
  while x <> nil do
  begin
    if x.cls = TMode.mType then
    begin
      typ := x.typ;
      case typ.form of
        TTypeMode.tmEnum: EnumDecl(x);
        TTypeMode.tmMessage: MessageDecl(x);
        TTypeMode.tmMap: MapDecl(x);
      end;
    end;
    x := x.next;
  end;

  Wrln('implementation');
  Wrln;
  x := obj.dsc;
  while x <> tab.Guard do
  begin
    if x.cls = TMode.mType then
    begin
      typ := x.typ;
      if typ.form = TTypeMode.tmMessage then
        MessageImpl(x);
    end;
    x := x.next;
  end;
end;

function TGen.GetCode: string;
begin
  Result := sb.ToString;
end;

procedure TGen.Wr(const s: string);
begin
  sb.Append(Blank(IndentLevel * 2) + s);
end;

procedure TGen.Wr(const f: string; const Args: array of const);
begin
  sb.AppendFormat(Blank(IndentLevel * 2) + f, Args);
end;

procedure TGen.Wrln;
begin
  sb.AppendLine;
end;

procedure TGen.Wrln(const s: string);
begin
  sb.AppendLine(Blank(IndentLevel * 2) + s);end;

procedure TGen.Wrln(const f: string; const Args: array of const);
begin
  sb.AppendFormat(Blank(IndentLevel * 2) + f, Args);
  sb.AppendLine;
end;

procedure TGen.Indent;
begin
  Inc(IndentLevel);
end;

procedure TGen.Dedent;
begin
  Dec(IndentLevel);
  if IndentLevel < 0 then
    IndentLevel := 0;
end;

procedure TGen.EnumDecl(obj: PObj);
var
  n: Integer;
begin
  Wrln('T%s = (', [obj.Name]);
  while obj <> tab.Guard do
  begin
    n := obj.val.AsInt64;
    Wr('  %s = %d', [obj.Name, n]);
    obj := obj.next;
    if obj <> tab.Guard then
      Wrln(',')
    else
      Wrln(');');
  end;
  Wrln;
end;

procedure TGen.MapDecl(obj: PObj);
var
  x: PObj;
  typ, key, value: PType;
begin
  typ := obj.typ;
  x := obj;
  key := gen.tab.UnknownType;
  value := gen.tab.UnknownType;
  while x <> tab.Guard do
  begin
    if x.name = 'key' then
      key := x.typ
    else if x.name = 'value' then
      value := x.typ;
    x := x.next;
  end;
  Wrln('T%s = ' + MapCollection + ';',
    [obj.DelphiName, key.declaration.DelphiName, Value.declaration.DelphiName]);
end;

procedure TGen.MessageDecl(msg: PObj);
var
  x: PObj;
  typ: PType;
begin
  // generate nested messages
  x := msg.dsc;
  while x <> tab.Guard do
  begin
    typ := x.typ;
    if x.cls = TMode.mType then
      case typ.form of
        TTypeMode.tmEnum: EnumDecl(x);
        TTypeMode.tmMessage: MessageDecl(x);
        TTypeMode.tmMap: MapDecl(x);
      end;
    x := x.next;
  end;

  Wrln('T%s = class', [msg.DelphiName]);

  // generate field tag definitions
  Wrln('const');
  Indent;
  typ := msg.typ;
  Assert(typ.form = TTypeMode.tmMessage);
  try
    x := typ.dsc;
    while x <> tab.Guard do
    begin
      (x.aux as TFieldOptions).AsTagDeclarations(gen);
      x := x.next;
    end;
  finally
    Dedent;
  end;

  // generate field declarations
  Wrln('private');
  Indent;
  try
    x := typ.dsc;
    while x <> tab.Guard do
    begin
      (x.aux as TFieldOptions).AsDeclaration(gen);
      x := x.next;
    end;
  finally
    Dedent;
  end;

  Wrln('public');
  Indent;
  try
    Wrln('constructor Create;');
    Wrln('destructor Destoy; override;');
    Wrln('// properties');
    x := typ.dsc;
    while x <> tab.Guard do
    begin
      (x.aux as TFieldOptions).AsProperty(gen);
      x := x.next;
    end;
  finally
    Dedent;
  end;

  Wrln('end;'); // class
  Wrln;
end;

procedure TGen.MessageImpl(msg: PObj);
var
  t: string;
  x: PObj;
  typ: PType;
begin
  typ := msg.typ;
  // parameterless constructor
  t := msg.DelphiName;
  Wrln('constructor %s.Create;', [t]);
  Wrln('begin');
  Indent;
  try
    Wrln('inherited Create;');
    x := typ.dsc;
    while x <> tab.Guard do
    begin
      (x.aux as TFieldOptions).AsInit(gen);
      x := x.next;
    end;
  finally
    Dedent;
  end;
  Wrln('end;');
  Wrln;

  Wrln('destructor %s.Destroy;', [msg.DelphiName]);
  Wrln('begin');
  Indent;
  try
    x := typ.dsc;
    while x <> tab.Guard do
    begin
      (x.aux as TFieldOptions).AsFree(gen);
      x := x.next;
    end;
    Wrln('inherited Destroy;');
  finally
    Dedent;
  end;

  Wrln('end;');
  Wrln;
end;

procedure TGen.MessageWrite(msg: PObj);
var
  x: PObj;
  typ: PType;
begin
  typ := msg.typ;
  x := typ.dsc;
  while x <> tab.Guard do
  begin
    (x.aux as TFieldOptions).AsWrite(gen);
    x := x.next;
  end;
end;

procedure TGen.MessageRead(msg: PObj);
var
  x: PObj;
  typ: PType;
begin
  typ := msg.typ;
  x := typ.dsc;
  while x <> tab.Guard do
  begin
    (x.aux as TFieldOptions).AsRead(gen);
    x := x.next;
  end;
end;

procedure TGen.GenComment(const ñ: string);
var
  s: string;
begin
  for s in ñ.Split([#13#10], TStringSplitOptions.None) do
    Wrln('// ' + s)
end;

procedure TGen.LoadMessage(msg: PObj);
var
  obj: PObj;
  typ: PType;
begin
  typ := msg.typ;
  Assert((msg.cls = TMode.mType) and (typ.form = TTypeMode.tmMessage));
  obj := msg;
  while obj <> tab.Guard do
  begin
    if obj.cls = TMode.mType then
    begin
      typ := obj.typ;
      if typ.form = TTypeMode.tmMessage then
        LoadMessage(obj);
    end;
    obj := obj.next;
  end;
end;

procedure TGen.WriterInterface(msg: PObj);
begin
  Wrln(msg.DelphiName + 'Writer = class');
  Wrln('private');
  Wrln('  FPb: TProtoBufOutput;');
  Wrln('public');
  Wrln('  constructor Create;');
  Wrln('  destructor Destroy; override;');
  Wrln('  function GetPb: TProtoBufOutput;');
  Wrln('  procedure Write(' + AsCamel(msg.Name) + ': ' + msg.DelphiName + ');');
  Wrln('end;');
  Wrln;
end;

procedure TGen.WriterImplementation(msg: PObj);
begin
  Wrln('function %sWriter.GetPb: TProtoBufOutput;', [msg.DelphiName]);
  Wrln('begin');
  Wrln('  Result := FPb;');
  Wrln('end');
  Wrln;
  Wrln('procedure %sWriter.Wra%s: %s);', [msg.DelphiName, msg.Name, msg.DelphiName]);
  Wrln('var');
  Wrln('  i: Integer;');
  Wrln('begin');
  Indent;
  try
    MessageImpl(msg);
  finally
    Dedent;
  end;
  Wrln('end;');
  Wrln('');
end;

procedure TGen.ReaderInterface(msg: PObj);
var
  typ: PType;
  msgType, s, t: string;
begin
  typ := msg.typ;
  Assert((msg.cls = TMode.mType) and (typ.form = TTypeMode.tmMessage));
  msgType := msg.DelphiName;
  Wrln('%sReader = class', [msgType]);
  Wrln('private');
  Wrln('  FPb: TProtoBufInput;');
  MessageDecl(msg);
  s := AsCamel(msg.Name);
  t := msg.DelphiName;
  Wrln('  procedure Load%s(%s: %s);', [s, msg.Name, t]);
  Wrln('public');
  Wrln('  constructor Create;');
  Wrln('  destructor Destroy; override;');
  Wrln('  function GetPb: TProtoBufInput;');
  s := AsCamel(msg.Name);
  t := msg.DelphiName;
  Wrln('  procedure Load(%s: %s);', [s, t]);
  Wrln('end;');
  Wrln;
end;

procedure TGen.ReaderImplementation(msg: PObj);
var
  f: PObj;
  typ: PType;
begin
  typ := msg.typ;
  Assert((msg.cls = TMode.mType) and (typ.form = TTypeMode.tmMessage));
  Wrln('function %Reader.GetPb: TProtoBufOutput;', [msg.DelphiName]);
  Wrln('begin');
  Wrln('  Result := FPb;');
  Wrln('end;');
  Wrln;
  Wrln('procedure %sReader.Load(%s: %s);',
    [msg.DelphiName, AsCamel(msg.Name), msg.DelphiName]);
  Wrln('var');
  Wrln('  tag, fieldNumber, wireType: integer;');
  Wrln('begin');
  Indent;
  LoadMessage(msg);
  Wrln('tag := FPb.readTag;');
  Wrln('while tag <> 0 do');
  Wrln('begin');
  Indent;
  Wrln('wireType := getTagWireType(tag);');
  Wrln('fieldNumber := getTagFieldNumber(tag);');
  Wrln('tag := FPb.readTag;');
  Wrln('case fieldNumber of');
  f := typ.dsc;
  while f <> tab.Guard do
  begin
    Wrln('%s.ft%s:', [msg.DelphiName, AsCamel(f.Name)]);
    Indent;
    Wrln('  %s.%s := FPb.read%s;', [AsCamel(f.Name), AsCamel(f.Name),
      f.DelphiName]);
    Dedent;
    f := f.next;
  end;
  Wrln('else');
  Wrln('  FPb.skipField(tag);');
  Dedent;
  Wrln('end;');
  Dedent;
  Wrln('end;');
  Wrln('');
end;

{$EndRegion}

end.
