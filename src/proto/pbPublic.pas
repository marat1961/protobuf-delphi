// Protocol Buffers - Google's data interchange format
// Copyright 2008 Google Inc.  All rights reserved.
// http://code.google.com/p/protobuf/
//
// Author this port to delphi - Marat Shaimardanov, Tomsk (2007..2020)
//
// Send any postcards with postage stamp to my address:
// Frunze 131/1, 56, Russia, Tomsk, 634021
// then you can use this code in self project.

unit pbPublic;

interface

const
  WIRETYPE_VARINT = 0;
  WIRETYPE_FIXED64 = 1;
  WIRETYPE_LENGTH_DELIMITED = 2;
  WIRETYPE_START_GROUP = 3;
  WIRETYPE_END_GROUP = 4;
  WIRETYPE_FIXED32 = 5;

  TAG_TYPE_BITS = 3;
  TAG_TYPE_MASK = (1 shl TAG_TYPE_BITS) - 1;

  RecursionLimit = 64;

// Given a tag value, determines the wire type (the lower 3 bits).
function getTagWireType(tag: Integer): Integer; inline;

// Given a tag value, determines the field number (the upper 29 bits).
function getTagFieldNumber(tag: Integer): Integer; inline;

// Makes a tag value given a field number and wire type.
function makeTag(fieldNumber, wireType: Integer): Integer; inline;

implementation

function getTagWireType(tag: Integer): Integer;
begin
  result := tag and TAG_TYPE_MASK;
end;

function getTagFieldNumber(tag: Integer): Integer;
begin
  result := tag shr TAG_TYPE_BITS;
end;

function makeTag(fieldNumber, wireType: Integer): Integer;
begin
  result := (fieldNumber shl TAG_TYPE_BITS) or wireType;
end;

end.
