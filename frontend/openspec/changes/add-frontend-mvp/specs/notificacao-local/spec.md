## Purpose

Avisa o cliente, por uma notificação local do Android, que o pagamento da reserva foi confirmado enquanto o
app estava aberto. O toque na notificação abre a reserva. É o recurso nativo secundário, Should Have: só
entra depois que todos os itens Must estiverem verdes. Não é push e não depende de servidor de mensagens.

## ADDED Requirements

### Requirement: Escopo recomendado e condicionado aos itens obrigatórios
A notificação local SHALL ser implementada só depois que todos os requisitos Must Have do app estiverem
verdes no CI e sem defeito aberto. Se for cortada por prazo, SHALL ficar registrada como retirada, com a data
da decisão, em vez de ser apagada. Sem ela, nenhum outro fluxo do app SHALL mudar. (RF24)

#### Scenario: App sem a notificação
- **GIVEN** a notificação local ainda não implementada
- **WHEN** um pagamento é confirmado na tela Pagamento
- **THEN** o app navega para a DetalheReserva normalmente, sem emitir notificação

### Requirement: Canal e inicialização
A inicialização SHALL acontecer no `main()`, antes do `runApp`, e criar o canal `reservas`:
- nome "Reservas";
- descrição "Confirmação de pagamento das suas reservas";
- importância padrão.

A notificação SHALL usar um ícone monocromático derivado do logo, protegido da remoção de recursos no build
release. (RF24)

#### Scenario: Canal visível nas configurações
- **WHEN** o app é aberto pela primeira vez em um aparelho com Android 8 ou superior
- **THEN** as configurações de notificação do app listam o canal "Reservas"

### Requirement: Permissão pedida uma única vez na tela Pagamento
Na primeira abertura da tela Pagamento, depois do QR, o app SHALL mostrar, no estilo dos cartões do
protótipo, o card "Quer ser avisado quando o pagamento for confirmado?" com o botão "Ativar avisos". O card
SHALL aparecer só quando os avisos estão desligados e `permissao_notificacao_pedida` é falso:
- em Android 13 ou superior, "Ativar avisos" abre o diálogo de `POST_NOTIFICATIONS`;
- em Android 8 a 12, o card não aparece, porque os avisos já vêm ligados.

Depois da resposta, o app SHALL gravar `permissao_notificacao_pedida` e não perguntar de novo. Negar SHALL
deixar o app em silêncio, sem erro. A permissão nunca SHALL ser pedida na abertura do app nem no login.
(RF24, RNF08, CT-25)

#### Scenario: Negar os avisos
- **GIVEN** um aparelho com Android 14 e a primeira abertura da tela Pagamento
- **WHEN** o cliente toca "Ativar avisos" e nega no diálogo
- **THEN** o card some e não volta nas próximas reservas
- **AND** a confirmação do pagamento só navega para a DetalheReserva

### Requirement: Notificação na transição para pago
Quando a consulta da tela Pagamento detectar `PAGO`, o app SHALL emitir uma única notificação por reserva:
- título "Reserva confirmada!";
- texto "<nome da quadra>, <dd/MM> às <HH>h";
- carga com o id da reserva.

A notificação só SHALL ser emitida quando `notificar_confirmacao` está ligado e as notificações do app estão
permitidas. Ciclos repetidos que devolvem `PAGO` SHALL NOT emitir outra notificação. (RF24, RN12, CT-25)

#### Scenario: Notificação ao confirmar
- **GIVEN** os avisos permitidos e `notificar_confirmacao` ligado
- **WHEN** a consulta detecta `PAGO` para a reserva das 19:00 de 10/10 na "Arena Sul"
- **THEN** a barra de status mostra "Reserva confirmada!" com "Arena Sul, 10/10 às 19h"
- **AND** uma segunda resposta `PAGO` da mesma reserva não gera outra notificação

#### Scenario: Preferência desligada no Perfil
- **GIVEN** o switch "Confirmação de reserva" desligado
- **WHEN** a consulta detecta `PAGO`
- **THEN** nenhuma notificação é emitida

### Requirement: Toque abre a DetalheReserva
O toque na notificação SHALL abrir a DetalheReserva da reserva da carga:
- **app aberto ou em segundo plano**: o app navega para `/reservas/:id`;
- **app fechado**: o app guarda o destino e navega para ele depois da Splash, se a sessão for de CLIENTE;
- **sem sessão válida**: o destino é descartado e o fluxo normal de login segue.

(RF24)

#### Scenario: Abrir pela notificação com o app fechado
- **GIVEN** uma notificação de confirmação na barra e o app encerrado pelo gerenciador
- **WHEN** o cliente toca a notificação
- **THEN** o app abre, passa pela Splash e mostra a DetalheReserva da reserva confirmada

### Requirement: Limites declarados da notificação local
A notificação SHALL ser local, disparada pelo próprio app aberto. O app SHALL NOT usar FCM, token de
dispositivo nem tarefa em segundo plano para notificar. Com o app fechado no momento da confirmação, a
confirmação aparece na próxima abertura, pela sincronização, sem notificação. (RF24, RNF11)

#### Scenario: Pagamento confirmado com o app fechado
- **GIVEN** o cliente pagou e fechou o app antes da confirmação
- **WHEN** o pagamento é confirmado pelo backend
- **THEN** nenhuma notificação é emitida
- **AND** ao abrir o app, MinhasReservas mostra a reserva "Confirmada"
