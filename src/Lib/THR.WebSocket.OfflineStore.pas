{*******************************************************************************
  Unit......: THR.WebSocket.OfflineStore
  Objetivo..: Repositório em memória, protegido para acesso concorrente, das
              mensagens destinadas a usuários que não estão conectados.
  Padrão....: ThR - Normas e Padronização de Codificação (Delphi) v4.0.1
*******************************************************************************}
unit THR.WebSocket.OfflineStore;

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.Generics.Collections,
  THR.WebSocket.Types, THR.WebSocket.Interfaces;

type
  {*****************************************************************************
    TWebSocketMemoryOfflineStore
    Implementação padrão de IWebSocketOfflineStore. As mensagens são mantidas
    apenas em memória e recuperadas na próxima conexão do destinatário.
  *****************************************************************************}
  TWebSocketMemoryOfflineStore = class(TInterfacedObject, IWebSocketOfflineStore)
  strict private
    FMessages: TObjectDictionary<String, TList<String>>;
    FLock: TCriticalSection;
    function ListOf(const ATarget: String): TList<String>;
  public
    constructor Create;
    destructor Destroy; override;
    class function New: IWebSocketOfflineStore;

    function Store(const ATarget: String; const AMessage: String): IWebSocketOfflineStore;
    function Fetch(const ATarget: String): TArray<String>;
    function Count(const ATarget: String): Integer;
    function Clear(const ATarget: String): IWebSocketOfflineStore;
    function ClearAll: IWebSocketOfflineStore;
  end;

implementation

{ TWebSocketMemoryOfflineStore }

constructor TWebSocketMemoryOfflineStore.Create;
begin
  inherited Create;
  FMessages := TObjectDictionary<String, TList<String>>.Create([doOwnsValues]);
  FLock := TCriticalSection.Create;
end;

destructor TWebSocketMemoryOfflineStore.Destroy;
begin
  FMessages.Free;
  FLock.Free;
  inherited;
end;

class function TWebSocketMemoryOfflineStore.New: IWebSocketOfflineStore;
begin
  Result := Create;
end;

function TWebSocketMemoryOfflineStore.ListOf(const ATarget: String): TList<String>;
begin
  if not FMessages.TryGetValue(ATarget.ToUpper, Result) then
  begin
    Result := TList<String>.Create;
    FMessages.Add(ATarget.ToUpper, Result);
  end;
end;

function TWebSocketMemoryOfflineStore.Store(const ATarget: String;
  const AMessage: String): IWebSocketOfflineStore;
begin
  Result := Self;

  if ATarget = '' then
    Exit;

  FLock.Enter;
  try
    ListOf(ATarget).Add(AMessage);
  finally
    FLock.Leave;
  end;
end;

function TWebSocketMemoryOfflineStore.Fetch(const ATarget: String): TArray<String>;
var
  LList: TList<String>;
begin
  SetLength(Result, 0);

  if ATarget = '' then
    Exit;

  FLock.Enter;
  try
    if FMessages.TryGetValue(ATarget.ToUpper, LList) then
    begin
      Result := LList.ToArray;
      LList.Clear;
    end;
  finally
    FLock.Leave;
  end;
end;

function TWebSocketMemoryOfflineStore.Count(const ATarget: String): Integer;
var
  LList: TList<String>;
begin
  Result := 0;

  FLock.Enter;
  try
    if FMessages.TryGetValue(ATarget.ToUpper, LList) then
      Result := LList.Count;
  finally
    FLock.Leave;
  end;
end;

function TWebSocketMemoryOfflineStore.Clear(const ATarget: String): IWebSocketOfflineStore;
begin
  Result := Self;

  FLock.Enter;
  try
    FMessages.Remove(ATarget.ToUpper);
  finally
    FLock.Leave;
  end;
end;

function TWebSocketMemoryOfflineStore.ClearAll: IWebSocketOfflineStore;
begin
  Result := Self;

  FLock.Enter;
  try
    FMessages.Clear;
  finally
    FLock.Leave;
  end;
end;

end.
