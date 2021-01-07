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

  TLoadHelper = record helper for TpbLoader
  public
    procedure LoadPerson(Person: PPerson);
    procedure LoadPhoneNumber(PhoneNumber: PPhoneNumber);
  end;

  TSaveHelper = record helper for TpbSaver
  type
    TSave<T> = procedure(const h: TpbSaver; const Value: T);
    TSavePair<Key, Value> = procedure(const h: TpbSaver; const Pair: TsgPair<Key, Value>);
  public
    procedure SaveObj<T>(const obj: T; Save: TSave<T>; Tag: Integer);
    procedure SaveList<T>(const List: TsgRecordList<T>; Save: TSave<T>; Tag: Integer);
  end;

procedure SavePerson(const h: TpbSaver; const Person: TPerson);
procedure SavePhoneNumber(const h: TpbSaver; const PhoneNumber: TPhoneNumber);

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

procedure TLoadHelper.LoadPhoneNumber(PhoneNumber: PPhoneNumber);
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

procedure TLoadHelper.LoadPerson(Person: PPerson);
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
            LoadPhoneNumber(Person.FPhones.Add);
          finally
            Pb.Pop;
          end;
        end;
      TPerson.ftMyPhone:
        begin
          Assert(wireType = TWire.LENGTH_DELIMITED);
          Pb.Push;
          try
            LoadPhoneNumber(@Person.FMyPhone);
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

procedure SavePhoneNumber(const h: TpbSaver; const PhoneNumber: TPhoneNumber);
begin
  h.Pb.writeString(TPhoneNumber.ftNumber, PhoneNumber.Number);
  h.Pb.writeInt32(TPhoneNumber.ftType, Ord(PhoneNumber.&Type));
end;

procedure SavePerson(const h: TpbSaver; const Person: TPerson);
begin
  h.Pb.writeString(TPerson.ftName, Person.Name);
  h.Pb.writeInt32(TPerson.ftId, Person.Id);
  h.Pb.writeString(TPerson.ftEmail, Person.Email);
  if Person.FPhones.Count > 0 then
    h.SaveList<TPhoneNumber>(Person.FPhones, SavePhoneNumber, TPerson.ftPhones);
  h.SaveObj<TPhoneNumber>(Person.FMyPhone, SavePhoneNumber, TPerson.ftMyPhone);
end;

end.
