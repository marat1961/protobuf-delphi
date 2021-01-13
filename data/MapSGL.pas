unit MapSGL;

interface

uses
  System.Classes, System.SysUtils, System.Generics.Collections,
  Oz.SGL.Hash, Oz.SGL.Collections, Oz.Pb.Classes;

{$T+}

type

  TEnumVal = (
    MAP_VALUE_FOO = 0,
    MAP_VALUE_BAR = 1,
    MAP_VALUE_BAZ = 2);

  PMsgVal = ^TMsgVal;
  TMsgVal = record
  const
    ftFoo = 1;
  private
    FFoo: Integer;
  public
    procedure Init;
    procedure Free;
    // properties
    property Foo: Integer read FFoo write FFoo;
  end;

  PMapFields = ^TMapFields;
  TMapFields = record
  type
    TStringString = TsgHashMap<string, string>;
    TStringInt32 = TsgHashMap<string, Integer>;
    TStringInt64 = TsgHashMap<string, Int64>;
    TStringBool = TsgHashMap<string, Boolean>;
    TStringDouble = TsgHashMap<string, Double>;
    TStringEnumVal = TsgHashMap<string, TEnumVal>;
    TStringMsgVal = TsgHashMap<string, TMsgVal>;
    TInt32String = TsgHashMap<Integer, string>;
    TInt64String = TsgHashMap<Int64, string>;
    TBoolString = TsgHashMap<Boolean, string>;
    TStringMapFields = TsgHashMap<string, TMapFields>;
  const
    ftMapStringString = 1;
    ftMapStringInt32 = 2;
    ftMapStringInt64 = 3;
    ftMapStringBool = 4;
    ftMapStringDouble = 5;
    ftMapStringEnum = 6;
    ftMapStringMsg = 7;
    ftMapInt32String = 8;
    ftMapInt64String = 9;
    ftMapBoolString = 10;
    ftTestMapFields = 11;
    ftStringTmapfields = 12;
  private
    FMapStringString: TStringString;
    FMapStringInt32: TStringInt32;
    FMapStringInt64: TStringInt64;
    FMapStringBool: TStringBool;
    FMapStringDouble: TStringDouble;
    FMapStringEnum: TStringEnumVal;
    FMapStringMsg: TStringMsgVal;
    FMapInt32String: TInt32String;
    FMapInt64String: TInt64String;
    FMapBoolString: TBoolString;
    FTestMapFields: PMapFields;
    FStringTmapfields: TsgHashMap<string, TMapFields>;
  public
    procedure Init;
    procedure Free;
    // properties
    property MapStringString: TStringString read FMapStringString write FMapStringString;
    property MapStringInt32: TStringInt32 read FMapStringInt32 write FMapStringInt32;
    property MapStringInt64: TStringInt64 read FMapStringInt64 write FMapStringInt64;
    property MapStringBool: TStringBool read FMapStringBool write FMapStringBool;
    property MapStringDouble: TStringDouble read FMapStringDouble write FMapStringDouble;
    property MapStringEnum: TStringEnumVal read FMapStringEnum write FMapStringEnum;
    property MapStringMsg: TStringMsgVal read FMapStringMsg write FMapStringMsg;
    property MapInt32String: TInt32String read FMapInt32String write FMapInt32String;
    property MapInt64String: TInt64String read FMapInt64String write FMapInt64String;
    property MapBoolString: TBoolString read FMapBoolString write FMapBoolString;
    property TestMapFields: PMapFields read FTestMapFields write FTestMapFields;
    property StringTmapfields: TStringMapFields read FStringTmapfields write FStringTmapfields;
  end;

  TLoadHelper = record helper for TpbLoader
  public
    procedure LoadMsgVal(var Value: TMsgVal);
    procedure LoadMapFields(var Value: TMapFields);
  end;

  TSaveHelper = record helper for TpbSaver
  type
    TSave<T> = procedure(const S: TpbSaver; const Value: T);
    TSavePair<Key, Value> = procedure(const S: TpbSaver; const Pair: TsgPair<Key, Value>);
  private
    procedure SaveObj<T>(const obj: T; Save: TSave<T>; Tag: Integer);
    procedure SaveList<T>(const List: TsgRecordList<T>; Save: TSave<T>; Tag: Integer);
    procedure SaveMap<Key, Value>(const Map: TsgHashMap<Key, Value>;
      Save: TSavePair<Key, Value>; Tag: Integer);
  public
    class procedure SaveMsgVal(const S: TpbSaver; const Value: TMsgVal); static;
    class procedure SaveMapFields(const S: TpbSaver; const Value: TMapFields); static;
  end;

implementation

{ TMsgVal }

procedure TMsgVal.Init;
begin
  Self := Default(TMsgVal);
end;

procedure TMsgVal.Free;
begin
end;

{ TMapFields }

procedure TMapFields.Init;
begin
  Self := Default(TMapFields);
  FMapStringString := TsgHashMap<string, string>.From(300);
  FMapStringInt32 := TsgHashMap<string, Integer>.From(300);
  FMapStringInt64 := TsgHashMap<string, Int64>.From(300);
  FMapStringBool := TsgHashMap<string, Boolean>.From(300);
  FMapStringDouble := TsgHashMap<string, Double>.From(300);
  FMapStringEnum := TsgHashMap<string, TEnumVal>.From(300);
  FMapStringMsg := TsgHashMap<string, TMsgVal>.From(300);
  FMapInt32String := TsgHashMap<Integer, string>.From(300);
  FMapInt64String := TsgHashMap<Int64, string>.From(300);
  FMapBoolString := TsgHashMap<Boolean, string>.From(300);
  FStringTmapfields := TsgHashMap<string, TMapFields>.From(300);
end;

procedure TMapFields.Free;
begin
  FMapStringString.Free;
  FMapStringInt32.Free;
  FMapStringInt64.Free;
  FMapStringBool.Free;
  FMapStringDouble.Free;
  FMapStringEnum.Free;
  FMapStringMsg.Free;
  FMapInt32String.Free;
  FMapInt64String.Free;
  FMapBoolString.Free;
  FStringTmapfields.Free;
end;

procedure TLoadHelper.LoadMsgVal(var Value: TMsgVal);
var
  fieldNumber, wireType: integer;
  tag: TpbTag;
begin
  tag := Pb.readTag;
  while tag.v <> 0 do
  begin
    wireType := tag.WireType;
    fieldNumber := tag.FieldNumber;
    case fieldNumber of
      TMsgVal.ftFoo:
        begin
          Assert(wireType = TWire.VARINT);
          Value.Foo := Pb.readInt32;
        end;
      else
        Pb.skipField(tag);
    end;
    tag := Pb.readTag;
  end;
end;

procedure TLoadHelper.LoadMapFields(var Value: TMapFields);
var
  fieldNumber, wireType: integer;
  tag: TpbTag;
begin
  tag := Pb.readTag;
  while tag.v <> 0 do
  begin
    wireType := tag.WireType;
    fieldNumber := tag.FieldNumber;
    case fieldNumber of
      TMapFields.ftMapStringString:
        Value.MapStringString.Insert(
          TsgPair<string, string>.From(Pb.readString, Pb.readString));
      TMapFields.ftMapStringInt32:
        Value.MapStringInt32.Insert(
          TsgPair<string, Integer>.From(Pb.readString, Pb.readInt32));
      TMapFields.ftMapStringInt64:
        Value.MapStringInt64.Insert(
          TsgPair<string, Int64>.From(Pb.readString, Pb.readInt64));
      TMapFields.ftMapStringBool:
        Value.MapStringBool.Insert(
          TsgPair<string, Boolean>.From(Pb.readString, Pb.readBoolean));
      TMapFields.ftMapStringDouble:
        Value.MapStringDouble.Insert(
          TsgPair<string, Double>.From(Pb.readString, Pb.readDouble));
      TMapFields.ftMapStringEnum:
        Value.MapStringEnum.Insert(
          TsgPair<string, TEnumVal>.From(Pb.readString, TEnumVal(Pb.readInt32)));
      TMapFields.ftMapStringMsg:
        begin
          var Pair: TsgPair<string, TMsgVal>;
          Pair.Key := Pb.readString;
          LoadMsgVal(Pair.Value);
          Value.MapStringMsg.Insert(Pair);
        end;
      TMapFields.ftMapInt32String:
        Value.MapInt32String.Insert(
          TsgPair<Int32, string>.From(Pb.readInt32, Pb.readString));
      TMapFields.ftMapInt64String:
        Value.MapInt64String.Insert(
          TsgPair<Int64, string>.From(Pb.readInt64, Pb.readString));
      TMapFields.ftMapBoolString:
        Value.MapBoolString.Insert(
          TsgPair<Boolean, string>.From(Pb.readBoolean, Pb.readString));
      TMapFields.ftTestMapFields:
        begin
          Assert(wireType = TWire.LENGTH_DELIMITED);
          Pb.Push;
          try
            LoadMapFields(Value.FTestMapFields^);
          finally
            Pb.Pop;
          end;
        end;
      TMapFields.ftStringTmapfields:
        begin
          var Pair: TsgPair<string, TMapFields>;
          Pair.Key := Pb.readString;
          LoadMapFields(Pair.Value);
          Value.StringTmapfields.Insert(Pair);
        end;
      else
        Pb.skipField(tag);
    end;
    tag := Pb.readTag;
  end;
end;

{ TSaveHelper }

procedure TSaveHelper.SaveObj<T>(const obj: T; Save: TSave<T>; Tag: Integer);
var
  h: TpbSaver;
begin
  h.Init;
  try
    Save(h, obj);
    Pb.writeMessage(tag, h.Pb^);
  finally
    h.Free;
  end;
end;

procedure TSaveHelper.SaveList<T>(const List: TsgRecordList<T>;
  Save: TSave<T>; Tag: Integer);
var
  i: Integer;
  h: TpbSaver;
begin
  h.Init;
  try
    for i := 0 to List.Count - 1 do
    begin
      h.Clear;
      Save(h, List[i]^);
      Pb.writeMessage(tag, h.Pb^);
    end;
  finally
    h.Free;
  end;
end;

procedure TSaveHelper.SaveMap<Key, Value>(const Map: TsgHashMap<Key, Value>;
  Save: TSavePair<Key, Value>; Tag: Integer);
var
  h: TpbSaver;
  Pair: TsgHashMapIterator<Key, Value>.PPair;
  it: TsgHashMapIterator<Key, Value>;
begin
  h.Init;
  try
    it := Map.Begins;
    while it <> Map.Ends do
    begin
      h.Clear;
      Save(h, it.GetPair^);
      Pb.writeMessage(tag, h.Pb^);
      it.Next;
    end;
  finally
    h.Free;
  end;
end;

class procedure TSaveHelper.SaveMsgVal(const S: TpbSaver; const Value: TMsgVal);
begin
  S.Pb.writeInt32(TMsgVal.ftFoo, Value.Foo);
end;

class procedure TSaveHelper.SaveMapFields(const S: TpbSaver; const Value: TMapFields);
begin
  SaveMap<String, String>(Value.MapStringString,
  TMapFields.ftMapStringString);
  h.Init;
  try
    h.SaveStringString();
    Pb.writeMessage(TMapFields.ftMapStringString, h.Pb^);
  finally
    h.Free;
  end;
  h.Init;
  try
    h.SaveStringInt32(Value.MapStringInt32);
    Pb.writeMessage(TMapFields.ftMapStringInt32, h.Pb^);
  finally
    h.Free;
  end;
  h.Init;
  try
    h.SaveStringInt64(Value.MapStringInt64);
    Pb.writeMessage(TMapFields.ftMapStringInt64, h.Pb^);
  finally
    h.Free;
  end;
  h.Init;
  try
    h.SaveStringBool(Value.MapStringBool);
    Pb.writeMessage(TMapFields.ftMapStringBool, h.Pb^);
  finally
    h.Free;
  end;
  h.Init;
  try
    h.SaveStringDouble(Value.MapStringDouble);
    Pb.writeMessage(TMapFields.ftMapStringDouble, h.Pb^);
  finally
    h.Free;
  end;
  h.Init;
  try
    h.SaveStringEnumVal(Value.MapStringEnum);
    Pb.writeMessage(TMapFields.ftMapStringEnum, h.Pb^);
  finally
    h.Free;
  end;
  h.Init;
  try
    h.SaveStringMsgVal(Value.MapStringMsg);
    Pb.writeMessage(TMapFields.ftMapStringMsg, h.Pb^);
  finally
    h.Free;
  end;
  h.Init;
  try
    h.SaveInt32String(Value.MapInt32String);
    Pb.writeMessage(TMapFields.ftMapInt32String, h.Pb^);
  finally
    h.Free;
  end;
  h.Init;
  try
    h.SaveInt64String(Value.MapInt64String);
    Pb.writeMessage(TMapFields.ftMapInt64String, h.Pb^);
  finally
    h.Free;
  end;
  h.Init;
  try
    h.SaveBoolString(Value.MapBoolString);
    Pb.writeMessage(TMapFields.ftMapBoolString, h.Pb^);
  finally
    h.Free;
  end;
  S.SaveObj<TMapFields>(Value.FTestMapFields, SaveMapFields, TMapFields.ftTestMapFields);
  h.Init;
  try
    h.SaveStringMapFields(Value.StringTmapfields);
    Pb.writeMessage(TMapFields.ftStringTmapfields, h.Pb^);
  finally
    h.Free;
  end;
end;

procedure TSaveHelper.SaveStringString(Item: TPair<string, string>);
var
  h: TpbSaver;
begin
  S.Pb.writeString(1, Value.Key);
  S.Pb.writeString(2, Value.Value);
end;

procedure TSaveHelper.SaveStringInt32(Item: TPair<string, Integer>);
var
  h: TpbSaver;
begin
  S.Pb.writeString(1, Value.Key);
  S.Pb.writeInt32(2, Value.Value);
end;

procedure TSaveHelper.SaveStringInt64(Item: TPair<string, Int64>);
var
  h: TpbSaver;
begin
  S.Pb.writeString(1, Value.Key);
  S.Pb.writeInt64(2, Value.Value);
end;

procedure TSaveHelper.SaveStringBool(Item: TPair<string, Boolean>);
var
  h: TpbSaver;
begin
  S.Pb.writeString(1, Value.Key);
  S.Pb.writeBoolean(2, Value.Value);
end;

procedure TSaveHelper.SaveStringDouble(Item: TPair<string, Double>);
var
  h: TpbSaver;
begin
  S.Pb.writeString(1, Value.Key);
  S.Pb.writeDouble(2, Value.Value);
end;

procedure TSaveHelper.SaveStringEnumVal(Item: TPair<string, TEnumVal>);
var
  h: TpbSaver;
begin
  S.Pb.writeString(1, Value.Key);
  S.Pb.writeInt32(2, Ord(Value.Value));
end;

procedure TSaveHelper.SaveStringMsgVal(Item: TPair<string, TMsgVal>);
var
  h: TpbSaver;
begin
  S.Pb.writeString(1, Value.Key);
  S.SaveObj<TMsgVal>(Value.FValue, SaveMsgVal, 2);
end;

procedure TSaveHelper.SaveInt32String(Item: TPair<Integer, string>);
var
  h: TpbSaver;
begin
  S.Pb.writeInt32(1, Value.Key);
  S.Pb.writeString(2, Value.Value);
end;

procedure TSaveHelper.SaveInt64String(Item: TPair<Int64, string>);
var
  h: TpbSaver;
begin
  S.Pb.writeInt64(1, Value.Key);
  S.Pb.writeString(2, Value.Value);
end;

procedure TSaveHelper.SaveBoolString(Item: TPair<Boolean, string>);
var
  h: TpbSaver;
begin
  S.Pb.writeBoolean(1, Value.Key);
  S.Pb.writeString(2, Value.Value);
end;

procedure TSaveHelper.SaveStringMapFields(Item: TPair<string, TMapFields>);
var
  h: TpbSaver;
begin
  S.Pb.writeString(1, Value.Key);
  S.SaveObj<TMapFields>(Value.FValue, SaveMapFields, 2);
end;

end.

