{*******************************************************************************
  Unit......: ClientFluentMain
  Objetivo..: Formulário principal do cliente WebSocket. Demonstra o consumo de
              IPusherClient em uma aplicação VCL conectada a um servidor
              Laravel Reverb / Laravel WebSockets, com os eventos sincronizados
              na thread principal.
  Padrão....: ThR - Normas e Padronização de Codificação (Delphi) v4.0.1
*******************************************************************************}
unit ClientFluentMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  System.JSON, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Vcl.ExtCtrls,
  System.Net.HttpClient, System.Net.URLClient,
  THR.WebSocket,
  THR.WebSocket.Pusher;

type
  {*****************************************************************************
    TFrmClientFluent
    Cliente visual do protocolo Pusher: conecta, inscreve-se em canais e
    exibe os eventos transmitidos pelo Laravel. Toda a leitura acontece na
    thread da biblioteca; SynchronizeEvents devolve os callbacks à thread
    principal, permitindo atualizar os controles diretamente.

    Canais privados e de presença podem ser assinados de duas formas:
      - localmente, com o app secret (apenas para testes);
      - pelo endpoint /broadcasting/auth do Laravel, que é o caminho correto
        em produção porque aplica as regras de routes/channels.php.
  *****************************************************************************}
  TFrmClientFluent = class(TForm)
    LblLog: TLabel;
    LblServidor: TLabel;
    LblAppKey: TLabel;
    LblAppSecret: TLabel;
    LblAuthURL: TLabel;
    LblToken: TLabel;
    LblCanal: TLabel;
    LblEvento: TLabel;
    LblPayload: TLabel;
    MemLog: TMemo;
    EdtServidor: TEdit;
    EdtAppKey: TEdit;
    EdtAppSecret: TEdit;
    EdtAuthURL: TEdit;
    EdtToken: TEdit;
    EdtCanal: TEdit;
    EdtEvento: TEdit;
    EdtPayload: TEdit;
    BtnConectar: TButton;
    BtnPing: TButton;
    BtnInscrever: TButton;
    BtnCancelar: TButton;
    BtnEnviar: TButton;
    PnlStatus: TPanel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure BtnConectarClick(Sender: TObject);
    procedure BtnPingClick(Sender: TObject);
    procedure BtnInscreverClick(Sender: TObject);
    procedure BtnCancelarClick(Sender: TObject);
    procedure BtnEnviarClick(Sender: TObject);
    procedure EdtPayloadKeyPress(Sender: TObject; var Key: Char);
  strict private
    FPusher: IPusherClient;
    procedure BuildClient;
    procedure BindAuthorization;
    procedure Log(const AMessage: String);
    procedure UpdateInterface;
    procedure Connect;
    procedure Disconnect;
    function CurrentChannel: String;
    function Authorize(const ASocketID: String; const AChannel: String): String;
    function PostAuthorization(const ASocketID: String; const AChannel: String): String;
    function BuildAuthHeaders: TNetHeaders;
    class function ExtractAuth(const AContent: String): String; static;
  end;

var
  FrmClientFluent: TFrmClientFluent;

implementation

{$R *.dfm}

const
  C_STATUS_ESTABLISHED = 'Conectado';
  C_STATUS_CONNECTING = 'Negociando...';
  C_STATUS_DISCONNECTED = 'Desconectado';

{ TFrmClientFluent }

procedure TFrmClientFluent.FormCreate(Sender: TObject);
begin
  BuildClient;
  MemLog.Clear;
  Log('Pronto para conectar ao servidor Pusher/Reverb.');
  UpdateInterface;
end;

procedure TFrmClientFluent.FormDestroy(Sender: TObject);
begin
  if not Assigned(FPusher) then
    Exit;

  FPusher.Disconnect;

  { Os eventos capturam Self; anulá-los impede chamadas após a destruição
    do formulário. }
  FPusher
    .OnConnected(nil)
    .OnDisconnected(nil)
    .OnSubscribed(nil)
    .OnEvent(nil)
    .OnError(nil)
    .OnLog(nil)
    .OnAuthorize(nil);
  FPusher := nil;
end;

{ Monta o cliente uma única vez. SynchronizeEvents garante que os eventos
  cheguem na thread principal. }
procedure TFrmClientFluent.BuildClient;
begin
  FPusher := TPusherClient
    .New
    .Path('/app')
    .ConnectTimeout(5000)
    .SynchronizeEvents
    .OnLog(
      procedure(const AClient: IPusherClient; const AMessage: String)
      begin
        Log(AMessage);
      end)
    .OnConnected(
      procedure(const AClient: IPusherClient)
      begin
        Log('Handshake Pusher concluído. socket_id = ' + AClient.SocketID);
        UpdateInterface;
      end)
    .OnDisconnected(
      procedure(const AClient: IPusherClient)
      begin
        Log('Conexão encerrada.');
        UpdateInterface;
      end)
    .OnSubscribed(
      procedure(const AClient: IPusherClient; const AChannel: String)
      begin
        UpdateInterface;
      end)
    .OnEvent(
      procedure(const AClient: IPusherClient; const AChannel: String;
        const AEvent: String; const AData: String)
      begin
        Log(Format('< [%s] %s %s', [AChannel, AEvent, AData]));
      end)
    .OnError(
      procedure(const AClient: IPusherClient; const AException: Exception)
      begin
        Log('Erro: ' + AException.Message);
        UpdateInterface;
      end);
end;

{ Com a URL de autorização preenchida, a assinatura vem do Laravel. Sem ela,
  a biblioteca cai no app secret local. }
procedure TFrmClientFluent.BindAuthorization;
begin
  if Trim(EdtAuthURL.Text) = '' then
  begin
    FPusher.OnAuthorize(nil);
    Exit;
  end;

  FPusher.OnAuthorize(
    function(const ASocketID: String; const AChannel: String): String
    begin
      Result := Authorize(ASocketID, AChannel);
    end);
end;

{ O callback roda na thread principal (SynchronizeEvents), portanto a
  requisição bloqueia a interface pelo tempo do POST. }
function TFrmClientFluent.Authorize(const ASocketID: String;
  const AChannel: String): String;
begin
  Log(Format('> POST %s (%s)', [Trim(EdtAuthURL.Text), AChannel]));
  Result := ExtractAuth(PostAuthorization(ASocketID, AChannel));
  Log('< auth = ' + Result);
end;

function TFrmClientFluent.BuildAuthHeaders: TNetHeaders;
var
  LToken: String;
begin
  Result := [
    TNameValuePair.Create('Content-Type', 'application/json'),
    TNameValuePair.Create('Accept', 'application/json'),
    TNameValuePair.Create('X-Requested-With', 'XMLHttpRequest')];

  LToken := Trim(EdtToken.Text);

  if LToken <> '' then
    Result := Result + [TNameValuePair.Create('Authorization', 'Bearer ' + LToken)];
end;

function TFrmClientFluent.PostAuthorization(const ASocketID: String;
  const AChannel: String): String;
var
  LHTTP: THTTPClient;
  LBody: TStringStream;
  LResponse: IHTTPResponse;
  LRequest: TJSONObject;
begin
  LRequest := TJSONObject.Create;
  try
    LRequest.AddPair('socket_id', ASocketID);
    LRequest.AddPair('channel_name', AChannel);
    LBody := TStringStream.Create(LRequest.ToJSON, TEncoding.UTF8);
  finally
    LRequest.Free;
  end;

  try
    LHTTP := THTTPClient.Create;
    try
      LResponse := LHTTP.Post(Trim(EdtAuthURL.Text), LBody, nil, BuildAuthHeaders);
      Result := LResponse.ContentAsString(TEncoding.UTF8);

      if LResponse.StatusCode <> 200 then
        raise EPusherException.CreateFmt('%s devolveu HTTP %d: %s',
          [Trim(EdtAuthURL.Text), LResponse.StatusCode, Result]);
    finally
      LHTTP.Free;
    end;
  finally
    LBody.Free;
  end;
end;

//{ Resposta esperada: {"auth":"app_key:assinatura"} - canais de presença
//  trazem também o campo channel_data. }
class function TFrmClientFluent.ExtractAuth(const AContent: String): String;
var
  LValue: TJSONValue;
begin
  Result := '';
  LValue := TJSONObject.ParseJSONValue(AContent);
  try
    if LValue is TJSONObject then
      TJSONObject(LValue).TryGetValue<String>('auth', Result);
  finally
    LValue.Free;
  end;

  if Result = '' then
    raise EPusherException.Create('Resposta sem o campo "auth": ' + AContent);
end;

procedure TFrmClientFluent.Log(const AMessage: String);
begin
  MemLog.Lines.Add(FormatDateTime('hh:nn:ss', Now) + '  ' + AMessage);
end;

function TFrmClientFluent.CurrentChannel: String;
begin
  Result := Trim(EdtCanal.Text);
end;

procedure TFrmClientFluent.UpdateInterface;
var
  LConnected: Boolean;
  LEstablished: Boolean;
begin
  LConnected := Assigned(FPusher) and FPusher.IsConnected;
  LEstablished := Assigned(FPusher) and FPusher.IsEstablished;

  if LConnected then
    BtnConectar.Caption := 'Desconectar'
  else
    BtnConectar.Caption := 'Conectar';

  if LEstablished then
  begin
    PnlStatus.Caption := C_STATUS_ESTABLISHED;
    PnlStatus.Font.Color := clGreen;
  end
  else
  if LConnected then
  begin
    PnlStatus.Caption := C_STATUS_CONNECTING;
    PnlStatus.Font.Color := clNavy;
  end
  else
  begin
    PnlStatus.Caption := C_STATUS_DISCONNECTED;
    PnlStatus.Font.Color := clMaroon;
  end;

  BtnPing.Enabled := LEstablished;
  BtnInscrever.Enabled := LEstablished;
  BtnCancelar.Enabled := LEstablished;
  BtnEnviar.Enabled := LEstablished;
  EdtServidor.Enabled := not LConnected;
  EdtAppKey.Enabled := not LConnected;
  EdtAppSecret.Enabled := not LConnected;
end;

{ Aceita "host" ou "host:porta" no campo do servidor. O canal informado é
  registrado antes da conexão e subscrito assim que o socket_id chega. }
procedure TFrmClientFluent.Connect;
var
  LHost: String;
  LPort: Word;
  LPosition: Integer;
begin
  if Trim(EdtAppKey.Text) = '' then
    raise EPusherException.Create('Informe a app key (PUSHER_APP_KEY).');

  LHost := Trim(EdtServidor.Text);
  LPort := C_PUSHER_DEFAULT_PORT;
  LPosition := Pos(':', LHost);

  if LPosition > 0 then
  begin
    LPort := StrToIntDef(Copy(LHost, LPosition + 1, MaxInt), C_PUSHER_DEFAULT_PORT);
    LHost := Copy(LHost, 1, LPosition - 1);
  end;

  if LHost = '' then
    LHost := '127.0.0.1';

  Log(Format('Conectando a ws://%s:%d/app/%s...', [LHost, LPort, Trim(EdtAppKey.Text)]));
  BindAuthorization;

  FPusher
    .Host(LHost)
    .Port(LPort)
    .AppKey(Trim(EdtAppKey.Text))
    .AppSecret(Trim(EdtAppSecret.Text))
    .Subscribe(CurrentChannel)
    .Connect;
end;

procedure TFrmClientFluent.Disconnect;
begin
  FPusher.Disconnect;
  UpdateInterface;
end;

procedure TFrmClientFluent.BtnConectarClick(Sender: TObject);
begin
  try
    if FPusher.IsConnected then
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

procedure TFrmClientFluent.BtnInscreverClick(Sender: TObject);
begin
  if CurrentChannel = '' then
    Exit;

  try
    FPusher.Subscribe(CurrentChannel);
    Log(Format('> pusher:subscribe %s', [CurrentChannel]));
  except
    on E: Exception do
      Log('Falha ao inscrever: ' + E.Message);
  end;
end;

procedure TFrmClientFluent.BtnCancelarClick(Sender: TObject);
begin
  if CurrentChannel = '' then
    Exit;

  try
    FPusher.Unsubscribe(CurrentChannel);
    Log(Format('> pusher:unsubscribe %s', [CurrentChannel]));
  except
    on E: Exception do
      Log('Falha ao cancelar a inscrição: ' + E.Message);
  end;
end;

{ Eventos de cliente exigem o prefixo "client-", canal privado ou de presença
  e a opção habilitada no servidor. }
procedure TFrmClientFluent.BtnEnviarClick(Sender: TObject);
var
  LEvent: String;
  LPayload: String;
begin
  LEvent := Trim(EdtEvento.Text);
  LPayload := Trim(EdtPayload.Text);

  if (LEvent = '') or (CurrentChannel = '') then
    Exit;

  try
    FPusher.Trigger(CurrentChannel, LEvent, LPayload);
    Log(Format('> [%s] %s %s', [CurrentChannel, LEvent, LPayload]));
  except
    on E: Exception do
      Log('Falha ao enviar: ' + E.Message);
  end;
end;

procedure TFrmClientFluent.BtnPingClick(Sender: TObject);
begin
  try
    FPusher.Ping;
    Log('> pusher:ping');
  except
    on E: Exception do
      Log('Falha ao enviar o Ping: ' + E.Message);
  end;
end;

procedure TFrmClientFluent.EdtPayloadKeyPress(Sender: TObject; var Key: Char);
begin
  if (Key = #13) and BtnEnviar.Enabled then
  begin
    Key := #0;
    BtnEnviarClick(BtnEnviar);
  end;
end;

end.
