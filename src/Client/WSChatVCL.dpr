{*******************************************************************************
  Programa..: WSChatVCL
  Objetivo..: Cliente de chat WebSocket com interface visual, falando com o
              servidor WSServerFluent deste mesmo repositório, sem qualquer
              dependência do protocolo Pusher.
  Padrão....: ThR - Normas e Padronização de Codificação (Delphi) v4.0.1
*******************************************************************************}
program WSChatVCL;

uses
  Vcl.Forms,
  THR.WebSocket.Types in '..\Lib\THR.WebSocket.Types.pas',
  THR.WebSocket.Interfaces in '..\Lib\THR.WebSocket.Interfaces.pas',
  THR.WebSocket.Frame in '..\Lib\THR.WebSocket.Frame.pas',
  THR.WebSocket.Handshake in '..\Lib\THR.WebSocket.Handshake.pas',
  THR.WebSocket.Session in '..\Lib\THR.WebSocket.Session.pas',
  THR.WebSocket.OfflineStore in '..\Lib\THR.WebSocket.OfflineStore.pas',
  THR.WebSocket.Message in '..\Lib\THR.WebSocket.Message.pas',
  THR.WebSocket.Server in '..\Lib\THR.WebSocket.Server.pas',
  THR.WebSocket.Client in '..\Lib\THR.WebSocket.Client.pas',
  THR.WebSocket in '..\Lib\THR.WebSocket.pas',
  ClientChatMain in 'ClientChatMain.pas' {FrmClientChat};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'Cliente WebSocket - chat';
  Application.CreateForm(TFrmClientChat, FrmClientChat);
  Application.Run;
end.
