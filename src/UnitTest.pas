// Protocol Buffers - Google's data interchange format
// Copyright 2008 Google Inc.  All rights reserved.
// http://code.google.com/p/protobuf/
//
// author this port to delphi - Marat Shaymardanov, Tomsk 2007, 2018
//
// You can freely use this code in any project
// if sending any postcards with postage stamp to my address:
// Frunze 131/1, 56, Russia, Tomsk, 634021

unit UnitTest;

interface

uses pbPublic, pbInput, pbOutput;

procedure TestAll;

implementation

procedure TestVarint;
type
  TVarintCase = record
    bytes: array [1..10] of Byte;     // Encoded bytes.
    size: Integer;                    // Encoded size, in bytes.
    value: Int64;                     // Parsed value.
  end;
const
  VarintCases: array [0..7] of TVarintCase = (
    // 32-bit values
    (bytes: ($00, $00, $00, $00, $00, $00, $00, $00, $00, $00); size: 1; value: 0),
    (bytes: ($01, $00, $00, $00, $00, $00, $00, $00, $00, $00); size: 1; value: 1),
    (bytes: ($7f, $00, $00, $00, $00, $00, $00, $00, $00, $00); size: 1; value: 127),
    (bytes: ($a2, $74, $00, $00, $00, $00, $00, $00, $00, $00); size: 2; value: 14882),
    (bytes: ($ff, $ff, $ff, $ff, $0f, $00, $00, $00, $00, $00); size: 5; value: -1),
    // 64-bit
    (bytes: ($be, $f7, $92, $84, $0b, $00, $00, $00, $00, $00); size: 5; value: 2961488830),
    (bytes: ($be, $f7, $92, $84, $1b, $00, $00, $00, $00, $00); size: 5; value: 7256456126),
    (bytes: ($80, $e6, $eb, $9c, $c3, $c9, $a4, $49, $00, $00); size: 8; value: 41256202580718336)
  );
var
  i, j: Integer;
  t: TVarintCase;
  pb: TProtoBufInput;
  buf: AnsiString;
  i64: Int64;
  int: Integer;
begin
  for i := 0 to 7 do
  begin
    t := VarintCases[i];
    // создать тестовый буфер
    SetLength(buf, t.size);
    for j := 1 to t.size do buf[j] := AnsiChar(t.bytes[j]);
    pb := TProtoBufInput.Create(@buf[1], t.size);
    try
      if i < 5 then
      begin
        int := pb.readRawVarint32;
        Assert(t.value = int, 'Test Varint fails');
      end
      else
      begin
        i64 := pb.readRawVarint64;
        Assert(t.value = i64, 'Test Varint fails');
      end;
    finally
      pb.Free;
    end;
  end;
end;

procedure TestReadLittleEndian32;
type
  TLittleEndianCase = record
    bytes: array [1..4] of Byte;      // Encoded bytes.
    value: Integer;                   // Parsed value.
  end;
const
  LittleEndianCases: array [0..5] of TLittleEndianCase = (
    (bytes: ($78, $56, $34, $12); value: $12345678),
    (bytes: ($f0, $de, $bc, $9a); value: Integer($9abcdef0)),
    (bytes: ($ff, $00, $00, $00); value: 255),
    (bytes: ($ff, $ff, $00, $00); value: 65535),
    (bytes: ($4e, $61, $bc, $00); value: 12345678),
    (bytes: ($b2, $9e, $43, $ff); value: -12345678)
  );
var
  i, j: Integer;
  t: TLittleEndianCase;
  pb: TProtoBufInput;
  buf: AnsiString;
  int: Integer;
begin
  for i := 0 to 5 do
  begin
    t := LittleEndianCases[i];
    SetLength(buf, 4);
    for j := 1 to 4 do buf[j] := AnsiChar(t.bytes[j]);
    pb := TProtoBufInput.Create(@buf[1], 4);
    try
      int := pb.readRawLittleEndian32;
      Assert(t.value = int, 'Test readRawLittleEndian32 fails');
    finally
      pb.Free;
    end;
  end;
end;

procedure TestReadLittleEndian64;
type
  TLittleEndianCase = record
    bytes: array [1..8] of Byte;      // Encoded bytes.
    value: Int64;                     // Parsed value.
  end;
const
  LittleEndianCases: array [0..3] of TLittleEndianCase = (
    (bytes: ($67, $45, $23, $01, $78, $56, $34, $12); value: $1234567801234567),
    (bytes: ($f0, $de, $bc, $9a, $78, $56, $34, $12); value: $123456789abcdef0),
    (bytes: ($79, $df, $0d, $86, $48, $70, $00, $00); value: 123456789012345),
    (bytes: ($87, $20, $F2, $79, $B7, $8F, $FF, $FF); value: -123456789012345)
  );
var
  i, j: Integer;
  t: TLittleEndianCase;
  pb: TProtoBufInput;
  buf: AnsiString;
  int: Int64;
begin
  for i := 0 to 3 do
  begin
    t := LittleEndianCases[i];
    SetLength(buf, 8);
    for j := 1 to 8 do buf[j] := AnsiChar(t.bytes[j]);
    pb := TProtoBufInput.Create(@buf[1], 8);
    try
      int := pb.readRawLittleEndian64;
      Assert(t.value = int, 'Test readRawLittleEndian64 fails');
    finally
      pb.Free;
    end;
  end;
end;

procedure TestDecodeZigZag;
begin
  (* 32 *)
  Assert( 0 = decodeZigZag32(0));
  Assert(-1 = decodeZigZag32(1));
  Assert( 1 = decodeZigZag32(2));
  Assert(-2 = decodeZigZag32(3));
  Assert(Integer($3FFFFFFF) = decodeZigZag32(Integer($7FFFFFFE)));
  Assert(Integer($C0000000) = decodeZigZag32(Integer($7FFFFFFF)));
  Assert(Integer($7FFFFFFF) = decodeZigZag32(Integer($FFFFFFFE)));
  Assert(Integer($80000000) = decodeZigZag32(Integer($FFFFFFFF)));
  (* 64 *)
  Assert( 0 = decodeZigZag64(0));
  Assert(-1 = decodeZigZag64(1));
  Assert( 1 = decodeZigZag64(2));
  Assert(-2 = decodeZigZag64(3));
  Assert($000000003FFFFFFF = decodeZigZag64($000000007FFFFFFE));
  Assert(Int64($FFFFFFFFC0000000) = decodeZigZag64(Int64($000000007FFFFFFF)));
  Assert(Int64($000000007FFFFFFF) = decodeZigZag64(Int64($00000000FFFFFFFE)));
  Assert(Int64($FFFFFFFF80000000) = decodeZigZag64(Int64($00000000FFFFFFFF)));
  Assert(Int64($7FFFFFFFFFFFFFFF) = decodeZigZag64(Int64($FFFFFFFFFFFFFFFE)));
  Assert(Int64($8000000000000000) = decodeZigZag64(Int64($FFFFFFFFFFFFFFFF)));
end;

procedure TestReadString;
const
  TEST_string  = AnsiString('Тестовая строка');
  TEST_empty_string = AnsiString('');
  TEST_integer = 12345678;
  TEST_single  = 12345.123;
  TEST_double  = 1234567890.123;
var
  out_pb: TProtoBufOutput;
  in_pb: TProtoBufInput;
  tag, t: Integer;
  text: AnsiString;
  int: Integer;
  dbl: Double;
  flt: Single;
  delta: Extended;
begin
  out_pb := TProtoBufOutput.Create;
  out_pb.writeString(1, TEST_string);
  out_pb.writeString(2, TEST_empty_string);
  out_pb.writeFixed32(3, TEST_integer);
  out_pb.writeFloat(4, TEST_single);
  out_pb.writeDouble(5, TEST_double);
  out_pb.SaveToFile('test.dmp');

  in_pb := TProtoBufInput.Create();
  in_pb.LoadFromFile('test.dmp');

  // TEST_string
  tag := makeTag(1, WIRETYPE_LENGTH_DELIMITED);
  t := in_pb.readTag;
  Assert(tag = t);
  text := in_pb.readString;
  Assert(TEST_string = text);

  // TEST_empty_string
  tag := makeTag(2, WIRETYPE_LENGTH_DELIMITED);
  t := in_pb.readTag;
  Assert(tag = t);
  text := in_pb.readString;
  Assert(TEST_empty_string = text);

  // TEST_integer
  tag := makeTag(3, WIRETYPE_FIXED32);
  t := in_pb.readTag;
  Assert(tag = t);
  int := in_pb.readFixed32;
  Assert(TEST_integer = int);

  // TEST_single
  tag := makeTag(4, WIRETYPE_FIXED32);
  t := in_pb.readTag;
  Assert(tag = t);
  flt := in_pb.readFloat;
  delta := TEST_single - flt;
  Assert(abs(delta) < 0.001);

  // TEST_double
  tag := makeTag(5, WIRETYPE_FIXED64);
  t := in_pb.readTag;
  Assert(tag = t);
  dbl := in_pb.readDouble;
  {$OVERFLOWCHECKS ON}
  delta := dbl - TEST_double;
  Assert(abs(delta) < 0.000001);
end;

procedure TestMemoryLeak;
const
  Mb = 1024 * 1024;
var
  in_pb: TProtoBufInput;
  buf_size: Integer;
  s: AnsiString;
  i: Integer;
begin
  buf_size := 64 * Mb;
  SetLength(s, buf_size);
  for i := 0 to 200 do
  begin
    in_pb := TProtoBufInput.Create(PAnsiChar(s), Length(s), False);
    in_pb.Free;
  end;
end;

procedure TestAll;
begin
  TestVarint;
  TestReadLittleEndian32;
  TestReadLittleEndian64;
  TestDecodeZigZag;
  TestReadString;
  TestMemoryLeak;
end;

end.

