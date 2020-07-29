//
//	author Marat Shaymardanov, Tomsk 2001
//
// You can freely use this code in any project
// if sending any postcards with postage stamp to my address:
// Frunze 131/1, 56, Russia, Tomsk, 634021
//
//  The buffer for strings.
//  The main purpose of the rapid format of long string.
//     Features:
//     1. Minimize the handling of the memory manager.
//     2. One-time allocation of the specified size
//     3. The class is not multi-thread safe
//

unit StrBuffer;

interface

uses Classes, SysUtils;

const
  MaxBuffSize = Maxint div 16;
  SBufferIndexError = 'Buffer index out of bounds (%d)';
  SBufferCapacityError = 'Buffer capacity out of bounds (%d)';
  SBufferCountError = 'Buffer count out of bounds (%d)';

type

{
  If you do not have enough space in the string than
  is taken a piece of memory twice the size
  and copies the data in this chunk of memory
}
  TStrBuffer = class
  private
    FCount: Integer;
    FCapacity: Integer;
    FBuff: PChar;
  protected
    class procedure Error(const Msg: string; Data: Integer);
  public
    constructor Create;
    destructor Destroy; override;
    procedure SaveToStream(Stream: TStream);
    procedure SaveToFile(const FileName: string);
    procedure LoadFromFile(const FileName: string);
    procedure LoadFromStream(Stream: TStream);
    procedure Clear;
    procedure Add(const aValue: string); overload;
    procedure SetCapacity(NewCapacity: Integer);
    function GetText: string;
    function GetCount: integer;
  end;

  PSegment = ^TSegment;
  TSegment = record
    Next: PSegment;
    Size: integer;
    Count: integer;
    Data: array[0..0] of char;
  end;

  { add memory done by segments }
  TSegmentBuffer = class
  private
    FCount: Integer;
    FCapacity: Integer;
    FFirst: PSegment;
    FLast: PSegment;
  protected
    class procedure Error(const Msg: string; Data: Integer);
  public
    constructor Create;
    destructor Destroy; override;
    procedure SaveToStream(Stream: TStream);
    procedure SaveToFile(const FileName: string);
    procedure LoadFromFile(const FileName: string);
    procedure LoadFromStream(Stream: TStream);
    procedure Clear;
    procedure AddSegment(aSize: integer);
    procedure Add(const aValue: char); overload;
    procedure Add(const aValue: string); overload;
    procedure Add(const aValue: PChar; aCnt: integer); overload;
    function GetText: string;
    function GetCount: integer;
    property Text: string read GetText;
  end;

implementation

{$RANGECHECKS OFF}

{ TStrBuffer }

class procedure TStrBuffer.Error(const Msg: string; Data: Integer);

  function ReturnAddr: Pointer;
  asm
          MOV     EAX,[EBP+4]
  end;

begin
  raise EListError.CreateFmt(Msg, [Data])at ReturnAddr;
end;

constructor TStrBuffer.Create;
begin
  inherited Create;
  FCount := 0;
  FCapacity := 0;
  FBuff := nil;
end;

destructor TStrBuffer.Destroy;
begin
  Clear;
  inherited;
end;

procedure TStrBuffer.Clear;
begin
  FCount := 0;
  SetCapacity(0);
end;

procedure TStrBuffer.Add(const aValue: string);
var cnt, delta: integer;
begin
  cnt := Length(aValue);
  if FCount + cnt > FCapacity then begin
    delta := FCapacity div 2;
    if delta < cnt then
      delta := cnt * 2;
    SetCapacity(FCapacity + Delta);
  end;
  System.Move(Pointer(aValue)^, PChar(FBuff + FCount)^, cnt);
  Inc(FCount, cnt);
end;

function TStrBuffer.GetCount: integer;
begin
  result := FCount;
end;

function TStrBuffer.GetText: string;
begin
  SetLength(result, FCount);
  System.Move(FBuff^, Pointer(result)^, FCount);
end;

procedure TStrBuffer.SetCapacity(NewCapacity: Integer);
begin
  if (NewCapacity < FCount) or (NewCapacity > MaxBuffSize) then
    Error(SBufferCapacityError, NewCapacity);
  if NewCapacity <> FCapacity then begin
    ReallocMem(FBuff, NewCapacity);
    FCapacity := NewCapacity;
  end;
end;

procedure TStrBuffer.SaveToStream(Stream: TStream);
begin
  Stream.WriteBuffer(FBuff, FCount);
end;

procedure TStrBuffer.SaveToFile(const FileName: string);
var stream: TStream;
begin
  stream := TFileStream.Create(FileName, fmCreate);
  try
    SaveToStream(stream);
  finally
    stream.Free;
  end;
end;

procedure TStrBuffer.LoadFromFile(const FileName: string);
var stream: TStream;
begin
  stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    LoadFromStream(stream);
  finally
    stream.Free;
  end;
end;

procedure TStrBuffer.LoadFromStream(Stream: TStream);
var
  size: Integer;
  s: string;
begin
  Clear;
  size := Stream.Size - Stream.Position;
  SetString(s, nil, size);
  Stream.Read(Pointer(s)^, size);
  Add(s);
end;

{ TSegmentBuffer }

class procedure TSegmentBuffer.Error(const Msg: string; Data: Integer);

  function ReturnAddr: Pointer;
  asm
          MOV     EAX,[EBP+4]
  end;

begin
  raise EListError.CreateFmt(Msg, [Data])at ReturnAddr;
end;

constructor TSegmentBuffer.Create;
begin
  inherited Create;
  FCount := 0;
  FFirst := AllocMem(4096 + SizeOf(TSegment));
  with FFirst^ do begin
    Next := nil;
    Size := 4096;
    Count := 0;
  end;
  FLast := FFirst;
end;

destructor TSegmentBuffer.Destroy;
begin
  Clear;
  FreeMem(FFirst, FFirst^.Size);
  inherited Destroy;
end;

procedure TSegmentBuffer.Clear;
var p1, p2: PSegment;
begin
  p1 := FFirst;
  while p1 <> FLast do begin
    p2 := p1;
    p1 := p1^.next;
    FreeMem(p2, p2^.Size);
  end;
  FFirst := FLast;
  FFirst^.Count := 0;
  FCount := 0;
end;

procedure TSegmentBuffer.AddSegment(aSize: integer);
var
  segment: PSegment;
begin
  segment := AllocMem(aSize + SizeOf(TSegment) - SizeOf(char));
  with segment^ do begin
    next := nil;
    size := aSize;
    count := 0;
  end;
  FLast^.next := segment;
  FLast := segment;
  Inc(FCapacity, aSize);
end;

function TSegmentBuffer.GetCount: integer;
begin
  result := FCount;
end;

function TSegmentBuffer.GetText: string;
var
  p: PChar;
  segment: PSegment;
  len: integer;
begin
  SetString(result, nil, FCount);
  p := Pointer(result);
  segment := FFirst;
  while segment <> nil do begin
    len := segment^.Count;
    System.Move(segment^.Data, p^, len);
    inc(p, len);
    segment := segment^.Next;
  end;
end;

procedure TSegmentBuffer.Add(const aValue: PChar; aCnt: integer);
var
  p: PChar;
  tmp: integer;
begin
  p := aValue;
  // define size of unused memory in current buffer segment
  tmp := FLast^.Size - FLast^.Count;
  // if you do not have enough space in the buffer then copy the "unused" bytes
  // and reduce current segment
  if aCnt > tmp then begin
    System.Move(p^, FLast^.Data[FLast^.Count], tmp);
    Inc(FLast^.Count, tmp);
    Inc(FCount, tmp);
    Inc(p, tmp);
    Dec(aCnt, tmp);
    // add another segment of the larger buffer size
    tmp := FLast^.Size;
    if tmp < aCnt then tmp := aCnt;
    AddSegment(tmp * 2);
  end;
  if aCnt > 0 then begin
    Move(p^, FLast^.Data[FLast^.Count], aCnt);
    Inc(FCount, aCnt);
    Inc(FLast^.Count, aCnt);
  end;
end;

procedure TSegmentBuffer.Add(const aValue: string);
var
  p: PChar;
begin
  p := Pointer(aValue);
  Add(p, Length(aValue));
end;

procedure TSegmentBuffer.Add(const aValue: char);
begin
  Add(@aValue, 1);
end;

procedure TSegmentBuffer.SaveToFile(const FileName: string);
var stream: TStream;
begin
  stream := TFileStream.Create(FileName, fmCreate);
  try
    SaveToStream(stream);
  finally
    stream.Free;
  end;
end;

procedure TSegmentBuffer.SaveToStream(Stream: TStream);
var segment: PSegment;
begin
  segment := FFirst;
  while segment <> nil do begin
    Stream.WriteBuffer(segment^.Data[0], segment^.Count);
    segment := segment^.Next;
  end;
end;

procedure TSegmentBuffer.LoadFromFile(const FileName: string);
var stream: TStream;
begin
  stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    LoadFromStream(stream);
  finally
    stream.Free;
  end;
end;

procedure TSegmentBuffer.LoadFromStream(Stream: TStream);
var
  size: Integer;
  s: string;
begin
  Clear;
  size := Stream.Size - Stream.Position;
  SetString(s, nil, size);
  Stream.Read(Pointer(s)^, size);
  Add(s);
end;

{$RANGECHECKS ON}

end.

