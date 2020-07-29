unit pbPublic;

interface

const
  WIRETYPE_VARINT           = 0;
  WIRETYPE_FIXED64          = 1;
  WIRETYPE_LENGTH_DELIMITED = 2;
  WIRETYPE_START_GROUP      = 3;
  WIRETYPE_END_GROUP        = 4;
  WIRETYPE_FIXED32          = 5;

  TAG_TYPE_BITS = 3;
  TAG_TYPE_MASK = (1 shl TAG_TYPE_BITS) - 1;

  RecursionLimit = 64;

(* Given a tag value, determines the wire type (the lower 3 bits). *)
function getTagWireType(tag: integer): integer;

(* Given a tag value, determines the field number (the upper 29 bits). *)
function getTagFieldNumber(tag: integer): integer;

(* Makes a tag value given a field number and wire type. *)
function makeTag(fieldNumber, wireType: integer): integer;

implementation

function getTagWireType(tag: integer): integer;
begin
  result := tag and TAG_TYPE_MASK;
end;

function getTagFieldNumber(tag: integer): integer;
begin
  result := tag shr TAG_TYPE_BITS;
end;

function makeTag(fieldNumber, wireType: integer): integer;
begin
  result := (fieldNumber shl TAG_TYPE_BITS) or wireType;
end;

end.
 