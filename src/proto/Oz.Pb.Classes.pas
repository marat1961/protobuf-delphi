unit Oz.Pb.Classes;

interface

uses
  Classes, SysUtils, StrBuffer;

const
  TAG_TYPE_BITS = 3;
  TAG_TYPE_MASK = (1 shl TAG_TYPE_BITS) - 1;

  RecursionLimit = 64;

type

{$Region 'TWire'}

  TWireType = 0..7;

  TWire = record
  const
    VARINT = 0;
    FIXED64 = 1;
    LENGTH_DELIMITED = 2;
    START_GROUP = 3;
    END_GROUP = 4;
    FIXED32 = 5;
    Names: array [VARINT .. FIXED32] of string = (
      'VARINT',
      'FIXED64',
      'LENGTH_DELIMITED',
      'START_GROUP',
      'END_GROUP',
      'FIXED32');
  end;

{$EndRegion}

{$Region 'TpbTag: proto field tag'}

  TpbTag = record
  var
    v: Integer;
  public
    // Given a tag value, determines the field number (the upper 29 bits).
    function FieldNumber: Integer; inline;
    // Given a tag value, determines the wire type (the lower 3 bits).
    function WireType: TWireType; inline;
    // Makes a tag value given a field number and wire type.
    procedure MakeTag(FieldNo: Integer; WireType: TWireType); inline;
  end;

{$EndRegion}

{$Region 'TpbInput: Decode data from the buffer and place them to object fields'}

  PpbInput = ^TpbInput;
  TpbInput = record
  const
    RECURSION_LIMIT = 64;
    SIZE_LIMIT = 64 shl 20;  // 64 mb
  private var
    FLen: Integer;
    FBuffer: PByte;
    FPos: Integer;
    FLastTag: TpbTag;
    FOwnsData: Boolean;
    FRecursionDepth: ShortInt;
  public
    procedure Init; overload;
    procedure Init(const pb: TpbInput); overload;
    procedure Init(Buf: PByte; BufSize: Integer; OwnsData: Boolean); overload;
    class function From(const Buf: TBytes): TpbInput; overload; static;
    class function From(Buf: PByte; BufSize: Integer;
      OwnsData: Boolean = False): TpbInput; overload; static;
    procedure Free;

    // I/O routines to file and stream
    procedure SaveToStream(Stream: TStream);
    procedure SaveToFile(const FileName: string);
    procedure LoadFromFile(const FileName: string);
    procedure LoadFromStream(Stream: TStream);
    // Merge messages
    procedure mergeFrom(const builder: TpbInput);
    // Set buffer posititon
    procedure setPos(Pos: Integer);
    // Get buffer posititon
    function getPos: Integer;
    // Attempt to read a field tag, returning zero if we have reached EOF
    function readTag: TpbTag;
    // Check whether the latter match the value read tag
    // Used to test for nested groups
    procedure checkLastTagWas(value: Integer);
    // Reads and discards a Single field, given its tag value
    function skipField(tag: TpbTag): Boolean;
    // Reads and discards an entire message
    procedure skipMessage;
    // Read a Double field value
    function readDouble: Double;
    // Read a float field value
    function readFloat: Single;
    // Read an Int64 field value
    function readInt64: Int64;
    // Read an Int32 field value
    function readInt32: Integer;
    // Read a fixed64 field value
    function readFixed64: Int64;
    // Read a fixed32 field value
    function readFixed32: Integer;
    // Read a Boolean field value
    function readBoolean: Boolean;
    // Read a string field value
    function readString: string;
    // Read nested message
    procedure readMessage(builder: PpbInput);
    // Read a uint32 field value
    function readUInt32: Integer;
    // Read a enum field value
    function readEnum: Integer;
    // Read an sfixed32 field value
    function readSFixed32: Integer;
    // Read an sfixed64 field value
    function readSFixed64: Int64;
    // Read an sint32 field value
    function readSInt32: Integer;
    // Read an sint64 field value
    function readSInt64: Int64;
    // Read a raw Varint from the stream,
    // if larger than 32 bits, discard the upper bits
    function readRawVarint32: Integer;
    // Read a raw Varint
    function readRawVarint64: Int64;
    // Read a 32-bit little-endian Integer
    function readRawLittleEndian32: Integer;
    // Read a 64-bit little-endian Integer
    function readRawLittleEndian64: Int64;
    // Read one byte
    function readRawByte: ShortInt;
    // Read "size" bytes
    procedure readRawBytes(var data; size: Integer);
    function readBytes(size: Integer): TBytes;
    // Skip "size" bytes
    procedure skipRawBytes(size: Integer);
  end;

{$EndRegion}

{$Region 'TpbOutput: Encode the object fields and and write them to buffer'}

  PpbOutput = ^TpbOutput;
  TpbOutput = record
  private
    FBuffer: TSegmentBuffer;
  public
    class function From: TpbOutput; static;
    procedure Free;
    procedure Clear;

    procedure SaveToStream(Stream: TStream); inline;
    procedure SaveToFile(const FileName: string); inline;

    // Encode and write varint
    procedure writeRawVarint32(value: Integer);
    // Encode and write varint
    procedure writeRawVarint64(value: Int64);
    // Encode and write tag
    procedure writeTag(fieldNumber: Integer; wireType: Integer); inline;
    // Encode and write single byte
    procedure writeRawByte(value: ShortInt); inline;
    // Write the data with specified size
    procedure writeRawData(const p: Pointer; size: Integer); inline;

    // Get the result as a bytes
    function GetBytes: TBytes; inline;
    // Write a Double field, including tag
    procedure writeDouble(fieldNumber: Integer; value: Double);
    // Write a Single field, including tag
    procedure writeFloat(fieldNumber: Integer; value: Single);
    // Write a Int64 field, including tag
    procedure writeInt64(fieldNumber: Integer; value: Int64);
    // Write a Int64 field, including tag
    procedure writeInt32(fieldNumber: Integer; value: Integer);
    // Write a fixed64 field, including tag
    procedure writeFixed64(fieldNumber: Integer; value: Int64);
    // Write a fixed32 field, including tag
    procedure writeFixed32(fieldNumber: Integer; value: Integer);
    // Write a Boolean field, including tag
    procedure writeBoolean(fieldNumber: Integer; value: Boolean);
    // Write a string field, including tag
    procedure writeString(fieldNumber: Integer; const value: string);
    // Write a message field, including tag
    procedure writeMessage(fieldNumber: Integer; const value: TpbOutput);
    //  Write a unsigned Int32 field, including tag
    procedure writeUInt32(fieldNumber: Integer; value: Cardinal);
    // Get serialized size
    function getSerializedSize: Integer;
    // Write to buffer
    procedure writeTo(buffer: TpbOutput);
  end;

{$EndRegion}

{$Region 'TpbCustomReader: Base class for a builder'}

  // Builder to download or save the object using the protocol buffer.
  TpbCustomBuilder = class
  private
    Fpbi: TpbInput;
    Fpbo: TpbOutput;
    function GetPbi: PpbInput;
    function GetPbo: PpbOutput;
  public
    constructor Create;
    destructor Destroy; override;
    property Pbi: PpbInput read GetPbi;
    property Pbo: PpbOutput read GetPbo;
  end;

{$EndRegion}

{$Region 'procedures'}

function decodeZigZag32(n: Integer): Integer;
function decodeZigZag64(n: Int64): Int64;

{$EndRegion}

implementation

const
  ProtoBufException = 'Protocol buffer exception: ';

{$Region 'procedures'}

function decodeZigZag32(n: Integer): Integer;
begin
  Result := (n shr 1) xor -(n and 1);
end;

function decodeZigZag64(n: Int64): Int64;
begin
  Result := (n shr 1) xor -(n and 1);
end;

{$EndRegion}

{$Region 'TpbTag'}

function TpbTag.FieldNumber: Integer;
begin
  Result := v shr TAG_TYPE_BITS;
end;

function TpbTag.WireType: TWireType;
begin
  result := v and TAG_TYPE_MASK;
end;

procedure TpbTag.MakeTag(FieldNo: Integer; WireType: TWireType);
begin
  v := (fieldNumber shl TAG_TYPE_BITS) or wireType;
end;

{$EndRegion}

{$Region 'TpbInput'}

procedure TpbInput.Init;
begin
  Self := Default(TpbInput);
end;

procedure TpbInput.Init(Buf: PByte; BufSize: Integer; OwnsData: Boolean);
begin
  FLen := BufSize;
  FPos := 0;
  FOwnsData := OwnsData;
  FRecursionDepth := 0;
  if not OwnsData then
    FBuffer := Buf
  else
  begin
    // allocate a buffer and copy the data
    GetMem(FBuffer, FLen);
    Move(Buf^, FBuffer^, FLen);
  end;
end;

procedure TpbInput.Init(const pb: TpbInput);
begin
  Self.FBuffer := pb.FBuffer;
  Self.FPos := 0;
  Self.FOwnsData := False;
end;

class function TpbInput.From(const Buf: TBytes): TpbInput;
begin
  Result.Init(@Buf[0], Length(Buf), False);
end;

class function TpbInput.From(Buf: PByte; BufSize: Integer;
  OwnsData: Boolean = False): TpbInput;
begin
  Result.Init(Buf, BufSize, OwnsData);
end;

procedure TpbInput.Free;
begin
  if FOwnsData then
    FreeMem(FBuffer, FLen);
  Self := Default(TpbInput);
end;

function TpbInput.readTag: TpbTag;
begin
  if FPos < FLen then
    FLastTag.v := readRawVarint32
  else
    FLastTag.v := 0;
  Result := FLastTag;
end;

procedure TpbInput.checkLastTagWas(value: Integer);
begin
  Assert(FLastTag.v = value, ProtoBufException + 'invalid end tag');
end;

function TpbInput.skipField(tag: TpbTag): Boolean;
begin
  Result := True;
  case tag.WireType of
    TWire.VARINT:
      readInt32;
    TWire.FIXED64:
      readRawLittleEndian64;
    TWire.LENGTH_DELIMITED:
      skipRawBytes(readRawVarint32);
    TWire.FIXED32:
      readRawLittleEndian32;
    else
      raise Exception.Create('InvalidProtocolBufferException.invalidWireType');
  end;
end;

procedure TpbInput.skipMessage;
var tag: TpbTag;
begin
  repeat
    tag := readTag;
  until (tag.v = 0) or (not skipField(tag));
end;

function TpbInput.readDouble: Double;
begin
  readRawBytes(Result, SizeOf(Double));
end;

function TpbInput.readFloat: Single;
begin
  readRawBytes(Result, SizeOf(Single));
end;

function TpbInput.readInt64: Int64;
begin
  Result := readRawVarint64;
end;

function TpbInput.readInt32: Integer;
begin
  Result := readRawVarint32;
end;

function TpbInput.readFixed64: Int64;
begin
  Result := readRawLittleEndian64;
end;

function TpbInput.readFixed32: Integer;
begin
  Result := readRawLittleEndian32;
end;

function TpbInput.readBoolean: Boolean;
begin
  Result := readRawVarint32 <> 0;
end;

function TpbInput.readString: string;
var
  size: Integer;
  buf, text: TBytes;
begin
  size := readRawVarint32;
  Assert(size > 0, ProtoBufException + 'readString (size <= 0)');
  // Decode utf8 to string
  buf := readBytes(size);
  text := TEncoding.UTF8.Convert(TEncoding.UTF8, TEncoding.Unicode, buf);
  Result := TEncoding.Unicode.GetString(text);
end;

procedure TpbInput.readMessage(builder: PpbInput);
begin
  readRawVarint32;
  Assert(FRecursionDepth < RECURSION_LIMIT,
    ProtoBufException + 'recursion Limit Exceeded');
  Inc(FRecursionDepth);
  builder.mergeFrom(Self);
  checkLastTagWas(0);
  dec(FRecursionDepth);
end;

function TpbInput.readUInt32: Integer;
begin
  Result := readRawVarint32;
end;

function TpbInput.readEnum: Integer;
begin
  Result := readRawVarint32;
end;

function TpbInput.readSFixed32: Integer;
begin
  Result := readRawLittleEndian32;
end;

function TpbInput.readSFixed64: Int64;
begin
  Result := readRawLittleEndian64;
end;

function TpbInput.readSInt32: Integer;
begin
  Result := decodeZigZag32(readRawVarint32);
end;

function TpbInput.readSInt64: Int64;
begin
  Result := decodeZigZag64(readRawVarint64);
end;

function TpbInput.readRawVarint32: Integer;
var
  tmp: ShortInt;
  shift: Integer;
begin
  shift := 0;
  Result := 0;
  repeat
    // for negative numbers number value may be to 10 byte
    Assert(shift < 64, ProtoBufException + 'malformed Varint');
    tmp := readRawByte;
    Result := Result or ((tmp and $7f) shl shift);
    Inc(shift, 7);
  until tmp >= 0;
end;

function TpbInput.readRawVarint64: Int64;
var
  tmp: ShortInt;
  shift: Integer;
  i64: Int64;
begin
  shift := -7;
  Result := 0;
  repeat
    Inc(shift, 7);
    Assert(shift < 64, ProtoBufException + 'malformed Varint');
    tmp := readRawByte;
    i64 := tmp and $7f;
    i64 := i64 shl shift;
    Result := Result or i64;
  until tmp >= 0;
end;

function TpbInput.readRawLittleEndian32: Integer;
begin
  readRawBytes(Result, SizeOf(Result));
end;

function TpbInput.readRawLittleEndian64: Int64;
begin
  readRawBytes(Result, SizeOf(Result));
end;

function TpbInput.readRawByte: ShortInt;
begin
  Assert(FPos < FLen, ProtoBufException + 'eof encounterd');
  Result := ShortInt(FBuffer[FPos]);
  Inc(FPos);
end;

procedure TpbInput.readRawBytes(var data; size: Integer);
begin
  Assert(FPos + size <= FLen, ProtoBufException + 'eof encounterd');
  Move(FBuffer[FPos], data, size);
  Inc(FPos, size);
end;

function TpbInput.readBytes(size: Integer): TBytes;
begin
  Assert(FPos + size <= FLen, ProtoBufException + 'eof encounterd');
  SetLength(Result, size);
  Move(FBuffer[FPos], Pointer(Result)^, size);
  Inc(FPos, size);
end;

procedure TpbInput.skipRawBytes(size: Integer);
begin
  Assert(size >= 0, ProtoBufException + 'negative Size');
  Assert(FPos + size <= FLen, ProtoBufException + 'truncated Message');
  Inc(FPos, size);
end;

procedure TpbInput.SaveToFile(const FileName: string);
var Stream: TStream;
begin
  Stream := TFileStream.Create(FileName, fmCreate);
  try
    SaveToStream(Stream);
  finally
    Stream.Free;
  end;
end;

procedure TpbInput.SaveToStream(Stream: TStream);
begin
  Stream.WriteBuffer(Pointer(FBuffer)^, FLen);
end;

procedure TpbInput.LoadFromFile(const FileName: string);
var Stream: TStream;
begin
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    LoadFromStream(Stream);
  finally
    Stream.Free;
  end;
end;

procedure TpbInput.LoadFromStream(Stream: TStream);
begin
  if FOwnsData then begin
    FreeMem(FBuffer, FLen);
    FBuffer := nil;
  end;
  FOwnsData := True;
  FLen := Stream.Size;
  GetMem(FBuffer, FLen);
  Stream.Position := 0;
  Stream.Read(Pointer(FBuffer)^, FLen);
end;

procedure TpbInput.mergeFrom(const builder: TpbInput);
begin
  Assert(False, 'under conctruction');
end;

procedure TpbInput.setPos(Pos: Integer);
begin
  FPos := Pos;
end;

function TpbInput.getPos: Integer;
begin
  Result := FPos;
end;

{$EndRegion}


class function TpbOutput.From: TpbOutput;
begin
  Result.FBuffer := TSegmentBuffer.Create;
end;

procedure TpbOutput.Free;
begin
  FreeAndNil(FBuffer);
end;

procedure TpbOutput.Clear;
begin
  FBuffer.Clear;
end;

procedure TpbOutput.writeRawByte(value: ShortInt);
begin
  // -128..127
  FBuffer.Add(Byte(value));
end;

procedure TpbOutput.writeRawData(const p: Pointer; size: Integer);
begin
  FBuffer.Add(p, size);
end;

procedure TpbOutput.writeTag(fieldNumber, wireType: Integer);
var
  tag: TpbTag;
begin
  tag.MakeTag(fieldNumber, wireType);
  writeRawVarint32(tag.v);
end;

procedure TpbOutput.writeRawVarint32(value: Integer);
var b: ShortInt;
begin
  repeat
    b := value and $7F;
    value := value shr 7;
    if value <> 0 then
      b := b + $80;
    writeRawByte(b);
  until value = 0;
end;

procedure TpbOutput.writeRawVarint64(value: Int64);
var b: ShortInt;
begin
  repeat
    b := value and $7F;
    value := value shr 7;
    if value <> 0 then
      b := b + $80;
    writeRawByte(b);
  until value = 0;
end;

procedure TpbOutput.writeBoolean(fieldNumber: Integer; value: Boolean);
begin
  writeTag(fieldNumber, TWire.VARINT);
  writeRawByte(ord(value));
end;

procedure TpbOutput.writeDouble(fieldNumber: Integer; value: Double);
begin
  writeTag(fieldNumber, TWire.FIXED64);
  writeRawData(@value, SizeOf(value));
end;

procedure TpbOutput.writeFloat(fieldNumber: Integer; value: Single);
begin
  writeTag(fieldNumber, TWire.FIXED32);
  writeRawData(@value, SizeOf(value));
end;

procedure TpbOutput.writeFixed32(fieldNumber, value: Integer);
begin
  writeTag(fieldNumber, TWire.FIXED32);
  writeRawData(@value, SizeOf(value));
end;

procedure TpbOutput.writeFixed64(fieldNumber: Integer; value: Int64);
begin
  writeTag(fieldNumber, TWire.FIXED64);
  writeRawData(@value, SizeOf(value));
end;

procedure TpbOutput.writeInt32(fieldNumber, value: Integer);
begin
  writeTag(fieldNumber, TWire.VARINT);
  writeRawVarint32(value);
end;

procedure TpbOutput.writeInt64(fieldNumber: Integer; value: Int64);
begin
  writeTag(fieldNumber, TWire.VARINT);
  writeRawVarint64(value);
end;

procedure TpbOutput.writeString(fieldNumber: Integer;
  const value: string);
var
  bytes, text: TBytes;
begin
  writeTag(fieldNumber, TWire.LENGTH_DELIMITED);
  bytes := TEncoding.Unicode.GetBytes(value);
  text := TEncoding.Unicode.Convert(TEncoding.Unicode, TEncoding.UTF8, bytes);
  writeRawVarint32(Length(text));
  FBuffer.Add(text);
end;

procedure TpbOutput.writeUInt32(fieldNumber: Integer; value: Cardinal);
begin
  writeTag(fieldNumber, TWire.VARINT);
  writeRawVarint32(value);
end;

procedure TpbOutput.writeMessage(fieldNumber: Integer;
  const value: TpbOutput);
begin
  writeTag(fieldNumber, TWire.LENGTH_DELIMITED);
  writeRawVarint32(value.getSerializedSize);
  value.writeTo(self);
end;

function TpbOutput.GetBytes: TBytes;
begin
  result := FBuffer.GetBytes;
end;

procedure TpbOutput.SaveToFile(const FileName: string);
begin
  FBuffer.SaveToFile(FileName);
end;

procedure TpbOutput.SaveToStream(Stream: TStream);
begin
  FBuffer.SaveToStream(Stream);
end;

function TpbOutput.getSerializedSize: Integer;
begin
  result := FBuffer.GetCount;
end;

procedure TpbOutput.writeTo(buffer: TpbOutput);
begin
  buffer.FBuffer.Add(GetBytes);
end;

{$EndRegion}

{$Region 'TpbCustomBuilder'}

constructor TpbCustomBuilder.Create;
begin
  inherited;
  FPbi.Init;
  FPbo := TpbOutput.From;
end;

destructor TpbCustomBuilder.Destroy;
begin
  FPbi.Free;
  FPbo.Free;
  inherited;
end;

function TpbCustomBuilder.GetPbi: PpbInput;
begin
  Result := @FPbi;
end;

function TpbCustomBuilder.GetPbo: PpbOutput;
begin
  Result := @FPbo;
end;

{$EndRegion}

end.
