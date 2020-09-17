unit Oz.Pb.Gen;

interface

uses
  System.Classes, System.SysUtils, System.Math, Generics.Collections,
  Oz.Cocor.Utils, Oz.Cocor.Lib, Oz.Pb.Tab, Oz.Pb.Classes;

const
  RepeatedCollection = 'TList<%s>';
  MapCollection = 'TDictionary<%s, %s>';

type

{$Region 'TGen: code generator for delphi'}

  TMapTypes = TList<PType>;
  TGetMap = (
    asVarDecl,
    asParam,
    asVarUsing);
  TGen = class(TCocoPart)
  private
    IndentLevel: Integer;
    sb: TStringBuilder;
    maps: TMapTypes;
    mapvars: TMapTypes;
    pairMessage: TObjDesc;
    pairType: TTypeDesc;
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

    // Field tag ident
    function FieldTag(obj: PObj): string;
    // Field tag declaration
    procedure FieldTagDecl(obj: PObj);
    // Field declaration
    procedure FieldDecl(obj: PObj);
    // field property
    procedure FieldProperty(obj: PObj);
    // Initialize field value
    procedure FieldInit(obj: PObj);
    // Free field
    procedure FieldFree(obj: PObj);
    // Get read statement
    function GetRead(obj: PObj): string;
    // Field read from buffer
    procedure FieldRead(obj: PObj);
    // Write field to buffer
    procedure FieldWrite(obj: PObj);
    // Field reflection
    procedure FieldReflection(obj: PObj);
    // unused
    procedure GenComment(const comment: string);

    // Message code
    function GetPair(maptypes: TMapTypes; typ: PType; mas: TGetMap): string;
    procedure MessageDecl(msg: PObj);
    procedure MessageImpl(msg: PObj);
    procedure LoadDecl(msg: PObj);
    procedure SaveDecl(msg: PObj);
    procedure LoadImpl(msg: PObj);
    procedure SaveImpl(msg: PObj);
    procedure SaveMaps;

    // Top level code
    procedure ModelDecl;
    procedure ModelImpl;
    procedure BuilderDecl(Load: Boolean);
    procedure BuilderImpl(Load: Boolean);
    function GetBuilderName(Load: Boolean): string;
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

{$Region 'TGen'}

constructor TGen.Create(Parser: TBaseParser);
begin
  inherited;
  sb := TStringBuilder.Create;
  maps := TList<PType>.Create;
  mapvars := TList<PType>.Create;
end;

destructor TGen.Destroy;
begin
  mapvars.Free;
  maps.Free;
  sb.Free;
  inherited;
end;

procedure TGen.GenerateCode;
var
  ns: string;
begin
  ns := AsCamel(Tab.Module.Name);
  Wrln('unit %s;', [ns]);
  Wrln;
  Wrln('interface');
  Wrln;
  Wrln('uses');
  Wrln('  System.Classes, System.SysUtils, Generics.Collections, Oz.Pb.Classes;');
  Wrln;
  Wrln('type');
  Wrln;
  Indent;
  try
    ModelDecl;
    BuilderDecl({Load=}True);
    BuilderDecl({Load=}False);
  finally
    Dedent;
  end;
  Wrln('implementation');
  Wrln;
  ModelImpl;
  BuilderImpl(True);
  BuilderImpl(False);
  Wrln('end.');
end;

procedure TGen.ModelDecl;
var
  obj, x: PObj;
  typ: PType;
begin
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
end;

procedure TGen.ModelImpl;
var
  obj, x: PObj;
  typ: PType;
begin
  obj := tab.Module.Obj; // root proto file
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
  sb.Append(s);
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
  sb.AppendLine(Blank(IndentLevel * 2) + s);
end;

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
  x: PObj;
  n: Integer;
begin
  Wrln('%s = (', [obj.AsType]);
  x := obj.typ.dsc;
  while x <> tab.Guard do
  begin
    n := x.val.AsInt64;
    Wr('  %s = %d', [x.Name, n]);
    x := x.next;
    if x <> tab.Guard then
      Wr(',')
    else
      Wr(');');
    Wrln;
  end;
  Wrln;
end;

procedure TGen.MapDecl(obj: PObj);
var
  x: PObj;
  key, value: PType;
begin
  x := obj.typ.dsc;
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
  Wrln('%s = ' + MapCollection + ';',
    [obj.AsType, key.declaration.AsType, Value.declaration.AsType]);
  Wrln;
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

  Wrln('%s = class', [msg.AsType]);

  // generate field tag definitions
  Wrln('const');
  Indent;
  typ := msg.typ;
  Assert(typ.form = TTypeMode.tmMessage);
  try
    x := typ.dsc;
    while x <> tab.Guard do
    begin
      FieldTagDecl(x);
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
      FieldDecl(x);
      x := x.next;
    end;
  finally
    Dedent;
  end;

  Wrln('public');
  Indent;
  try
    Wrln('constructor Create;');
    Wrln('destructor Destroy; override;');
    Wrln('// properties');
    x := typ.dsc;
    while x <> tab.Guard do
    begin
      FieldProperty(x);
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
  // generate nested messages
  x := msg.dsc;
  while x <> tab.Guard do
  begin
    typ := x.typ;
    if x.cls = TMode.mType then
      case typ.form of
        TTypeMode.tmMessage: MessageImpl(x);
//        TTypeMode.tmMap: MapDecl(x);
      end;
    x := x.next;
  end;

  typ := msg.typ;
  // parameterless constructor
  t := msg.AsType;
  Wrln('constructor %s.Create;', [t]);
  Wrln('begin');
  Indent;
  try
    Wrln('inherited Create;');
    x := typ.dsc;
    while x <> tab.Guard do
    begin
      FieldInit(x);
      x := x.next;
    end;
  finally
    Dedent;
  end;
  Wrln('end;');
  Wrln;

  Wrln('destructor %s.Destroy;', [t]);
  Wrln('begin');
  Indent;
  try
    x := typ.dsc;
    while x <> tab.Guard do
    begin
      FieldFree(x);
      x := x.next;
    end;
    Wrln('inherited Destroy;');
  finally
    Dedent;
  end;

  Wrln('end;');
  Wrln;
end;

procedure TGen.LoadDecl(msg: PObj);
var
  typ: PType;
  x: PObj;
  t: string;
begin
  typ := msg.typ;
  if msg.cls <> TMode.mType then exit;
  if typ.form <> TTypeMode.tmMessage then exit;
  t := msg.AsType;
  Wrln('function Load%s(%s: %s): %s;', [msg.DelphiName, msg.name, t, t]);
  x := msg.dsc;
  while x <> tab.Guard do
  begin
    typ := x.typ;
    if (x.cls = TMode.mType) and (typ.form = TTypeMode.tmMessage) then
      LoadDecl(x);
    x := x.next;
  end;
end;

procedure TGen.SaveDecl(msg: PObj);
var
  typ: PType;
  x: PObj;
begin
  typ := msg.typ;
  if msg.cls <> TMode.mType then exit;
  case typ.form of
    TTypeMode.tmMap:
      if maps.IndexOf(typ) < 0 then
        maps.Add(typ);
    TTypeMode.tmMessage:
      begin
        Wrln('procedure Save%s(%s: %s);', [msg.DelphiName, msg.name, msg.AsType]);
        x := msg.dsc;
        while x <> tab.Guard do
        begin
          if x.cls = TMode.mType then SaveDecl(x);
          x := x.next;
        end;
      end;
  end;
end;

procedure TGen.LoadImpl(msg: PObj);
var
  x: PObj;
  typ: PType;
  s, t: string;
begin
  // generate nested messages
  x := msg.dsc;
  while x <> nil {tab.Guard} do
  begin
    typ := x.typ;
    if x.cls = TMode.mType then
      if typ.form = TTypeMode.tmMessage then
        LoadImpl(x);
    x := x.next;
  end;
  typ := msg.typ;
  if msg.cls <> TMode.mType then exit;
  if typ.form <> TTypeMode.tmMessage then exit;
  s := msg.DelphiName;
  t := msg.AsType;
  Wrln('function %s.Load%s(%s: %s): %s;', [GetBuilderName(True), s, msg.name, t, t]);
  Wrln('var');
  Wrln('  fieldNumber, wireType: integer;');
  Wrln('  tag: TpbTag;');
  Wrln('begin');
  Indent;
  Wrln('Result := %s;', [s]);
  Wrln('tag := Pb.readTag;');
  Wrln('while tag.v <> 0 do');
  Wrln('begin');
  Indent;
  Wrln('wireType := tag.WireType;');
  Wrln('fieldNumber := tag.FieldNumber;');
  Wrln('case fieldNumber of');
  x := typ.dsc;
  while x <> tab.Guard do
  begin
    FieldRead(x);
    x := x.next;
  end;
  Wrln('  else');
  Wrln('    Pb.skipField(tag);');
  Wrln('end;');
  Wrln('tag := Pb.readTag;');
  Dedent;
  Wrln('end;');
  Dedent;
  Wrln('end;');
  Wrln('');
end;

procedure TGen.SaveImpl(msg: PObj);
var
  typ: PType;
  x: PObj;

  function HasRepeatedVars(x: PObj): Boolean;
  begin
    while x <> tab.Guard do
    begin
      if TFieldOptions(x.aux).Rule = TFieldRule.Repeated then
        exit(True);
      x := x.next;
    end;
    Result := False;
  end;

  procedure SaveMessage;
  var
    s, t: string;
    x: PObj;
    typ: PType;
  begin
    s := msg.DelphiName;
    t := msg.AsType;
    Wrln('procedure %s.Save%s(%s: %s);', [GetBuilderName(False), s, msg.name, t]);
    mapvars.Clear;
    x := msg.dsc;
    while x <> tab.Guard do
    begin
      typ := x.typ;
      if x.cls = TMode.mType then
        case typ.form of
          TTypeMode.tmMap:
            if mapvars.IndexOf(typ) < 0 then
              mapvars.Add(typ);
        end;
      x := x.next;
    end;
    if HasRepeatedVars(msg.typ.dsc) or (mapvars.Count > 0) then
    begin
      Wrln('var');
      begin
        if HasRepeatedVars(msg.typ.dsc) then
          Wrln('  i: Integer;');
        Wrln('  h: TpbSaver;');
      end;
      for typ in mapvars do
        Wrln('  ' + GetPair(mapvars, typ, TGetMap.asVarDecl) + ';');
    end;
    Wrln('begin');
    Indent;
    try
      typ := msg.typ;
      x := typ.dsc;
      while x <> tab.Guard do
      begin
        FieldWrite(x);
        x := x.next;
      end;
    finally
      Dedent;
    end;
    Wrln('end;');
    Wrln('');
  end;

begin
  // generate nested messages
  x := msg.dsc;
  while x <> nil {tab.Guard} do
  begin
    typ := x.typ;
    if (x.cls = TMode.mType) and (typ.form = TTypeMode.tmMessage) then
      SaveImpl(x);
    x := x.next;
  end;
  typ := msg.typ;
  if (msg.cls = TMode.mType) and (typ.form = TTypeMode.tmMessage) then
    SaveMessage;
end;

type
  TFieldGen = record
  var
    g: TGen;
    obj: PObj;
    o: TFieldOptions;
    ft: string;
    m, mn, mt, n, t: string;
    function GetTag: string;
    // Embedded types
    procedure GenType;
    procedure GenEnum;
    procedure GenMap(const pair: string);
    procedure GenMessage;
  public
    procedure Init(g: TGen; obj: PObj; o: TFieldOptions; const ft: string);
    procedure Gen;
  end;

procedure TFieldGen.Init(g: TGen; obj: PObj; o: TFieldOptions; const ft: string);
begin
  Self.g := g;
  Self.obj := obj;
  Self.m := obj.typ.declaration.name;
  Self.o := o;
  Self.ft := ft;
  mn := o.Msg.DelphiName;
  mt := o.Msg.AsType;
  n := obj.DelphiName;
  t := obj.AsType;
end;

procedure TFieldGen.Gen;
begin
  if o.Default <> '' then
  begin
    g.Wrln('if %s.F%s <> %s then', [m, t, o.Default]);
    g.Indent;
  end;
  case obj.typ.form of
    TTypeMode.tmDouble .. TTypeMode.tmSint64:
      GenType;
    TTypeMode.tmEnum:
      GenEnum;
    TTypeMode.tmMessage:
      GenMessage;
    TTypeMode.tmMap:
      GenMap(g.GetPair(g.mapvars, obj.typ, TGetMap.asVarUsing));
    else
      raise Exception.Create('unsupported field type');
  end;
  if o.Default <> '' then
    g.Dedent;
end;

function TFieldGen.GetTag: string;
begin
  if (ft = '1') or (ft = '2') then
    Result := ft
  else
    Result := mt + '.' + ft;
end;

procedure TFieldGen.GenType;
begin
  // Pb.writeString(TPerson.ftName, Person.Name);
  if o.rule <> TFieldRule.Repeated then
    g.Wrln('Pb.write%s(%s, %s.%s);', [AsCamel(m), GetTag, mn, n])
  else
  begin
    g.Wrln('h.Init;');
    g.Wrln('try');
    g.Wrln('  for i := 0 to %s.F%s.Count - 1 do', [mn, n]);
    case obj.typ.form of
      TTypeMode.tmInt32, TTypeMode.tmUint32, TTypeMode.tmSint32,
      TTypeMode.tmBool, TTypeMode.tmEnum:
        g.Wrln('    h.writeRawVarint32(%s.F%s[i]);', [mn, n]);
      TTypeMode.tmInt64, TTypeMode.tmUint64, TTypeMode.tmSint64:
        g.Wrln('    h.writeRawVarint64(%s.F%s[i]);', [mn, n]);
      TTypeMode.tmFixed64, TTypeMode.tmSfixed64, TTypeMode.tmDouble,
      TTypeMode.tmSfixed32, TTypeMode.tmFixed32, TTypeMode.tmFloat:
        g.Wrln('    h.writeRawData(%s.F%s[i], sizeof(%s));', [mn, n, t]);
      TTypeMode.tmString:
        g.Wrln('    h.writeRawString(%s.F%s[i]);', [mn, n]);
      TTypeMode.tmBytes:
        g.Wrln('    h.writeRawBytes(%s.F%s[i]);', [mn, n]);
    end;
    g.Wrln('  Pb.writeMessage(%s, h.Pb^);', [GetTag]);
    g.Wrln('finally');
    g.Wrln('  h.Free;');
    g.Wrln('end;');
  end;
end;

procedure TFieldGen.GenEnum;
begin
  if o.rule <> TFieldRule.Repeated then
    g.Wrln('Pb.writeInt32(%s, Ord(%s.%s));', [GetTag, mn, AsCamel(n)])
  else
  begin
    g.Wrln('h.Init;');
    g.Wrln('try');
    g.Wrln('  for i := 0 to %s.F%s.Count - 1 do', [mn, n]);
    g.Wrln('    h.writeRawVarint32(Ord(%s.%s));', [mn, AsCamel(n)]);
    g.Wrln('  Pb.writeMessage(%s, h.Pb^);', [GetTag]);
    g.Wrln('finally');
    g.Wrln('  h.Free;');
    g.Wrln('end;');
  end;
end;

procedure TFieldGen.GenMessage;
var s: string;
begin
  if o.rule <> TFieldRule.Repeated then
  begin
    if ft <> '2' then
    begin
      g.Wrln('if %s.F%s <> nil then', [mn, n]);
      g.Wrln('begin');
      g.Indent;
    end;
    g.Wrln('h.Init;');
    g.Wrln('try');
    g.Wrln('  h.Save%s(%s.%s);', [m, mn, n]);
    s := Format('  Pb.writeMessage(%s, h.Pb^);', [GetTag]);
    g.Wrln(s);
    g.Wrln('finally');
    g.Wrln('  h.Free;');
    g.Wrln('end;');
    if ft <> '2' then
    begin
      g.Dedent;
      g.Wrln('end;');
    end;
  end
  else
  begin
    n := AsCamel(Plural(n));
    g.Wrln('if %s.F%s.Count > 0 then', [mn, n]);
    g.Wrln('begin');
    g.Wrln('  h.Init;');
    g.Wrln('  try');
    g.Wrln('    for i := 0 to %s.F%s.Count - 1 do', [mn, n]);
    g.Wrln('    begin');
    g.Wrln('      h.Clear;');
    g.Wrln('      h.Save%s(%s.%s[i]);', [m, mn, n]);
    g.Wrln('      Pb.writeMessage(%s, h.Pb^);', [GetTag]);
    g.Wrln('    end;');
    g.Wrln('  finally');
    g.Wrln('    h.Free;');
    g.Wrln('  end;');
    g.Wrln('end;');
  end;
end;

procedure TFieldGen.GenMap(const pair: string);
var s: string;
begin
  if o.rule <> TFieldRule.Repeated then
  begin
    if ft <> '2' then
    begin
      g.Wrln('if %s.F%s <> nil then', [mn, n]);
      g.Wrln('begin');
      g.Indent;
    end;
    g.Wrln('h.Init;');
    g.Wrln('try');
    g.Wrln('  h.Save%s(%s.%s);', [m, mn, n]);
    s := Format('  Pb.writeMessage(%s, h.Pb^);', [GetTag]);
    g.Wrln(s);
    g.Wrln('finally');
    g.Wrln('  h.Free;');
    g.Wrln('end;');
    if ft <> '2' then
    begin
      g.Dedent;
      g.Wrln('end;');
    end;
  end
  else
  begin
    g.Wrln('h.Init;');
    g.Wrln('try');
    g.Wrln('  for %s in %s.F%s do', [pair, mn, n]);
    g.Wrln('  begin');
    g.Wrln('    h.Clear;');
    g.Wrln('    h.Save%s(Item);', [AsCamel(m)]);
    g.Wrln('    Pb.writeMessage(%s, h.Pb^);', [GetTag]);
    g.Wrln('  end;');
    g.Wrln('finally');
    g.Wrln('  h.Free;');
    g.Wrln('end;');
  end;
end;

procedure TGen.SaveMaps;
var
  typ: PType;
  map, key, value: PObj;
  s, t: string;
  ko, vo: TFieldOptions;

  procedure G(obj: PObj; o: TFieldOptions; const ft: string);
  var fg: TFieldGen;
  begin
    fg.Init(Self, obj, o, ft);
    fg.Gen;
  end;

begin
  pairMessage.cls := TMode.mType;
  pairMessage.name := 'Item';
  pairMessage.typ := @pairType;
  pairType.form := TTypeMode.tmMessage;
  pairType.declaration := @pairMessage;
  for typ in maps do
  begin
    map := typ.declaration;
    s := map.DelphiName;
    t := map.AsType;
    Wrln('procedure %s.Save%s(%s);',
      [GetBuilderName(False), map.DelphiName, GetPair(maps, typ, TGetMap.asParam)]);
    Wrln('var');
    Wrln('  h: TpbSaver;');
    Wrln('begin');
    Indent;
    try
      key := typ.dsc;
      ko := TFieldOptions.Create(key, @pairMessage, 1, TFieldRule.Singular);
      G(key, ko, '1');
      value := key.next;
      vo := TFieldOptions.Create(value, @pairMessage, 2, TFieldRule.Singular);
      G(value, vo, '2');
    finally
      Dedent;
    end;
    Wrln('end;');
    Wrln('');
  end;
end;

function TGen.FieldTag(obj: PObj): string;
var
  n: string;
  o: TFieldOptions;
begin
(*
   ftId | ftPhones
*)
  o := obj.aux as TFieldOptions;
  n := AsCamel(obj.name);
  if o.Rule = TFieldRule.Repeated then
    n := Plural(n);
  Result := 'ft' + n;
end;

procedure TGen.FieldTagDecl(obj: PObj);
var o: TFieldOptions;
begin
(*
   ftId = 1;
*)
  o := obj.aux as TFieldOptions;
  Wrln('%s = %d;', [FieldTag(obj), o.Tag]);
end;

procedure TGen.FieldDecl(obj: PObj);
var
  n, t: string;
  o: TFieldOptions;
begin
(*
   FId: Integer;
*)
  o := obj.aux as TFieldOptions;
  n := obj.AsField;
  t := obj.AsType;
  if o.Rule = TFieldRule.Repeated then
  begin
    n := Plural(n);
    t := Format(RepeatedCollection, [t]);
  end;
  Wrln('%s: %s;', [n, t]);
end;

procedure TGen.FieldProperty(obj: PObj);
var
  n, f, t, s: string;
  ro: Boolean;
  o: TFieldOptions;
begin
(*
  // here can be field comment
  Id: Integer read FId write FId;
*)
  o := obj.aux as TFieldOptions;
  ro := o.ReadOnly;
  n := obj.DelphiName;
  f := obj.AsField;
  t := obj.AsType;
  if o.Rule = TFieldRule.Repeated then
  begin
    ro := True;
    n := Plural(obj.name);
    t := Format(RepeatedCollection, [t]);
    f := 'F' + n;
    if TObjDesc.Keywords.IndexOf(f) >= 0 then
      f := '&' + f;
  end;
  s := Format('property %s: %s read %s', [n, t, f]);
  if ro then
    s := s + ';'
  else
    s := s + Format(' write %s;', [f]);
  Wrln(s);
end;

procedure TGen.FieldInit(obj: PObj);
var
  f, t: string;
  o: TFieldOptions;
begin
(*
   repeating fields
     FPhones := TList<TPhoneNumber>.Create;
   map fields
     FTags := TDictionary<Integer, TpbField>.Create;
   fields for which the default value is not empty.
     FTyp := ptHOME;
*)
  o := obj.aux as TFieldOptions;
  f := obj.AsField;
  t := obj.AsType;
  if o.Default <> '' then
    Wrln('%s := %s;', [f, o.Default])
  else if o.Rule = TFieldRule.Repeated then
    Wrln('%s := ' + RepeatedCollection + '.Create;', [Plural(f), t])
  else if obj.typ.form = TTypeMode.tmMap then
    Wrln('%s := %s.Create;', [f, t]);
end;

procedure TGen.FieldFree(obj: PObj);
var
  f: string;
  o: TFieldOptions;
begin
  o := obj.aux as TFieldOptions;
  f := obj.AsField;
  if o.Rule = TFieldRule.Repeated then
    Wrln('%s.Free;', [Plural(f)])
  else if obj.typ.form = TTypeMode.tmMap then
    Wrln('%s.Free;', [f])
end;

function TGen.GetRead(obj: PObj): string;
var
  msg: PObj;
  m, n: string;
  key, value: PObj;
begin
  msg := obj.typ.declaration;
  m := msg.DelphiName;
  n := obj.DelphiName;
  case obj.typ.form of
    TTypeMode.tmMessage:
      Result := Format('Load%s(%s.Create)', [m, msg.AsType]);
    TTypeMode.tmEnum:
      Result := Format('T%s(Pb.readInt32)', [m]);
    TTypeMode.tmMap:
      begin
        key := obj.typ.dsc;
        value := key.next;
        Result := Format('%s, %s', [GetRead(key), GetRead(value)]);
      end;
    else
      Result := Format('Pb.read%s', [AsCamel(msg.name)]);
  end;
end;

procedure TGen.FieldRead(obj: PObj);
var
  o: TFieldOptions;
  msg: PObj;
  w, mn, mt, m, n: string;

  procedure GenType;
  begin
    if o.Rule <> TFieldRule.Repeated then
    begin
      Wrln('begin');
      Wrln('  Assert(wireType = TWire.%s);', [w]);
      Wrln('  %s.%s := %s;', [o.Msg.name, n, GetRead(obj)]);
      Wrln('end;');
    end
    else
    begin
      Wrln('begin');
      Indent;
      Wrln('Pb.Push;');
      Wrln('try');
      Wrln('  while not Pb.Eof do');
      case obj.typ.form of
        TTypeMode.tmInt32, TTypeMode.tmUint32, TTypeMode.tmSint32,
        TTypeMode.tmBool, TTypeMode.tmEnum:
          Wrln('    Pb.readRawVarint32(%s.F%s[i]);', [mn, n]);
        TTypeMode.tmInt64, TTypeMode.tmUint64, TTypeMode.tmSint64:
          Wrln('    Pb.readRawVarint64(%s.F%s[i]);', [mn, n]);
        TTypeMode.tmFixed64, TTypeMode.tmSfixed64, TTypeMode.tmDouble,
        TTypeMode.tmSfixed32, TTypeMode.tmFixed32, TTypeMode.tmFloat:
          Wrln('    Pb.readRawData(%s.F%s[i], sizeof(%s));', [mn, n, mt]);
        TTypeMode.tmString:
          Wrln('    Pb.readRawString(%s.F%s[i]);', [mn, n]);
        TTypeMode.tmBytes:
          Wrln('    Pb.readRawBytes(%s.F%s[i]);', [mn, n]);
      end;
      n := 'F' + Plural(obj.name);
      Wrln('  %s.%s.Add(%s);', [o.Msg.name, n, GetRead(obj)]);
      Wrln('finally');
      Wrln('  Pb.Pop;');
      Wrln('end;');
      Dedent;
      Wrln('end;');
    end;
  end;

  procedure GenEnum;
  begin
    if o.Rule <> TFieldRule.Repeated then
    begin
      Wrln('begin');
      Wrln('  Assert(wireType = TWire.%s);', [w]);
      Wrln('  %s.%s := %s;', [o.Msg.name, n, GetRead(obj)]);
      Wrln('end;');
    end
    else
    begin
      Wrln('begin');
      Indent;
      Wrln('Pb.Push;');
      Wrln('try');
      Wrln('  while not Pb.Eof do');
      n := 'F' + Plural(obj.name);
      Wrln('    %s.%s.Add(%s);', [o.Msg.name, n, GetRead(obj)]);
      Wrln('finally');
      Wrln('  Pb.Pop;');
      Wrln('end;');
      Dedent;
      Wrln('end;');
    end;
  end;

  procedure GenMessage;
  begin
    Wrln('begin');
    Indent;
    Wrln('Assert(wireType = TWire.LENGTH_DELIMITED);');
    Wrln('Pb.Push;');
    Wrln('try');
    if o.Rule <> TFieldRule.Repeated then
      Wrln('  %s.F%s := %s;', [o.Msg.name, n, GetRead(obj)])
    else
    begin
      n := 'F' + Plural(obj.name);
      Wrln('  %s.%s.Add(%s);', [o.Msg.name, n, GetRead(obj)]);
    end;
    Wrln('finally');
    Wrln('  Pb.Pop;');
    Wrln('end;');
    Dedent;
    Wrln('end;');
  end;

  procedure GenMap;
  begin
    Wrln('%s.%s.AddOrSetValue(%s);', [o.Msg.name, n, GetRead(obj)]);
    // Map fields cannot be repeated.
  end;

begin
  o := obj.aux as TFieldOptions;
  mn := o.Msg.DelphiName;
  mt := o.Msg.AsType;
  msg := obj.typ.declaration;
  w := TWire.Names[GetWireType(obj.typ.form)];
  m := msg.DelphiName;
  n := obj.DelphiName;
  Indent;
  try
    Wrln('%s.%s:', [mt, FieldTag(obj)]);
    Indent;
    try
      case obj.typ.form of
        TTypeMode.tmMessage: GenMessage;
        TTypeMode.tmEnum: GenEnum;
        TTypeMode.tmMap: GenMap;
        else GenType;
      end;
    finally
      Dedent;
    end;
  finally
    Dedent;
  end;
end;

procedure TGen.FieldWrite(obj: PObj);
var
  fg: TFieldGen;
begin
  Assert(obj.cls = TMode.mField);
  fg.Init(Self, obj, obj.aux as TFieldOptions, FieldTag(obj));
  fg.Gen;
end;

procedure TGen.FieldReflection(obj: PObj);
begin
  raise Exception.Create('under consruction');
end;

procedure TGen.GenComment(const comment: string);
var
  s: string;
begin
  for s in comment.Split([#13#10], TStringSplitOptions.None) do
    Wrln('// ' + s)
end;

function TGen.GetPair(maptypes: TMapTypes; typ: PType; mas: TGetMap): string;
var
  msg, key, value: PObj;
  i: Integer;
  s: string;
begin
  msg := typ.declaration;
  Assert((msg.cls = TMode.mType) and (typ.form = TTypeMode.tmMap));
  i := maptypes.IndexOf(typ);
  if (i > 0) and (mas = TGetMap.asVarUsing) then
    s := Format('Item%d', [i])
  else
    s := 'Item';
  if mas = TGetMap.asVarUsing then exit(s);
  key := typ.dsc;
  value := key.next;
  Result := Format('%s: TPair<%s, %s>', [s, key.AsType, value.AsType]);
end;

function TGen.GetBuilderName(Load: Boolean): string;
begin
  if Load then
    Result := 'TLoadHelper'
  else
    Result := 'TSaveHelper';
end;

procedure TGen.BuilderDecl(Load: Boolean);
const
  Names: array [Boolean] of string = ('TpbSaver', 'TpbLoader');
var
  obj, x, m: PObj;
  typ: PType;
  s: string;
begin
  Wrln('%s = record helper for %s', [GetBuilderName(Load), Names[Load]]);
  Wrln('public');
  Indent;
  try
    maps.Clear;
    obj := tab.Module.Obj; // root proto file
    x := obj.dsc;
    while x <> nil do
    begin
      if x.cls = TMode.mType then
        if Load then
          LoadDecl(x)
        else
          SaveDecl(x);
      x := x.next;
    end;
    if not Load then
      for typ in maps do
      begin
        m := typ.declaration;
        s := GetPair(maps, typ, TGetMap.asParam);
        Wrln('procedure Save%s(%s);', [m.DelphiName, s]);
      end;
  finally
    Dedent;
  end;
  Wrln('end;');
  Wrln;
end;

procedure TGen.BuilderImpl;
var
  obj, x: PObj;
begin
  obj := tab.Module.Obj; // root proto file
  x := obj.dsc;
  while x <> nil do
  begin
    if x.cls = TMode.mType then
      if Load then
        LoadImpl(x)
      else
        SaveImpl(x);
    x := x.next;
  end;
  if not Load then
    SaveMaps;
end;

{$EndRegion}

end.
