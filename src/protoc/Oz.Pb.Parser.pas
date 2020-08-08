
// Copyright (c) 2020 Tomsk, Marat Shaimardanov
// Protocol buffer Generator for Delphi

unit Oz.Pb.Parser;

interface

uses
  System.Classes, System.SysUtils, System.Character, System.IOUtils,
  Oz.Cocor.Lib, Oz.Pb.Scanner, Oz.Pb.Options, Oz.Pb.Tab;

type

{$Region 'TpbParser'}

  TpbParser= class(TBaseParser)
  const
    ErrorMessages: array [1..20] of string = (
      {1} 'multiple declaration',
      {2} 'undefined ident',
      {3} 'not found this module',
      {4} 'type is not "record" type',
      {5} 'property redeclared',
      {6} 'collection redeclared',
      {7} 'illegal length declaration',
      {8} 'missing length declaration',
      {9} 'base type of set must be enumerated type',
     {10} 'too many members of enumerated base type (> 32)',
     {11} 'expected SUBCOLLECTION declarataion',
     {12} 'not match SUBCOLLECTION type',
     {13} 'invalid collection',
     {14} 'unsatisfied FORWARD declaration',
     {15} 'clause "ASC" or "DESC" may be used only for indexes',
     {16} 'illegal "GEN" declarataion for collection based on inherited type',
     {17} 'expected "GEN" declarataion',
     {18} 'undefined property',
     {19} 'unsatisfied "Foreign key" declaration',
     {20} 'it is not necessary to specify base type for the FORWARD declaration');


    _EOFSym = 0;
    _identSym = 1;
    _decimalLitSym = 2;
    _octalLitSym = 3;
    _hexLitSym = 4;
    _realSym = 5;
    _stringSym = 6;
    _badStringSym = 7;
    _charSym = 8;
  private
    procedure LexName(var s: string);
    procedure SemError(n: Integer);
    procedure _Pb;
    procedure _Syntax(Scope: TpbModule);
    procedure _Import(Scope: TpbModule);
    procedure _Package(Scope: TpbModule);
    procedure _Option(Scope: TpbModule);
    procedure _TopLevelDef(Scope: TpbModule);
    procedure _EmptyStatement;
    procedure _Message(Scope: TIdent);
    procedure _Enum(Scope: TIdent);
    procedure _Service(Scope: TpbModule);
    procedure _Ident(var name: string);
    procedure _MessageBody(msg: TpbMessage);
    procedure _Field(msg: TpbMessage);
    procedure _MapField;
    procedure _OneOf(msg: TpbMessage);
    procedure _Reserved;
    procedure _strLit;
    procedure _FullIdent(var name: string);
    procedure _OptionName(var s: string);
    procedure _Constant(var c: TConst);
    procedure _Rpc(service: TpbService);
    procedure _UserType(var typ: string);
    procedure _intLit(var s: string);
    procedure _floatLit(var s: string);
    procedure _boolLit;
    procedure _Type(f: TPbField);
    procedure _FieldNumber(var fn: string);
    procedure _FieldOptions(f: TPbField);
    procedure _OneOfField(oneOf: TPbOneOf);
    procedure _FieldOption(f: TPbField);
    procedure _keyType;
    procedure _Ranges;
    procedure _FieldNames;
    procedure _Range(var lo, hi: string);
    procedure _EnumBody(e: TPbEnum);
    procedure _EnumField(e: TPbEnum);
    procedure _EnumValueOption(e: TPbEnum);
  protected
    function Starts(s, kind: Integer): Boolean; override;
    procedure Get; override;
  public
    options: TOptions;
    tab: TpbTable;
    listing: TStrings;
    constructor Create(scanner: TBaseScanner; listing: TStrings);
    destructor Destroy; override;
    function ErrorMsg(nr: Integer): string; override;
    procedure Parse; override;
  end;

{$EndRegion}

{$Region 'TCocoPartHelper'}

  TCocoPartHelper = class helper for TCocoPart
  private
    function GetParser: TpbParser;
    function GetScanner: TpbScanner;
    function GetOptions: TOptions;
    function GetTab: TpbTable;
    function GetErrors: TErrors;
  public
    property parser: TpbParser read GetParser;
    property scanner: TpbScanner read GetScanner;
    property options: TOptions read GetOptions;
    property tab: TpbTable read GetTab;
    property errors: TErrors read GetErrors;
 end;

{$EndRegion}

implementation

{$Region 'TpbParser'}

constructor TpbParser.Create(scanner: TBaseScanner; listing: TStrings);
begin
  inherited Create(scanner, listing);
  options := GetOptions;
  tab := TpbTable.Create(Self);
end;

destructor TpbParser.Destroy;
begin
  tab.Free;
  inherited;
end;

procedure TpbParser.LexName(var s: string);
begin
  s := t.val;
end;

procedure TpbParser.SemError(n: Integer);
begin
  SemErr(ErrorMessages[n]);
end;

procedure TpbParser.Get;
begin
  repeat
    t := la;
    la := scanner.Scan;
    if la.kind <= scanner.MaxToken then
    begin
      Inc(errDist);
      break;
    end;

    la := t;
  until False;
end;

procedure TpbParser._Pb;
var Scope: TpbModule;
begin
  Scope := tab.Module;
  _Syntax(Scope);
  while StartOf(1) do
  begin
    if la.kind = 15 then
    begin
      _Import(Scope);
    end
    else if la.kind = 18 then
    begin
      _Package(Scope);
    end
    else if la.kind = 19 then
    begin
      _Option(Scope);
    end
    else if (la.kind = 9) or (la.kind = 23) or (la.kind = 59) then
    begin
      _TopLevelDef(Scope);
    end
    else
    begin
      _EmptyStatement;
    end;
  end;
end;

procedure TpbParser._Syntax(Scope: TpbModule);
begin
  Expect(12);
  Expect(13);
  _strLit;
  tab.Module.Syntax := TSyntaxVersion.Proto2;
  if t.val = 'proto3' then
    tab.Module.Syntax := TSyntaxVersion.Proto3
  else if t.val <> 'proto2' then
    SemErr('invalid syntax version');
  Expect(14);
end;

procedure TpbParser._Import(Scope: TpbModule);
var weak: Boolean;
begin
  weak := False;
  Expect(15);
  if (la.kind = 16) or (la.kind = 17) then
  begin
    if la.kind = 16 then
    begin
      Get;
      weak := True;
    end
    else
    begin
      Get;
    end;
  end;
  _strLit;
  tab.Module.LookupImport(t.val, weak);
  Expect(14);
end;

procedure TpbParser._Package(Scope: TpbModule);
var Name: string;
begin
  Expect(18);
  _FullIdent(Name);
  Tab.AddPackage(Name);
  Expect(14);
end;

procedure TpbParser._Option(Scope: TpbModule);
var Name: string; Cv: TConst;
begin
  Expect(19);
  _OptionName(option.Name);
  Expect(13);
  _Constant(Cv);
  Tab.Module.AddOption(Name, Cv);
  Expect(14);
end;

procedure TpbParser._TopLevelDef(Scope: TpbModule);
begin
  if la.kind = 9 then
  begin
    _Message(tab.Module);
  end
  else if la.kind = 59 then
  begin
    _Enum(tab.Module);
  end
  else if la.kind = 23 then
  begin
    _Service(tab.Module);
  end
  else
    SynErr(61);
end;

procedure TpbParser._EmptyStatement;
begin
  Expect(14);
end;

procedure TpbParser._Message(Scope: TIdent);
var
 msg: TpbMessage;
 name: string;
begin
  Expect(9);
  _Ident(name);
  msg := Tab.AddMessage(Scope, name, '');
  _MessageBody(msg);
end;

procedure TpbParser._Enum(Scope: TIdent);
var e: TPbEnum;
begin
  Expect(59);
  _Ident(name);
  _EnumBody(e);
end;

procedure TpbParser._Service(Scope: TpbModule);
var service: TpbService;
begin
  Expect(23);
  _Ident(ServiceName);
  Expect(10);
  while (la.kind = 14) or (la.kind = 19) or (la.kind = 24) do
  begin
    if la.kind = 19 then
    begin
      _Option(service);
    end
    else if la.kind = 24 then
    begin
      _Rpc(service.Rpc);
    end
    else
    begin
      _EmptyStatement;
    end;
  end;
  Expect(11);
end;

procedure TpbParser._Ident(var name: string);
begin
  Expect(1);
  name := t.val;
end;

procedure TpbParser._MessageBody(msg: TpbMessage);
begin
  Expect(10);
  while StartOf(2) do
  begin
    case la.kind of
      1, 22, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48:
      begin
        _Field(msg);
      end;
      53:
      begin
        _MapField;
      end;
      59:
      begin
        _Enum(msg);
      end;
      9:
      begin
        _Message(msg);
      end;
      19:
      begin
        _Option(msg);
      end;
      51:
      begin
        _OneOf(msg);
      end;
      56:
      begin
        _Reserved;
      end;
      14:
      begin
        _EmptyStatement;
      end;
      end;
  end;
  Expect(11);
end;

procedure TpbParser._Field(msg: TpbMessage);
var f: TPbField;
begin
  if la.kind = 48 then
  begin
    Get;
  end;
  _Type(f);
  _Ident(fieldName);
  Expect(13);
  _FieldNumber(f.FieldNumber);
  if la.kind = 49 then
  begin
    Get;
    _FieldOptions(f);
    Expect(50);
  end;
  Expect(14);
end;

procedure TpbParser._MapField;
var f: TPbField;
begin
  Expect(53);
  Expect(54);
  _keyType;
  Expect(52);
  _Type(f);
  Expect(55);
  _Ident(mapName);
  Expect(13);
  _FieldNumber(f.FieldNumber);
  if la.kind = 49 then
  begin
    Get;
    _FieldOptions(f);
    Expect(50);
  end;
  Expect(14);
end;

procedure TpbParser._OneOf(msg: TpbMessage);
var oneOf: TPbOneOf;
begin
  Expect(51);
  _Ident(oneofName);
  Expect(10);
  while StartOf(3) do
  begin
    if la.kind = 19 then
    begin
      _Option(oneOf);
    end
    else if StartOf(4) then
    begin
      _OneOfField(oneOf);
    end
    else
    begin
      _EmptyStatement;
    end;
  end;
  Expect(11);
end;

procedure TpbParser._Reserved;
begin
  Expect(56);
  if (la.kind = 2) or (la.kind = 3) or (la.kind = 4) then
  begin
    _Ranges;
  end
  else if la.kind = 1 then
  begin
    _FieldNames;
  end
  else
    SynErr(62);
  Expect(14);
end;

procedure TpbParser._strLit;
begin
  Expect(6);
end;

procedure TpbParser._FullIdent(var name: string);
begin
  Expect(1);
  name := t.val;
  while la.kind = 22 do
  begin
    Get;
    Expect(1);
    name := name + '.' + t.val;
  end;
end;

procedure TpbParser._OptionName(var s: string);
var name: string;
begin
  if la.kind = 1 then
  begin
    Get;
    name := t.val;
  end
  else if la.kind = 20 then
  begin
    Get;
    _FullIdent(name);
    name := name + '(' + name + ')';
    Expect(21);
  end
  else
    SynErr(63);
  while la.kind = 22 do
  begin
    Get;
    Expect(1);
    name := name + '.' + t.val;
  end;
end;

procedure TpbParser._Constant(var c: TConst);
var cval: string;
begin
  if la.kind = 1 then
  begin
    _FullIdent(cval);
    c.Init(cval, TConstType.cIdent);
  end
  else if StartOf(5) then
  begin
    if (la.kind = 31) or (la.kind = 32) then
    begin
      if la.kind = 31 then
      begin
        Get;
        c.sign := -1;
      end
      else
      begin
        Get;
      end;
    end;
    if (la.kind = 2) or (la.kind = 3) or (la.kind = 4) then
    begin
      _intLit(cval);
      c.Init(cval, TpbConstant.cInt);
    end
    else if (la.kind = 5) or (la.kind = 27) or (la.kind = 28) then
    begin
      _floatLit(cval);
      c.Init(cval, TpbConstant.cFloat);
    end
    else
      SynErr(64);
  end
  else if la.kind = 6 then
  begin
    _strLit;
    c.Init(t.val, TpbConstant.cStr);
  end
  else if (la.kind = 29) or (la.kind = 30) then
  begin
    _boolLit;
    c.Init(t.val, TpbConstant.cBool);
  end
  else
    SynErr(65);
end;

procedure TpbParser._Rpc(service: TpbService);
begin
  Expect(24);
  _Ident(name);
  Expect(20);
  if la.kind = 25 then
  begin
    Get;
  end;
  _UserType(messageType);
  Expect(21);
  Expect(26);
  Expect(20);
  if la.kind = 25 then
  begin
    Get;
  end;
  _UserType(messageType);
  Expect(21);
  if la.kind = 10 then
  begin
    Get;
    while (la.kind = 14) or (la.kind = 19) do
    begin
      if la.kind = 19 then
      begin
        _Option(rpc);
      end
      else
      begin
        _EmptyStatement;
      end;
    end;
    Expect(11);
  end
  else if la.kind = 14 then
  begin
    Get;
  end
  else
    SynErr(66);
end;

procedure TpbParser._UserType(var typ: string);
begin
  if la.kind = 22 then
  begin
    Get;
  end;
  Expect(1);
  while la.kind = 22 do
  begin
    Get;
    Expect(1);
  end;
end;

procedure TpbParser._intLit(var s: string);
begin
  if la.kind = 2 then
  begin
    Get;
    s := t.val;
  end
  else if la.kind = 3 then
  begin
    Get;
    s := t.val;
  end
  else if la.kind = 4 then
  begin
    Get;
    s := t.val;
  end
  else
    SynErr(67);
end;

procedure TpbParser._floatLit(var s: string);
begin
  if la.kind = 5 then
  begin
    Get;
    s  := t.val;
  end
  else if la.kind = 27 then
  begin
    Get;
    s := 'Infinity';
  end
  else if la.kind = 28 then
  begin
    Get;
    s := 'NaN';
  end
  else
    SynErr(68);
end;

procedure TpbParser._boolLit;
begin
  if la.kind = 29 then
  begin
    Get;
  end
  else if la.kind = 30 then
  begin
    Get;
  end
  else
    SynErr(69);
end;

procedure TpbParser._Type(f: TPbField);
begin
  case la.kind of
    33:
    begin
      Get;
    end;
    34:
    begin
      Get;
    end;
    35:
    begin
      Get;
    end;
    36:
    begin
      Get;
    end;
    37:
    begin
      Get;
    end;
    38:
    begin
      Get;
    end;
    39:
    begin
      Get;
    end;
    40:
    begin
      Get;
    end;
    41:
    begin
      Get;
    end;
    42:
    begin
      Get;
    end;
    43:
    begin
      Get;
    end;
    44:
    begin
      Get;
    end;
    45:
    begin
      Get;
    end;
    46:
    begin
      Get;
    end;
    47:
    begin
      Get;
    end;
    1, 22:
    begin
      _UserType(typ);
    end;
    else
      SynErr(70);
  end;
end;

procedure TpbParser._FieldNumber(var fn: string);
begin
  _intLit(fn);
end;

procedure TpbParser._FieldOptions(f: TPbField);
begin
  _FieldOption(f);
  while la.kind = 52 do
  begin
    Get;
    _FieldOption(f);
  end;
end;

procedure TpbParser._OneOfField(oneOf: TPbOneOf);
var f: TPbField;
begin
  _Type(f);
  _Ident(f.fieldName);
  Expect(13);
  _FieldNumber(f.FieldNumber);
  if la.kind = 49 then
  begin
    Get;
    _FieldOptions(f);
    Expect(50);
  end;
  Expect(14);
end;

procedure TpbParser._FieldOption(f: TPbField);
var Name: string; Cv: TConst;
begin
  _OptionName(option.Name);
  Expect(13);
  _Constant(Cv);
  f.AddOption(Name, Cv);
end;

procedure TpbParser._keyType;
begin
  case la.kind of
    35:
    begin
      Get;
    end;
    36:
    begin
      Get;
    end;
    37:
    begin
      Get;
    end;
    38:
    begin
      Get;
    end;
    39:
    begin
      Get;
    end;
    40:
    begin
      Get;
    end;
    41:
    begin
      Get;
    end;
    42:
    begin
      Get;
    end;
    43:
    begin
      Get;
    end;
    44:
    begin
      Get;
    end;
    45:
    begin
      Get;
    end;
    46:
    begin
      Get;
    end;
    else
      SynErr(71);
  end;
end;

procedure TpbParser._Ranges;
var lo, hi: string;
begin
  _Range(lo, ho);
  while la.kind = 52 do
  begin
    Get;
    _Range(lo, hi);
  end;
end;

procedure TpbParser._FieldNames;
begin
  _Ident(fieldName);
  while la.kind = 52 do
  begin
    Get;
    _Ident(fieldName);
  end;
end;

procedure TpbParser._Range(var lo, hi: string);
begin
  _intLit(lo);
  if la.kind = 57 then
  begin
    Get;
    if (la.kind = 2) or (la.kind = 3) or (la.kind = 4) then
    begin
      _intLit(hi);
    end
    else if la.kind = 58 then
    begin
      Get;
      hi := 'max';
    end
    else
      SynErr(72);
  end;
end;

procedure TpbParser._EnumBody(e: TPbEnum);
begin
  Expect(10);
  while (la.kind = 1) or (la.kind = 14) or (la.kind = 19) do
  begin
    if la.kind = 19 then
    begin
      _Option(e);
    end
    else if la.kind = 1 then
    begin
      _EnumField(e);
    end
    else
    begin
      _EmptyStatement;
    end;
  end;
  Expect(11);
end;

procedure TpbParser._EnumField(e: TPbEnum);
var n: string;
begin
  Expect(1);
  Expect(13);
  if la.kind = 31 then
  begin
    Get;
  end;
  _intLit(n);
  if la.kind = 49 then
  begin
    Get;
    _EnumValueOption(e);
    while la.kind = 52 do
    begin
      Get;
      _EnumValueOption(e);
    end;
    Expect(50);
  end;
  Expect(14);
end;

procedure TpbParser._EnumValueOption(e: TPbEnum);
var Name: string; Cv: TConst;
begin
  _OptionName(Name);
  Expect(13);
  _Constant(Cv);
  e.AddOption(Name, Cv);
end;

procedure TpbParser.Parse;
begin
  la := scanner.NewToken;
  la.val := '';
  Get;
  _Pb;
  Expect(0);
end;

function TpbParser.Starts(s, kind: Integer): Boolean;
const
  x = false;
  T = true;
  sets: array [0..5] of array [0..61] of Boolean = (
    (T,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x),
    (x,x,x,x, x,x,x,x, x,T,x,x, x,x,T,T, x,x,T,T, x,x,x,T, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,T, x,x),
    (x,T,x,x, x,x,x,x, x,T,x,x, x,x,T,x, x,x,x,T, x,x,T,x, x,x,x,x, x,x,x,x, x,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,x,x,T, x,T,x,x, T,x,x,T, x,x),
    (x,T,x,x, x,x,x,x, x,x,x,x, x,x,T,x, x,x,x,T, x,x,T,x, x,x,x,x, x,x,x,x, x,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, x,x,x,x, x,x,x,x, x,x,x,x, x,x),
    (x,T,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,T,x, x,x,x,x, x,x,x,x, x,T,T,T, T,T,T,T, T,T,T,T, T,T,T,T, x,x,x,x, x,x,x,x, x,x,x,x, x,x),
    (x,x,T,T, T,T,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,T, T,x,x,T, T,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x));
begin
  Result := sets[s, kind];
end;

function TpbParser.ErrorMsg(nr: Integer): string;
const
  MaxErr = 72;
  Errors: array [0 .. MaxErr] of string = (
    {0} 'EOF expected',
    {1} 'ident expected',
    {2} 'decimalLit expected',
    {3} 'octalLit expected',
    {4} 'hexLit expected',
    {5} 'real expected',
    {6} 'string expected',
    {7} 'badString expected',
    {8} 'char expected',
    {9} '"message" expected',
    {10} '"{" expected',
    {11} '"}" expected',
    {12} '"syntax" expected',
    {13} '"=" expected',
    {14} '";" expected',
    {15} '"import" expected',
    {16} '"weak" expected',
    {17} '"public" expected',
    {18} '"package" expected',
    {19} '"option" expected',
    {20} '"(" expected',
    {21} '")" expected',
    {22} '"." expected',
    {23} '"service" expected',
    {24} '"rpc" expected',
    {25} '"stream" expected',
    {26} '"returns" expected',
    {27} '"inf" expected',
    {28} '"nan" expected',
    {29} '"true" expected',
    {30} '"false" expected',
    {31} '"-" expected',
    {32} '"+" expected',
    {33} '"double" expected',
    {34} '"float" expected',
    {35} '"int32" expected',
    {36} '"int64" expected',
    {37} '"uint32" expected',
    {38} '"uint64" expected',
    {39} '"sint32" expected',
    {40} '"sint64" expected',
    {41} '"fixed32" expected',
    {42} '"fixed64" expected',
    {43} '"sfixed32" expected',
    {44} '"sfixed64" expected',
    {45} '"bool" expected',
    {46} '"string" expected',
    {47} '"bytes" expected',
    {48} '"repeated" expected',
    {49} '"[" expected',
    {50} '"]" expected',
    {51} '"oneof" expected',
    {52} '"," expected',
    {53} '"map" expected',
    {54} '"<" expected',
    {55} '">" expected',
    {56} '"reserved" expected',
    {57} '"to" expected',
    {58} '"max" expected',
    {59} '"enum" expected',
    {60} '??? expected',
    {61} 'invalid TopLevelDef',
    {62} 'invalid Reserved',
    {63} 'invalid OptionName',
    {64} 'invalid Constant',
    {65} 'invalid Constant',
    {66} 'invalid Rpc',
    {67} 'invalid intLit',
    {68} 'invalid floatLit',
    {69} 'invalid boolLit',
    {70} 'invalid Type',
    {71} 'invalid keyType',
    {72} 'invalid Range');
begin
  if nr <= MaxErr then
    Result := Errors[nr]
  else
    Result := 'error ' + IntToStr(nr);
end;

{$EndRegion}

{$Region 'TCocoPartHelper'}

function TCocoPartHelper.GetParser: TpbParser;
begin
  Result := FParser as TpbParser;
end;

function TCocoPartHelper.GetScanner: TpbScanner;
begin
  Result := parser.scanner as TpbScanner;
end;

function TCocoPartHelper.GetOptions: TOptions;
begin
  Result := parser.options;
end;

function TCocoPartHelper.GetTab: TpbTable;
begin
  Result := parser.tab;
end;

function TCocoPartHelper.GetErrors: TErrors;
begin
  Result := parser.errors;
end;

{$EndRegion}

end.

