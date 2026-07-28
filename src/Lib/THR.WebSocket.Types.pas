{*******************************************************************************
  Unit......: THR.WebSocket.Types
  Objetivo..: Tipos, constantes e exceções compartilhados pela biblioteca
              WebSocket ThR.
  Padrão....: ThR - Normas e Padronização de Codificação (Delphi) v4.0.1
*******************************************************************************}
unit THR.WebSocket.Types;

interface

uses
  System.SysUtils, System.Classes, IdGlobal;

type
  { Exceções }
  EWebSocketException = class(Exception);
  EWebSocketConfigurationException = class(EWebSocketException);
  EWebSocketHandshakeException = class(EWebSocketException);
  EWebSocketProtocolException = class(EWebSocketException);
  EWebSocketNotConnectedException = class(EWebSocketException);

  { Códigos de operação definidos pela RFC 6455 }
  TWebSocketOpCode = (
    wsoContinuation = $0,
    wsoText = $1,
    wsoBinary = $2,
    wsoClose = $8,
    wsoPing = $9,
    wsoPong = $A);

  { Estado do ciclo de vida de uma sessão }
  TWebSocketSessionState = (
    wssConnected,
    wssHandshaking,
    wssOpen,
    wssClosing,
    wssClosed);

  { Modo de entrega de uma mensagem de saída }
  TWebSocketDeliveryMode = (
    wsdBroadcast,
    wsdDirect);

  { Quadro (frame) lido ou escrito no canal }
  TWebSocketFrame = record
  strict private
    function GetPayloadLength: Integer;
  public
    Fin: Boolean;
    Masked: Boolean;
    OpCode: TWebSocketOpCode;
    Payload: TIdBytes;
    procedure Clear;
    function AsText: String;
    function IsControlFrame: Boolean;
    property PayloadLength: Integer read GetPayloadLength;
  end;

  { Descritor de uma mensagem de saída, montada pelo construtor fluente }
  TWebSocketOutgoingMessage = record
  public
    Text: String;
    Data: TIdBytes;
    OpCode: TWebSocketOpCode;
    DeliveryMode: TWebSocketDeliveryMode;
    Target: String;
    ExcludeID: String;
    StoreWhenOffline: Boolean;
    class function Create: TWebSocketOutgoingMessage; static;
    function IsBinary: Boolean;
  end;

  { Rotinas utilitárias de apoio (parsing de recurso, query string e cabeçalhos) }
  TWebSocketUtils = class
  strict private
    class function HexValue(const AChar: Char): Integer; static;
  public
    class function URLDecode(const AValue: String): String; static;
    class function ExtractPath(const AResource: String): String; static;
    class function ExtractQuery(const AResource: String): String; static;
    class procedure ParseQuery(const AQuery: String; const AList: TStrings); static;
    class function HeaderName(const ALine: String): String; static;
    class function HeaderValue(const ALine: String): String; static;
    class function GenerateID: String; static;
  end;

const
  C_WEBSOCKET_GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';
  C_WEBSOCKET_VERSION = '13';
  C_DEFAULT_PORT = 8080;
  C_DEFAULT_PATH = '/';
  C_DEFAULT_USER_NAME_PARAM = 'name';
  C_DEFAULT_READ_TIMEOUT = 10;
  C_DEFAULT_IDLE_INTERVAL = 10;
  C_MAX_PAYLOAD_LENGTH = 64 * 1024 * 1024;
  C_MAX_PAYLOAD_LENGTH_7_BITS = 125;
  C_MAX_PAYLOAD_LENGTH_16_BITS = 65535;
  C_PAYLOAD_MARKER_16_BITS = 126;
  C_PAYLOAD_MARKER_64_BITS = 127;
  C_MASK_KEY_LENGTH = 4;
  C_TARGET_ALL = 'ALL';
  C_CRLF = #13#10;

implementation

{ TWebSocketFrame }

procedure TWebSocketFrame.Clear;
begin
  Fin := True;
  Masked := False;
  OpCode := wsoText;
  SetLength(Payload, 0);
end;

function TWebSocketFrame.GetPayloadLength: Integer;
begin
  Result := Length(Payload);
end;

function TWebSocketFrame.AsText: String;
begin
  if PayloadLength = 0 then
    Exit('');

  Result := BytesToString(Payload, IndyTextEncoding_UTF8);
end;

function TWebSocketFrame.IsControlFrame: Boolean;
begin
  Result := OpCode in [wsoClose, wsoPing, wsoPong];
end;

{ TWebSocketOutgoingMessage }

class function TWebSocketOutgoingMessage.Create: TWebSocketOutgoingMessage;
begin
  Result.Text := '';
  SetLength(Result.Data, 0);
  Result.OpCode := wsoText;
  Result.DeliveryMode := wsdBroadcast;
  Result.Target := '';
  Result.ExcludeID := '';
  Result.StoreWhenOffline := False;
end;

function TWebSocketOutgoingMessage.IsBinary: Boolean;
begin
  Result := OpCode = wsoBinary;
end;

{ TWebSocketUtils }

class function TWebSocketUtils.HexValue(const AChar: Char): Integer;
begin
  Result := -1;

  if CharInSet(AChar, ['0'..'9']) then
    Result := Ord(AChar) - Ord('0')
  else
  if CharInSet(AChar, ['a'..'f']) then
    Result := Ord(AChar) - Ord('a') + 10
  else
  if CharInSet(AChar, ['A'..'F']) then
    Result := Ord(AChar) - Ord('A') + 10;
end;

class function TWebSocketUtils.URLDecode(const AValue: String): String;
var
  LBytes: TIdBytes;
  LIndex: Integer;
  LCount: Integer;
  LHigh: Integer;
  LLow: Integer;
begin
  if AValue = '' then
    Exit('');

  SetLength(LBytes, Length(AValue));
  LCount := 0;
  LIndex := 1;

  while LIndex <= Length(AValue) do
  begin
    LHigh := -1;
    LLow := -1;

    if (AValue[LIndex] = '%') and (LIndex + 2 <= Length(AValue)) then
    begin
      LHigh := HexValue(AValue[LIndex + 1]);
      LLow := HexValue(AValue[LIndex + 2]);
    end;

    if (LHigh >= 0) and (LLow >= 0) then
    begin
      LBytes[LCount] := Byte((LHigh shl 4) or LLow);
      Inc(LIndex, 3);
    end
    else
    if AValue[LIndex] = '+' then
    begin
      LBytes[LCount] := Byte(Ord(' '));
      Inc(LIndex);
    end
    else
    begin
      LBytes[LCount] := Byte(Ord(AValue[LIndex]));
      Inc(LIndex);
    end;

    Inc(LCount);
  end;

  SetLength(LBytes, LCount);
  Result := BytesToString(LBytes, IndyTextEncoding_UTF8);
end;

class function TWebSocketUtils.ExtractPath(const AResource: String): String;
var
  LPosition: Integer;
begin
  LPosition := Pos('?', AResource);

  if LPosition = 0 then
    Exit(AResource);

  Result := Copy(AResource, 1, LPosition - 1);
end;

class function TWebSocketUtils.ExtractQuery(const AResource: String): String;
var
  LPosition: Integer;
begin
  LPosition := Pos('?', AResource);

  if LPosition = 0 then
    Exit('');

  Result := Copy(AResource, LPosition + 1, MaxInt);
end;

class procedure TWebSocketUtils.ParseQuery(const AQuery: String; const AList: TStrings);
var
  LPairs: TArray<String>;
  LPair: String;
  LPosition: Integer;
begin
  AList.Clear;

  if AQuery = '' then
    Exit;

  LPairs := AQuery.Split(['&']);

  for LPair in LPairs do
  begin
    LPosition := Pos('=', LPair);

    if LPosition > 0 then
      AList.Values[URLDecode(Copy(LPair, 1, LPosition - 1))] :=
        URLDecode(Copy(LPair, LPosition + 1, MaxInt))
    else
    if LPair <> '' then
      AList.Values[URLDecode(LPair)] := '';
  end;
end;

class function TWebSocketUtils.HeaderName(const ALine: String): String;
var
  LPosition: Integer;
begin
  LPosition := Pos(':', ALine);

  if LPosition = 0 then
    Exit(Trim(ALine));

  Result := Trim(Copy(ALine, 1, LPosition - 1));
end;

class function TWebSocketUtils.HeaderValue(const ALine: String): String;
var
  LPosition: Integer;
begin
  LPosition := Pos(':', ALine);

  if LPosition = 0 then
    Exit('');

  Result := Trim(Copy(ALine, LPosition + 1, MaxInt));
end;

class function TWebSocketUtils.GenerateID: String;
var
  LGuid: TGUID;
begin
  LGuid := TGUID.NewGuid;
  Result := LGuid.ToString.Trim(['{', '}']);
end;

end.
