## Purpose

Permite que o dono de uma quadra declare em que dias e faixas de hora ela abre, o que define quais
slots existem para reserva; um dia sem faixa declarada significa que a quadra está fechada nesse dia.

## ADDED Requirements

### Requirement: Uma faixa de funcionamento por dia da semana
O sistema SHALL aceitar no máximo uma faixa de funcionamento por par de quadra e dia da semana. O
dia da semana SHALL ser um inteiro de 1 a 7, com 1 representando segunda-feira e 7 representando
domingo. Um dia sem faixa cadastrada SHALL significar quadra fechada nesse dia. Não SHALL haver
suporte a duas faixas no mesmo dia, a faixa que atravessa a meia-noite nem a exceção por data
específica. (RF11, RN19)

#### Scenario: Dia sem faixa é dia fechado
- **WHEN** uma quadra não tem faixa cadastrada para o dia 7
- **THEN** a consulta de horários dessa quadra não traz entrada para o dia 7
- **AND** a grade de slots desse dia vem inteiramente fechada

#### Scenario: Dia fora do intervalo é rejeitado
- **WHEN** o dono envia uma faixa com dia da semana igual a 0 ou a 8
- **THEN** a resposta é 400 com `codigo` `VALIDACAO`

### Requirement: Faixa com hora de fechamento posterior à de abertura
O sistema SHALL exigir que a hora de fechamento seja estritamente posterior à hora de abertura, e
SHALL exigir que ambas caiam em hora cheia. O último slot reservável do dia SHALL começar uma hora
antes do fechamento. (RF11, RN19, RN06)

#### Scenario: Fechamento anterior ou igual à abertura
- **WHEN** o dono envia uma faixa com abertura às 22:00 e fechamento às 08:00
- **THEN** a resposta é 400 com `codigo` `VALIDACAO`

#### Scenario: Último slot do dia
- **WHEN** uma quadra abre às 08:00 e fecha às 22:00 em um dia
- **THEN** o último slot reservável desse dia começa às 21:00 e termina às 22:00

### Requirement: Criação de faixa de funcionamento
O sistema SHALL permitir que o dono da quadra crie uma faixa em
`POST /api/v1/quadras/{id}/horarios-funcionamento`, respondendo 201 com a faixa criada. Tentar criar
uma segunda faixa para um dia que já tem faixa SHALL responder 409 com `codigo` `DIA_JA_CADASTRADO`.
Apenas o dono da quadra SHALL poder criar; outro DONO SHALL receber 403 com `codigo`
`ACESSO_NEGADO`, e um CLIENTE SHALL receber 403. (RF11, RN03, RN19)

#### Scenario: Faixa criada para um dia livre
- **WHEN** o dono cria uma faixa para o dia 6 com abertura às 08:00 e fechamento às 22:00
- **THEN** a resposta é 201 com a faixa criada

#### Scenario: Dia já cadastrado
- **WHEN** o dono tenta criar uma segunda faixa para um dia que já tem faixa
- **THEN** a resposta é 409 com `codigo` `DIA_JA_CADASTRADO`
- **AND** a faixa existente permanece inalterada

#### Scenario: Quadra de outro dono
- **WHEN** um DONO tenta criar faixa em quadra de outro dono
- **THEN** a resposta é 403 com `codigo` `ACESSO_NEGADO`

### Requirement: Leitura das faixas de funcionamento
O sistema SHALL permitir que qualquer usuário autenticado liste as faixas de uma quadra em
`GET /api/v1/quadras/{id}/horarios-funcionamento`, devolvendo de zero a sete entradas, cada uma com
identificador, quadra, dia da semana, hora de abertura e hora de fechamento. Quadra inexistente
SHALL responder 404. (RF11)

#### Scenario: Quadra sem nenhuma faixa
- **WHEN** um usuário autenticado consulta os horários de uma quadra recém-criada
- **THEN** a resposta é 200 com uma lista vazia

### Requirement: Alteração de faixa de funcionamento
O sistema SHALL permitir que o dono altere a hora de abertura e a hora de fechamento de uma faixa em
`PUT /api/v1/quadras/{id}/horarios-funcionamento/{hid}`, respondendo 200 com a faixa atualizada.
Faixa inexistente ou pertencente a outra quadra SHALL responder 404. Apenas o dono SHALL poder
alterar. (RF11, RN03)

#### Scenario: Hora de fechamento ampliada
- **WHEN** o dono altera o fechamento de 22:00 para 23:00 em um dia sem conflito
- **THEN** a resposta é 200 com o fechamento novo
- **AND** a grade de slots desse dia passa a incluir o slot das 22:00

### Requirement: Alteração que deixaria reserva ativa fora do funcionamento é bloqueada
O sistema SHALL recusar a alteração de uma faixa quando a nova faixa deixaria ao menos uma reserva
ativa futura daquele dia da semana fora do horário de funcionamento, respondendo 409 com `codigo`
`HORARIO_COM_RESERVAS`. Ampliar a faixa SHALL ser sempre permitido. (RF11, RN16)

#### Scenario: Redução de faixa com reserva afetada
- **WHEN** existe uma reserva ativa futura às 21:00 e o dono tenta mudar o fechamento de 22:00 para 20:00
- **THEN** a resposta é 409 com `codigo` `HORARIO_COM_RESERVAS`
- **AND** a faixa permanece inalterada

#### Scenario: Redução de faixa sem reserva afetada
- **WHEN** não há reserva ativa futura na parte da faixa que seria removida
- **THEN** a alteração responde 200

### Requirement: Remoção de faixa de funcionamento
O sistema SHALL permitir que o dono remova uma faixa em
`DELETE /api/v1/quadras/{id}/horarios-funcionamento/{hid}`, respondendo 204 e fazendo o dia voltar a
ser fechado. A remoção SHALL ser recusada com 409 e `codigo` `HORARIO_COM_RESERVAS` quando existir
reserva ativa futura naquele dia da semana. (RF11, RN16, RN19)

#### Scenario: Remoção libera o dia
- **WHEN** o dono remove a faixa do dia 7 sem reservas ativas futuras nesse dia
- **THEN** a resposta é 204
- **AND** a grade de slots do próximo domingo vem inteiramente fechada

#### Scenario: Remoção bloqueada por reserva futura
- **WHEN** existe reserva ativa futura em um domingo e o dono tenta remover a faixa do dia 7
- **THEN** a resposta é 409 com `codigo` `HORARIO_COM_RESERVAS`
- **AND** a faixa permanece cadastrada

### Requirement: Operações individuais e independentes
Cada uma das quatro operações sobre faixas de funcionamento SHALL ser exposta como um endpoint
próprio e SHALL poder ser executada isoladamente, sem depender de envio do conjunto completo dos
sete dias. (RF11)

#### Scenario: Ligar, alterar e desligar um dia
- **WHEN** o consumidor cria a faixa de um dia, depois altera sua hora de fechamento e depois a remove
- **THEN** cada passo corresponde a uma chamada independente e as demais faixas da quadra permanecem inalteradas
