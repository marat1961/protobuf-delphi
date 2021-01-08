unit PersonDC;

interface

uses
  System.Classes, System.SysUtils, Generics.Collections, Oz.Pb.Classes;

type

  TPhoneType = (
    MOBILE = 0,
    HOME = 1,
    WORK = 2);

  TPhoneNumber = class
  const
    ftNumber = 1;
    ftType = 2;
  private
    FNumber: string;
    FType: TPhoneType;
  public
    constructor Create;
    destructor Destroy; override;
    // properties
    property Number: string read FNumber write FNumber;
    property &Type: TPhoneType read FType write FType;
  end;

  TPerson = class
  const
    ftName = 1;
    ftId = 2;
    ftEmail = 3;
    ftPhones = 4;
    ftMyPhone = 5;
  private
    FName: string;
    FId: Integer;
    FEmail: string;
    FPhones: TList<TPhoneNumber>;
    FMyPhone: TPhoneNumber;
  public
    constructor Create;
    destructor Destroy; override;
    // properties
    property Name: string read FName write FName;
    property Id: Integer read FId write FId;
    property Email: string read FEmail write FEmail;
    property Phones: TList<TPhoneNumber> read FPhones;
    property MyPhone: TPhoneNumber read FMyPhone write FMyPhone;
  end;

  TLoadHelper = record helper for TpbLoader
  type
    TLoad<T: constructor> = procedure(var Value: T) of object;
    TLoadPair<Key, Value> = procedure(var Pair: TPair<Key, Value>) of object;
  private
    procedure LoadObj<T: constructor>(var obj: T; Load: TLoad<T>);
    procedure LoadList<T: constructor>(const List: TList<T>; Load: TLoad<T>);
  public
    procedure LoadPerson(var Value: TPerson);
    procedure LoadPhoneNumber(var Value: TPhoneNumber);
  end;

  TSaveHelper = record helper for TpbSaver
  type
    TSave<T> = procedure(const S: TpbSaver; const Value: T);
    TSavePair<Key, Value> = procedure(const S: TpbSaver; const Pair: TPair<Key, Value>);
  private
    procedure SaveObj<T>(const obj: T; Save: TSave<T>; Tag: Integer);
    procedure SaveList<T>(const List: TList<T>; Save: TSave<T>; Tag: Integer);
    procedure SaveMap<Key, Value>(const Map: TDictionary<Key, Value>;
      Save: TSavePair<Key, Value>; Tag: Integer);
  public
    class procedure SavePerson(const S: TpbSaver; const Value: TPerson); static;
    class procedure SavePhoneNumber(const S: TpbSaver; const Value: TPhoneNumber); static;
  end;

implementation

{ TPhoneNumber }

constructor TPhoneNumber.Create;
begin
  inherited Create;
end;

destructor TPhoneNumber.Destroy;
begin
  inherited Destroy;
end;

{ TPerson }

constructor TPerson.Create;
begin
  inherited Create;
  FPhones := TList<TPhoneNumber>.Create;
end;

destructor TPerson.Destroy;
begin
  FPhones.Free;
  inherited Destroy;
end;

{ TLoadHelper }

procedure TLoadHelper.LoadObj<T>(var obj: T; Load: TLoad<T>);
begin
  Pb.Push;
  try
    obj := T.Create;
    Load(obj);
  finally
    Pb.Pop;
  end;
end;

procedure TLoadHelper.LoadList<T>(const List: TList<T>; Load: TLoad<T>);
var
  obj: T;
begin
  Pb.Push;
  try
    obj := T.Create;
    Load(obj);
    List.Add(obj);
  finally
    Pb.Pop;
  end;
end;

procedure TLoadHelper.LoadPhoneNumber(var Value: TPhoneNumber);
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
      TPhoneNumber.ftNumber:
        begin
          Assert(wireType = TWire.LENGTH_DELIMITED);
          Value.Number := Pb.readString;
        end;
      TPhoneNumber.ftType:
        begin
          Assert(wireType = TWire.VARINT);
          Value.&Type := TPhoneType(Pb.readInt32);
        end;
      else
        Pb.skipField(tag);
    end;
    tag := Pb.readTag;
  end;
end;

procedure TLoadHelper.LoadPerson(var Value: TPerson);
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
      TPerson.ftName:
        begin
          Assert(wireType = TWire.LENGTH_DELIMITED);
          Value.Name := Pb.readString;
        end;
      TPerson.ftId:
        begin
          Assert(wireType = TWire.VARINT);
          Value.Id := Pb.readInt32;
        end;
      TPerson.ftEmail:
        begin
          Assert(wireType = TWire.LENGTH_DELIMITED);
          Value.Email := Pb.readString;
        end;
      TPerson.ftPhones:
        begin
          Assert(wireType = TWire.LENGTH_DELIMITED);
          LoadList<TPhoneNumber>(Value.FPhones, LoadPhoneNumber);
        end;
      TPerson.ftMyPhone:
        begin
          Assert(wireType = TWire.LENGTH_DELIMITED);
          LoadObj<TPhoneNumber>(Value.FMyPhone, LoadPhoneNumber);
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

procedure TSaveHelper.SaveList<T>(const List: TList<T>; Save: TSave<T>; Tag: Integer);
var
  i: Integer;
  h: TpbSaver;
  Item: T;
begin
  h.Init;
  try
    for i := 0 to List.Count - 1 do
    begin
      h.Clear;
      Item := List[i];
      Save(h, Item);
      Pb.writeMessage(tag, h.Pb^);
    end;
  finally
    h.Free;
  end;
end;

procedure TSaveHelper.SaveMap<Key, Value>(const Map: TDictionary<Key, Value>;
  Save: TSavePair<Key, Value>; Tag: Integer);
var
  h: TpbSaver;
  Pair: TPair<Key, Value>;
begin
  h.Init;
  try
    for Pair in Map do
    begin
      h.Clear;
      Save(h, Pair);
      Pb.writeMessage(tag, h.Pb^);
    end;
  finally
    h.Free;
  end;
end;

class procedure TSaveHelper.SavePhoneNumber(const S: TpbSaver; const Value: TPhoneNumber);
begin
  S.Pb.writeString(TPhoneNumber.ftNumber, Value.Number);
  S.Pb.writeInt32(TPhoneNumber.ftType, Ord(Value.&Type));
end;

class procedure TSaveHelper.SavePerson(const S: TpbSaver; const Value: TPerson);
begin
  S.Pb.writeString(TPerson.ftName, Value.Name);
  S.Pb.writeInt32(TPerson.ftId, Value.Id);
  S.Pb.writeString(TPerson.ftEmail, Value.Email);
  if Value.FPhones.Count > 0 then
    S.SaveList<TPhoneNumber>(Value.FPhones, SavePhoneNumber, TPerson.ftPhones);
  if Value.FMyPhone <> nil then
    S.SaveObj<TPhoneNumber>(Value.FMyPhone, SavePhoneNumber, TPerson.ftMyPhone);
end;

end.
