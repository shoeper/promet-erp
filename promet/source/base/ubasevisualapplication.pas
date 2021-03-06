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
{%RunFlags BUILD-}
unit uBaseVisualApplication;
{$mode objfpc}{$H+}
{.$SETPEFLAGS $20}
{$SETPEOPTFLAGS $140}
interface
uses
  Classes, SysUtils, Forms, XMLPropStorage, uBaseApplication, FileUtil, Utils,
  {uAppconsts, }uBaseDBInterface, PropertyStorage, ClipBrd, LCLType,
  uBaseVisualControls, uData, UTF8Process, Controls, Process, ProcessUtils,
  uSystemMessage, uProcessManager, uExtControls, db, typinfo, eventlog,menus,
  Dialogs,uIntfStrConsts,DBZVDateTimePicker
  {$IFDEF LCLCARBON}
  ,MacOSAll,CarbonProc
  {$ENDIF}
  ;
type

  { TBaseVisualApplication }

  TBaseVisualApplication = class(TApplication, IBaseApplication, IBaseDbInterface)
    procedure BaseVisualApplicationDebugLn(Sender: TObject; S: string;
      var Handled: Boolean);
    procedure BaseVisualApplicationException(Sender: TObject; E: Exception);
    procedure BaseVisualApplicationQueryEndSession(var Cancel: Boolean);
    procedure DataDataConnect(Sender: TObject);
    procedure DataDataConnectionLost(Sender: TObject);
    procedure DataDataDisconnectKeepAlive(Sender: TObject);
    procedure MessageHandlerExit(Sender: TObject);
    procedure ReaderReferenceName(Reader: TReader; var aName: string);
    procedure SenderTFrameReaderAncestorNotFound(Reader: TReader;
      const ComponentName: string; ComponentClass: TPersistentClass;
      var Component: TComponent);
    procedure SenderTFrameReaderError(Reader: TReader; const Message: string;
      var Handled: Boolean);
    procedure SenderTFrameReaderReadStringProperty(Sender: TObject;
      const Instance: TPersistent; PropInfo: PPropInfo; var Content: string);
  private
    FDBInterface: IBaseDBInterface;
    FOnUserTabAdded: TNotifyEvent;
    Properties: TXMLPropStorage;
    Processmanager: TProcessUTF8;
    FMessagehandler : TMessageHandler;
    FActualName : string;
    FProps : TStringList;
    FFields : TStringList;
    FLogger : TEventLog;
    FAppName : string;
    FAppVersion : real;
    FAppRevision : Integer;
    aParent: TWinControl;
    FQuickHelp : Boolean;
    procedure StartProcessManager;
    procedure UserTabAdded(Sender : TObject);
    function HandleSystemCommand(Sender : TObject;aCommand : string) : Boolean;
    {$IFDEF LCLCARBON}
    procedure GetOSXDateStyles;
    {$ENDIF}
  protected
    function GetSingleInstance : Boolean; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ShowException(E: Exception);override;
    procedure HandleException(Sender: TObject); override;
    procedure Initialize; override;

    procedure Terminate; override;

    function GetOurConfigDir : string;
    procedure SetConfigName(aName : string);
    procedure RestoreConfig;
    procedure SaveConfig;
    function GetConfig: TCustomPropertyStorage;
    function GetLanguage: string;
    procedure SetLanguage(const AValue: string);
    function SendMessage(Target,Message : string) : Integer;
    procedure AddTabClasses(aType : string;pcPages : TExtMenuPageControl);
    procedure AddTabs(pcPages : TExtMenuPageControl);
    procedure OnAddCustomTab(Sender: TObject);

    procedure Log(aType : string;aMsg : string);
    procedure Log(aMsg : string);
    procedure Info(aMsg : string);
    procedure Warning(aMsg : string);
    procedure Error(aMsg : string);
    procedure Debug(aMsg : string);
    function GetLog : TEventLog;
    function GetQuickHelp: Boolean;
    procedure SetQuickhelp(AValue: Boolean);

    function GetAppName: string;virtual;
    function GetApprevision: Integer;virtual;
    function GetAppVersion: real;virtual;
    procedure SetAppname(AValue: string);virtual;
    procedure SetAppRevision(AValue: Integer);virtual;
    procedure SetAppVersion(AValue: real);virtual;

    function Login : Boolean;
    function ChangePasswort: Boolean;
    procedure Logout;
    procedure DoExit;
    property Data : IBaseDbInterface read FDBInterface implements IBaseDBInterface;
    property MessageHandler : TMessageHandler read FMessageHandler;
    property OnUserTabAdded : TNotifyEvent read FOnUserTabAdded write FOnUserTabAdded;
  end;
var
  PrometheusClipboardFormat : TClipboardFormat;
  LinkClipboardFormat : TClipboardFormat;
implementation
uses uPassword,uMashineID,uError,ComCtrls,StdCtrls,ExtCtrls,
  DBCtrls, LMessages, LCLIntf,
  LazLogger,Buttons;
resourcestring
  strWrongPasswort            = 'Falsches Passwort !';
  strUsernotFound             = 'Benutzer nicht gefunden !';
  strConfigNotreadable        = 'Die Konfiguration konnte nicht gelesen werden, möglicherweise gingen Einstellungen verloren !';
  strGiveOldPasswort          = 'Geben Sie ihr aktuelles Passwort ein';
  strDisconnected             = 'Die Verbindung zur Datenbank ist nicht mehr verfügbar. Bitte stellen Sie die Verbindung wieder her. Das Programm wird automatisch erkennen das die Verbindung wieder verfügbar ist.';
  strNewTab                   = 'Neues Tab';

function TBaseVisualApplication.HandleSystemCommand(Sender: TObject;
  aCommand: string): Boolean;
var
  bCommand: String;
  cCommand: String;
begin
  Result := False;
  bCommand := copy(aCommand,0,pos('(',aCommand)-1);
  cCommand := copy(aCommand,length(bCommand)+1,length(aCommand));
  if bCommand = '' then bCommand := aCommand;
  if bCommand = 'Shutdown' then
    begin
      LCLIntf.PostMessage(Application.Mainform.Handle,LM_CLOSEQUERY,0,0);
      Result := True;
    end
  else if bCommand = 'ForcedShutdown' then
    begin
      Halt(0);
      Result := True;
    end
  else if bCommand = 'Ping' then
    begin
      Result := True;
    end
  ;
end;

function TBaseVisualApplication.GetSingleInstance: Boolean;
begin
  Result := False;
end;

procedure TBaseVisualApplication.BaseVisualApplicationDebugLn(Sender: TObject;
  S: string; var Handled: Boolean);
begin
  if Assigned(uData.Data) and HasOption('syslog') then
    FLogger.Debug(s);
end;

procedure TBaseVisualApplication.BaseVisualApplicationException(
  Sender: TObject; E: Exception);
var
  err: String;
begin
  fError := TfError.Create(Self);
  fError.SetLanguage;
//  if E is EDatabaseError then
//    fError.ShowWarning(e.Message)
//  else if E is EDivByZero then
//    fError.ShowWarning(e.Message)
//  else
    fError.ShowError(e.Message);
  fError.Free;
end;
procedure TBaseVisualApplication.BaseVisualApplicationQueryEndSession(
  var Cancel: Boolean);
var
  CloseAction : TCloseAction;
begin
  if Assigned(MainForm) and Assigned(Mainform.OnClose) then
    Mainform.OnClose(MainForm,CloseAction);
  with Self as IBaseDbInterface do
    DBLogout;
  FDBInterface.Data.Free;
end;

procedure TBaseVisualApplication.DataDataConnect(Sender: TObject);
begin
  if not Assigned(Application.MainForm) then exit;
  if Assigned(Application.MainForm.FindComponent('pDisconnected')) then
    Application.MainForm.FindComponent('pDisconnected').Free;
end;

procedure TBaseVisualApplication.DataDataConnectionLost(Sender: TObject);
var
  aPanel: TPanel;
begin
  if not Assigned(Application.MainForm) then exit;
  if Assigned(Application.MainForm.FindComponent('pDisconnected')) then exit;
  aPanel := TPanel.Create(Application.MainForm);
  aPanel.Name := 'pDisconnected';
  aPanel.caption := strDisconnected;
  aPanel.Parent := Application.MainForm;
  aPanel.Left := 0;
  aPanel.Top := 0;
  aPanel.Height := Application.MainForm.Height;
  aPanel.Width := Application.MainForm.Width;
  aPanel.Anchors:=[akTop, akLeft, akRight, akBottom];
end;

procedure TBaseVisualApplication.DataDataDisconnectKeepAlive(Sender: TObject);
begin
  Application.ProcessMessages;
end;

procedure TBaseVisualApplication.MessageHandlerExit(Sender: TObject);
begin
  FMessageHandler := nil;
end;
{$IFDEF LCLCARBON}
procedure TBaseVisualApplication.GetOSXDateStyles;
var
  currentLocale: CFLocaleRef;
  dateFormatter: CFDateFormatterRef;
  formattedString: CFStringRef;
begin exit;
  currentLocale := CFLocaleCopyCurrent();

  dateFormatter := CFDateFormatterCreate(nil, currentLocale, kCFDateFormatterLongStyle, kCFDateFormatterNoStyle);
  formattedString := CFDateFormatterGetFormat(dateFormatter);
  LongDateFormat := CFStringToStr(formattedString);
  if Assigned(dateFormatter) then
    CFRelease(Pointer(dateFormatter));
  FreeCFString(formattedString);

  dateFormatter := CFDateFormatterCreate(nil, currentLocale, kCFDateFormatterShortStyle, kCFDateFormatterNoStyle);
  formattedString := CFDateFormatterGetFormat(dateFormatter);
  ShortDateFormat := CFStringToStr(formattedString);
  if Assigned(dateFormatter) then
    CFRelease(Pointer(dateFormatter));
  FreeCFString(formattedString);

  dateFormatter := CFDateFormatterCreate(nil, currentLocale,kCFDateFormatterNoStyle, kCFDateFormatterShortStyle);
  formattedString := CFDateFormatterGetFormat(dateFormatter);
  ShortTimeFormat := CFStringToStr(formattedString);
  if Assigned(dateFormatter) then
    CFRelease(Pointer(dateFormatter));
  FreeCFString(formattedString);

  dateFormatter := CFDateFormatterCreate(nil, currentLocale,kCFDateFormatterNoStyle, kCFDateFormatterShortStyle);
  formattedString := CFDateFormatterGetFormat(dateFormatter);
  LongTimeFormat := CFStringToStr(formattedString);
  if Assigned(dateFormatter) then
    CFRelease(Pointer(dateFormatter));
  FreeCFString(formattedString);

  CFRelease(Pointer(currentLocale));
end;
{$ENDIF}
constructor TBaseVisualApplication.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BaseApplication := Self;
  FAppName := 'Promet-ERP';
  FQuickHelp:=True;
  FAppVersion := 7.0;
  FAppRevision := 0;
  FLogger := TEventLog.Create(Self);
  FLogger.Active:=false;
  if HasOption('l','logfile') then
    begin
      FLogger.FileName := GetOptionValue('l','logfile');
    end
  else
    begin
      FLogger.LogType:=ltSystem;
    end;
  LazLogger.GetDebugLogger.OnDebugLn:=@BaseVisualApplicationDebugLn;
  FLogger.Active:=True;
  {.$Warnings Off}
  FDBInterface := TBaseDBInterface.Create;
  FDBInterface.SetOwner(Self);
  {.$Warnings On}
  Properties := TXMLPropStorage.Create(AOwner);
  //if not DirectoryExistsUTF8(GetGlobalConfigDir(GetAppname)) then
  //  ForceDirectoriesUTF8(GetGlobalConfigDir(GetAppname));
  Properties.FileName := GetOurConfigDir+'config.xml';
  Properties.RootNodePath := 'Config';
  Self.OnQueryEndSession:=@BaseVisualApplicationQueryEndSession;
  Self.OnException:=@BaseVisualApplicationException;
  {$IFDEF WINDOWS}
  if Self.MainFormHandle<>0 then
    Self.MainFormOnTaskBar:=True;
  {$ENDIF}
  {$IFDEF LCLCARBON}
  GetOSXDateStyles;
  {$ENDIF}
end;
destructor TBaseVisualApplication.Destroy;
begin
  LazLogger.GetDebugLogger.OnDebugLn:=nil;
  Properties.Free;
  inherited Destroy;
end;
procedure TBaseVisualApplication.ShowException(E: Exception);
begin
end;

procedure TBaseVisualApplication.HandleException(Sender: TObject);
begin
  if not HasOption('debug') then
    Application.Flags:=[AppNoExceptionMessages];
  inherited HandleException(Sender);
end;

procedure TBaseVisualApplication.Initialize;
begin
  inherited Initialize;
  CreateForm(TfVisualControls,fVisualControls);
end;
procedure TBaseVisualApplication.Terminate;
begin
  LazLogger.GetDebugLogger.OnDebugLn:=nil;
  if Assigned(FDBInterface.Data) then
    begin
      with Self as IBaseDbInterface do
        DBLogout;
      try
        FDBInterface.Data.Free;
        FDBInterface.Data := nil;
      except
      end;
    end;
  inherited Terminate;
end;
function TBaseVisualApplication.GetOurConfigDir: string;
begin
  Result := GetConfigDir(StringReplace(lowercase(GetAppname),'-','',[rfReplaceAll]));
  if HasOption('c','config-path') then
    Result := GetOptionValue('c','config-path');
  if not DirectoryExistsUTF8(Result) then
    ForceDirectoriesUTF8(Result);
  result := AppendPathDelim(Result);
end;
procedure TBaseVisualApplication.SetConfigName(aName: string);
begin
  Properties.FileName := UTF8ToSys(GetOurConfigDir+aName+'.xml');
end;
procedure TBaseVisualApplication.RestoreConfig;
var
  NewRect : TRect;
  aWS: TWindowState;
begin
  with Self as IBaseApplication do
    begin
      try
      Properties.Restore;
      if Assigned(MainForm) then
        begin
          aWS := TWindowState(Config.ReadInteger('MainFormState',Integer(wsNormal)));
          Config.ReadRect('MainFormPos',NewRect,MainForm.BoundsRect);
          MainForm.BoundsRect := NewRect;
          Mainform.WindowState:=aWS;
        end;
      except
        DeleteFile(Properties.FileName);
      end;
    end;
end;
procedure TBaseVisualApplication.SaveConfig;
begin
  with Self as IBaseApplication do
    begin
      if Assigned(MainForm) then
        begin
          Config.WriteInteger('MainFormState',Integer(Mainform.WindowState));
          if Mainform.WindowState<> wsMaximized then
            Config.WriteRect('MainFormPos',MainForm.BoundsRect);
        end;
      Properties.Save;
    end;
end;
function TBaseVisualApplication.GetConfig: TCustomPropertyStorage;
begin
  Result := Properties;
end;
function TBaseVisualApplication.GetLanguage: string;
begin
  with Self as IBaseApplication do
    Result := Config.ReadString('LANGUAGE','');
end;
procedure TBaseVisualApplication.SetLanguage(const AValue: string);
begin
  with Self as IBaseApplication do
    Config.WriteString('LANGUAGE',AValue);
  //TODO:change Language
end;
function TBaseVisualApplication.SendMessage(Target, Message: string): Integer;
begin
end;
procedure TBaseVisualApplication.AddTabClasses(aType: string;
  pcPages: TExtMenuPageControl);
begin
  pcPages.TabTypes:=aType;
  with Data.Data.Forms.DataSet do
    begin
      Data.Data.SetFilter(Data.Data.Forms,Data.QuoteField('TYPE')+'='+Data.QuoteValue(aType));
      First;
      while not EOF do
        begin
          pcPages.AddTabClass(TFrame,FieldByName('NAME').AsString,@UserTabAdded);
          Next;
        end;
    end;
  if Data.Data.Users.Rights.Right('OPTIONS') > RIGHT_READ then
    begin
      pcPages.CanHaveCustomTabs(@OnAddCustomTab);
    end;
end;
procedure TBaseVisualApplication.AddTabs(pcPages: TExtMenuPageControl);
var
  aFrame: TFrame;
  aFound: Boolean;
  i: Integer;
  aTab: TTabSheet;
  OldIndex: Integer;
  function ShouldRemoveTab(aTabSheet : TTabSheet) : Boolean;
  var
    a: Integer;
    aDS: TDataSource;
    FN: String;
  begin
    Result := True;
    for a := 0 to aTabSheet.ComponentCount-1 do
      begin
        aDS := nil;
        FN := '';
        if (aTabSheet.Components[a] is TDBEdit) then
          begin
            aDS := TDBEdit(aTabSheet.Components[a]).DataSource;
            FN := TDBEdit(aTabSheet.Components[a]).DataField;
          end
        else if (aTabSheet.Components[a] is TDBMemo) then
          begin
            aDS := TDBMemo(aTabSheet.Components[a]).DataSource;
            FN := TDBMemo(aTabSheet.Components[a]).DataField;
          end
        else if (aTabSheet.Components[a] is TDBComboBox) then
          begin
            aDS := TDBComboBox(aTabSheet.Components[a]).DataSource;
            FN := TDBComboBox(aTabSheet.Components[a]).DataField;
          end
        else if (aTabSheet.Components[a] is TDBCheckBox) then
          begin
            aDS := TDBCheckBox(aTabSheet.Components[a]).DataSource;
            FN := TDBCheckBox(aTabSheet.Components[a]).DataField;
          end
        else if (aTabSheet.Components[a] is TDBZVDateTimePicker) then
          begin
            aDS := TDBZVDateTimePicker(aTabSheet.Components[a]).DataSource;
            FN := TDBZVDateTimePicker(aTabSheet.Components[a]).DataField;
          end
        ;
        if Assigned(aDS)
        and Assigned(aDS.DataSet)
        and (aDS.DataSet.FieldDefs.IndexOf(FN) <> -1)
        and (not aDS.DataSet.FieldByName(FN).IsNull) then
          begin
            Result := False;
            break;
          end;
      end;
  end;

begin
  Data.Data.SetFilter(Data.Data.Forms,Data.QuoteField('TYPE')+'='+Data.QuoteValue(TExtMenuPageControl(pcPages).TabTypes));
  with Data.Data.Forms.DataSet do
    begin
      First;
      while not EOF do
        begin
          aFound := False;
          for i := 1 to pcPages.PageCount-2 do
            if pcPages.Page[i].Caption = FieldByName('NAME').AsString then
              begin
                aFound := True;
                if ShouldRemoveTab(TTabSheet(pcPages.Page[i])) then
                  begin
                    pcPages.WillRemoveTab(TTabSheet(pcPages.Page[i]));
                    pcPages.TabIndex:=0;
                    pcPages.Page[i].Destroy;
                  end;
              end;
          if (not aFound) then
            begin
              pcPages.Visible:=False;
              OldIndex := pcPages.TabIndex;
              aTab := TTabSheet.Create(pcPages);
              aTab.Caption := FieldByName('NAME').AsString;
              aFrame := TFrame.Create(Self);
              aFrame.Parent := aTab;
              aTab.Visible:=False;
              aTab.PageControl := pcPages;
              try
                UserTabAdded(aFrame);
                if ShouldRemoveTab(aTab) then
                  begin
                    pcPages.WillRemoveTab(atab);
                    aTab.Destroy;
                    aFrame.Destroy;
                  end
                else
                  begin
                    aTab.PageIndex:=pcPages.PageCount-2;
                    aTab.Visible:=True;
                  end;
              except
                FreeAndNil(aFrame);
              end;
              pcPages.TabIndex:=OldIndex;
              pcPages.Visible:=True;
            end;
          Next;
        end;
    end;
end;
procedure TBaseVisualApplication.OnAddCustomTab(Sender: TObject);
var
  PC: TExtMenuPageControl;
  aName: String;
  aTab: TTabSheet;
  aFrame: TFrame;
  OldIndex: Integer;
begin
  if TMenuItem(Sender).Owner.Owner is TExtMenuPageControl then
    PC := TmenuItem(Sender).Owner.Owner as TExtMenuPageControl;
  if not Assigned(PC) then exit;
  Data.Data.SetFilter(Data.Data.Forms,Data.QuoteField('TYPE')+'='+Data.QuoteValue(PC.TabTypes));
  if InputQuery(strNewTab,strName,aName) then
    begin
      with Data.Data.Forms do
        begin
          Insert;
          FieldByName('TYPE').AsString:=PC.TabTypes;
          FieldByName('NAME').AsString:=aName;
          Post;
        end;
      PC.Visible:=False;
      OldIndex := PC.TabIndex;
      aTab := TTabSheet.Create(PC);
      with Data.Data.Forms do
        aTab.Caption := FieldByName('NAME').AsString;
      aFrame := TFrame.Create(Self);
      aFrame.Parent := aTab;
      aTab.Visible:=False;
      aTab.PageControl := PC;
      try
        UserTabAdded(aFrame);
        aTab.PageIndex:=PC.PageCount-2;
        aTab.Visible:=True;
      except
        FreeAndNil(aFrame);
      end;
      with Data.Data.Forms do
        PC.AddTabClass(TFrame,FieldByName('NAME').AsString,@UserTabAdded);
      PC.TabIndex:=OldIndex;
      PC.Visible:=True;
    end;
end;
procedure TBaseVisualApplication.Log(aType: string; aMsg: string);
begin
  //debugln(aType+':'+aMsg);
  try
  if Assigned(FLogger) then
    begin
      if aType = 'INFO' then
        FLogger.Info(aMsg)
      else if aType = 'WARNING' then
        FLogger.Warning(aMsg)
      else if aType = 'ERROR' then
        FLogger.Error(aMsg);
    end;
  except
  end;
end;
procedure TBaseVisualApplication.Log(aMsg: string);
begin
  try
    Log('INFO',aMsg);
  except
  end;
end;
procedure TBaseVisualApplication.Info(aMsg: string);
begin
  try
    Log(aMsg)
  except
  end;
end;
procedure TBaseVisualApplication.Warning(aMsg: string);
begin
  try
    Log('WARNING',aMsg);
  except
  end;
end;
procedure TBaseVisualApplication.Error(aMsg: string);
begin
  try
    Log('ERROR',aMsg);
  except
  end;
end;
procedure TBaseVisualApplication.Debug(aMsg: string);
begin
  if HasOption('debug') then
    debugln('DEBUG:'+aMsg);
end;
function TBaseVisualApplication.GetLog: TEventLog;
begin
  Result := FLogger;
end;

function TBaseVisualApplication.GetQuickHelp: Boolean;
begin
  Result := FQuickHelp;
end;

procedure TBaseVisualApplication.SetQuickhelp(AValue: Boolean);
begin
  FQuickHelp:=AValue;
end;

function TBaseVisualApplication.GetAppName: string;
begin
  Result := FAppName;
end;
function TBaseVisualApplication.GetApprevision: Integer;
begin
  Result := FAppRevision;
end;
function TBaseVisualApplication.GetAppVersion: real;
begin
  Result := FAppVersion;
end;
procedure TBaseVisualApplication.SetAppname(AValue: string);
begin
  FAppName:=AValue;
end;
procedure TBaseVisualApplication.SetAppRevision(AValue: Integer);
begin
  FAppRevision:=AValue;
end;
procedure TBaseVisualApplication.SetAppVersion(AValue: real);
begin
  FAppVersion:=AValue;
end;
procedure TBaseVisualApplication.StartProcessManager;
begin
  FMessagehandler := TMessageHandler.Create(Data.Data);
  FMessageHandler.RegisterCommandHandler(@HandleSystemCommand);
  with Application as IBaseDBInterface do
    begin
      if Data.Users.DataSet.Active then
        begin
          ProcessManager := uProcessManager.StartMessageManager(MandantName,Data.Users.DataSet.FieldByName('NAME').AsString);
          if not Assigned(Processmanager) then
            ProcessManager := uProcessManager.StartProcessManager(MandantName,Data.Users.DataSet.FieldByName('NAME').AsString)
        end;
    end;
end;
procedure TBaseVisualApplication.ReaderReferenceName(Reader: TReader;
  var aName: string);
begin
  if (copy(aName,0,5) = 'Data.')
  then
    FProps.Add(copy(aName,6,length(aName)));
  if ((aParent.FindComponent(aName) <> nil) and (aParent.FindComponent(aName) is TDataSource)) then
    FProps.Add(aName);
end;
procedure TBaseVisualApplication.SenderTFrameReaderAncestorNotFound(
  Reader: TReader; const ComponentName: string;
  ComponentClass: TPersistentClass; var Component: TComponent);
begin
  debugln(ComponentName+' not found');
end;
procedure TBaseVisualApplication.SenderTFrameReaderError(Reader: TReader;
  const Message: string; var Handled: Boolean);
begin
  debugln(Message);
  Handled:=True;
end;
procedure TBaseVisualApplication.SenderTFrameReaderReadStringProperty(
  Sender: TObject; const Instance: TPersistent; PropInfo: PPropInfo;
  var Content: string);
begin
  if Propinfo^.Name = 'DataField' then
    FFields.Add(Content);
end;
procedure TBaseVisualApplication.UserTabAdded(Sender: TObject);
var
  Stream: TMemoryStream;
  Reader: TReader;
  i: Integer;
  tmp : string;
  aComponent: TDBEdit;
  aDS: TDataSource;
  aOld: TWinControl;
  aTab: TWinControl;
begin
  with Sender as TFrame do
    begin
      //TFrame(Sender).Visible := False;
      if TFrame(Sender).Parent is TTabSheet then
        if TTabSheet(TFrame(Sender).Parent).PageControl is TExtMenuPageControl then
          Data.Data.SetFilter(Data.Data.Forms,Data.QuoteField('TYPE')+'='+Data.QuoteValue(TExtMenuPageControl(TTabSheet(TFrame(Sender).Parent).PageControl).TabTypes));
        if Data.Data.Forms.DataSet.Locate('NAME',TTabSheet(TFrame(Sender).Parent).Caption,[]) then
          begin
            aTab := TFrame(Sender).Parent;
            try
              Stream := TMemoryStream.Create;
              Data.Data.BlobFieldToStream(Data.Data.Forms.DataSet,'FORM',Stream);
              Stream.Position := 0;
              Reader := TReader.Create(Stream, 4096);
              Reader.OnError:=@SenderTFrameReaderError;
              Reader.Parent := TComponent(Sender);
              Reader.OnReferenceName:=@ReaderReferenceName;
              Reader.OnAncestorNotFound:=@SenderTFrameReaderAncestorNotFound;
              Reader.OnReadStringProperty:=@SenderTFrameReaderReadStringProperty;
              aParent := TWinControl(Sender);
              FProps := TStringList.Create;
              FFields := TStringList.Create;
              while (not (aParent is TExtControlFrame)) and Assigned(aParent) do
                aParent := aParent.Parent;
              try
                if Stream.Size>0 then
                  begin
                    Reader.ReadRootComponent(TFrame(Sender).Parent);
                    for i := 0 to Reader.Root.ComponentCount-1 do
                      begin
                        if (Reader.Root.Components[i] is TDBEdit) and (FProps.Count > 0) and (FFields.Count > 0) then
                          begin
                            aDS := TDataSource(aParent.FindComponent(FProps[0]));
                            if Assigned(aDS) and Assigned(aDS.DataSet) and (aDS.DataSet.Active) and (aDS.DataSet.FieldDefs.IndexOf(FFields[0]) <> -1) then
                              begin
                                TDBEdit(Reader.Root.Components[i]).DataField := FFields[0];
                                TDBEdit(Reader.Root.Components[i]).DataSource := TDataSource(aParent.FindComponent(FProps[0]));
                              end;
                            FProps.Delete(0);
                            FFields.Delete(0);
                          end
                        else if (Reader.Root.Components[i] is TDBMemo) and (FProps.Count > 0) and (FFields.Count > 0) then
                          begin
                            aDS := TDataSource(aParent.FindComponent(FProps[0]));
                            if Assigned(aDS) and Assigned(aDS.DataSet) and (aDS.DataSet.Active) and (aDS.DataSet.FieldDefs.IndexOf(FFields[0]) <> -1) then
                              begin
                                TDBMemo(Reader.Root.Components[i]).DataSource := TDataSource(aParent.FindComponent(FProps[0]));
                                TDBMemo(Reader.Root.Components[i]).DataField := FFields[0];
                              end;
                            FProps.Delete(0);
                            FFields.Delete(0);
                          end
                        else if (Reader.Root.Components[i] is TDBCombobox) and (FProps.Count > 0) and (FFields.Count > 0) then
                          begin
                            aDS := TDataSource(aParent.FindComponent(FProps[0]));
                            if Assigned(aDS) and Assigned(aDS.DataSet) and (aDS.DataSet.Active) and (aDS.DataSet.FieldDefs.IndexOf(FFields[0]) <> -1) then
                              begin
                                TDBCombobox(Reader.Root.Components[i]).DataSource := TDataSource(aParent.FindComponent(FProps[0]));
                                TDBComboBox(Reader.Root.Components[i]).DataField := FFields[0];
                              end;
                            FProps.Delete(0);
                            FFields.Delete(0);
                          end
                        else if (Reader.Root.Components[i] is TDBCheckBox) and (FProps.Count > 0) and (FFields.Count > 0) then
                          begin
                            aDS := TDataSource(aParent.FindComponent(FProps[0]));
                            if Assigned(aDS) and Assigned(aDS.DataSet) and (aDS.DataSet.Active) and (aDS.DataSet.FieldDefs.IndexOf(FFields[0]) <> -1) then
                              begin
                                TDBCheckBox(Reader.Root.Components[i]).DataSource := TDataSource(aParent.FindComponent(FProps[0]));
                                TDBCheckBox(Reader.Root.Components[i]).DataField := FFields[0];
                              end;
                            FProps.Delete(0);
                            FFields.Delete(0);
                          end
                        else if (Reader.Root.Components[i] is TDBZVDateTimePicker) and (FProps.Count > 0) and (FFields.Count > 0) then
                          begin
                            aDS := TDataSource(aParent.FindComponent(FProps[0]));
                            if Assigned(aDS) and Assigned(aDS.DataSet) and (aDS.DataSet.Active) and (aDS.DataSet.FieldDefs.IndexOf(FFields[0]) <> -1) then
                              begin
                                TDBZVDateTimePicker(Reader.Root.Components[i]).DataSource := TDataSource(aParent.FindComponent(FProps[0]));
                                TDBZVDateTimePicker(Reader.Root.Components[i]).DataField := FFields[0];
                              end;
                            FProps.Delete(0);
                            FFields.Delete(0);
                          end
                        ;
                      end;
                  end;
              finally
                Reader.Free;
              end;
              FProps.Destroy;
              FFields.Destroy;
              Stream.Free;
            except
            end;
            if Assigned(FOnUserTabAdded) then
              FOnUserTabAdded(aTab);
          end;
    end;
end;
function TBaseVisualApplication.Login: Boolean;
var
  aID: LongInt;
  rMandant: String;
  rUser: String;
  rAutoLogin: String;
begin
  Result := True;
  if not Assigned(fPassword) then
    Application.CreateForm(TfPassword,fPassword);
  fPassword.cbMandant.Text:='';
  fPassword.cbMandant.Enabled := True;
  fPassword.cbUser.Enabled := False;
  fPassword.ePasswort.Enabled := False;
  fPassword.ePasswort.Text := '';
  try
    try
      with Self as IBaseApplication do
        begin
          aID := CreateUserID;
          rMandant := Config.ReadString('LOGINMANDANT','');
          rUser := Config.ReadString('LOGINUSER','');
          rAutoLogin := Config.ReadString('AUTOMATICLOGIN','T');
          if ((Config.ReadInteger('AUTOMATICLOGIN',0)=aID) and (aID <> 0))
          or ((rMandant='Standart') and (rUser='Administrator') and (rAutoLogin='')) then
            with Self as IBaseDBInterface do
              if DBLogin(Config.ReadString('LOGINMANDANT',''),Config.ReadString('LOGINUSER',''),True) then
                begin
                  Data.DeleteExpiredSessions;
                  uData.Data := Data;
                  StartProcessManager;
                  udata.Data.OnConnectionLost:=@DataDataConnectionLost;
                  udata.Data.OnDisconnectKeepAlive:=@DataDataDisconnectKeepAlive;
                  udata.Data.OnConnect:=@DataDataConnect;
                  Result := True;
                  exit;
                end
              else
                Config.WriteInteger('AUTOMATICLOGIN',0);
          with Self as IBaseDBInterface do
            if fPassword.Execute then
              begin
                if not Assigned(Data) then
                  begin
                    Config.WriteInteger('AUTOMATICLOGIN',0);
                    Exception.Create('');
                    Result := False;
                    exit;
                  end;
                if Data.Users.Passwort.IsNull or (Data.Users.Passwort.AsString = '') then
                  begin
                    Data.Users.SetPasswort(fPassword.ePasswort.Text);
                  end;
                if not Data.Users.DataSet.Locate('NAME',fPassword.cbUser.Text,[]) then
                  begin
                    Config.WriteInteger('AUTOMATICLOGIN',0);
                    Exception.Create(strUsernotFound);
                    Result := False;
                    exit;
                  end;
                if not (Data.Users.CheckPasswort(fPassword.ePasswort.text)) then
                  begin
                    Config.WriteInteger('AUTOMATICLOGIN',0);
                    raise Exception.Create(strWrongPasswort);
                    Result := False;
                    exit;
                  end;
                with Self as IBaseDBInterface do
                  if not DBLogin(Config.ReadString('LOGINMANDANT',''),Config.ReadString('LOGINUSER',''),True,True) then
                    begin
                      Config.WriteInteger('AUTOMATICLOGIN',0);
                      raise Exception.Create('');
                      Result := False;
                      exit;
                    end;
                Data.DeleteExpiredSessions;
                uData.Data := Data;
                StartProcessManager;
                fPassword.ePasswort.Text := '';
              end
            else
              begin
                Result := False;
                fPassword.ePasswort.Text := '';
                exit;
              end;
        end;
    except
      on e : Exception do
        begin
          if e.Message = strUsernotFound then
            fError.ShowWarning(e.Message)
          else if e.Message = strWrongPasswort then
            fError.ShowWarning(e.Message)
          else if e.Message <> '' then
            fError.ShowError(e.Message);
          Result := False;
        end;
    end;
  finally
  end;
  if Result then
    begin
      udata.Data.OnConnectionLost:=@DataDataConnectionLost;
      udata.Data.OnDisconnectKeepAlive:=@DataDataDisconnectKeepAlive;
      udata.Data.OnConnect:=@DataDataConnect;
    end;
  if not Result then uData.Data := nil;
end;
function TBaseVisualApplication.ChangePasswort: Boolean;
begin
  Result := False;
  if fPassword.Execute(strGiveOldPasswort,false)
  and Data.Data.Users.CheckPasswort(fPassword.ePasswort.Text) then
    begin
      with Data.Data.Users do
        begin
          if not CanEdit then
            DataSet.Edit;
          DataSet.FieldByName('PASSWORD').AsString:='';
          DataSet.Post;
          fPassword.cbUserSelect(nil);
        end;
      if fPassword.Execute(strFirstLogin,false) then
        begin
          Data.Data.Users.SetPasswort(fPassword.ePasswort.Text);
          fPassword.ePasswort.Text := '';
          Result := True;
        end;
    end;
end;
procedure TBaseVisualApplication.Logout;
begin
  LazLogger.GetDebugLogger.OnDebugLn:=nil;
  uData.Data := nil;
  DoExit;
  with Self as IBaseApplication do
    begin
      Config.WriteString('AUTOMATICLOGIN','NO');
      Terminate;
    end;
end;
procedure TBaseVisualApplication.DoExit;
begin
  if Assigned(Messagehandler) then
    begin
      MessageHandler.OnExit:=@MessageHandlerExit;
      Messagehandler.Terminate;
      while Assigned(MessageHandler) do sleep(10);
      sleep(50);
      FMessageHandler := nil;
    end;
  if Self.HasOption('t','terminateprocesses') then
    if Processmanager.Active then Processmanager.Terminate(1);
  if Assigned(Processmanager) then
    FreeAndNil(ProcessManager);
  with Self as IBaseDbInterface do
    DBLogout;
end;
initialization
  PrometheusClipboardFormat := RegisterClipboardFormat('PrometERP XML');
  LinkClipboardFormat := RegisterClipboardFormat('PrometERP Link');
  RegisterClass(TSpeedButton);
  RegisterClass(TLabel);
  RegisterClass(TDBEdit);
  RegisterClass(TDBMemo);
  RegisterClass(TDBComboBox);
  RegisterClass(TPanel);
end.

