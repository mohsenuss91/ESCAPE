{
  ESCAPE, Environment for the Simulation of Computer Architectures
  for the Purpose of Education
  Copyright (C) 1998-2001 Peter Verplaetse, ELIS Department, Ghent University
  Copyright (C) 2010-2015 Jonas Maebe, ELIS Department, Ghent University
  Copyright (C) 1996-1998 Jan Van Campenhout, ELIS Department, Ghent University

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
}


{ Project: Escape                                                            }
{ Version: 1.1                                                               }
{ Author: Peter Verplaetse                                                   }
{ Date: 22 July 1998                                                         }

unit Activity;

{$MODE Delphi}

interface

uses
  SysUtils, {WinTypes, WinProcs,} Messages, Classes, Graphics, Controls,
  Forms, Dialogs, StdCtrls, Menus, Grids, LResources;

type
  { This is the Pipeline Activity form }

  { TActivityForm }

  TActivityForm = class(TForm)
    Grid: TStringGrid;
    MainMenu1: TMainMenu;
    PopupMenu1: TPopupMenu;
    View1: TMenuItem;
    HideForm1: TMenuItem;
    HideForm2: TMenuItem;
    procedure GridDrawCell(Sender: TObject; Col, Row: Longint;
      Rect: TRect; State: TGridDrawState);
    procedure FormCreate(Sender: TObject);
    procedure GridResize(Sender: TObject);
    procedure HideForm1Click(Sender: TObject);
  private
    { 6 colors are used -- each istruction is assigned a color }
    LookupColor: array [0..32768 div 4-1] of Integer; {bits 2-0: color, bit 4: 1 when stalled}
    Colors: array [0..4,0..1023] of TColor;
    Stalled: array [0..4,0..1023] of Boolean;
    NextIndex: Integer;
    LastColor: Integer;
  public
    { Clears the diagram }
    procedure Clear;
    { Add one or more lines to the diagram if necessary }
    procedure AddLines(MaxAmount: Integer);
    { Remove one or more lines from the diagram if necessary }
    procedure RemoveLines(Amount: Integer);
    { Show the last line if not on display }
    procedure ShowLine;
  end;

var
  ActivityForm: TActivityForm;

implementation

uses
  Pipe, InstrMem, Common;

{$R *.lfm}

procedure TActivityForm.Clear;
var
  i,j: Integer;
begin
  for i:=1 to Grid.RowCount-1 do
    for j:=0 to Grid.ColCount-1 do
      Grid.Cells[j,i]:='';
  for i:=0 to High(LookupColor) do
    LookupColor[i]:=-1;
  LastColor:=-1;
  NextIndex:=PSimulator.ActivityStartIndex
end;

procedure TActivityForm.ShowLine;
var
  i, DesiredTopRowPos: Integer;
begin
  i:=(NextIndex-PSimulator.ActivityStartIndex) and 1023;
  DesiredTopRowPos:=i+1-Grid.VisibleRowCount;
  if Grid.TopRow+Grid.VisibleRowCount-1<i then
    Grid.TopRow:=DesiredTopRowPos
  else if Grid.TopRow<>DesiredTopRowPos then
    if DesiredTopRowPos>0 then
      Grid.TopRow:=DesiredTopRowPos
    else
      Grid.TopRow:=1;
end;

procedure TActivityForm.AddLines(MaxAmount: Integer);
var
  Time,i,j,l,AmountAdded: Integer;
  p, Adr: LongInt;
  s: string;
  c: TColor;
begin
  AmountAdded:=0;
  with PSimulator do
    while NextIndex<>ActivityNextIndex do
    begin
      if (AmountAdded>=MaxAmount) then
        break;
      inc(AmountAdded);
      i:=((NextIndex-ActivityStartIndex) and 1023);
      Time:=ActivityStartTime+i;
      Grid.Cells[0,i+1]:=IntToStr(Time);
      for j:=4 downto 0 do
      begin
        p:=ActivityData[j,NextIndex];
        if p>=0 then
        begin
          Adr:=p and $7FFF;
          Stalled[j,i]:=(p and $40000000<>0);
          l:=LookupColor[Adr shr 2];
          if (l<0) or ((j=0) and (l<$10)) then { new pc or not recently stalled }
          begin
            LastColor:=(LastColor+1) mod 6;
            LookupColor[Adr shr 2]:=LastColor;
            l:=LastColor
          end;
          if Stalled[j,i] then
            LookupColor[Adr shr 2]:=LookupColor[Adr shr 2] or $10
          else
            LookupColor[Adr shr 2]:=LookupColor[Adr shr 2] and $F;
          case l and $f of
            0: c:=clYellow;
            1: c:=clLime;
            2: c:=clAqua;
            3: c:=clRed;
            4: c:=clSilver
          else
           {5} c:=clFuchsia
          end;
          Colors[j,i]:=c;
          s:=Disassemble(CodeMemory.Read(Adr,2),Adr,0,false)
        end else
          s:='';
        Grid.Cells[j+1,i+1]:=s
      end;
      NextIndex:=(NextIndex+1) and 1023
    end;
  ShowLine
end;

procedure TActivityForm.RemoveLines(Amount: Integer);
var
  ctr, i, j: Integer;
begin
  with PSimulator do
    for ctr:=1 to Amount do
    begin
      NextIndex:=(NextIndex-1) and 1023;
      i:=((NextIndex-ActivityStartIndex) and 1023);
      Grid.Cells[0,i+1]:='';
      for j:=4 downto 0 do
      begin
        Colors[j,i]:=clWhite;
        Grid.Cells[j+1,i+1]:=''
      end;
      if NextIndex=ActivityStartIndex then
        break;
    end;
  ShowLine
end;

procedure TActivityForm.GridDrawCell(Sender: TObject; Col,
  Row: Longint; Rect: TRect; State: TGridDrawState);
var
  s: string;
  X,Y: Integer;
  Alignment: TAlignment;
begin
  s:=Grid.Cells[Col,Row];
  with Grid.Canvas do
  begin
    Font.Name:='Microsoft Sans Serif';
    Font.Style:=[];
    Font.Size:=8;
    Brush.Color:=clWhite;
    Brush.Style:=bsSolid;
    if Row=0 then
    begin
      Brush.Color:=clBtnFace;
      Font.Style:=[fsBold];
      Font.Size:=10;
      Alignment:=taCenter
    end else if Col>0 then
    begin
      if Length(s)>0 then
      begin
        Brush.Color:=self.Colors[Col-1,Row-1];
        FillRect(Rect);
        if Stalled[Col-1,Row-1] then
        begin
          Brush.Color:=clGray;
          Brush.Style:=bsDiagCross;
        end;
        Pen.Color:=clBlack;
        Rectangle(Rect.Left,Rect.Top,Rect.Right,Rect.Bottom);
        Brush.Style:=bsClear
      end;
      AlignMent:=taLeftJustify
    end else
    begin
      Alignment:=taRightJustify;
      Font.Size:=10
    end;
    { Write text in cell or erase when empty}
    if Length(s)>0 then
    begin
      case Alignment of
        taLeftJustify: X:=Rect.Left+3;
        taCenter: X:=Rect.Left+(Grid.ColWidths[Col]-TextWidth(s)) div 2
      else
        {taRightJustify} X:=Rect.Right-TextWidth(s)-3
      end;
      if (Row>0) and (Col>0) then
        Y:=Rect.Top+3
      else
        Y:=Rect.Top+2;
      TextRect(Rect,X,Y,s)
    end else
    begin
      Brush.Color:=clWhite;
      FillRect(Rect)
    end;
    { Create 3D look for top row }
    if Row=0 then
    begin
      Pen.Color:=clWhite;
      PolyLine([Point(Rect.Right-1,Rect.Top),Point(Rect.Left,Rect.Top),
                Point(Rect.Left,Rect.Bottom)])
    end
  end
end;

procedure TActivityForm.FormCreate(Sender: TObject);
begin
  Grid.Cells[0,0]:='Time';
  Grid.Cells[1,0]:='IF';
  Grid.Cells[2,0]:='ID';
  Grid.Cells[3,0]:='EX';
  Grid.Cells[4,0]:='MEM';
  Grid.Cells[5,0]:='WB'
end;

procedure TActivityForm.GridResize(Sender: TObject);
var
  i,W: Integer;
begin
  W:=Courier10Width*5+5;
  Grid.ColWidths[0]:=W;
  for i:=1 to 4 do
    Grid.ColWidths[i]:=((Grid.ClientWidth-W)*i) div 5 +W-Grid.CellRect(i,0).Left;
  Grid.ColWidths[5]:=Grid.ClientWidth-Grid.CellRect(5,0).Left-1
end;

procedure TActivityForm.HideForm1Click(Sender: TObject);
begin
  Hide
end;

end.
