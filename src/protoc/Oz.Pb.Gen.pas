unit Oz.Pb.Gen;

interface

uses
  System.Classes, System.SysUtils, System.Math,
  Oz.Cocor.Utils, Oz.Cocor.Lib, pbPublic, Oz.Pb.Tab;

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

    procedure GenComment(const ñ: string);
    procedure LoadMessage(msg: TpbMessage);
    procedure WriterInterface(msg: TpbMessage);
    procedure ReaderInterface(msg: TpbMessage);
    procedure WriterImplementation(msg: TpbMessage);
    procedure ReaderImplementation(msg: TpbMessage);
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

{$Region 'TpbFieldHelper'}

type

  TpbFieldHelper = class helper for TpbField
    (* constant declarations for field tags
       ftId = 1;
    *)
    procedure AsTagDeclarations(gen: TGen);

    (* field declaration
       FId: Integer;
    *)
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

{$Region 'TpbMessageHelper'}

  TpbMessageHelper = class helper for TpbMessage
    procedure AsDeclaration(gen: TGen);
    procedure AsImplementation(gen: TGen);
    procedure AsWrite(gen: TGen);
    procedure AsRead(gen: TGen);
  end;

{$EndRegion}

{$Region 'TpbEnumHelper'}

  TpbEnumHelper = class helper for TpbEnum
    procedure AsDeclaration(gen: TGen);
  end;

{$EndRegion}

{$Region 'TpbFieldHelper'}

procedure TpbFieldHelper.AsTagDeclarations(gen: TGen);
begin
  gen.Wr('%s = %d;', [AsCamel(Name), Tag])
end;

procedure TpbFieldHelper.AsDeclaration(gen: TGen);
var n, t: string;
begin
  n := AsCamel(Name);
  t := Typ.DelphiName;
  if Rule = TFieldRule.Repeated then
    gen.Wr('%ss: TList<T%s>;', [n, t])
  else
    gen.Wr('%s: %s;', [n, t]);
end;

procedure TpbFieldHelper.AsProperty(gen: TGen);
var n, t: string;
begin
  n := AsCamel(Name);
  t := Typ.DelphiName;
  if Rule = TFieldRule.Repeated then
    gen.Wr('%ss: TList<T%s> read F%s;', [n, t, n])
  else
    gen.Wr('%s: %s read F%s write F%s;', [n, t, n, n]);
end;

procedure TpbFieldHelper.AsReflection(gen: TGen);
begin
  raise Exception.Create('under consruction');
end;

procedure TpbFieldHelper.AsInit(gen: TGen);
var
  n, t, k, v: string;
begin
  n := AsCamel(Name);
  t := Typ.DelphiName;
  if options.Default <> '' then
    gen.Wrln('F%s := %s;', [n, options.Default])
  else if Rule = TFieldRule.Repeated then
    gen.Wrln('F%s := TList<%Ts>.Create;', [n, t])
  else if typ.TypMode = TTypeMode.tmMap then
  begin
    k := 'keyType';
    v := 'valueType';
    gen.Wrln('F%s := TDictionary<%s, %s>.Create;', [n, k, v]);
  end;
end;

procedure TpbFieldHelper.AsFree(gen: TGen);
begin
  if (Rule = TFieldRule.Repeated) or (typ.TypMode = TTypeMode.tmMap) then
    gen.Wrln('F%s.Free;', [AsCamel(Name)]);
end;

procedure TpbFieldHelper.AsRead(gen: TGen);
var
  m, n, s: string;
begin
  m := Msg.DelphiName;
  n := AsCamel(Typ.Name);
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

procedure TpbFieldHelper.AsWrite(gen: TGen);
var
  m, f, def: string;

  procedure Process;
  begin
    case Typ.TypMode of
      TTypeMode.tmDouble .. TTypeMode.tmSint64: // Embedded types
        gen.Wrln('FPb.Write%s(%s.ft%s, %s.%s);',
          [Typ.name, m, Name, msg.Name, Name]);
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
  m := AsCamel(Self.Msg.Name);
  f := Self.Typ.DelphiName;
  def := Self.Options.Default;
  if def = '' then
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

{$Region 'TpbMessageHelper'}

procedure TpbMessageHelper.AsDeclaration(gen: TGen);
var
  m: TpbMessage;
  f: TpbField;
  i: Integer;
begin
  // generate nested messages
  if em.Messages.Count > 0 then
  begin
    for i := 0 to em.Messages.Count - 1 do
    begin
      m := em.Messages[i];
      m.AsDeclaration(gen);
    end;
  end;

  gen.Wrln('%s = class', [DelphiName]);

  // generate field tag definitions
  gen.Wrln('const');
  gen.Indent;
  try
    for i := 0 to Fields.Count - 1 do
    begin
      f := Fields[i];
      gen.Wrln('ft%s = %d;', [f.Name, f.tag]);
    end;
  finally
    gen.Dedent;
  end;

  // generate field declarations
  gen.Wrln('private');
  gen.Indent;
  try
    for i := 0 to Fields.Count - 1 do
    begin
      f := Fields[i];
      f.AsDeclaration(gen);
    end;
  finally
    gen.Dedent;
  end;

  gen.Wrln('public');
  gen.Indent;
  try
    gen.Wrln('constructor Create;');
    gen.Wrln('destructor Destoy; override;');
    gen.Wrln;
    for i := 0 to Fields.Count - 1 do
    begin
      f := Fields[i];
      f.AsProperty(gen);
    end;
  finally
    gen.Dedent;
  end;
  gen.Wrln('end;'); // class
  gen.Wrln;
end;

procedure TpbMessageHelper.AsImplementation(gen: TGen);
var
  i: Integer;
  t, v: string;
  f: TpbField;
begin
  // parameterless constructor
  t := DelphiName;
  gen.Wrln;
  gen.Wrln('constructor %s.Create;', [t]);
  gen.Wrln('begin');
  gen.Indent;
  try
    gen.Wrln('inherited Create;');
    for i := 0 to Fields.Count - 1 do
      Fields[i].AsInit(gen);
  finally
    gen.Dedent;
  end;
  gen.Wrln('end;');
  gen.Wrln;

  gen.Wr('destructor %s.Destroy;', [DelphiName]);
  gen.Wrln('begin');
  gen.Indent;
  try
    for i := 0 to Fields.Count - 1 do
      Fields[i].AsFree(gen);
    gen.Wrln('inherited Destroy;');
  finally
    gen.Dedent;
  end;
  gen.Wrln('end;');

  for i := 0 to Fields.Count - 1 do
  begin
    f := Fields[i];
    gen.Wrln('F%.s := %s;', [AsCamel(f.Name) + 's', AsCamel(f.Name)]);
  end;
  gen.Dedent;
  gen.Wrln('end;');
  gen.Wrln;

  gen.WriterImplementation(Self);
  gen.ReaderImplementation(Self);
end;

procedure TpbMessageHelper.AsRead(gen: TGen);
begin

end;

procedure TpbMessageHelper.AsWrite(gen: TGen);
var
  i: Integer;
  f: TpbField;
  m: TpbMessage;
begin
  for i := 0 to Fields.Count - 1 do
  begin
    f := Fields[i];
    f.AsWrite(gen);
  end;
end;

{$EndRegion}

{$Region 'TpbEnumHelper'}

procedure TpbEnumHelper.AsDeclaration(gen: TGen);
var
  i: Integer;
  ev: TEnumValue;
begin
  gen.Wrln('T%s = (', [Name]);
  for i := 0 to Enums.Count - 1 do
  begin
    ev := Enums[i];
    gen.Wr('  %s=%d', [ev.Name, ev.IntVal]);
    if i < Enums.Count - 1 then
      gen.Wrln(',')
    else
      gen.Wrln(');');
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
  s: string;
  i: Integer;
  em: Tem;
  e: TpbEnum;
  m: TpbMessage;
begin
  em := Tab.Module.Em;
  s := Tab.Module.NameSpace;
  Wrln('unit %s;', [s]);
  Wrln;
  Wrln('interface');
  Wrln;
  Wrln('uses');
  Wrln('  System.Classes, System.SysUtils, Generics.Collections,');
  Wrln('  pbPublic, pbInput, pbOutput;');
  Wrln;
  Wrln('type');
  Wrln;
  for i := 0 to em.Enums.Count - 1 do
  begin
    e := em.Enums[i];
    e.AsDeclaration(Self);
  end;
  for i := 0 to em.Messages.Count - 1 do
  begin
    m := em.Messages[i];
    m.AsDeclaration(Self);
  end;
  Wrln;
  Wrln('implementation');
  Wrln;
  for i := 0 to em.Messages.Count - 1 do
  begin
    m := em.Messages[i];
    m.AsImplementation(Self);
  end;
  Wrln('end;');
end;

function TGen.GetCode: string;
begin
  Result := sb.ToString
end;

procedure TGen.Wr(const s: string);
begin
  sb.Append(s)
end;

procedure TGen.Wr(const f: string; const Args: array of const);
begin
  sb.AppendFormat(f, Args);
end;

procedure TGen.Wrln;
begin
  sb.AppendLine
end;

procedure TGen.Wrln(const s: string);
begin
  sb.AppendLine(s);
end;

procedure TGen.Wrln(const f: string; const Args: array of const);
begin
  sb.AppendFormat(''.PadRight(IndentLevel * 2, ' ') + f, Args);
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

procedure TGen.GenComment(const ñ: string);
var
  s: string;
begin
  for s in ñ.Split([#13#10], TStringSplitOptions.None) do
    Wrln('// ' + s)
end;

procedure TGen.LoadMessage(msg: TpbMessage);
var
  i: Integer;
  f: TpbField;
  m: TpbMessage;
begin
  for i := 0 to msg.em.Messages.Count - 1 do
  begin
    m := msg.em.Messages[i];
    LoadMessage(m);
  end;
end;

procedure TGen.WriterInterface(msg: TpbMessage);
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

procedure TGen.WriterImplementation(msg: TpbMessage);
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
    msg.AsImplementation(Self);
  finally
    Dedent;
  end;
  Wrln('end;');
  Wrln('');
end;

procedure TGen.ReaderInterface(msg: TpbMessage);
var
  i: Integer;
  m: TpbMessage;
  msgType, s, t: string;
begin
  msgType := msg.DelphiName;
  Wrln('%sReader = class', [msgType]);
  Wrln('private');
  Wrln('  FPb: TProtoBufInput;');
  for i := 0 to msg.em.Messages.Count - 1 do
  begin
    m := msg.em.Messages[i];
    s := AsCamel(m.Name);
    t := m.DelphiName;
    Wrln('  procedure Load%s(%s: %s);', [s, m.Name, t]);
  end;
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

procedure TGen.ReaderImplementation(msg: TpbMessage);
var
  i: Integer;
  f: TpbField;
begin
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
  for i := 0 to msg.Fields.Count - 1 do
  begin
    f := msg.Fields[i];
    Wrln('%s.ft%s:', [msg.DelphiName, AsCamel(f.Name)]);
    Indent;
    Wrln('  %s.%s := FPb.read%s;', [AsCamel(f.Name), AsCamel(f.Name),
      f.Typ.DelphiName]);
    Dedent;
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
