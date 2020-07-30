// Copyright 2003 Google Inc.  All rights reserved.
// http://code.google.com/p/protobuf/
//
// author this port to delphi - Marat Shaymardanov, Tomsk 2007, 2018
//
// You can freely use this code in any project
// if sending any postcards with postage stamp to my address:
// Frunze 131/1, 56, Russia, Tomsk, 634021

unit pbInput;

interface

uses Classes, SysUtils, pbPublic;

type

  TProtoBufInput = class;

  IExtensionRegistry = interface
    ['{B08BC625-245E-4C25-98DD-98859B951CC7}']
  end;

  IBuilder = interface
    ['{98E70F9E-9236-48B2-A6BB-6468150B3A58}']
    procedure mergeFrom(input: TProtoBufInput; extReg: IExtensionRegistry);
  end;

  // Reads and decodes protocol message fields.
  TProtoBufInput = class
  private
    FBuffer: PAnsiChar;
    FPos: Integer;
    FLen: Integer;
    FSizeLimit: Integer;
    FRecursionDepth: Integer;
    FLastTag: Integer;
    FOwnObject: boolean;
  public
    constructor Create; overload;
    constructor Create(buf: PAnsiChar; len: Integer; OwnsObjects: boolean = False); overload;
    destructor Destroy; override;
    // I/O routines for files & streams
    procedure SaveToStream(Stream: TStream);
    procedure SaveToFile(const FileName: string);
    procedure LoadFromFile(const FileName: string);
    procedure LoadFromStream(Stream: TStream);
    // Set buffer posititon
    procedure setPos(aPos: Integer);
    // Get buffer posititon
    function getPos: Integer;
    // Attempt to read a field tag, returning zero if we have reached EOF.
    function readTag: Integer;
    // Check whether the latter match the value read tag.
    // Used to test for nested groups.
    procedure checkLastTagWas(value: Integer);
    // Reads and discards a Single field, given its tag value.
    function skipField(tag: Integer): boolean;
    // Reads and discards an entire message.
    procedure skipMessage;
    // Read a Double field value
    function readDouble: Double;
    // Read a float field value
    function readFloat: Single;
    // Read an Int64 field value
    function readInt64: Int64;
    // Read an int32 field value
    function readInt32: Integer;
    // Read a fixed64 field value
    function readFixed64: Int64;
    // Read a fixed32 field value
    function readFixed32: Integer;
    // Read a boolean field value
    function readBoolean: boolean;
    // Read a AnsiString field value
    function readString: AnsiString;
    // Read nested message
    procedure readMessage(builder: IBuilder; extensionRegistry: IExtensionRegistry);
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
    // Read a raw Varint from the stream. If larger than 32 bits, discard the upper bits
    function readRawVarint32: Integer;
    // Read a raw Varint
    function readRawVarint64: Int64;
    // Read a 32-bit little-endian Integer
    function readRawLittleEndian32: Integer;
    // Read a 64-bit little-endian Integer
    function readRawLittleEndian64: Int64;
    // Read one byte
    function readRawByte: Shortint;
    // Read "size" bytes
    procedure readRawBytes(var data; size: Integer);
    // Skip "size" bytes
    procedure skipRawBytes(size: Integer);
  end;

function decodeZigZag32(n: Integer): Integer;
function decodeZigZag64(n: Int64): Int64;

implementation

const
  ProtoBufException = 'Protocol buffer exception: ';
  DEFAULT_RECURSION_LIMIT = 64;
  DEFAULT_SIZE_LIMIT = 64 shl 20; // 64MB

function decodeZigZag32(n: Integer): Integer;
begin
  Result := (n shr 1) xor -(n and 1);
end;

function decodeZigZag64(n: Int64): Int64;
begin
  Result := (n shr 1) xor -(n and 1);
end;

{ TProtoBufInput }

constructor TProtoBufInput.Create;
begin
  inherited Create;
  FPos := 0;
  FLen := 256;
  GetMem(FBuffer, FLen);
  FSizeLimit := DEFAULT_SIZE_LIMIT;
  FRecursionDepth := DEFAULT_RECURSION_LIMIT;
  FOwnObject := true;
end;

constructor TProtoBufInput.Create(buf: PAnsiChar; len: Integer; OwnsObjects: boolean);
begin
  inherited Create;
  if not OwnsObjects then
    FBuffer := buf
  else
  begin
    // allocate a buffer and copy the data
    GetMem(FBuffer, len);
    Move(buf^, FBuffer^, len);
  end;
  FPos := 0;
  FLen := len;
  FSizeLimit := DEFAULT_SIZE_LIMIT;
  FRecursionDepth := DEFAULT_RECURSION_LIMIT;
  FOwnObject := OwnsObjects;
end;

destructor TProtoBufInput.Destroy;
begin
  if FOwnObject then
    FreeMem(FBuffer, FLen);
  inherited Destroy;
end;

function TProtoBufInput.readTag: Integer;
begin
  if FPos <= FLen then
    FLastTag := readRawVarint32
  else
    FLastTag := 0;
  Result := FLastTag;
end;

procedure TProtoBufInput.checkLastTagWas(value: Integer);
begin
  Assert(FLastTag = value, ProtoBufException + 'invalid end tag');
end;

function TProtoBufInput.skipField(tag: Integer): boolean;
begin
  Result := True;
  case getTagWireType(tag) of
    WIRETYPE_VARINT:
      readInt32;
    WIRETYPE_FIXED64:
      readRawLittleEndian64;
    WIRETYPE_LENGTH_DELIMITED:
      skipRawBytes(readRawVarint32());
    WIRETYPE_FIXED32:
      readRawLittleEndian32();
  else
    raise Exception.Create('InvalidProtocolBufferException.invalidWireType');
  end;
end;

procedure TProtoBufInput.skipMessage;
var
  tag: Integer;
begin
  repeat
    tag := readTag();
  until (tag = 0) or (not skipField(tag));
end;

function TProtoBufInput.readDouble: Double;
begin
  readRawBytes(Result, SizeOf(Double));
end;

function TProtoBufInput.readFloat: Single;
begin
  readRawBytes(Result, SizeOf(Single));
end;

function TProtoBufInput.readInt64: Int64;
begin
  Result := readRawVarint64;
end;

function TProtoBufInput.readInt32: Integer;
begin
  Result := readRawVarint32;
end;

function TProtoBufInput.readFixed64: Int64;
begin
  Result := readRawLittleEndian64;
end;

function TProtoBufInput.readFixed32: Integer;
begin
  Result := readRawLittleEndian32;
end;

function TProtoBufInput.readBoolean: boolean;
begin
  Result := readRawVarint32 <> 0;
end;

function TProtoBufInput.readString: AnsiString;
var
  size: Integer;
begin
  size := readRawVarint32;
  Assert(size >= 0, ProtoBufException + 'readString (size <= 0)');
  SetString(Result, FBuffer + FPos, size);
  Inc(FPos, size);
end;

procedure TProtoBufInput.readMessage(builder: IBuilder; extensionRegistry: IExtensionRegistry);
begin
  readRawVarint32;
  Assert(FRecursionDepth < RecursionLimit, ProtoBufException + 'recursion Limit Exceeded');
  Inc(FRecursionDepth);
  builder.mergeFrom(Self, extensionRegistry);
  checkLastTagWas(0);
  dec(FRecursionDepth);
end;

function TProtoBufInput.readUInt32: Integer;
begin
  Result := readRawVarint32;
end;

function TProtoBufInput.readEnum: Integer;
begin
  Result := readRawVarint32;
end;

function TProtoBufInput.readSFixed32: Integer;
begin
  Result := readRawLittleEndian32;
end;

function TProtoBufInput.readSFixed64: Int64;
begin
  Result := readRawLittleEndian64;
end;

function TProtoBufInput.readSInt32: Integer;
begin
  Result := decodeZigZag32(readRawVarint32);
end;

function TProtoBufInput.readSInt64: Int64;
begin
  Result := decodeZigZag64(readRawVarint64());
end;

function TProtoBufInput.readRawVarint32: Integer;
var
  tmp: Shortint;
  shift: Integer;
begin
  shift := -7;
  Result := 0;
  repeat
    Inc(shift, 7);
    // for negative numbers number value may be to 10 byte
    Assert(shift < 64, ProtoBufException + 'malformed Varint');
    tmp := readRawByte;
    Result := Result or ((tmp and $7F) shl shift);
  until tmp >= 0;
end;

function TProtoBufInput.readRawVarint64: Int64;
var
  tmp: Shortint;
  shift: Integer;
  i64: Int64;
begin
  shift := -7;
  Result := 0;
  repeat
    Inc(shift, 7);
    Assert(shift < 64, ProtoBufException + 'malformed Varint');
    tmp := readRawByte;
    i64 := tmp and $7F;
    i64 := i64 shl shift;
    Result := Result or i64;
  until tmp >= 0;
end;

function TProtoBufInput.readRawLittleEndian32: Integer;
begin
  readRawBytes(Result, SizeOf(Result));
end;

function TProtoBufInput.readRawLittleEndian64: Int64;
begin
  readRawBytes(Result, SizeOf(Result));
end;

function TProtoBufInput.readRawByte: Shortint;
begin
  Assert(FPos <= FLen, ProtoBufException + 'eof encounterd');
  Result := Shortint(FBuffer[FPos]);
  Inc(FPos);
end;

procedure TProtoBufInput.readRawBytes(var data; size: Integer);
begin
  Assert(FPos + size <= FLen, ProtoBufException + 'eof encounterd');
  Move(FBuffer[FPos], data, size);
  Inc(FPos, size);
end;

procedure TProtoBufInput.skipRawBytes(size: Integer);
begin
  Assert(size >= 0, ProtoBufException + 'negative Size');
  Assert((FPos + size) < FLen, ProtoBufException + 'truncated Message');
  Inc(FPos, size);
end;

procedure TProtoBufInput.SaveToFile(const FileName: string);
var
  Stream: TStream;
begin
  Stream := TFileStream.Create(FileName, fmCreate);
  try
    SaveToStream(Stream);
  finally
    Stream.Free;
  end;
end;

procedure TProtoBufInput.SaveToStream(Stream: TStream);
begin
  Stream.WriteBuffer(Pointer(FBuffer)^, FLen);
end;

procedure TProtoBufInput.LoadFromFile(const FileName: string);
var
  Stream: TStream;
begin
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    LoadFromStream(Stream);
  finally
    Stream.Free;
  end;
end;

procedure TProtoBufInput.LoadFromStream(Stream: TStream);
begin
  if FOwnObject then
  begin
    FreeMem(FBuffer, FLen);
    FBuffer := nil;
  end;
  FOwnObject := True;
  FLen := Stream.Size;
  GetMem(FBuffer, FLen);
  Stream.Position := 0;
  Stream.Read(Pointer(FBuffer)^, FLen);
end;

procedure TProtoBufInput.setPos(aPos: Integer);
begin
  FPos := aPos;
end;

function TProtoBufInput.getPos: Integer;
begin
  Result := FPos;
end;

end.

