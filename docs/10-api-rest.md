# API REST — contrato do backend

Contrato completo da API do backend Spring Boot do app "Só mais uma": convenções, autenticação, formato de erro, tabela de endpoints por módulo (com os dois CRUDs completos marcados), exemplos dos quatro endpoints centrais, regra de contrato aditivo após a N1 e documentação viva via Swagger/springdoc.

Dono do documento: Integrante D (com B na parte de Quadra/HorarioFuncionamento e C na parte de Reserva). Fonte executável do contrato: `GET /v3/api-docs` do backend rodando (springdoc 3.1.0).

## 1. Convenções gerais

| Item | Regra | Prioridade |
|---|---|---|
| Prefixo | Todas as rotas de negócio ficam sob `/api/v1`. Só `/actuator/health`, `/swagger-ui.html` e `/v3/api-docs` ficam fora do prefixo | obrigatório |
| Formato | `Content-Type: application/json; charset=utf-8` na requisição e na resposta. Chaves em camelCase (`precoHora`, `pixCopiaECola`). Sem envelope (`data`, `success`): a resposta é o recurso ou a lista | obrigatório |
| Datas e horas | Instantes em ISO-8601 com offset (`2026-10-10T19:00:00-03:00`). O backend normaliza tudo para `America/Sao_Paulo` (RNF12) e responde sempre com offset `-03:00`. Datas puras (`data=2026-10-10`) e horas puras (`horaAbertura: "08:00"`) só onde a tabela indicar | obrigatório |
| Dinheiro | String decimal com duas casas e ponto (`"80.00"`), nunca número JSON (evita erro de ponto flutuante no Kotlin). No banco é `NUMERIC(10,2)` | obrigatório |
| Identificadores | `id` numérico `Long` (BIGINT IDENTITY). Exceção: `txid` do pagamento é string alfanumérica de 32 caracteres (UUID sem hifens) | obrigatório |
| Enums | Strings em maiúsculas exatamente como os enums canônicos (`CLIENTE`, `FUTSAL`, `PENDENTE_PAGAMENTO`). Valor desconhecido na entrada gera 400 `VALIDACAO` | obrigatório |
| Autenticação | `Authorization: Bearer <jwt>` em toda rota que não esteja marcada como pública | obrigatório |
| Paginação | Não há paginação no MVP (listas pequenas: quadras da cidade, reservas de um usuário). Limitação documentada em RNF04; a lista de reservas devolve no máximo os últimos 12 meses | obrigatório (decisão) |
| Filtros | Por query string (`?esporte=FUTSAL&cidade=Belo%20Horizonte`, `?data=2026-10-10`, `?situacao=PROXIMAS`). Filtro ausente = sem filtro | obrigatório |
| Ordenação | Fixa por endpoint (quadras por nome; reservas por `inicio`). Ordenar por distância é feito no app (RF22), não na API | obrigatório |
| Validação | Bean Validation nos records de request (`@Valid` no controller). Erro devolve 400 com `campos[]`. Toda validação de tamanho (`@Size`, `@Digits`, `@Pattern`) espelha o limite da coluna correspondente no banco, para que entrada grande demais vire sempre 400 `VALIDACAO` com `campos[]` e nunca 500 `ERRO_INTERNO` | obrigatório |
| Cabeçalho `X-Dev-Key` | Exigido apenas em `/dev/**`; valor da variável `DEV_KEY`. Errado ou ausente = 403 | obrigatório (dev/sandbox) |
| HTTPS | Obrigatório fora do ambiente de desenvolvimento (Render fornece TLS). Em dev, `http://10.0.2.2:8080` no emulador e IP da LAN no celular físico, liberado só no build `debug` via `network_security_config` (RNF09) | obrigatório |
| Idempotência | `PUT`/`DELETE` são idempotentes; `POST /reservas` não é (cada chamada tenta um novo slot), por isso o app nunca reenvia automaticamente e o "voltar" da tela Pagamento não retorna a ConfirmarReserva (ver `docs/04-telas.md`) | obrigatório |

### 1.1 Cadeia de tratamento de uma requisição

```mermaid
flowchart LR
  A[Requisicao HTTP] --> B[Filtro JWT\nSecurityConfig]
  B -- sem token / invalido --> E401[401 TOKEN_INVALIDO]
  B --> C[Controller\n@Valid + @PreAuthorize]
  C -- perfil errado --> E403[403 ACESSO_NEGADO]
  C -- DTO invalido --> E400[400 VALIDACAO + campos]
  C --> D[Service\nregras + @Transactional]
  D -- nao encontrado --> E404[404 NAO_ENCONTRADO]
  D -- conflito de estado --> E409[409 *]
  D -- regra de negocio --> E422[422 REGRA_NEGOCIO + subcodigo]
  D -- gateway Pix falhou --> E502[502 PAGAMENTO_INDISPONIVEL]
  D --> R[2xx + DTO de resposta]
  E401 & E403 & E400 & E404 & E409 & E422 & E502 --> H[GlobalExceptionHandler\nProblemDetail + codigo]
```

Versão textual: filtro JWT (401) -> controller com `@Valid` e `@PreAuthorize` (400/403) -> service com regras e transação (404/409/422/502) -> `GlobalExceptionHandler` converte toda exceção em `ProblemDetail` com o campo `codigo` (e o `subcodigo` nas respostas 422).

## 2. Autenticação e autorização

| Aspecto | Decisão |
|---|---|
| Token | JWT HS256 assinado com `JWT_SECRET` (>= 32 bytes, variável de ambiente), gerado por `NimbusJwtEncoder` e validado por `NimbusJwtDecoder` (Spring Security 7, sem jjwt). Validade de 7 dias (RNF01) |
| Claims | `sub` = id do usuário, `perfil` = `CLIENTE` ou `DONO`, `nome`, `iat`, `exp`. O app guarda `token` e `expiraEm` em `SessaoDataStore` (RF03) |
| Authorities | Claim `perfil` vira `ROLE_CLIENTE` / `ROLE_DONO` via `PerfilAuthoritiesConverter`. `@PreAuthorize("hasRole('DONO')")` nas escritas de Quadra e HorarioFuncionamento; `hasRole('CLIENTE')` em `POST /reservas` (RN02) |
| Propriedade | Checada no service, nunca só no controller: `quadra.dono.id == usuarioAutenticado.id` (RN03) e `reserva.cliente.id == usuarioAutenticado.id` (RN04). Falha = 403 `ACESSO_NEGADO`, mesmo que o recurso exista |
| Rotas públicas | `POST /auth/registrar`, `POST /auth/login`, `POST /webhooks/inter/pix/{segredo}`, `GET /actuator/health`, Swagger (só fora de `inter-prod`) |
| Logout | Não existe endpoint: o JWT não é revogável no MVP (RNF03). Sair = limpar DataStore e Room no app (RF03) |
| 401 x 429 | `CREDENCIAL_INVALIDA` (login errado) é tratado na tela de Login; `TOKEN_INVALIDO` (token ausente/expirado em rota protegida) derruba a sessão no app uma única vez, sem retry (evita loop durante o polling de pagamento). `LOGIN_BLOQUEADO` (429) após 5 falhas em 15 minutos (RF04) |

## 3. Formato de erro (RFC 9457 + `codigo`)

Toda resposta de erro é um `ProblemDetail` do Spring com campos de extensão: `codigo` (enum `CodigoErro`, estável, é o que o app usa para decidir a tela) e `timestamp` sempre; `subcodigo` (enum `SubcodigoErro`) somente nas respostas 422, onde `codigo` é sempre `REGRA_NEGOCIO` e o `subcodigo` diz qual regra falhou; `campos[]` nos erros de validação; e `reservaId` (Long) no 422 `RESERVA_PENDENTE_EXISTENTE`. `detail` é uma frase em português pronta para exibir no snackbar (RNF06).

As extensões do `ProblemDetail`, portanto, são `codigo`, `subcodigo` (só em 422), `timestamp`, `campos[]` e `reservaId`. No app elas viram `ErroApi(status, codigo, subcodigo, detail, campos)`, montado pelo `ProblemDetailParser` (ver `docs/09-arquitetura.md` §5).

```json
{
  "type": "about:blank",
  "title": "Dados inválidos",
  "status": 400,
  "detail": "Verifique os campos destacados.",
  "instance": "/api/v1/quadras",
  "codigo": "VALIDACAO",
  "timestamp": "2026-09-20T14:03:11.402-03:00",
  "campos": [
    { "campo": "precoHora", "mensagem": "deve ser maior ou igual a 1.00" },
    { "campo": "cep", "mensagem": "deve ter 8 dígitos" }
  ]
}
```

### 3.1 Tabela de códigos

| HTTP | `codigo` | Quando acontece | Regra / RF | Reação esperada do app |
|---|---|---|---|---|
| 400 | `VALIDACAO` | Bean Validation falhou, JSON malformado, enum desconhecido, `inicio` fora da hora cheia (RN06), `motivo` ausente no cancelamento pelo DONO (RN13) | RNF06, RN06 | Marcar campos de `campos[]`; se vazio, snackbar com `detail` |
| 401 | `CREDENCIAL_INVALIDA` | E-mail ou senha incorretos em `/auth/login` | RF02 | Mensagem na tela de Login; não derruba sessão |
| 401 | `TOKEN_INVALIDO` | Token ausente, expirado ou assinatura inválida em rota protegida | RNF01, RNF03 | `SessaoDataStore.limpar()` + Room limpo + Login (evento único) |
| 403 | `ACESSO_NEGADO` | Perfil sem permissão (DONO em `POST /reservas`), recurso de outro usuário (RN03, RN04), `X-Dev-Key` errada | RN01–RN04 | Snackbar "Você não tem acesso a este item" e voltar |
| 404 | `NAO_ENCONTRADO` | Id inexistente; quadra inativa vista por CLIENTE (RN09); reserva sem pagamento; CEP inexistente | RF08, RF09, RN09 | Estado vazio/erro da tela |
| 409 | `EMAIL_JA_CADASTRADO` | E-mail já existe no cadastro | RN20 | Marcar campo e-mail |
| 409 | `HORARIO_INDISPONIVEL` | Índice único parcial `ux_reserva_slot_ativo` rejeitou o INSERT: outro cliente pegou o slot | RN08, RF13 | Snackbar + voltar ao DetalheQuadra e recarregar slots |
| 409 | `DIA_JA_CADASTRADO` | `POST /horarios-funcionamento` para `diaSemana` que já tem linha | RN19, RF11 | Tela HorariosQuadra recarrega e usa `PUT` |
| 409 | `QUADRA_COM_RESERVAS` | `DELETE /quadras/{id}` com reserva ativa futura | RN16, RF10 | Diálogo "Cancele as reservas futuras antes de desativar" com atalho para ReservasQuadra |
| 409 | `HORARIO_COM_RESERVAS` | `PUT`/`DELETE` de horário que deixaria reserva ativa futura fora do funcionamento | RN16, RF11 | Idem, na tela HorariosQuadra |
| 422 | `REGRA_NEGOCIO` + `subcodigo: DATA_FORA_DA_JANELA` | `data` ou `inicio` além de hoje + 14 dias (passado é 400 `VALIDACAO`) | RN09, RF12 | Seletor de data limita a hoje + 14 |
| 422 | `REGRA_NEGOCIO` + `subcodigo: FORA_DO_FUNCIONAMENTO` | Slot fora do horário de funcionamento ou dia fechado | RN09, RN19 | Recarregar slots |
| 422 | `REGRA_NEGOCIO` + `subcodigo: RESERVA_PENDENTE_EXISTENTE` | Cliente já tem uma reserva `PENDENTE_PAGAMENTO`; a resposta traz a extensão `reservaId` (Long) | RN11 | App navega para `DetalheReserva(reservaId)` (botão Pagar agora) |
| 422 | `REGRA_NEGOCIO` + `subcodigo: CANCELAMENTO_FORA_DO_PRAZO` | CLIENTE cancelando CONFIRMADA com menos de 2 h; DONO após o início | RN13, RF17 | Snackbar com a regra |
| 422 | `REGRA_NEGOCIO` + `subcodigo: TRANSICAO_INVALIDA` | UPDATE condicional afetou 0 linhas: outro fluxo mudou o status antes (cancelar reserva já confirmada/expirada, confirmar pagamento já pago, editar reserva encerrada) | RN12, RN15 | Recarregar o detalhe e mostrar o status atual |
| 422 | `REGRA_NEGOCIO` + `subcodigo: SENHA_ATUAL_INCORRETA` | `PUT /usuarios/me` com `senhaAtual` errada | RF05 | Marcar campo |
| 429 | `LOGIN_BLOQUEADO` | 5 falhas de login em 15 min para o mesmo e-mail | RF04, RNF01 | Mensagem com o tempo restante (`detail`) |
| 500 | `ERRO_INTERNO` | Exceção não mapeada (nunca expõe stack trace) | RNF10 | `ErroBox` com "Tentar novamente" |
| 502 | `PAGAMENTO_INDISPONIVEL` | Gateway Pix falhou ao criar a cobrança; reserva cancelada por `SISTEMA` e slot liberado | RN17, RF19 | Snackbar "Não foi possível gerar a cobrança, tente novamente" |
| 503 | `CEP_INDISPONIVEL` | BrasilAPI e ViaCEP falharam | RF09 | Permitir preencher endereço e lat/lon manualmente |

Regras: o app decide pelo par `codigo` + `subcodigo` (nos 422) e nunca por `detail`; `title` segue o status HTTP; `codigo` e `subcodigo` nunca são renomeados depois da N1 (seção 7).

Exemplo de 422 em `POST /api/v1/reservas` quando o cliente já tem uma reserva pendente (RN11):

```json
{
  "type": "about:blank",
  "title": "Regra de negócio",
  "status": 422,
  "detail": "Você já tem uma reserva aguardando pagamento. Conclua ou cancele antes de reservar outro horário.",
  "instance": "/api/v1/reservas",
  "codigo": "REGRA_NEGOCIO",
  "subcodigo": "RESERVA_PENDENTE_EXISTENTE",
  "timestamp": "2026-10-08T14:05:11.302-03:00",
  "reservaId": 42
}
```

O app lê `reservaId` e navega para `DetalheReserva(42)`, que tem o botão "Pagar agora" (ver `docs/04-telas.md`); nunca vai direto para a tela Pagamento.

## 4. Endpoints por módulo

Legenda: rotas abaixo são relativas a `/api/v1` (salvo infra). Perfil: **público**, **ambos** (qualquer autenticado), **CLIENTE**, **DONO**, **DONO (dono)** = precisa ser o dono da quadra. Prioridade: Must Have (N1) = OBR-N1, Must Have (N2) = OBR-N2, Should Have = REC, Could Have = OPC. Marcações **[CRUD-C/R/U/D]** apontam os dois CRUDs completos exigidos pelo critério 3 (Quadra e HorarioFuncionamento).

### 4.1 Autenticação

| Método | Rota | Objetivo | Perfil | Respostas / códigos | RF | Prioridade |
|---|---|---|---|---|---|---|
| POST | `/auth/registrar` | Criar usuário (`nome`, `email`, `senha`, `telefone?`, `perfil`) e devolver token (auto-login) | público | 201 `TokenResponse`; 400 `VALIDACAO`; 409 `EMAIL_JA_CADASTRADO` | RF01 | Must Have (N1) |
| POST | `/auth/login` | `email` + `senha` -> token JWT de 7 dias | público | 200 `TokenResponse`; 400; 401 `CREDENCIAL_INVALIDA`; 429 `LOGIN_BLOQUEADO` | RF02, RF04 | Must Have (N1); 429 em N2 |
| — | (sem endpoint) | Logout é local: limpa `SessaoDataStore` e `AppDatabase` | — | — | RF03 | Must Have (N1) |

`RegistrarRequest`: `telefone` (opcional, `@Size(max=20)`, espelhando a coluna).

### 4.2 Usuários

| Método | Rota | Objetivo | Perfil | Respostas / códigos | RF | Prioridade |
|---|---|---|---|---|---|---|
| GET | `/usuarios/me` | Dados do usuário logado | ambos | 200 `UsuarioResponse`; 401 | RF05 | Must Have (N1) |
| PUT | `/usuarios/me` | Editar `nome`, `telefone` e, opcionalmente, `senhaAtual` + `novaSenha` (perfil e e-mail não mudam, RN20) | ambos | 200 `UsuarioResponse`; 400; 422 `REGRA_NEGOCIO` (`subcodigo: SENHA_ATUAL_INCORRETA`) | RF05 | Must Have (N1) |
| DELETE | `/usuarios/me` | Desativar a própria conta (`usuario.ativo=false`) | ambos | 204; 409 `QUADRA_COM_RESERVAS` (DONO com reservas futuras) | — | Could Have |

### 4.3 Quadras — CRUD completo nº 1

| Método | Rota | Objetivo | Perfil | Respostas / códigos | RF | Prioridade |
|---|---|---|---|---|---|---|
| GET | `/quadras?esporte=&cidade=` | Listar quadras ativas com filtro opcional por `TipoEsporte` e cidade (ordenação por distância é no app) **[CRUD-R lista]** | ambos | 200 `List<QuadraResponse>` | RF07 | Must Have (N1) |
| GET | `/quadras/{id}` | Detalhe da quadra com `horariosFuncionamento[]` embutidos **[CRUD-R item]** | ambos | 200 `QuadraResponse`; 404 (inexistente; inativa para CLIENTE) | RF08 | Must Have (N1) |
| GET | `/quadras/minhas` | Quadras do DONO logado, inclusive inativas **[CRUD-R do dono]** | DONO | 200 `List<QuadraResponse>` | RF06 | Must Have (N1) |
| POST | `/quadras` | Criar quadra; `donoId` = usuário logado (RN01) **[CRUD-C]** | DONO | 201 `QuadraResponse` + header `Location`; 400; 403 | RF06 | Must Have (N1) |
| PUT | `/quadras/{id}` | Editar todos os campos editáveis **[CRUD-U]** | DONO (dono) | 200; 400; 403; 404 | RF06 | Must Have (N1) |
| DELETE | `/quadras/{id}` | Desativar (soft delete, `ativa=false`); some da listagem pública **[CRUD-D]** | DONO (dono) | 204; 403; 404; 409 `QUADRA_COM_RESERVAS` | RF06, RF10 | Must Have (N1) |

`QuadraRequest` (POST/PUT): `nome` (`@NotBlank @Size(max=100)`), `tipoEsporte` (`@NotNull`), `descricao` (`@Size(max=500)`), `precoHora` (`@DecimalMin("1.00") @Digits(integer=8, fraction=2)`), `cep` (`@Pattern("\\d{8}")`), `logradouro` (`@Size(max=150)`), `numero` (`@NotBlank @Size(max=10)`), `bairro` (`@Size(max=80)`), `cidade` (`@NotBlank @Size(max=80)`), `uf` (`@Size(min=2,max=2) @Pattern("[A-Z]{2}")`), `latitude`/`longitude` (opcionais, `-90..90` / `-180..180`), `fotoUrl` (`@Size(max=300)`).

### 4.4 Horários de funcionamento — CRUD completo nº 2

| Método | Rota | Objetivo | Perfil | Respostas / códigos | RF | Prioridade |
|---|---|---|---|---|---|---|
| GET | `/quadras/{id}/horarios-funcionamento` | Listar as faixas (0 a 7 linhas; dia ausente = fechado, RN19) **[CRUD-R]** | ambos | 200 `List<HorarioFuncionamentoResponse>`; 404 | RF11 | Must Have (N1) |
| POST | `/quadras/{id}/horarios-funcionamento` | Criar faixa `{diaSemana 1..7, horaAbertura, horaFechamento}` **[CRUD-C]** | DONO (dono) | 201; 400 (`horaFechamento <= horaAbertura`); 403; 404; 409 `DIA_JA_CADASTRADO` | RF11 | Must Have (N1) |
| PUT | `/quadras/{id}/horarios-funcionamento/{hid}` | Alterar abertura/fechamento da faixa **[CRUD-U]** | DONO (dono) | 200; 400; 403; 404; 409 `HORARIO_COM_RESERVAS` | RF11 | Must Have (N1) |
| DELETE | `/quadras/{id}/horarios-funcionamento/{hid}` | Remover faixa (dia passa a fechado) **[CRUD-D]** | DONO (dono) | 204; 403; 404; 409 `HORARIO_COM_RESERVAS` | RF11 | Must Have (N1) |

A tela HorariosQuadra tem 7 linhas fixas (segunda a domingo) e cada interação dispara a operação individual correspondente: ligar o switch = `POST`, mudar hora = `PUT`, desligar = `DELETE`.

### 4.5 Slots (calculados, não persistidos)

| Método | Rota | Objetivo | Perfil | Respostas / códigos | RF | Prioridade |
|---|---|---|---|---|---|---|
| GET | `/quadras/{id}/slots?data=2026-10-10` | Grade de slots de 60 min da data = funcionamento do dia − reservas ativas − horas passadas; cada slot `{inicio, fim, valor, status}` com `StatusSlot` | ambos | 200 `List<SlotResponse>`; 400 (`data` inválida); 404; 422 `REGRA_NEGOCIO` (`subcodigo: DATA_FORA_DA_JANELA`, além de hoje+14) | RF12 | Must Have (N2); backend pronto na N1 |

### 4.6 Reservas

| Método | Rota | Objetivo | Perfil | Respostas / códigos | RF | Prioridade |
|---|---|---|---|---|---|---|
| POST | `/reservas` | `{quadraId, inicio, observacao?}` -> reserva `PENDENTE_PAGAMENTO` + cobrança Pix (RN06–RN11, RN17) | CLIENTE | 201 `ReservaResponse` (com `pagamento`); 400 `VALIDACAO` (hora não cheia, passado); 403 (DONO); 404 (quadra inexistente/inativa); **409 `HORARIO_INDISPONIVEL`**; 422 `REGRA_NEGOCIO` (`subcodigo: DATA_FORA_DA_JANELA` / `FORA_DO_FUNCIONAMENTO` / `RESERVA_PENDENTE_EXISTENTE`, este último com a extensão `reservaId`); 502 `PAGAMENTO_INDISPONIVEL` | RF13, RF19 | Must Have (N2); backend pronto na N1 |
| GET | `/reservas?situacao=PROXIMAS\|HISTORICO` | CLIENTE: as suas; DONO: as das suas quadras. `PROXIMAS` = `fim >= agora` e status ativo; `HISTORICO` = o resto. Sem `situacao` = tudo (12 meses) | ambos | 200 `List<ReservaResponse>` | RF15, RF18 | Must Have (N2) |
| GET | `/reservas/{id}` | Detalhe com `pagamento` embutido | CLIENTE (sua) / DONO (sua quadra) | 200; 403; 404 | RF15 | Must Have (N2) |
| PATCH | `/reservas/{id}` | `{observacao}` (RN15). `{inicio}` enquanto `PENDENTE_PAGAMENTO` é Could Have (remarcar) | CLIENTE (sua) | 200; 400; 403; 404; 422 `REGRA_NEGOCIO` (`subcodigo: TRANSICAO_INVALIDA`, reserva encerrada) | RF16 | Must Have (N2) |
| POST | `/reservas/{id}/cancelar` | `{motivo?}` -> `CANCELADA`; grava `canceladoPor`, `motivoCancelamento`, `canceladoEm` (RN13, RN14) | CLIENTE (sua) / DONO (sua quadra) | 200 `ReservaResponse`; 400 (DONO sem `motivo`); 403; 404; 422 `REGRA_NEGOCIO` (`subcodigo: CANCELAMENTO_FORA_DO_PRAZO` / `TRANSICAO_INVALIDA`) | RF17 | Must Have (N2) |
| GET | `/quadras/{id}/reservas?data=2026-10-10` | Reservas da quadra na data (com `clienteNome`/`clienteTelefone`); sem `data` = próximas | DONO (dono) | 200; 403; 404 | RF18 | Must Have (N2) |

`CriarReservaRequest`: `quadraId` (`@NotNull`), `inicio` (`@NotNull @Future OffsetDateTime`), `observacao` (`@Size(max=200)`). `CancelarReservaRequest`: `motivo` (`@Size(max=200)`, obrigatório quando o chamador é DONO — validado no service).

### 4.7 Pagamentos

| Método | Rota | Objetivo | Perfil | Respostas / códigos | RF | Prioridade |
|---|---|---|---|---|---|---|
| GET | `/reservas/{id}/pagamento` | Estado atual da cobrança para o polling do app (`{txid, provedor, status, valor, pixCopiaECola, expiraEm, pagoEm}`). Sem parâmetros | CLIENTE (sua) | 200 `PagamentoResponse`; 403; 404 (reserva sem pagamento) | RF20 | Must Have (N2) |
| POST | `/dev/pagamentos/{txid}/confirmar` | Simular pagamento: profile `simulado` marca `PAGO` direto; `inter-sandbox` chama `POST /pix/v2/cob/pagar/{txid}` no sandbox e deixa o job/polling detectar; não existe em `inter-prod`. Antes de qualquer efeito, o service confere que o pagamento pertence ao usuário autenticado (`pagamento.reserva.cliente.id == usuarioAutenticado.id`, mesma checagem de propriedade da RN04); de outro usuário = 403 `ACESSO_NEGADO`, mesmo com `X-Dev-Key` válida | JWT + `X-Dev-Key` | 200 `PagamentoResponse`; 403 `ACESSO_NEGADO` (`X-Dev-Key` errada **ou** pagamento de outro usuário); 404; 422 `REGRA_NEGOCIO` (`subcodigo: TRANSICAO_INVALIDA`); 502 | RF21 | Must Have (N2) |
| POST | `/webhooks/inter/pix/{segredo}` | Callback do Inter (array JSON de pix recebidos); valida `txid` existente, status `PENDENTE` e `valor` igual; idempotente; ignora desconhecidos | público (profiles `inter-*`) | 200 (corpo válido, mesmo sem efeito); 400 (não é array) | RF20 | Should Have |

O botão "Já paguei" da tela Pagamento não usa parâmetro nem rota própria: ele apenas dispara imediatamente mais um ciclo do polling que o app já faz em `GET /reservas/{id}/pagamento`, sem chamada extra ao gateway.

### 4.8 CEP (segunda API externa)

| Método | Rota | Objetivo | Perfil | Respostas / códigos | RF | Prioridade |
|---|---|---|---|---|---|---|
| GET | `/cep/{cep}` | Proxy para BrasilAPI CEP v2 com fallback ViaCEP; devolve endereço e, quando disponível, `latitude`/`longitude` | DONO | 200 `CepResponse`; 400 (não são 8 dígitos); 404; 503 `CEP_INDISPONIVEL` | RF09 | Must Have (N1) |

### 4.9 Infraestrutura

| Método | Rota | Objetivo | Perfil | Respostas / códigos | RF | Prioridade |
|---|---|---|---|---|---|---|
| GET | `/actuator/health` | Health check; usado para aquecer o Render antes da demo | público | 200 `{"status":"UP"}` | RNF05 | Must Have (N2) |
| GET | `/swagger-ui.html`, `/v3/api-docs` | Contrato vivo (springdoc 3.1.0); desligado em `inter-prod` | público em dev | 200 | RNF10 | Must Have (N1) |

## 5. DTOs de resposta (campos)

| Record | Campos |
|---|---|
| `TokenResponse` | `token`, `expiraEm`, `usuario: UsuarioResponse` |
| `UsuarioResponse` | `id`, `nome`, `email`, `telefone`, `perfil`, `criadoEm` |
| `QuadraResponse` | `id`, `donoId`, `nome`, `tipoEsporte`, `descricao`, `precoHora`, `cep`, `logradouro`, `numero`, `bairro`, `cidade`, `uf`, `latitude`, `longitude`, `fotoUrl`, `ativa`, `horariosFuncionamento[]` (só em `GET /quadras/{id}`), `atualizadoEm` |
| `HorarioFuncionamentoResponse` | `id`, `quadraId`, `diaSemana` (1 = segunda … 7 = domingo), `horaAbertura` (`"08:00"`), `horaFechamento` (`"22:00"`) |
| `SlotResponse` | `inicio`, `fim`, `valor`, `status` (`LIVRE`, `OCUPADO`, `PASSADO`, `FECHADO`) |
| `ReservaResponse` | `id`, `quadraId`, `quadraNome`, `quadraEndereco`, `clienteId`, `clienteNome` e `clienteTelefone` (somente para DONO), `inicio`, `fim`, `valor`, `status`, `observacao`, `expiraEm`, `canceladoPor`, `motivoCancelamento`, `canceladoEm`, `criadoEm`, `pagamento: PagamentoResponse?` |
| `PagamentoResponse` | `txid`, `provedor` (`INTER`/`SIMULADO`), `status` (`PENDENTE`, `PAGO`, `EXPIRADO`, `CANCELADO`), `valor`, `pixCopiaECola`, `expiraEm`, `pagoEm` |
| `CepResponse` | `cep`, `logradouro`, `bairro`, `cidade`, `uf`, `latitude?`, `longitude?`, `fonte` (`BRASILAPI`/`VIACEP`) |

Nunca aparecem em nenhuma resposta: `senhaHash`, dados do pagador (`infoPagador`, `devedor`, CPF), `endToEndId` (fica só no banco), `location` do Inter, segredos.

## 6. Exemplos dos quatro endpoints centrais

### 6.1 `POST /api/v1/auth/login`

Requisição:

```json
{ "email": "cliente@demo.com", "senha": "Senha123" }
```

Resposta `200 OK`:

```json
{
  "token": "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIiwicGVyZmlsIjoiQ0xJRU5URSIsIm5vbWUiOiJDbGllbnRlIERlbW8iLCJpYXQiOjE3OTE4MzY4MDAsImV4cCI6MTc5MjQ0MTYwMH0.assinatura",
  "expiraEm": "2026-10-17T19:00:00-03:00",
  "usuario": {
    "id": 1,
    "nome": "Cliente Demo",
    "email": "cliente@demo.com",
    "telefone": "31999990000",
    "perfil": "CLIENTE",
    "criadoEm": "2026-09-15T10:00:00-03:00"
  }
}
```

Erro `401` -> `codigo: "CREDENCIAL_INVALIDA"`; após a quinta falha em 15 min, `429` -> `codigo: "LOGIN_BLOQUEADO"`, `detail: "Muitas tentativas. Tente novamente em 14 minutos."`.

### 6.2 `POST /api/v1/reservas`

Requisição (`Authorization: Bearer <token de CLIENTE>`):

```json
{
  "quadraId": 3,
  "inicio": "2026-10-10T19:00:00-03:00",
  "observacao": "Levamos as bolas"
}
```

Resposta `201 Created`, `Location: /api/v1/reservas/42`:

```json
{
  "id": 42,
  "quadraId": 3,
  "quadraNome": "Arena Society Savassi",
  "quadraEndereco": "Rua Pernambuco, 1000 - Savassi, Belo Horizonte/MG",
  "clienteId": 1,
  "inicio": "2026-10-10T19:00:00-03:00",
  "fim": "2026-10-10T20:00:00-03:00",
  "valor": "80.00",
  "status": "PENDENTE_PAGAMENTO",
  "observacao": "Levamos as bolas",
  "expiraEm": "2026-10-08T14:20:11-03:00",
  "canceladoPor": null,
  "motivoCancelamento": null,
  "canceladoEm": null,
  "criadoEm": "2026-10-08T14:05:11-03:00",
  "pagamento": {
    "txid": "3f9c2b7e1d4a4c6f9a8b7c6d5e4f3a2b",
    "provedor": "INTER",
    "status": "PENDENTE",
    "valor": "80.00",
    "pixCopiaECola": "00020126830014BR.GOV.BCB.PIX2561qrcodepix-h.bancointer.com.br/pj-s/v2/cob/3f9c2b7e...5204000053039865802BR5915SO MAIS UMA LTDA6014BELO HORIZONTE62070503***63041D3D",
    "expiraEm": "2026-10-08T14:20:11-03:00",
    "pagoEm": null
  }
}
```

`expiraEm` = `criadoEm` + 15 min (RN10) e é o mesmo instante da cobrança Pix (`calendario.expiracao = 900`). Se o gateway falhar, a resposta é `502 PAGAMENTO_INDISPONIVEL` e a reserva já foi cancelada por `SISTEMA` (RN17): o app não precisa desfazer nada.

### 6.3 `GET /api/v1/reservas/42/pagamento`

Resposta `200 OK` durante o polling (a cada 5 s por 2 min, depois a cada 10 s, só com a tela Pagamento visível — RNF04):

```json
{
  "txid": "3f9c2b7e1d4a4c6f9a8b7c6d5e4f3a2b",
  "provedor": "INTER",
  "status": "PAGO",
  "valor": "80.00",
  "pixCopiaECola": "00020126830014BR.GOV.BCB.PIX2561qrcodepix-h.bancointer.com.br/pj-s/v2/cob/3f9c2b7e...63041D3D",
  "expiraEm": "2026-10-08T14:20:11-03:00",
  "pagoEm": "2026-10-08T14:07:40-03:00"
}
```

O app encerra o polling quando `status` sai de `PENDENTE` ou quando `expiraEm` passa; em `PAGO` dispara a notificação local (RF24) e navega para DetalheReserva.

### 6.4 Erro `409` em `POST /api/v1/reservas`

```json
{
  "type": "about:blank",
  "title": "Conflito",
  "status": 409,
  "detail": "Esse horário acabou de ser reservado. Escolha outro.",
  "instance": "/api/v1/reservas",
  "codigo": "HORARIO_INDISPONIVEL",
  "timestamp": "2026-10-08T14:05:11.302-03:00"
}
```

Origem: `DataIntegrityViolationException` no `saveAndFlush` por causa do índice `ux_reserva_slot_ativo` (ver `docs/07-regras-de-negocio.md`, RN08). Comprovado por `ReservaConcorrenciaIT` (10 threads -> 1 x 201 e 9 x 409).

## 7. Contrato aditivo após a N1

Motivo: o APK instalado nos celulares dos testes com usuários (09 a 13/11) e no beta do Checkpoint 2 precisa continuar funcionando enquanto o backend evolui (RNF09, risco R17 em `docs/19-riscos.md`).

| Regra (vale a partir da tag `v0.1-n1`, qui 01/10/2026, véspera da apresentação da N1) | Prioridade |
|---|---|
| Campos de resposta só são **adicionados**, sempre opcionais (`null` permitido); nunca removidos, renomeados ou com tipo alterado | obrigatório |
| Campos de requisição novos são opcionais com valor padrão no backend | obrigatório |
| Valores de enum não são removidos; valor novo só entra junto com atualização do app. O app usa `ignoreUnknownKeys = true` e `coerceInputValues = true` no `Json` do kotlinx.serialization e trata enum desconhecido como estado "Outro" sem quebrar | obrigatório |
| `codigo` e `subcodigo` de erro nunca mudam de nome; códigos e subcódigos novos podem ser criados (o app cai no tratamento genérico por status HTTP) | obrigatório |
| Rotas e métodos existentes não mudam de semântica; endpoint novo é permitido. Mudança incompatível exigiria `/api/v2` (não previsto no MVP) | obrigatório |
| Snapshot do contrato da N1 commitado em `docs/api/openapi-n1.json` (exportado de `/v3/api-docs`); o PR que altera um DTO anexa o diff contra o snapshot | recomendado |

Não há cabeçalho de versão do app nem filtro correspondente no backend: são poucos participantes e os aparelhos são instalados pelo próprio grupo, então a versão instalada é conferida diretamente no aparelho quando surgir dúvida.

## 8. Swagger / springdoc

| Item | Decisão | Prioridade |
|---|---|---|
| Dependência | `org.springdoc:springdoc-openapi-starter-webmvc-ui:3.1.0` (linha compatível com Spring Boot 4.1) | obrigatório |
| URLs | `/swagger-ui.html` (interface) e `/v3/api-docs` (JSON OpenAPI 3.1) | obrigatório |
| Segurança | `OpenApiConfig` declara `@SecurityScheme(name = "bearerAuth", type = HTTP, scheme = "bearer", bearerFormat = "JWT")` e aplica globalmente; o botão **Authorize** recebe o token devolvido por `/auth/login` | obrigatório |
| Anotações | `@Tag` por controller (Autenticacao, Usuarios, Quadras, HorariosFuncionamento, Slots, Reservas, Pagamentos, CEP, Dev, Webhooks), `@Operation(summary)` por endpoint e `@ApiResponse` listando os `codigo` possíveis; schemas saem dos records automaticamente | obrigatório |
| Ambientes | Ligado em `simulado` e `inter-sandbox`; `springdoc.api-docs.enabled=false` e `springdoc.swagger-ui.enabled=false` em `inter-prod` | obrigatório |
| Uso na disciplina | Evidência do critério 2 e do critério 3 (CRUD x2): abrir o Swagger, autenticar como `dono@demo.com`, executar `POST /quadras` e mostrar 403 com token de CLIENTE; na N1, os endpoints de reserva e pagamento são demonstrados só pelo Swagger, antes das telas | obrigatório |
| Scripts | Os arquivos `scripts/api/*.http` (IntelliJ HTTP Client / VS Code REST Client) repetem os fluxos principais contra `http://localhost:8080`; variáveis em `scripts/http-client.env.json` | recomendado |

## 9. Rastreabilidade

| Critério / requisito | Evidência neste contrato |
|---|---|
| Critério 3 — CRUD completo de >= 2 entidades | Seções 4.3 e 4.4: `POST`/`GET`/`PUT`/`DELETE` individuais de Quadra e de HorarioFuncionamento |
| Critério 3 — autenticação e 2 perfis | Seção 2: JWT, `ROLE_CLIENTE`/`ROLE_DONO`, coluna Perfil da tabela |
| Critério 4 — API externa | 4.7 (Inter Pix via `PixGateway`) e 4.8 (BrasilAPI/ViaCEP) |
| Critério 6 — validações e erros | Seções 1, 3 e 3.1: Bean Validation, `ProblemDetail` + `codigo` + `subcodigo` + `campos[]` |
| RNF09 — comunicação com a API | Seções 1 e 7 |
| RNF10 — manutenibilidade | Seção 8 (contrato vivo) e 7 (snapshot da N1) |
| RN08 — exclusividade do slot | 6.4 (409 `HORARIO_INDISPONIVEL`) |
| RN17 — falha do gateway | 4.6 e 6.2 (502 `PAGAMENTO_INDISPONIVEL`) |
