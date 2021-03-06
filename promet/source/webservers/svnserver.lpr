program svnserver;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, SysUtils, pcmdprometapp, CustApp, uBaseCustomApplication, lnetbase,
  lNet, uBaseDBInterface, md5,uData,
  pmimemessages,fileutil,lconvencoding,uBaseApplication,
  ulsvnserver, ulwebdavserver, uDocuments, Utils,lMimeTypes,lHTTPUtil,lCommon,
  DateUtils,uimpvcal,uCalendar,uWiki,synautil;
type
  TSVNServer = class(TBaseCustomApplication)
    procedure ServerAccess(AMessage: string);
    function ServerDelete(aDir: string): Boolean;
    function ServerGetDirectoryList(aDir: string; var aDirList: TLDirectoryList
      ) : Boolean;
    function ServerGetFile(aDir: string; Stream: TStream;var LastModified : TDateTime;var MimeType : string): Boolean;
    function ServerMkCol(aDir: string): Boolean;
    function ServerPutFile(aDir: string; Stream: TStream): Boolean;
    function ServerReadAllowed(aDir: string): Boolean;
    function ServerUserLogin(aUser, aPassword: string): Boolean;
  private
    Server : TLSVNServer;
    procedure AddDocumentsToFileList(aFileList : TLDirectoryList;aDocuments : TDocuments);
    procedure AddDocumentToFileList(aFileList : TLDirectoryList;aDocuments : TDocuments);
  protected
    procedure DoRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
  end;
const
  WebFormatSettings : TFormatSettings = (
    CurrencyFormat: 1;
    NegCurrFormat: 5;
    ThousandSeparator: ',';
    DecimalSeparator: '.';
    CurrencyDecimals: 2;
    DateSeparator: '-';
    TimeSeparator: ':';
    ListSeparator: ',';
    CurrencyString: '$';
    ShortDateFormat: 'd/m/y';
    LongDateFormat: 'dd" "mmmm" "yyyy';
    TimeAMString: 'AM';
    TimePMString: 'PM';
    ShortTimeFormat: 'hh:nn';
    LongTimeFormat: 'hh:nn:ss';
    ShortMonthNames: ('Jan','Feb','Mar','Apr','May','Jun',
                      'Jul','Aug','Sep','Oct','Nov','Dec');
    LongMonthNames: ('January','February','March','April','May','June',
                     'July','August','September','October','November','December');
    ShortDayNames: ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');
    LongDayNames:  ('Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday');
    TwoDigitYearCenturyWindow: 50;
  );
function BuildISODate(aDate : TDateTime) : string;
var
  bias: Integer;
  h, m: Integer;
begin
  bias := TimeZoneBias;
  if bias >= 0 then
    Result := '+'
  else
    Result := '-';
  bias := Abs(bias);
  h := bias div 60;
  m := bias mod 60;
  Result := FormatDateTime('yyyy-mm-dd',aDate)+'T'+FormatDateTime('hh:nn:ss',aDate,WebFormatSettings)+ Result + SysUtils.Format('%.2d:%.2d', [h, m]);
end;
procedure TSVNServer.ServerAccess(AMessage: string);
begin
  writeln(AMessage);
end;
function TSVNServer.ServerDelete(aDir: string): Boolean;
var
  aDocuments: TDocuments;
  aDocument: TDocument;
begin
  aDocuments := TDocuments.Create(nil,Data);
  aDocuments.Select(1,'D',0);
  aDocuments.Open;
  if copy(aDir,length(aDir),1) = '/' then
    aDir := copy(aDir,0,length(aDir)-1);
  if rpos('/',aDir) > 1 then
    Result := aDocuments.OpenPath(copy(aDir,0,rpos('/',aDir)),'/')
  else Result := True;
  if Result then
    begin
      Result := False;
      aDir := copy(aDir,rpos('/',aDir)+1,length(aDir));
      if aDocuments.SelectFile(aDir) then
        begin
          aDocument := TDocument.Create(nil,Data);
          aDocument.SelectByNumber(aDocuments.DataSet.FieldByName('NUMBER').AsVariant);
          aDocument.Open;
          if aDocument.Count > 0 then
            begin
              aDocument.Delete;
              Result := True;
            end;
          aDocument.Free;
        end;
    end;
  aDocuments.Free;
end;
function TSVNServer.ServerGetDirectoryList(aDir: string;
  var aDirList: TLDirectoryList) : Boolean;
var
  aItem: TLFile;
  aDocuments: TDocuments;
  aFile: String;
begin
  Result := false;
  if aDir = '/' then
    begin
      Result := True;
      aDirList := TLDirectoryList.Create;
      aItem := TLFile.Create('calendar',True);
      aDocuments := TDocuments.Create(nil,Data);
      aDocuments.Select(1,'D',0);
      aDocuments.Open;
      AddDocumentsToFileList(aDirList,aDocuments);
      aDocuments.Free;
      aDirList.Add(aItem);
    end
  else if copy(aDir,0,9) = '/calendar' then
    begin
      if Data.Users.DataSet.Active then
        begin
          aDirList := TLDirectoryList.Create;
          aItem := TLFile.Create('standard.ics',False);
          aItem.Properties.Values['getcontenttype'] := 'text/calendar';
          aItem.Properties.Values['creationdate'] := BuildISODate(Now());
          aItem.Properties.Values['getlastmodified'] := FormatDateTime('ddd, dd mmm yyyy hh:nn:ss',LocalTimeToGMT(Now()),WebFormatSettings)+' GMT';
          aDirList.Add(aItem);
        end;
      Result := True;
    end
  else
    begin
      aDirList := TLDirectoryList.Create;
      aDocuments := TDocuments.Create(nil,Data);
      aDocuments.Select(1,'D',0);
      if copy(aDir,length(aDir),1) <> '/' then
        aDir := aDir+'/';
      if aDocuments.OpenPath(aDir,'/') then
        begin
          AddDocumentsToFileList(aDirList,aDocuments);
          Result := True;
        end
      else
        begin
          aDir := copy(aDir,0,length(aDir)-1);
          aFile := HTTPDecode(copy(aDir,rpos('/',aDir)+1,length(aDir)));
          aDir := copy(aDir,0,rpos('/',aDir));
          if (aDir = '') or (aDir = '/') or aDocuments.OpenPath(aDir,'/') then
            begin
              aDocuments.DataSet.First;
              while not aDocuments.DataSet.EOF do
                begin
                  if aDocuments.FileName = aFile then
                    AddDocumentToFileList(aDirList,aDocuments);
                  aDocuments.DataSet.Next;
                end;
              Result := True;
            end;
        end;
      aDocuments.Free;
    end;
end;
function TSVNServer.ServerGetFile(aDir: string; Stream: TStream;var LastModified : TDateTime;var MimeType : string): Boolean;
var
  aDocuments: TDocuments;
  aDocument: TDocument;
  aFileName: String;
  lIndex: Integer;
  sl: TStringList;
  aCal: TCalendar;
begin
  if aDir = 'calendar/standart.ics' then
    begin
      sl := TStringList.Create;
      aCal := TCalendar.Create(nil,Data);
      aCal.Open;
      VCalExport(aCal,sl);
      sl.SaveToStream(Stream);
      aCal.Free;
      sl.Free;
      Result := True;
    end
  else
    begin
      Mimetype := '';
      aDocuments := TDocuments.Create(nil,Data);
      aDocuments.Select(1,'D',0);
      aDocuments.Open;
      if rpos('/',aDir) > 1 then
        Result := aDocuments.OpenPath(copy(aDir,0,rpos('/',aDir)),'/')
      else Result := True;
      if Result then
        begin
          Result := False;
          aDir := copy(aDir,rpos('/',aDir)+1,length(aDir));
          if aDocuments.SelectFile(aDir) then
            begin
              aDocument := TDocument.Create(nil,Data);
              aDocument.SelectByNumber(aDocuments.DataSet.FieldByName('NUMBER').AsVariant);
              aDocument.Open;
              if aDocument.Count > 0 then
                begin
                  aDocument.CheckoutToStream(Stream);
                  LastModified:=aDocument.LastModified;
                  if Assigned(MimeList) then
                    begin
                      lIndex := MimeList.IndexOf(ExtractFileExt(aDocuments.FileName));
                      if lIndex >= 0 then
                        MimeType := TStringObject(MimeList.Objects[lIndex]).Str;
                    end;
                  if MimeType = '' then
                    MimeType := GetMimeTypeforExtension(ExtractFileExt(aDocuments.FileName));
                  Result := True;
                end;
              aDocument.Free;
            end;
        end;
    end;
end;
function TSVNServer.ServerMkCol(aDir: string): Boolean;
var
  aDocuments: TDocuments;
  aDocument: TDocument;
  Subfolder: Boolean = False;
begin
  aDocuments := TDocuments.Create(nil,Data);
  aDocuments.Select(1,'D',0);
  aDocuments.Open;
  if copy(aDir,length(aDir),1)='/' then
    aDir := copy(aDir,0,length(aDir)-1);
  if (rpos('/',aDir) > 1) then
    begin
      Result := aDocuments.OpenPath(copy(aDir,0,rpos('/',aDir)-1),'/');
      Subfolder := True;
    end
  else Result := True;
  if Result then
    begin
      Result := False;
      aDir := copy(aDir,rpos('/',aDir)+1,length(aDir));
      aDocument := TDocument.Create(nil,Data);
      if SubFolder then
        aDocument.BaseParent := aDocuments
      else
        begin
          aDocument.Ref_ID := aDocuments.Ref_ID;
          aDocument.BaseTyp:=aDocuments.BaseTyp;
          aDocument.BaseID:=aDocuments.BaseID;
          aDocument.BaseVersion:=aDocuments.BaseVersion;
          aDocument.BaseLanguage:=aDocuments.BaseLanguage;
        end;
      aDocument.Insert;
      aDocument.CreateDirectory(aDir);
      aDocument.Free;
      Result := True;
    end;
  aDocuments.Free;
end;
function TSVNServer.ServerPutFile(aDir: string; Stream: TStream): Boolean;
var
  aDocuments: TDocuments;
  aDocument: TDocument;
  aFileName: String;
  aFStream: TFileStream;
  aFiles: TStrings;
  aDocuments2: TDocuments;
begin
  aDocuments := TDocuments.Create(nil,Data);
  aDocuments.Select(1,'D',0);
  aDocuments.Open;
  if rpos('/',aDir) > 1 then
    Result := aDocuments.OpenPath(copy(aDir,0,rpos('/',aDir)-1),'/')
  else Result := True;
  aDocuments2 := TDocuments.Create(nil,Data);
  aDocuments2.Select(1,'D',0);
  aDocuments2.Open;
  if rpos('/',aDir) > 1 then
    Result := aDocuments2.OpenPath(copy(aDir,0,rpos('/',aDir)),'/')
  else Result := True;
  if Result then
    begin
      Result := False;
      aDocument := TDocument.Create(nil,Data);
      aFileName := ExtractFileName(aDir);
      if ADocuments2.SelectFile(aFileName) then //Checkin existing File
        begin
          aDocument.SelectByNumber(aDocuments2.DataSet.FieldByName('NUMBER').AsString);
          aDocument.Open;
          ForceDirectories(GetTempDir+'promettemp');
          aFStream := TFileStream.Create(AppendPathDelim(GetTempDir+'promettemp')+aDocuments2.FileName,fmCreate);
          Stream.Position:=0;
          aFStream.CopyFrom(Stream,Stream.Size);
          aFStream.Free;
          aFiles := aDocument.CollectCheckInFiles(GetTempDir+'promettemp');
          aDocument.CheckinFiles(aFiles,GetTempDir+'promettemp');
          Result := True;
        end
      else
        begin //Create new file
          aDocument.BaseParent := aDocuments;
          if rpos('.',aFileName) > 0 then
            aDocument.AddFromStream(copy(aFileName,0,rpos('.',aFileName)-1),copy(ExtractFileExt(aFileName),2,length(aFileName)),Stream)
          else
            aDocument.AddFromStream(aFileName,'',Stream);
          Result := True;
        end;
        aDocument.Free;
    end;
  aDocuments.Free;
  aDocuments2.Free;
end;
function TSVNServer.ServerReadAllowed(aDir: string): Boolean;
begin
  //Result := not ((copy(aDir,0,9) = '/calendar') and not Data.Users.DataSet.Active);
  Result := True;
end;
function TSVNServer.ServerUserLogin(aUser, aPassword: string): Boolean;
begin
  Data.Users.Open;
  Result := Data.Users.DataSet.Locate('NAME',aUser,[]) and (Data.Users.Leaved.IsNull);
  if Result then
    Result := Data.Users.Passwort.AsString = md5print(MD5String(aPassword));
  if not Result then Data.Users.DataSet.Close;
end;
procedure TSVNServer.AddDocumentsToFileList(aFileList: TLDirectoryList;
  aDocuments: TDocuments);
var
  aFile: TLFile;
  lIndex: Integer;
begin
  aDocuments.DataSet.First;
  while not aDocuments.DataSet.EOF do
    begin
      AddDocumentToFileList(aFileList,aDocuments);
      aDocuments.DataSet.Next;
    end;
end;

procedure TSVNServer.AddDocumentToFileList(aFileList: TLDirectoryList;
  aDocuments: TDocuments);
var
  aFile: TLFile;
  lIndex: Integer;
begin
  aFile := TLFile.Create(aDocuments.FileName,aDocuments.IsDir);
  if not aDocuments.IsDir then
    begin
      if Assigned(MimeList) then
        begin
          lIndex := MimeList.IndexOf(ExtractFileExt(aDocuments.FileName));
          if lIndex >= 0 then
            aFile.Properties.Values['getcontenttype'] := TStringObject(MimeList.Objects[lIndex]).Str;
        end;
      if aFile.Properties.Values['getcontenttype'] = '' then
        aFile.Properties.Values['getcontenttype'] := GetMimeTypeforExtension(ExtractFileExt(aDocuments.FileName));
      if aFile.Properties.Values['getcontenttype'] = '' then
        aFile.Properties.Values['getcontenttype'] := 'text/plain';
      aFile.Properties.Values['creationdate'] := BuildISODate(aDocuments.CreationDate);
      aFile.Properties.Values['getlastmodified'] := FormatDateTime('ddd, dd mmm yyyy hh:nn:ss',LocalTimeToGMT(aDocuments.LastModified),WebFormatSettings)+' GMT';
      aFile.Properties.Values['getcontentlength'] := IntToStr(aDocuments.Size);
    end;
  aFile.Properties.Values['creationdate'] := BuildISODate(aDocuments.CreationDate);
  aFileList.Add(aFile);
end;

procedure TSVNServer.DoRun;
var
  y,m,d,h,mm,s,ss: word;
begin
  with Self as IBaseDBInterface do
    DBLogout;
{
  with Self as IBaseApplication do
    if not Log.Active then
      begin
        DecodeDate(Now(),y,m,d);
        DecodeTime(Now(),h,mm,s,ss);
        Log.FileName := Format('svn_server_log_%.4d-%.2d-%.2d %.2d_%.2d_%.2d_%.4d.log',[y,m,d,h,mm,s,ss]);
        Log.Active:=True;
      end;
}
  while not Terminated do
    Server.CallAction;
  // stop program loop
  Terminate;
end;
constructor TSVNServer.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  StopOnException:=True;
  Server := TLSVNServer.Create(Self);
  Server.OnAccess:=@ServerAccess;
  Server.OnGetDirectoryList:=@ServerGetDirectoryList;
  Server.OnMkCol:=@ServerMkCol;
  Server.OnDelete:=@ServerDelete;
  Server.OnPutFile:=@ServerPutFile;
  Server.OnGetFile:=@ServerGetFile;
  Server.OnReadAllowed:=@ServerReadAllowed;
  Server.OnUserLogin:=@ServerUserLogin;
  Login;
  if not Server.Listen(8085) then raise Exception.Create('Cant bind to port !');
  Data.Users.DataSet.Close;
end;
destructor TSVNServer.Destroy;
begin
  Server.Free;
  inherited Destroy;
end;
var
  Application: TSVNServer;
{$R *.res}
begin
  Application:=TSVNServer.Create(nil);
  Application.Run;
  Application.Free;
end.
