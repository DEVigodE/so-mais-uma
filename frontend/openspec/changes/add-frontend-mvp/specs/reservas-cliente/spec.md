## Purpose

Leva o cliente da escolha de um horário até a reserva criada e permite acompanhar e gerir as próprias
reservas. Cobre:
- grade de slots com seleção do horário e confirmação da reserva;
- lista separada em próximas e histórico;
- detalhe com edição da observação e cancelamento dentro do prazo, por um sheet que exige o motivo.

## ADDED Requirements

### Requirement: Fidelidade da seleção de data e da grade ao protótipo
Abaixo da parte estática, a DetalheQuadra do CLIENTE SHALL reproduzir a parte inferior de
`docs/Protótipo de Alta Fidelidade/detalhe_da_quadra/code.html`:
- título "Escolha a Data" com o mês da data selecionada;
- faixa horizontal de datas, de hoje até hoje mais 14 dias. Cada data tem:
  - em cima, "Hoje", "Amanhã" ou a abreviação do dia da semana;
  - no meio, o número do dia;
  - embaixo, o dia da semana para hoje e amanhã, e o mês para as demais.
- título "Horários Disponíveis" com "Partidas de 60 min" e a legenda Livre, Ocupado e Passado;
- grade de slots em duas colunas;
- barra fixa inferior com "HORÁRIO SELECIONADO", o dia e a faixa do slot, "Total: <preço>" e o botão
  "Continuar".

Cada slot SHALL seguir o estado:
- `LIVRE`: horário na cor primária, "Disponível" e o preço em formato compacto;
- `LIVRE` selecionado: fundo primário com contorno, marca de confirmação e o preço completo;
- `OCUPADO`: "Reservado" com cadeado;
- `PASSADO`: horário riscado e esmaecido com o ícone de histórico.

Slots `FECHADO` SHALL ficar ocultos. A etiqueta "Recomendado" SHALL ser omitida. (RF12, RN06, RN09)

#### Scenario: Quatro estados na grade
- **GIVEN** hoje às 17:30, com a quadra aberta das 16:00 às 23:00 e uma reserva ativa às 18:00
- **WHEN** o cliente abre a DetalheQuadra com hoje selecionado
- **THEN** 16:00 e 17:00 aparecem riscados, 18:00 aparece como "Reservado" e os demais como "Disponível" com o preço
- **AND** nenhum slot `FECHADO` aparece e não existe etiqueta "Recomendado"

#### Scenario: Faixa de datas limitada
- **WHEN** o cliente rola a faixa de datas até o fim
- **THEN** a última data oferecida é hoje mais 14 dias

### Requirement: Grade de slots consultada a cada data
A grade SHALL ser obtida com `GET /quadras/{id}/slots?data=<AAAA-MM-DD>` para a data selecionada, começando
por hoje. Trocar de data SHALL descartar a resposta pendente da data anterior. Os slots SHALL NOT ir para o
cache local. A grade SHALL ser recarregada quando o app volta ao primeiro plano e quando a ConfirmarReserva
devolve o pedido de recarga.

O comportamento por estado SHALL ser:
- **carregando**: esqueleto de uma linha de slots;
- **data sem slot livre**: "Nenhum horário livre nesta data". A tela procura as datas seguintes em sequência,
  até hoje mais 14 dias, e, ao achar a primeira com slot livre, oferece o botão "Ver <dia da semana>,
  <dd/MM>", que seleciona essa data;
- **falha**: a caixa de erro com "Tentar novamente" só na área da grade;
- **sem conexão**: a área da grade mostra "Conecte-se para ver os horários";
- **422 `DATA_FORA_DA_JANELA`**: snackbar com a regra.

(RF12, RN09, RNF11, CT-16)

#### Scenario: Próxima data com horário livre
- **GIVEN** hoje e amanhã sem nenhum slot livre e um slot livre depois de amanhã
- **WHEN** o cliente seleciona hoje
- **THEN** aparece "Nenhum horário livre nesta data" com o botão que leva a depois de amanhã

#### Scenario: Grade offline
- **GIVEN** o aparelho em modo avião
- **WHEN** o cliente abre a DetalheQuadra
- **THEN** a parte estática aparece do cache, e a área da grade mostra "Conecte-se para ver os horários"
- **AND** não há barra de horário selecionado

### Requirement: Seleção do slot e barra Continuar
Tocar um slot `LIVRE` SHALL selecioná-lo, apenas um por vez, e mostrar a barra inferior:
- o dia como "Hoje", "Amanhã" ou "<dia da semana abreviado>, <dd/MM>";
- a faixa "19:00 - 20:00";
- "Total: <preço do slot>".

Tocar o slot selecionado de novo ou trocar de data SHALL desfazer a seleção e esconder a barra. Slots
`OCUPADO` e `PASSADO` SHALL ser inativos. "Continuar" SHALL abrir a ConfirmarReserva em
`/quadras/:id/reservar?inicio=<instante>`, com o instante ISO-8601 de offset `-03:00`, e aguardar o
resultado. Ao receber o pedido de recarga, a tela SHALL limpar a seleção e recarregar a grade.
(RF12, RF13, RN06, RN08)

#### Scenario: Selecionar e continuar
- **WHEN** o cliente toca o slot das 19:00 de amanhã e depois "Continuar"
- **THEN** a barra mostrou "Amanhã, 19:00 - 20:00" e "Total: R$ 90,00"
- **AND** a ConfirmarReserva abre com `inicio` igual a amanhã às `19:00:00-03:00`

#### Scenario: Slot ocupado não seleciona
- **WHEN** o cliente toca um slot "Reservado"
- **THEN** nada é selecionado e a barra não aparece

### Requirement: Fidelidade da ConfirmarReserva ao protótipo
A ConfirmarReserva SHALL reproduzir `docs/Protótipo de Alta Fidelidade/confirmar_reserva/code.html` no
estado anterior à criação da reserva:
- barra com voltar, logo, título "Confirmar Agendamento" e avatar;
- aviso com o ícone de informação: "Você terá 15 minutos para pagar via Pix; após esse período o horário
  será liberado automaticamente.";
- cartão de resumo com a imagem da quadra, a etiqueta de esporte, o nome, o endereço curto
  ("<logradouro>, <número> - <bairro>"), "Total" com o preço e o bloco "Data e Horário" no formato
  "Sábado, 10 de outubro de 2026 · 19:00 – 20:00";
- campo "Observações para a quadra (opcional)" com contador `0/200` e o placeholder do protótipo;
- botão principal "Confirmar e gerar Pix".

Os seguintes elementos do protótipo SHALL ficar fora desta tela, porque pertencem à tela Pagamento depois da
criação: a pílula "Aguardando Pagamento" com contador, o bloco "Pague com Pix" com QR, copia e cola e
"Como pagar", o botão "Já realizei o pagamento" e "Cancelar reserva". (RF13, RN10)

#### Scenario: Tela antes do POST
- **WHEN** a ConfirmarReserva é aberta
- **THEN** a tela mostra o resumo, o aviso de 15 minutos, o campo de observações e o botão "Confirmar e gerar Pix"
- **AND** não há QR Code, contador, "Já realizei o pagamento" nem "Cancelar reserva"

### Requirement: Criação da reserva
"Confirmar e gerar Pix" SHALL enviar `POST /reservas` com `{quadraId, inicio, observacao}`, com a observação
sem espaços nas pontas e omitida quando vazia. Até a resposta chegar, o botão SHALL mostrar progresso e
ignorar novos toques, para não haver POST duplicado. O comportamento por resultado SHALL ser:

| Resposta | Comportamento |
|---|---|
| 2xx | grava a reserva com a cobrança em `reserva_cache` e faz `go` para `/reservas/:id/pagamento` |
| 409 `HORARIO_INDISPONIVEL` | snackbar "Esse horário acabou de ser reservado. Escolha outro." e volta à DetalheQuadra com o pedido de recarga |
| 422 `RESERVA_PENDENTE_EXISTENTE` | diálogo "Você já tem uma reserva aguardando pagamento" com "Ir para a reserva", que faz `go` para `/reservas/<reservaId>` |
| 502 `PAGAMENTO_INDISPONIVEL` | diálogo "Não foi possível gerar a cobrança Pix. Tente novamente." e, ao fechar, volta à grade com o pedido de recarga |
| 422 `FORA_DO_FUNCIONAMENTO` ou `DATA_FORA_DA_JANELA` | snackbar com a regra e volta à grade com o pedido de recarga |
| 400 por início no passado | snackbar "Esse horário já passou. Escolha outro." e volta à grade |
| 404 | snackbar "Quadra não encontrada" e volta |

Sem conexão, o botão SHALL ficar desabilitado com "Conecte-se para reservar".
(RF13, RF19, RN08, RN10, RN11, RN17, CT-18, CT-19, CT-20, CT-23)

#### Scenario: Reserva criada
- **WHEN** o cliente confirma um slot livre
- **THEN** o app abre a tela Pagamento com o QR da cobrança
- **AND** o back físico não retorna à ConfirmarReserva

#### Scenario: Dois celulares no mesmo slot
- **GIVEN** dois clientes na ConfirmarReserva do mesmo slot
- **WHEN** os dois tocam "Confirmar e gerar Pix" quase ao mesmo tempo
- **THEN** um vai para a tela Pagamento
- **AND** o outro vê "Esse horário acabou de ser reservado. Escolha outro." e volta à grade recarregada com o slot como "Reservado"

#### Scenario: Cliente com reserva pendente
- **GIVEN** o cliente já tem uma reserva aguardando pagamento
- **WHEN** ele tenta confirmar outro horário
- **THEN** aparece o diálogo "Você já tem uma reserva aguardando pagamento"
- **AND** "Ir para a reserva" abre a DetalheReserva da pendente, com o botão "Pagar agora (Pix)"

#### Scenario: Gateway Pix indisponível
- **WHEN** a criação responde 502 `PAGAMENTO_INDISPONIVEL`
- **THEN** aparece "Não foi possível gerar a cobrança Pix. Tente novamente."
- **AND** ao fechar o diálogo a grade recarrega com o slot livre de novo

### Requirement: Fidelidade de MinhasReservas ao protótipo
MinhasReservas (`/reservas`) SHALL reproduzir `docs/Protótipo de Alta Fidelidade/minhas_reservas/code.html`:
- barra com o logo, o rótulo "SÓ MAIS UMA", o título "Minhas Reservas", a pílula de conexão ("Online" ou
  "Offline") e o avatar;
- cabeçalho "Minhas Reservas" com a pílula "Sincronizado há X min" e o subtítulo
  "Acompanhe seus jogos agendados e histórico de partidas.";
- abas segmentadas "Próximas" e "Histórico" com contadores;
- quando sem conexão, a faixa "Modo cache ativo" com "Última sincronização <quando>" e o botão
  "Atualizar dados";
- a lista de cards;
- o bloco "Histórico recente" com "Ver todos (N)";
- o cartão "Quer marcar mais uma partida?" com o botão "Encontrar novas quadras".

O card pendente SHALL ter:
- imagem com a etiqueta "Aguardando Pagamento" e o contador `mm:ss` até `expiraEm`;
- o rótulo curto do esporte e o valor sobre a imagem;
- nome, esporte, data e faixa, endereço;
- as ações "Pagar Agora (Pix)" e "Ver detalhes".

O card confirmado SHALL ter a etiqueta "Confirmada", a marca "Pago via Pix", que o status `CONFIRMADA`
implica, e as ações "Ver detalhes" e "Como chegar".

O texto do cartão final SHALL ser "Encontre quadras com horários livres para você e sua galera.", sem
números de quadras nem cidade inventados. O subtítulo de sub-quadra ("Quadra 1 (Coberta)") SHALL ser
omitido. (RF15, RF23)

#### Scenario: Sem números inventados
- **WHEN** MinhasReservas é exibida
- **THEN** o cartão final não menciona "Mais de 40 quadras" nem uma cidade

#### Scenario: Card confirmado com como chegar
- **GIVEN** uma reserva `CONFIRMADA` futura
- **WHEN** a aba Próximas é exibida
- **THEN** o card mostra "Confirmada", "Pago via Pix", "Ver detalhes" e "Como chegar"

### Requirement: Abas Próximas e Histórico
A lista SHALL vir de `reserva_cache`. A divisão entre as abas SHALL ser:
- **Próximas**: reservas `PENDENTE_PAGAMENTO` ou `CONFIRMADA` com fim no futuro, em ordem crescente de
  início;
- **Histórico**: as demais, em ordem decrescente de início. Uma reserva `CONFIRMADA` cujo fim já passou
  aparece como "Concluída".

Os contadores das abas SHALL ser o tamanho de cada lista. "Histórico recente" SHALL mostrar na aba Próximas
até 3 itens do histórico em formato compacto (ícone do esporte, nome, "dd de Mês • HH:mm", valor e etiqueta
de status), e "Ver todos (N)" SHALL trocar para a aba Histórico, que usa o mesmo formato compacto.

Quando o contador de um card pendente chega a zero, o card SHALL mostrar "Expirado" e desabilitar
"Pagar Agora (Pix)" até a próxima sincronização movê-lo para o histórico.

As ações e os estados SHALL ser:
- "Pagar Agora (Pix)" abre `/reservas/:id/pagamento`;
- "Ver detalhes" ou o toque no card abre `/reservas/:id`;
- "Encontrar novas quadras" vai para `/quadras`;
- Próximas vazia mostra "Você ainda não tem reservas" com "Encontrar quadra";
- Histórico vazio mostra "Nenhuma reserva anterior".

(RF15, RF14, RNF06, CT-22, CT-27)

#### Scenario: Separação entre abas
- **GIVEN** uma reserva `CONFIRMADA` amanhã, uma `CONFIRMADA` ontem e uma `EXPIRADA`
- **WHEN** MinhasReservas é exibida
- **THEN** a aba Próximas mostra 1 e a aba Histórico mostra 2
- **AND** a reserva de ontem aparece como "Concluída"

#### Scenario: Reserva expirada vai para o histórico
- **GIVEN** uma reserva pendente cujo prazo de pagamento acabou
- **WHEN** a lista é sincronizada depois que o backend a marcou como `EXPIRADA`
- **THEN** ela sai de Próximas e aparece no Histórico como "Expirada"

### Requirement: Dados da quadra nos cards de reserva
Como `ReservaResponse` não traz foto, esporte nem coordenadas, os cards e o detalhe da reserva SHALL obter
esses dados de `quadra_cache` pelo `quadraId`. Sem a quadra no cache, por exemplo quadra desativada:
- a imagem cai no placeholder;
- o esporte usa o ícone genérico e o rótulo é omitido;
- "Como chegar" usa o endereço da reserva.

(RF15, RF22)

#### Scenario: Reserva de quadra que saiu do catálogo
- **GIVEN** uma reserva antiga de uma quadra desativada, ausente do cache
- **WHEN** a reserva aparece no histórico
- **THEN** o card mostra o placeholder de imagem e o nome da quadra vindo da reserva

### Requirement: Fidelidade da DetalheReserva ao protótipo
A DetalheReserva (`/reservas/:id`) SHALL reproduzir `docs/Protótipo de Alta Fidelidade/detalhe_da_reserva/code.html`:
- barra com voltar, logo, título "Detalhe Da Reserva" e avatar;
- pílula de status ao lado de "Sincronizado há X min";
- caixa "Código da Reserva" com `#RES-<id>` e o botão "Copiar", que vira "Copiado!" por 2 s;
- cartão com o esporte, o nome, a etiqueta curta do esporte e a imagem;
- blocos "Data do Jogo" ("Sábado, 26 de Outubro de 2026") e "Horário Reservado"
  ("19:00 - 20:00 (60 minutos)");
- endereço e o botão "Como chegar";
- cartão "Informações do Pagamento" com a etiqueta de status, a linha "Pix" com `pagoEm` e o valor, e
  "ID da Transação (TxID)" com "Copiar";
- cartão "Observações para a quadra" com "Editar" e o texto "O dono da arena lerá estas instruções antes da
  partida.";
- cartão "Política de Cancelamento";
- botões "Cancelar Reserva" e "Voltar para Minhas Reservas".

A etiqueta de pagamento SHALL ser "Aguardando", "Liquidado", "Expirado" ou "Cancelado". A linha
"Aprovado pelo Banco Central • Liquidação instantânea" SHALL dar lugar ao rótulo do provedor, só quando o
pagamento está `PAGO`. Uma reserva `PENDENTE_PAGAMENTO` SHALL ganhar o botão "Pagar agora (Pix)", que abre a
tela Pagamento. Elementos omitidos:
- "Contatar Arena" e o WhatsApp da arena, porque a API não expõe o contato do dono;
- o mapa estático;
- o selo "Quadra Oficial 7x7 Homologada";
- "Baixar comprovante da reserva (PDF)";
- as marcações "(RN13)" e "Regra RN14:".

(RF15, RF16, RF17, RN14)

#### Scenario: Elementos sem dado não aparecem
- **WHEN** a DetalheReserva de uma reserva confirmada é exibida
- **THEN** não aparecem "Contatar Arena", WhatsApp, mapa, selo de quadra oficial nem botão de PDF
- **AND** o título da política é "Política de Cancelamento", sem "(RN13)"

### Requirement: Detalhe da reserva com cache e servidor
A DetalheReserva SHALL mostrar na hora a reserva guardada no cache. Com rede, SHALL buscar `GET /reservas/{id}`
e gravar a resposta, inclusive a cobrança embutida, no cache. O comportamento por resultado SHALL ser:
- **403**: a caixa de erro "Você não tem permissão para isso" com Voltar;
- **404**: a caixa de erro "Reserva não encontrada" com Voltar;
- **sem conexão**: os dados vêm do cache, editar e cancelar ficam desabilitados com
  "Conecte-se para alterar", e "Pagar agora (Pix)" continua disponível com o QR do cache.

"Voltar para Minhas Reservas" SHALL fazer `go` para `/reservas`. (RF15, RN04, RF23, CT-27, CT-28)

#### Scenario: Reserva de outro cliente
- **WHEN** o app abre a DetalheReserva de uma reserva que pertence a outro cliente
- **THEN** aparece "Você não tem permissão para isso" com o botão Voltar

#### Scenario: Pagar uma pendente em modo avião
- **GIVEN** uma reserva pendente cujo código Pix está no cache e o aparelho em modo avião
- **WHEN** o cliente toca "Pagar agora (Pix)" no detalhe
- **THEN** a tela Pagamento abre com o QR desenhado a partir do cache

### Requirement: Edição da observação
A observação SHALL ser editável enquanto a reserva está `PENDENTE_PAGAMENTO` ou `CONFIRMADA` e o fim ainda não
passou. "Editar" SHALL abrir o campo no próprio cartão, com contador `x/200` e os botões "Cancelar" e
"Salvar alteração". Salvar SHALL enviar `PATCH /reservas/{id}` com `{observacao}`. O comportamento por
resultado SHALL ser:
- **2xx**: atualiza o cache e mostra "Observação atualizada com sucesso!" por 3 s;
- **422 `TRANSICAO_INVALIDA`**: mostra "A reserva mudou de situação" e recarrega a reserva.

Sem observação, o cartão SHALL mostrar "Nenhuma observação.". (RF16, RN15, CT-27)

#### Scenario: Observação alterada
- **WHEN** o cliente edita a observação para "Levar 2 bolas" e toca "Salvar alteração"
- **THEN** aparece "Observação atualizada com sucesso!" e o cartão mostra o texto novo
- **AND** reabrir o detalhe mostra o mesmo texto

#### Scenario: Reserva encerrada não edita
- **GIVEN** uma reserva `EXPIRADA`
- **WHEN** o detalhe é exibido
- **THEN** o botão "Editar" não aparece e a observação é somente leitura

### Requirement: Política de cancelamento calculada
O cartão "Política de Cancelamento" SHALL ser calculado no fuso de Brasília. A pílula SHALL mostrar o tempo
restante como "Faltam N horas" a partir de 1 hora e "Faltam N min" abaixo disso. Os casos SHALL ser:
- **`CONFIRMADA` com o instante atual até 2 horas antes do início**:
  - pílula "Dentro do prazo de cancelamento (Faltam <tempo>)";
  - texto "Cancelamento gratuito disponível até 2 horas antes do início da partida (até dd/MM às HH:mm).";
  - nota "Conforme regulamento, para reservas confirmadas o estorno financeiro é alinhado diretamente com o
    gestor da arena em caso de cancelamento aprovado.".
- **`CONFIRMADA` com menos de 2 horas para o início**: pílula "Prazo de cancelamento encerrado"; o botão
  "Cancelar Reserva" fica visível e desabilitado.
- **`PENDENTE_PAGAMENTO`**: o texto informa que a reserva pode ser cancelada a qualquer momento antes de o
  Pix expirar.
- **concluída, cancelada ou expirada**: o cartão não aparece.

A decisão final é do servidor. (RF17, RN13, RN14, RNF12, CT-26)

#### Scenario: Faltam mais de 2 horas
- **GIVEN** uma reserva `CONFIRMADA` que começa daqui a 48 horas, às 19:00
- **WHEN** o detalhe é exibido
- **THEN** a pílula mostra "Dentro do prazo de cancelamento (Faltam 46 horas)" e o texto informa o limite das 17:00

#### Scenario: Menos de 2 horas para o início
- **GIVEN** uma reserva `CONFIRMADA` que começa daqui a 1 hora
- **WHEN** o detalhe é exibido
- **THEN** a pílula mostra "Prazo de cancelamento encerrado" e o botão "Cancelar Reserva" está desabilitado

### Requirement: Sheet de cancelamento do cliente
"Cancelar Reserva", na DetalheReserva, e "Cancelar reserva", na tela Pagamento, SHALL abrir o sheet que
reproduz `docs/Protótipo de Alta Fidelidade/cancelar_reserva_confirma_o/code.html`:
- alça, ícone de alerta e título "Cancelar Reserva?";
- texto "Você está prestes a cancelar seu jogo na <quadra> (<dia, data> às <HH:mm>).";
- quadro de regra com o tempo restante do prazo e o parágrafo "Atenção:", sem "(RN14)". O parágrafo diz que
  o cancelamento libera o horário imediatamente e, só para reserva `CONFIRMADA`, que o estorno é alinhado
  com o gestor da arena;
- campo "Motivo do cancelamento" obrigatório, com contador `x / 200`, a dica "Informe o motivo para
  conhecimento da arena (mínimo 5 caracteres).", o placeholder do protótipo e o aviso
  "Por favor, insira pelo menos 5 caracteres." quando há de 1 a 4 caracteres;
- chips "Imprevisto de equipe", "Problema de saúde", "Condições climáticas" e "Outro", que preenchem o campo
  com o próprio texto e põem o foco nele;
- botões "Manter reserva", que recebe o foco por padrão, e "Confirmar cancelamento", habilitado só com
  motivo válido.

O motivo SHALL ter de 5 a 200 caracteres depois de remover espaços das pontas, embora a API aceite o motivo
opcional para o cliente; o app o envia sempre. Confirmar SHALL enviar `POST /reservas/{id}/cancelar` com
`{motivo}`, mostrando "Cancelando...". O comportamento por resultado SHALL ser:
- **2xx**: grava a reserva atualizada no cache, fecha o sheet, mostra a reserva cancelada e o snackbar
  "Reserva cancelada com sucesso. O horário foi liberado.";
- **422 `CANCELAMENTO_FORA_DO_PRAZO`**: "Cancelamento permitido até 2 h antes do início";
- **422 `TRANSICAO_INVALIDA`**: "A reserva mudou de situação", e a reserva é recarregada;
- **sem conexão**: o botão de confirmar fica desabilitado.

(RF17, RN13, RN14, RN15, CT-26)

#### Scenario: Motivo curto demais
- **WHEN** o cliente digita "Ops" no motivo
- **THEN** aparece "Por favor, insira pelo menos 5 caracteres." e "Confirmar cancelamento" continua desabilitado

#### Scenario: Cancelar com chip de motivo
- **GIVEN** uma reserva `CONFIRMADA` para amanhã
- **WHEN** o cliente toca o chip "Condições climáticas" e confirma
- **THEN** a API recebe `motivo` igual a "Condições climáticas"
- **AND** o detalhe passa a mostrar a reserva cancelada

#### Scenario: Cancelar a pendente
- **GIVEN** uma reserva `PENDENTE_PAGAMENTO`
- **WHEN** o cliente cancela com o motivo "Mudança de planos"
- **THEN** a reserva fica cancelada e a cobrança aparece como "Cancelado" no bloco de pagamento

### Requirement: Reserva cancelada
Uma reserva `CANCELADA` SHALL ser exibida como em `docs/Protótipo de Alta Fidelidade/detalhe_da_reserva_cancelada/code.html`:
- pílula "CANCELADA" com a data e hora de `canceladoEm`;
- código com "Copiar";
- cartão "Reserva Cancelada" / "Horário liberado imediatamente no sistema da arena" com:
  - "Cancelada por:" valendo "Você (Cliente)", "Arena (Proprietário)" ou "Sistema (falha na cobrança
    Pix)";
  - "Motivo registrado:" com o motivo entre aspas;
- cartão da quadra com imagem esmaecida e o selo "Horário Desmarcado", a data riscada,
  "19:00 - 20:00 (Duração original: 60 minutos)", "Endereço da Quadra" e "Como chegar";
- cartão "Histórico Financeiro" com a linha "Pagamento via Pix" e o TxID, quando a cobrança é conhecida;
- cartão de observações "Somente leitura";
- faixa do titular com as iniciais, o nome do usuário, "Titular da reserva cancelada" e "Cliente";
- botões "Buscar outra quadra / Novo jogo", que vai para `/quadras`, e "Voltar para Minhas Reservas".

O cartão "Política de Estorno / Reembolso" e a etiqueta "Estorno Pendente" SHALL aparecer só quando o
pagamento está `PAGO`. Elementos omitidos:
- "Falar com a Arena no WhatsApp" e "Contatar Arena";
- "Baixar comprovante de cancelamento (PDF)";
- as marcações "(RF17)" e "(RN14)".

Para cancelamento pelo `SISTEMA`, o motivo SHALL ser "Não foi possível gerar a cobrança Pix." no lugar do
código técnico. (RF15, RF17, RN14, RN17)

#### Scenario: Cancelada sem pagamento
- **GIVEN** uma reserva cancelada pelo cliente quando ainda estava pendente
- **WHEN** o detalhe é exibido
- **THEN** aparecem "Você (Cliente)" e o motivo registrado
- **AND** não aparecem o cartão de estorno nem a etiqueta "Estorno Pendente"

#### Scenario: Cancelada depois de paga
- **GIVEN** uma reserva paga e cancelada pela arena
- **WHEN** o detalhe é exibido
- **THEN** aparecem "Arena (Proprietário)", "Estorno Pendente" e o cartão "Política de Estorno / Reembolso" sem botão de WhatsApp

### Requirement: Acessibilidade das telas de reserva
As telas de reserva SHALL atender a estes pontos:
- cada data da faixa anuncia o estado selecionado e a data por extenso, por exemplo "sábado, 10 de outubro";
- cada slot é lido como "19h às 20h, livre", "ocupado" ou "já passou", e os não livres são anunciados como
  desativados;
- o resumo da ConfirmarReserva é lido em bloco e o contador do campo de observações é anunciado;
- as abas de MinhasReservas anunciam o papel de aba;
- cada card tem rótulo único com o status, e o botão de pagar inclui o nome da quadra;
- o sheet de cancelamento abre com o foco em "Manter reserva".

(RNF07)

#### Scenario: Slot lido pelo TalkBack
- **GIVEN** o TalkBack ligado
- **WHEN** o foco chega ao slot das 19:00 livre
- **THEN** o leitor anuncia "19h às 20h, livre, R$ 90,00"
