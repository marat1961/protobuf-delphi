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

  TProtoBufOutput = class
  private
    FBuffer: TSegmentBuffer;
  protected
    (* Закодировать и записать varint. *)
    procedure writeRawVarint32(value: integer);
    (* Закодировать и записать varint. *)
    procedure writeRawVarint64(value: int64);
    (* Закодировать и записать tag. *)
    procedure writeTag(fieldNumber: integer; wireType: integer);
    (* Записать один байт. *)
    procedure writeRawByte(value: shortint);
    (* Записать данные, указанного размера. *)
    procedure writeRawData(const p: Pointer; size: integer);
  public
    constructor Create;
    destructor Destroy; override;
    procedure SaveToStream(Stream: TStream);
    procedure SaveToFile(const FileName: string);
    procedure Clear;
    (* получить результат в виде строки *)
    function GetText: string;
    (* Записать double поле, включая tag в буфер. *)
    procedure writeDouble(fieldNumber: integer; value: double);
    (* Записать single поле, включая tag в буфер. *)
    procedure writeFloat(fieldNumber: integer; value: Single);
    (* Записать int64 поле, включая tag в буфер. *)
    procedure writeInt64(fieldNumber: integer; value: int64);
    (* Записать int32 поле, включая tag в буфер. *)
    procedure writeInt32(fieldNumber: integer; value: integer);
    (* Записать fixed64 поле, включая tag в буфер. *)
    procedure writeFixed64(fieldNumber: integer; value: int64);
    (* Записать fixed32 поле, включая tag в буфер. *)
    procedure writeFixed32(fieldNumber: integer; value: integer);
    (* Записать boolean поле, включая tag в буфер. *)
    procedure writeBoolean(fieldNumber: integer; value: boolean);
    (* Записать string поле, включая tag в буфер. *)
    procedure writeString(fieldNumber: integer; const value: string);
    (* Записать вложенное message поле, включая tag в буфер. *)
    procedure writeMessage(fieldNumber: integer; const value: IpbMessage);
    (* Записать unsigned int32 поле, включая tag в буфер. *)
    procedure writeUInt32(fieldNumber: integer; value: cardinal);
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
  FBuffer.Add(chr(value));
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
{  if (value >= 0) then
    writeRawVarint32(value)
  else
    // Must sign-extend.
    writeRawVarint64(value);}
end;

procedure TProtoBufOutput.writeInt64(fieldNumber: integer; value: int64);
begin
  writeTag(fieldNumber, WIRETYPE_VARINT);
  writeRawVarint64(value);
end;

procedure TProtoBufOutput.writeString(fieldNumber: integer; const value: string);
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

function TProtoBufOutput.GetText: string;
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

end.
