{*******************************************************************************
  Unit......: THR.WebSocket.Pusher
  Objetivo..: Camada de protocolo Pusher (Laravel Reverb / Laravel WebSockets)
              construída sobre o IWebSocketClient da biblioteca ThR.
              Trata handshake de aplicação, subscrição de canais, ping/pong
              de aplicação e autenticação de canais privados e de presença.
  Padrão....: ThR - Normas e Padronização de Codificação (Delphi) v4.0.1
*******************************************************************************}
unit THR.WebSocket.Pusher;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Hash,
  THR.WebSocket.Types,
  THR.WebSocket.Client;

type
  EPusherException = class(EWebSocketException);

  IPusherClient = interface;

  TPusherEvent = reference to procedure(const AClient: IPusherClient);
  TPusherTextEvent = reference to procedure(const AClient: IPusherClient;
    const AMessage: String);
  TPusherChannelEvent = reference to procedure(const AClient: IPusherClient;
    const AChannel: String);
  TPusherMessageEvent = reference to procedure(const AClient: IPusherClient;
    const AChannel: String; const AEvent: String; const AData: String);
  TPusherErrorEvent = reference to procedure(const AClient: IPusherClient;
    const AException: Exception);

  { Assinatura de canal privado delegada ao consumidor (ex.: POST em
    /broadcasting/auth). Deve retornar o conteúdo do campo "auth". }
  TPusherAuthorizeEvent = reference to function(const ASocketID: String;
    const AChannel: String): String;

  {*****************************************************************************
    IPusherClient
    Contrato fluente do cliente Pusher.

    Exemplo:
      TPusherClient
        .New
        .Host('127.0.0.1')
        .Port(6001)
        .AppKey('5e0e16ccda5d32cde34cfdd4e1a214f8')
        .SynchronizeEvents
        .OnEvent(
          procedure(const AClient: IPusherClient; const AChannel: String;
            const AEvent: String; const AData: String)
          begin
            MemoLog.Lines.Add(AChannel + ' | ' + AEvent + ' | ' + AData);
          end)
        .Subscribe('pedidos')
        .Connect;
  *****************************************************************************}
  IPusherClient = interface
    ['{6C41B7A2-90D5-4E38-A7F1-5B2E08C93D64}']
    { Configuração }
    function Host(const AValue: String): IPusherClient;
    function Port(const AValue: Word): IPusherClient;
    function Path(const AValue: String): IPusherClient;
    function AppKey(const AValue: String): IPusherClient;
    function AppSecret(const AValue: String): IPusherClient;
    function ConnectTimeout(const AValue: Integer): IPusherClient;
    function ReadTimeout(const AValue: Integer): IPusherClient;
    function SynchronizeEvents(const AValue: Boolean = True): IPusherClient;

    { Eventos }
    function OnConnected(const AEvent: TPusherEvent): IPusherClient;
    function OnDisconnected(const AEvent: TPusherEvent): IPusherClient;
    function OnSubscribed(const AEvent: TPusherChannelEvent): IPusherClient;
    function OnEvent(const AEvent: TPusherMessageEvent): IPusherClient;
    function OnAuthorize(const AEvent: TPusherAuthorizeEvent): IPusherClient;
    function OnError(const AEvent: TPusherErrorEvent): IPusherClient;
    function OnLog(const AEvent: TPusherTextEvent): IPusherClient;

    { Controle }
    function Connect: IPusherClient;
    function Disconnect: IPusherClient;
    function IsConnected: Boolean;
    function IsEstablished: Boolean;
    function SocketID: String;
    function Socket: IWebSocketClient;

    { Canais }
    function Subscribe(const AChannel: String): IPusherClient; overload;
    function Subscribe(const AChannel: String; const AChannelData: String): IPusherClient; overload;
    function Unsubscribe(const AChannel: String): IPusherClient;

    { Envio }
    function Trigger(const AChannel: String; const AEvent: String;
      const AData: String): IPusherClient;
    function Ping: IPusherClient;
  end;

  {*****************************************************************************
    TPusherClient
    Implementa IPusherClient delegando o transporte ao IWebSocketClient.
    Canais registrados antes da conexão são subscritos automaticamente assim
    que o servidor devolve o pusher:connection_established.
  *****************************************************************************}
  TPusherClient = class(TInterfacedObject, IPusherClient)
  strict private
    FSocket: IWebSocketClient;
    FChannels: TStringList;
    FHost: String;
    FPath: String;
    FAppKey: String;
    FAppSecret: String;
    FSocketID: String;
    FPort: Word;

    FOnConnected: TPusherEvent;
    FOnDisconnected: TPusherEvent;
    FOnSubscribed: TPusherChannelEvent;
    FOnEvent: TPusherMessageEvent;
    FOnAuthorize: TPusherAuthorizeEvent;
    FOnError: TPusherErrorEvent;
    FOnLog: TPusherTextEvent;

    procedure BindSocketEvents;
    procedure HandleMessage(const AMessage: String);
    procedure HandleEvent(const AEventName: String; const AChannel: String;
      const AData: String);
    procedure HandleConnectionEstablished(const AData: String);
    procedure SubscribePending;
    procedure SendSubscription(const AChannel: String; const AChannelData: String);
    procedure SendEvent(const AEventName: String; const AData: TJSONObject);
    procedure RememberChannel(const AChannel: String; const AChannelData: String);
    procedure ForgetChannel(const AChannel: String);
    procedure Log(const AMessage: String);
    procedure NotifyError(const AMessage: String);
    function BuildAuth(const AChannel: String; const AChannelData: String): String;
    function BuildResource: String;

    class function IsPrivateChannel(const AChannel: String): Boolean; static;
    class function ExtractData(const AObject: TJSONObject): String; static;
    class function ExtractText(const AObject: TJSONObject; const AName: String): String; static;
  public
    constructor Create;
    destructor Destroy; override;
    class function New: IPusherClient;

    { Configuração }
    function Host(const AValue: String): IPusherClient;
    function Port(const AValue: Word): IPusherClient;
    function Path(const AValue: String): IPusherClient;
    function AppKey(const AValue: String): IPusherClient;
    function AppSecret(const AValue: String): IPusherClient;
    function ConnectTimeout(const AValue: Integer): IPusherClient;
    function ReadTimeout(const AValue: Integer): IPusherClient;
    function SynchronizeEvents(const AValue: Boolean = True): IPusherClient;

    { Eventos }
    function OnConnected(const AEvent: TPusherEvent): IPusherClient;
    function OnDisconnected(const AEvent: TPusherEvent): IPusherClient;
    function OnSubscribed(const AEvent: TPusherChannelEvent): IPusherClient;
    function OnEvent(const AEvent: TPusherMessageEvent): IPusherClient;
    function OnAuthorize(const AEvent: TPusherAuthorizeEvent): IPusherClient;
    function OnError(const AEvent: TPusherErrorEvent): IPusherClient;
    function OnLog(const AEvent: TPusherTextEvent): IPusherClient;

    { Controle }
    function Connect: IPusherClient;
    function Disconnect: IPusherClient;
    function IsConnected: Boolean;
    function IsEstablished: Boolean;
    function SocketID: String;
    function Socket: IWebSocketClient;

    { Canais }
    function Subscribe(const AChannel: String): IPusherClient; overload;
    function Subscribe(const AChannel: String; const AChannelData: String): IPusherClient; overload;
    function Unsubscribe(const AChannel: String): IPusherClient;

    { Envio }
    function Trigger(const AChannel: String; const AEvent: String;
      const AData: String): IPusherClient;
    function Ping: IPusherClient;
  end;

const
  C_PUSHER_DEFAULT_PORT = 6001;
  C_PUSHER_DEFAULT_PATH = '/app';
  C_PUSHER_PROTOCOL = '7';
  C_PUSHER_CLIENT_NAME = 'delphi-thr';
  C_PUSHER_CLIENT_VERSION = '1.0';
  C_PUSHER_PREFIX_PRIVATE = 'private-';
  C_PUSHER_PREFIX_PRESENCE = 'presence-';
  C_PUSHER_PREFIX_CLIENT = 'client-';
  C_PUSHER_EVENT_ESTABLISHED = 'pusher:connection_established';
  C_PUSHER_EVENT_SUBSCRIBE = 'pusher:subscribe';
  C_PUSHER_EVENT_UNSUBSCRIBE = 'pusher:unsubscribe';
  C_PUSHER_EVENT_PING = 'pusher:ping';
  C_PUSHER_EVENT_PONG = 'pusher:pong';
  C_PUSHER_EVENT_ERROR = 'pusher:error';
  C_PUSHER_EVENT_SUBSCRIBED = 'pusher_internal:subscription_succeeded';

implementation

{ TPusherClient }

constructor TPusherClient.Create;
begin
  inherited Create;

  FHost := '127.0.0.1';
  FPort := C_PUSHER_DEFAULT_PORT;
  FPath := C_PUSHER_DEFAULT_PATH;
  FSocketID := '';

  FChannels := TStringList.Create;
  FSocket := TWebSocketClient.New;

  BindSocketEvents;
end;

destructor TPusherClient.Destroy;
begin
  { Libera o transporte antes das estruturas usadas pelos callbacks. }
  FSocket := nil;
  FChannels.Free;
  inherited;
end;

class function TPusherClient.New: IPusherClient;
begin
  Result := Create;
end;

{ Rotinas internas }

procedure TPusherClient.BindSocketEvents;
begin
  FSocket
    .ReplyPingWithPong
    .OnMessage(
      procedure(const AClient: IWebSocketClient; const AMessage: String)
      begin
        HandleMessage(AMessage);
      end)
    .OnDisconnected(
      procedure(const AClient: IWebSocketClient)
      begin
        FSocketID := '';

        if Assigned(FOnDisconnected) then
          FOnDisconnected(Self);
      end)
    .OnError(
      procedure(const AClient: IWebSocketClient; const AException: Exception)
      begin
        if Assigned(FOnError) then
          FOnError(Self, AException);
      end)
    .OnLog(
      procedure(const AClient: IWebSocketClient; const AMessage: String)
      begin
        Log(AMessage);
      end);
end;

function TPusherClient.BuildResource: String;
begin
  if FAppKey = '' then
    raise EPusherException.Create('AppKey não informada (PUSHER_APP_KEY).');

  Result := FPath;

  if Copy(Result, Length(Result), 1) <> '/' then
    Result := Result + '/';

  Result := Result + FAppKey;
end;

procedure TPusherClient.Log(const AMessage: String);
begin
  if Assigned(FOnLog) then
    FOnLog(Self, AMessage);
end;

procedure TPusherClient.NotifyError(const AMessage: String);
var
  LError: Exception;
begin
  if not Assigned(FOnError) then
  begin
    Log(AMessage);
    Exit;
  end;

  LError := EPusherException.Create(AMessage);
  try
    FOnError(Self, LError);
  finally
    LError.Free;
  end;
end;

class function TPusherClient.IsPrivateChannel(const AChannel: String): Boolean;
begin
  Result := AChannel.StartsWith(C_PUSHER_PREFIX_PRIVATE)
    or AChannel.StartsWith(C_PUSHER_PREFIX_PRESENCE);
end;

class function TPusherClient.ExtractText(const AObject: TJSONObject;
  const AName: String): String;
var
  LValue: TJSONValue;
begin
  LValue := AObject.Values[AName];

  if not Assigned(LValue) then
    Exit('');

  if LValue is TJSONString then
    Exit(TJSONString(LValue).Value);

  Result := LValue.ToJSON;
end;

class function TPusherClient.ExtractData(const AObject: TJSONObject): String;
begin
  { O campo "data" chega ora como objeto, ora como string JSON escapada. }
  Result := ExtractText(AObject, 'data');
end;

procedure TPusherClient.RememberChannel(const AChannel: String;
  const AChannelData: String);
begin
  ForgetChannel(AChannel);
  FChannels.Add(AChannel + '=' + AChannelData);
end;

procedure TPusherClient.ForgetChannel(const AChannel: String);
var
  LIndex: Integer;
begin
  LIndex := FChannels.IndexOfName(AChannel);

  if LIndex >= 0 then
    FChannels.Delete(LIndex);
end;

{ Tratamento das mensagens recebidas }

procedure TPusherClient.HandleMessage(const AMessage: String);
var
  LValue: TJSONValue;
begin
  LValue := TJSONObject.ParseJSONValue(AMessage);

  if not Assigned(LValue) then
  begin
    NotifyError('Mensagem Pusher inválida: ' + AMessage);
    Exit;
  end;

  try
    if not (LValue is TJSONObject) then
      Exit;

    HandleEvent(
      ExtractText(TJSONObject(LValue), 'event'),
      ExtractText(TJSONObject(LValue), 'channel'),
      ExtractData(TJSONObject(LValue)));
  finally
    LValue.Free;
  end;
end;

procedure TPusherClient.HandleEvent(const AEventName: String;
  const AChannel: String; const AData: String);
begin
  if AEventName = C_PUSHER_EVENT_ESTABLISHED then
  begin
    HandleConnectionEstablished(AData);
    Exit;
  end;

  if AEventName = C_PUSHER_EVENT_PING then
  begin
    SendEvent(C_PUSHER_EVENT_PONG, TJSONObject.Create);
    Exit;
  end;

  if AEventName = C_PUSHER_EVENT_ERROR then
  begin
    NotifyError('Erro devolvido pelo servidor Pusher: ' + AData);
    Exit;
  end;

  if AEventName = C_PUSHER_EVENT_SUBSCRIBED then
  begin
    Log(Format('Inscrito no canal "%s".', [AChannel]));

    if Assigned(FOnSubscribed) then
      FOnSubscribed(Self, AChannel);

    Exit;
  end;

  if Assigned(FOnEvent) then
    FOnEvent(Self, AChannel, AEventName, AData);
end;

procedure TPusherClient.HandleConnectionEstablished(const AData: String);
var
  LValue: TJSONValue;
begin
  LValue := TJSONObject.ParseJSONValue(AData);
  try
    if LValue is TJSONObject then
      FSocketID := ExtractText(TJSONObject(LValue), 'socket_id');
  finally
    LValue.Free;
  end;

  if FSocketID = '' then
  begin
    NotifyError('Conexão estabelecida sem socket_id: ' + AData);
    Exit;
  end;

  Log('Conexão Pusher estabelecida. socket_id = ' + FSocketID);
  SubscribePending;

  if Assigned(FOnConnected) then
    FOnConnected(Self);
end;

{ Envio }

procedure TPusherClient.SendEvent(const AEventName: String; const AData: TJSONObject);
var
  LRoot: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('event', AEventName);

    if Assigned(AData) then
      LRoot.AddPair('data', AData);

    FSocket.Send(LRoot.ToJSON);
  finally
    LRoot.Free;
  end;
end;

function TPusherClient.BuildAuth(const AChannel: String;
  const AChannelData: String): String;
var
  LPayload: String;
begin
  if not IsPrivateChannel(AChannel) then
    Exit('');

  if Assigned(FOnAuthorize) then
    Exit(FOnAuthorize(FSocketID, AChannel));

  if FAppSecret = '' then
    raise EPusherException.CreateFmt(
      'O canal "%s" exige autenticação: informe AppSecret ou OnAuthorize.', [AChannel]);

  LPayload := FSocketID + ':' + AChannel;

  if AChannelData <> '' then
    LPayload := LPayload + ':' + AChannelData;

  Result := FAppKey + ':' + THashSHA2.GetHMAC(LPayload, FAppSecret, SHA256);
end;

procedure TPusherClient.SendSubscription(const AChannel: String;
  const AChannelData: String);
var
  LData: TJSONObject;
  LAuth: String;
begin
  LAuth := BuildAuth(AChannel, AChannelData);

  LData := TJSONObject.Create;
  LData.AddPair('channel', AChannel);

  if LAuth <> '' then
    LData.AddPair('auth', LAuth);

  if AChannelData <> '' then
    LData.AddPair('channel_data', AChannelData);

  SendEvent(C_PUSHER_EVENT_SUBSCRIBE, LData);
end;

procedure TPusherClient.SubscribePending;
var
  LIndex: Integer;
begin
  for LIndex := 0 to FChannels.Count - 1 do
    SendSubscription(FChannels.Names[LIndex], FChannels.ValueFromIndex[LIndex]);
end;

{ Configuração }

function TPusherClient.Host(const AValue: String): IPusherClient;
begin
  Result := Self;
  FHost := AValue;
end;

function TPusherClient.Port(const AValue: Word): IPusherClient;
begin
  Result := Self;
  FPort := AValue;
end;

function TPusherClient.Path(const AValue: String): IPusherClient;
begin
  Result := Self;
  FPath := AValue;
end;

function TPusherClient.AppKey(const AValue: String): IPusherClient;
begin
  Result := Self;
  FAppKey := AValue;
end;

function TPusherClient.AppSecret(const AValue: String): IPusherClient;
begin
  Result := Self;
  FAppSecret := AValue;
end;

function TPusherClient.ConnectTimeout(const AValue: Integer): IPusherClient;
begin
  Result := Self;
  FSocket.ConnectTimeout(AValue);
end;

function TPusherClient.ReadTimeout(const AValue: Integer): IPusherClient;
begin
  Result := Self;
  FSocket.ReadTimeout(AValue);
end;

function TPusherClient.SynchronizeEvents(const AValue: Boolean): IPusherClient;
begin
  Result := Self;
  FSocket.SynchronizeEvents(AValue);
end;

{ Eventos }

function TPusherClient.OnConnected(const AEvent: TPusherEvent): IPusherClient;
begin
  Result := Self;
  FOnConnected := AEvent;
end;

function TPusherClient.OnDisconnected(const AEvent: TPusherEvent): IPusherClient;
begin
  Result := Self;
  FOnDisconnected := AEvent;
end;

function TPusherClient.OnSubscribed(const AEvent: TPusherChannelEvent): IPusherClient;
begin
  Result := Self;
  FOnSubscribed := AEvent;
end;

function TPusherClient.OnEvent(const AEvent: TPusherMessageEvent): IPusherClient;
begin
  Result := Self;
  FOnEvent := AEvent;
end;

function TPusherClient.OnAuthorize(const AEvent: TPusherAuthorizeEvent): IPusherClient;
begin
  Result := Self;
  FOnAuthorize := AEvent;
end;

function TPusherClient.OnError(const AEvent: TPusherErrorEvent): IPusherClient;
begin
  Result := Self;
  FOnError := AEvent;
end;

function TPusherClient.OnLog(const AEvent: TPusherTextEvent): IPusherClient;
begin
  Result := Self;
  FOnLog := AEvent;
end;

{ Controle }

function TPusherClient.Connect: IPusherClient;
begin
  Result := Self;

  if FSocket.IsConnected then
    Exit;

  FSocketID := '';

  FSocket
    .Host(FHost)
    .Port(FPort)
    .Resource(BuildResource)
    .Parameter('protocol', C_PUSHER_PROTOCOL)
    .Parameter('client', C_PUSHER_CLIENT_NAME)
    .Parameter('version', C_PUSHER_CLIENT_VERSION)
    .Connect;
end;

function TPusherClient.Disconnect: IPusherClient;
begin
  Result := Self;
  FSocketID := '';
  FSocket.Disconnect;
end;

function TPusherClient.IsConnected: Boolean;
begin
  Result := FSocket.IsConnected;
end;

function TPusherClient.IsEstablished: Boolean;
begin
  Result := FSocket.IsConnected and (FSocketID <> '');
end;

function TPusherClient.SocketID: String;
begin
  Result := FSocketID;
end;

function TPusherClient.Socket: IWebSocketClient;
begin
  Result := FSocket;
end;

{ Canais }

function TPusherClient.Subscribe(const AChannel: String): IPusherClient;
begin
  Result := Subscribe(AChannel, '');
end;

function TPusherClient.Subscribe(const AChannel: String;
  const AChannelData: String): IPusherClient;
begin
  Result := Self;

  if AChannel = '' then
    Exit;

  RememberChannel(AChannel, AChannelData);

  { Antes do connection_established não há socket_id para assinar o canal. }
  if IsEstablished then
    SendSubscription(AChannel, AChannelData);
end;

function TPusherClient.Unsubscribe(const AChannel: String): IPusherClient;
var
  LData: TJSONObject;
begin
  Result := Self;
  ForgetChannel(AChannel);

  if not IsEstablished then
    Exit;

  LData := TJSONObject.Create;
  LData.AddPair('channel', AChannel);
  SendEvent(C_PUSHER_EVENT_UNSUBSCRIBE, LData);
end;

{ Envio }

function TPusherClient.Trigger(const AChannel: String; const AEvent: String;
  const AData: String): IPusherClient;
var
  LRoot: TJSONObject;
  LData: TJSONValue;
begin
  Result := Self;

  if not AEvent.StartsWith(C_PUSHER_PREFIX_CLIENT) then
    raise EPusherException.CreateFmt(
      'Eventos de cliente devem começar com "%s".', [C_PUSHER_PREFIX_CLIENT]);

  { Payload não-JSON é transmitido como string simples. }
  LData := TJSONObject.ParseJSONValue(AData);

  if not Assigned(LData) then
    LData := TJSONString.Create(AData);

  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('event', AEvent);
    LRoot.AddPair('channel', AChannel);
    LRoot.AddPair('data', LData);
    FSocket.Send(LRoot.ToJSON);
  finally
    LRoot.Free;
  end;
end;

function TPusherClient.Ping: IPusherClient;
begin
  Result := Self;
  SendEvent(C_PUSHER_EVENT_PING, TJSONObject.Create);
end;

end.
