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
| `THR.WebSocket.Pusher.pas` | Cliente do protocolo Pusher / Laravel Reverb (`TPusherClient.New`), sobre o cliente acima |

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

## Cliente Pusher (Laravel Reverb / Laravel WebSockets)

`THR.WebSocket.Pusher` é uma camada de **protocolo de aplicação** sobre o
`IWebSocketClient`: o transporte continua sendo o mesmo, o que muda é o diálogo
depois do handshake. Ela cuida do recurso `/app/{app_key}`, do `socket_id`, do
`pusher:ping`, da inscrição em canais e da assinatura de canais privados.

```delphi
FPusher := TPusherClient
  .New
  .Host('127.0.0.1')
  .Port(6001)                     // PUSHER_PORT
  .AppKey('5e0e16cc…')            // PUSHER_APP_KEY
  .SynchronizeEvents
  .OnConnected(
    procedure(const AClient: IPusherClient)
    begin
      MemoLog.Lines.Add('socket_id: ' + AClient.SocketID);
    end)
  .OnEvent(
    procedure(const AClient: IPusherClient; const AChannel: String;
      const AEvent: String; const AData: String)
    begin
      MemoLog.Lines.Add(Format('[%s] %s %s', [AChannel, AEvent, AData]));
    end)
  .Subscribe('pedidos')
  .Connect;
```

Guarde a variável em um campo: a interface é contada por referência e a conexão
cai junto com ela. Canais registrados antes do `Connect` são subscritos sozinhos
assim que o `socket_id` chega.

### Configuração

| Método | Padrão | Efeito |
|---|---|---|
| `Host` / `Port` | `127.0.0.1` / 6001 | Endereço do Reverb (`PUSHER_HOST` / `PUSHER_PORT`) |
| `Path` | `/app` | Prefixo do recurso; a app key é concatenada |
| `AppKey` | — | Obrigatória; identifica a aplicação no servidor |
| `AppSecret` | vazio | Assina canais privados localmente (**apenas testes**) |
| `ConnectTimeout` / `ReadTimeout` / `SynchronizeEvents` | — | Repassados ao cliente WebSocket |

`PUSHER_APP_ID` e `PUSHER_APP_CLUSTER` não participam da conexão do cliente —
servem à API HTTP de publicação e ao serviço hospedado da Pusher.

### Eventos

| Evento | Quando dispara |
|---|---|
| `OnConnected` | Após o `pusher:connection_established` (já com `socket_id`) |
| `OnDisconnected` | Conexão encerrada |
| `OnSubscribed` | `pusher_internal:subscription_succeeded` de um canal |
| `OnEvent` | Qualquer outro evento: `(canal, evento, data)` |
| `OnAuthorize` | Função que devolve o `auth` de um canal privado |
| `OnError` / `OnLog` | Erros do protocolo e rastreamento |

`IsConnected` indica o socket aberto; `IsEstablished` indica o handshake de
aplicação concluído — é este que habilita `Subscribe` e `Trigger`.

### Canais privados e de presença

O Reverb não decide quem entra no canal: ele apenas confere uma assinatura
HMAC-SHA256 de `"{socket_id}:{canal}"`. Há dois caminhos:

```delphi
// 1. assinatura local — rápido para testar, expõe o segredo no executável
FPusher.AppSecret('b60900f4…');

// 2. delegada ao Laravel — caminho correto em produção
FPusher.OnAuthorize(
  function(const ASocketID: String; const AChannel: String): String
  begin
    // POST em /broadcasting/auth com socket_id e channel_name;
    // devolver o campo "auth" da resposta
    Result := MinhaApi.Autorizar(ASocketID, AChannel);
  end);
```

Só o segundo aplica as regras de `routes/channels.php`. Com o segredo local,
qualquer canal é aceito. Canais de presença exigem também o `channel_data`
devolvido pelo endpoint, informado em `Subscribe(canal, channelData)`.

### Envio e manutenção da conexão

```delphi
FPusher.Trigger('private-sala.1', 'client-digitando', '{"user":"Ana"}');
FPusher.Ping;   // pusher:ping — evite cair pelo activity_timeout
```

`Trigger` exige o prefixo `client-`, canal privado ou de presença e client
events habilitados no servidor. `Socket` devolve o `IWebSocketClient` interno,
caso precise do transporte cru.

> Limitações atuais: sem `wss://` (TLS) — o transporte é TCP puro, adequado a
> `PUSHER_SCHEME=http`; e o `IPusherClient` é somente cliente, o
> `THR.WebSocket.Server` não substitui o Reverb.

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

### Panorama dos clientes

| Projeto | Tipo | Protocolo | Serve para |
|---|---|---|---|
| `WSClient` | VCL | chat próprio | Referência histórica: thread de leitura e seção crítica escritas à mão |
| `WSClientFluent` | console | chat próprio | Testes rápidos e automatizados por linha de comando |
| `WSChatVCL` | VCL | chat próprio | O mesmo chat com interface, já usando a API fluente |
| `WSClientFluentVCL` | VCL | Pusher | Conectar a um Laravel Reverb: canais, eventos e autorização |

Os três primeiros conversam com o `WSServerFluent` deste repositório; o último
conversa com o servidor do Laravel e não usa o servidor daqui.

### `src\Client\WSClient.dpr` — cliente VCL sem a biblioteca

Versão original, anterior à `THR.WebSocket`: fala WebSocket direto pela unit
`src\Common\SimpleWebSocket.pas`, com thread de leitura e seção crítica dentro
do próprio formulário. Mantido como comparação — mostra o que a biblioteca
passou a absorver.

### `src\Client\WSChatVCL.dpr` — chat com interface visual

Mesmo layout do `WSClient` (log, mensagem, destino, nome, botão de conexão),
porém consumindo a biblioteca. O formulário
[ClientChatMain.pas](src/Client/ClientChatMain.pas) **não tem thread de
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

### `src\Client\WSClientFluentVCL.dpr` — cliente Pusher / Laravel Reverb

Formulário [ClientFluentMain.pas](src/Client/ClientFluentMain.pas), o único
exemplo que **não** usa o servidor deste repositório. A tela expõe todo o ciclo
do protocolo:

| Campo / botão | Papel |
|---|---|
| **Servidor** | `host` ou `host:porta` (padrão `127.0.0.1:6001`) |
| **App key** | `PUSHER_APP_KEY`; vira o recurso `/app/{key}` |
| **App secret** | Assinatura local de canais privados; deixe vazio em produção |
| **Auth URL** | `/broadcasting/auth`; preenchida, tem prioridade sobre o secret |
| **Token** | `Authorization: Bearer …` enviado ao endpoint de autorização |
| **Conectar** / **Ping** | Abre a conexão; `Ping` dispara `pusher:ping` |
| **Canal** + **Inscrever** / **Cancelar** | `pusher:subscribe` e `pusher:unsubscribe` |
| **Evento** + **Payload** + **Enviar** | Dispara um evento `client-*` no canal |

O rótulo de status distingue três estados: `Desconectado`, `Negociando…`
(socket aberto, aguardando o `connection_established`) e `Conectado` (com
`socket_id`). O log registra o handshake, cada inscrição, o POST de autorização
e todo evento recebido no formato `< [canal] evento {json}`.

A autorização fica em `BindAuthorization`: com **Auth URL** preenchida, instala
um `OnAuthorize` que faz `POST` em JSON (`socket_id`, `channel_name`) com
`Accept: application/json` e `X-Requested-With: XMLHttpRequest`, e extrai o
campo `auth` da resposta; vazia, deixa a biblioteca assinar com o app secret.
O POST roda na thread principal — para muitos canais, mova-o para uma thread.

Roteiro: `php artisan reverb:start`, preencha servidor e app key, **Conectar**,
inscreva-se no canal e dispare um `broadcast(new SeuEvento)` no Laravel.

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
2. `WSChatVCL.exe` — nome `UserA`, Conectar
3. `WSChatVCL.exe` (segunda instância) — nome `UserB`, Conectar
4. Em `UserA`: destino `UserB`, mensagem qualquer, Enviar

`UserB` recebe `< [UserB] …`. Com destino `ALL`, todos recebem exceto o
remetente. Se `UserB` estiver fechado, o servidor guarda a mensagem e a entrega
quando ele conectar.
