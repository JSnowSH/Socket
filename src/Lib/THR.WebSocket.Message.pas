{*******************************************************************************
  Unit......: THR.WebSocket.Message
  Objetivo..: Construtor fluente de mensagens de saída. Acumula o conteúdo e
              os critérios de entrega, delegando a transmissão ao dispatcher
              do servidor no momento do Send.
  Padrão....: ThR - Normas e Padronização de Codificação (Delphi) v4.0.1
*******************************************************************************}
unit THR.WebSocket.Message;

interface

uses
  System.SysUtils, System.JSON, IdGlobal,
  THR.WebSocket.Types, THR.WebSocket.Interfaces;

type
  {*****************************************************************************
    TWebSocketMessage
    Implementa IWebSocketMessage.
  *****************************************************************************}
  TWebSocketMessage = class(TInterfacedObject, IWebSocketMessage)
  strict private
    FDispatcher: IWebSocketDispatcher;
    FMessage: TWebSocketOutgoingMessage;
  public
    constructor Create(const ADispatcher: IWebSocketDispatcher);
    class function New(const ADispatcher: IWebSocketDispatcher): IWebSocketMessage;

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

implementation

{ TWebSocketMessage }

constructor TWebSocketMessage.Create(const ADispatcher: IWebSocketDispatcher);
begin
  inherited Create;

  if ADispatcher = nil then
    raise EWebSocketConfigurationException.Create(
      'Dispatcher não informado para a construção da mensagem.');

  FDispatcher := ADispatcher;
  FMessage := TWebSocketOutgoingMessage.Create;
end;

class function TWebSocketMessage.New(const ADispatcher: IWebSocketDispatcher): IWebSocketMessage;
begin
  Result := Create(ADispatcher);
end;

function TWebSocketMessage.Text(const AValue: String): IWebSocketMessage;
begin
  Result := Self;
  FMessage.Text := AValue;
  FMessage.OpCode := wsoText;
end;

function TWebSocketMessage.JSON(const AValue: TJSONObject): IWebSocketMessage;
begin
  Result := Self;

  if AValue = nil then
    Exit;

  FMessage.Text := AValue.ToJSON;
  FMessage.OpCode := wsoText;
end;

function TWebSocketMessage.Binary(const AValue: TIdBytes): IWebSocketMessage;
begin
  Result := Self;
  FMessage.Data := AValue;
  FMessage.OpCode := wsoBinary;
end;

function TWebSocketMessage.&To(const ATarget: String): IWebSocketMessage;
begin
  Result := Self;

  if SameText(ATarget, C_TARGET_ALL) or (ATarget = '') then
    Exit(ToAll);

  FMessage.Target := ATarget;
  FMessage.DeliveryMode := wsdDirect;
end;

function TWebSocketMessage.Target(const ATarget: String): IWebSocketMessage;
begin
  Result := &To(ATarget);
end;

function TWebSocketMessage.ToAll: IWebSocketMessage;
begin
  Result := Self;
  FMessage.Target := '';
  FMessage.DeliveryMode := wsdBroadcast;
end;

function TWebSocketMessage.Excluding(const ASessionID: String): IWebSocketMessage;
begin
  Result := Self;
  FMessage.ExcludeID := ASessionID;
end;

function TWebSocketMessage.StoreWhenOffline(const AValue: Boolean): IWebSocketMessage;
begin
  Result := Self;
  FMessage.StoreWhenOffline := AValue;
end;

function TWebSocketMessage.Send: Integer;
begin
  Result := FDispatcher.DispatchMessage(FMessage);
end;

end.
