{*******************************************************************************
  Unit......: THR.WebSocket.Handshake
  Objetivo..: Negociação do handshake HTTP de upgrade para WebSocket
              (lado servidor e lado cliente), conforme a RFC 6455.
  Padrão....: ThR - Normas e Padronização de Codificação (Delphi) v4.0.1
*******************************************************************************}
unit THR.WebSocket.Handshake;

interface

uses
  System.SysUtils, System.Classes, System.StrUtils,
  IdGlobal, IdIOHandler, IdHash, IdHashSHA, IdCoderMIME,
  THR.WebSocket.Types;

type
  { Requisição de upgrade recebida do cliente }
  TWebSocketHandshakeRequest = record
  public
    Method: String;
    Resource: String;
    Path: String;
    Query: String;
    Host: String;
    Key: String;
    Version: String;
    Protocol: String;
    IsUpgrade: Boolean;
    IsWebSocket: Boolean;
    procedure Clear;
    function IsValid: Boolean;
  end;

  {*****************************************************************************
    TWebSocketHandshake
    Concentra as rotinas de handshake. Nenhum estado é mantido.
  *****************************************************************************}
  TWebSocketHandshake = class
  strict private
    class function BuildAcceptResponse(const AKey: String; const AProtocol: String): String; static;
  public
    class function ComputeAcceptKey(const AKey: String): String; static;
    class function GenerateKey: String; static;

    { Lado servidor }
    class function TryReadRequest(const AIOHandler: TIdIOHandler;
      out ARequest: TWebSocketHandshakeRequest): Boolean; static;
    class procedure Accept(const AIOHandler: TIdIOHandler;
      const ARequest: TWebSocketHandshakeRequest); static;
    class procedure Reject(const AIOHandler: TIdIOHandler;
      const AStatus: String = '400 Bad Request'); static;

    { Lado cliente }
    class procedure PerformClientHandshake(const AIOHandler: TIdIOHandler;
      const AHost: String; const AResource: String); static;
  end;

implementation

{ TWebSocketHandshakeRequest }

procedure TWebSocketHandshakeRequest.Clear;
begin
  Method := '';
  Resource := '';
  Path := '';
  Query := '';
  Host := '';
  Key := '';
  Version := '';
  Protocol := '';
  IsUpgrade := False;
  IsWebSocket := False;
end;

function TWebSocketHandshakeRequest.IsValid: Boolean;
begin
  Result := SameText(Method, 'GET')
    and IsUpgrade
    and IsWebSocket
    and (Key <> '');
end;

{ TWebSocketHandshake }

class function TWebSocketHandshake.ComputeAcceptKey(const AKey: String): String;
var
  LHash: TIdHashSHA1;
begin
  LHash := TIdHashSHA1.Create;
  try
    Result := TIdEncoderMIME.EncodeBytes(LHash.HashString(AKey + C_WEBSOCKET_GUID));
  finally
    LHash.Free;
  end;
end;

class function TWebSocketHandshake.GenerateKey: String;
var
  LBytes: TIdBytes;
  LIndex: Integer;
begin
  SetLength(LBytes, 16);

  for LIndex := 0 to High(LBytes) do
    LBytes[LIndex] := Byte(Random(256));

  Result := TIdEncoderMIME.EncodeBytes(LBytes);
end;

class function TWebSocketHandshake.TryReadRequest(const AIOHandler: TIdIOHandler;
  out ARequest: TWebSocketHandshakeRequest): Boolean;
var
  LLine: String;
  LName: String;
  LValue: String;
  LPosition: Integer;
begin
  ARequest.Clear;

  LLine := AIOHandler.ReadLn;

  if LLine = '' then
    Exit(False);

  { Primeira linha: GET /recurso?query HTTP/1.1 }
  LPosition := Pos(' ', LLine);

  if LPosition = 0 then
    Exit(False);

  ARequest.Method := Copy(LLine, 1, LPosition - 1);
  LValue := Trim(Copy(LLine, LPosition + 1, MaxInt));
  LPosition := Pos(' ', LValue);

  if LPosition > 0 then
    ARequest.Resource := Copy(LValue, 1, LPosition - 1)
  else
    ARequest.Resource := LValue;

  ARequest.Path := TWebSocketUtils.ExtractPath(ARequest.Resource);
  ARequest.Query := TWebSocketUtils.ExtractQuery(ARequest.Resource);

  { Cabeçalhos, até a linha em branco que encerra a seção }
  LLine := AIOHandler.ReadLn;

  while LLine <> '' do
  begin
    LName := TWebSocketUtils.HeaderName(LLine);
    LValue := TWebSocketUtils.HeaderValue(LLine);

    if SameText(LName, 'Host') then
      ARequest.Host := LValue
    else
    if SameText(LName, 'Sec-WebSocket-Key') then
      ARequest.Key := LValue
    else
    if SameText(LName, 'Sec-WebSocket-Version') then
      ARequest.Version := LValue
    else
    if SameText(LName, 'Sec-WebSocket-Protocol') then
      ARequest.Protocol := LValue
    else
    if SameText(LName, 'Connection') then
      ARequest.IsUpgrade := ContainsText(LValue, 'Upgrade')
    else
    if SameText(LName, 'Upgrade') then
      ARequest.IsWebSocket := SameText(LValue, 'websocket');

    LLine := AIOHandler.ReadLn;
  end;

  Result := ARequest.IsValid;
end;

class function TWebSocketHandshake.BuildAcceptResponse(const AKey: String;
  const AProtocol: String): String;
var
  LResponse: TStringBuilder;
begin
  LResponse := TStringBuilder.Create;
  try
    LResponse
      .Append('HTTP/1.1 101 Switching Protocols').Append(C_CRLF)
      .Append('Upgrade: websocket').Append(C_CRLF)
      .Append('Connection: Upgrade').Append(C_CRLF)
      .Append('Sec-WebSocket-Accept: ').Append(ComputeAcceptKey(AKey)).Append(C_CRLF);

    if AProtocol <> '' then
      LResponse
        .Append('Sec-WebSocket-Protocol: ')
        .Append(AProtocol)
        .Append(C_CRLF);

    Result := LResponse.Append(C_CRLF).ToString;
  finally
    LResponse.Free;
  end;
end;

class procedure TWebSocketHandshake.Accept(const AIOHandler: TIdIOHandler;
  const ARequest: TWebSocketHandshakeRequest);
begin
  if not ARequest.IsValid then
    raise EWebSocketHandshakeException.Create('Requisição de handshake inválida.');

  AIOHandler.Write(BuildAcceptResponse(ARequest.Key, ARequest.Protocol));
end;

class procedure TWebSocketHandshake.Reject(const AIOHandler: TIdIOHandler;
  const AStatus: String);
var
  LResponse: TStringBuilder;
begin
  LResponse := TStringBuilder.Create;
  try
    AIOHandler.Write(
      LResponse
        .Append('HTTP/1.1 ').Append(AStatus).Append(C_CRLF)
        .Append('Connection: close').Append(C_CRLF)
        .Append('Content-Length: 0').Append(C_CRLF)
        .Append(C_CRLF)
        .ToString);
  finally
    LResponse.Free;
  end;
end;

class procedure TWebSocketHandshake.PerformClientHandshake(const AIOHandler: TIdIOHandler;
  const AHost: String; const AResource: String);
var
  LKey: String;
  LRequest: TStringBuilder;
  LLine: String;
  LStatusLine: String;
  LAccept: String;
begin
  LKey := GenerateKey;
  LRequest := TStringBuilder.Create;
  try
    AIOHandler.Write(
      LRequest
        .Append('GET ').Append(AResource).Append(' HTTP/1.1').Append(C_CRLF)
        .Append('Host: ').Append(AHost).Append(C_CRLF)
        .Append('Upgrade: websocket').Append(C_CRLF)
        .Append('Connection: Upgrade').Append(C_CRLF)
        .Append('Sec-WebSocket-Key: ').Append(LKey).Append(C_CRLF)
        .Append('Sec-WebSocket-Version: ').Append(C_WEBSOCKET_VERSION).Append(C_CRLF)
        .Append(C_CRLF)
        .ToString);
  finally
    LRequest.Free;
  end;

  LStatusLine := AIOHandler.ReadLn;
  LAccept := '';
  LLine := AIOHandler.ReadLn;

  while LLine <> '' do
  begin
    if SameText(TWebSocketUtils.HeaderName(LLine), 'Sec-WebSocket-Accept') then
      LAccept := TWebSocketUtils.HeaderValue(LLine);

    LLine := AIOHandler.ReadLn;
  end;

  if not ContainsText(LStatusLine, '101') then
    raise EWebSocketHandshakeException.CreateFmt(
      'Servidor recusou o upgrade para WebSocket: %s', [LStatusLine]);

  if LAccept <> ComputeAcceptKey(LKey) then
    raise EWebSocketHandshakeException.Create(
      'Sec-WebSocket-Accept inválido: handshake não confirmado pelo servidor.');
end;

initialization
  Randomize;

end.
