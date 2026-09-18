{*******************************************************************************
  Unit......: THR.WebSocket.Client
  Objetivo..: Cliente WebSocket com API fluente, construído sobre o
              TIdTCPClient da Indy. Consome o servidor THR.WebSocket.Server.
  Padrão....: ThR - Normas e Padronização de Codificação (Delphi) v4.0.1
*******************************************************************************}
unit THR.WebSocket.Client;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.SyncObjs, System.NetEncoding,
  IdTCPClient, IdGlobal, IdIOHandler, IdException, IdSSLOpenSSL,
  THR.WebSocket.Types, THR.WebSocket.Frame, THR.WebSocket.Handshake;

type
  IWebSocketClient = interface;

  TWebSocketClientEvent = reference to procedure(const AClient: IWebSocketClient);
  TWebSocketClientTextEvent = reference to procedure(const AClient: IWebSocketClient;
    const AMessage: String);
  TWebSocketClientBinaryEvent = reference to procedure(const AClient: IWebSocketClient;
    const AData: TIdBytes);
  TWebSocketClientErrorEvent = reference to procedure(const AClient: IWebSocketClient;
    const AException: Exception);

  {*****************************************************************************
    IWebSocketClient
    Contrato fluente do cliente.

    Exemplo:
      TWebSocketClient
        .New
        .Host('127.0.0.1')
        .Port(8080)
        .Resource('/chat')
        .Parameter('name', 'UserA')
        .SynchronizeEvents
        .OnMessage(
          procedure(const AClient: IWebSocketClient; const AMessage: String)
          begin
            MemoLog.Lines.Add(AMessage);
          end)
        .Connect;
  *****************************************************************************}
  IWebSocketClient = interface
    ['{7E5D1A46-3F92-4C08-B57D-2A64E9013B8F}']
    { Configuração }
    function Host(const AValue: String): IWebSocketClient;
    function Port(const AValue: Word): IWebSocketClient;
    function Resource(const AValue: String): IWebSocketClient;
    function Parameter(const AName: String; const AValue: String): IWebSocketClient;
    function ConnectTimeout(const AValue: Integer): IWebSocketClient;
    function ReadTimeout(const AValue: Integer): IWebSocketClient;
    function SynchronizeEvents(const AValue: Boolean = True): IWebSocketClient;
    function ReplyPingWithPong(const AValue: Boolean = True): IWebSocketClient;

    { Ativa TLS (wss://) na conexao, usando IdSSLOpenSSL. Precisa das DLLs
      OpenSSL disponiveis para o processo. }
    function UseSSL(const AValue: Boolean = True): IWebSocketClient;

    { Eventos }
    function OnConnected(const AEvent: TWebSocketClientEvent): IWebSocketClient;
    function OnDisconnected(const AEvent: TWebSocketClientEvent): IWebSocketClient;
    function OnMessage(const AEvent: TWebSocketClientTextEvent): IWebSocketClient;
    function OnBinary(const AEvent: TWebSocketClientBinaryEvent): IWebSocketClient;
    function OnError(const AEvent: TWebSocketClientErrorEvent): IWebSocketClient;
    function OnLog(const AEvent: TWebSocketClientTextEvent): IWebSocketClient;

    { Controle }
    function Connect: IWebSocketClient;
    function Disconnect: IWebSocketClient;
    function IsConnected: Boolean;

    { Envio }
    function Send(const AText: String): IWebSocketClient; overload;
    function Send(const AJSON: TJSONObject): IWebSocketClient; overload;
    function SendBinary(const AData: TIdBytes): IWebSocketClient;
    function SendTo(const ATarget: String; const AText: String): IWebSocketClient;
    function Ping: IWebSocketClient;
  end;

  {*****************************************************************************
    TWebSocketClient
    Implementa IWebSocketClient. A leitura acontece em thread própria; os
    eventos podem ser sincronizados com a thread principal (SynchronizeEvents),
    o que é obrigatório quando o consumidor atualiza controles visuais.
  *****************************************************************************}
  TWebSocketClient = class(TInterfacedObject, IWebSocketClient)
  strict private
  type
    TReaderThread = class(TThread)
    strict private
      FOwner: TWebSocketClient;
    strict protected
      procedure Execute; override;
    public
      constructor Create(const AOwner: TWebSocketClient);
    end;

  strict private
    FClient: TIdTCPClient;
    FReader: TReaderThread;
    FParameters: TStringList;
    FLock: TCriticalSection;
    FHost: String;
    FPort: Word;
    FResource: String;
    FReadTimeout: Integer;
    FSynchronizeEvents: Boolean;
    FReplyPingWithPong: Boolean;
    FUseSSL: Boolean;
    FSSLHandler: TIdSSLIOHandlerSocketOpenSSL;

    FOnConnected: TWebSocketClientEvent;
    FOnDisconnected: TWebSocketClientEvent;
    FOnMessage: TWebSocketClientTextEvent;
    FOnBinary: TWebSocketClientBinaryEvent;
    FOnError: TWebSocketClientErrorEvent;
    FOnLog: TWebSocketClientTextEvent;

    function BuildResource: String;
    procedure Publish(const AProcedure: TProc);
    procedure Log(const AMessage: String);
    procedure NotifyError(const AException: Exception);
    procedure WriteFrame(const AData: TIdBytes; const AOpCode: TWebSocketOpCode);
    procedure ReadNextFrame;
    procedure StopReader;
  public
    constructor Create;
    destructor Destroy; override;
    class function New: IWebSocketClient;

    { Configuração }
    function Host(const AValue: String): IWebSocketClient;
    function Port(const AValue: Word): IWebSocketClient;
    function Resource(const AValue: String): IWebSocketClient;
    function Parameter(const AName: String; const AValue: String): IWebSocketClient;
    function ConnectTimeout(const AValue: Integer): IWebSocketClient;
    function ReadTimeout(const AValue: Integer): IWebSocketClient;
    function SynchronizeEvents(const AValue: Boolean = True): IWebSocketClient;
    function ReplyPingWithPong(const AValue: Boolean = True): IWebSocketClient;

    { Ativa TLS (wss://) na conexao, usando IdSSLOpenSSL. Precisa das DLLs
      OpenSSL disponiveis para o processo. }
    function UseSSL(const AValue: Boolean = True): IWebSocketClient;

    { Eventos }
    function OnConnected(const AEvent: TWebSocketClientEvent): IWebSocketClient;
    function OnDisconnected(const AEvent: TWebSocketClientEvent): IWebSocketClient;
    function OnMessage(const AEvent: TWebSocketClientTextEvent): IWebSocketClient;
    function OnBinary(const AEvent: TWebSocketClientBinaryEvent): IWebSocketClient;
    function OnError(const AEvent: TWebSocketClientErrorEvent): IWebSocketClient;
    function OnLog(const AEvent: TWebSocketClientTextEvent): IWebSocketClient;

    { Controle }
    function Connect: IWebSocketClient;
    function Disconnect: IWebSocketClient;
    function IsConnected: Boolean;

    { Envio }
    function Send(const AText: String): IWebSocketClient; overload;
    function Send(const AJSON: TJSONObject): IWebSocketClient; overload;
    function SendBinary(const AData: TIdBytes): IWebSocketClient;
    function SendTo(const ATarget: String; const AText: String): IWebSocketClient;
    function Ping: IWebSocketClient;
  end;

implementation

{ TWebSocketClient.TReaderThread }

constructor TWebSocketClient.TReaderThread.Create(const AOwner: TWebSocketClient);
begin
  inherited Create(True);
  FOwner := AOwner;
  FreeOnTerminate := False;
end;

procedure TWebSocketClient.TReaderThread.Execute;
begin
  while (not Terminated) and FOwner.IsConnected do
  begin
    try
      FOwner.ReadNextFrame;
    except
      on E: EIdException do
        Terminate;
      on E: Exception do
      begin
        FOwner.NotifyError(E);
        Terminate;
      end;
    end;
  end;

  FOwner.Publish(
    procedure
    begin
      if Assigned(FOwner.FOnDisconnected) then
        FOwner.FOnDisconnected(FOwner);
    end);
end;

{ TWebSocketClient }

constructor TWebSocketClient.Create;
begin
  inherited Create;

  FHost := '127.0.0.1';
  FPort := C_DEFAULT_PORT;
  FResource := C_DEFAULT_PATH;
  FReadTimeout := C_DEFAULT_READ_TIMEOUT;
  FSynchronizeEvents := False;
  FReplyPingWithPong := True;
  FUseSSL := False;

  FParameters := TStringList.Create;
  FLock := TCriticalSection.Create;
  FClient := TIdTCPClient.Create(nil);
  FClient.ConnectTimeout := 5000;
end;

destructor TWebSocketClient.Destroy;
begin
  StopReader;

  if FClient.Connected then
    FClient.Disconnect;

  FClient.Free;
  FSSLHandler.Free;
  FParameters.Free;
  FLock.Free;
  inherited;
end;

class function TWebSocketClient.New: IWebSocketClient;
begin
  Result := Create;
end;

{ Rotinas internas }

function TWebSocketClient.BuildResource: String;
var
  LIndex: Integer;
  LQuery: String;
begin
  Result := FResource;

  if FParameters.Count = 0 then
    Exit;

  LQuery := '';

  for LIndex := 0 to FParameters.Count - 1 do
  begin
    if LQuery <> '' then
      LQuery := LQuery + '&';

    LQuery := LQuery + TNetEncoding.URL.Encode(FParameters.Names[LIndex]) + '=' +
      TNetEncoding.URL.Encode(FParameters.ValueFromIndex[LIndex]);
  end;

  if Pos('?', Result) > 0 then
    Result := Result + '&' + LQuery
  else
    Result := Result + '?' + LQuery;
end;

procedure TWebSocketClient.Publish(const AProcedure: TProc);
begin
  if not Assigned(AProcedure) then
    Exit;

  if FSynchronizeEvents and (TThread.CurrentThread.ThreadID <> MainThreadID) then
    TThread.Queue(nil,
      procedure
      begin
        AProcedure();
      end)
  else
    AProcedure();
end;

procedure TWebSocketClient.Log(const AMessage: String);
begin
  Publish(
    procedure
    begin
      if Assigned(FOnLog) then
        FOnLog(Self, AMessage);
    end);
end;

procedure TWebSocketClient.NotifyError(const AException: Exception);
var
  LMessage: String;
  LClass: String;
begin
  LMessage := AException.Message;
  LClass := AException.ClassName;

  Publish(
    procedure
    var
      LError: Exception;
    begin
      if not Assigned(FOnError) then
      begin
        Log(Format('%s: %s', [LClass, LMessage]));
        Exit;
      end;

      LError := EWebSocketException.CreateFmt('%s: %s', [LClass, LMessage]);
      try
        FOnError(Self, LError);
      finally
        LError.Free;
      end;
    end);
end;

procedure TWebSocketClient.ReadNextFrame;
var
  LFrame: TWebSocketFrame;
  LText: String;
  LPayload: TIdBytes;
  LOpCode: TWebSocketOpCode;
  LHasFrame: Boolean;
begin
  LHasFrame := False;

  FLock.Enter;
  try
    if FClient.Connected then
      LHasFrame := TWebSocketFrameCodec.TryRead(FClient.IOHandler, LFrame, FReadTimeout);
  finally
    FLock.Leave;
  end;

  if not LHasFrame then
    Exit;

  LOpCode := LFrame.OpCode;
  LPayload := LFrame.Payload;

  case LOpCode of
    wsoText:
      begin
        LText := BytesToString(LPayload, IndyTextEncoding_UTF8);

        Publish(
          procedure
          begin
            if Assigned(FOnMessage) then
              FOnMessage(Self, LText);
          end);
      end;

    wsoBinary:
      Publish(
        procedure
        begin
          if Assigned(FOnBinary) then
            FOnBinary(Self, LPayload);
        end);

    wsoClose:
      begin
        Log('Servidor encerrou a conexão.');
        Disconnect;
      end;

    wsoPing:
      if FReplyPingWithPong then
        WriteFrame(LPayload, wsoPong);
  end;
end;

procedure TWebSocketClient.WriteFrame(const AData: TIdBytes;
  const AOpCode: TWebSocketOpCode);
begin
  if not IsConnected then
    raise EWebSocketNotConnectedException.Create('Cliente WebSocket não está conectado.');

  FLock.Enter;
  try
    TWebSocketFrameCodec.Write(FClient.IOHandler, AData, AOpCode, True);
  finally
    FLock.Leave;
  end;
end;

procedure TWebSocketClient.StopReader;
begin
  if FReader = nil then
    Exit;

  FReader.Terminate;

  { Quando a propria thread de leitura solicita a parada (quadro Close recebido
    do servidor), aguardar por si mesma provocaria deadlock. Nesse caso a
    instancia da thread e liberada pelo destrutor. }
  if TThread.Current.ThreadID = FReader.ThreadID then
    Exit;

  FReader.WaitFor;
  FReader.Free;
  FReader := nil;
end;

{ Configuração }

function TWebSocketClient.Host(const AValue: String): IWebSocketClient;
begin
  Result := Self;
  FHost := AValue;
end;

function TWebSocketClient.Port(const AValue: Word): IWebSocketClient;
begin
  Result := Self;
  FPort := AValue;
end;

function TWebSocketClient.Resource(const AValue: String): IWebSocketClient;
begin
  Result := Self;

  if AValue = '' then
    FResource := C_DEFAULT_PATH
  else
    FResource := AValue;
end;

function TWebSocketClient.Parameter(const AName: String;
  const AValue: String): IWebSocketClient;
begin
  Result := Self;

  if AName = '' then
    Exit;

  FParameters.Values[AName] := AValue;
end;

function TWebSocketClient.ConnectTimeout(const AValue: Integer): IWebSocketClient;
begin
  Result := Self;
  FClient.ConnectTimeout := AValue;
end;

function TWebSocketClient.ReadTimeout(const AValue: Integer): IWebSocketClient;
begin
  Result := Self;
  FReadTimeout := AValue;
end;

function TWebSocketClient.SynchronizeEvents(const AValue: Boolean): IWebSocketClient;
begin
  Result := Self;
  FSynchronizeEvents := AValue;
end;

function TWebSocketClient.ReplyPingWithPong(const AValue: Boolean): IWebSocketClient;
begin
  Result := Self;
  FReplyPingWithPong := AValue;
end;

function TWebSocketClient.UseSSL(const AValue: Boolean): IWebSocketClient;
begin
  Result := Self;
  FUseSSL := AValue;
end;

{ Eventos }

function TWebSocketClient.OnConnected(const AEvent: TWebSocketClientEvent): IWebSocketClient;
begin
  Result := Self;
  FOnConnected := AEvent;
end;

function TWebSocketClient.OnDisconnected(const AEvent: TWebSocketClientEvent): IWebSocketClient;
begin
  Result := Self;
  FOnDisconnected := AEvent;
end;

function TWebSocketClient.OnMessage(const AEvent: TWebSocketClientTextEvent): IWebSocketClient;
begin
  Result := Self;
  FOnMessage := AEvent;
end;

function TWebSocketClient.OnBinary(const AEvent: TWebSocketClientBinaryEvent): IWebSocketClient;
begin
  Result := Self;
  FOnBinary := AEvent;
end;

function TWebSocketClient.OnError(const AEvent: TWebSocketClientErrorEvent): IWebSocketClient;
begin
  Result := Self;
  FOnError := AEvent;
end;

function TWebSocketClient.OnLog(const AEvent: TWebSocketClientTextEvent): IWebSocketClient;
begin
  Result := Self;
  FOnLog := AEvent;
end;

{ Controle }

function TWebSocketClient.Connect: IWebSocketClient;
var
  LEsquema: String;
begin
  Result := Self;

  if IsConnected then
    Exit;

  StopReader;

  FClient.Host := FHost;
  FClient.Port := FPort;

  if FUseSSL then
  begin
    if FSSLHandler = nil then
      FSSLHandler := TIdSSLIOHandlerSocketOpenSSL.Create(nil);

    FSSLHandler.SSLOptions.Method := sslvTLSv1_2;
    FSSLHandler.SSLOptions.Mode := sslmClient;
    FSSLHandler.SSLOptions.VerifyMode := [];
    FSSLHandler.SSLOptions.VerifyDepth := 0;
    FClient.IOHandler := FSSLHandler;
  end
  else
    FClient.IOHandler := nil;

  FLock.Enter;
  try
    FClient.Connect;

    if FUseSSL then
      TIdSSLIOHandlerSocketOpenSSL(FClient.IOHandler).PassThrough := False;

    TWebSocketHandshake.PerformClientHandshake(FClient.IOHandler, FHost, BuildResource);
  finally
    FLock.Leave;
  end;

  if FUseSSL then
    LEsquema := 'wss'
  else
    LEsquema := 'ws';

  Log(Format('Conectado a %s://%s:%d%s', [LEsquema, FHost, FPort, BuildResource]));

  FReader := TReaderThread.Create(Self);
  FReader.Start;

  Publish(
    procedure
    begin
      if Assigned(FOnConnected) then
        FOnConnected(Self);
    end);
end;

function TWebSocketClient.Disconnect: IWebSocketClient;
begin
  Result := Self;

  if not FClient.Connected then
    Exit;

  { Interrompe a leitura antes de fechar, evitando concorrencia pelo canal. }
  StopReader;

  FLock.Enter;
  try
    try
      TWebSocketFrameCodec.WriteClose(FClient.IOHandler, 1000, True);
    except
      on E: Exception do
        Log('Falha ao enviar o quadro de fechamento: ' + E.Message);
    end;
  finally
    FLock.Leave;
  end;

  FClient.Disconnect;
  Log('Desconectado.');
end;

function TWebSocketClient.IsConnected: Boolean;
begin
  Result := FClient.Connected;
end;

{ Envio }

function TWebSocketClient.Send(const AText: String): IWebSocketClient;
begin
  Result := Self;
  WriteFrame(ToBytes(AText, IndyTextEncoding_UTF8), wsoText);
end;

function TWebSocketClient.Send(const AJSON: TJSONObject): IWebSocketClient;
begin
  Result := Self;

  if AJSON = nil then
    Exit;

  Send(AJSON.ToJSON);
end;

function TWebSocketClient.SendBinary(const AData: TIdBytes): IWebSocketClient;
begin
  Result := Self;
  WriteFrame(AData, wsoBinary);
end;

function TWebSocketClient.SendTo(const ATarget: String;
  const AText: String): IWebSocketClient;
var
  LJSON: TJSONObject;
begin
  Result := Self;
  LJSON := TJSONObject.Create;
  try
    LJSON
      .AddPair('to', ATarget)
      .AddPair('msg', AText);
    Send(LJSON);
  finally
    LJSON.Free;
  end;
end;

function TWebSocketClient.Ping: IWebSocketClient;
var
  LEmpty: TIdBytes;
begin
  Result := Self;
  SetLength(LEmpty, 0);
  WriteFrame(LEmpty, wsoPing);
end;

end.
