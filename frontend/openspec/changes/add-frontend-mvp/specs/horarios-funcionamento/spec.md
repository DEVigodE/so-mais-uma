## Purpose

Permite que o DONO defina em quais dias e faixas de hora cada quadra abre. A tela tem 7 cartões e um único
botão de salvar, mas cada mudança chega ao backend como uma operação individual de criação, alteração ou
remoção da faixa daquele dia. Isso preserva a evidência do segundo CRUD completo do critério 3.

## ADDED Requirements

### Requirement: Fidelidade de HorariosQuadra ao protótipo
HorariosQuadra (`/dono/quadras/:id/horarios`) SHALL reproduzir
`docs/Protótipo de Alta Fidelidade/hor_rios_de_funcionamento/code.html`:
- barra com voltar, logo, título "Horários De Funcionamento" e avatar;
- cartão da quadra com a etiqueta de esporte, o nome, o ícone de estádio e o aviso "Os horários seguem o fuso
  oficial de Brasília (Horário de Brasília).";
- cartão "Agilidade na configuração" / "Replicar horários padrão para a semana" com o botão "Copiar";
- aviso "O horário de fechamento deve ser posterior ao de abertura (intervalos regulares de 60 minutos).";
- 7 cartões, de "Segunda-feira" a "Domingo";
- botão "Salvar Horários de Funcionamento".

Cada cartão de dia SHALL ter o ponto de estado, o switch com o rótulo "Aberto" ou "Fechado" e os seletores
"Abre <HH:mm>" às "Fecha <HH:mm>". Dia fechado SHALL esmaecer o cartão, esconder os seletores e mostrar
"Quadra fechada neste dia". O botão de ajuda SHALL ser omitido. O fechamento SHALL ir no máximo até 23:00,
porque o 00:00 do exemplo do protótipo viola RN19. (RF11, RN19, RNF12)

#### Scenario: Dia fechado
- **GIVEN** a quadra sem faixa no domingo
- **WHEN** a tela é exibida
- **THEN** o cartão "Domingo" aparece esmaecido, com "Fechado" e "Quadra fechada neste dia", sem seletores de hora

#### Scenario: Limite do fechamento
- **WHEN** o DONO abre o seletor de fechamento de um dia
- **THEN** a última opção oferecida é 23:00

### Requirement: Carga das faixas de funcionamento
A tela SHALL mostrar na hora as faixas guardadas em `horarios_json` da quadra no escopo `MINHAS`. Com rede,
SHALL sincronizar com `GET /quadras/{id}/horarios-funcionamento`. Dia sem registro SHALL aparecer fechado.
Quadra sem nenhuma faixa SHALL mostrar os 7 dias fechados e a dica "Ative os dias em que a quadra funciona".
Falha de carga sem cache SHALL mostrar a caixa de erro com "Tentar novamente". (RF11, RN19, CT-14)

#### Scenario: Quadra recém-criada
- **GIVEN** uma quadra recém-criada, sem faixas
- **WHEN** o DONO abre Horários
- **THEN** os 7 dias aparecem fechados com a dica "Ative os dias em que a quadra funciona"

### Requirement: Edição local dos dias
A edição local SHALL seguir estas regras:
- ligar um dia fechado preenche 08:00 às 22:00, ou a faixa anterior se o dia já teve uma nesta edição;
- os seletores oferecem só horas cheias, de 00:00 a 22:00 para abertura e de 01:00 a 23:00 para
  fechamento;
- antes de salvar, cada dia aberto exige fechamento depois da abertura;
- um dia inválido mostra no próprio cartão "O fechamento precisa ser depois da abertura".

Nenhuma alteração local SHALL chamar a API antes de "Salvar Horários de Funcionamento". (RF11, RN19, RN06)

#### Scenario: Fechamento antes da abertura
- **WHEN** o DONO define abertura às 22:00 e fechamento às 08:00 na segunda-feira e toca salvar
- **THEN** o cartão da segunda-feira mostra "O fechamento precisa ser depois da abertura"
- **AND** nenhuma requisição é enviada

### Requirement: Replicar horários para a semana
"Copiar" SHALL copiar a faixa da segunda-feira para os outros 6 dias, abri-los e mostrar
"Horário copiado para todos os dias!". Nada é salvo até o DONO tocar o botão de salvar. O botão "Copiar"
SHALL ficar desabilitado quando a segunda-feira está fechada. (RF11)

#### Scenario: Copiar a segunda
- **GIVEN** a segunda-feira aberta das 07:00 às 23:00 e o domingo fechado
- **WHEN** o DONO toca "Copiar"
- **THEN** os 7 dias ficam abertos das 07:00 às 23:00 e aparece "Horário copiado para todos os dias!"

### Requirement: Salvamento em lote por operações individuais
"Salvar Horários de Funcionamento" SHALL comparar o estado da tela com as faixas do servidor e montar, dia a
dia, uma lista de operações individuais:
- `POST /quadras/{id}/horarios-funcionamento` para dia aberto sem faixa no servidor;
- `PUT /quadras/{id}/horarios-funcionamento/{hid}` para faixa alterada;
- `DELETE /quadras/{id}/horarios-funcionamento/{hid}` para dia fechado que tinha faixa.

Quando a lista inclui algum fechamento, o app SHALL pedir confirmação antes, nomeando os dias (por exemplo
"Fechar a quadra na segunda-feira e no domingo?").

As operações SHALL rodar em sequência, na ordem de segunda a domingo, com o botão mostrando "Salvando...".
Concluídas sem falha, o app SHALL:
- mostrar "Horários salvos com sucesso!";
- sincronizar a quadra no cache.

Sem alteração, o botão SHALL ficar desabilitado. (RF11, CT-14)

#### Scenario: Três operações em um salvamento
- **GIVEN** a segunda sem faixa, a terça das 08:00 às 22:00 e o domingo das 08:00 às 18:00 no servidor
- **WHEN** o DONO abre a segunda das 08:00 às 22:00, muda a terça para 09:00 às 22:00, fecha o domingo e salva
- **THEN** o app pede confirmação para fechar o domingo
- **AND** depois envia um `POST` da segunda, um `PUT` da terça e um `DELETE` do domingo, nessa ordem
- **AND** mostra "Horários salvos com sucesso!"

#### Scenario: Cada operação aparece separada no backend
- **WHEN** um salvamento altera dois dias
- **THEN** o backend recebe duas requisições independentes, uma por dia, e as demais faixas permanecem intactas

### Requirement: Conflitos e falhas por linha
Um erro em uma operação SHALL afetar apenas o dia correspondente:
- **409 `HORARIO_COM_RESERVAS`**: volta só aquele dia ao valor do servidor e, ao fim da sequência, abre o
  diálogo "Há reservas futuras nesse horário. Cancele-as antes de reduzir ou fechar o dia." com o atalho
  "Ver reservas" para a ReservasQuadra da quadra;
- **409 `DIA_JA_CADASTRADO`**: recarrega as faixas do servidor e marca o dia;
- **400 `VALIDACAO`**: mostra a mensagem no cartão do dia;
- **falha de rede**: interrompe a sequência, mantém como alteração pendente os dias que não foram enviados e
  mostra "Algumas alterações não foram salvas. Tente novamente.".

As operações que já deram certo SHALL permanecer salvas. (RF11, RN16, CT-15)

#### Scenario: Reduzir horário com reserva ativa
- **GIVEN** uma reserva `CONFIRMADA` amanhã às 19:00, que cai em uma terça-feira
- **WHEN** o DONO muda a terça para 08:00 às 18:00, muda a quarta para 09:00 às 22:00 e salva
- **THEN** a quarta é salva
- **AND** a terça volta para a faixa do servidor e aparece o diálogo com o atalho "Ver reservas"

### Requirement: Descartar alterações de horários
Sair de HorariosQuadra com alterações não salvas SHALL abrir o diálogo "Descartar alterações?" com
"Continuar editando" e "Descartar". (RNF06)

#### Scenario: Saída com dia alterado
- **GIVEN** o DONO ligou o sábado e não salvou
- **WHEN** ele toca voltar
- **THEN** aparece "Descartar alterações?"

### Requirement: HorariosQuadra sem conexão
Sem conexão com o backend, a tela SHALL exibir as faixas do cache com switches, seletores, "Copiar" e o botão
de salvar desabilitados, e o banner de modo cache. (RNF11, RF23, CT-28)

#### Scenario: Leitura em modo avião
- **GIVEN** o aparelho em modo avião
- **WHEN** o DONO abre Horários de uma quadra sincronizada antes
- **THEN** os 7 dias aparecem com os valores do cache e nenhum controle de edição está habilitado

### Requirement: Acessibilidade de HorariosQuadra
Cada cartão SHALL ser lido como uma unidade, por exemplo "Segunda-feira, aberto das 8h às 22h" ou
"Domingo, fechado". O switch SHALL ter o rótulo do dia. Os seletores SHALL anunciar se são de abertura ou de
fechamento. (RNF07)

#### Scenario: Cartão lido pelo TalkBack
- **GIVEN** o TalkBack ligado e a segunda aberta das 08:00 às 22:00
- **WHEN** o foco chega ao cartão da segunda-feira
- **THEN** o leitor anuncia "Segunda-feira, aberto das 8h às 22h"
