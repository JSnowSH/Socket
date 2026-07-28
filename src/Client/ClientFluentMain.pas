{*******************************************************************************
  Unit......: ClientFluentMain
  Objetivo..: Formulário principal do cliente de chat WebSocket. Demonstra o
              consumo de IWebSocketClient em uma aplicação VCL, com os eventos
              sincronizados na thread principal.
  Padrão....: ThR - Normas e Padronização de Codificação (Delphi) v4.0.1
*******************************************************************************}
unit ClientFluentMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  System.JSON, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Vcl.ExtCtrls, IdGlobal,
  THR.WebSocket;

type
  {*****************************************************************************
    TFrmClientFluent
    Interface visual equivalente à versão sem sintaxe fluente, porém sem
    thread de leitura nem seção crítica no formulário: a biblioteca cuida
    disso e entrega os eventos já na thread principal.
  *****************************************************************************}
  TFrmClientFluent = class(TForm)
    LblLog: TLabel;
    LblMensagem: TLabel;
    LblDestino: TLabel;
    LblNome: TLabel;
    LblServidor: TLabel;
    MemLog: TMemo;
    EdtMensagem: TEdit;
    EdtDestino: TEdit;
    EdtNome: TEdit;
    EdtServidor: TEdit;
    BtnEnviar: TButton;
    BtnConectar: TButton;
    BtnPing: TButton;
    PnlStatus: TPanel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure BtnConectarClick(Sender: TObject);
    procedure BtnEnviarClick(Sender: TObject);
    procedure BtnPingClick(Sender: TObject);
    procedure EdtMensagemKeyPress(Sender: TObject; var Key: Char);
  strict private
    FClient: IWebSocketClient;
    procedure BuildClient;
    procedure Log(const AMessage: String);
    procedure ShowIncoming(const AMessage: String);
    procedure UpdateInterface;
    procedure Connect;
    procedure Disconnect;
  end;

var
  FrmClientFluent: TFrmClientFluent;

implementation

{$R *.dfm}

const
  C_STATUS_CONNECTED = 'Conectado';
  C_STATUS_DISCONNECTED = 'Desconectado';

{ TFrmClientFluent }

procedure TFrmClientFluent.FormCreate(Sender: TObject);
begin
  BuildClient;
  MemLog.Clear;
  Log('Pronto para conectar.');
  UpdateInterface;
end;

procedure TFrmClientFluent.FormDestroy(Sender: TObject);
begin
  if not Assigned(FClient) then
    Exit;

  FClient.Disconnect;

  { Os eventos capturam Self; anulá-los impede chamadas após a destruição
    do formulário. }
  FClient
    .OnMessage(nil)
    .OnBinary(nil)
    .OnDisconnected(nil)
    .OnConnected(nil)
    .OnError(nil)
    .OnLog(nil);
  FClient := nil;
end;

{ Monta o cliente uma única vez. SynchronizeEvents garante que os eventos
  cheguem na thread principal, permitindo atualizar os controles diretamente. }
procedure TFrmClientFluent.BuildClient;
begin
  FClient := TWebSocketClient
    .New
    .Resource('/chat')
    .ConnectTimeout(5000)
    .SynchronizeEvents
    .OnLog(
      procedure(const AClient: IWebSocketClient; const AMessage: String)
      begin
        Log(AMessage);
      end)
    .OnConnected(
      procedure(const AClient: IWebSocketClient)
      begin
        UpdateInterface;
      end)
    .OnDisconnected(
      procedure(const AClient: IWebSocketClient)
      begin
        Log('Conexão encerrada.');
        UpdateInterface;
      end)
    .OnMessage(
      procedure(const AClient: IWebSocketClient; const AMessage: String)
      begin
        ShowIncoming(AMessage);
      end)
    .OnBinary(
      procedure(const AClient: IWebSocketClient; const AData: TIdBytes)
      begin
        Log(Format('Recebido binário de %d bytes.', [Length(AData)]));
      end)
    .OnError(
      procedure(const AClient: IWebSocketClient; const AException: Exception)
      begin
        Log('Erro: ' + AException.Message);
        UpdateInterface;
      end);
end;

procedure TFrmClientFluent.Log(const AMessage: String);
begin
  MemLog.Lines.Add(FormatDateTime('hh:nn:ss', Now) + '  ' + AMessage);
end;

{ Traduz o protocolo JSON do chat. Mensagens fora do protocolo são exibidas
  como texto puro. }
procedure TFrmClientFluent.ShowIncoming(const AMessage: String);
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
      Log('< ' + AMessage);
      Exit;
    end;

    LType := '';
    LText := '';
    LTarget := '';
    LJSON.TryGetValue<String>('type', LType);
    LJSON.TryGetValue<String>('msg', LText);
    LJSON.TryGetValue<String>('to', LTarget);

    if SameText(LType, 'welcome') then
      Log(Format('Conectado como "%s" (id %s).',
        [LJSON.GetValue<String>('name'), LJSON.GetValue<String>('id')]))
    else
    if LText <> '' then
      Log(Format('< [%s] %s', [LTarget, LText]))
    else
      Log('< ' + AMessage);
  finally
    LJSON.Free;
  end;
end;

procedure TFrmClientFluent.UpdateInterface;
var
  LConnected: Boolean;
begin
  LConnected := Assigned(FClient) and FClient.IsConnected;

  if LConnected then
  begin
    BtnConectar.Caption := 'Desconectar';
    PnlStatus.Caption := C_STATUS_CONNECTED;
    PnlStatus.Font.Color := clGreen;
  end
  else
  begin
    BtnConectar.Caption := 'Conectar';
    PnlStatus.Caption := C_STATUS_DISCONNECTED;
    PnlStatus.Font.Color := clMaroon;
  end;

  BtnEnviar.Enabled := LConnected;
  BtnPing.Enabled := LConnected;
  EdtNome.Enabled := not LConnected;
  EdtServidor.Enabled := not LConnected;
end;

{ Aceita "host" ou "host:porta" no campo do servidor. }
procedure TFrmClientFluent.Connect;
var
  LHost: String;
  LPort: Word;
  LPosition: Integer;
begin
  LHost := Trim(EdtServidor.Text);
  LPort := C_DEFAULT_PORT;
  LPosition := Pos(':', LHost);

  if LPosition > 0 then
  begin
    LPort := StrToIntDef(Copy(LHost, LPosition + 1, MaxInt), C_DEFAULT_PORT);
    LHost := Copy(LHost, 1, LPosition - 1);
  end;

  if LHost = '' then
    LHost := '127.0.0.1';

  Log(Format('Conectando a ws://%s:%d/chat...', [LHost, LPort]));

  FClient
    .Host(LHost)
    .Port(LPort)
    .Parameter('name', Trim(EdtNome.Text))
    .Connect;
end;

procedure TFrmClientFluent.Disconnect;
begin
  FClient.Disconnect;
  UpdateInterface;
end;

procedure TFrmClientFluent.BtnConectarClick(Sender: TObject);
begin
  try
    if FClient.IsConnected then
      Disconnect
    else
      Connect;
  except
    on E: Exception do
    begin
      Log('Falha na conexão: ' + E.Message);
      UpdateInterface;
    end;
  end;
end;

procedure TFrmClientFluent.BtnEnviarClick(Sender: TObject);
var
  LTarget: String;
  LText: String;
begin
  LText := Trim(EdtMensagem.Text);

  if LText = '' then
    Exit;

  LTarget := Trim(EdtDestino.Text);

  if LTarget = '' then
    LTarget := C_TARGET_ALL;

  try
    FClient.SendTo(LTarget, LText);
    Log(Format('> [%s] %s', [LTarget, LText]));
    EdtMensagem.Clear;
    EdtMensagem.SetFocus;
  except
    on E: Exception do
      Log('Falha ao enviar: ' + E.Message);
  end;
end;

procedure TFrmClientFluent.BtnPingClick(Sender: TObject);
begin
  try
    FClient.Ping;
    Log('Ping enviado.');
  except
    on E: Exception do
      Log('Falha ao enviar o Ping: ' + E.Message);
  end;
end;

procedure TFrmClientFluent.EdtMensagemKeyPress(Sender: TObject; var Key: Char);
begin
  if (Key = #13) and BtnEnviar.Enabled then
  begin
    Key := #0;
    BtnEnviarClick(BtnEnviar);
  end;
end;

end.
