{*******************************************************************************
  Copyright (C) Christian Ulrich info@cu-tec.de

  This source is free software; you can redistribute it and/or modify it under
  the terms of the GNU General Public License as published by the Free
  Software Foundation; either version 2 of the License, or commercial alternative
  contact us for more information

  This code is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
  details.

  A copy of the GNU General Public License is available on the World Wide Web
  at <http://www.gnu.org/copyleft/gpl.html>. You can also obtain it by writing
  to the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
  MA 02111-1307, USA.
Created 01.06.2006
*******************************************************************************}
unit uRepairPositionFrame;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, ExtCtrls, StdCtrls, DbCtrls,
  DBGrids, uExtControls, db, uMasterdata, uPrometFramesInplace;

type
  TfRepairPositionFrame = class(TPrometInplaceFrame)
    cbOperation: TDBComboBox;
    cbVersion1: TDBComboBox;
    cbWarrenty: TDBCheckBox;
    dnRepairPos: TDBNavigator;
    eSerial1: TDBEdit;
    gProblems: TExtDBGrid;
    lInfo: TLabel;
    lErrordescription: TLabel;
    lFoundProblems: TLabel;
    lInternalNotes: TLabel;
    lNotesforCustomer: TLabel;
    lOperation: TLabel;
    lSerial1: TLabel;
    lVersion1: TLabel;
    mErrordesc: TDBMemo;
    mInternalNotes: TDBMemo;
    mNotes: TDBMemo;
    Panel1: TPanel;
    Position: TDatasource;
    Repair: TDatasource;
    RepairDetail: TDatasource;
    procedure eSerial1Exit(Sender: TObject);
    procedure FrameEnter(Sender: TObject);
    procedure gProblemsColExit(Sender: TObject);
    procedure gProblemsColumnMoved(Sender: TObject; FromIndex, ToIndex: Integer
      );
    procedure gProblemsColumnSized(Sender: TObject);
    procedure gProblemsSelectEditor(Sender: TObject; Column: TColumn;
      var Editor: TWinControl);
  private
    { private declarations }
    FMasterdata : TMasterdata;
  public
    { public declarations }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy;override;
    procedure SetLanguage;
    procedure SetRights(Editable : Boolean);override;
  end;

implementation
{$R *.lfm}
uses uOrder,uPositionFrame,uData,Variants,uRowEditor,uBaseERPDBClasses;
resourcestring
  strRepaired                   = 'repariert';
  strDiscarded                  = 'entsorgt';
  strWaitingforCustomer         = 'wartet auf Kunden';
  strAssemblyexchanged          = 'Baugruppentausch';
  strIsNew                      = 'neuwertig';
procedure TfRepairPositionFrame.FrameEnter(Sender: TObject);
begin
  if TfPosition(Owner).Dataset is TOrderPos then
    with TfPosition(Owner).DataSet as TOrderPos do
      begin
        lInfo.Visible:=False;
        eSerial1Exit(eSerial1);
        if Self.Repair.DataSet = Repair.DataSet then exit;
        Position.DataSet := DataSet;
        Repair.Open;
        Self.Repair.DataSet := Repair.DataSet;
        Repair.Details.Open;
        RepairDetail.DataSet := Repair.Details.DataSet;
        fRowEditor.GetGridSizes('REPAIR',gProblems.DataSource,gProblems);
      end;
end;

procedure TfRepairPositionFrame.eSerial1Exit(Sender: TObject);
var
  aStorageJournal: TStorageJournal;
begin
  lInfo.Visible:=False;
  if trim(eSerial1.Text)<>'' then
    begin
      aStorageJournal := TStorageJournal.Create(nil,Data);
      aStorageJournal.Filter(Data.QuoteField('ID')+'='+Data.QuoteValue(Position.DataSet.FieldByName('IDENT').AsString)+' AND '+Data.QuoteField('SERIAL')+'='+Data.QuoteValue(trim(eSerial1.Text))+' AND NOT '+Data.ProcessTerm(Data.QuoteField('NOTE')+'='+Data.QuoteValue('')));
      if aStorageJournal.Count>0 then
        begin
          lInfo.Caption:=aStorageJournal.FieldByName('NOTE').AsString;
          lInfo.Visible:=True;
        end;
      aStorageJournal.Free;
    end;
end;

procedure TfRepairPositionFrame.gProblemsColExit(Sender: TObject);
var
  i: Integer;
  PartColumn: TColumn = nil;
begin
  if not Assigned(gProblems.SelectedField) then exit;
  if gProblems.SelectedField.FieldName <> 'ASSEMBLY' then exit;
  for i := 0 to gProblems.Columns.Count-1 do
    if gProblems.Columns[i].FieldName = 'PART' then
      begin
        PartColumn := gProblems.Columns[i];
        break;
      end;
  if not Assigned(PartColumn) then exit;
  PartColumn.PickList.Clear;
  if not Assigned(FMasterdata) then exit;
  if not FMasterdata.Assembly.DataSet.Active then exit;
  if FMasterdata.Assembly.DataSet.Locate('ASSEMBLY',RepairDetail.DataSet.FieldByName('ASSEMBLY').AsString,[]) then
    begin
      FMasterdata.Assembly.Parts.Open;
      FMasterdata.Assembly.Parts.DataSet.First;
      while not FMasterdata.Assembly.Parts.DataSet.EOF do
        begin
          PartColumn.PickList.Add(FMasterdata.Assembly.Parts.FieldByName('PART').AsString);
          FMasterdata.Assembly.Parts.DataSet.Next;
        end;
    end;
end;
procedure TfRepairPositionFrame.gProblemsColumnMoved(Sender: TObject;
  FromIndex, ToIndex: Integer);
begin
  fRowEditor.SetGridSizes('REPAIR',gProblems.DataSource,gProblems);
end;
procedure TfRepairPositionFrame.gProblemsColumnSized(Sender: TObject);
begin
  fRowEditor.SetGridSizes('REPAIR',gProblems.DataSource,gProblems);
end;
procedure TfRepairPositionFrame.gProblemsSelectEditor(Sender: TObject;
  Column: TColumn; var Editor: TWinControl);
var
  aFilter: String;
  aMasterdata: TMasterdata;
begin
  if not Self.Visible then exit;
  if not Position.DataSet.Active then exit;
  if Column.FieldName = 'ERROR' then exit;
  if Column.FieldName = 'ASSEMBLY' then
    begin
      Column.PickList.Clear;
      if not Assigned(FMasterdata) then
        aMasterdata := TMasterdata.Create(Self,Data)
      else aMasterdata := FMasterdata;
      FMasterdata := aMasterdata;
      aMasterdata.Select(Position.DataSet.FieldByName('IDENT').AsString);
      aMasterdata.Open;
      if aMasterdata.DataSet.Locate('ID;VERSION',VararrayOf([Position.DataSet.FieldByName('IDENT').AsVariant,Position.DataSet.FieldByName('VERSION').AsVariant]),[]) then
        aMasterdata.Assembly.Open
      else if aMasterdata.DataSet.Locate('ID',VararrayOf([Position.DataSet.FieldByName('IDENT').AsVariant]),[]) then
        aMasterdata.Assembly.Open
      else
        exit;
      with aMasterdata.Assembly.DataSet do
        begin
          First;
          while not eof do
            begin
              Column.PickList.Add(FieldbyName('ASSEMBLY').AsString);
              Next;
            end;
        end;
    end;
end;
constructor TfRepairPositionFrame.Create(AOwner: TComponent);
var
  i: Integer;
begin
  inherited Create(AOwner);
  FMasterdata := nil;
  for i := 0 to gproblems.Columns.Count-1 do
    if TColumn(gProblems.Columns[i]).FieldName = 'ERROR' then
      begin
        Data.RepairProblems.CreateTable;
        Data.RepairProblems.Open;
        with Data.RepairProblems.DataSet do
          begin
            First;
            TColumn(gProblems.Columns[i]).PickList.Clear;
            while not EOF do
              begin
                TColumn(gProblems.Columns[i]).PickList.Add(FieldByName('PROBLEM').AsString);
                next;
              end;
          end;
      end;
  SetLanguage;
end;
destructor TfRepairPositionFrame.Destroy;
begin
  if Assigned(Fmasterdata) then
    FMasterdata.Destroy;
  inherited Destroy;
end;
procedure TfRepairPositionFrame.SetLanguage;
begin
  cbOperation.Clear;
  cbOperation.Items.Add(strRepaired);
  cbOperation.Items.Add(strDiscarded);
  cbOperation.Items.Add(strWaitingforCustomer);
  cbOperation.Items.Add(strAssemblyexchanged);
  cbOperation.Items.Add(strIsNew);
end;
procedure TfRepairPositionFrame.SetRights(Editable: Boolean);
begin
  Enabled := Editable;
end;
end.

