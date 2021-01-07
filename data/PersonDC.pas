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
  public
    function LoadPerson(Person: TPerson): TPerson;
    function LoadPhoneNumber(PhoneNumber: TPhoneNumber): TPhoneNumber;
  end;

  TSaveHelper = record helper for TpbSaver
  type
    TSave<T> = procedure(const h: TpbSaver; const Value: T);
    TSavePair<Key, Value> = procedure(const h: TpbSaver; const Pair: TPair<Key, Value>);
  private
    procedure SaveObj<T>(const obj: T; Save: TSave<T>; Tag: Integer);
    procedure SaveList<T>(const List: TList<T>; Save: TSave<T>; Tag: Integer);
    procedure SaveMap<Key, Value>(const Map: TDictionary<Key, Value>;
      Save: TSavePair<Key, Value>; Tag: Integer);
  public
    class procedure SavePerson(const h: TpbSaver; const Person: TPerson); static;
    class procedure SavePhoneNumber(const h: TpbSaver; const PhoneNumber: TPhoneNumber); static;
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

function TLoadHelper.LoadPhoneNumber(PhoneNumber: TPhoneNumber): TPhoneNumber;
var
  fieldNumber, wireType: integer;
  tag: TpbTag;
begin
  Result := PhoneNumber;
  tag := Pb.readTag;
  while tag.v <> 0 do
  begin
    wireType := tag.WireType;
    fieldNumber := tag.FieldNumber;
    case fieldNumber of
      TPhoneNumber.ftNumber:
        begin
          Assert(wireType = TWire.LENGTH_DELIMITED);
          PhoneNumber.Number := Pb.readString;
        end;
      TPhoneNumber.ftType:
        begin
          Assert(wireType = TWire.VARINT);
          PhoneNumber.&Type := TPhoneType(Pb.readInt32);
        end;
      else
        Pb.skipField(tag);
    end;
    tag := Pb.readTag;
  end;
end;

function TLoadHelper.LoadPerson(Person: TPerson): TPerson;
var
  fieldNumber, wireType: integer;
  tag: TpbTag;
begin
  Result := Person;
  tag := Pb.readTag;
  while tag.v <> 0 do
  begin
    wireType := tag.WireType;
    fieldNumber := tag.FieldNumber;
    case fieldNumber of
      TPerson.ftName:
        begin
          Assert(wireType = TWire.LENGTH_DELIMITED);
          Person.Name := Pb.readString;
        end;
      TPerson.ftId:
        begin
          Assert(wireType = TWire.VARINT);
          Person.Id := Pb.readInt32;
        end;
      TPerson.ftEmail:
        begin
          Assert(wireType = TWire.LENGTH_DELIMITED);
          Person.Email := Pb.readString;
        end;
      TPerson.ftPhones:
        begin
          Assert(wireType = TWire.LENGTH_DELIMITED);
          Pb.Push;
          try
            Person.FPhones.Add(LoadPhoneNumber(TPhoneNumber.Create));
          finally
            Pb.Pop;
          end;
        end;
      TPerson.ftMyPhone:
        begin
          Assert(wireType = TWire.LENGTH_DELIMITED);
          Pb.Push;
          try
            Person.FMyPhone := LoadPhoneNumber(TPhoneNumber.Create);
          finally
            Pb.Pop;
          end;
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


class procedure TSaveHelper.SavePhoneNumber(const h: TpbSaver; const PhoneNumber: TPhoneNumber);
begin
  h.Pb.writeString(TPhoneNumber.ftNumber, PhoneNumber.Number);
  h.Pb.writeInt32(TPhoneNumber.ftType, Ord(PhoneNumber.&Type));
end;

class procedure TSaveHelper.SavePerson(const h: TpbSaver; const Person: TPerson);
begin
  h.Pb.writeString(TPerson.ftName, Person.Name);
  h.Pb.writeInt32(TPerson.ftId, Person.Id);
  h.Pb.writeString(TPerson.ftEmail, Person.Email);
  if Person.FPhones.Count > 0 then
    h.SaveList<TPhoneNumber>(Person.FPhones, SavePhoneNumber, TPerson.ftPhones);
  if Person.FMyPhone <> nil then
    h.SaveObj<TPhoneNumber>(Person.FMyPhone, SavePhoneNumber, TPerson.ftMyPhone);
end;

end.
