unit PersonSGL;

interface

uses
  System.Classes, System.SysUtils, Oz.SGL.Collections, Oz.Pb.Classes;

{$T+}

type
  TPhoneType = (
    MOBILE = 0,
    HOME = 1,
    WORK = 2);

  PPhoneNumber = ^TPhoneNumber;
  TPhoneNumber = record
  const
    ftNumber = 1;
    ftType = 2;
  private
    FNumber: string;
    FType: TPhoneType;
  public
    procedure Init;
    procedure Free;
    // properties
    property Number: string read FNumber write FNumber;
    property &Type: TPhoneType read FType write FType;
  end;

  PPerson = ^TPerson;
  TPerson = record
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
    FPhones: TsgRecordList<TPhoneNumber>;
    FMyPhone: TPhoneNumber;
  public
    procedure Init;
    procedure Free;
    // properties
    property Name: string read FName write FName;
    property Id: Integer read FId write FId;
    property Email: string read FEmail write FEmail;
    property Phones: TsgRecordList<TPhoneNumber> read FPhones;
    property MyPhone: TPhoneNumber read FMyPhone write FMyPhone;
  end;

  PAddressBook = ^TAddressBook;
  TAddressBook = record
  const
    ftPeoples = 1;
  private
    FPeoples: TsgRecordList<TPerson>;
  public
    procedure Init;
    procedure Free;
    // properties
    property Peoples: TsgRecordList<TPerson> read FPeoples;
  end;

  TLoadHelper = record helper for TpbLoader
  public
    procedure LoadPerson(var Value: TPerson);
    procedure LoadPhoneNumber(var Value: TPhoneNumber);
    procedure LoadAddressBook(var Value: TAddressBook);
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
    class procedure SavePerson(const S: TpbSaver; const Value: TPerson); static;
    class procedure SavePhoneNumber(const S: TpbSaver; const Value: TPhoneNumber); static;
    class procedure SaveAddressBook(const S: TpbSaver; const Value: TAddressBook); static;
  end;

implementation

{ TPhoneNumber }

procedure TPhoneNumber.Init;
begin
  Self := Default(TPhoneNumber);
end;

procedure TPhoneNumber.Free;
begin
end;

{ TPerson }

procedure TPerson.Init;
begin
  Self := Default(TPerson);
  FPhones := TsgRecordList<TPhoneNumber>.From(nil);
end;

procedure TPerson.Free;
begin
  FPhones.Free;
end;

{ TAddressBook }

procedure TAddressBook.Init;
begin
  Self := Default(TAddressBook);
  FPeoples := TsgRecordList<TPerson>.From(nil);
end;

procedure TAddressBook.Free;
begin
  FPeoples.Free;
end;

procedure TLoadHelper.LoadPhoneNumber(var Value: TPhoneNumber);
var
  fieldNumber, wireType: integer;
  tag: TpbTag;
begin
  Value.Init;
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
  Value.Init;
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
          Pb.Push;
          try
            LoadPhoneNumber(Value.FPhones.Add^);
          finally
            Pb.Pop;
          end;
        end;
      TPerson.ftMyPhone:
        begin
          Assert(wireType = TWire.LENGTH_DELIMITED);
          Pb.Push;
          try
            LoadPhoneNumber(Value.FMyPhone);
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

procedure TLoadHelper.LoadAddressBook(var Value: TAddressBook);
var
  fieldNumber, wireType: integer;
  tag: TpbTag;
begin
  Value.Init;
  tag := Pb.readTag;
  while tag.v <> 0 do
  begin
    wireType := tag.WireType;
    fieldNumber := tag.FieldNumber;
    case fieldNumber of
      TAddressBook.ftPeoples:
        begin
          Assert(wireType = TWire.LENGTH_DELIMITED);
          Pb.Push;
          try
            LoadPerson(Value.FPeoples.Add^);
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

class procedure TSaveHelper.SavePhoneNumber(const S: TpbSaver; const Value: TPhoneNumber);
begin
  if Value.Number <> '' then
    S.Pb.writeString(TPhoneNumber.ftNumber, Value.Number);
  if Ord(Value.&Type) <> 0 then
    S.Pb.writeInt32(TPhoneNumber.ftType, Ord(Value.&Type));
end;

class procedure TSaveHelper.SavePerson(const S: TpbSaver; const Value: TPerson);
begin
  if Value.Name <> '' then
    S.Pb.writeString(TPerson.ftName, Value.Name);
  if Value.Id <> 0 then
    S.Pb.writeInt32(TPerson.ftId, Value.Id);
  if Value.Email <> '' then
    S.Pb.writeString(TPerson.ftEmail, Value.Email);
  if Value.FPhones.Count > 0 then
    S.SaveList<TPhoneNumber>(Value.FPhones, SavePhoneNumber, TPerson.ftPhones);
  S.SaveObj<TPhoneNumber>(Value.FMyPhone, SavePhoneNumber, TPerson.ftMyPhone);
end;

class procedure TSaveHelper.SaveAddressBook(const S: TpbSaver; const Value: TAddressBook);
begin
  if Value.FPeoples.Count > 0 then
    S.SaveList<TPerson>(Value.FPeoples, SavePerson, TAddressBook.ftPeoples);
end;

end.
