{*******************************************************************************
  Programa..: WSClientFluent
  Objetivo..: Exemplo de uso do cliente da biblioteca THR.WebSocket. Conecta-se
              ao servidor de chat, exibe as mensagens recebidas e envia os
              comandos digitados no console.
  Uso.......: WSClientFluent.exe [nome] [host] [porta]
  Comandos..: /all <texto>          envia para todos
              /to <nome> <texto>    envia para um destinatário
              /ping                 envia um quadro de controle Ping
              /status               exibe o estado da conexão
              /quit                 encerra
  Padrão....: ThR - Normas e Padronização de Codificação (Delphi) v4.0.1
*******************************************************************************}
program WSClientFluent;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.SyncObjs,
  IdGlobal,
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

type
  {*****************************************************************************
    TChatClientDemo
    Demonstra o consumo de IWebSocketClient em uma aplicação console. Os
    eventos são disparados na thread de leitura, por isso a escrita no console
    é protegida por uma seção crítica.
  *****************************************************************************}
  TChatClientDemo = class
  strict private
    FClient: IWebSocketClient;
    FConsoleLock: TCriticalSection;
    FUserName: String;
    FHost: String;
    FPort: Word;
    FRunning: Boolean;
    procedure Print(const AText: String);
    procedure ShowUsage;
    procedure ShowIncoming(const AMessage: String);
    procedure ShowStatus;
    procedure BuildClient;
    procedure ExecuteCommand(const ALine: String);
    procedure SendToAll(const AText: String);
    procedure SendToTarget(const AArguments: String);
  public
    constructor Create(const AUserName: String; const AHost: String; const APort: Word);
    destructor Destroy; override;
    procedure Run;
  end;

{ TChatClientDemo }

constructor TChatClientDemo.Create(const AUserName: String; const AHost: String;
  const APort: Word);
begin
  inherited Create;
  FUserName := AUserName;
  FHost := AHost;
  FPort := APort;
  FRunning := True;
  FConsoleLock := TCriticalSection.Create;
end;

destructor TChatClientDemo.Destroy;
begin
  if Assigned(FClient) then
  begin
    FClient.Disconnect;

    { Os eventos capturam Self; anulá-los evita chamadas após a destruição. }
    FClient
      .OnMessage(nil)
      .OnDisconnected(nil)
      .OnError(nil)
      .OnLog(nil);
    FClient := nil;
  end;

  FConsoleLock.Free;
  inherited;
end;

procedure TChatClientDemo.Print(const AText: String);
begin
  FConsoleLock.Enter;
  try
    Writeln(AText);
  finally
    FConsoleLock.Leave;
  end;
end;

procedure TChatClientDemo.ShowUsage;
begin
  Print('Comandos: /all <texto> | /to <nome> <texto> | /ping | /status | /quit');
end;

{ Traduz o protocolo JSON do chat para uma linha legível. Mensagens que não
  seguirem o protocolo são exibidas como texto puro. }
procedure TChatClientDemo.ShowIncoming(const AMessage: String);
var
  LJSON: TJSONObject;
  LType: String;
  LText: String;
  LTarget: String;
begin
  LJSON := TJSONObject.ParseJSONValue(AMessage) as TJSONObject;
  try
    if not Assigned(LJSON) then
    begin
      Print('< ' + AMessage);
      Exit;
    end;

    LType := '';
    LText := '';
    LTarget := '';
    LJSON.TryGetValue<String>('type', LType);
    LJSON.TryGetValue<String>('msg', LText);
    LJSON.TryGetValue<String>('to', LTarget);

    if SameText(LType, 'welcome') then
      Print(Format('* conectado como "%s" (id %s)',
        [LJSON.GetValue<String>('name'), LJSON.GetValue<String>('id')]))
    else
    if LText <> '' then
      Print(Format('< [%s] %s', [LTarget, LText]))
    else
      Print('< ' + AMessage);
  finally
    LJSON.Free;
  end;
end;

procedure TChatClientDemo.ShowStatus;
begin
  if FClient.IsConnected then
    Print(Format('* conectado a ws://%s:%d como "%s"', [FHost, FPort, FUserName]))
  else
    Print('* desconectado');
end;

procedure TChatClientDemo.BuildClient;
begin
  FClient := TWebSocketClient
    .New
    .Host(FHost)
    .Port(FPort)
    .Resource('/chat')
    .Parameter('name', FUserName)
    .ConnectTimeout(5000)
    .OnLog(
      procedure(const AClient: IWebSocketClient; const AMessage: String)
      begin
        Print('* ' + AMessage);
      end)
    .OnMessage(
      procedure(const AClient: IWebSocketClient; const AMessage: String)
      begin
        ShowIncoming(AMessage);
      end)
    .OnBinary(
      procedure(const AClient: IWebSocketClient; const AData: TIdBytes)
      begin
        Print(Format('< [binário] %d bytes', [Length(AData)]));
      end)
    .OnDisconnected(
      procedure(const AClient: IWebSocketClient)
      begin
        Print('* conexão encerrada. Digite /quit para sair.');
      end)
    .OnError(
      procedure(const AClient: IWebSocketClient; const AException: Exception)
      begin
        Print('* erro: ' + AException.Message);
      end);
end;

procedure TChatClientDemo.SendToAll(const AText: String);
begin
  if AText = '' then
    Exit;

  FClient.SendTo(C_TARGET_ALL, AText);
  Print('> [todos] ' + AText);
end;

procedure TChatClientDemo.SendToTarget(const AArguments: String);
var
  LPosition: Integer;
  LTarget: String;
  LText: String;
begin
  LPosition := Pos(' ', AArguments);

  if LPosition = 0 then
  begin
    Print('* uso: /to <nome> <texto>');
    Exit;
  end;

  LTarget := Copy(AArguments, 1, LPosition - 1);
  LText := Trim(Copy(AArguments, LPosition + 1, MaxInt));

  if LText = '' then
  begin
    Print('* uso: /to <nome> <texto>');
    Exit;
  end;

  FClient.SendTo(LTarget, LText);
  Print(Format('> [%s] %s', [LTarget, LText]));
end;

procedure TChatClientDemo.ExecuteCommand(const ALine: String);
var
  LCommand: String;
  LArguments: String;
  LPosition: Integer;
begin
  if ALine = '' then
    Exit;

  LPosition := Pos(' ', ALine);

  if LPosition > 0 then
  begin
    LCommand := Copy(ALine, 1, LPosition - 1);
    LArguments := Trim(Copy(ALine, LPosition + 1, MaxInt));
  end
  else
  begin
    LCommand := ALine;
    LArguments := '';
  end;

  if SameText(LCommand, '/quit') then
    FRunning := False
  else
  if SameText(LCommand, '/status') then
    ShowStatus
  else
  if SameText(LCommand, '/ping') then
    FClient.Ping
  else
  if SameText(LCommand, '/to') then
    SendToTarget(LArguments)
  else
  if SameText(LCommand, '/all') then
    SendToAll(LArguments)
  else
  if LCommand.StartsWith('/') then
    ShowUsage
  else
    SendToAll(ALine);
end;

procedure TChatClientDemo.Run;
var
  LLine: String;
begin
  BuildClient;
  Print(Format('Conectando a ws://%s:%d/chat como "%s"...', [FHost, FPort, FUserName]));

  try
    FClient.Connect;
  except
    on E: Exception do
    begin
      Print('* falha ao conectar: ' + E.Message);
      Exit;
    end;
  end;

  ShowUsage;

  while FRunning do
  begin
    Readln(LLine);

    try
      ExecuteCommand(Trim(LLine));

      { Encerra quando a entrada padrao termina (stdin redirecionado). }
      if Eof(Input) then
        FRunning := False;
    except
      on E: EWebSocketNotConnectedException do
        Print('* não conectado: ' + E.Message);
      on E: Exception do
        Print('* erro ao executar o comando: ' + E.Message);
    end;
  end;
end;

  { Lê os argumentos de linha de comando, aplicando os valores padrão. }
procedure Main;
var
  LDemo: TChatClientDemo;
  LUserName: String;
  LHost: String;
  LPort: Word;
begin
  LUserName := 'UserA';
  LHost := '127.0.0.1';
  LPort := C_DEFAULT_PORT;

  if ParamCount >= 1 then
    LUserName := ParamStr(1);

  if ParamCount >= 2 then
    LHost := ParamStr(2);

  if ParamCount >= 3 then
    LPort := StrToIntDef(ParamStr(3), C_DEFAULT_PORT);

  LDemo := TChatClientDemo.Create(LUserName, LHost, LPort);
  try
    LDemo.Run;
  finally
    LDemo.Free;
  end;
end;

begin
  try
    Main;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
