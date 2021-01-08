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
    procedure LoadPerson(var Value: TPerson);
    procedure LoadPhoneNumber(var Value: TPhoneNumber);
  end;

  TSaveHelper = record helper for TpbSaver
  type
    TSave<T> = procedure(const h: TpbSaver; const Value: T);
    TSavePair<Key, Value> = procedure(const h: TpbSaver; const Pair: TsgPair<Key, Value>);
  private
    procedure SaveObj<T>(const obj: T; Save: TSave<T>; Tag: Integer);
    procedure SaveList<T>(const List: TsgRecordList<T>; Save: TSave<T>; Tag: Integer);
  public
    class procedure SavePerson(const S: TpbSaver; const Value: TPerson); static;
    class procedure SavePhoneNumber(const S: TpbSaver; const Value: TPhoneNumber); static;
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
  S.SaveObj<TPhoneNumber>(Value.FMyPhone, SavePhoneNumber, TPerson.ftMyPhone);
end;

end.
