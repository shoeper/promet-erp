program smtpsender;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, SysUtils, CustApp, uBaseCustomApplication, pcmdprometapp,
  pmimemessages, synautil, smtpsend, mimemess, mimepart, uMessages,
  uData, uBaseDBInterface, uPerson, ssl_openssl, laz_synapse,
  uDocuments,uMimeMessages,uBaseApplication,LConvEncoding;
resourcestring
  strActionMessageSend             = '%s - gesendet';
type
  TSMTPSender = class(TBaseCustomApplication)
  protected
    procedure DoRun; override;
    function GetSingleInstance : Boolean; override;
  public
    function CommandReceived(Sender : TObject;aCommand : string) : Boolean;
    procedure SendMessages(aUser : string);
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
  end;
procedure TSMTPSender.DoRun;
var
  i: Integer;
  StartTime: TDateTime;
begin
  with BaseApplication as IBaseApplication do
    begin
      AppVersion:={$I ../base/version.inc};
      AppRevision:={$I ../base/revision.inc};
    end;
  if not Login then
    begin
      Terminate;
      exit;
    end;
  RegisterMessageHandler;
  MessageHandler.RegisterCommandHandler(@Commandreceived);
  StartTime := Now();
  while not Terminated do
    begin
      if Now()-StartTime > ((1/HoursPerDay)*2) then break;
      with Data.Users.DataSet do
        begin
          First;
          while not EOF do
            begin
              SendMessages(FieldByName('NAME').AsString);
              Next;
            end;
        end;
      if HasOption('o','onerun') then break;
      for i := 0 to 1000 do
        begin
          sleep(60*6);
          if Terminated then break;
        end;
    end;
  Terminate;
end;

function TSMTPSender.GetSingleInstance: Boolean;
begin
  Result := True;
end;

function TSMTPSender.CommandReceived(Sender: TObject; aCommand: string
  ): Boolean;
var
  aUser: String;
begin
  Result := False;
  if copy(aCommand,0,5) = 'Send(' then
    begin
      aUser := copy(aCommand,6,length(aCommand));
      aUser := copy(aUser,0,length(aUser)-1);
      SendMessages(aUser);
      Result := True;
    end;
end;
procedure TSMTPSender.SendMessages(aUser: string);
var
  SMTP: TSMTPSend;
  Mime : TMimeMess;
  aMimePart: TMimePart;
  MP: TMimePart;
  MessageIndex: TMessageList;
  aMessage: TMimeMessage;
  mailaccounts: String = '';
  ss: TStringStream;
  i: Integer;
  sl: TStringList;
  Customers: TPerson;
  CustomerCont: TPersonContactData;
  atmp: String;
  ReceiversOK: Boolean;
  res: String;
  aDocument: TDocument;
  ArchiveMsg: TArchivedMessage;
  aDomain: String;
begin
  MessageIndex := TMessageList.Create(Self,Data);
  MessageIndex.CreateTable;
  aMessage := TMimeMessage.Create(Self,Data);
  mailaccounts := '';
  with Self as IBaseDbInterface do
    mailaccounts := DBConfig.ReadString('MAILACCOUNTS','');
  while pos('|',mailaccounts) > 0 do
    begin  //Servertype;Server;Username;Password;Active
      if copy(mailaccounts,0,pos(';',mailaccounts)-1) = 'SMTP' then
        begin
          SMTP := TSMTPSend.Create;
          SMTP.AutoTLS:=True;
          mailaccounts := copy(mailaccounts,pos(';',mailaccounts)+1,length(mailaccounts));
          smtp.TargetHost:= copy(mailaccounts,0,pos(';',mailaccounts)-1);
          mailaccounts := copy(mailaccounts,pos(';',mailaccounts)+1,length(mailaccounts));
          SMTP.UserName := copy(mailaccounts,0,pos(';',mailaccounts)-1);
          mailaccounts := copy(mailaccounts,pos(';',mailaccounts)+1,length(mailaccounts));
          SMTP.Password := copy(mailaccounts,0,pos(';',mailaccounts)-1);
          mailaccounts := copy(mailaccounts,pos(';',mailaccounts)+1,length(mailaccounts));
          Data.SetFilter(MessageIndex,Data.QuoteField('TREEENTRY')+'='+Data.QuoteValue(IntToStr(TREE_ID_SEND_MESSAGES))+' AND ('+Data.ProcessTerm(Data.QuoteField('SENDER')+'='+Data.QuoteValue('*'+smtp.UserName+'*'))+') and '+Data.QuoteField('READ')+'='+Data.QuoteValue('N'));
          if (MessageIndex.Count > 0) and (copy(mailaccounts,0,pos(';',mailaccounts)-1)= 'YES') then
            begin
              WriteLn('Login to Server:'+SMTP.TargetHost+' user:'+smtp.UserName);
              if SMTP.Login then
                begin
                  WriteLn('Login OK');
                  while not MessageIndex.DataSet.EOF do
                    begin
                      aMessage.SelectFromLink(Data.BuildLink(MessageIndex.DataSet));
                      aMessage.Open;
                      if aMessage.Count>0 then
                      with aMessage.DataSet do
                        begin
                          WriteLn('Mail from:'+GetemailAddr(FieldByName('SENDER').AsString));
                          if SMTP.MailFrom(GetemailAddr(FieldByName('SENDER').AsString),0) then
                            begin
                              Mime := TMimeMess.Create;
                              Mime := aMessage.EncodeMessage;
                              aDomain := GetEmailAddr(FieldByName('SENDER').AsString);
                              aDomain := copy(aDomain,pos('@',aDomain),length(aDomain));
                              if aDomain <> '' then
                                Mime.Header.MessageID := StringReplace(Mime.Header.MessageID,'@inv.local',aDomain,[rfReplaceAll]);
                              ReceiversOK := True;
                              for i := 0 to Mime.Header.ToList.Count-1 do
                                begin
                                  WriteLn('Mail To:'+getemailaddr(Mime.Header.ToList[i]));
                                  if  (getemailaddr(Mime.Header.ToList[i]) <> '')
                                  and (pos('@',getemailaddr(Mime.Header.ToList[i])) > 0) then
                                    begin
                                      if not SMTP.MailTo(lowercase(getemailaddr(Mime.Header.ToList[i]))) then
                                        begin
                                          ReceiversOk := False;
                                          res := SMTP.FullResult.Text;
                                          WriteLn('failed:'+res);
                                        end;
                                    end;
                                end;
                              if ReceiversOK and (Mime.Header.ToList.Count > 0) then
                                begin
                                  Mime.EncodeMessage;
                                  Edit;
                                  FieldbyName('READ').AsString:='Y';
                                  Post;
                                  if SMTP.MailData(Mime.Lines) then
                                    begin
                                      ArchiveMsg := TArchivedMessage.Create(nil,Data);
                                      ArchiveMsg.CreateTable;
                                      ArchiveMsg.Insert;
                                      ArchiveMsg.DataSet.FieldByName('ID').AsString:=Mime.Header.MessageID;
                                      ss := TStringStream.Create(Mime.Lines.Text);
                                      Data.StreamToBlobField(ss,ArchiveMsg.DataSet,'DATA');
                                      ss.Free;
                                      ArchiveMsg.DataSet.Post;
                                      ArchiveMsg.Free;
                                      for i := 0 to Mime.Header.ToList.Count-1 do
                                        begin
                                          CustomerCont := TPersonContactData.Create(Self,Data);
                                          if Data.IsSQLDb then
                                            Data.SetFilter(CustomerCont,'UPPER("DATA")=UPPER('''+getemailaddr(Mime.Header.ToList[i])+''')')
                                          else
                                            Data.SetFilter(CustomerCont,'"DATA"='''+getemailaddr(Mime.Header.ToList[i])+'''');
                                          Customers := TPerson.Create(Self,Data);
                                          Data.SetFilter(Customers,'"ACCOUNTNO"='+Data.QuoteValue(CustomerCont.DataSet.FieldByName('ACCOUNTNO').AsString));
                                          CustomerCont.Free;
                                          if Customers.Count > 0 then
                                            begin
                                              Customers.History.Open;
                                              atmp := ConvertEncoding(Mime.Header.Subject,GuessEncoding(Mime.Header.Subject),EncodingUTF8);
                                              Customers.History.AddItem(Customers.DataSet,Format(strActionMessageSend,[atmp]),
                                                                        Data.BuildLink(MessageIndex.DataSet),
                                                                        '',
                                                                        nil,
                                                                        ACICON_MAILANSWERED);
                                            end;
                                          Data.Users.History.AddItem(Customers.DataSet,Format(strActionMessageSend,[atmp]),
                                                                    Data.BuildLink(MessageIndex.DataSet),
                                                                    '',
                                                                    nil,
                                                                    ACICON_MAILANSWERED);
                                          Customers.Free;
                                        end;
                                      MessageHandler.SendCommand('prometerp','Message.refresh');
                                    end
                                  else
                                    begin
                                      Edit;
                                      FieldbyName('READ').AsString:='N';
                                      Post;
                                    end;
                                end;
                              Mime.Destroy;
                            end
                          else
                            begin
                              res := SMTP.FullResult.Text;
                              WriteLn('failed:'+res);
                            end;
                        end;
                      SMTP.Reset;
                      MessageIndex.DataSet.Next;
                    end;
                  SMTP.Logout;
                end;
              SMTP.Free;
            end;
        end;
      mailaccounts := copy(mailaccounts,pos('|',mailaccounts)+1,length(mailaccounts));
    end;
  aMessage.Free;
  MessageIndex.Free;
end;
constructor TSMTPSender.Create(TheOwner: TComponent);
begin
  SetAppVersion({$I ../base/version.inc});
  SetAppRevision({$I ../base/revision.inc});
  inherited Create(TheOwner);
end;
destructor TSMTPSender.Destroy;
begin
  inherited Destroy;
end;
var
  Application: TSMTPSender;
{$R *.res}
begin
  Application:=TSMTPSender.Create(nil);
  Application.Run;
  Application.Free;
end.
