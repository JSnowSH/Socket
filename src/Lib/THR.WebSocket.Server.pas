{*******************************************************************************
  Unit......: THR.WebSocket.Server
  Objetivo..: Servidor WebSocket com API fluente, construído sobre o
              TIdTCPServer da Indy. Concentra configuração, eventos, controle
              de sessões e roteamento de mensagens.
  Padrão....: ThR - Normas e Padronização de Codificação (Delphi) v4.0.1
*******************************************************************************}
unit THR.WebSocket.Server;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.SyncObjs,
  System.Generics.Collections,
  IdContext, IdTCPServer, IdGlobal, IdSocketHandle, IdIOHandler, IdException,
  THR.WebSocket.Types, THR.WebSocket.Interfaces, THR.WebSocket.Frame,
  THR.WebSocket.Handshake, THR.WebSocket.Session, THR.WebSocket.OfflineStore,
  THR.WebSocket.Message;

type
  {*****************************************************************************
    TWebSocketServer
    Implementa IWebSocketServer e IWebSocketDispatcher.

    Obtenção da instância: TWebSocketServer.New
  *****************************************************************************}
  TWebSocketServer = class(TInterfacedObject, IWebSocketServer, IWebSocketDispatcher)
  strict private
    FServer: TIdTCPServer;
    FSessions: TList<IWebSocketSession>;
    FSessionsLock: TCriticalSection;
    FOfflineStore: IWebSocketOfflineStore;

    FPort: Word;
    FPath: String;
    FUserNameParameter: String;
    FReadTimeout: Integer;
    FKeepOfflineMessages: Boolean;
    FEchoPingAsPong: Boolean;
    FSendWelcomeMessage: Boolean;

    FOnStart: TWebSocketServerEvent;
    FOnStop: TWebSocketServerEvent;
    FOnConnect: TWebSocketSessionEvent;
    FOnHandshake: TWebSocketSessionEvent;
    FOnDisconnect: TWebSocketSessionEvent;
    FOnMessage: TWebSocketTextEvent;
    FOnBinary: TWebSocketBinaryEvent;
    FOnError: TWebSocketErrorEvent;
    FOnLog: TWebSocketLogEvent;
    FOnAuthorize: TWebSocketAuthorizeEvent;

    { Eventos do TIdTCPServer }
    procedure DoServerConnect(AContext: TIdContext);
    procedure DoServerDisconnect(AContext: TIdContext);
    procedure DoServerExecute(AContext: TIdContext);

    { Rotinas internas }
    procedure Log(const AMessage: String);
    procedure NotifyError(const ASession: IWebSocketSession; const AException: Exception);
    procedure CheckInactive(const AOperation: String);
    procedure RegisterSession(const ASession: IWebSocketSession);
    procedure UnregisterSession(const ASession: IWebSocketSession);
    function SessionOf(const AContext: TIdContext): TWebSocketSession;
    function Snapshot: TArray<IWebSocketSession>;
    procedure ProcessHandshake(const ASession: TWebSocketSession);
    procedure ProcessFrame(const ASession: TWebSocketSession);
    procedure ProcessDataFrame(const ASession: TWebSocketSession;
      const AFrame: TWebSocketFrame);
    procedure DeliverWelcome(const ASession: TWebSocketSession);
    procedure DeliverOfflineMessages(const ASession: TWebSocketSession);
    function DispatchBroadcast(const AMessage: TWebSocketOutgoingMessage): Integer;
    function DispatchDirect(const AMessage: TWebSocketOutgoingMessage): Integer;
    function WriteToSession(const ASession: IWebSocketSession;
      const AMessage: TWebSocketOutgoingMessage): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    class function New: IWebSocketServer;

    { IWebSocketServer - configuração }
    function Port(const AValue: Word): IWebSocketServer;
    function Path(const AValue: String): IWebSocketServer;
    function UserNameParameter(const AValue: String): IWebSocketServer;
    function MaxConnections(const AValue: Integer): IWebSocketServer;
    function ReadTimeout(const AValue: Integer): IWebSocketServer;
    function KeepOfflineMessages(const AValue: Boolean = True): IWebSocketServer;
    function OfflineStore(const AValue: IWebSocketOfflineStore): IWebSocketServer;
    function EchoPingAsPong(const AValue: Boolean = True): IWebSocketServer;
    function SendWelcomeMessage(const AValue: Boolean = True): IWebSocketServer;

    { IWebSocketServer - eventos }
    function OnStart(const AEvent: TWebSocketServerEvent): IWebSocketServer;
    function OnStop(const AEvent: TWebSocketServerEvent): IWebSocketServer;
    function OnConnect(const AEvent: TWebSocketSessionEvent): IWebSocketServer;
    function OnHandshake(const AEvent: TWebSocketSessionEvent): IWebSocketServer;
    function OnDisconnect(const AEvent: TWebSocketSessionEvent): IWebSocketServer;
    function OnMessage(const AEvent: TWebSocketTextEvent): IWebSocketServer;
    function OnBinary(const AEvent: TWebSocketBinaryEvent): IWebSocketServer;
    function OnError(const AEvent: TWebSocketErrorEvent): IWebSocketServer;
    function OnLog(const AEvent: TWebSocketLogEvent): IWebSocketServer;
    function OnAuthorize(const AEvent: TWebSocketAuthorizeEvent): IWebSocketServer;

    { IWebSocketServer - controle }
    function Start: IWebSocketServer;
    function Stop: IWebSocketServer;
    function IsActive: Boolean;

    { IWebSocketServer - consultas }
    function Sessions: TArray<IWebSocketSession>;
    function SessionCount: Integer;
    function FindSession(const ATarget: String; out ASession: IWebSocketSession): Boolean;

    { IWebSocketServer - envio }
    function NewMessage: IWebSocketMessage;
    function Broadcast(const AText: String): Integer;
    function SendTo(const ATarget: String; const AText: String): Integer;
    function DisconnectAll: IWebSocketServer;

    { IWebSocketDispatcher }
    function DispatchMessage(const AMessage: TWebSocketOutgoingMessage): Integer;
  end;

implementation

{ TWebSocketServer }

constructor TWebSocketServer.Create;
begin
  inherited Create;

  FPort := C_DEFAULT_PORT;
  FPath := C_DEFAULT_PATH;
  FUserNameParameter := C_DEFAULT_USER_NAME_PARAM;
  FReadTimeout := C_DEFAULT_READ_TIMEOUT;
  FKeepOfflineMessages := False;
  FEchoPingAsPong := True;
  FSendWelcomeMessage := True;

  FSessions := TList<IWebSocketSession>.Create;
  FSessionsLock := TCriticalSection.Create;
  FOfflineStore := TWebSocketMemoryOfflineStore.New;

  FServer := TIdTCPServer.Create(nil);
  FServer.OnConnect := DoServerConnect;
  FServer.OnDisconnect := DoServerDisconnect;
  FServer.OnExecute := DoServerExecute;
end;

destructor TWebSocketServer.Destroy;
begin
  if FServer.Active then
    FServer.Active := False;

  FServer.Free;
  FSessions.Free;
  FSessionsLock.Free;
  inherited;
end;

class function TWebSocketServer.New: IWebSocketServer;
begin
  Result := Create;
end;

{ Rotinas internas }

procedure TWebSocketServer.Log(const AMessage: String);
begin
  if Assigned(FOnLog) then
    FOnLog(AMessage);
end;

procedure TWebSocketServer.NotifyError(const ASession: IWebSocketSession;
  const AException: Exception);
begin
  if Assigned(FOnError) then
    FOnError(ASession, AException)
  else
    Log('Erro: ' + AException.Message);
end;

procedure TWebSocketServer.CheckInactive(const AOperation: String);
begin
  if FServer.Active then
    raise EWebSocketConfigurationException.CreateFmt(
      'A configuração "%s" não pode ser alterada com o servidor ativo.', [AOperation]);
end;

procedure TWebSocketServer.RegisterSession(const ASession: IWebSocketSession);
begin
  FSessionsLock.Enter;
  try
    FSessions.Add(ASession);
  finally
    FSessionsLock.Leave;
  end;
end;

procedure TWebSocketServer.UnregisterSession(const ASession: IWebSocketSession);
begin
  FSessionsLock.Enter;
  try
    FSessions.Remove(ASession);
  finally
    FSessionsLock.Leave;
  end;
end;

function TWebSocketServer.SessionOf(const AContext: TIdContext): TWebSocketSession;
begin
  Result := nil;

  if (AContext <> nil) and (AContext.Data is TWebSocketSession) then
    Result := TWebSocketSession(AContext.Data);
end;

function TWebSocketServer.Snapshot: TArray<IWebSocketSession>;
begin
  FSessionsLock.Enter;
  try
    Result := FSessions.ToArray;
  finally
    FSessionsLock.Leave;
  end;
end;

{ Eventos do TIdTCPServer }

procedure TWebSocketServer.DoServerConnect(AContext: TIdContext);
var
  LSession: TWebSocketSession;
begin
  LSession := TWebSocketSession.Create(AContext);
  AContext.Data := LSession;
  RegisterSession(LSession);
  Log(Format('Cliente conectado: %s', [LSession.ID]));

  if Assigned(FOnConnect) then
    FOnConnect(LSession);
end;

procedure TWebSocketServer.DoServerDisconnect(AContext: TIdContext);
var
  LSession: TWebSocketSession;
  LReference: IWebSocketSession;
begin
  LSession := SessionOf(AContext);

  if LSession = nil then
    Exit;

  LReference := LSession;
  AContext.Data := nil;
  LSession.ChangeState(wssClosed);
  Log(Format('Cliente desconectado: %s (%s)', [LSession.UserName, LSession.ID]));

  if Assigned(FOnDisconnect) then
  begin
    try
      FOnDisconnect(LReference);
    except
      on E: Exception do
        NotifyError(LReference, E);
    end;
  end;

  UnregisterSession(LReference);
end;

procedure TWebSocketServer.DoServerExecute(AContext: TIdContext);
var
  LSession: TWebSocketSession;
begin
  LSession := SessionOf(AContext);

  if LSession = nil then
    Exit;

  try
    if LSession.State = wssOpen then
      ProcessFrame(LSession)
    else
      ProcessHandshake(LSession);
  except
    on E: EIdException do
      AContext.Connection.Disconnect;
    on E: Exception do
    begin
      NotifyError(LSession, E);
      AContext.Connection.Disconnect;
    end;
  end;
end;

procedure TWebSocketServer.ProcessHandshake(const ASession: TWebSocketSession);
var
  LRequest: TWebSocketHandshakeRequest;
  LIOHandler: TIdIOHandler;
  LUserName: String;
  LAuthorized: Boolean;
begin
  LIOHandler := ASession.Context.Connection.IOHandler;
  ASession.ChangeState(wssHandshaking);

  if not TWebSocketHandshake.TryReadRequest(LIOHandler, LRequest) then
  begin
    TWebSocketHandshake.Reject(LIOHandler);
    ASession.Context.Connection.Disconnect;
    Log('Requisição inválida recusada: não é um upgrade WebSocket.');
    Exit;
  end;

  if (FPath <> C_DEFAULT_PATH) and (not SameText(LRequest.Path, FPath)) then
  begin
    TWebSocketHandshake.Reject(LIOHandler, '404 Not Found');
    ASession.Context.Connection.Disconnect;
    Log(Format('Recurso "%s" recusado. Esperado "%s".', [LRequest.Path, FPath]));
    Exit;
  end;

  ASession.ApplyHandshake(LRequest.Resource, LRequest.Path, LRequest.Query,
    FUserNameParameter);

  if Assigned(FOnAuthorize) then
  begin
    LUserName := ASession.UserName;
    LAuthorized := FOnAuthorize(LRequest.Resource, LUserName);

    if not LAuthorized then
    begin
      ASession.ChangeState(wssHandshaking);
      TWebSocketHandshake.Reject(LIOHandler, '401 Unauthorized');
      ASession.Context.Connection.Disconnect;
      Log(Format('Conexão não autorizada para "%s".', [LUserName]));
      Exit;
    end;
  end;

  TWebSocketHandshake.Accept(LIOHandler, LRequest);
  Log(Format('Handshake concluído para %s (%s)', [ASession.UserName, ASession.ID]));

  if Assigned(FOnHandshake) then
    FOnHandshake(ASession);

  DeliverWelcome(ASession);
  DeliverOfflineMessages(ASession);
end;

procedure TWebSocketServer.DeliverWelcome(const ASession: TWebSocketSession);
var
  LWelcome: TJSONObject;
begin
  if not FSendWelcomeMessage then
    Exit;

  LWelcome := TJSONObject.Create;
  try
    LWelcome
      .AddPair('type', 'welcome')
      .AddPair('id', ASession.ID)
      .AddPair('name', ASession.UserName);
    ASession.Send(LWelcome);
  finally
    LWelcome.Free;
  end;
end;

procedure TWebSocketServer.DeliverOfflineMessages(const ASession: TWebSocketSession);
var
  LPending: TArray<String>;
  LMessage: String;
begin
  if not FKeepOfflineMessages then
    Exit;

  LPending := FOfflineStore.Fetch(ASession.UserName);

  if Length(LPending) = 0 then
    Exit;

  Log(Format('Entregando %d mensagem(ns) pendente(s) para %s.',
    [Length(LPending), ASession.UserName]));

  for LMessage in LPending do
    ASession.Send(LMessage);
end;

procedure TWebSocketServer.ProcessFrame(const ASession: TWebSocketSession);
var
  LFrame: TWebSocketFrame;
  LIOHandler: TIdIOHandler;
begin
  LIOHandler := ASession.Context.Connection.IOHandler;

  if not TWebSocketFrameCodec.TryRead(LIOHandler, LFrame, FReadTimeout) then
    Exit;

  ASession.TouchActivity;

  case LFrame.OpCode of
    wsoContinuation, wsoText, wsoBinary:
      ProcessDataFrame(ASession, LFrame);

    wsoClose:
      begin
        ASession.ChangeState(wssClosing);
        ASession.Context.Connection.Disconnect;
      end;

    wsoPing:
      if FEchoPingAsPong then
        ASession.SendPong(LFrame.Payload);

    wsoPong:
      Log(Format('Pong recebido de %s.', [ASession.ID]));
  end;
end;

procedure TWebSocketServer.ProcessDataFrame(const ASession: TWebSocketSession;
  const AFrame: TWebSocketFrame);
var
  LPayload: TIdBytes;
  LOpCode: TWebSocketOpCode;
  LText: String;
begin
  if not ASession.AppendFragment(AFrame) then
    Exit;

  LOpCode := ASession.FragmentOpCode;
  LPayload := ASession.TakeFragmentPayload;

  if LOpCode = wsoBinary then
  begin
    if Assigned(FOnBinary) then
      FOnBinary(ASession, LPayload);

    Exit;
  end;

  LText := BytesToString(LPayload, IndyTextEncoding_UTF8);
  Log(Format('Mensagem de %s: %s', [ASession.UserName, LText]));

  if Assigned(FOnMessage) then
    FOnMessage(ASession, LText);
end;

{ Configuração fluente }

function TWebSocketServer.Port(const AValue: Word): IWebSocketServer;
begin
  Result := Self;
  CheckInactive('Port');
  FPort := AValue;
end;

function TWebSocketServer.Path(const AValue: String): IWebSocketServer;
begin
  Result := Self;
  CheckInactive('Path');

  if AValue = '' then
    FPath := C_DEFAULT_PATH
  else
    FPath := AValue;
end;

function TWebSocketServer.UserNameParameter(const AValue: String): IWebSocketServer;
begin
  Result := Self;
  CheckInactive('UserNameParameter');
  FUserNameParameter := AValue;
end;

function TWebSocketServer.MaxConnections(const AValue: Integer): IWebSocketServer;
begin
  Result := Self;
  FServer.MaxConnections := AValue;
end;

function TWebSocketServer.ReadTimeout(const AValue: Integer): IWebSocketServer;
begin
  Result := Self;
  FReadTimeout := AValue;
end;

function TWebSocketServer.KeepOfflineMessages(const AValue: Boolean): IWebSocketServer;
begin
  Result := Self;
  FKeepOfflineMessages := AValue;
end;

function TWebSocketServer.OfflineStore(const AValue: IWebSocketOfflineStore): IWebSocketServer;
begin
  Result := Self;

  if AValue = nil then
    raise EWebSocketConfigurationException.Create(
      'O repositório de mensagens offline não pode ser nulo.');

  FOfflineStore := AValue;
end;

function TWebSocketServer.EchoPingAsPong(const AValue: Boolean): IWebSocketServer;
begin
  Result := Self;
  FEchoPingAsPong := AValue;
end;

function TWebSocketServer.SendWelcomeMessage(const AValue: Boolean): IWebSocketServer;
begin
  Result := Self;
  FSendWelcomeMessage := AValue;
end;

{ Eventos }

function TWebSocketServer.OnStart(const AEvent: TWebSocketServerEvent): IWebSocketServer;
begin
  Result := Self;
  FOnStart := AEvent;
end;

function TWebSocketServer.OnStop(const AEvent: TWebSocketServerEvent): IWebSocketServer;
begin
  Result := Self;
  FOnStop := AEvent;
end;

function TWebSocketServer.OnConnect(const AEvent: TWebSocketSessionEvent): IWebSocketServer;
begin
  Result := Self;
  FOnConnect := AEvent;
end;

function TWebSocketServer.OnHandshake(const AEvent: TWebSocketSessionEvent): IWebSocketServer;
begin
  Result := Self;
  FOnHandshake := AEvent;
end;

function TWebSocketServer.OnDisconnect(const AEvent: TWebSocketSessionEvent): IWebSocketServer;
begin
  Result := Self;
  FOnDisconnect := AEvent;
end;

function TWebSocketServer.OnMessage(const AEvent: TWebSocketTextEvent): IWebSocketServer;
begin
  Result := Self;
  FOnMessage := AEvent;
end;

function TWebSocketServer.OnBinary(const AEvent: TWebSocketBinaryEvent): IWebSocketServer;
begin
  Result := Self;
  FOnBinary := AEvent;
end;

function TWebSocketServer.OnError(const AEvent: TWebSocketErrorEvent): IWebSocketServer;
begin
  Result := Self;
  FOnError := AEvent;
end;

function TWebSocketServer.OnLog(const AEvent: TWebSocketLogEvent): IWebSocketServer;
begin
  Result := Self;
  FOnLog := AEvent;
end;

function TWebSocketServer.OnAuthorize(const AEvent: TWebSocketAuthorizeEvent): IWebSocketServer;
begin
  Result := Self;
  FOnAuthorize := AEvent;
end;

{ Controle }

function TWebSocketServer.Start: IWebSocketServer;
var
  LBinding: TIdSocketHandle;
begin
  Result := Self;

  if FServer.Active then
    Exit;

  FServer.Bindings.Clear;
  LBinding := FServer.Bindings.Add;
  LBinding.IP := '0.0.0.0';
  LBinding.Port := FPort;
  FServer.DefaultPort := FPort;
  FServer.Active := True;

  Log(Format('Servidor WebSocket ouvindo na porta %d, recurso "%s".', [FPort, FPath]));

  if Assigned(FOnStart) then
    FOnStart(Self);
end;

function TWebSocketServer.Stop: IWebSocketServer;
begin
  Result := Self;

  if not FServer.Active then
    Exit;

  DisconnectAll;
  FServer.Active := False;
  Log('Servidor WebSocket encerrado.');

  if Assigned(FOnStop) then
    FOnStop(Self);
end;

function TWebSocketServer.IsActive: Boolean;
begin
  Result := FServer.Active;
end;

function TWebSocketServer.DisconnectAll: IWebSocketServer;
var
  LSession: IWebSocketSession;
begin
  Result := Self;

  for LSession in Snapshot do
  begin
    try
      LSession.Close;
    except
      on E: Exception do
        NotifyError(LSession, E);
    end;
  end;
end;

{ Consultas }

function TWebSocketServer.Sessions: TArray<IWebSocketSession>;
begin
  Result := Snapshot;
end;

function TWebSocketServer.SessionCount: Integer;
begin
  FSessionsLock.Enter;
  try
    Result := FSessions.Count;
  finally
    FSessionsLock.Leave;
  end;
end;

function TWebSocketServer.FindSession(const ATarget: String;
  out ASession: IWebSocketSession): Boolean;
var
  LSession: IWebSocketSession;
  LCandidate: TWebSocketSession;
begin
  ASession := nil;

  for LSession in Snapshot do
  begin
    LCandidate := LSession as TWebSocketSession;

    if LCandidate.IsOpen and LCandidate.Matches(ATarget) and (ASession = nil) then
      ASession := LSession;
  end;

  Result := ASession <> nil;
end;

{ Envio }

function TWebSocketServer.NewMessage: IWebSocketMessage;
begin
  Result := TWebSocketMessage.New(Self);
end;

function TWebSocketServer.Broadcast(const AText: String): Integer;
begin
  Result := NewMessage
    .Text(AText)
    .ToAll
    .Send;
end;

function TWebSocketServer.SendTo(const ATarget: String; const AText: String): Integer;
begin
  Result := NewMessage
    .Text(AText)
    .&To(ATarget)
    .StoreWhenOffline(FKeepOfflineMessages)
    .Send;
end;

function TWebSocketServer.WriteToSession(const ASession: IWebSocketSession;
  const AMessage: TWebSocketOutgoingMessage): Boolean;
begin
  Result := False;

  try
    if AMessage.IsBinary then
      ASession.SendBinary(AMessage.Data)
    else
      ASession.Send(AMessage.Text);

    Result := True;
  except
    on E: Exception do
      NotifyError(ASession, E);
  end;
end;

function TWebSocketServer.DispatchBroadcast(const AMessage: TWebSocketOutgoingMessage): Integer;
var
  LSession: IWebSocketSession;
begin
  Result := 0;

  for LSession in Snapshot do
  begin
    if LSession.IsOpen and (not SameText(LSession.ID, AMessage.ExcludeID)) then
    begin
      if WriteToSession(LSession, AMessage) then
        Inc(Result);
    end;
  end;
end;

function TWebSocketServer.DispatchDirect(const AMessage: TWebSocketOutgoingMessage): Integer;
var
  LSession: IWebSocketSession;
begin
  Result := 0;

  if FindSession(AMessage.Target, LSession) then
  begin
    if WriteToSession(LSession, AMessage) then
      Inc(Result);
  end;

  if (Result = 0) and AMessage.StoreWhenOffline and (not AMessage.IsBinary) then
  begin
    FOfflineStore.Store(AMessage.Target, AMessage.Text);
    Log(Format('Destinatário "%s" offline. Mensagem armazenada.', [AMessage.Target]));
  end;
end;

function TWebSocketServer.DispatchMessage(const AMessage: TWebSocketOutgoingMessage): Integer;
begin
  if AMessage.DeliveryMode = wsdDirect then
    Result := DispatchDirect(AMessage)
  else
    Result := DispatchBroadcast(AMessage);
end;

end.
