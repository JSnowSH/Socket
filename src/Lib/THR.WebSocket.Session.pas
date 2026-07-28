{*******************************************************************************
  Unit......: THR.WebSocket.Session
  Objetivo..: Implementação da sessão de um cliente conectado ao servidor.
              Cada sessão encapsula o contexto Indy, os parâmetros do
              handshake e serializa as escritas no canal.
  Padrão....: ThR - Normas e Padronização de Codificação (Delphi) v4.0.1
*******************************************************************************}
unit THR.WebSocket.Session;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.SyncObjs,
  IdContext, IdGlobal, IdIOHandler,
  THR.WebSocket.Types, THR.WebSocket.Interfaces, THR.WebSocket.Frame;

type
  {*****************************************************************************
    TWebSocketSession
    Implementa IWebSocketSession. Instanciada pelo servidor no evento de
    conexão e destruída quando o cliente se desliga.
  *****************************************************************************}
  TWebSocketSession = class(TInterfacedObject, IWebSocketSession)
  strict private
    FContext: TIdContext;
    FID: String;
    FUserName: String;
    FResource: String;
    FPath: String;
    FParameters: TStringList;
    FState: TWebSocketSessionState;
    FCreatedAt: TDateTime;
    FLastActivityAt: TDateTime;
    FWriteLock: TCriticalSection;
    FFragmentPayload: TIdBytes;
    FFragmentOpCode: TWebSocketOpCode;
    function GetIOHandler: TIdIOHandler;
    procedure WriteFrame(const AData: TIdBytes; const AOpCode: TWebSocketOpCode);
  public
    constructor Create(const AContext: TIdContext);
    destructor Destroy; override;

    { IWebSocketSession }
    function ID: String;
    function UserName: String;
    function Resource: String;
    function Path: String;
    function Parameter(const AName: String): String;
    function State: TWebSocketSessionState;
    function IsOpen: Boolean;
    function IsConnected: Boolean;
    function CreatedAt: TDateTime;
    function LastActivityAt: TDateTime;

    function Send(const AText: String): IWebSocketSession; overload;
    function Send(const AJSON: TJSONObject): IWebSocketSession; overload;
    function SendBinary(const AData: TIdBytes): IWebSocketSession;
    function Ping: IWebSocketSession;
    function Close: IWebSocketSession;

    { Uso interno do servidor }
    procedure ApplyHandshake(const AResource: String; const APath: String;
      const AQuery: String; const AUserNameParameter: String);
    procedure ChangeState(const AState: TWebSocketSessionState);
    procedure TouchActivity;
    procedure SendPong(const APayload: TIdBytes);
    function AppendFragment(const AFrame: TWebSocketFrame): Boolean;
    function TakeFragmentPayload: TIdBytes;
    function FragmentOpCode: TWebSocketOpCode;
    function Context: TIdContext;
    function Matches(const ATarget: String): Boolean;
  end;

implementation

{ TWebSocketSession }

constructor TWebSocketSession.Create(const AContext: TIdContext);
begin
  inherited Create;
  FContext := AContext;
  FID := TWebSocketUtils.GenerateID;
  FUserName := '';
  FResource := '';
  FPath := '';
  FState := wssConnected;
  FCreatedAt := Now;
  FLastActivityAt := FCreatedAt;
  FFragmentOpCode := wsoText;
  SetLength(FFragmentPayload, 0);
  FParameters := TStringList.Create;
  FWriteLock := TCriticalSection.Create;
end;

destructor TWebSocketSession.Destroy;
begin
  FWriteLock.Free;
  FParameters.Free;
  inherited;
end;

function TWebSocketSession.Context: TIdContext;
begin
  Result := FContext;
end;

function TWebSocketSession.GetIOHandler: TIdIOHandler;
begin
  Result := nil;

  if (FContext <> nil) and (FContext.Connection <> nil) then
    Result := FContext.Connection.IOHandler;
end;

function TWebSocketSession.ID: String;
begin
  Result := FID;
end;

function TWebSocketSession.UserName: String;
begin
  Result := FUserName;
end;

function TWebSocketSession.Resource: String;
begin
  Result := FResource;
end;

function TWebSocketSession.Path: String;
begin
  Result := FPath;
end;

function TWebSocketSession.Parameter(const AName: String): String;
begin
  Result := FParameters.Values[AName];
end;

function TWebSocketSession.State: TWebSocketSessionState;
begin
  Result := FState;
end;

function TWebSocketSession.IsOpen: Boolean;
begin
  Result := (FState = wssOpen) and IsConnected;
end;

function TWebSocketSession.IsConnected: Boolean;
begin
  Result := (FContext <> nil)
    and (FContext.Connection <> nil)
    and FContext.Connection.Connected;
end;

function TWebSocketSession.CreatedAt: TDateTime;
begin
  Result := FCreatedAt;
end;

function TWebSocketSession.LastActivityAt: TDateTime;
begin
  Result := FLastActivityAt;
end;

function TWebSocketSession.Matches(const ATarget: String): Boolean;
begin
  Result := SameText(FUserName, ATarget) or SameText(FID, ATarget);
end;

procedure TWebSocketSession.ApplyHandshake(const AResource: String; const APath: String;
  const AQuery: String; const AUserNameParameter: String);
begin
  FResource := AResource;
  FPath := APath;
  TWebSocketUtils.ParseQuery(AQuery, FParameters);
  FUserName := FParameters.Values[AUserNameParameter];

  if FUserName = '' then
    FUserName := 'Anon_' + FID;

  ChangeState(wssOpen);
end;

procedure TWebSocketSession.ChangeState(const AState: TWebSocketSessionState);
begin
  FState := AState;
end;

procedure TWebSocketSession.TouchActivity;
begin
  FLastActivityAt := Now;
end;

procedure TWebSocketSession.WriteFrame(const AData: TIdBytes;
  const AOpCode: TWebSocketOpCode);
var
  LIOHandler: TIdIOHandler;
begin
  LIOHandler := GetIOHandler;

  if (LIOHandler = nil) or (not IsConnected) then
    raise EWebSocketNotConnectedException.CreateFmt(
      'Sessão %s não está conectada.', [FID]);

  FWriteLock.Enter;
  try
    TWebSocketFrameCodec.Write(LIOHandler, AData, AOpCode, False);
    TouchActivity;
  finally
    FWriteLock.Leave;
  end;
end;

function TWebSocketSession.Send(const AText: String): IWebSocketSession;
begin
  Result := Self;
  WriteFrame(ToBytes(AText, IndyTextEncoding_UTF8), wsoText);
end;

function TWebSocketSession.Send(const AJSON: TJSONObject): IWebSocketSession;
begin
  Result := Self;

  if AJSON = nil then
    Exit;

  Send(AJSON.ToJSON);
end;

function TWebSocketSession.SendBinary(const AData: TIdBytes): IWebSocketSession;
begin
  Result := Self;
  WriteFrame(AData, wsoBinary);
end;

function TWebSocketSession.Ping: IWebSocketSession;
var
  LEmpty: TIdBytes;
begin
  Result := Self;
  SetLength(LEmpty, 0);
  WriteFrame(LEmpty, wsoPing);
end;

procedure TWebSocketSession.SendPong(const APayload: TIdBytes);
begin
  WriteFrame(APayload, wsoPong);
end;

function TWebSocketSession.Close: IWebSocketSession;
var
  LIOHandler: TIdIOHandler;
begin
  Result := Self;

  if not IsConnected then
    Exit;

  ChangeState(wssClosing);
  LIOHandler := GetIOHandler;

  FWriteLock.Enter;
  try
    try
      if LIOHandler <> nil then
        TWebSocketFrameCodec.WriteClose(LIOHandler);
    finally
      FContext.Connection.Disconnect;
      ChangeState(wssClosed);
    end;
  finally
    FWriteLock.Leave;
  end;
end;

function TWebSocketSession.AppendFragment(const AFrame: TWebSocketFrame): Boolean;
begin
  if AFrame.OpCode <> wsoContinuation then
  begin
    FFragmentOpCode := AFrame.OpCode;
    SetLength(FFragmentPayload, 0);
  end;

  AppendBytes(FFragmentPayload, AFrame.Payload);
  Result := AFrame.Fin;
end;

function TWebSocketSession.TakeFragmentPayload: TIdBytes;
begin
  Result := FFragmentPayload;
  SetLength(FFragmentPayload, 0);
end;

function TWebSocketSession.FragmentOpCode: TWebSocketOpCode;
begin
  Result := FFragmentOpCode;
end;

end.
