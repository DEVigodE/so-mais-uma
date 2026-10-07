## Purpose

Permite que o DONO veja as reservas recebidas nas próprias quadras, de todas ou de uma quadra, por data, com
um resumo do dia calculado da lista e o contato cadastral do cliente. O DONO também pode cancelar uma
reserva até o início, informando o motivo, sem nunca ver dados de quem pagou o Pix.

## ADDED Requirements

### Requirement: Fidelidade de ReservasQuadra ao protótipo
ReservasQuadra (`/dono/reservas` como aba e `/dono/quadras/:id/reservas` por quadra) SHALL reproduzir
`docs/Protótipo de Alta Fidelidade/reservas_da_quadra_dono/code.html`. A tela SHALL ter, de cima para baixo:
- barra com o logo, "Só mais uma", a etiqueta "DONO", o subtítulo "Reservas" e o avatar;
- faixa de sincronização com o ponto pulsante, "Modo sincronizado • Atualizado <quando>" ou, sem conexão,
  "Modo cache ativo • Atualizado <quando>", e o botão de atualizar;
- cabeçalho "Reservas da Arena" / "Gerenciamento de horários agendados e cancelamentos";
- resumo do dia em três blocos: "Agendadas", "Aguardando" e "Previsão";
- "Data selecionada" com "Outro dia" e a faixa de datas, cada data com "Hoje" ou o dia da semana sobre
  "dd Mês";
- chips "Todas as quadras (N)" e um chip por quadra com o ícone do esporte e o nome;
- linha "Horários de Hoje (N registros)" (ou "Horários de dd/MM (N registros)") com "Ordem cronológica";
- cards de reserva;
- cartão "Regras de cancelamento pelo Dono" com o texto do protótipo.

O card SHALL ter:
- barra lateral na cor do status;
- faixa "19:00 – 20:00" com "60 min" e a etiqueta de status;
- nome da quadra e valor;
- linha de situação do pagamento;
- bloco do cliente com iniciais, nome, etiqueta "Titular", telefone e os botões de ligar e de WhatsApp;
- "Observação do atleta:" com o texto ou "Nenhuma observação informada.";
- rodapé com "Cód: #RES-<id>" e o botão de cancelar.

Elementos omitidos:
- o sino de notificações;
- o botão de baixar relatório;
- as marcações "(RN03)" e "(RN13 / RN14)";
- a frase "Estorno direto com arena realizado (RN14)", que afirma um fato sem dado.

(RF18, RF17, RN03, RN05)

#### Scenario: Sem download e sem notificações
- **WHEN** a ReservasQuadra é exibida
- **THEN** não há botão de baixar relatório nem botão de notificações
- **AND** o cartão de regras tem o título "Regras de cancelamento pelo Dono", sem marcação de regra

### Requirement: Fontes de dados por data e por quadra
As datas da faixa SHALL ir de hoje até hoje mais 14 dias. Nessas datas, a lista SHALL vir de `reserva_cache`,
sincronizado por `GET /reservas`, filtrada pela data, no fuso de Brasília, e pelo chip de quadra. Aberta por
uma quadra em MinhasQuadras, a tela SHALL começar com o chip daquela quadra selecionado.

"Outro dia" SHALL abrir um seletor de data para qualquer dia fora da faixa. A data escolhida SHALL ser
consultada só online, com `GET /quadras/{id}/reservas?data=<AAAA-MM-DD>`, uma chamada por quadra do filtro,
sem gravar no cache. Sem conexão, "Outro dia" SHALL ficar desabilitado.

A lista SHALL estar em ordem crescente de início e incluir as reservas canceladas e expiradas do dia. O
comportamento por estado SHALL ser:
- **dia sem reservas**: "Nenhuma reserva nesta data";
- **falha de carga**: a caixa de erro com "Tentar novamente";
- **atualização**: o gesto de puxar e o botão de atualizar sincronizam de novo.

(RF18, RF23, CT-27)

#### Scenario: Reservas de amanhã de uma quadra
- **GIVEN** o DONO com uma reserva `CONFIRMADA` amanhã às 19:00 na quadra "Quadra Teste Usabilidade"
- **WHEN** ele abre Reservas dessa quadra e toca a data de amanhã
- **THEN** o card mostra 19:00 – 20:00, "Confirmada", o valor, o nome e o telefone do cliente

#### Scenario: Data passada consultada online
- **WHEN** o DONO escolhe em "Outro dia" uma data do mês anterior
- **THEN** o app consulta `GET /quadras/{id}/reservas?data=` para cada quadra do filtro e mostra o resultado
- **AND** nada dessa consulta é gravado no cache

### Requirement: Resumo do dia calculado
Os três blocos SHALL ser calculados da lista exibida, ou seja, da data e do chip selecionados:
- **"Agendadas"**: a quantidade de reservas `CONFIRMADA`, com a ocupação "<p>% ocupado" igual às reservas
  ativas (`CONFIRMADA` e `PENDENTE_PAGAMENTO`) divididas pelos slots do dia das quadras filtradas, segundo
  `horarios_json`;
- **"Aguardando"**: a quantidade de reservas `PENDENTE_PAGAMENTO`, com "Expira em Xm" pelo menor tempo
  restante até `expiraEm`;
- **"Previsão"**: a soma dos valores das reservas ativas, com o rótulo "Hoje total" quando a data é hoje e
  "Total do dia" nos demais casos.

(RF18, RN10)

#### Scenario: Resumo de hoje
- **GIVEN** hoje, nas quadras filtradas, 4 reservas `CONFIRMADA` de R$ 90,00, 1 `PENDENTE_PAGAMENTO` de R$ 90,00 que expira em 11 min e 1 `CANCELADA`, com 25 slots no dia
- **WHEN** a aba Reservas é exibida
- **THEN** "Agendadas" mostra 4 e "20% ocupado"
- **AND** "Aguardando" mostra 1 e "Expira em 11m"
- **AND** "Previsão" mostra R$ 450 e "Hoje total"

### Requirement: Card de reserva do dono
O card SHALL mostrar as seguintes informações, conforme o status:
- **etiqueta de status**: "Confirmada", "Aguardando Pix (<min> min)", "Cancelada pelo Atleta",
  "Cancelada pela Arena", "Cancelada pelo Sistema" ou "Expirada";
- **situação do pagamento, derivada do status**:
  - "Pago via Pix • Transação conciliada" para `CONFIRMADA` futura;
  - "Pago via Pix • Concluído" para `CONFIRMADA` encerrada;
  - "Pix Gerado • Aguardando compensação automática" para `PENDENTE_PAGAMENTO`.

O telefone SHALL aparecer formatado. O botão de ligar SHALL abrir o discador com `tel:<dígitos>`, e o de
WhatsApp SHALL abrir `https://wa.me/55<dígitos>`. Os dois botões SHALL ficar ocultos quando o telefone é nulo.

Reserva cancelada SHALL ficar esmaecida, com o horário riscado, a etiqueta "Horário Liberado", o valor
riscado e a linha "Cliente: <nome> • Motivo: "<motivo>"".

O card SHALL NOT mostrar nenhum dado de quem pagou o Pix. (RF18, RN05, CT-27)

#### Scenario: Ligar para o cliente
- **WHEN** o DONO toca o botão de ligar de um card cujo telefone é `11987654321`
- **THEN** o discador abre com `11987654321`, sem pedir permissão de chamada

#### Scenario: Cliente sem telefone
- **GIVEN** uma reserva de um cliente que não informou telefone
- **WHEN** o card é exibido
- **THEN** os botões de ligar e de WhatsApp não aparecem

### Requirement: Cancelamento pelo dono
O botão do card SHALL ser "Cancelar Reserva" para `CONFIRMADA` e "Desistir / Cancelar" para
`PENDENTE_PAGAMENTO`. Ele SHALL existir só enquanto o início não passou. O botão SHALL abrir o sheet do
protótipo, com:
- ícone, título "Cancelar Reserva" e "Confirme o cancelamento do horário";
- resumo Cliente, Horário, Quadra e Valor;
- aviso "Atenção: Esta reserva foi quitada. Após o cancelamento, combine o estorno diretamente com o cliente
  por chave Pix ou remarcação.", só para `CONFIRMADA`;
- seleção "Motivo do cancelamento (visível ao cliente):" com "Manutenção emergencial da quadra",
  "Condições climáticas adversas (chuva/tempestade)", "Acordo amigável de horário com o atleta" e
  "Outro motivo operacional";
- botões "Voltar" e "Confirmar".

"Outro motivo operacional" SHALL abrir um campo de texto de 5 a 200 caracteres. As demais opções SHALL
enviar o próprio texto como motivo. Confirmar SHALL enviar `POST /reservas/{id}/cancelar` com `{motivo}`. O
comportamento por resultado SHALL ser:
- **2xx**: atualiza o cache, mostra "Reserva cancelada e slot liberado com sucesso!" e recalcula o resumo;
- **422 `CANCELAMENTO_FORA_DO_PRAZO`**: mostra "O horário já começou e não pode mais ser cancelado";
- **422 `TRANSICAO_INVALIDA`**: mostra "A reserva mudou de situação" e recarrega;
- **400 `VALIDACAO`**: marca o campo do motivo.

Sem conexão, o botão SHALL ficar desabilitado. (RF17, RN03, RN13, RN14, CT-26)

#### Scenario: Dono cancela com motivo da lista
- **GIVEN** uma reserva `CONFIRMADA` amanhã
- **WHEN** o DONO escolhe "Manutenção emergencial da quadra" e confirma
- **THEN** a API recebe esse texto como `motivo` e o card passa a "Cancelada pela Arena"

#### Scenario: Outro motivo curto demais
- **WHEN** o DONO escolhe "Outro motivo operacional" e digita "chuva"
- **THEN** o motivo é aceito, porque tem 5 caracteres
- **AND** com "ok" o botão "Confirmar" fica desabilitado

### Requirement: Acessibilidade de ReservasQuadra
A tela SHALL atender a estes pontos:
- os botões de contato são anunciados como "Ligar para <nome>" e "Conversar com <nome> no WhatsApp";
- as datas e os chips anunciam o estado selecionado;
- o erro do motivo é anunciado;
- status e situação do pagamento são comunicados por texto.

(RNF07)

#### Scenario: Botão de ligar com nome
- **GIVEN** o TalkBack ligado e uma reserva de "Maria Souza"
- **WHEN** o foco chega ao botão de ligar
- **THEN** o leitor anuncia "Ligar para Maria Souza"
