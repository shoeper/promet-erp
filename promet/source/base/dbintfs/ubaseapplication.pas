{*******************************************************************************
Dieser Sourcecode darf nicht ohne gültige Geheimhaltungsvereinbarung benutzt werden
und ohne gültigen Vertriebspartnervertrag weitergegeben oder kommerziell verwertet werden.
You have no permission to use this Source without valid NDA
and copy it without valid distribution partner agreement
Christian Ulrich
info@cu-tec.de
Created 01.06.2006
*******************************************************************************}
unit uBaseApplication;
{$mode objfpc}{$H+}
interface
uses
  Classes, SysUtils, CustApp, PropertyStorage, eventLog;
type
  TBaseApplicationClass = class of TCustomApplication;

  { IBaseApplication }

  IBaseApplication = interface['{F8CB41DF-69F1-40C2-ADAA-C8BDCCB28CDD}']
    function GetAppName: string;
    function GetApprevision: Integer;
    function GetAppVersion: real;
    function GetOurConfigDir : string;
    function GetConfig: TCustomPropertyStorage;
    function GetLog: TEventLog;
    function GetSingleInstance : Boolean;
    function GetLanguage: string;
    procedure SetAppname(AValue: string);
    procedure SetAppRevision(AValue: Integer);
    procedure SetAppVersion(AValue: real);
    procedure SetLanguage(const AValue: string);
    procedure SetConfigName(aName : string);
    procedure RestoreConfig;
    procedure SaveConfig;
    function Login : Boolean;
    function ChangePasswort : Boolean;
    procedure Logout;
    procedure Log(aType : string;aMsg : string);
    procedure Log(aMsg : string);
    procedure Info(aMsg : string);
    function GetQuickHelp: Boolean;
    procedure SetQuickhelp(AValue: Boolean);
    procedure Warning(aMsg : string);
    procedure Error(aMsg : string);
    procedure Debug(aMsg : string);
    procedure DoExit;
    property Language : string read GetLanguage write SetLanguage;
    property Config : TCustomPropertyStorage read GetConfig;
    property SingleInstance : Boolean read GetSingleInstance;
    property Appname : string read GetAppName write SetAppname;
    property AppVersion : real read GetAppVersion write SetAppVersion;
    property AppRevision : Integer read GetApprevision write SetAppRevision;
    property EventLog : TEventLog read GetLog;
    property QuickHelp : Boolean read GetQuickHelp write SetQuickhelp;
  end;
var
  TBaseApplicationType : TBaseApplicationClass;
  BaseApplication : TCustomApplication;
implementation
initialization
  BaseApplication := nil;
end.
