{*******************************************************************************
  Programa..: WSClientFluentVCL
  Objetivo..: Cliente de chat WebSocket com interface visual, equivalente ao
              WSClient original, porém consumindo a biblioteca THR.WebSocket
              com sintaxe fluente.
  Padrão....: ThR - Normas e Padronização de Codificação (Delphi) v4.0.1
*******************************************************************************}
program WSClientFluentVCL;

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
  ClientFluentMain in 'ClientFluentMain.pas' {FrmClientFluent};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'Cliente WebSocket fluente';
  Application.CreateForm(TFrmClientFluent, FrmClientFluent);
  Application.Run;
end.
