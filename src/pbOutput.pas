unit pbOutput;

interface

uses
  Classes, StrBuffer, pbPublic;

type

  TProtoBufOutput = class;

  IpbMessage = interface
    function getSerializedSize: integer;
    procedure writeTo(buffer: TProtoBufOutput);
  end;

  TProtoBufOutput = class(TInterfacedObject, IpbMessage)
  private
    FBuffer: TSegmentBuffer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure SaveToStream(Stream: TStream);
    procedure SaveToFile(const FileName: string);
    procedure Clear;

    (* Encode and write varint. *)
    procedure writeRawVarint32(value: integer);
    (* Encode and write varint. *)
    procedure writeRawVarint64(value: int64);
    (* Encode and write tag. *)
    procedure writeTag(fieldNumber: integer; wireType: integer);
    (* Encode and write single byte. *)
    procedure writeRawByte(value: shortint);
    (* Write the data with specified size. *)
    procedure writeRawData(const p: Pointer; size: integer);

    (* Get the result as a string *)
    function GetText: AnsiString;
    (* Write a double field, including tag. *)
    procedure writeDouble(fieldNumber: integer; value: double);
    (* Write a single field, including tag. *)
    procedure writeFloat(fieldNumber: integer; value: single);
    (* Write a int64 field, including tag. *)
    procedure writeInt64(fieldNumber: integer; value: int64);
    (* Write a int64 field, including tag. *)
    procedure writeInt32(fieldNumber: integer; value: integer);
    (* Write a fixed64 field, including tag. *)
    procedure writeFixed64(fieldNumber: integer; value: int64);
    (* Write a fixed32 field, including tag. *)
    procedure writeFixed32(fieldNumber: integer; value: integer);
    (* Write a boolean field, including tag. *)
    procedure writeBoolean(fieldNumber: integer; value: boolean);
    (* Write a string field, including tag. *)
    procedure writeString(fieldNumber: integer; const value: AnsiString);
    (* Write a message field, including tag. *)
    procedure writeMessage(fieldNumber: integer; const value: IpbMessage);
    (*  Write a unsigned int32 field, including tag. *)
    procedure writeUInt32(fieldNumber: integer; value: cardinal);
    (* Get serialized size *)
    function getSerializedSize: integer;
    (* Write to buffer *)
    procedure writeTo(buffer: TProtoBufOutput);
  end;

implementation

{$r-}

{ TProtoBuf }

constructor TProtoBufOutput.Create;
begin
  FBuffer := TSegmentBuffer.Create;
  inherited Create;
end;

destructor TProtoBufOutput.Destroy;
begin
  FBuffer.Free;
  inherited Destroy;
end;

procedure TProtoBufOutput.Clear;
begin
  FBuffer.Clear;
end;

procedure TProtoBufOutput.writeRawByte(value: shortint);
begin
  FBuffer.Add(AnsiChar(value));
end;

procedure TProtoBufOutput.writeRawData(const p: Pointer; size: integer);
begin
  FBuffer.Add(p, size);
end;

procedure TProtoBufOutput.writeTag(fieldNumber, wireType: integer);
begin
  writeRawVarint32(makeTag(fieldNumber, wireType));
end;

procedure TProtoBufOutput.writeRawVarint32(value: integer);
var b: shortint;
begin
  repeat
    b := value and $7F;
    value := value shr 7;
    if value <> 0 then
      b := b + $80;
    writeRawByte(b);
  until value = 0;
end;

procedure TProtoBufOutput.writeRawVarint64(value: int64);
var b: shortint;
begin
  repeat
    b := value and $7F;
    value := value shr 7;
    if value <> 0 then
      b := b + $80;
    writeRawByte(b);
  until value = 0;
end;

procedure TProtoBufOutput.writeBoolean(fieldNumber: integer; value: boolean);
begin
  writeTag(fieldNumber, WIRETYPE_VARINT);
  writeRawByte(ord(value));
end;

procedure TProtoBufOutput.writeDouble(fieldNumber: integer; value: double);
begin
  writeTag(fieldNumber, WIRETYPE_FIXED64);
  writeRawData(@value, SizeOf(value));
end;

procedure TProtoBufOutput.writeFloat(fieldNumber: integer; value: Single);
begin
  writeTag(fieldNumber, WIRETYPE_FIXED32);
  writeRawData(@value, SizeOf(value));
end;

procedure TProtoBufOutput.writeFixed32(fieldNumber, value: integer);
begin
  writeTag(fieldNumber, WIRETYPE_FIXED32);
  writeRawData(@value, SizeOf(value));
end;

procedure TProtoBufOutput.writeFixed64(fieldNumber: integer; value: int64);
begin
  writeTag(fieldNumber, WIRETYPE_FIXED64);
  writeRawData(@value, SizeOf(value));
end;

procedure TProtoBufOutput.writeInt32(fieldNumber, value: integer);
begin
  writeTag(fieldNumber, WIRETYPE_VARINT);
  writeRawVarint32(value);
end;

procedure TProtoBufOutput.writeInt64(fieldNumber: integer; value: int64);
begin
  writeTag(fieldNumber, WIRETYPE_VARINT);
  writeRawVarint64(value);
end;

procedure TProtoBufOutput.writeString(fieldNumber: integer; const value: AnsiString);
begin
  writeTag(fieldNumber, WIRETYPE_LENGTH_DELIMITED);
  writeRawVarint32(length(value));
  FBuffer.Add(value);
end;

procedure TProtoBufOutput.writeUInt32(fieldNumber: integer; value: cardinal);
begin
  writeTag(fieldNumber, WIRETYPE_VARINT);
  writeRawVarint32(value);
end;

procedure TProtoBufOutput.writeMessage(fieldNumber: integer;
  const value: IpbMessage);
begin
  writeTag(fieldNumber, WIRETYPE_LENGTH_DELIMITED);
  writeRawVarint32(value.getSerializedSize());
  value.writeTo(self);
end;

function TProtoBufOutput.GetText: AnsiString;
begin
  result := FBuffer.GetText;
end;

procedure TProtoBufOutput.SaveToFile(const FileName: string);
begin
  FBuffer.SaveToFile(FileName);
end;

procedure TProtoBufOutput.SaveToStream(Stream: TStream);
begin
  FBuffer.SaveToStream(Stream);
end;

function TProtoBufOutput.getSerializedSize: integer;
begin
  result := FBuffer.GetCount;
end;

procedure TProtoBufOutput.writeTo(buffer: TProtoBufOutput);
begin
  buffer.FBuffer.Add(GetText);
end;

end.
