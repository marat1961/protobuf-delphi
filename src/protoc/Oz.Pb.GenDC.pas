(* Protocol buffer code generator, for Delphi
 * Copyright (c) 2020 Marat Shaimardanov
 *
 * This file is part of Protocol buffer code generator, for Delphi
 * is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this file. If not, see <https://www.gnu.org/licenses/>.
 *)

unit Oz.Pb.GenDC;

interface

uses
  System.SysUtils, Oz.Cocor.Utils, Oz.Pb.Tab, Oz.Pb.CustomGen;

{$Region 'TGenDC: code generator for delphi'}
type

  TGenDC = class(TCustomGen)
  protected
    function MapCollection: string; override;
    function RepeatedCollection: string; override;
    function CreateName: string; override;
    procedure GenUses; override;
    procedure GenEntityType(msg: PObj); override;
    procedure GenEntityDecl; override;
    procedure GenEntityImpl(msg: PObj); override;
    procedure GenLoadDecl(msg: PObj); override;
    procedure GenSaveDecl(msg: PObj); override;
    procedure GenLoadMethod(msg: PObj); override;
    procedure GenLoadResult(const s: string); override;
    procedure GenFieldRead(msg: PObj); override;
    procedure GenSaveImpl(msg: PObj); override;
  end;

{$EndRegion}

implementation

uses
  Oz.Pb.Parser;

{$Region 'TGenDC'}

function TGenDC.MapCollection: string;
begin
  Result := 'TDictionary<%s, %s>';
end;

function TGenDC.RepeatedCollection: string;
begin
  Result := 'TList<%s>';
end;

procedure TGenDC.GenUses;
begin
  Wrln('uses');
  Wrln('  System.Classes, System.SysUtils, Generics.Collections, Oz.Pb.Classes;');
  Wrln;
end;

function TGenDC.CreateName: string;
begin
  Result := 'Create';
end;

procedure TGenDC.GenEntityDecl;
begin
  Wrln('constructor Create;');
  Wrln('destructor Destroy; override;');
end;

procedure TGenDC.GenEntityImpl(msg: PObj);
var
  typ: PType;
  t: string;
  x: PObj;
begin
  typ := msg.typ;
  // parameterless constructor
  t := msg.AsType;
  Wrln('constructor %s.Create;', [t]);
  Wrln('begin');
  Indent;
  try
    Wrln('inherited Create;');
    x := typ.dsc;
    while x <> tab.Guard do
    begin
      FieldInit(x);
      x := x.next;
    end;
  finally
    Dedent;
  end;
  Wrln('end;');
  Wrln;

  Wrln('destructor %s.Destroy;', [t]);
  Wrln('begin');
  Indent;
  try
    x := typ.dsc;
    while x <> tab.Guard do
    begin
      FieldFree(x);
      x := x.next;
    end;
    Wrln('inherited Destroy;');
  finally
    Dedent;
  end;
end;

procedure TGenDC.GenEntityType(msg: PObj);
begin
  Wrln('%s = class', [msg.AsType]);
end;

procedure TGenDC.GenLoadDecl(msg: PObj);
var
  t: string;
begin
  t := msg.AsType;
  Wrln('function Load%s(%s: %s): %s;', [msg.DelphiName, msg.name, t, t]);
end;

procedure TGenDC.GenSaveDecl(msg: PObj);
begin
  Wrln('procedure Save%s(%s: %s);', [msg.DelphiName, msg.name, msg.AsType]);
end;

procedure TGenDC.GenLoadMethod(msg: PObj);
var
  s, t: string;
begin
  s := msg.DelphiName;
  t := msg.AsType;
  Wrln('function %s.Load%s(%s: %s): %s;',
    [GetBuilderName(True), s, msg.name, t, t]);
end;

procedure TGenDC.GenLoadResult(const s: string);
begin
  Wrln('Result := %s;', [s]);
end;

procedure TGenDC.GenFieldRead(msg: PObj);
var
  o: TFieldOptions;
  n: string;
begin
  o := msg.aux as TFieldOptions;
  n := 'F' + Plural(msg.name);
  Wrln('    %s.%s.Add(%s);', [o.Msg.name, n, GetRead(msg)]);
end;

procedure TGenDC.GenSaveImpl(msg: PObj);
var
  s, t: string;
begin
  s := msg.DelphiName;
  t := msg.AsType;
  Wrln('procedure %s.Save%s(%s: %s);', [GetBuilderName(False), s, msg.name, t]);
end;

{$EndRegion}

end.
