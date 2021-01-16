unit Oz.Protoc.Test;

interface

uses
  TestFramework;

type

{$Region 'TPbTest'}

  TPbTest = class(TTestCase)
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure Test;
  end;

{$EndRegion}

implementation

{ TPbTest }

procedure TPbTest.SetUp;
begin
end;

procedure TPbTest.TearDown;
begin
end;

procedure TPbTest.Test;
begin
end;

initialization

  RegisterTest(TPbTest.Suite);

end.
