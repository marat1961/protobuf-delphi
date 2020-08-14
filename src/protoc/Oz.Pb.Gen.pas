unit Oz.Pb.Gen;

interface

uses
  System.Classes, System.SysUtils, System.Math,
  Oz.Cocor.Utils, Oz.Cocor.Lib, pbPublic, Oz.Pb.Tab;

type

{$Region 'TGen: code generator for delphi'}

  TGen = class(TBaseParser)
  private
    IndentLevel: Integer;
    sb: TStringBuilder;
    function GetCode: string;

    procedure Wr(const s: string); overload;
    procedure Wr(const f: string; const Args: array of const); overload;
    procedure Wrln; overload;
    procedure Wrln(const s: string); overload;
    procedure Wrln(const f: string; const Args: array of const); overload;

    procedure Indent;
    procedure Dedent;

    procedure GenComment(const ñ: string);
    procedure GenMessage(msg: TpbMessage);
    procedure LoadMessage(msg: TpbMessage);
    procedure GenEnum(e: TpbEnum);
    procedure WriterInterface(msg: TpbMessage);
    procedure ReaderInterface(msg: TpbMessage);
    procedure WriterImplementation(msg: TpbMessage);
    procedure ReaderImplementation(msg: TpbMessage);
  public
    constructor Create;
    destructor Destroy; override;
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
  t := Typ.AsDelphiType;
  if Rule = TFieldRule.Repeated then
    gen.Wr('%ss: TList<%s>;', [n, t])
  else
    gen.Wr('%s: %s;', [n, t]);
end;

procedure TpbFieldHelper.AsProperty(gen: TGen);
var n, t: string;
begin
  n := AsCamel(Name);
  t := Typ.AsDelphiType;
  if Rule = TFieldRule.Repeated then
    gen.Wr('%ss: TList<%s> read F%s;', [n, t, n])
  else
    gen.Wr('%s: %s read F%s write F%s;', [n, t, n, n]);
end;

procedure TpbFieldHelper.AsReflection(gen: TGen);
begin
  raise Exception.Create('under consruction');
end;

procedure TpbFieldHelper.AsInit(gen: TGen);
begin
  if options.Default <> '' then
    gen.Wrln('F%s := %s;',
      [AsCamel(Name), options.Default])
  else if Rule = TFieldRule.Repeated then
    gen.Wrln('F%s := TList<%s>.Create;',
      [AsCamel(Name), Typ.AsDelphiType])
  else if typ.TypMode = TTypeMode.tmMap then
    gen.Wrln('F%s := TDictionary<%s, %s>.Create;',
      [AsCamel(Name), 'keyType', 'valueType'])
end;

procedure TpbFieldHelper.AsFree(gen: TGen);
begin

end;

procedure TpbFieldHelper.AsRead(gen: TGen);
var
  m, n, s: string;
begin
  m := Msg.AsDelphiType;
  n := AsCamel(Typ.Name);
  gen.Wrln('%s.ft%s:', [m, n]);
  gen.Indent;
  try
    gen.Wrln('begin');
    gen.Indent;
    try
      gen.Wrln('Assert(wireType = WIRETYPE_LENGTH_DELIMITED);');
      gen.Wrln('person.Name := pb.readString;');
    finally
      gen.Dedent;
    end;
    gen.Wrln('end;');
  finally
    gen.Dedent;
  end;
end;

procedure TpbFieldHelper.AsWrite(gen: TGen);
begin

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

  gen.Wrln('%s = class', [AsDelphiType]);

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
  t := AsDelphiType;
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

  gen.Wr('destructor %s.Destroy;', [AsDelphiType]);
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

{$EndRegion}

{$Region 'TGen'}

constructor TGen.Create;
begin
  sb := TStringBuilder.Create;
end;

destructor TGen.Destroy;
begin
  sb.Free;
  inherited;
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

procedure TGen.GenMessage(msg: TpbMessage);
var
  i: Integer;
  f: TpbField;
  m: TpbMessage;
begin
  for i := 0 to msg.Fields.Count - 1 do
  begin
    f := msg.Fields[i];
    Wrln('  FPb.Write%s(%s.ft%s, %s.%s);',
      [AsCamel(f.Typ.Name), msg.AsDelphiType, f.Name, msg.Name, f.Name]);
  end;
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

procedure TGen.GenEnum(e: TpbEnum);
var
  i: Integer;
  ev: TEnumValue;
  s: string;
begin
  Wrln('T%s = (', [e.Name]);
  for i := 0 to e.Enums.Count - 1 do
  begin
    ev := e.Enums[i];
    Wr('  %s=%d', [ev.Name, ev.IntVal]);
    if i < e.Enums.Count - 1 then
      Wrln(',')
    else
      Wrln(');');
  end;
end;

procedure TGen.WriterInterface(msg: TpbMessage);
begin
  Wrln(msg.AsDelphiType + 'Writer = class');
  Wrln('private');
  Wrln('  FPb: TProtoBufOutput;');
  Wrln('public');
  Wrln('  constructor Create;');
  Wrln('  destructor Destroy; override;');
  Wrln('  function GetPb: TProtoBufOutput;');
  Wrln('  procedure Write(' + AsCamel(msg.Name) + ': ' + msg.AsDelphiType + ');');
  Wrln('end;');
  Wrln;
end;

procedure TGen.WriterImplementation(msg: TpbMessage);
begin
  Wrln('function %sWriter.GetPb: TProtoBufOutput;', [msg.AsDelphiType]);
  Wrln('begin');
  Wrln('  Result := FPb;');
  Wrln('end');
  Wrln;
  Wrln('procedure %sWriter.Wra%s: %s);', [msg.AsDelphiType, msg.Name, msg.AsDelphiType]);
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
  msgType := msg.AsDelphiType;
  Wrln('%sReader = class', [msgType]);
  Wrln('private');
  Wrln('  FPb: TProtoBufInput;');
  for i := 0 to msg.em.Messages.Count - 1 do
  begin
    m := msg.em.Messages[i];
    s := AsCamel(m.Name);
    t := m.AsDelphiType;
    Wrln('  procedure Load%s(%s: %s);', [s, m.Name, t]);
  end;
  Wrln('public');
  Wrln('  constructor Create;');
  Wrln('  destructor Destroy; override;');
  Wrln('  function GetPb: TProtoBufInput;');
  s := AsCamel(msg.Name);
  t := msg.AsDelphiType;
  Wrln('  procedure Load(%s: %s);', [s, t]);
  Wrln('end;');
  Wrln;
end;

procedure TGen.ReaderImplementation(msg: TpbMessage);
var
  i: Integer;
  f: TpbField;
begin
  Wrln('function %Reader.GetPb: TProtoBufOutput;', [msg.AsDelphiType]);
  Wrln('begin');
  Wrln('  Result := FPb;');
  Wrln('end;');
  Wrln;
  Wrln('procedure %sReader.Load(%s: %s);',
    [msg.AsDelphiType, AsCamel(msg.Name), msg.AsDelphiType]);
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
    Wrln('%s.ft%s:', [msg.AsDelphiType, AsCamel(f.Name)]);
    Indent;
    Wrln('  %s.%s := FPb.read%s;', [AsCamel(f.Name), AsCamel(f.Name),
      f.Typ.AsDelphiType]);
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

function TGen.GetCode: string;
begin
  Result := sb.ToString
end;

{$EndRegion}

end.
