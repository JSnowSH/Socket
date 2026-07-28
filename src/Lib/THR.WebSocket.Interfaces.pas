{*******************************************************************************
  Unit......: THR.WebSocket.Interfaces
  Objetivo..: Contratos (interfaces) fluentes da biblioteca WebSocket ThR.
              Toda a API pública do servidor é consumida por estas interfaces.
  Padrão....: ThR - Normas e Padronização de Codificação (Delphi) v4.0.1
*******************************************************************************}
unit THR.WebSocket.Interfaces;

interface

uses
  System.SysUtils, System.JSON, IdGlobal,
  THR.WebSocket.Types;

type
  IWebSocketSession = interface;
  IWebSocketMessage = interface;
  IWebSocketServer = interface;

  { Eventos publicados pelo servidor }
  TWebSocketLogEvent = reference to procedure(const AMessage: String);
  TWebSocketServerEvent = reference to procedure(const AServer: IWebSocketServer);
  TWebSocketSessionEvent = reference to procedure(const ASession: IWebSocketSession);
  TWebSocketTextEvent = reference to procedure(const ASession: IWebSocketSession;
    const AMessage: String);
  TWebSocketBinaryEvent = reference to procedure(const ASession: IWebSocketSession;
    const AData: TIdBytes);
  TWebSocketErrorEvent = reference to procedure(const ASession: IWebSocketSession;
    const AException: Exception);
  TWebSocketAuthorizeEvent = reference to function(const AResource: String;
    const AUserName: String): Boolean;

  {*****************************************************************************
    IWebSocketSession
    Representa um cliente conectado. Permite consultar a identificação e os
    parâmetros informados no handshake, além de enviar dados diretamente.
  *****************************************************************************}
  IWebSocketSession = interface
    ['{4B0F3D91-6C57-4A2E-9E0B-13C7A5E28D41}']
    function ID: String;
    function UserName: String;
    function Resource: String;
    function Path: String;
    function Parameter(const AName: String): String;
    function State: TWebSocketSessionState;
    function IsOpen: Boolean;
    function IsConnected: Boolean;
    function CreatedAt: TDateTime;
    function LastActivityAt: TDateTime;

    function Send(const AText: String): IWebSocketSession; overload;
    function Send(const AJSON: TJSONObject): IWebSocketSession; overload;
    function SendBinary(const AData: TIdBytes): IWebSocketSession;
    function Ping: IWebSocketSession;
    function Close: IWebSocketSession;
  end;

  {*****************************************************************************
    IWebSocketOfflineStore
    Repositório de mensagens destinadas a usuários desconectados.
  *****************************************************************************}
  IWebSocketOfflineStore = interface
    ['{9D1C7A38-2E64-4B15-8F03-6A5D9B4E7C22}']
    function Store(const ATarget: String; const AMessage: String): IWebSocketOfflineStore;
    function Fetch(const ATarget: String): TArray<String>;
    function Count(const ATarget: String): Integer;
    function Clear(const ATarget: String): IWebSocketOfflineStore;
    function ClearAll: IWebSocketOfflineStore;
  end;

  {*****************************************************************************
    IWebSocketMessage
    Construtor fluente de mensagens de saída. A mensagem só é transmitida
    quando o método Send é invocado.

    Exemplo:
      LServer
        .NewMessage
        .Text('Ola!')
        .&To('UserA')
        .StoreWhenOffline
        .Send;
  *****************************************************************************}
  IWebSocketMessage = interface
    ['{1F8B2C05-77A4-4D69-B3E2-58C0A9147F63}']
    function Text(const AValue: String): IWebSocketMessage;
    function JSON(const AValue: TJSONObject): IWebSocketMessage;
    function Binary(const AValue: TIdBytes): IWebSocketMessage;

    function &To(const ATarget: String): IWebSocketMessage;
    function Target(const ATarget: String): IWebSocketMessage;
    function ToAll: IWebSocketMessage;
    function Excluding(const ASessionID: String): IWebSocketMessage;
    function StoreWhenOffline(const AValue: Boolean = True): IWebSocketMessage;

    function Send: Integer;
  end;

  {*****************************************************************************
    IWebSocketServer
    Fachada fluente do servidor WebSocket. Métodos de configuração e de
    registro de eventos retornam a própria interface, permitindo encadeamento.

    Exemplo:
      TWebSocketServer
        .New
        .Port(8080)
        .Path('/chat')
        .KeepOfflineMessages
        .OnMessage(
          procedure(const ASession: IWebSocketSession; const AMessage: String)
          begin
            ASession.Send('Eco: ' + AMessage);
          end)
        .Start;
  *****************************************************************************}
  IWebSocketServer = interface
    ['{2A6E4C13-5D80-4F97-A1B6-7C3E9F05D284}']
    { Configuração }
    function Port(const AValue: Word): IWebSocketServer;
    function Path(const AValue: String): IWebSocketServer;
    function UserNameParameter(const AValue: String): IWebSocketServer;
    function MaxConnections(const AValue: Integer): IWebSocketServer;
    function ReadTimeout(const AValue: Integer): IWebSocketServer;
    function KeepOfflineMessages(const AValue: Boolean = True): IWebSocketServer;
    function OfflineStore(const AValue: IWebSocketOfflineStore): IWebSocketServer;
    function EchoPingAsPong(const AValue: Boolean = True): IWebSocketServer;
    function SendWelcomeMessage(const AValue: Boolean = True): IWebSocketServer;

    { Eventos }
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

    { Controle }
    function Start: IWebSocketServer;
    function Stop: IWebSocketServer;
    function IsActive: Boolean;

    { Consultas }
    function Sessions: TArray<IWebSocketSession>;
    function SessionCount: Integer;
    function FindSession(const ATarget: String; out ASession: IWebSocketSession): Boolean;

    { Envio }
    function NewMessage: IWebSocketMessage;
    function Broadcast(const AText: String): Integer;
    function SendTo(const ATarget: String; const AText: String): Integer;
    function DisconnectAll: IWebSocketServer;
  end;

  {*****************************************************************************
    IWebSocketDispatcher
    Contrato interno consumido pelo construtor fluente de mensagens.
  *****************************************************************************}
  IWebSocketDispatcher = interface
    ['{6C9A0F72-4B38-41E5-BD27-0E8F35A6C914}']
    function DispatchMessage(const AMessage: TWebSocketOutgoingMessage): Integer;
  end;

implementation

end.
