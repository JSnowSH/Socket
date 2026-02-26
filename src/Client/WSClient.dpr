program WSClient;

uses
  Vcl.Forms,
  ClientMain in 'ClientMain.pas' {FClientMain},
  SimpleWebSocket in '..\Common\SimpleWebSocket.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFClientMain, FClientMain);
  Application.Run;
end.
