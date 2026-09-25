## Purpose

Garante que um cliente consiga tomar um horário de quadra com exclusividade, acompanhe suas
reservas e possa cancelá-las dentro de prazos conhecidos, e que o dono veja e possa cancelar as
reservas recebidas nas suas quadras, sem que dois clientes jamais fiquem com o mesmo horário.

## ADDED Requirements

### Requirement: Criação de reserva pendente de pagamento
O sistema SHALL permitir que um usuário com perfil `CLIENTE` crie uma reserva em
`POST /api/v1/reservas` informando quadra, início e, opcionalmente, uma observação de até 200
caracteres. A reserva criada SHALL nascer com status `PENDENTE_PAGAMENTO`, fim igual ao início mais
60 minutos e valor igual ao preço por hora vigente da quadra no momento da criação. A resposta SHALL
ser 201 com a reserva e a cobrança Pix associada. Um usuário com perfil `DONO` SHALL receber 403 com
`codigo` `ACESSO_NEGADO`, inclusive para quadras próprias. (RF13, RN02, RN07, RN10)

#### Scenario: Cliente reserva um slot livre
- **WHEN** um CLIENTE envia `POST /api/v1/reservas` para um slot livre de uma quadra ativa
- **THEN** a resposta é 201 com status `PENDENTE_PAGAMENTO`, `fim` uma hora após `inicio` e `valor` igual ao preço por hora da quadra
- **AND** a resposta traz a cobrança Pix associada

#### Scenario: DONO não reserva
- **WHEN** um DONO envia `POST /api/v1/reservas`, inclusive para uma quadra própria
- **THEN** a resposta é 403 com `codigo` `ACESSO_NEGADO`

#### Scenario: Preço da quadra muda depois da reserva
- **WHEN** o dono altera o preço por hora depois de a reserva ter sido criada
- **THEN** o valor da reserva existente permanece o que era no momento da criação

### Requirement: Exclusividade do slot garantida no banco de dados
O sistema SHALL garantir que exista no máximo uma reserva com status `PENDENTE_PAGAMENTO` ou
`CONFIRMADA` por par de quadra e instante de início. A garantia SHALL residir em uma restrição de
unicidade do banco de dados que considere apenas reservas nesses dois status, e SHALL NOT depender
de verificação prévia em memória nem de bloqueio de linha. A tentativa perdedora SHALL receber 409
com `codigo` `HORARIO_INDISPONIVEL`. Reservas que saem desses status SHALL liberar o slot
automaticamente, sem operação adicional. (RF13, RN08)

#### Scenario: Dois clientes disputam o mesmo slot
- **WHEN** dois CLIENTES distintos enviam `POST /api/v1/reservas` concorrentes para a mesma quadra e o mesmo início
- **THEN** exatamente um recebe 201
- **AND** o outro recebe 409 com `codigo` `HORARIO_INDISPONIVEL`
- **AND** existe exatamente uma reserva ativa para aquele par de quadra e início

#### Scenario: Dez clientes disputam o mesmo slot simultaneamente
- **WHEN** dez CLIENTES distintos enviam a criação da mesma reserva ao mesmo tempo
- **THEN** exatamente uma resposta é 201 e nove são 409 com `codigo` `HORARIO_INDISPONIVEL`
- **AND** a contagem de reservas ativas para aquele par de quadra e início é 1
- **AND** existe exatamente uma cobrança Pix criada
- **AND** nenhuma exceção não tratada é registrada no log

#### Scenario: Slot liberado por expiração pode ser retomado
- **WHEN** a reserva que ocupava um slot passa a `EXPIRADA`
- **THEN** outro CLIENTE consegue criar uma reserva para o mesmo slot com resposta 201

#### Scenario: Outra violação de integridade não vira conflito de horário
- **WHEN** a criação falha por uma violação de integridade que não é a da restrição de exclusividade do slot
- **THEN** a resposta é 500 com `codigo` `ERRO_INTERNO`
- **AND** a exceção original é registrada por completo no log, sem ser reescrita como horário indisponível

### Requirement: Validação do horário pedido na reserva
O sistema SHALL recusar a criação quando o início não estiver em hora cheia no fuso de referência ou
estiver no passado, respondendo 400 com `codigo` `VALIDACAO`. SHALL recusar com 404 e `codigo`
`NAO_ENCONTRADO` quando a quadra não existe ou está inativa. SHALL recusar com 422, `codigo`
`REGRA_NEGOCIO` e `subcodigo` `DATA_FORA_DA_JANELA` quando a data do início passa de hoje mais 14
dias, e com `subcodigo` `FORA_DO_FUNCIONAMENTO` quando o slot cai fora da faixa de funcionamento do
dia ou em dia sem faixa cadastrada. (RF13, RN06, RN09, RN19)

#### Scenario: Início fora da hora cheia
- **WHEN** um CLIENTE envia um início às 19:30
- **THEN** a resposta é 400 com `codigo` `VALIDACAO` e uma entrada em `campos[]` para o campo de início

#### Scenario: Início no passado
- **WHEN** um CLIENTE envia um início anterior ao instante atual
- **THEN** a resposta é 400 com `codigo` `VALIDACAO`

#### Scenario: Quadra inativa
- **WHEN** um CLIENTE tenta reservar em uma quadra desativada
- **THEN** a resposta é 404 com `codigo` `NAO_ENCONTRADO`

#### Scenario: Data além da janela de quinze dias
- **WHEN** um CLIENTE envia um início para hoje mais 15 dias
- **THEN** a resposta é 422 com `subcodigo` `DATA_FORA_DA_JANELA`

#### Scenario: Horário fora do funcionamento
- **WHEN** um CLIENTE tenta reservar às 07:00 em uma quadra que abre às 08:00
- **THEN** a resposta é 422 com `subcodigo` `FORA_DO_FUNCIONAMENTO`

### Requirement: Uma reserva pendente por cliente
O sistema SHALL permitir no máximo uma reserva com status `PENDENTE_PAGAMENTO` por cliente. Uma nova
tentativa enquanto existir uma pendente SHALL responder 422 com `codigo` `REGRA_NEGOCIO`, `subcodigo`
`RESERVA_PENDENTE_EXISTENTE` e a extensão `reservaId` apontando para a reserva pendente, para que o
consumidor leve o usuário a concluí-la ou cancelá-la. (RF13, RN11)

#### Scenario: Cliente com pendente tenta reservar outro horário
- **WHEN** um CLIENTE que já tem uma reserva `PENDENTE_PAGAMENTO` envia uma nova criação
- **THEN** a resposta é 422 com `subcodigo` `RESERVA_PENDENTE_EXISTENTE`
- **AND** a resposta traz `reservaId` com o identificador da reserva pendente existente

#### Scenario: Cliente volta a reservar após resolver a pendente
- **WHEN** a reserva pendente do cliente passa a `CONFIRMADA`, `CANCELADA` ou `EXPIRADA`
- **THEN** uma nova criação do mesmo cliente é aceita

### Requirement: Prazo de pagamento e expiração automática
Toda reserva criada SHALL receber um instante de expiração igual ao instante de criação mais 15
minutos, e a cobrança Pix associada SHALL expirar no mesmo instante. O sistema SHALL executar
periodicamente, a cada 60 segundos, a expiração em lote das reservas `PENDENTE_PAGAMENTO` cujo
instante de expiração já passou, marcando-as como `EXPIRADA`, e marcar como `EXPIRADO` os pagamentos
`PENDENTE` correspondentes. A expiração SHALL liberar o slot. (RF14, RN10)

#### Scenario: Reserva não paga expira e libera o slot
- **WHEN** uma reserva fica `PENDENTE_PAGAMENTO` por mais de 15 minutos sem pagamento
- **THEN** no ciclo seguinte de expiração ela passa a `EXPIRADA` e o pagamento passa a `EXPIRADO`
- **AND** o slot volta a aparecer como `LIVRE` na grade
- **AND** outro cliente consegue reservá-lo

#### Scenario: Reserva paga dentro do prazo não expira
- **WHEN** o pagamento é confirmado antes do instante de expiração
- **THEN** a reserva permanece `CONFIRMADA` e nunca é marcada como `EXPIRADA`

#### Scenario: Janela do ciclo de expiração
- **WHEN** uma reserva expira entre duas execuções do ciclo
- **THEN** ela é marcada como `EXPIRADA` no máximo 60 segundos depois do instante de expiração

### Requirement: Compensação quando a cobrança Pix não pode ser criada
A criação da reserva e a criação da cobrança Pix SHALL ocorrer em transações separadas: a reserva
SHALL ser confirmada no banco antes de qualquer chamada ao provedor de pagamento, de modo que
nenhuma chamada externa ocorra com a restrição de exclusividade retida. Se a cobrança não puder ser
criada, o sistema SHALL cancelar a reserva marcando `CanceladoPor` igual a `SISTEMA` com o motivo
correspondente, SHALL NOT persistir pagamento algum e SHALL responder 502 com `codigo`
`PAGAMENTO_INDISPONIVEL`, liberando o slot. (RF13, RF19, RN17)

#### Scenario: Provedor de pagamento indisponível
- **WHEN** a criação da cobrança falha por indisponibilidade do provedor
- **THEN** a resposta é 502 com `codigo` `PAGAMENTO_INDISPONIVEL`
- **AND** a reserva fica `CANCELADA` com `canceladoPor` igual a `SISTEMA`
- **AND** não existe registro de pagamento para essa reserva
- **AND** o slot volta a aparecer como `LIVRE`

#### Scenario: Nenhuma chamada externa dentro da transação da reserva
- **WHEN** a criação de uma reserva é processada
- **THEN** a transação que insere a reserva termina antes de qualquer chamada ao provedor de pagamento

### Requirement: Listagem de reservas por situação
O sistema SHALL expor `GET /api/v1/reservas` para qualquer usuário autenticado, ordenada por início.
Para um CLIENTE, SHALL devolver apenas as próprias reservas; para um DONO, apenas as reservas das
suas quadras. O parâmetro de situação SHALL aceitar `PROXIMAS`, que devolve reservas ativas com fim
no futuro, e `HISTORICO`, que devolve as demais. A ausência do parâmetro SHALL devolver tudo,
limitado aos últimos 12 meses. Não SHALL haver paginação. (RF15, RF18, RN04, RN03)

#### Scenario: Cliente vê apenas as próprias reservas
- **WHEN** um CLIENTE chama a listagem
- **THEN** nenhuma reserva de outro cliente aparece no resultado

#### Scenario: Dono vê as reservas das próprias quadras
- **WHEN** um DONO chama a listagem
- **THEN** o resultado traz apenas reservas feitas em quadras desse dono

#### Scenario: Separação entre próximas e histórico
- **WHEN** um CLIENTE tem uma reserva `CONFIRMADA` para amanhã e uma `EXPIRADA` de ontem
- **THEN** a consulta por `PROXIMAS` devolve apenas a de amanhã
- **AND** a consulta por `HISTORICO` devolve apenas a de ontem

### Requirement: Detalhe da reserva com o estado do pagamento
O sistema SHALL expor `GET /api/v1/reservas/{id}` devolvendo a reserva com a cobrança associada
embutida quando existir. O acesso SHALL ser permitido ao cliente dono da reserva e ao dono da quadra
em que ela foi feita; qualquer outro usuário SHALL receber 403 com `codigo` `ACESSO_NEGADO`. Os
dados de nome e telefone do cliente SHALL aparecer somente quando quem consulta é o DONO da quadra,
e SHALL ser os dados cadastrais do cliente, nunca dados do pagador Pix. (RF15, RN04, RN05)

#### Scenario: Cliente consulta a própria reserva
- **WHEN** o cliente dono da reserva consulta o detalhe
- **THEN** a resposta é 200 com os dados da reserva e a cobrança embutida

#### Scenario: Reserva de outro cliente
- **WHEN** um CLIENTE consulta o detalhe de uma reserva de outro cliente
- **THEN** a resposta é 403 com `codigo` `ACESSO_NEGADO`

#### Scenario: Dono vê o contato do cliente
- **WHEN** o dono da quadra consulta o detalhe de uma reserva recebida
- **THEN** a resposta inclui nome e telefone cadastrais do cliente
- **AND** não inclui nenhum dado de quem efetuou o pagamento Pix

### Requirement: Edição apenas da observação da reserva
O sistema SHALL permitir que o cliente dono da reserva altere a observação em
`PATCH /api/v1/reservas/{id}`, com no máximo 200 caracteres, enquanto a reserva estiver ativa.
Qualquer outro campo enviado SHALL ser ignorado. A tentativa de editar uma reserva `CANCELADA` ou
`EXPIRADA` SHALL responder 422 com `codigo` `REGRA_NEGOCIO` e `subcodigo` `TRANSICAO_INVALIDA`.
(RF16, RN15)

#### Scenario: Observação alterada em reserva ativa
- **WHEN** o cliente altera a observação de uma reserva `CONFIRMADA` futura
- **THEN** a resposta é 200 e a nova observação aparece em uma consulta seguinte

#### Scenario: Edição de reserva encerrada
- **WHEN** o cliente tenta alterar a observação de uma reserva `EXPIRADA`
- **THEN** a resposta é 422 com `subcodigo` `TRANSICAO_INVALIDA`

#### Scenario: Campo não editável é ignorado
- **WHEN** o cliente envia, junto da observação, um novo valor ou um novo início
- **THEN** apenas a observação é alterada

### Requirement: Reserva nunca é apagada
O sistema SHALL NOT oferecer exclusão de reserva. Toda reserva SHALL permanecer no banco e SHALL ser
encerrada apenas por mudança de status, de modo que o histórico do cliente e do dono seja
preservado. (RN15)

#### Scenario: Não existe rota de exclusão
- **WHEN** um consumidor procura uma operação para apagar uma reserva
- **THEN** não existe nenhuma rota que remova o registro
- **AND** reservas encerradas continuam listadas no histórico

### Requirement: Cancelamento pelo cliente com prazo por status
O sistema SHALL permitir que o cliente dono da reserva a cancele em
`POST /api/v1/reservas/{id}/cancelar`, respondendo 200 com a reserva atualizada e gravando
`CanceladoPor` igual a `CLIENTE`, o motivo quando informado e o instante do cancelamento. Reserva
`PENDENTE_PAGAMENTO` SHALL poder ser cancelada a qualquer momento. Reserva `CONFIRMADA` SHALL poder
ser cancelada somente até 2 horas antes do início; depois disso a resposta SHALL ser 422 com
`codigo` `REGRA_NEGOCIO` e `subcodigo` `CANCELAMENTO_FORA_DO_PRAZO`. O cancelamento SHALL liberar o
slot e SHALL NOT gerar devolução automática de valores. (RF17, RN13, RN14)

#### Scenario: Cliente cancela reserva confirmada com antecedência
- **WHEN** o cliente cancela uma reserva `CONFIRMADA` que começa amanhã
- **THEN** a resposta é 200 com status `CANCELADA` e `canceladoPor` igual a `CLIENTE`
- **AND** o slot volta a aparecer como `LIVRE`
- **AND** nenhuma devolução de valor é feita pelo sistema

#### Scenario: Cliente cancela fora do prazo
- **WHEN** o cliente tenta cancelar uma reserva `CONFIRMADA` que começa em 1 hora
- **THEN** a resposta é 422 com `subcodigo` `CANCELAMENTO_FORA_DO_PRAZO`
- **AND** a reserva permanece `CONFIRMADA`

#### Scenario: Cliente cancela reserva pendente
- **WHEN** o cliente cancela uma reserva `PENDENTE_PAGAMENTO` a qualquer momento antes de ela expirar
- **THEN** a resposta é 200 com status `CANCELADA`
- **AND** a cobrança associada passa a `CANCELADO`

### Requirement: Cancelamento pelo dono com motivo obrigatório
O sistema SHALL permitir que o dono da quadra cancele reservas recebidas nela até o instante de
início, gravando `CanceladoPor` igual a `DONO`. O motivo SHALL ser obrigatório para o dono, com 1 a
200 caracteres; a ausência do motivo SHALL responder 400 com `codigo` `VALIDACAO`. Cancelar depois
do início SHALL responder 422 com `subcodigo` `CANCELAMENTO_FORA_DO_PRAZO`. Um DONO que não é o dono
da quadra SHALL receber 403 com `codigo` `ACESSO_NEGADO`. (RF17, RN03, RN13)

#### Scenario: Dono cancela com motivo
- **WHEN** o dono da quadra cancela uma reserva futura informando o motivo
- **THEN** a resposta é 200 com status `CANCELADA`, `canceladoPor` igual a `DONO` e o motivo gravado

#### Scenario: Dono cancela sem motivo
- **WHEN** o dono da quadra tenta cancelar sem informar o motivo
- **THEN** a resposta é 400 com `codigo` `VALIDACAO`
- **AND** a reserva permanece inalterada

#### Scenario: Dono cancela depois do início
- **WHEN** o dono tenta cancelar uma reserva cujo início já passou
- **THEN** a resposta é 422 com `subcodigo` `CANCELAMENTO_FORA_DO_PRAZO`

### Requirement: Transições de status resistentes a concorrência
Toda mudança de status de reserva SHALL ser aplicada condicionada ao status esperado, em uma única
operação atômica no banco, e SHALL NOT ser feita lendo a reserva, alterando em memória e gravando de
volta. Quando a operação não altera nenhuma linha porque outro fluxo já mudou o status, o sistema
SHALL responder 422 com `codigo` `REGRA_NEGOCIO` e `subcodigo` `TRANSICAO_INVALIDA` se o pedido veio
de um usuário, e SHALL tratar como operação sem efeito, apenas registrando em log, se o pedido veio
de um processo interno. (RN12, RN15)

#### Scenario: Cancelar uma reserva que acabou de ser confirmada
- **WHEN** o cliente pede o cancelamento no mesmo instante em que o pagamento é confirmado, e a confirmação vence a corrida
- **THEN** o cancelamento responde 422 com `subcodigo` `TRANSICAO_INVALIDA`
- **AND** uma consulta seguinte mostra a reserva `CONFIRMADA`

#### Scenario: Cancelar uma reserva já cancelada
- **WHEN** o cliente pede o cancelamento de uma reserva que já está `CANCELADA`
- **THEN** a resposta é 422 com `subcodigo` `TRANSICAO_INVALIDA`

### Requirement: Transições permitidas da reserva
O status de uma reserva SHALL seguir exclusivamente as transições: de inexistente para
`PENDENTE_PAGAMENTO` na criação; de `PENDENTE_PAGAMENTO` para `CONFIRMADA` por pagamento
confirmado, para `EXPIRADA` pelo ciclo de expiração ou para `CANCELADA` por cliente, dono ou
sistema; de `CONFIRMADA` para `CANCELADA` dentro dos prazos; e de `EXPIRADA` para `CONFIRMADA`
apenas por pagamento recebido com atraso quando o slot ainda estiver livre. `CANCELADA` SHALL ser
terminal. Qualquer outra transição SHALL ser recusada. (RN10, RN12, RN13, RN14, RN17)

#### Scenario: Reserva cancelada não volta atrás
- **WHEN** qualquer fluxo tenta mudar o status de uma reserva `CANCELADA`
- **THEN** a reserva permanece `CANCELADA`

#### Scenario: Reserva expirada volta a confirmada por pagamento tardio
- **WHEN** um pagamento é recebido para uma reserva `EXPIRADA` cujo slot continua livre
- **THEN** a reserva passa a `CONFIRMADA`

### Requirement: Agenda da quadra para o dono
O sistema SHALL expor `GET /api/v1/quadras/{id}/reservas` para o dono da quadra, aceitando filtro
opcional por data e devolvendo, para cada reserva, o horário, o valor, o status e o nome e telefone
cadastrais do cliente. Sem o filtro de data, SHALL devolver as próximas reservas. Um DONO que não é
o dono da quadra SHALL receber 403 com `codigo` `ACESSO_NEGADO`, e quadra inexistente SHALL
responder 404. A resposta SHALL NOT conter dados do pagador Pix. (RF18, RN03, RN05)

#### Scenario: Dono consulta a agenda de uma data
- **WHEN** o dono consulta as reservas da própria quadra para uma data com uma reserva confirmada
- **THEN** a resposta é 200 com essa reserva, incluindo horário, valor, status, nome e telefone do cliente

#### Scenario: Agenda de quadra de outro dono
- **WHEN** um DONO consulta as reservas de uma quadra de outro dono
- **THEN** a resposta é 403 com `codigo` `ACESSO_NEGADO`
