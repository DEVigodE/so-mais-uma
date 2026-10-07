## Purpose

Mostra ao cliente a cobrança Pix da reserva recém-criada. Cobre:
- QR desenhado no aparelho, código copia e cola e contador até a expiração;
- consulta ao backend, enquanto a tela está visível, até detectar a confirmação ou a expiração;
- cancelamento da reserva pendente;
- em build de desenvolvimento, simulação do pagamento.

## ADDED Requirements

### Requirement: Fidelidade da tela Pagamento ao protótipo
A tela Pagamento (`/reservas/:id/pagamento`) SHALL reproduzir `docs/Protótipo de Alta Fidelidade/pagamento_pix/code.html`:
- barra com voltar, logo, título "Pagamento Pix" e o avatar de iniciais, como nas demais telas;
- cartão do contador com o ícone de cronômetro, "TEMPO PARA PAGAMENTO", a pílula `mm:ss`, a barra de
  progresso da janela de 15 minutos e o texto "Pague em até 15 minutos para garantir seu horário. Caso
  expire, a vaga será liberada imediatamente.";
- cartão de resumo com `#RES-<id>`, a pílula "Aguardando Pagamento", o ícone do esporte, o nome da quadra, o
  esporte, a linha "<Sáb, 26 de Outubro> • 19:00 - 20:00 (60 min)" e "Valor Total";
- cartão do QR com a pílula do provedor, o QR Code e a legenda "Escaneie o QR Code usando a câmera do
  aplicativo do seu banco";
- cartão "Código Pix Copia e Cola" com o código e o botão "Copiar código Pix";
- "Como pagar:" com os 4 passos do protótipo, sendo o quarto com o valor real da reserva;
- botões "Já realizei o pagamento", "Simular confirmação Pix (Dev Sandbox)" (só em debug),
  "Voltar para Minhas Reservas" com a nota "A reserva permanecerá pendente até o tempo limite." e
  "Cancelar reserva", vindo do protótipo da ConfirmarReserva.

O cartão de permissão de notificação SHALL aparecer no mesmo estilo, conforme a capability
`notificacao-local`. Elementos omitidos:
- o subtítulo de sub-quadra ("Quadra 1 Coberta");
- a marca decorativa no centro do QR, para não reduzir a leitura do código;
- a marcação "(RF19)".

(RF19, RF20, RF21)

#### Scenario: Tela de uma reserva pendente
- **GIVEN** uma reserva pendente de R$ 90,00 com cobrança no profile `simulado`
- **WHEN** a tela Pagamento é aberta
- **THEN** aparecem o contador, `#RES-<id>`, "Aguardando Pagamento", o QR com a pílula "Pagamento simulado", o código copia e cola e os 4 passos
- **AND** o quarto passo cita o valor R$ 90,00

### Requirement: QR Code e copia e cola
O QR Code SHALL ser gerado no aparelho a partir de `pixCopiaECola`, com qr_flutter, sem chamada externa. Ele
SHALL ter módulos escuros sobre fundo claro também no tema escuro, para a câmera do banco ler. O QR SHALL
ter o rótulo semântico "QR Code Pix, <valor>". "Copiar código Pix" SHALL:
- copiar o código para a área de transferência;
- trocar o texto do botão por "Código copiado!" com marca de confirmação;
- mostrar a pílula "Código copiado para a área de transferência!" por 3,5 s.

(RF19, CT-18, CT-25)

#### Scenario: Copiar o código
- **WHEN** o cliente toca "Copiar código Pix"
- **THEN** a área de transferência contém exatamente o `pixCopiaECola` da cobrança
- **AND** aparece "Código copiado para a área de transferência!"

#### Scenario: QR legível no tema escuro
- **GIVEN** o aparelho em modo escuro
- **WHEN** a tela Pagamento é exibida
- **THEN** o QR continua escuro sobre fundo claro e é lido pelo app de um banco

### Requirement: Contador a partir de expiraEm
O contador SHALL ser recalculado a cada segundo como a diferença entre `expiraEm` e o instante atual, nunca
por um cronômetro que começa do zero. A barra de progresso SHALL ser essa diferença dividida pelos 15
minutos da janela. Ao chegar a zero, a tela SHALL fazer um último ciclo de consulta e, se a cobrança não
estiver paga, passar ao estado expirado. Para o leitor de tela, o contador SHALL ser anunciado apenas aos
5 minutos, a 1 minuto e em zero. (RF14, RN10)

#### Scenario: Reabrir a tela no meio do prazo
- **GIVEN** uma reserva criada há 4 minutos
- **WHEN** o cliente sai e volta à tela Pagamento
- **THEN** o contador mostra cerca de 11:00, e não 15:00

### Requirement: Carga da cobrança com cache
A tela SHALL desenhar o QR, o valor e o contador imediatamente a partir de `reserva_cache` quando o código
copia e cola está lá. Em seguida SHALL consultar `GET /reservas/{id}/pagamento` e gravar a resposta no cache.
Sem conexão:
- com o código no cache, o QR continua legível e pagável, o status mostra
  "Aguardando conexão para verificar", "Copiar código Pix" funciona e "Já realizei o pagamento", a simulação
  e "Cancelar reserva" ficam desabilitados;
- sem o código no cache, a tela mostra "Conecte-se para carregar o código Pix" com "Tentar novamente".

Uma resposta 404 SHALL levar à DetalheReserva com `go`. (RF19, RF23, CT-28)

#### Scenario: QR em modo avião
- **GIVEN** a reserva pendente criada neste aparelho e o aparelho em modo avião
- **WHEN** o cliente abre a tela Pagamento pela lista de reservas
- **THEN** o QR aparece a partir do cache e o status mostra "Aguardando conexão para verificar"

### Requirement: Polling do pagamento com backoff
Enquanto a tela está visível, o app SHALL consultar `GET /reservas/{id}/pagamento`:
- a cada 5 s nos 2 primeiros minutos de tela visível;
- depois, a cada 10 s.

As regras de ciclo de vida SHALL ser:
- a consulta pausa quando o app sai do primeiro plano e retoma com um ciclo imediato quando volta, por meio
  do `AppLifecycleListener`;
- o temporizador é cancelado no descarte da tela;
- a consulta termina com o status `PAGO`, `EXPIRADO` ou `CANCELADO`, ou com o último ciclo depois de
  `expiraEm`.

O comportamento em falha SHALL ser:
- falha de rede mantém o QR e o status "Aguardando conexão para verificar";
- outra falha mantém o QR e mostra "Não foi possível verificar agora", sem interromper a consulta;
- um 401 encerra a sessão uma única vez, conforme `plataforma-app`.

O app SHALL NOT enviar parâmetro `atualizar` nem chamar o provedor Pix. (RF20, RNF04, CT-22, CT-25)

#### Scenario: Backoff depois de 2 minutos
- **GIVEN** a tela Pagamento visível com a cobrança pendente
- **WHEN** passam 3 minutos sem pagamento
- **THEN** a consulta rodou a cada 5 s nos 2 primeiros minutos e a cada 10 s no terceiro

#### Scenario: App em segundo plano
- **GIVEN** a tela Pagamento visível
- **WHEN** o cliente troca para o app do banco
- **THEN** nenhuma consulta é feita enquanto o app está em segundo plano
- **AND** ao voltar, uma consulta é feita imediatamente

#### Scenario: Expiração para a consulta
- **WHEN** a cobrança passa a `EXPIRADO`
- **THEN** a consulta para e a tela mostra o estado expirado

### Requirement: Já realizei o pagamento
"Já realizei o pagamento" SHALL disparar imediatamente um ciclo extra da mesma consulta, sem mudar a
cadência e sem parâmetro novo. Durante a consulta, o botão SHALL mostrar "Verificando liquidação Pix..." com
o ícone girando. Se a cobrança continuar pendente, SHALL mostrar "Aguardando compensação bancária" por 2 s e
voltar ao texto original. (RF20)

#### Scenario: Pagamento ainda não compensado
- **GIVEN** a cobrança ainda pendente no backend
- **WHEN** o cliente toca "Já realizei o pagamento"
- **THEN** o botão mostra "Verificando liquidação Pix..." e depois "Aguardando compensação bancária"

### Requirement: Transição para pago
Quando a consulta devolver `PAGO`, o app SHALL:
- gravar no cache a cobrança paga e a reserva como `CONFIRMADA`;
- emitir uma única vez a notificação local, conforme `notificacao-local`;
- fazer `go` para `/reservas/:id`, resultando na pilha MinhasReservas -> DetalheReserva na aba Reservas.

Nos 2 primeiros minutos, a mudança SHALL aparecer em até 5 s depois da confirmação no backend.
(RF20, RF24, RN12, CT-25)

#### Scenario: Confirmação pela simulação
- **GIVEN** a tela Pagamento aberta e o pagamento confirmado pelo endpoint de simulação em outro dispositivo
- **WHEN** o próximo ciclo da consulta roda
- **THEN** em até 5 s o app abre a DetalheReserva com a reserva "Confirmada"
- **AND** o back leva a MinhasReservas, e não à tela Pagamento nem à ConfirmarReserva

### Requirement: Estado expirado
Com a cobrança `EXPIRADO` no servidor, ou com o prazo vencido sem pagamento, a tela SHALL reproduzir
`docs/Protótipo de Alta Fidelidade/pagamento_expirado/code.html`:
- título "Pagamento Expirado";
- alerta "Tempo de pagamento esgotado" com o texto "O prazo de 15 minutos para conclusão do pagamento Pix
  encerrou às <HH:mm de expiraEm>. Para não prejudicar outros atletas, este horário foi liberado no catálogo
  da arena.";
- resumo com "Código da Reserva", a pílula "EXPIRADO", a miniatura da quadra, o nome, o esporte, a data e
  "Valor Total";
- bloco do QR desativado com "00:00 • Expirado", "Código Pix Cancelado" e "Inválido para pagamento";
- aviso "Não realize transferências para este código Pix. Nenhuma cobrança foi efetuada na sua conta.";
- botões "Escolher outro horário / Nova reserva", que faz `go` para a DetalheQuadra da mesma quadra, e
  "Voltar para Minhas Reservas".

O bloco desativado SHALL desenhar um padrão decorativo, nunca o QR real da cobrança. O link
"Precisa de ajuda? Fale com a Arena" SHALL ser omitido. (RF14, RN10, CT-22)

#### Scenario: QR expirado não é escaneável
- **WHEN** a tela entra no estado expirado
- **THEN** o QR real da cobrança deixa de ser desenhado e não há botão de copiar código

#### Scenario: Escolher outro horário
- **WHEN** o cliente toca "Escolher outro horário / Nova reserva"
- **THEN** a DetalheQuadra da mesma quadra abre com a grade atualizada

### Requirement: Cobrança cancelada durante a consulta
Quando a consulta devolver `CANCELADO`, por exemplo porque a arena cancelou a reserva, o app SHALL parar a
consulta, gravar o novo estado no cache e fazer `go` para a DetalheReserva, que mostra a reserva cancelada,
com o snackbar "A reserva foi cancelada.". (RF17, RN13)

#### Scenario: Arena cancela enquanto o cliente paga
- **GIVEN** a tela Pagamento aberta
- **WHEN** o dono cancela a reserva pendente
- **THEN** no ciclo seguinte o app abre a DetalheReserva no estado cancelado com "A reserva foi cancelada."

### Requirement: Simulação do pagamento em build de desenvolvimento
O botão "Simular confirmação Pix (Dev Sandbox)" SHALL aparecer só quando o app roda em modo debug e
`DEV_KEY` não é vazia. Ao tocar, o app SHALL enviar `POST /dev/pagamentos/{txid}/confirmar` com o cabeçalho
`X-Dev-Key` e mostrar "Aprovando via Sandbox...". O comportamento por resultado SHALL ser:
- **sucesso**: dispara um ciclo imediato da consulta. No profile `simulado`, esse ciclo já encontra `PAGO`;
  no `inter-sandbox`, a confirmação chega por um ciclo seguinte;
- **403**: mostra "Chave de desenvolvimento inválida";
- **outras falhas**: mostram a mensagem do erro.

(RF21, CT-24)

#### Scenario: Simulação no profile simulado
- **GIVEN** um APK debug com `DEV_KEY` igual à do backend em `simulado`
- **WHEN** o cliente toca "Simular confirmação Pix (Dev Sandbox)"
- **THEN** em até 5 s o app abre a DetalheReserva com a reserva "Confirmada"

#### Scenario: Release sem simulação
- **WHEN** a tela Pagamento roda em um APK release
- **THEN** o botão de simulação não existe na árvore de widgets

### Requirement: Voltar e cancelar a pendente
O back físico, a seta da barra e "Voltar para Minhas Reservas" SHALL fazer `go` para `/reservas`, nunca
voltando à ConfirmarReserva. "Cancelar reserva" SHALL abrir o sheet de cancelamento do cliente. Depois do
cancelamento, SHALL fazer `go` para a DetalheReserva no estado cancelado. (RF17, RN13, CT-25, CT-26)

#### Scenario: Back físico na tela Pagamento
- **GIVEN** a tela Pagamento aberta logo depois de criar a reserva
- **WHEN** o cliente usa o back físico
- **THEN** o app abre MinhasReservas com a reserva pendente e o botão "Pagar Agora (Pix)"

### Requirement: Rótulo do provedor
A pílula do provedor SHALL mostrar:
- "Ambiente de testes (sandbox) • Inter" quando `provedor` é `INTER`;
- "Pagamento simulado" quando é `SIMULADO`.

A pílula SHALL ficar oculta quando o provedor não é conhecido no cache. (RF19)

#### Scenario: Provedor simulado
- **GIVEN** o backend no profile `simulado`
- **WHEN** a tela Pagamento é exibida
- **THEN** a pílula mostra "Pagamento simulado"

### Requirement: Acessibilidade da tela Pagamento
A tela SHALL atender a estes pontos:
- o QR é lido como imagem com o rótulo "QR Code Pix, <valor>";
- a confirmação de cópia é anunciada;
- o status é comunicado por texto e ícone;
- os botões têm texto completo;
- o contador segue a regra de anúncios por marco.

(RNF07, CT-25)

#### Scenario: QR lido pelo TalkBack
- **GIVEN** o TalkBack ligado e uma cobrança de R$ 80,00
- **WHEN** o foco chega ao QR
- **THEN** o leitor anuncia "QR Code Pix, R$ 80,00"
