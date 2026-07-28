# THR.WebSocket — Biblioteca WebSocket fluente para Delphi

Biblioteca de servidor e cliente WebSocket (RFC 6455) sobre Indy, com API fluente.
Escrita conforme **ThR — Normas e Padronização de Codificação (Delphi) v4.0.1**.

## Unidades

| Unit | Responsabilidade |
|---|---|
| `THR.WebSocket.pas` | Fachada — única unit necessária no `uses` do consumidor |
| `THR.WebSocket.Types.pas` | Tipos, enumerados, constantes `C_`, exceções e utilitários |
| `THR.WebSocket.Interfaces.pas` | Contratos fluentes (`IWebSocketServer`, `IWebSocketSession`, `IWebSocketMessage`, `IWebSocketOfflineStore`) |
| `THR.WebSocket.Frame.pas` | Codec de quadros (leitura, escrita, máscara, ping/pong/close) |
| `THR.WebSocket.Handshake.pas` | Handshake HTTP de upgrade (servidor e cliente) |
| `THR.WebSocket.Session.pas` | Sessão de um cliente conectado; serializa as escritas |
| `THR.WebSocket.OfflineStore.pas` | Repositório em memória de mensagens para usuários offline |
| `THR.WebSocket.Message.pas` | Construtor fluente de mensagens de saída |
| `THR.WebSocket.Server.pas` | Servidor (`TWebSocketServer.New`) |
| `THR.WebSocket.Client.pas` | Cliente (`TWebSocketClient.New`), com thread de leitura própria |

Dependências: apenas RTL + Indy (já presente no RAD Studio). Adicione `src\Lib`
ao *search path* do projeto.

## Servidor

```delphi
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
        Writeln(AMessage);
      end)
    .OnMessage(
      procedure(const ASession: IWebSocketSession; const AMessage: String)
      begin
        ASession.Send('Eco: ' + AMessage);
      end)
    .Start;
```

### Configuração

| Método | Padrão | Efeito |
|---|---|---|
| `Port` | 8080 | Porta de escuta (só com o servidor inativo) |
| `Path` | `/` | Recurso aceito no handshake; `/` aceita qualquer recurso |
| `UserNameParameter` | `name` | Parâmetro da query que identifica o usuário |
| `MaxConnections` | 0 (ilimitado) | Limite de conexões simultâneas |
| `ReadTimeout` | 10 ms | Espera por dados em cada ciclo de leitura |
| `KeepOfflineMessages` | `False` | Guarda mensagens diretas de destinatários ausentes |
| `OfflineStore` | memória | Substitui o repositório (ex.: banco de dados) |
| `EchoPingAsPong` | `True` | Responde `Ping` automaticamente |
| `SendWelcomeMessage` | `True` | Envia `{"type":"welcome","id":…,"name":…}` após o handshake |

### Eventos

`OnStart`, `OnStop`, `OnConnect`, `OnHandshake`, `OnDisconnect`, `OnMessage`,
`OnBinary`, `OnError`, `OnLog`, `OnAuthorize`.

`OnAuthorize` é uma função — retornar `False` recusa a conexão com `401`:

```delphi
LServer.OnAuthorize(
  function(const AResource: String; const AUserName: String): Boolean
  begin
    Result := AUserName.StartsWith('User');
  end);
```

> Os eventos são disparados na thread da conexão. Ao atualizar controles
> visuais, use `TThread.Queue`.

### Envio de mensagens

```delphi
// broadcast, exceto o remetente
LServer
  .NewMessage
  .Text(LTexto)
  .ToAll
  .Excluding(ASession.ID)
  .Send;

// direto, com fila offline quando o destino não está conectado
LServer
  .NewMessage
  .JSON(LJSONObject)
  .&To('UserA')
  .StoreWhenOffline
  .Send;

// atalhos
LServer.Broadcast('aviso geral');
LServer.SendTo('UserA', 'mensagem direta');
```

`Send` retorna a quantidade de destinatários atendidos. `&To` aceita `'ALL'`
(equivale a `ToAll`); `Target` é um apelido de `&To` para quem prefere evitar
o identificador escapado.

### Consultas

```delphi
LServer.SessionCount;
for LSession in LServer.Sessions do
  Writeln(LSession.UserName);

if LServer.FindSession('UserA', LSession) then
  LSession.Send('oi');
```

## Cliente

```delphi
FClient := TWebSocketClient
  .New
  .Host('127.0.0.1')
  .Port(8080)
  .Resource('/chat')
  .Parameter('name', EditName.Text)
  .SynchronizeEvents          // eventos na thread principal (VCL/FMX)
  .OnMessage(
    procedure(const AClient: IWebSocketClient; const AMessage: String)
    begin
      MemoLog.Lines.Add(AMessage);
    end)
  .OnDisconnected(
    procedure(const AClient: IWebSocketClient)
    begin
      BtnConnect.Caption := 'Conectar';
    end)
  .Connect;

FClient.SendTo('UserA', 'mensagem direta');   // {"to":"UserA","msg":"…"}
FClient.Send('texto livre');
FClient.Disconnect;
```

O cliente mascara os quadros (exigência da RFC para o lado cliente), valida o
`Sec-WebSocket-Accept` do servidor e mantém uma thread de leitura própria.

## Protocolo do exemplo de chat

Mensagem do cliente: `{"to": "ALL" | "<usuário>", "msg": "<texto>"}`.
O roteamento fica no consumidor (evento `OnMessage`) — a biblioteca não impõe
formato de payload.

## Observações de ciclo de vida

- `TWebSocketServer.New` e `TWebSocketClient.New` devolvem interfaces com
  contagem de referência: não há `Free` manual.
- Se um evento capturar a própria variável do servidor/cliente (closure),
  cria-se referência circular. Anule os eventos ao encerrar
  (`LServer.OnMessage(nil)`) ou capture apenas o que for necessário.
- `Stop` desconecta todas as sessões antes de desativar a escuta.

## Exemplos executáveis

### `src\Server\WSServerFluent.dpr`

Servidor de chat: reproduz o comportamento original (broadcast, envio direto e
mensagens offline) usando somente a API fluente.

### `src\Client\WSClientFluentVCL.dpr` — cliente com interface visual

Equivalente ao `WSClient` original (mesmo layout: log, mensagem, destino, nome,
botão de conexão), porém consumindo a biblioteca. O formulário
[ClientFluentMain.pas](../Client/ClientFluentMain.pas) **não tem thread de
leitura nem seção crítica** — `SynchronizeEvents` entrega os eventos na thread
principal, então os controles são atualizados diretamente:

```delphi
FClient := TWebSocketClient
  .New
  .Resource('/chat')
  .ConnectTimeout(5000)
  .SynchronizeEvents
  .OnConnected(
    procedure(const AClient: IWebSocketClient)
    begin
      UpdateInterface;
    end)
  .OnMessage(
    procedure(const AClient: IWebSocketClient; const AMessage: String)
    begin
      ShowIncoming(AMessage);
    end);
```

Recursos da tela: campo `host` ou `host:porta`, botão Conectar/Desconectar com
estado refletido no rótulo colorido, botão Ping, `Enter` envia a mensagem e
tradução do protocolo JSON para linhas legíveis. No `OnDestroy`, os eventos são
anulados antes de liberar a interface, desfazendo a captura de `Self`.

### `src\Client\WSClientFluent.dpr` — cliente em console

Mesma funcionalidade sem interface gráfica, útil para testes automatizados. A
classe `TChatClientDemo` protege a escrita no console com seção crítica, pois
aqui os eventos chegam na thread de leitura (sem `SynchronizeEvents`).

```
WSClientFluent.exe [nome] [host] [porta]        padrão: UserA 127.0.0.1 8080

/all <texto>          envia para todos
/to <nome> <texto>    envia para um destinatário
/ping                 envia um quadro de controle Ping
/status               exibe o estado da conexão
/quit                 encerra
```

Teste rápido em três consoles:

```
> WSServerFluent.exe
> WSClientFluent.exe UserB
> WSClientFluent.exe UserA
  /to UserB ola do A
```

`UserB` recebe `< [UserB] ola do A`. Se `UserB` não estiver conectado, o
servidor guarda a mensagem e a entrega no próximo handshake dele.

### Roteiro de teste

1. `WSServerFluent.exe`
2. `WSClientFluentVCL.exe` — nome `UserA`, Conectar
3. `WSClientFluentVCL.exe` (segunda instância) — nome `UserB`, Conectar
4. Em `UserA`: destino `UserB`, mensagem qualquer, Enviar

`UserB` recebe `< [UserB] …`. Com destino `ALL`, todos recebem exceto o
remetente. Se `UserB` estiver fechado, o servidor guarda a mensagem e a entrega
quando ele conectar.
