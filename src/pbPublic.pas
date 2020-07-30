// Protocol Buffers - Google's data interchange format
// Copyright 2008 Google Inc.  All rights reserved.
// http://code.google.com/p/protobuf/
//
// author this port to delphi - Marat Shaymardanov, Tomsk 2007, 2018
//
// You can freely use this code in any project
// if sending any postcards with postage stamp to my address:
// Frunze 131/1, 56, Russia, Tomsk, 634021

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

(* Get a tag value, determines the wire type (the lower 3 bits) *)
function getTagWireType(tag: Integer): Integer;

(* Get a tag value, determines the field number (the upper 29 bits) *)
function getTagFieldNumber(tag: Integer): Integer;

(* Makes a tag value given a field number and wire type *)
function makeTag(fieldNumber, wireType: Integer): Integer;

implementation

function getTagWireType(tag: Integer): Integer;
begin
  Result := tag and TAG_TYPE_MASK;
end;

function getTagFieldNumber(tag: Integer): Integer;
begin
  Result := tag shr TAG_TYPE_BITS;
end;

function makeTag(fieldNumber, wireType: Integer): Integer;
begin
  Result := (fieldNumber shl TAG_TYPE_BITS) or wireType;
end;

end.

