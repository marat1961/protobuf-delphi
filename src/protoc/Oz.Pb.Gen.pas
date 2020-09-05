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

    // Field code
    // constant declarations for field tags
    procedure FieldTagDecl(obj: PObj);
    // field declaration
    procedure FieldDecl(obj: PObj);
    // field property
    procedure FieldProperty(obj: PObj);
    // Initialize field value
    procedure FieldInit(obj: PObj);
    // Free field
    procedure FieldFree(obj: PObj);
    // Field read from buffer
    procedure FieldRead(obj: PObj);
    // write field to buffer
    procedure FieldWrite(obj: PObj);
    // field reflection
    procedure FieldReflection(obj: PObj);

    procedure LoadMessage(msg: PObj);
    procedure GenComment(const comment: string);

    // Message code
    procedure MessageDecl(msg: PObj);
    procedure MessageImpl(msg: PObj);
    procedure ReaderDecl(msg: PObj);
    procedure ReaderImpl(msg: PObj);
    procedure WriterDecl(msg: PObj);
    procedure WriterImpl(msg: PObj);

    // Top level code
    procedure ModelDecl;
    procedure ModelImpl;
    procedure IoDecl;
    procedure IoImpl;
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
  ns := Tab.Module.NameSpace;
  Wrln('unit %s;', [ns]);
  Wrln;
  Wrln('interface');
  Wrln;
  Wrln('uses');
  Wrln('  System.Classes, System.SysUtils, Generics.Collections,');
  Wrln('  pbPublic, pbInput, pbOutput;');
  Wrln;
  Wrln('type');
  Wrln;
  Indent;
  try
    ModelDecl;
    IoDecl;
  finally
    Dedent;
  end;
  Wrln('implementation');
  Wrln;
  ModelImpl;
  IoImpl;
  Wrln('end;');
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

procedure TGen.ReaderDecl(msg: PObj);
var
  typ: PType;
  s, t: string;
begin
  typ := msg.typ;
  Assert((msg.cls = TMode.mType) and (typ.form = TTypeMode.tmMessage));
  s := msg.DelphiName;
  t := msg.AsType;
  Wrln('%sReader = class', [t]);
  Wrln('private');
  Wrln('  FPb: TProtoBufInput;');
  Wrln('  procedure Load%s(%s: %s);', [s, msg.name, t]);
  Wrln('public');
  Wrln('  constructor Create;');
  Wrln('  destructor Destroy; override;');
  Wrln('  function GetPb: TProtoBufInput;');
  Wrln('  procedure Load(%s: %s);', [s, t]);
  Wrln('end;');
  Wrln;
end;

procedure TGen.ReaderImpl(msg: PObj);
var
  x: PObj;
  typ: PType;
  s, t: string;
begin
  typ := msg.typ;
  Assert((msg.cls = TMode.mType) and (typ.form = TTypeMode.tmMessage));
  s := msg.DelphiName;
  t := msg.AsType;
  Wrln('function %sReader.GetPb: TProtoBufOutput;', [t]);
  Wrln('begin');
  Wrln('  Result := FPb;');
  Wrln('end;');
  Wrln;
  Wrln('procedure %sReader.Load(%s: %s);',  [t, s, t]);
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
  x := typ.dsc;
  while x <> tab.Guard do
  begin
    FieldRead(x);
    x := x.next;
  end;
  Wrln('else');
  Wrln('  FPb.skipField(tag);');
  Dedent;
  Wrln('end;');
  Dedent;
  Wrln('end;');
  Wrln('');
end;

procedure TGen.WriterDecl(msg: PObj);
var
  typ: PType;
  s, t: string;
begin
  typ := msg.typ;
  Assert((msg.cls = TMode.mType) and (typ.form = TTypeMode.tmMessage));
  s := msg.DelphiName;
  t := msg.AsType;
  Wrln('%sWriter = class', [t]);
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

procedure TGen.WriterImpl(msg: PObj);
var
  typ: PType;
  x: PObj;
  s, t: string;
begin
  typ := msg.typ;
  Assert((msg.cls = TMode.mType) and (typ.form = TTypeMode.tmMessage));
  s := msg.DelphiName;
  t := msg.AsType;
  Wrln('function %sWriter.GetPb: TProtoBufOutput;', [t]);
  Wrln('begin');
  Wrln('  Result := FPb;');
  Wrln('end');
  Wrln;
  Wrln('procedure %sWriter.Write(%s: %s);', [t, s, t]);
  Wrln('var');
  Wrln('  i: Integer;');
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

procedure TGen.FieldTagDecl(obj: PObj);
var 
  n: string;
  o: TFieldOptions;
begin
(*
   ftId = 1;
*)
  o := obj.aux as TFieldOptions;
  n := AsCamel(obj.name);
  if o.Rule = TFieldRule.Repeated then
    n := Plural(n);
  Wrln('ft%s = %d;', [n, o.Tag]);
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
    Wrln('%s := ' + RepeatedCollection + '.Create;', [f, t])
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
  if (o.Rule = TFieldRule.Repeated) or (obj.typ.form = TTypeMode.tmMap) then
    Wrln('%s.Free;', [f]);
end;

procedure TGen.FieldRead(obj: PObj);
var
  n, t: string;
  o: TFieldOptions;
begin
(*
  TPerson.ftName:
    begin
      Assert(wireType = TWire.LENGTH_DELIMITED);
      person.Name := pb.readString;
    end;

    Wrln('%s.ft%s:', [msg.DelphiName, AsCamel(x.Name)]);
    Indent;
    Dedent;

*)
  o := obj.aux as TFieldOptions;
  n := obj.DelphiName;
  t := obj.typ.declaration.AsType;
  Indent;
  try
    Wrln('%s.ft%s:', [o.Msg.AsType, n]);
    Indent;
    try
      Wrln('%s.%s := FPb.read%s;', [o.Msg.name, n, AsCamel(t)]);
    finally
      Dedent;
    end;
  finally
    Dedent;
  end;
end;

procedure TGen.FieldWrite(obj: PObj);
var
  m, t: string;
  o: TFieldOptions;

  procedure Process;
  begin
    case obj.typ.form of
      TTypeMode.tmDouble .. TTypeMode.tmSint64: // Embedded types
        Wrln('FPb.Write%s(%s.ft%s, %s.%s);',
          [AsCamel(obj.name), m, obj.name, o.msg.name, obj.name]);
      TTypeMode.tmEnum:
        Wrln('FPb.Write Enum');
      TTypeMode.tmMessage:
        Wrln('FPb.Write Message');
      TTypeMode.tmMap:
        Wrln('FPb.Write Map');
      else
        raise Exception.Create('unsupported field type');
    end;
  end;

begin
(*
  FPb.WriteString(TPerson.ftName, Person.Name);
*)
  o := obj.aux as TFieldOptions;
  m := AsCamel(o.Msg.Name);
  t := obj.AsType;
  if o.Default = '' then
    Process
  else
  begin
    // if Phone.FTyp <> ptHOME then
    Wrln('if %s.F%s <> %s then', [m, t]);
    Indent;
    try
      Process;
    finally
      Dedent;
    end;
  end;
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
//        LoadMessage(obj);
    end;
    obj := obj.next;
  end;
end;

procedure TGen.IoDecl;
var
  obj, x: PObj;
begin
  obj := tab.Module.Obj; // root proto file
  x := obj.dsc;
  while x <> nil do
  begin
    if (x.cls = TMode.mType) and (x.typ.form = TTypeMode.tmMessage) then
    begin
      ReaderDecl(x);
      WriterDecl(x);
    end;
    x := x.next;
  end;
end;

procedure TGen.IoImpl;
var
  obj, x: PObj;
begin
  obj := tab.Module.Obj; // root proto file
  x := obj.dsc;
  while x <> nil do
  begin
    if (x.cls = TMode.mType) and (x.typ.form = TTypeMode.tmMessage) then
    begin
      ReaderImpl(x);
      WriterImpl(x);
    end;
    x := x.next;
  end;
end;

{$EndRegion}

end.
