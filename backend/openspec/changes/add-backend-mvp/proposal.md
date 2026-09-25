## Why

O aplicativo "Só mais uma" tem 24 documentos de planejamento completos em `docs/` (RF01–RF24,
RNF01–RNF12, RN01–RN20, modelagem das 5 tabelas, contrato REST inteiro, integração Pix do Banco
Inter, CT-01..CT-31), mas nenhuma especificação executável: `openspec/specs/` está vazio e o
backend é apenas o esqueleto do Spring Initializr. Sem requisitos verificáveis, as quatro fatias
verticais da equipe (A auth/segurança, B quadra/horário/CEP, C reserva/slots/concorrência,
D pagamento Pix) não têm contrato comum e a rastreabilidade RF/RN → código → teste exigida pela
disciplina fica presa em prosa.

Este change converte a documentação narrativa em requisitos com cenários testáveis, cobrindo o
backend MVP inteiro, organizado em fases N1 (entrega de 02/10/2026) e N2 (apresentação de
07–11/12/2026).

## What Changes

- Estabelece o contrato da API REST `/api/v1`: ~30 endpoints, `ProblemDetail` RFC 9457 com campo
  `codigo`, formato de data/dinheiro/enum, fuso único `America/Sao_Paulo`, regra de evolução
  aditiva a partir da tag `v0.1-n1`.
- Especifica autenticação JWT HS256 (Nimbus, 7 dias), BCrypt custo 10, política de senha, bloqueio
  de login após 5 falhas por 15 minutos e autorização em três camadas (token → role → propriedade).
- Especifica os dois CRUDs completos exigidos pelo critério 3 da disciplina: `Quadra` e
  `HorarioFuncionamento`.
- Especifica a disponibilidade por slots de 60 minutos calculados em memória a partir de
  `horario_funcionamento`, nunca persistidos.
- Especifica a reserva com exclusividade garantida por índice único parcial no PostgreSQL
  (`ux_reserva_slot_ativo`), expiração automática em 15 minutos, limite de uma reserva pendente por
  cliente e transições de estado por UPDATE condicional.
- Especifica o pagamento Pix atrás da interface `PixGateway`, com `SimuladoPixGateway` (padrão) e
  `InterPixGateway` (OAuth2 client_credentials + mTLS), confirmação idempotente por três caminhos
  (polling do app, `ConsultaPagamentoJob`, webhook) e tratamento de pagamento tardio.
- Especifica a segunda API externa obrigatória: `GET /cep/{cep}` via BrasilAPI CEP v2 com fallback
  ViaCEP, sempre pelo backend.
- **BREAKING (em relação à documentação, não ao código)**: fixa o backend em **Maven**, pacote
  **`br.com.puc.so_mais_uma`** e **Java 25**, seguindo o esqueleto que já existe no repositório.
  `README.md`, `docs/09-arquitetura.md`, `docs/21-git-e-organizacao.md` e `docs/23-plano-de-testes.md`
  prescrevem Gradle Kotlin DSL, `br.com.somaisuma` e JDK 21, e ficarão desatualizados até um PR de
  documentação posterior (fora do escopo deste change).

### Suposições registradas

1. O módulo Maven sai de `backend/so-mais-uma/` e passa a viver em `backend/` direto, como o
   monorepo descrito em `docs/21-git-e-organizacao.md` espera.
2. Comandos de teste passam a ser `./mvnw verify` e `./mvnw test -Dtest='ReservaConcorrenciaIT'`;
   o job `backend` do CI roda Maven.
3. Lombok 1.18.48 sobre JDK 25 é um risco pontual nas entidades JPA; se falhar, os getters/setters
   são escritos à mão (entidade JPA não pode ser `record`).
4. Toda a especificação assume o profile `simulado` como padrão, para que `main` sempre suba sem
   variáveis de ambiente de terceiros.

## Capabilities

### New Capabilities

- `plataforma-backend`: convenções transversais da API — prefixo `/api/v1`, `ProblemDetail` RFC 9457
  com `codigo`/`subcodigo`/`campos[]`/`timestamp`, catálogo completo de códigos de erro, fuso
  `America/Sao_Paulo`, formatos de data/dinheiro/enum, os três profiles Spring, Swagger por profile,
  `/actuator/health`, migrations Flyway aditivas com `ddl-auto=validate`, contrato aditivo pós-N1.
- `autenticacao`: cadastro com auto-login, login por e-mail e senha, emissão e validação de JWT
  HS256, hash BCrypt, política de senha, bloqueio temporário de login, mapeamento de perfil para
  autoridade Spring, unicidade de e-mail e imutabilidade do perfil.
- `perfil-usuario`: leitura e edição dos próprios dados (nome, telefone, senha), sem alterar e-mail
  nem perfil; desativação de conta como item opcional.
- `quadras`: CRUD completo de quadra pelo DONO, listagem pública com filtro por esporte e cidade,
  detalhe com horários embutidos, soft delete bloqueado por reservas ativas futuras, autorização por
  propriedade.
- `horarios-funcionamento`: CRUD completo das faixas de funcionamento, uma por dia da semana 1..7,
  com as restrições de unicidade e de coerência de horário e o bloqueio por reservas ativas.
- `cep`: consulta de CEP pelo backend com fonte primária BrasilAPI CEP v2, fallback ViaCEP,
  devolução de latitude/longitude e erro dedicado quando as duas fontes falham.
- `disponibilidade-slots`: grade de slots de 60 minutos em hora cheia para uma quadra e uma data,
  com os quatro status possíveis, calculada em memória e limitada à janela de hoje até hoje+14 dias.
- `reservas`: criação com exclusividade de slot, listagem por situação para cliente e para dono,
  detalhe, edição de observação, cancelamento com prazos por perfil, expiração automática e
  compensação quando a cobrança Pix falha.
- `pagamentos-pix`: geração da cobrança Pix imediata no ato da reserva, consulta de estado para
  polling, confirmação idempotente pelos três caminhos, endpoint de simulação protegido, webhook do
  Inter, job de consulta com quota e tratamento de pagamento tardio e de valor divergente.

### Modified Capabilities

Nenhuma: `openspec/specs/` está vazio, este é o primeiro change do projeto.

## Impact

- **Código**: cria todo o backend sob `backend/src/main/java/br/com/puc/so_mais_uma/` nas camadas
  `config`, `security`, `controller`, `service`, `repository`, `entity`, `dto`, `exception`,
  `integracao`; move o módulo de `backend/so-mais-uma/` para `backend/`.
- **Banco**: `V1__init.sql` com as tabelas `usuario`, `quadra`, `horario_funcionamento`, `reserva`,
  `pagamento`, os CHECKs de enum e os índices, incluindo o índice único parcial
  `ux_reserva_slot_ativo`.
- **Dependências**: starters `webmvc`, `data-jpa`, `security`, `oauth2-resource-server`,
  `validation`, `flyway` (+ `flyway-database-postgresql`), `actuator`, `docker-compose`;
  `springdoc-openapi-starter-webmvc-ui` 3.1.0; Lombok; driver PostgreSQL; Testcontainers.
- **Integrações externas**: Banco Inter API Pix (sandbox `cdpj-sandbox.partners.uatinter.co` e
  produção), BrasilAPI CEP v2 e ViaCEP.
- **Consumidor**: o app Android depende deste contrato. RF03 (sessão local), RF22 (geolocalização),
  RF23 (cache Room) e RF24 (notificação local) são responsabilidade do cliente e **não** fazem parte
  deste change; o backend apenas fornece `latitude`/`longitude` nas quadras e o estado do pagamento
  para o polling.
- **Documentação**: `README.md`, `docs/09-arquitetura.md`, `docs/21-git-e-organizacao.md` e
  `docs/23-plano-de-testes.md` passam a divergir do build real (Maven/Java 25/pacote) e precisam de
  atualização em um PR próprio.
