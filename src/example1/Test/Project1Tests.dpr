program Project1Tests;
{

  Delphi DUnit Test Project
  -------------------------
  This project contains the DUnit test framework and the GUI/Console test runners.
  Add "CONSOLE_TESTRUNNER" to the conditional defines entry in the project options
  to use the console test runner.  Otherwise the GUI test runner will be used by
  default.

}

{$IFDEF CONSOLE_TESTRUNNER}
{$APPTYPE CONSOLE}
{$ENDIF}

uses
  DUnitTestRunner,
  TestExample1 in 'TestExample1.pas',
  Example1 in '..\Example1.pas',
  StrBuffer in '..\..\StrBuffer.pas',
  pbInput in '..\..\pbInput.pas',
  pbOutput in '..\..\pbOutput.pas',
  pbPublic in '..\..\pbPublic.pas';

{$R *.RES}

begin
  DUnitTestRunner.RunRegisteredTests;
end.

