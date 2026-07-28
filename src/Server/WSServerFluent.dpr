{*******************************************************************************
  Programa..: WSServerFluent
  Objetivo..: Exemplo de uso da biblioteca THR.WebSocket. Reproduz o servidor
              de chat original (broadcast, envio direto e mensagens offline)
              utilizando exclusivamente a API fluente.
  Padrão....: ThR - Normas e Padronização de Codificação (Delphi) v4.0.1
*******************************************************************************}
program WSServerFluent;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  THR.WebSocket.Types in '..\Lib\THR.WebSocket.Types.pas',
  THR.WebSocket.Interfaces in '..\Lib\THR.WebSocket.Interfaces.pas',
  THR.WebSocket.Frame in '..\Lib\THR.WebSocket.Frame.pas',
  THR.WebSocket.Handshake in '..\Lib\THR.WebSocket.Handshake.pas',
  THR.WebSocket.Session in '..\Lib\THR.WebSocket.Session.pas',
  THR.WebSocket.OfflineStore in '..\Lib\THR.WebSocket.OfflineStore.pas',
  THR.WebSocket.Message in '..\Lib\THR.WebSocket.Message.pas',
  THR.WebSocket.Server in '..\Lib\THR.WebSocket.Server.pas',
  THR.WebSocket.Client in '..\Lib\THR.WebSocket.Client.pas',
  THR.WebSocket in '..\Lib\THR.WebSocket.pas';

  { Encaminha a mensagem recebida conforme o campo "to" do protocolo JSON:
    ALL (ou ausente) faz broadcast; qualquer outro valor entrega direto. }
procedure RouteMessage(const AServer: IWebSocketServer;
  const ASession: IWebSocketSession; const AMessage: String);
var
  LJSON: TJSONObject;
  LTarget: String;
  LDelivered: Integer;
begin
  LTarget := C_TARGET_ALL;
  LJSON := TJSONObject.ParseJSONValue(AMessage) as TJSONObject;
  try
    if Assigned(LJSON) then
      LJSON.TryGetValue<String>('to', LTarget);

    if (LTarget = '') or SameText(LTarget, C_TARGET_ALL) then
      LDelivered := AServer
        .NewMessage
        .Text(AMessage)
        .ToAll
        .Excluding(ASession.ID)
        .Send
    else
      LDelivered := AServer
        .NewMessage
        .Text(AMessage)
        .&To(LTarget)
        .StoreWhenOffline
        .Send;

    Writeln(Format('  -> entregue a %d destinatário(s).', [LDelivered]));
  finally
    LJSON.Free;
  end;
end;

procedure Run;
var
  LServer: IWebSocketServer;
begin
  LServer := TWebSocketServer
    .New
    .Port(8080)
    .Path('/chat')
    .UserNameParameter('name')
    .KeepOfflineMessages
    .OnLog(
      procedure(const AMessage: String)
      begin
        Writeln(FormatDateTime('hh:nn:ss', Now) + ' ' + AMessage);
      end)
    .OnHandshake(
      procedure(const ASession: IWebSocketSession)
      begin
        Writeln(Format('  %s entrou no chat.', [ASession.UserName]));
      end)
    .OnDisconnect(
      procedure(const ASession: IWebSocketSession)
      begin
        Writeln(Format('  %s saiu do chat.', [ASession.UserName]));
      end)
    .OnError(
      procedure(const ASession: IWebSocketSession; const AException: Exception)
      begin
        Writeln('  [erro] ' + AException.Message);
      end);

  LServer.OnMessage(
    procedure(const ASession: IWebSocketSession; const AMessage: String)
    begin
      RouteMessage(LServer, ASession, AMessage);
    end);

  LServer.Start;
  try
    Writeln('Pressione ENTER para encerrar.');
    Readln;
  finally
    LServer.Stop;

    { O evento OnMessage captura LServer; anular os eventos desfaz a referência
      circular e permite a liberação da instância do servidor. }
    LServer.OnMessage(nil);
  end;
end;

begin
  try
    Run;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
