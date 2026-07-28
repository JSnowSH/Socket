{*******************************************************************************
  Unit......: THR.WebSocket
  Objetivo..: Fachada da biblioteca. Basta declarar esta unit no uses para ter
              acesso a todos os tipos, interfaces e implementações.
  Padrão....: ThR - Normas e Padronização de Codificação (Delphi) v4.0.1
*******************************************************************************}
unit THR.WebSocket;

interface

uses
  THR.WebSocket.Types, THR.WebSocket.Interfaces, THR.WebSocket.Frame,
  THR.WebSocket.Handshake, THR.WebSocket.Session, THR.WebSocket.OfflineStore,
  THR.WebSocket.Message, THR.WebSocket.Server, THR.WebSocket.Client;

type
  { Tipos }
  TWebSocketOpCode = THR.WebSocket.Types.TWebSocketOpCode;
  TWebSocketSessionState = THR.WebSocket.Types.TWebSocketSessionState;
  TWebSocketDeliveryMode = THR.WebSocket.Types.TWebSocketDeliveryMode;
  TWebSocketFrame = THR.WebSocket.Types.TWebSocketFrame;
  TWebSocketOutgoingMessage = THR.WebSocket.Types.TWebSocketOutgoingMessage;
  TWebSocketUtils = THR.WebSocket.Types.TWebSocketUtils;

  { Exceções }
  EWebSocketException = THR.WebSocket.Types.EWebSocketException;
  EWebSocketConfigurationException = THR.WebSocket.Types.EWebSocketConfigurationException;
  EWebSocketHandshakeException = THR.WebSocket.Types.EWebSocketHandshakeException;
  EWebSocketProtocolException = THR.WebSocket.Types.EWebSocketProtocolException;
  EWebSocketNotConnectedException = THR.WebSocket.Types.EWebSocketNotConnectedException;

  { Interfaces do servidor }
  IWebSocketServer = THR.WebSocket.Interfaces.IWebSocketServer;
  IWebSocketSession = THR.WebSocket.Interfaces.IWebSocketSession;
  IWebSocketMessage = THR.WebSocket.Interfaces.IWebSocketMessage;
  IWebSocketOfflineStore = THR.WebSocket.Interfaces.IWebSocketOfflineStore;

  { Eventos do servidor }
  TWebSocketLogEvent = THR.WebSocket.Interfaces.TWebSocketLogEvent;
  TWebSocketServerEvent = THR.WebSocket.Interfaces.TWebSocketServerEvent;
  TWebSocketSessionEvent = THR.WebSocket.Interfaces.TWebSocketSessionEvent;
  TWebSocketTextEvent = THR.WebSocket.Interfaces.TWebSocketTextEvent;
  TWebSocketBinaryEvent = THR.WebSocket.Interfaces.TWebSocketBinaryEvent;
  TWebSocketErrorEvent = THR.WebSocket.Interfaces.TWebSocketErrorEvent;
  TWebSocketAuthorizeEvent = THR.WebSocket.Interfaces.TWebSocketAuthorizeEvent;

  { Implementações }
  TWebSocketServer = THR.WebSocket.Server.TWebSocketServer;
  TWebSocketMemoryOfflineStore = THR.WebSocket.OfflineStore.TWebSocketMemoryOfflineStore;
  TWebSocketFrameCodec = THR.WebSocket.Frame.TWebSocketFrameCodec;
  TWebSocketHandshake = THR.WebSocket.Handshake.TWebSocketHandshake;

  { Cliente }
  IWebSocketClient = THR.WebSocket.Client.IWebSocketClient;
  TWebSocketClient = THR.WebSocket.Client.TWebSocketClient;
  TWebSocketClientEvent = THR.WebSocket.Client.TWebSocketClientEvent;
  TWebSocketClientTextEvent = THR.WebSocket.Client.TWebSocketClientTextEvent;
  TWebSocketClientBinaryEvent = THR.WebSocket.Client.TWebSocketClientBinaryEvent;
  TWebSocketClientErrorEvent = THR.WebSocket.Client.TWebSocketClientErrorEvent;

const
  { Códigos de operação }
  wsoContinuation = THR.WebSocket.Types.wsoContinuation;
  wsoText = THR.WebSocket.Types.wsoText;
  wsoBinary = THR.WebSocket.Types.wsoBinary;
  wsoClose = THR.WebSocket.Types.wsoClose;
  wsoPing = THR.WebSocket.Types.wsoPing;
  wsoPong = THR.WebSocket.Types.wsoPong;

  { Estados de sessão }
  wssConnected = THR.WebSocket.Types.wssConnected;
  wssHandshaking = THR.WebSocket.Types.wssHandshaking;
  wssOpen = THR.WebSocket.Types.wssOpen;
  wssClosing = THR.WebSocket.Types.wssClosing;
  wssClosed = THR.WebSocket.Types.wssClosed;

  { Modos de entrega }
  wsdBroadcast = THR.WebSocket.Types.wsdBroadcast;
  wsdDirect = THR.WebSocket.Types.wsdDirect;

  { Constantes de configuração }
  C_DEFAULT_PORT = THR.WebSocket.Types.C_DEFAULT_PORT;
  C_DEFAULT_PATH = THR.WebSocket.Types.C_DEFAULT_PATH;
  C_TARGET_ALL = THR.WebSocket.Types.C_TARGET_ALL;

implementation

end.
