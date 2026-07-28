{*******************************************************************************
  Unit......: THR.WebSocket.Frame
  Objetivo..: Codificação e decodificação de quadros (frames) WebSocket
              conforme a RFC 6455.
  Padrão....: ThR - Normas e Padronização de Codificação (Delphi) v4.0.1
*******************************************************************************}
unit THR.WebSocket.Frame;

interface

uses
  System.SysUtils, System.Classes, IdGlobal, IdIOHandler,
  THR.WebSocket.Types;

type
  {*****************************************************************************
    TWebSocketFrameCodec
    Responsável exclusivamente pela leitura e escrita de quadros no canal.
  *****************************************************************************}
  TWebSocketFrameCodec = class
  strict private
    class function BuildHeader(const AOpCode: TWebSocketOpCode; const AFinal: Boolean;
      const ALength: Int64; const AMasked: Boolean): TIdBytes; static;
    class function BuildMaskKey: TIdBytes; static;
    class function ApplyMask(const AData: TIdBytes; const AMaskKey: TIdBytes): TIdBytes; static;
    class function ReadPayloadLength(const AIOHandler: TIdIOHandler;
      const AMarker: Byte): Int64; static;
  public
    class function HasPendingData(const AIOHandler: TIdIOHandler;
      const ATimeout: Integer = C_DEFAULT_READ_TIMEOUT): Boolean; static;

    class function TryRead(const AIOHandler: TIdIOHandler;
      out AFrame: TWebSocketFrame;
      const ATimeout: Integer = C_DEFAULT_READ_TIMEOUT): Boolean; static;

    class procedure Write(const AIOHandler: TIdIOHandler; const AData: TIdBytes;
      const AOpCode: TWebSocketOpCode = wsoBinary;
      const AMasked: Boolean = False); overload; static;

    class procedure Write(const AIOHandler: TIdIOHandler; const AText: String;
      const AOpCode: TWebSocketOpCode = wsoText;
      const AMasked: Boolean = False); overload; static;

    class procedure WriteClose(const AIOHandler: TIdIOHandler;
      const ACode: Word = 1000; const AMasked: Boolean = False); static;

    class procedure WritePing(const AIOHandler: TIdIOHandler;
      const AMasked: Boolean = False); static;

    class procedure WritePong(const AIOHandler: TIdIOHandler; const APayload: TIdBytes;
      const AMasked: Boolean = False); static;
  end;

implementation

{ TWebSocketFrameCodec }

class function TWebSocketFrameCodec.BuildMaskKey: TIdBytes;
var
  LIndex: Integer;
begin
  SetLength(Result, C_MASK_KEY_LENGTH);

  for LIndex := 0 to C_MASK_KEY_LENGTH - 1 do
    Result[LIndex] := Byte(Random(256));
end;

class function TWebSocketFrameCodec.ApplyMask(const AData: TIdBytes;
  const AMaskKey: TIdBytes): TIdBytes;
var
  LIndex: Integer;
begin
  SetLength(Result, Length(AData));

  for LIndex := 0 to High(AData) do
    Result[LIndex] := AData[LIndex] xor AMaskKey[LIndex mod C_MASK_KEY_LENGTH];
end;

class function TWebSocketFrameCodec.BuildHeader(const AOpCode: TWebSocketOpCode;
  const AFinal: Boolean; const ALength: Int64; const AMasked: Boolean): TIdBytes;
var
  LFirstByte: Byte;
  LMaskBit: Byte;
  LShift: Integer;
begin
  SetLength(Result, 0);

  LFirstByte := Byte(Ord(AOpCode));

  if AFinal then
    LFirstByte := LFirstByte or $80;

  AppendByte(Result, LFirstByte);

  LMaskBit := 0;

  if AMasked then
    LMaskBit := $80;

  if ALength <= C_MAX_PAYLOAD_LENGTH_7_BITS then
    AppendByte(Result, Byte(ALength) or LMaskBit)
  else
  if ALength <= C_MAX_PAYLOAD_LENGTH_16_BITS then
  begin
    AppendByte(Result, C_PAYLOAD_MARKER_16_BITS or LMaskBit);
    AppendByte(Result, Byte((ALength shr 8) and $FF));
    AppendByte(Result, Byte(ALength and $FF));
  end
  else
  begin
    AppendByte(Result, C_PAYLOAD_MARKER_64_BITS or LMaskBit);

    for LShift := 7 downto 0 do
      AppendByte(Result, Byte((ALength shr (LShift * 8)) and $FF));
  end;
end;

class function TWebSocketFrameCodec.ReadPayloadLength(const AIOHandler: TIdIOHandler;
  const AMarker: Byte): Int64;
begin
  if AMarker = C_PAYLOAD_MARKER_16_BITS then
    Result := AIOHandler.ReadUInt16(True)
  else
  if AMarker = C_PAYLOAD_MARKER_64_BITS then
    Result := Int64(AIOHandler.ReadUInt64(True))
  else
    Result := AMarker;
end;

class function TWebSocketFrameCodec.HasPendingData(const AIOHandler: TIdIOHandler;
  const ATimeout: Integer): Boolean;
begin
  if not AIOHandler.InputBufferIsEmpty then
    Exit(True);

  AIOHandler.CheckForDataOnSource(ATimeout);
  Result := not AIOHandler.InputBufferIsEmpty;
end;

class function TWebSocketFrameCodec.TryRead(const AIOHandler: TIdIOHandler;
  out AFrame: TWebSocketFrame; const ATimeout: Integer): Boolean;
var
  LFirstByte: Byte;
  LSecondByte: Byte;
  LPayloadLength: Int64;
  LMaskKey: TIdBytes;
begin
  AFrame.Clear;
  Result := False;

  if not HasPendingData(AIOHandler, ATimeout) then
    Exit;

  LFirstByte := AIOHandler.ReadByte;
  LSecondByte := AIOHandler.ReadByte;

  AFrame.Fin := (LFirstByte and $80) <> 0;
  AFrame.OpCode := TWebSocketOpCode(LFirstByte and $0F);
  AFrame.Masked := (LSecondByte and $80) <> 0;

  LPayloadLength := ReadPayloadLength(AIOHandler, LSecondByte and $7F);

  if LPayloadLength > C_MAX_PAYLOAD_LENGTH then
    raise EWebSocketProtocolException.CreateFmt(
      'Payload de %d bytes excede o limite suportado de %d bytes.',
      [LPayloadLength, C_MAX_PAYLOAD_LENGTH]);

  if AFrame.Masked then
    AIOHandler.ReadBytes(LMaskKey, C_MASK_KEY_LENGTH, False);

  if LPayloadLength > 0 then
  begin
    AIOHandler.ReadBytes(AFrame.Payload, Integer(LPayloadLength), False);

    if AFrame.Masked then
      AFrame.Payload := ApplyMask(AFrame.Payload, LMaskKey);
  end;

  Result := True;
end;

class procedure TWebSocketFrameCodec.Write(const AIOHandler: TIdIOHandler;
  const AData: TIdBytes; const AOpCode: TWebSocketOpCode; const AMasked: Boolean);
var
  LBuffer: TIdBytes;
  LMaskKey: TIdBytes;
begin
  LBuffer := BuildHeader(AOpCode, True, Length(AData), AMasked);

  if AMasked then
  begin
    LMaskKey := BuildMaskKey;
    AppendBytes(LBuffer, LMaskKey);
    AppendBytes(LBuffer, ApplyMask(AData, LMaskKey));
  end
  else
    AppendBytes(LBuffer, AData);

  AIOHandler.Write(LBuffer);
end;

class procedure TWebSocketFrameCodec.Write(const AIOHandler: TIdIOHandler;
  const AText: String; const AOpCode: TWebSocketOpCode; const AMasked: Boolean);
begin
  Write(AIOHandler, ToBytes(AText, IndyTextEncoding_UTF8), AOpCode, AMasked);
end;

class procedure TWebSocketFrameCodec.WriteClose(const AIOHandler: TIdIOHandler;
  const ACode: Word; const AMasked: Boolean);
var
  LPayload: TIdBytes;
begin
  SetLength(LPayload, 0);
  AppendByte(LPayload, Byte((ACode shr 8) and $FF));
  AppendByte(LPayload, Byte(ACode and $FF));
  Write(AIOHandler, LPayload, wsoClose, AMasked);
end;

class procedure TWebSocketFrameCodec.WritePing(const AIOHandler: TIdIOHandler;
  const AMasked: Boolean);
var
  LPayload: TIdBytes;
begin
  SetLength(LPayload, 0);
  Write(AIOHandler, LPayload, wsoPing, AMasked);
end;

class procedure TWebSocketFrameCodec.WritePong(const AIOHandler: TIdIOHandler;
  const APayload: TIdBytes; const AMasked: Boolean);
begin
  Write(AIOHandler, APayload, wsoPong, AMasked);
end;

initialization
  Randomize;

end.
