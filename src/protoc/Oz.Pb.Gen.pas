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
    // get read statement
    function GetRead(obj: PObj): string;
    // Field read from buffer
    procedure FieldRead(obj: PObj);
    // write field to buffer
    procedure FieldWrite(obj: PObj);
    // field reflection
    procedure FieldReflection(obj: PObj);
    procedure GenComment(const comment: string);

    // Message code
    procedure LocalVars(msg: PObj);
    procedure MessageDecl(msg: PObj);
    procedure MessageImpl(msg: PObj);
    procedure LoadDecl(msg: PObj);
    procedure SaveDecl(msg: PObj);
    procedure LoadImpl(msg: PObj);
    procedure SaveImpl(msg: PObj);

    // Top level code
    procedure ModelDecl;
    procedure ModelImpl;
    procedure BuilderDecl;
    procedure BuilderImpl;
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
    BuilderDecl;
  finally
    Dedent;
  end;
  Wrln('implementation');
  Wrln;
  ModelImpl;
  BuilderImpl;
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
    typ := x.typ;
    if x.cls = TMode.mType then
      case typ.form of
        TTypeMode.tmEnum: EnumDecl(x);
        TTypeMode.tmMessage: MessageDecl(x);
        TTypeMode.tmMap: MapDecl(x);
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
  Assert((msg.cls = TMode.mType) and (typ.form = TTypeMode.tmMessage));
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
  Assert((msg.cls = TMode.mType) and (typ.form = TTypeMode.tmMessage));
  Wrln('procedure Save%s(%s: %s);', [msg.DelphiName, msg.name, msg.AsType]);
  x := msg.dsc;
  while x <> tab.Guard do
  begin
    typ := x.typ;
    if (x.cls = TMode.mType) and (typ.form = TTypeMode.tmMessage) then
      SaveDecl(x);
    x := x.next;
  end;
end;

procedure TGen.LoadImpl(msg: PObj);
var
  x: PObj;
  typ: PType;
  s, t: string;
begin
  typ := msg.typ;
  Assert((msg.cls = TMode.mType) and (typ.form = TTypeMode.tmMessage));
  s := msg.DelphiName;
  t := msg.AsType;
  Wrln('function TpbBuilder.Load%s(%s: %s): %s;', [s, msg.name, t, t]);
  Wrln('var');
  Wrln('  fieldNumber, wireType: integer;');
  Wrln('  tag: TpbTag;');
  Wrln('begin');
  Indent;
  Wrln('Result := %s;', [s]);
  Wrln('tag := Pbi.readTag;');
  Wrln('while tag.v <> 0 do');
  Wrln('begin');
  Indent;
  Wrln('wireType := tag.WireType;');
  Wrln('fieldNumber := tag.FieldNumber;');
  Wrln('tag := Pbi.readTag;');
  Wrln('case fieldNumber of');
  x := typ.dsc;
  while x <> tab.Guard do
  begin
    FieldRead(x);
    x := x.next;
  end;
  Wrln('  else');
  Wrln('    Pbi.skipField(tag);');
  Wrln('end;');
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
  s, t: string;
begin
  typ := msg.typ;
  Assert((msg.cls = TMode.mType) and (typ.form = TTypeMode.tmMessage));
  s := msg.DelphiName;
  t := msg.AsType;
  Wrln('procedure TpbBuilder.Save%s(%s: %s);',  [s, msg.name, t]);
  Wrln('var');
  Wrln('  i: Integer;');
  Wrln('  pb: TpbOutput;');
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
      Result := Format('T%s(Pbi.readInt32)', [m]);
    TTypeMode.tmMap:
      begin
        key := obj.typ.dsc;
        value := key.next;
        Result := Format('%s, %s', [GetRead(key), GetRead(value)]);
      end;
    else
      Result := Format('Pbi.read%s', [AsCamel(msg.name)]);
  end;
end;

procedure TGen.FieldRead(obj: PObj);
var
  o: TFieldOptions;
  msg: PObj;
  w, mt, m, n: string;

  procedure GenMessage;
  begin
    if o.Rule <> TFieldRule.Repeated then
    begin
      Wrln('  %s.F%s := %s;', [o.Msg.name, n, GetRead(obj)]);
    end
    else
    begin
      n := 'F' + Plural(obj.name);
      Wrln('  %s.%s.Add(%s);', [o.Msg.name, n, GetRead(obj)]);
    end;
  end;

  procedure GenMap;
  begin
    Wrln('  %s.%s.AddOrSetValue(%s);', [o.Msg.name, n, GetRead(obj)]);
  end;

  procedure GenEnum;
  begin
    Wrln('  begin');
    Wrln('    Assert(wireType = TWire.%s);', [w]);
    Wrln('    %s.%s := %s;', [o.Msg.name, n, GetRead(obj)]);
    Wrln('  end;');
  end;

  procedure GenType;
  begin
    Wrln('  begin');
    Wrln('    Assert(wireType = TWire.%s);', [w]);
    Wrln('    %s.%s := %s;', [o.Msg.name, n, GetRead(obj)]);
    Wrln('  end;');
  end;

begin
  o := obj.aux as TFieldOptions;
  mt := o.Msg.AsType;
  msg := obj.typ.declaration;
  w := TWire.Names[GetWireType(obj.typ.form)];
  m := msg.DelphiName;
  n := obj.DelphiName;
  Indent;
  try
    Wrln('%s.%s:', [mt, FieldTag(obj)]);
    case obj.typ.form of
      TTypeMode.tmMessage: GenMessage;
      TTypeMode.tmEnum: GenEnum;
      TTypeMode.tmMap: GenMap;
      else GenType;
    end;
  finally
    Dedent;
  end;
end;

procedure TGen.FieldWrite(obj: PObj);
var
  o: TFieldOptions;
  msg: PObj;
  m, mn, mt, n, t: string;

  // Embedded types
  procedure GenType;
  begin
    // Pbo.writeString(TPerson.ftName, Person.Name);
    Wrln('Pbo.write%s(%s.%s, %s.%s);', [AsCamel(m), mt, FieldTag(obj), mn, n]);
  end;

  procedure GenEnum;
  begin
    Wrln('Pbo.writeInt32(%s.%s, Ord(%s.%s));', [mt, FieldTag(obj), mn, AsCamel(n)]);
  end;

  procedure GenMessage;
  begin
    if o.Rule <> TFieldRule.Repeated then
    begin
      Wrln('if %s.F%s <> nil then', [mn, n]);
      Wrln('begin');
      Wrln('  pb := TpbOutput.From;');
      Wrln('  try');
      Wrln('    Save%s(%s.%s);', [m, mn, n]);
      Wrln('    Pbo.writeMessage(%s.ft%s, pb);', [mt, n]);
      Wrln('  finally');
      Wrln('    pb.Free;');
      Wrln('  end;');
      Wrln('end;');
    end
    else
    begin
      n := AsCamel(Plural(n));
      Wrln('if %s.F%s.Count > 0 then', [mn, n]);
      Wrln('begin');
      Wrln('  pb := TpbOutput.From;');
      Wrln('  try');
      Wrln('    for i := 0 to %s.F%s.Count - 1 do', [mn, n]);
      Wrln('    begin');
      Wrln('      pb.Clear;');
      Wrln('      Save%s(%s.%s[i]);', [m, mn, n]);
      Wrln('      Pbo.writeMessage(%s.ft%s, pb);', [mt, n]);
      Wrln('    end;');
      Wrln('  finally');
      Wrln('    pb.Free;');
      Wrln('  end;');
      Wrln('end;');
    end;
  end;

  procedure GenMap;
  begin
    Wrln('pb := TpbOutput.From;');
    Wrln('try');
    Wrln('  for Item in %s.F%s do', [mn, n]);
    Wrln('  begin');
    Wrln('    pb.Clear;');
    Wrln('    Save%s(Item);', [AsCamel(m)]);
    Wrln('    Pbo.writeMessage(%s.ft%s, pb);', [mt, n]);
    Wrln('  end;');
    Wrln('finally');
    Wrln('  pb.Free;');
    Wrln('end;');
  end;

begin
  o := obj.aux as TFieldOptions;
  msg := obj.typ.declaration;
  m := msg.name;
  mn := o.Msg.DelphiName;
  mt := o.Msg.AsType;
  n := obj.DelphiName;
  t := obj.AsType;
  if o.Default <> '' then
  begin
    Wrln('if %s.F%s <> %s then', [m, t]);
    Indent;
  end;
  case obj.typ.form of
    TTypeMode.tmDouble .. TTypeMode.tmSint64:
      GenType;
    TTypeMode.tmEnum:
      GenEnum;
    TTypeMode.tmMessage:
      GenMessage;
    TTypeMode.tmMap:
      GenMap;
    else
      raise Exception.Create('unsupported field type');
  end;
  if o.Default <> '' then
    Dedent;
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

procedure TGen.LocalVars(msg: PObj);
var
  x: PObj;
  typ: PType;
begin
  x := msg.dsc;
  while x <> tab.Guard do
  begin
    typ := x.typ;
    if (x.cls = TMode.mType) and (typ.form = TTypeMode.tmMessage) then
      Wrln('  %s: %s;', [x.name, x.AsType]);
    x := x.next;
  end;
end;

procedure TGen.BuilderDecl;
var
  obj, x: PObj;
begin
  Wrln('TPbBuilder = class(TpbCustomBuilder)');
  Wrln('public');
  Indent;
  try
    obj := tab.Module.Obj; // root proto file
    x := obj.dsc;
    while x <> nil do
    begin
      if (x.cls = TMode.mType) and (x.typ.form = TTypeMode.tmMessage) then
      begin
        LoadDecl(x);
        SaveDecl(x);
      end;
      x := x.next;
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
    if (x.cls = TMode.mType) and (x.typ.form = TTypeMode.tmMessage) then
    begin
      LoadImpl(x);
      SaveImpl(x);
    end;
    x := x.next;
  end;
end;

{$EndRegion}

end.
