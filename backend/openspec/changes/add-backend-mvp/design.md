## Context

Ver `proposal.md` — Why para a motivação. O que molda o desenho técnico:

- **Ponto de partida real**: `backend/so-mais-uma/` contém apenas o esqueleto do Spring Initializr —
  `pom.xml` (Maven, parent `spring-boot-starter-parent:4.1.1`, `java.version` 25, três dependências),
  `SoMaisUmaApplication.java` vazia, `application.yaml` com o nome da aplicação. Não há controller,
  entidade, migração, `compose.yaml` nem `Dockerfile`.
- **Divergência com a documentação**: `docs/09`, `docs/21`, `docs/23` e o `README.md` descrevem Gradle
  Kotlin DSL, pacote `br.com.somaisuma` e JDK 21. A decisão desta change é seguir o esqueleto real
  (Maven, `br.com.puc.so_mais_uma`, Java 25) e mover o módulo para `backend/` direto.
- **Restrição estruturante do domínio**: a exclusividade do slot (RN08) é o requisito que define a
  arquitetura de escrita. Ela precisa sobreviver a N threads e a N instâncias do backend, e o caminho
  de criação da reserva também chama um provedor Pix externo — duas exigências que puxam em direções
  opostas se estiverem na mesma transação.
- **Restrição de equipe**: quatro pessoas, fatias verticais por domínio, 15 semanas. O desenho precisa
  minimizar conflito de merge entre as fatias (auth, quadra/horário, reserva/slot, pagamento).
- **Restrição de terceiros**: o provedor Pix real (sandbox) só responde em horário comercial de dias
  úteis e exige conta PJ e certificado com validade de 30 dias. O backend não pode depender dele para
  funcionar em desenvolvimento, em CI ou na apresentação.

## Goals / Non-Goals

**Goals:**

- Um único artefato executável (monólito) com camadas explícitas, mapeáveis ao critério de
  arquitetura da disciplina e a uma fatia de equipe por pacote de domínio.
- A garantia de exclusividade do slot residindo no banco de dados, provada por teste de concorrência
  real com contêiner PostgreSQL.
- Nenhuma chamada HTTP externa dentro de uma transação de banco.
- Um único ponto de confirmação de pagamento, alcançável por três caminhos distintos, idempotente por
  construção.
- Troca de provedor Pix e de ambiente por variável de ambiente, sem recompilar.
- Esquema de banco versionado e aditivo, validado (nunca gerado) pelo mapeamento objeto-relacional.

**Non-Goals:**

- Escalar horizontalmente com estado compartilhado. O contador de bloqueio de login fica em memória e
  não sobrevive a reinício nem se replica entre instâncias; isso é aceito e documentado.
- Revogação de token, refresh token, recuperação de senha por e-mail.
- Paginação, cache HTTP, cache distribuído, fila de mensagens.
- Devolução de valores por API, divisão de valores, repasse ao dono.
- Qualquer componente do aplicativo Android (RF03, RF22, RF23, RF24).

## Decisions

### D1 — Monólito em camadas, pacotes por camada

`br.com.puc.so_mais_uma.{config,security,controller,service,repository,entity,dto,exception,integracao}`,
um único módulo Maven, um único artefato.

*Alternativas*: package-by-feature; microsserviços; módulos Maven por camada.
*Por quê*: os pacotes por camada mapeiam literalmente o critério de arquitetura da disciplina e
aparecem na árvore do projeto sem explicação adicional. Package-by-feature exigiria justificar a
estrutura na banca. Microsserviços e módulos separados custam tempo de build e configuração sem
nenhum ganho para quatro pessoas. O conflito de merge entre fatias é evitado porque cada camada tem
um arquivo por domínio (`QuadraService`, `ReservaService`, `PagamentoService`...), e não um arquivo
compartilhado.

Regras de dependência entre camadas, aplicadas em revisão de PR:

| Pacote | Responsabilidade | Pode depender de | Nunca |
|---|---|---|---|
| `controller` | rota, `@Valid`, extrair usuário autenticado, converter DTO, status HTTP | `service`, `dto`, `security` | tocar `repository`, devolver `entity`, conter regra de negócio |
| `service` | regras RN01–RN20, transação, checagem de propriedade, orquestração, jobs | `repository`, `entity`, `integracao`, `exception` | conhecer HTTP, montar `ProblemDetail` |
| `repository` | interfaces Spring Data JPA, consultas derivadas e `UPDATE` condicionais | `entity` | lógica além da consulta |
| `entity` | mapeamento JPA das 5 tabelas e os enums | — | sair do backend |
| `dto` | `record` de entrada/saída com Bean Validation e conversor estático a partir da entidade | `entity` (leitura) | anotação JPA |
| `exception` | exceções de domínio e o tradutor global para `ProblemDetail` | `dto` | — |
| `config` | beans de infraestrutura | tudo | regra de negócio |
| `security` | emissão e leitura de JWT, autoridades, bloqueio de login | `entity` (enums), `UsuarioRepository` | acesso a banco além disso |
| `integracao` | adaptadores externos atrás de interface; convertem falha em exceção de integração | `config` | tocar `repository` ou `entity` |

Entidades JPA usam Lombok apenas para acessores (`@Getter`, `@Setter`, `@NoArgsConstructor`) — nunca
`@Data`, que geraria `equals`/`hashCode` sobre entidade gerenciada. DTOs são `record`.

### D2 — Exclusividade do slot por índice único parcial, não por lock

```sql
CREATE UNIQUE INDEX ux_reserva_slot_ativo ON reserva (quadra_id, inicio)
    WHERE status IN ('PENDENTE_PAGAMENTO', 'CONFIRMADA');
```

*Alternativas*: verificar existência antes do INSERT; lock pessimista (`SELECT ... FOR UPDATE`); lock
otimista por versão; restrição de exclusão com intervalos (`EXCLUDE USING gist`); lock distribuído.
*Por quê*: não existe linha para travar antes de um INSERT, então lock pessimista exigiria travar a
quadra inteira e serializaria horários independentes. Lock otimista protege atualização, não criação.
A restrição de exclusão por intervalo resolve intervalos arbitrários, que não existem aqui porque
RN06 e RN07 fixam o slot em hora cheia de 60 minutos — o par `(quadra_id, inicio)` é a identidade
completa do slot. Verificar antes do INSERT deixa janela de corrida e serve apenas como conforto de
interface, na grade de slots. O índice parcial ainda dá de graça a liberação do slot: uma reserva que
sai de `PENDENTE_PAGAMENTO`/`CONFIRMADA` sai do índice, sem nenhum código de limpeza, preservando o
histórico (RN15).

Consequências no código de criação:

- `saveAndFlush`, nunca `save`: com `save` o INSERT só sai no commit, fora do método, e a violação
  chegaria como exceção do proxy transacional, fora do alcance do `catch`.
- O `catch` de violação de integridade é **seletivo pelo nome da constraint**. Só
  `ux_reserva_slot_ativo` vira 409 `HORARIO_INDISPONIVEL`. Chave estrangeira inexistente, `NOT NULL`
  violado ou `CHECK` de duração/hora cheia também chegam como violação de integridade e nada têm a ver
  com concorrência: essas continuam subindo, respondem 500 e vão inteiras para o log. A mesma regra
  vale para `ux_usuario_email` (RN20) e para o índice de idempotência do pagamento (RN12).

### D3 — Cobrança Pix fora da transação da reserva, com compensação

Uma fachada sem transação orquestra três transações: (1) `ReservaService.criarPendente` insere e
commita a reserva; (2) `PagamentoService.criarCobranca` chama o provedor por HTTP e insere o
pagamento; (3) em falha de integração, `ReservaService.cancelarPorSistema` cancela a reserva com
`CanceladoPor = SISTEMA` e a fachada responde 502 `PAGAMENTO_INDISPONIVEL`.

*Alternativas*: criar a cobrança dentro da transação da reserva, deixando o rollback desfazer tudo.
*Por quê*: o rollback automático é mais simples, mas seguraria a entrada do índice único durante uma
chamada de rede que pode levar segundos ou estourar timeout — todos os concorrentes daquele slot
ficariam bloqueados nesse intervalo, e o pool de conexões seria consumido por transações à espera de
I/O. Com a compensação explícita, a transação de escrita dura milissegundos. O preço é que existe uma
janela em que a reserva está commitada sem cobrança; ela é fechada pela transação 3 e, no pior caso
(queda do processo entre 1 e 3), pelo job de expiração em no máximo 16 minutos. É por isso que a
relação é `reserva 1 — 0..1 pagamento`, e não `1 — 1`.

### D4 — Toda transição de status é `UPDATE ... WHERE status = <esperado>`

Nenhuma transição é feita por ler, alterar em memória e salvar. Cada transição é uma única instrução
condicionada ao status atual, e o número de linhas afetadas é o resultado:

- 1 linha: a transição aconteceu.
- 0 linhas: outro fluxo venceu a corrida — 422 `TRANSICAO_INVALIDA` se o pedido veio de um usuário,
  operação sem efeito com log se veio de job ou webhook.

*Alternativas*: lock otimista por coluna de versão; ler-alterar-salvar dentro de transação serializável.
*Por quê*: a versão exige tratar a exceção de concorrência em todo caminho e ainda faz uma leitura a
mais; o isolamento serializável transformaria corridas rotineiras (job de expiração versus webhook) em
falhas de serialização que precisariam de retry. O `UPDATE` condicional resolve o mesmo problema em
uma instrução e é a mesma técnica em todos os fluxos.

**Armadilha registrada**: `UPDATE` em massa não passa pelo contexto de persistência. A entidade
carregada antes do `UPDATE` fica com o status antigo e desanexada depois dele. Portanto: as
anotações de modificação usam limpeza e sincronização automáticas do contexto; os valores necessários
depois do `UPDATE` (identificador da reserva, valor) são lidos **antes** dele; e o status usado para
decidir o caminho seguinte é **relido do banco**, nunca tirado do objeto em memória.

### D5 — Um único ponto de confirmação de pagamento, idempotente

`PagamentoService.confirmar(txid, endToEndId, valor, horario)` é chamado pelos três caminhos: job de
consulta periódica, webhook do provedor e endpoint de simulação. A sequência é:

1. Localizar a cobrança por identificador de transação; desconhecida → resultado neutro com log.
2. Comparar o valor recebido com o valor da cobrança; divergente → não confirma, log, resultado neutro.
3. `UPDATE pagamento SET status='PAGO' ... WHERE txid=? AND status='PENDENTE'`.
4. 1 linha → `UPDATE reserva SET status='CONFIRMADA' WHERE id=? AND status='PENDENTE_PAGAMENTO'`;
   se essa também afetar 1 linha, terminou.
5. 0 linhas em qualquer um dos dois → **reler o status da cobrança no banco**. Se for `PAGO`, é
   no-op (job e webhook chegaram juntos). Se for `EXPIRADO` ou `CANCELADO`, é pagamento tardio.

**Zero linhas não significa "já processado"** — essa é a decisão que torna RN14 alcançável. Encerrar o
método no primeiro zero deixaria o tratamento de pagamento tardio como código morto.

Tripla proteção contra duplicidade: a guarda `status='PENDENTE'`; a guarda `end_to_end_id IS NULL` no
caminho tardio; e o índice único parcial sobre `end_to_end_id`, cuja violação é capturada pelo nome
da constraint e mapeada para "já processado" com log — nunca para 500, que faria o provedor reenviar
a notificação quatro vezes.

### D6 — Reconfirmação tardia em transação própria (`REQUIRES_NEW`), em bean separado

O tratamento de pagamento tardio tenta primeiro reconfirmar a reserva `EXPIRADA` e só depois marca a
cobrança como paga.

*Por quê a ordem e a transação separada*: a reconfirmação é a única operação do fluxo que pode violar
`ux_reserva_slot_ativo` (o slot pode já ter sido tomado). Quando o PostgreSQL dispara a violação, a
transação em que o comando rodou fica abortada — nenhum `catch` em Java a reabre, e dentro dela não
seria possível nem gravar o log nem marcar a cobrança como paga. Com a transação própria, o rollback
fica contido na transação interna e a externa segue viva para gravar `PAGO` e registrar o estorno
manual. O bean precisa ser **separado** porque a propagação só é aplicada em chamadas que passam pelo
proxy do contêiner: um método chamando outro no mesmo bean não cria transação nova.

Estado prometido por RN14 e alcançável por esse desenho: cobrança `PAGO` com reserva ainda `EXPIRADA`
e um registro de log com identificador de transação, reserva e valor, que é a lista de estornos a
fazer manualmente.

### D7 — Provedor Pix atrás de interface, selecionado por ambiente

```java
public interface PixGateway {
    CobrancaPix criarCobranca(String txid, BigDecimal valor, int expiracaoSegundos, String descricao);
    StatusCobranca consultar(String txid);
    void removerCobranca(String txid);
    ProvedorPagamento provedor();
}
```

Duas implementações selecionadas por perfil de execução: a simulada no ambiente padrão e a que
integra o provedor externo nos ambientes de homologação e produção. O identificador de transação é
gerado pelo backend como UUID sem hifens (32 caracteres, dentro da faixa de 26 a 35 exigida pelo
provedor). O código copia e cola do ambiente simulado é gerado por um construtor próprio de payload
(estrutura de campos com tamanho e dígito verificador CRC-16/CCITT-FALSE).

*Alternativas*: usar apenas o provedor real; usar o SDK oficial do provedor; usar outro provedor de
pagamento.
*Por quê*: a conta PJ e o certificado estão fora do controle da equipe e o sandbox só responde em
horário comercial de dias úteis com certificado de 30 dias de validade. Sem o provedor simulado, não
há desenvolvimento, CI, teste com usuários nem apresentação garantida. O simulado é parte do produto,
não contorno. O SDK oficial exigiria jar manual e conversão de certificado; um cliente HTTP com
pacote TLS lendo os arquivos de certificado e chave é menos passos e explicável em um slide.

Matriz de ambiente e componentes ativos:

| Ambiente | `PixGateway` | Endpoint de simulação | Webhook | Job de consulta | Documentação |
|---|---|---|---|---|---|
| `simulado` (padrão) | simulado | sim (marca pago direto) | não | não | ligada |
| `inter-sandbox` | externo (sandbox) | sim (repassa ao provedor) | sim | sim | ligada |
| `inter-prod` | externo (produção) | **não existe** | sim | sim | desligada |

### D8 — Slots calculados, nunca persistidos

A grade é derivada a cada requisição de `horario_funcionamento` menos as reservas ativas menos as
horas já passadas.

*Alternativas*: tabela de slots pré-gerados com job de geração; armazenar intervalos livres.
*Por quê*: slots persistidos criam milhares de linhas por quadra, exigem um job de geração e abrem a
possibilidade de dessincronização entre a tabela de slots e a tabela de reservas — exatamente o bug
que o índice único evita. Com slots derivados, a única fonte de verdade sobre ocupação é `reserva`.

### D9 — Esquema: cinco tabelas, chaves inteiras, enums como texto com verificação

`usuario`, `quadra`, `horario_funcionamento`, `reserva`, `pagamento`. Chaves primárias
`BIGINT GENERATED ALWAYS AS IDENTITY`; instantes em `TIMESTAMPTZ`; horas locais de funcionamento em
`TIME`; dinheiro em `NUMERIC(10,2)`; enums como `VARCHAR` com `CHECK` e mapeamento por nome, nunca por
ordinal; exclusão lógica única (`usuario.ativo`, `quadra.ativa`, `reserva.status`); auditoria
`criado_em`/`atualizado_em` em toda tabela.

*Alternativas*: UUID como chave primária; enum nativo do PostgreSQL; tabela para tipo de esporte;
tabela de endereço; exclusão física.
*Por quê*: UUID deixa a URL da demonstração ilegível e não traz benefício aqui (a única exceção é o
identificador de transação, que o provedor exige alfanumérico de 26 a 35 caracteres). Enum nativo
obriga migração para acrescentar valor. Tipo de esporte como tabela adicionaria uma entidade, uma
chave estrangeira, uma tela e quatro endpoints para uma lista fixa de sete valores. Exclusão física
apagaria histórico de reservas com pagamento associado.

DDL inicial (`V1__init.sql`), congelado após a primeira entrega:

```sql
CREATE TABLE usuario (
    id             BIGINT       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome           VARCHAR(100) NOT NULL,
    email          VARCHAR(150) NOT NULL,
    senha_hash     VARCHAR(72)  NOT NULL,
    telefone       VARCHAR(20),
    perfil         VARCHAR(10)  NOT NULL,
    ativo          BOOLEAN      NOT NULL DEFAULT TRUE,
    criado_em      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    atualizado_em  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT ck_usuario_perfil          CHECK (perfil IN ('CLIENTE', 'DONO')),
    CONSTRAINT ck_usuario_email_minusculo CHECK (email = lower(email))
);
CREATE UNIQUE INDEX ux_usuario_email ON usuario (email);

CREATE TABLE quadra (
    id             BIGINT        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dono_id        BIGINT        NOT NULL REFERENCES usuario (id),
    nome           VARCHAR(100)  NOT NULL,
    tipo_esporte   VARCHAR(20)   NOT NULL,
    descricao      VARCHAR(500),
    preco_hora     NUMERIC(10,2) NOT NULL,
    cep            CHAR(8)       NOT NULL,
    logradouro     VARCHAR(150)  NOT NULL,
    numero         VARCHAR(10)   NOT NULL,
    bairro         VARCHAR(80),
    cidade         VARCHAR(80)   NOT NULL,
    uf             CHAR(2)       NOT NULL,
    latitude       NUMERIC(9,6),
    longitude      NUMERIC(9,6),
    foto_url       VARCHAR(300),
    ativa          BOOLEAN       NOT NULL DEFAULT TRUE,
    criado_em      TIMESTAMPTZ   NOT NULL DEFAULT now(),
    atualizado_em  TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT ck_quadra_tipo_esporte CHECK (tipo_esporte IN
        ('FUTEBOL_SOCIETY', 'FUTSAL', 'VOLEI', 'BASQUETE', 'TENIS', 'BEACH_TENNIS', 'PADEL')),
    CONSTRAINT ck_quadra_preco_hora   CHECK (preco_hora > 0),
    CONSTRAINT ck_quadra_cep          CHECK (cep ~ '^[0-9]{8}$'),
    CONSTRAINT ck_quadra_uf           CHECK (uf = upper(uf)),
    CONSTRAINT ck_quadra_latitude     CHECK (latitude  IS NULL OR latitude  BETWEEN  -90 AND  90),
    CONSTRAINT ck_quadra_longitude    CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180),
    CONSTRAINT ck_quadra_coordenadas  CHECK ((latitude IS NULL) = (longitude IS NULL))
);
CREATE INDEX idx_quadra_dono ON quadra (dono_id);

CREATE TABLE horario_funcionamento (
    id               BIGINT   GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    quadra_id        BIGINT   NOT NULL REFERENCES quadra (id) ON DELETE CASCADE,
    dia_semana       SMALLINT NOT NULL,
    hora_abertura    TIME     NOT NULL,
    hora_fechamento  TIME     NOT NULL,
    CONSTRAINT ck_horario_dia_semana  CHECK (dia_semana BETWEEN 1 AND 7),
    CONSTRAINT ck_horario_intervalo   CHECK (hora_fechamento > hora_abertura),
    CONSTRAINT ck_horario_hora_cheia  CHECK (EXTRACT(MINUTE FROM hora_abertura) = 0
                                         AND EXTRACT(MINUTE FROM hora_fechamento) = 0),
    CONSTRAINT ux_horario_quadra_dia  UNIQUE (quadra_id, dia_semana)
);

CREATE TABLE reserva (
    id                   BIGINT        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    quadra_id            BIGINT        NOT NULL REFERENCES quadra (id),
    cliente_id           BIGINT        NOT NULL REFERENCES usuario (id),
    inicio               TIMESTAMPTZ   NOT NULL,
    fim                  TIMESTAMPTZ   NOT NULL,
    valor                NUMERIC(10,2) NOT NULL,
    status               VARCHAR(20)   NOT NULL,
    observacao           VARCHAR(200),
    expira_em            TIMESTAMPTZ   NOT NULL,
    cancelado_por        VARCHAR(10),
    motivo_cancelamento  VARCHAR(200),
    cancelado_em         TIMESTAMPTZ,
    criado_em            TIMESTAMPTZ   NOT NULL DEFAULT now(),
    atualizado_em        TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT ck_reserva_status        CHECK (status IN
        ('PENDENTE_PAGAMENTO', 'CONFIRMADA', 'CANCELADA', 'EXPIRADA')),
    CONSTRAINT ck_reserva_valor         CHECK (valor > 0),
    CONSTRAINT ck_reserva_duracao       CHECK (fim = inicio + INTERVAL '60 minutes'),
    CONSTRAINT ck_reserva_hora_cheia    CHECK (inicio = date_trunc('hour', inicio AT TIME ZONE INTERVAL '-03:00')
                                                              AT TIME ZONE INTERVAL '-03:00'),
    CONSTRAINT ck_reserva_cancelado_por CHECK (cancelado_por IS NULL OR cancelado_por IN ('CLIENTE', 'DONO', 'SISTEMA')),
    CONSTRAINT ck_reserva_cancelamento  CHECK ((status = 'CANCELADA') = (cancelado_por IS NOT NULL))
);
CREATE INDEX idx_reserva_cliente         ON reserva (cliente_id, inicio DESC);
CREATE INDEX idx_reserva_quadra_inicio   ON reserva (quadra_id, inicio);
CREATE INDEX idx_reserva_pendente_expira ON reserva (expira_em) WHERE status = 'PENDENTE_PAGAMENTO';

CREATE UNIQUE INDEX ux_reserva_slot_ativo ON reserva (quadra_id, inicio)
    WHERE status IN ('PENDENTE_PAGAMENTO', 'CONFIRMADA');

CREATE TABLE pagamento (
    id                BIGINT        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    reserva_id        BIGINT        NOT NULL REFERENCES reserva (id),
    txid              VARCHAR(35)   NOT NULL,
    provedor          VARCHAR(10)   NOT NULL,
    valor             NUMERIC(10,2) NOT NULL,
    status            VARCHAR(10)   NOT NULL,
    pix_copia_e_cola  TEXT          NOT NULL,
    location          VARCHAR(255),
    end_to_end_id     VARCHAR(32),
    expira_em         TIMESTAMPTZ   NOT NULL,
    pago_em           TIMESTAMPTZ,
    criado_em         TIMESTAMPTZ   NOT NULL DEFAULT now(),
    atualizado_em     TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT ux_pagamento_reserva  UNIQUE (reserva_id),
    CONSTRAINT ux_pagamento_txid     UNIQUE (txid),
    CONSTRAINT ck_pagamento_txid     CHECK (txid ~ '^[A-Za-z0-9]{26,35}$'),
    CONSTRAINT ck_pagamento_provedor CHECK (provedor IN ('INTER', 'SIMULADO')),
    CONSTRAINT ck_pagamento_status   CHECK (status IN ('PENDENTE', 'PAGO', 'EXPIRADO', 'CANCELADO')),
    CONSTRAINT ck_pagamento_valor    CHECK (valor > 0),
    CONSTRAINT ck_pagamento_pago     CHECK ((status = 'PAGO') = (pago_em IS NOT NULL))
);
CREATE UNIQUE INDEX ux_pagamento_end_to_end ON pagamento (end_to_end_id) WHERE end_to_end_id IS NOT NULL;
CREATE INDEX idx_pagamento_pendente ON pagamento (criado_em) WHERE status = 'PENDENTE';
```

Duas observações que já custaram decisão:

- `ck_reserva_hora_cheia` usa o deslocamento fixo `INTERVAL '-03:00'` e **não** o nome do fuso. A
  conversão pelo nome é apenas estável, não imutável, e o PostgreSQL recusa expressão não imutável em
  restrição de verificação — a criação da tabela falharia e derrubaria a migração, o boot e os testes
  de integração. A restrição é a última linha de defesa; a validação de hora cheia continua na camada
  de serviço, que responde 400 com o campo.
- A constraint de idempotência do pagamento chama-se `ux_pagamento_end_to_end` no DDL, enquanto
  `docs/07-regras-de-negocio.md` a cita como `ux_pagamento_end_to_end_id` no trecho de código. O nome
  do DDL é o que vale; o código que reconhece a violação pelo nome da constraint precisa usar
  exatamente `ux_pagamento_end_to_end`, senão a violação vira 500 em vez de "já processado". A
  divergência está anotada para correção em `docs/07` num PR de documentação.

### D10 — Estados e transições

`StatusReserva {PENDENTE_PAGAMENTO, CONFIRMADA, CANCELADA, EXPIRADA}`:

| De → Para | Disparo | Guarda |
|---|---|---|
| — → `PENDENTE_PAGAMENTO` | criação pelo cliente | índice único do slot |
| `PENDENTE_PAGAMENTO` → `CONFIRMADA` | confirmação de pagamento | `status='PENDENTE_PAGAMENTO'` |
| `PENDENTE_PAGAMENTO` → `EXPIRADA` | job de expiração | `status='PENDENTE_PAGAMENTO' AND expira_em < agora` |
| `PENDENTE_PAGAMENTO` → `CANCELADA` | cliente, dono ou sistema | `status` em ativos |
| `CONFIRMADA` → `CANCELADA` | cliente até 2 h antes; dono até o início | prazo no serviço + `status` em ativos |
| `EXPIRADA` → `CONFIRMADA` | pagamento tardio | `status='EXPIRADA'` + índice único aceita |

`CANCELADA` é terminal. `StatusPagamento {PENDENTE, PAGO, EXPIRADO, CANCELADO}`: `PENDENTE` →
`PAGO`/`EXPIRADO`/`CANCELADO`; `EXPIRADO`/`CANCELADO` → `PAGO` apenas no caminho tardio; `PAGO` é
terminal. Mapeamento com o provedor externo: cobrança ativa → `PENDENTE`; concluída → `PAGO`;
removida pelo recebedor (nosso pedido) → `CANCELADO`; removida pelo provedor → sem transição, a
reserva expira normalmente. O provedor não tem estado de expiração nem de recusa — por isso a
expiração é decidida pelo nosso `expira_em`, nunca pela consulta ao provedor.

### D11 — Agendamento: dois jobs, pool de duas threads

`ExpiracaoReservaJob` (todos os ambientes, 60 s): dois `UPDATE` em lote (reservas e pagamentos
vencidos) mais a limpeza dos bloqueios de login vencidos. `ConsultaPagamentoJob` (apenas ambientes
integrados, 60 s): no máximo 10 cobranças pendentes por ciclo, para respeitar o limite de chamadas do
provedor.

*Alternativas*: agendador com persistência; fila com entrega atrasada por reserva.
*Por quê*: a expiração é um `UPDATE` condicional em lote sobre um índice parcial — um método. Um
agendador persistente ou uma fila adicionariam infraestrutura para o mesmo resultado.

### D12 — Segurança: JWT simétrico, sem estado no servidor

Emissão e validação com a implementação de JOSE que já acompanha o starter de servidor de recursos
OAuth2, algoritmo HS256, segredo de no mínimo 32 bytes vindo do ambiente, validade de 7 dias. O claim
de perfil vira autoridade (`ROLE_CLIENTE`/`ROLE_DONO`) por um conversor próprio. A autorização por
rota fica em anotação no controller; a checagem de propriedade fica sempre no serviço e responde 403,
nunca 404.

*Alternativas*: biblioteca de JWT de terceiros; sessão por cookie; OAuth social.
*Por quê*: a biblioteca de terceiros mais comum tem atrito com a versão do serializador JSON usada
pelo Boot 4; a implementação que já vem com o starter não adiciona dependência nem risco de
compatibilidade. Sessão por cookie exigiria estado no servidor, incompatível com a hospedagem
escolhida e com o cliente móvel.

O bloqueio de login (5 falhas, 15 minutos) fica em um mapa concorrente em memória. A limitação (não
sobrevive a reinício, não se replica) é aceita e documentada: é uma proteção contra força bruta
oportunista, não um controle de segurança distribuído.

### D13 — Build: Maven, Java 25, módulo em `backend/`

O conteúdo de `backend/so-mais-uma/` sobe um nível para `backend/`, mantendo `pom.xml`, wrapper Maven
e o pacote `br.com.puc.so_mais_uma`. Dependências a acrescentar ao `pom.xml`, todas com versão
gerenciada pelo parent, exceto onde indicado:

| Finalidade | Artefato |
|---|---|
| Web MVC | `spring-boot-starter-webmvc` |
| Persistência | `spring-boot-starter-data-jpa` |
| Segurança | `spring-boot-starter-security`, `spring-boot-starter-oauth2-resource-server` |
| Validação | `spring-boot-starter-validation` |
| Migrações | starter de Flyway do Boot 4 + `flyway-database-postgresql` |
| Operação | `spring-boot-starter-actuator` |
| Documentação | `org.springdoc:springdoc-openapi-starter-webmvc-ui` 3.1.0 (versão explícita) |
| Driver | `org.postgresql:postgresql` (runtime) |
| Acessores | `org.projectlombok:lombok` (apenas compilação) |
| Banco em dev | suporte a Docker Compose do Boot (apenas desenvolvimento) |
| Testes | starter de teste do Boot, fatia de teste de web MVC, suporte a Testcontainers, `org.testcontainers:postgresql`, suporte de teste do Spring Security |

Os identificadores exatos dos starters mudaram entre Boot 3 e Boot 4 (por exemplo,
`spring-boot-starter-web` passou a `spring-boot-starter-webmvc`, e as fatias de teste ganharam
starters próprios). A primeira tarefa de fundação inclui confirmar cada identificador contra o
gerenciamento de dependências do parent 4.1.1 antes de escrever o restante.

*Alternativas*: migrar para Gradle Kotlin DSL como a documentação prescreve.
*Por quê*: decisão do usuário — o esqueleto Maven já existe e funciona; converter o build consumiria
tempo da fase de fundação sem alterar nenhum comportamento observável do sistema. O custo é manter
`README.md`, `docs/09`, `docs/21` e `docs/23` desatualizados até um PR de documentação.

### D14 — Configuração por ambiente

`application.yml` com o padrão (`simulado`, prefixo da API, Flyway, fuso, pool de agendamento) e três
arquivos por ambiente. Variáveis: seleção de ambiente; URL, usuário e senha do banco; segredo e
validade do token; fuso; chave do endpoint de simulação; chave, nome e cidade do recebedor no
ambiente simulado; identificador e segredo de cliente, caminhos de certificado e chave, chave Pix,
URL base, escopos e segredo do webhook nos ambientes integrados; porta. O repositório ignora desde o
primeiro commit os arquivos de certificado, chave e variáveis de ambiente.

## Risks / Trade-offs

- **Lombok 1.18.48 sobre JDK 25 pode falhar no processamento de anotações** → a primeira tarefa de
  fundação compila uma entidade com Lombok antes de escrever as outras quatro; se falhar, os acessores
  das cinco entidades são escritos à mão (entidade JPA não pode ser `record`) e o Lombok sai do
  `pom.xml`. Nenhum outro pacote depende dele.
- **Identificadores de starter divergentes entre Boot 3 e Boot 4** → confirmar contra o parent 4.1.1
  na tarefa de fundação; o projeto não sobe se um starter estiver errado, então a falha é imediata e
  barata.
- **Janela entre a reserva commitada e a cobrança criada (D3)** → a transação de compensação fecha o
  caso normal; a queda do processo no meio é coberta pelo job de expiração em no máximo 16 minutos, ao
  custo de o slot ficar indisponível nesse intervalo.
- **Slot preso por até 16 minutos (15 de prazo + 1 ciclo do job)** → aceito; reduzir o ciclo do job
  aumenta carga sem ganho perceptível. O prazo é configurável para testes.
- **Bloqueio de login em memória** → não sobrevive a reinício nem se replica; documentado como
  limitação conhecida. Mitiga força bruta oportunista, que é o cenário real do projeto.
- **Token de 7 dias sem revogação** → um token vazado vale até expirar; documentado. Sair do
  aplicativo limpa o dispositivo, não o servidor.
- **Webhook sem autenticação mútua nem lista de IPs permitidos** → protegido por segmento secreto na
  URL mais validação de identificador de transação, status e valor, mais idempotência. Um atacante que
  descobrisse a URL ainda não conseguiria confirmar uma cobrança com valor divergente.
- **Sandbox do provedor disponível apenas em horário comercial de dias úteis, certificado de 30 dias**
  → o ambiente padrão simulado cobre desenvolvimento, CI, teste com usuários e apresentação; a troca
  de ambiente é por variável, sem recompilar.
- **`UPDATE` em massa desanexa a entidade carregada** → convenção obrigatória: ler antes o que for
  preciso depois, e reler o status do banco para decidir o caminho. Coberto por teste de serviço de
  pagamento.
- **Divergência entre a documentação e o build real (Maven, Java 25, pacote)** → registrada no
  `proposal.md`; exige um PR de documentação depois, senão a banca encontra README que não executa.

## Migration Plan

Não há dados nem usuários em produção: a "migração" é a construção inicial, feita em fases.

1. **Fundação** — mover o módulo para `backend/`, completar o `pom.xml`, subir PostgreSQL 18 por
   Docker Compose, configurar os quatro arquivos de configuração, validar que a aplicação sobe no
   ambiente padrão e responde o health check.
2. **Contrato do banco** — `V1__init.sql` completo, entidades e enums, teste de integração que prova
   que a migração aplica e que o mapeamento valida o esquema. A partir da primeira entrega etiquetada,
   `V1` nunca mais é editado; toda evolução entra como `V2`, `V3` e assim por diante, sempre aditiva.
3. **Fatias verticais de backend**, na ordem em que uma destrava a seguinte: plataforma de erros e
   configuração → autenticação → perfil → quadras → horários → CEP → slots → reservas → pagamento
   simulado.
4. **Integração externa** — provedor real em homologação, job de consulta, webhook, reconfirmação
   tardia.
5. **Publicação** — imagem de contêiner multiestágio, banco gerenciado, variáveis e arquivos secretos
   no painel do provedor de hospedagem, carga de demonstração aplicada fora das migrações.

**Reversão**: até a primeira entrega, reverter é apagar o banco e reaplicar as migrações, porque não
há dado de valor. Depois disso, a regra de migração aditiva garante que o artefato anterior continue
funcionando contra o esquema novo, então a reversão é voltar a versão do artefato sem tocar no banco.

## Open Questions

- **Webhook do provedor entra ou não**: depende de haver uma URL pública com TLS a tempo. A decisão
  não altera as specs (o requisito já está marcado como opcional) nem o desenho — o ponto de
  confirmação é o mesmo com ou sem webhook. Pode ser respondida na fase de integração externa.
- **Ambiente de produção do provedor**: depende de conta jurídica aprovada, que está fora do controle
  da equipe. Sem ela, o ambiente de homologação cobre todos os critérios. Também não altera specs nem
  desenho.
