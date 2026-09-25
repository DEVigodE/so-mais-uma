## Purpose

Mostra, para uma quadra e uma data, quais blocos de uma hora estão livres, ocupados, já passados ou
fora do horário de funcionamento, para que o cliente escolha um horário antes de reservar.

## ADDED Requirements

### Requirement: Grade de slots de 60 minutos por quadra e data
O sistema SHALL expor `GET /api/v1/quadras/{id}/slots?data=<AAAA-MM-DD>` para qualquer usuário
autenticado, respondendo 200 com a lista de slots daquela data. Cada slot SHALL ter início, fim,
valor e status. Todo slot SHALL começar em hora cheia e durar exatamente 60 minutos, e o valor de
cada slot SHALL ser o preço por hora vigente da quadra. Os slots SHALL ser calculados a cada
requisição e SHALL NOT ser persistidos. (RF12, RN06, RN07)

#### Scenario: Quadra aberta das 08:00 às 22:00
- **WHEN** um usuário autenticado consulta a grade de um dia em que a quadra abre às 08:00 e fecha às 22:00
- **THEN** a resposta é 200 com 14 slots
- **AND** o primeiro começa às 08:00 e o último começa às 21:00 e termina às 22:00
- **AND** cada slot traz o preço por hora atual da quadra como valor

#### Scenario: Slots nunca são armazenados
- **WHEN** a mesma grade é consultada duas vezes sem nenhuma reserva no intervalo
- **THEN** as duas respostas são equivalentes e nenhum registro de slot é criado no banco

### Requirement: Estados possíveis de um slot
Cada slot SHALL ter exatamente um dos quatro status de `StatusSlot`: `FECHADO` quando o horário está
fora da faixa de funcionamento do dia ou o dia não tem faixa cadastrada; `PASSADO` quando o início
do slot já passou em relação ao instante atual; `OCUPADO` quando existe reserva ativa
(`PENDENTE_PAGAMENTO` ou `CONFIRMADA`) para aquela quadra e aquele início; e `LIVRE` nos demais
casos. (RF12, RN08, RN09, RN19)

#### Scenario: Slot com reserva ativa vem ocupado
- **WHEN** existe uma reserva `CONFIRMADA` para o slot das 19:00 da data consultada
- **THEN** esse slot vem com status `OCUPADO`

#### Scenario: Reserva encerrada libera o slot
- **WHEN** a única reserva do slot das 19:00 está `CANCELADA` ou `EXPIRADA`
- **THEN** esse slot vem com status `LIVRE`

#### Scenario: Horas já passadas de hoje
- **WHEN** a data consultada é hoje e o instante atual é 14:30
- **THEN** os slots que começam às 08:00 até às 14:00 vêm com status `PASSADO`
- **AND** o slot das 15:00 em diante vem com `LIVRE` ou `OCUPADO`, conforme as reservas

#### Scenario: Dia sem faixa de funcionamento
- **WHEN** a data consultada cai em um dia da semana sem faixa cadastrada para a quadra
- **THEN** todos os slots do dia vêm com status `FECHADO`

### Requirement: Janela de consulta limitada a quinze dias
O sistema SHALL aceitar consulta de grade apenas para datas entre hoje e hoje mais 14 dias,
inclusive. Data além desse limite SHALL responder 422 com `codigo` `REGRA_NEGOCIO` e `subcodigo`
`DATA_FORA_DA_JANELA`. Data em formato inválido SHALL responder 400 com `codigo` `VALIDACAO`.
(RF12, RN09)

#### Scenario: Data além da janela
- **WHEN** um usuário consulta a grade para hoje mais 15 dias
- **THEN** a resposta é 422 com `codigo` `REGRA_NEGOCIO` e `subcodigo` `DATA_FORA_DA_JANELA`

#### Scenario: Último dia da janela é aceito
- **WHEN** um usuário consulta a grade para hoje mais 14 dias
- **THEN** a resposta é 200 com a grade daquele dia

#### Scenario: Data malformada
- **WHEN** um usuário consulta a grade com `data=10-10-2026`
- **THEN** a resposta é 400 com `codigo` `VALIDACAO`

### Requirement: Grade sempre no fuso de referência
O sistema SHALL montar a grade no fuso `America/Sao_Paulo`, independentemente do fuso de quem
consulta, e SHALL devolver os instantes de início e fim com o offset correspondente a esse fuso.
(RF12, RNF12)

#### Scenario: Consulta feita de outro fuso
- **WHEN** um consumidor em outro fuso pede a grade de uma data
- **THEN** os slots devolvidos correspondem às horas locais da quadra no fuso de referência
- **AND** cada instante vem com o offset desse fuso

### Requirement: Grade de quadra inexistente ou inativa
O sistema SHALL responder 404 com `codigo` `NAO_ENCONTRADO` quando a grade é pedida para uma quadra
inexistente ou para uma quadra inativa consultada por quem não é o seu dono. (RF12, RN09)

#### Scenario: Grade de quadra desativada
- **WHEN** um CLIENTE consulta a grade de uma quadra que foi desativada
- **THEN** a resposta é 404 com `codigo` `NAO_ENCONTRADO`

### Requirement: Grade é melhor esforço, não reserva
A grade SHALL ser informativa: um slot devolvido como `LIVRE` SHALL NOT garantir que a reserva será
aceita, porque outro cliente pode ocupá-lo entre a consulta e a criação da reserva. A garantia de
exclusividade SHALL ficar exclusivamente na criação da reserva. (RF12, RN08, RNF11)

#### Scenario: Slot livre na grade e ocupado na reserva
- **WHEN** um cliente vê um slot `LIVRE` e outro cliente reserva esse slot antes dele
- **THEN** a tentativa de reserva do primeiro responde 409 com `codigo` `HORARIO_INDISPONIVEL`
- **AND** uma nova consulta da grade mostra o slot como `OCUPADO`
