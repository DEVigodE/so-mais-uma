## Purpose

Faz as telas de consulta abrirem na hora e continuarem úteis sem rede. Cobre:
- cache local de quadras e reservas;
- sincronização "cache primeiro, rede depois, servidor vence";
- escritas sempre online.

O app nunca edita dados localmente: o cache só espelha o servidor.

## ADDED Requirements

### Requirement: Banco local com sqflite
O cache SHALL ser um banco SQLite aberto com sqflite no arquivo `somaisuma.db` da pasta de bancos do app, com
duas tabelas: `quadra_cache` e `reserva_cache`. O mapeamento entre linhas e modelos SHALL ser escrito à mão,
sem geração de código. O banco SHALL ter `version` igual a 1 e recriar as tabelas no `onUpgrade` e no
`onDowngrade`, porque o conteúdo é só cache e volta na próxima sincronização. Qualquer mudança de coluna SHALL
subir a `version` no mesmo PR. (RF23, RNF10, RNF11)

#### Scenario: APK novo com coluna nova
- **GIVEN** um aparelho com a versão anterior do app e o cache populado
- **WHEN** o APK novo, com `version` 2, é instalado por cima
- **THEN** as tabelas são recriadas vazias e a próxima sincronização as repovoa, sem erro de coluna inexistente

### Requirement: Cache de quadras por escopo
`quadra_cache` SHALL ter chave primária composta `(id, escopo)`, com dois escopos:
- `CATALOGO`, preenchido por `GET /quadras`;
- `MINHAS`, preenchido por `GET /quadras/minhas`, inclusive com as inativas.

A tabela SHALL guardar todos os campos de `QuadraResponse` necessários às telas, inclusive `cep`, e os
horários de funcionamento serializados em `horarios_json`. Sincronizar um escopo SHALL substituir apenas as
linhas daquele escopo, em uma transação, sem tocar o outro. (RF23, RF06, RF07)

#### Scenario: Substituir o catálogo preserva as quadras do dono
- **GIVEN** a mesma quadra presente nos escopos `CATALOGO` e `MINHAS`
- **WHEN** o escopo `CATALOGO` é substituído por uma lista vazia
- **THEN** a quadra continua no escopo `MINHAS`

### Requirement: Cache de reservas
`reserva_cache` SHALL ter chave primária `id`. A tabela SHALL guardar:
- dados da reserva: quadra, endereço, início, fim, valor, status, observação e `expira_em`;
- datas de criação e de cancelamento, quem cancelou e o motivo;
- nome e telefone do cliente, que só chegam para o DONO;
- dados da cobrança: status, provedor, `txid`, `pix_copia_e_cola` e `pago_em`.

A sincronização SHALL usar uma única chamada `GET /reservas` sem `situacao` e substituir a tabela inteira em
uma transação. Como essa listagem não traz a cobrança, a substituição SHALL preservar, pelo `id`, as colunas
de cobrança das reservas que continuam existindo. Essas colunas só SHALL mudar com respostas que trazem a
cobrança: criação, detalhe, edição, cancelamento e a consulta do pagamento. (RF23, RF15, RF18, RF19)

#### Scenario: Sincronização não apaga o código Pix
- **GIVEN** uma reserva pendente criada neste aparelho, com `pix_copia_e_cola` no cache
- **WHEN** MinhasReservas sincroniza com `GET /reservas`, que devolve a reserva sem a cobrança
- **THEN** a reserva continua com o mesmo `pix_copia_e_cola` no cache

#### Scenario: Reserva removida do servidor some do cache
- **GIVEN** uma reserva no cache que não volta mais na listagem do servidor
- **WHEN** a sincronização termina com sucesso
- **THEN** a reserva deixa de existir no cache e de aparecer nas telas

### Requirement: Leitura com cache primeiro e reatividade
As telas de consulta SHALL desenhar imediatamente o que existe no cache e, em seguida, sincronizar com o
servidor. Os repositórios SHALL expor os dados em signals que emitem depois de cada gravação no banco, para que
a tela se atualize sozinha quando a sincronização termina. A tela nunca SHALL ver um escopo vazio no meio de
uma substituição. (RF23, RNF04, CT-28)

#### Scenario: Abertura instantânea
- **GIVEN** o catálogo sincronizado antes e o backend lento
- **WHEN** o cliente abre Quadras
- **THEN** a lista do cache aparece sem esperar a resposta da rede
- **AND** a lista é atualizada sozinha quando a sincronização termina

### Requirement: Servidor vence
A sincronização SHALL substituir o conteúdo do escopo pela resposta do servidor. Linhas ausentes da resposta
SHALL ser apagadas, e status alterados no servidor SHALL substituir os do cache, sem merge e sem resolução de
conflito. Depois de cada sincronização bem-sucedida, o app SHALL gravar `ultima_sincronizacao_quadras` ou
`ultima_sincronizacao_reservas`. (RNF11, RF23, CT-28)

#### Scenario: Reserva cancelada pelo dono enquanto o cliente estava offline
- **GIVEN** o cliente em modo avião com uma reserva `CONFIRMADA` no cache, cancelada no servidor pelo dono
- **WHEN** a rede volta e a lista sincroniza
- **THEN** a reserva aparece como cancelada

### Requirement: Gatilhos de sincronização
Cada tela com cache SHALL sincronizar o próprio escopo nestes momentos:
- ao abrir;
- no gesto de puxar para atualizar;
- quando o app volta ao primeiro plano;
- quando a conexão com o backend volta;
- depois de uma escrita bem-sucedida que afeta o escopo.

O app SHALL NOT ter sincronização periódica nem tarefa em segundo plano. (RF23, RNF11)

#### Scenario: Voltar do app do banco
- **GIVEN** o cliente na aba Reservas, que troca para o app do banco
- **WHEN** ele volta ao app
- **THEN** a aba Reservas sincroniza de novo

### Requirement: Detecção de conexão com o backend
O app SHALL considerar o backend alcançável usando o `internet_connection_checker_plus` configurado para
consultar `/actuator/health`, derivado de `API_BASE_URL`, e expor esse estado em um signal global. A transição
de inalcançável para alcançável SHALL disparar a sincronização da tela visível. O banner de modo cache SHALL
sumir só depois de uma sincronização bem-sucedida. (RF23, RNF08)

#### Scenario: Hotspot sem internet com backend local
- **GIVEN** o kit de demo com o backend no notebook e o celular em um hotspot sem acesso à internet
- **WHEN** o app é usado
- **THEN** o backend é considerado alcançável e as escritas ficam habilitadas

### Requirement: Comportamento sem rede e com erro
Uma falha de rede na sincronização SHALL manter o cache na tela e mostrar o banner "Modo cache ativo" com
"Última sincronização <quando>", sem nova tentativa automática. Um erro HTTP SHALL manter o cache e
comunicar o erro por snackbar, ou pela caixa de erro quando não há cache. No primeiro uso sem rede e sem
cache, a tela SHALL mostrar "Conecte-se para carregar os dados" com "Tentar novamente". (RF23, RNF06, CT-28)

#### Scenario: Primeiro uso em modo avião
- **GIVEN** um usuário que acabou de entrar e ainda não sincronizou o catálogo
- **WHEN** ele abre Quadras em modo avião
- **THEN** aparece "Conecte-se para carregar os dados" com o botão "Tentar novamente"

### Requirement: Escritas somente online
Toda escrita SHALL exigir conexão e ir direto ao backend. As escritas são: cadastro, login, edição do perfil,
criação, edição e desativação de quadra, horários, criação de reserva, edição da observação, cancelamento e
simulação de pagamento. Sem conexão, os botões de escrita SHALL ficar desabilitados com o motivo (por exemplo
"Conecte-se para reservar" e "Conecte-se para alterar"). O app SHALL NOT enfileirar escritas para enviar
depois. O sucesso SHALL ser gravado no cache e a lista afetada SHALL ser sincronizada de novo. A falha SHALL
NOT tocar o cache. (RNF11, CT-28)

#### Scenario: Cancelar em modo avião
- **GIVEN** o aparelho em modo avião
- **WHEN** o cliente abre a DetalheReserva de uma reserva confirmada
- **THEN** "Cancelar Reserva" e "Editar" estão desabilitados com "Conecte-se para alterar"

### Requirement: Comportamento tela a tela em modo avião
Com o cache populado e o aparelho em modo avião, as telas SHALL seguir docs/12 §12.6, tela a tela:

| Tela | Com cache e sem rede | Ações |
|---|---|---|
| Splash | lê a sessão local e entra na home do perfil | — |
| Login e Cadastro | formulário normal; enviar mostra o aviso de falta de conexão | exigem rede |
| Quadras | lista do catálogo com filtros locais e distância por `ultima_lat/lon` | abrir o detalhe funciona |
| DetalheQuadra | parte estática do cache; a grade mostra "Conecte-se para ver os horários" | reservar fica indisponível |
| Pagamento | QR do `pix_copia_e_cola` e contador; status "Aguardando conexão para verificar" | copiar funciona; o resto fica desabilitado |
| MinhasReservas | as duas abas do cache e a faixa "Modo cache ativo" | pagar abre o QR do cache |
| DetalheReserva | dados, status, observação e pagamento do cache | editar e cancelar ficam desabilitados |
| Perfil | dados da sessão e a última sincronização | Sair funciona |
| MinhasQuadras | quadras do escopo `MINHAS` | Nova quadra, Editar e Desativar ficam desabilitados |
| FormQuadra | campos do cache | Buscar CEP e Salvar ficam desabilitados |
| HorariosQuadra | as 7 linhas de `horarios_json` | edição desabilitada |
| ReservasQuadra | reservas da faixa de datas, com nome e telefone do cliente | cancelar e "Outro dia" ficam desabilitados |

(RF23, RNF11, CT-28)

#### Scenario: Roteiro do modo avião
- **GIVEN** Quadras e MinhasReservas abertas uma vez com rede
- **WHEN** o modo avião é ligado, o app é fechado pelo gerenciador e reaberto
- **THEN** a Splash entra na home sem rede e Quadras aparece com o banner de modo cache
- **AND** a DetalheQuadra mostra "Conecte-se para ver os horários" e a reserva pendente reabre o QR do cache
- **AND** ao desligar o modo avião a sincronização roda sozinha e o banner some

### Requirement: Limpeza do cache com a sessão
O logout e o 401 `TOKEN_INVALIDO` SHALL apagar as duas tabelas em uma transação, antes que outro usuário
entre no mesmo aparelho. (RF03, RNF03, CT-06)

#### Scenario: Cache vazio depois de sair
- **WHEN** o usuário sai do app
- **THEN** `quadra_cache` e `reserva_cache` não têm nenhuma linha

### Requirement: O que não vai para o cache
O cache SHALL NOT guardar:
- slots, que são voláteis e consultados a cada data;
- respostas de CEP;
- senha;
- dados do pagador Pix;
- dados de outros usuários além do nome e do telefone do cliente que chegam dentro da reserva para o DONO.

(RN05, RNF02, RNF11)

#### Scenario: Grade nunca vem do cache
- **GIVEN** a grade de uma data consultada com rede
- **WHEN** o cliente sai, liga o modo avião e volta à mesma data
- **THEN** a grade não é exibida e aparece "Conecte-se para ver os horários"
