
// Copyright (c) 2020 Tomsk, Marat Shaimardanov
// Protocol buffer Generator for Delphi

unit Oz.Pb.Parser;

interface

uses
  System.Classes, System.SysUtils, System.Character, System.IOUtils, System.Math,
  Oz.Cocor.Utils, Oz.Cocor.Lib, Oz.Pb.Scanner, Oz.Pb.Options, Oz.Pb.Tab, Oz.Pb.Gen;

type

{$Region 'TpbParser'}

  TpbParser= class(TBaseParser)
  const
    ErrorMessages: array [1..5] of string = (
      {1} 'multiple declaration',
      {2} 'undefined ident',
      {3} 'not found this module',
      {4} 'message type not found',
      {5} 'message type expected'
      );
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
    procedure SemError(n: Integer);
    procedure _Pb;
    procedure _Syntax;
    procedure _Import;
    procedure _Package;
    procedure _Option(var obj: PObj);
    procedure _TopLevelDef;
    procedure _EmptyStatement;
    procedure _Message(var obj: PObj);
    procedure _Enum(Scope: TIdent);
    procedure _Map(obj: PObj);
    procedure _Service(obj: PObj);
    procedure _Ident(var name: string);
    procedure _Field(msg: PObj);
    procedure _MapField(msg: PObj);
    procedure _OneOf(msg: PObj);
    procedure _Reserved(msg: PObj);
    procedure _strLit;
    procedure _FullIdent(var name: string);
    procedure _OptionName(var s: string);
    procedure _Constant(var c: TConst);
    procedure _KeyType(var ft: PType);
    procedure _Type(var typ: PType);
    procedure _Rpc(service: PObj);
    procedure _UserType(var typ: TUserType);
    procedure _intLit(var n: Integer);
    procedure _floatLit(var n: Double);
    procedure _boolLit;
    procedure _FieldNumber(var tag: Integer);
    procedure _FieldOptions(f: TPbField);
    procedure _OneOfField(oneOf: PObj);
    procedure _FieldOption(f: TPbField);
    procedure _Ranges(Reserved: TIntSet);
    procedure _FieldNames;
    procedure _Range(var lo, hi: Integer);
    procedure _EnumField(e: PObj);
    procedure _EnumValueOption(e: PObj);
  protected
    function Starts(s, kind: Integer): Boolean; override;
    procedure Get; override;
  public
    options: TOptions;
    tab: TpbTable;
    listing: TStrings;
    gen: TGen;
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
    function GetGen: TGen;
  public
    property parser: TpbParser read GetParser;
    property scanner: TpbScanner read GetScanner;
    property options: TOptions read GetOptions;
    property tab: TpbTable read GetTab;
    property errors: TErrors read GetErrors;
    property gen: TGen read GetGen;
 end;

{$EndRegion}

implementation

{$Region 'TpbParser'}

constructor TpbParser.Create(scanner: TBaseScanner; listing: TStrings);
begin
  inherited Create(scanner, listing);
  options := GetOptions;
  tab := TpbTable.Create(Self);
  gen := TGen.Create(Self);
end;

destructor TpbParser.Destroy;
begin
  tab.Free;
  inherited;
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
var obj: PObj;
begin
  tab.OpenScope;
  _Syntax;
  while StartOf(1) do
  begin
    if la.kind = 15 then
    begin
      _Import;
    end
    else if la.kind = 18 then
    begin
      _Package;
    end
    else if la.kind = 19 then
    begin
      _Option(obj);
    end
    else if StartOf(2) then
    begin
      _TopLevelDef;
    end
    else
    begin
      _EmptyStatement;
    end;
  end;
  tab.CloseScope;
end;

procedure TpbParser._Syntax;
begin
  Expect(12);
  Expect(13);
  _strLit;
  tab.Module.Syntax := TSyntaxVersion.Proto2;
  if t.val = '"proto3"' then
    tab.Module.Syntax := TSyntaxVersion.Proto3
  else if t.val <> '"proto2"' then
    SemErr('invalid syntax version');
  Expect(14);
end;

procedure TpbParser._Import;
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

  Expect(14);
end;

procedure TpbParser._Package;
var name: string;
begin
  Expect(18);
  _FullIdent(name);
  Tab.Module.AddPackage(name);
  Expect(14);
end;

procedure TpbParser._Option(var obj: PObj);
var
  name: string;
  Cv: TConst;
begin
  Expect(19);
  _OptionName(name);
  Expect(13);
  _Constant(Cv);
  Scope.AddOption(name, Cv);
  Expect(14);
end;

procedure TpbParser._TopLevelDef;
var
  obj: PObj;
begin
  if la.kind = 9 then
  begin
    _Message(obj);
  end
  else if la.kind = 61 then
  begin
    _Enum(obj);
  end
  else if la.kind = 23 then
  begin
    _Map(obj);
  end
  else if la.kind = 27 then
  begin
    _Service(obj);
  end
  else
    SynErr(63);
end;

procedure TpbParser._EmptyStatement;
begin
  Expect(14);
end;

procedure TpbParser._Message(var obj: PObj);
var
  name: string;
  msg: PObj;
begin
  Expect(9);
  _Ident(name);
  if Scope.em.Messages.Find(name) <> nil then
    SemError(1);
  msg := Scope.em.AddMessage(Scope, name);
  tab.OpenScope;
  Expect(10);
  while StartOf(3) do
  begin
    case la.kind of
      1, 22, 37, 38, 39, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57:
      begin
        _Field(msg);
      end;
      23:
      begin
        _MapField(msg);
      end;
      61:
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
      42:
      begin
        _OneOf(msg);
      end;
      58:
      begin
        _Reserved(msg);
      end;
      14:
      begin
        _EmptyStatement;
      end;
      end;
  end;
  Expect(11);
  tab.OpenScope;
end;

procedure TpbParser._Enum(Scope: TIdent);
var
  name: string;
  enum: PObj;
begin
  Expect(61);
  _Ident(name);
  enum := Scope.em.AddEnum(Scope, name);
  Expect(10);
  while (la.kind = 1) or (la.kind = 14) or (la.kind = 19) do
  begin
    if la.kind = 19 then
    begin
      _Option(enum);
    end
    else if la.kind = 1 then
    begin
      _EnumField(enum);
    end
    else
    begin
      _EmptyStatement;
    end;
  end;
  Expect(11);
end;

procedure TpbParser._Map(obj: PObj);
var
  name: string;
  key, value: PType;
  map: TpbMapType;
begin
  Expect(23);
  _Ident(name);
  map := module.MapTypes.Find(name);
  if map <> nil then
    SemError(1);
  Expect(24);
  _KeyType(key);
  Expect(25);
  _Type(module, value);
  Expect(26);
  module.LookupMapType(name, key, value);
end;

procedure TpbParser._Service(obj: PObj);
var
   name: string;
   service: PObj;
begin
  Expect(27);
  _Ident(name);
  if module.Services.Find(name) <> nil then
    SemError(1);
  service := PObj.Create(module, name);
  module.Services.Add(service);
  Expect(10);
  while (la.kind = 14) or (la.kind = 19) or (la.kind = 28) do
  begin
    if la.kind = 19 then
    begin
      _Option(service);
    end
    else if la.kind = 28 then
    begin
      _Rpc(service);
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

procedure TpbParser._Field(msg: PObj);
var
  f: TPbField;
  name: string;
  tag: Integer;
  rule: TFieldRule;
  ft: PType;
begin
  rule := TFieldRule.Singular;
  if (la.kind = 37) or (la.kind = 38) or (la.kind = 39) then
  begin
    if la.kind = 37 then
    begin
      Get;
      rule := TFieldRule.Repeated;
    end
    else if la.kind = 38 then
    begin
      Get;
      rule := TFieldRule.Optional;
    end
    else
    begin
      Get;
    end;
  end;
  _Type(ft);
  _Ident(name);
  if msg.Fields.Find(name) <> nil then
    SemError(1);
  Expect(13);
  _FieldNumber(tag);
  f := msg.em.AddField(msg, name, ft, tag, rule);
  if la.kind = 40 then
  begin
    Get;
    _FieldOptions(f);
    Expect(41);
  end;
  Expect(14);
end;

procedure TpbParser._MapField(msg: PObj);
var
        mapName, name: string;
        key, value, map: PType;
        tag: Integer;
        f: TpbField;
begin
  Expect(23);
  if la.kind = 1 then
  begin
    _Ident(mapName);
  end;
  map := tab.module.MapTypes.Find(mapName);
  if map <> nil then
    SemError(1);
  Expect(24);
  _KeyType(key);
  Expect(25);
  _Type(msg, value);
  Expect(26);
  if map = nil then
    map := tab.module.LookupMapType(mapName, key, value);
  _Ident(mapName);
  Expect(13);
  _FieldNumber(tag);
  f := msg.em.AddField(msg, name, map, tag, TFieldRule.Singular);
  if la.kind = 40 then
  begin
    Get;
    _FieldOptions(f);
    Expect(41);
  end;
  Expect(14);
end;

procedure TpbParser._OneOf(msg: PObj);
var
  oneOf: PObj;
  name: string;
begin
  Expect(42);
  _Ident(name);
  oneOf := msg.AddOneOf(name);
  Expect(10);
  while StartOf(4) do
  begin
    if la.kind = 19 then
    begin
      _Option(oneOf);
    end
    else if StartOf(5) then
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

procedure TpbParser._Reserved(msg: PObj);
begin
  Expect(58);
  if (la.kind = 2) or (la.kind = 3) or (la.kind = 4) then
  begin
    _Ranges(msg.Reserved);
  end
  else if la.kind = 1 then
  begin
    _FieldNames;
  end
  else
    SynErr(64);
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
    SynErr(65);
  while la.kind = 22 do
  begin
    Get;
    Expect(1);
    name := name + '.' + t.val;
  end;
end;

procedure TpbParser._Constant(var c: TConst);
var
  s: string;
  i, sign: Integer;
  d: Double;
begin
  if la.kind = 1 then
  begin
    _FullIdent(s);
    c.AsIdent(s);
  end
  else if StartOf(6) then
  begin
    sign := 1;
    if (la.kind = 35) or (la.kind = 36) then
    begin
      if la.kind = 35 then
      begin
        Get;
        sign := -sign;
      end
      else
      begin
        Get;
      end;
    end;
    if (la.kind = 2) or (la.kind = 3) or (la.kind = 4) then
    begin
      _intLit(i);
      c.AsInt(i * sign);
    end
    else if (la.kind = 5) or (la.kind = 31) or (la.kind = 32) then
    begin
      _floatLit(d);
      c.AsFloat(d * sign);
    end
    else
      SynErr(66);
  end
  else if la.kind = 6 then
  begin
    _strLit;
    c.AsStr(t.val);
  end
  else if (la.kind = 33) or (la.kind = 34) then
  begin
    _boolLit;
    c.AsBool(t.val);
  end
  else
    SynErr(67);
end;

procedure TpbParser._KeyType(var ft: PType);
begin
  case la.kind of
    46:
    begin
      Get;
      ft := tab.GetBasisType(TTypeMode.tmInt32);
    end;
    47:
    begin
      Get;
      ft := tab.GetBasisType(TTypeMode.tmInt64);
    end;
    48:
    begin
      Get;
      ft := tab.GetBasisType(TTypeMode.tmUint32);
    end;
    49:
    begin
      Get;
      ft := tab.GetBasisType(TTypeMode.tmUint64);
    end;
    50:
    begin
      Get;
      ft := tab.GetBasisType(TTypeMode.tmSint32);
    end;
    51:
    begin
      Get;
      ft := tab.GetBasisType(TTypeMode.tmSint64);
    end;
    52:
    begin
      Get;
      ft := tab.GetBasisType(TTypeMode.tmFixed32);
    end;
    53:
    begin
      Get;
      ft := tab.GetBasisType(TTypeMode.tmFixed64);
    end;
    54:
    begin
      Get;
      ft := tab.GetBasisType(TTypeMode.tmSfixed32);
    end;
    55:
    begin
      Get;
      ft := tab.GetBasisType(TTypeMode.tmSfixed64);
    end;
    56:
    begin
      Get;
      ft := tab.GetBasisType(TTypeMode.tmBool);
    end;
    57:
    begin
      Get;
      ft := tab.GetBasisType(TTypeMode.tmString);
    end;
    else
      SynErr(68);
  end;
end;

procedure TpbParser._Type(var typ: PType);
var
  obj: PObj;
  ut: TUserType;
begin
  if la.kind = 43 then
  begin
    Get;
    typ := tab.GetBasisType(TTypeMode.tmDouble);
  end
  else if la.kind = 44 then
  begin
    Get;
    typ := tab.GetBasisType(TTypeMode.tmFloat);
  end
  else if la.kind = 45 then
  begin
    Get;
    typ := tab.GetBasisType(TTypeMode.tmBytes);
  end
  else if StartOf(7) then
  begin
    _KeyType(typ);
  end
  else if (la.kind = 1) or (la.kind = 22) then
  begin
    _UserType(ut);
    typ := tab.Find(obj, ut);
    if obj.cls = TMode.mType then
      typ := obj.typ
    else if typ.TypMode = TTypeMode.tmUnknown then
      SemError(2)
    else
      SemError(5);
  end
  else
    SynErr(69);
end;

procedure TpbParser._Rpc(service: PObj);
var
  name: string;
  typ: TUserType;
  rpc: PObj;
begin
  Expect(28);
  _Ident(name);
  if service.RpcSystem.Find(name) <> nil then
   SemError(1);
   rpc := service.AddRpc(name);
  Expect(20);
  if la.kind = 29 then
  begin
    Get;
  end;
  _UserType(typ);
  rpc.Request := service.Module.em.FindMessageType(rpc, typ);
  if rpc.Request.TypMode = TTypeMode.tmUnknown then
    SemError(4)
  else if rpc.Request.Mode <> TMode.mRecord then
    SemError(5);
  Expect(21);
  Expect(30);
  Expect(20);
  if la.kind = 29 then
  begin
    Get;
  end;
  _UserType(typ);
  rpc.Response := service.Module.em.FindMessageType(rpc, typ);
  if rpc.Response.TypMode = TTypeMode.tmUnknown then
    SemError(4)
  else if rpc.Response.Mode <> TMode.mRecord then
    SemError(5);
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
    SynErr(70);
end;

procedure TpbParser._UserType(var typ: TUserType);
begin
  typ := Default(TUserType);
  if la.kind = 22 then
  begin
    Get;
    typ.OutermostScope := True;
  end;
  Expect(1);
  typ.name := t.val;
  while la.kind = 22 do
  begin
    Get;
    if typ.Package <> '' then
      typ.Package := typ.Package + '.';
    typ.Package := typ.Package + typ.Name;
    Expect(1);
    typ.Name := t.val;
  end;
end;

procedure TpbParser._intLit(var n: Integer);
begin
  if la.kind = 2 then
  begin
    Get;
    n := tab.ParseInt(t.val, 10);
  end
  else if la.kind = 3 then
  begin
    Get;
    n := tab.ParseInt(t.val, 8);
  end
  else if la.kind = 4 then
  begin
    Get;
    n := tab.ParseInt(t.val, 16);
  end
  else
    SynErr(71);
end;

procedure TpbParser._floatLit(var n: Double);
var code: Integer;
begin
  if la.kind = 5 then
  begin
    Get;
    Val(t.val, n, code);
  end
  else if la.kind = 31 then
  begin
    Get;
    n := Infinity;
  end
  else if la.kind = 32 then
  begin
    Get;
    n := NaN;
  end
  else
    SynErr(72);
end;

procedure TpbParser._boolLit;
begin
  if la.kind = 33 then
  begin
    Get;
  end
  else if la.kind = 34 then
  begin
    Get;
  end
  else
    SynErr(73);
end;

procedure TpbParser._FieldNumber(var tag: Integer);
begin
  _intLit(tag);
end;

procedure TpbParser._FieldOptions(f: TPbField);
begin
  _FieldOption(f);
  while la.kind = 25 do
  begin
    Get;
    _FieldOption(f);
  end;
end;

procedure TpbParser._OneOfField(oneOf: PObj);
var
  f: TPbField;
  name: string;
  tag: Integer;
  ft: PType;
begin
  _Type(oneOf.msg, ft);
  _Ident(name);
  Expect(13);
  _FieldNumber(tag);
  f := oneOf.AddField(name, ft, tag);
  if la.kind = 40 then
  begin
    Get;
    _FieldOptions(f);
    Expect(41);
  end;
  Expect(14);
end;

procedure TpbParser._FieldOption(f: TPbField);
var name: string; Cv: TConst;
begin
  _OptionName(name);
  Expect(13);
  _Constant(Cv);
  f.AddOption(name, Cv);
end;

procedure TpbParser._Ranges(Reserved: TIntSet);
var lo, hi: Integer;
begin
  _Range(lo, hi);
  Reserved.AddRange(lo, hi);
  while la.kind = 25 do
  begin
    Get;
    _Range(lo, hi);
    Reserved.AddRange(lo, hi);
  end;
end;

procedure TpbParser._FieldNames;
var name: string;
begin
  _Ident(name);
  while la.kind = 25 do
  begin
    Get;
    _Ident(name);
  end;
end;

procedure TpbParser._Range(var lo, hi: Integer);
begin
  _intLit(lo);
  if la.kind = 59 then
  begin
    Get;
    if (la.kind = 2) or (la.kind = 3) or (la.kind = 4) then
    begin
      _intLit(hi);
    end
    else if la.kind = 60 then
    begin
      Get;
      hi := 65535;
    end
    else
      SynErr(74);
  end;
end;

procedure TpbParser._EnumField(e: PObj);
var
     name: string;
     n: Integer;
     ev: TEnumValue;
begin
  _Ident(name);
  Expect(13);
  if la.kind = 35 then
  begin
    Get;
  end;
  _intLit(n);
  ev := TEnumValue.Create(e, name, n);
  e.EnumValues.Add(ev);
  if la.kind = 40 then
  begin
    Get;
    _EnumValueOption(e);
    while la.kind = 25 do
    begin
      Get;
      _EnumValueOption(e);
    end;
    Expect(41);
  end;
  Expect(14);
end;

procedure TpbParser._EnumValueOption(e: PObj);
var
     Name: string;
     Cv: TConst;
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
  sets: array [0..7] of array [0..63] of Boolean = (
    (T,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x),
    (x,x,x,x, x,x,x,x, x,T,x,x, x,x,T,T, x,x,T,T, x,x,x,T, x,x,x,T, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,T,x,x),
    (x,x,x,x, x,x,x,x, x,T,x,x, x,x,x,x, x,x,x,x, x,x,x,T, x,x,x,T, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,T,x,x),
    (x,T,x,x, x,x,x,x, x,T,x,x, x,x,T,x, x,x,x,T, x,x,T,T, x,x,x,x, x,x,x,x, x,x,x,x, x,T,T,T, x,x,T,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,T,x, x,T,x,x),
    (x,T,x,x, x,x,x,x, x,x,x,x, x,x,T,x, x,x,x,T, x,x,T,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,x,x, x,x,x,x),
    (x,T,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,T,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,T, T,T,T,T, T,T,T,T, T,T,T,T, T,T,x,x, x,x,x,x),
    (x,x,T,T, T,T,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,T, T,x,x,T, T,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x),
    (x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,x,x, x,x,T,T, T,T,T,T, T,T,T,T, T,T,x,x, x,x,x,x));
begin
  Result := sets[s, kind];
end;

function TpbParser.ErrorMsg(nr: Integer): string;
const
  MaxErr = 74;
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
    {23} '"map" expected',
    {24} '"<" expected',
    {25} '"," expected',
    {26} '">" expected',
    {27} '"service" expected',
    {28} '"rpc" expected',
    {29} '"stream" expected',
    {30} '"returns" expected',
    {31} '"inf" expected',
    {32} '"nan" expected',
    {33} '"true" expected',
    {34} '"false" expected',
    {35} '"-" expected',
    {36} '"+" expected',
    {37} '"repeated" expected',
    {38} '"optional" expected',
    {39} '"required" expected',
    {40} '"[" expected',
    {41} '"]" expected',
    {42} '"oneof" expected',
    {43} '"double" expected',
    {44} '"float" expected',
    {45} '"bytes" expected',
    {46} '"int32" expected',
    {47} '"int64" expected',
    {48} '"uint32" expected',
    {49} '"uint64" expected',
    {50} '"sint32" expected',
    {51} '"sint64" expected',
    {52} '"fixed32" expected',
    {53} '"fixed64" expected',
    {54} '"sfixed32" expected',
    {55} '"sfixed64" expected',
    {56} '"bool" expected',
    {57} '"string" expected',
    {58} '"reserved" expected',
    {59} '"to" expected',
    {60} '"max" expected',
    {61} '"enum" expected',
    {62} '??? expected',
    {63} 'invalid TopLevelDef',
    {64} 'invalid Reserved',
    {65} 'invalid OptionName',
    {66} 'invalid Constant',
    {67} 'invalid Constant',
    {68} 'invalid KeyType',
    {69} 'invalid Type',
    {70} 'invalid Rpc',
    {71} 'invalid intLit',
    {72} 'invalid floatLit',
    {73} 'invalid boolLit',
    {74} 'invalid Range');
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

function TCocoPartHelper.GetGen: TGen;
begin
  Result := parser.gen;
end;

{$EndRegion}

end.

