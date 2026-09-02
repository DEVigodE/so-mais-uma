# 17. Checklist da Entrega N1 (28/09 a 02/10/2026)

Lista verificável do que precisa estar pronto para a apresentação da N1, separada por área, com responsável e forma de evidência, mais o calendário da semana (congelamento em `release/n1` na terça 29/09, teste do README em máquina limpa, tag `v0.1-n1`) e o roteiro de 5 minutos da demo.

Escopo da N1 (ver docs/02-escopo-mvp.md): Must Have (N1) = RF01, RF02, RF03, RF05, RF06, RF07, RF08, RF09, RF10, RF11 com telas + backend de RF12, RF13, RF14 e RF19 pronto e demonstrável via Swagger. Reserva e pagamento **não** têm tela na N1; isso é dito na apresentação como decisão de escopo, não como atraso.

Convenção: cada item traz **Resp.** (titular; o suplente revisa) e **Evidência** (o que se mostra em menos de 1 minuto).

## 17.1 Documentação

- [ ] `README.md` com instalação e execução: pré-requisitos (JDK 21, Docker, Android Studio Quail 4), `docker compose up -d` + `./gradlew bootRun` (profile `simulado`), abrir `android/` e rodar no emulador (`http://10.0.2.2:8080`) ou celular via `adb`, usuários de demonstração do seed, tabela de versões verificada em 01/09/2026 — **Resp.:** A · **Evidência:** teste em máquina limpa registrado em issue (ver 17.8)
- [ ] `docs/00-indice.md` listando os 23 documentos com uma linha cada — **Resp.:** A · **Evidência:** abrir no GitHub
- [ ] `docs/01-visao-do-produto.md`: problema, domínio, público-alvo (critério 1) — **Resp.:** A · **Evidência:** seção citada no slide 1
- [ ] `docs/02-escopo-mvp.md`: Must Have (N1), Must Have (N2), Should, Could, Fora do MVP com motivo — **Resp.:** A · **Evidência:** tabela de classificação
- [ ] `docs/03-perfis-e-permissoes.md`: `PerfilUsuario {CLIENTE, DONO}` e matriz de permissões — **Resp.:** A · **Evidência:** matriz + 403 no Swagger
- [ ] `docs/04-telas.md`: 13 telas + Splash, grafo de navegação em mermaid, link do Figma — **Resp.:** B · **Evidência:** abrir o Figma pelo link
- [ ] `docs/05-requisitos-funcionais.md`: RF01–RF24 com tag de prioridade e módulo — **Resp.:** A · **Evidência:** tabela com tags OBR-N1/OBR-N2/REC/OPC
- [ ] `docs/06-requisitos-nao-funcionais.md`: RNF01–RNF12 mensuráveis — **Resp.:** A · **Evidência:** tabela
- [ ] `docs/07-regras-de-negocio.md`: RN01–RN20 com código HTTP associado — **Resp.:** C · **Evidência:** RN08 citada ao mostrar o 409
- [ ] `docs/08-modelagem-banco.md`: `erDiagram` das 5 tabelas, dicionário de dados, decisões (enum `TipoEsporte`, slots calculados, índice único parcial) — **Resp.:** B · **Evidência:** diagrama renderizado no GitHub = `V1__init.sql`
- [ ] `docs/09-arquitetura.md`: visão geral, camadas do backend (`controller/service/repository/entity/dto/exception`) e do Android (`ui -> viewmodel -> repository -> api/dao/datastore`), justificativa das tecnologias — **Resp.:** B (justificativa) e A (camadas) · **Evidência:** árvore de pacotes no repositório bate com o documento
- [ ] `docs/10-api-rest.md` v1: rotas de auth, usuário, quadra, horário, CEP, slots, reservas, `/dev` — **Resp.:** D · **Evidência:** Swagger espelha a tabela
- [ ] `docs/11-integracao-pix-inter.md` v1: fluxo, `PixGateway` e profiles, gates de 02/09 e 04/09 com resultado registrado, decisão sobre CNPJ — **Resp.:** D · **Evidência:** ata das decisões no documento
- [ ] `docs/14-backlog.md`: backlog priorizado com estimativa P/M/G e milestone; link do GitHub Projects — **Resp.:** D · **Evidência:** board aberto na apresentação
- [ ] `docs/15-divisao-equipe.md`, `docs/16-cronograma.md`, `docs/19-riscos.md`, `docs/21-git-e-organizacao.md` publicados — **Resp.:** A (editor) · **Evidência:** commits de cada integrante nos seus trechos
- [ ] `docs/12`, `docs/13`, `docs/22`, `docs/23` existem ao menos como esqueleto com "previsto para a N2" — **Resp.:** C e D · **Evidência:** arquivos no índice (recomendado)

## 17.2 Protótipo

- [ ] Figma navegável com as 13 telas + Splash (Login, Cadastro, Quadras, DetalheQuadra, ConfirmarReserva, Pagamento, MinhasReservas, DetalheReserva, Perfil, MinhasQuadras, FormQuadra, HorariosQuadra, ReservasQuadra) — **Resp.:** B · **Evidência:** percorrer fluxo CLIENTE e fluxo DONO clicando
- [ ] Estados carregando/vazio/erro desenhados para pelo menos Quadras e MinhasReservas (RNF06) — **Resp.:** B · **Evidência:** frames no Figma
- [ ] Export em PDF salvo em `docs/prototipo/` como backup offline — **Resp.:** B · **Evidência:** arquivo no repositório
- [ ] Protótipo coerente com as telas implementadas (mesmos nomes de tela e de campo) — **Resp.:** B (revisão de A) · **Evidência:** comparação lado a lado no ensaio

## 17.3 Backend

- [ ] Spring Boot 4.1.x sobe com `./gradlew bootRun` no profile `simulado`; `compose.yaml` com `postgres:18-alpine` — **Resp.:** A · **Evidência:** `GET /actuator/health` = UP
- [ ] Flyway `V1__init.sql` aplicado (`usuario`, `quadra`, `horario_funcionamento`, `reserva`, `pagamento`, índice `ux_reserva_slot_ativo`) e `scripts/seed-demo.sql` (`cliente@demo.com`, `dono@demo.com`, senha `Senha123`, 3 quadras georreferenciadas, horários seg–dom, 2 reservas) — **Resp.:** B (V1 consolidado, V2) e C (índice) · **Evidência:** `flyway_schema_history` com 2 linhas
- [ ] RF01/RF02: `POST /auth/registrar` (201 + token, 409 `EMAIL_JA_CADASTRADO`), `POST /auth/login` (200; 401 `CREDENCIAL_INVALIDA`); JWT HS256 via Nimbus com claim `perfil` (RNF01) — **Resp.:** A · **Evidência:** Swagger + token decodificado
- [ ] RF05: `GET /usuarios/me` e `PUT /usuarios/me` (edição de nome, telefone e senha), obrigatórios na N1 — **Resp.:** A · **Evidência:** Swagger + CT-07 de docs/23
- [ ] RF06: `POST /quadras`, `GET /quadras`, `GET /quadras/{id}`, `GET /quadras/minhas`, `PUT /quadras/{id}`, `DELETE /quadras/{id}` (soft) com regra de propriedade 403 (RN01, RN03) — **Resp.:** B · **Evidência:** Swagger; 403 com token CLIENTE em `POST /quadras`
- [ ] RF07/RF08: `GET /quadras?esporte=` e detalhe com horários de funcionamento — **Resp.:** B · **Evidência:** Swagger
- [ ] RF09: `GET /cep/{cep}` via `CepClient` (BrasilAPI v2 -> fallback ViaCEP), 404 e 503 `CEP_INDISPONIVEL` — **Resp.:** B · **Evidência:** `CepClientTest` (`MockRestServiceServer`) + chamada ao vivo
- [ ] RF10: `DELETE /quadras/{id}` responde 409 `QUADRA_COM_RESERVAS` com reserva ativa futura (RN16) — **Resp.:** B · **Evidência:** `QuadraServiceTest` + `DELETE` no Swagger devolvendo 409
- [ ] RF11: `POST`, `GET`, `PUT /{hid}`, `DELETE /{hid}` em `/quadras/{id}/horarios-funcionamento`, `UNIQUE (quadra_id, dia_semana)` -> 409 `DIA_JA_CADASTRADO` (RN19) — **Resp.:** B · **Evidência:** Swagger, 4 operações individuais
- [ ] RF12: `GET /quadras/{id}/slots?data=` com `StatusSlot {LIVRE, OCUPADO, PASSADO, FECHADO}` no fuso `America/Sao_Paulo` (RN06, RN09, RNF12) — **Resp.:** C · **Evidência:** `SlotServiceTest`
- [ ] RF13: `POST /reservas` cria PENDENTE_PAGAMENTO; segundo POST no mesmo slot -> 409 `HORARIO_INDISPONIVEL` (RN08); 422 `RESERVA_PENDENTE_EXISTENTE` (RN11) — **Resp.:** C · **Evidência:** Swagger ao vivo + `ReservaConcorrenciaIT` (10 threads: 1x201, 9x409) verde no CI
- [ ] RF14: `ExpiracaoReservaJob` (UPDATE condicional a cada 60 s) — **Resp.:** C · **Evidência:** `ReservaServiceTest` + log do job
- [ ] RF19/RF21: `PagamentoService` + `SimuladoPixGateway` + `PixPayloadBuilder` (CRC16) + `POST /dev/pagamentos/{txid}/confirmar` (JWT + `X-Dev-Key`) -> reserva CONFIRMADA (RN12) — **Resp.:** D · **Evidência:** Swagger; `PixPayloadBuilderTest` com payload conhecido
- [ ] `ReservaFacade`: cobrança fora da transação; falha -> CANCELADA por SISTEMA + 502 `PAGAMENTO_INDISPONIVEL` (RN17) — **Resp.:** C · **Evidência:** teste unitário com gateway lançando `IntegracaoExternaException`
- [ ] `GlobalExceptionHandler` -> `ProblemDetail` RFC 9457 com `codigo` e `campos[]` em 400 (RNF09) — **Resp.:** A · **Evidência:** enviar `QuadraRequest` inválido no Swagger
- [ ] Swagger (`/swagger-ui.html`, springdoc 3.1.0) com todas as rotas acima e autenticação Bearer configurada — **Resp.:** A · **Evidência:** abrir na apresentação
- [ ] Segredos fora do Git: `JWT_SECRET` (>= 32 bytes) e `DEV_KEY` por variável de ambiente; `.gitignore` com `*.crt *.key *.pfx .env` (RNF02, RNF01) — **Resp.:** A · **Evidência:** `git log --all -- '*.key' '*.crt' '.env'` vazio
- [ ] Testes rodando no CI: `JwtServiceTest`, `AuthServiceTest`, `QuadraServiceTest`, `HorarioFuncionamentoServiceTest`, `CepClientTest`, `SlotServiceTest`, `PixPayloadBuilderTest`, `ReservaConcorrenciaIT` (Testcontainers `postgres:18-alpine`) — **Resp.:** cada titular · **Evidência:** badge/aba Actions verde em `release/n1`

## 17.4 Android

- [ ] Projeto compila (`./gradlew assembleDebug`) no CI e nos 4 notebooks; versões fixadas em `gradle/libs.versions.toml` (AGP 9.4, Kotlin 2.4.10, Compose BOM 2026.08.00, Navigation 2.10.0, Room 3.0.2, DataStore 1.2.1, Retrofit 3.0.0, kotlinx.serialization 1.11.0); compileSdk/targetSdk 37, minSdk 26 (RNF08, RNF10) — **Resp.:** B (esqueleto) e A (CI) · **Evidência:** Actions verde
- [ ] `AppContainer` (DI manual), `SessaoDataStore`, `AuthInterceptor`, `Rotas.kt` com rotas `@Serializable`, `AppNavHost` com 2 grafos e bottom-nav por perfil — **Resp.:** A · **Evidência:** trocar de usuário CLIENTE para DONO muda a bottom-nav
- [ ] Tela Login (RF02): validação por campo, erro 401 `CREDENCIAL_INVALIDA` legível (o 429 do bloqueio de login é item da N2, ver docs/18-checklist-n2.md) — **Resp.:** A · **Evidência:** ao vivo
- [ ] Tela Cadastro (RF01): nome, e-mail, telefone, senha >= 8 com letra e número, confirmar, radio CLIENTE/DONO, auto-login — **Resp.:** A · **Evidência:** ao vivo
- [ ] Splash + sessão (RF03): token no DataStore, `token_expira_em`, Sair limpa DataStore e Room — **Resp.:** A · **Evidência:** fechar e reabrir o app mantém a sessão
- [ ] Tela Quadras (RF07): cards, chips de esporte, estados carregando/vazio/erro, pull-to-refresh — **Resp.:** B · **Evidência:** ao vivo
- [ ] Tela DetalheQuadra (RF08, versão estática): dados, endereço, horários de funcionamento; grade de slots aparece como "disponível na N2" — **Resp.:** B · **Evidência:** ao vivo
- [ ] Tela MinhasQuadras (RF06): lista com ativa/inativa, FAB nova, editar, desativar com diálogo e tratamento de 409 — **Resp.:** B · **Evidência:** ao vivo
- [ ] Tela FormQuadra (RF06, RF09): dropdown `TipoEsporte`, CEP + "Buscar" preenchendo logradouro/bairro/cidade/UF/lat/lon, lat/lon editáveis, validação por campo — **Resp.:** B · **Evidência:** ao vivo com CEP real
- [ ] Tela HorariosQuadra (RF11): 7 linhas com switch e `TimePicker`; ligar -> POST, alterar -> PUT, desligar -> DELETE — **Resp.:** B · **Evidência:** ao vivo, mostrando as 3 operações
- [ ] Tela Perfil (RF03/RF05): dados do usuário, edição de nome, telefone e senha, e Sair — **Resp.:** A · **Evidência:** ao vivo + CT-07 de docs/23
- [ ] Componentes `CampoTextoValidado`, `CarregandoBox`, `ErroBox(onTentarNovamente)`, `VazioBox` usados nas telas acima (RNF06) — **Resp.:** A e B · **Evidência:** desligar o backend e abrir Quadras mostra `ErroBox`
- [ ] 401 em rota protegida (`TOKEN_INVALIDO`) -> limpa sessão -> Login, sem loop (RNF03) — **Resp.:** A · **Evidência:** invalidar `JWT_SECRET` no backend e abrir o app
- [ ] Tela Pagamento v1 com QR (ZXing) e "Copiar código" existe no código, mas fica fora da demo da N1 — **Resp.:** D · **Evidência:** commit no `main` (opcional na N1)
- [ ] `FakeApiService` para telas sem endpoint e testes de ViewModel; `LoginViewModelTest`, `CadastroViewModelTest`, `QuadrasViewModelTest` — **Resp.:** A e B · **Evidência:** `./gradlew test` verde

## 17.5 Banco

- [ ] DER em docs/08 idêntico a `V1__init.sql` (nomes, tipos, NOT NULL, CHECKs) — **Resp.:** B (revisão de C) · **Evidência:** revisão cruzada registrada no PR
- [ ] Índice único parcial `ux_reserva_slot_ativo ON reserva (quadra_id, inicio) WHERE status IN ('PENDENTE_PAGAMENTO','CONFIRMADA')` presente — **Resp.:** C · **Evidência:** `\d reserva` no psql durante a demo
- [ ] `UNIQUE (quadra_id, dia_semana)`, `CHECK dia_semana BETWEEN 1 AND 7`, `CHECK hora_fechamento > hora_abertura` (RN19) — **Resp.:** B · **Evidência:** `\d horario_funcionamento`
- [ ] PKs `BIGINT GENERATED ALWAYS AS IDENTITY`; enums como VARCHAR com CHECK; `TIMESTAMPTZ`; `NUMERIC(10,2)` — **Resp.:** B · **Evidência:** DDL
- [ ] `pagamento` sem nenhuma coluna de dados do pagador (RN05, RNF02) — **Resp.:** D · **Evidência:** `\d pagamento`
- [ ] Migrations aditivas: `V1` nunca mais editado após a tag `v0.1-n1` — **Resp.:** B · **Evidência:** regra em docs/08 e docs/21

## 17.6 Git

- [ ] Commits dos 4 integrantes em `backend/`, `android/` e `docs/` (critério 7) — **Resp.:** A (verifica toda sexta) · **Evidência:** `git shortlog -sn -- backend`, `-- android`, `-- docs` mostrados na apresentação
- [ ] Mensagens descritivas no padrão `feat(reserva): cria indice unico parcial anti-dupla-reserva (#12)` — **Resp.:** todos · **Evidência:** `git log --oneline -30`
- [ ] Branches `feat/<area>-<descricao>`; PR < 400 linhas com aprovação do suplente; ninguém mergeia o próprio PR — **Resp.:** todos · **Evidência:** aba Pull Requests
- [ ] `main` protegida com CI obrigatório — **Resp.:** A · **Evidência:** configurações do repositório
- [ ] Issues com labels `must-n1/must-n2/should/could/fora-mvp` + `backend/android/docs`, milestone CP1/N1/CP2/N2, estimativa P/M/G; board do GitHub Projects atualizado — **Resp.:** D · **Evidência:** board aberto
- [ ] `CONTRIBUTING.md` com padrão de commit, fluxo de PR e avisos de toolchain (Jackson 3, KSP, plugin Compose na versão do Kotlin) — **Resp.:** A · **Evidência:** arquivo
- [ ] Branch `release/n1` criada ter 29/09; hotfixes só via PR para `release/n1` com cherry-pick em `main` — **Resp.:** A · **Evidência:** branch no GitHub
- [ ] Tag anotada `v0.1-n1` em `release/n1` (qui 01/10 após o ensaio, ou na véspera do dia marcado) — **Resp.:** A · **Evidência:** aba Releases com o vídeo de 2 min anexado

## 17.7 Apresentação

- [ ] Slides (máx. 6): problema/público, arquitetura, modelagem, escopo N1 x N2, divisão da equipe, próximos passos — **Resp.:** A (montagem), cada um o seu slide · **Evidência:** PDF em `docs/apresentacao/n1.pdf`
- [ ] Roteiro de 5 min (17.9) ensaiado 2 vezes na qui 01/10 com cronômetro — **Resp.:** D (condução do ensaio) · **Evidência:** tempos anotados na issue do ensaio
- [ ] Vídeo de backup de 2 min (app + Swagger + 409) gravado com o backend local — **Resp.:** D · **Evidência:** link no Release `v0.1-n1`
- [ ] Máquina de demo: Docker + backend em `release/n1` + seed carregado + Swagger aberto + emulador ou celular via USB (`adb`); Wi-Fi da faculdade não é pré-requisito (hotspot próprio) — **Resp.:** B (máquina) e A (backup) · **Evidência:** checklist marcado 30 min antes
- [ ] Terminal com `./gradlew test --tests '*ReservaConcorrenciaIT*'` já executado e saída visível (1x201, 9x409) — **Resp.:** C · **Evidência:** terminal aberto
- [ ] Cada integrante sabe defender sua fatia (A: JWT sem jjwt e navegação; B: enum x tabela, slots derivados, CEP -> lat/lon, CRUD x2; C: índice único + 409 + teste de 10 threads; D: `PixGateway`, por que existe o simulado, gates do Inter) — **Resp.:** cada um · **Evidência:** ensaio

## 17.8 Calendário da semana da N1

| Dia | O que acontece | Responsável |
|---|---|---|
| seg 28/09 | Bug bash: cada um testa a fatia do outro; últimos PRs `must-n1` mergeados até 20h | todos |
| ter 29/09 | **Congelamento**: `git checkout -b release/n1` a partir de `main` + push; a partir daqui só correções via PR para `release/n1`; D renova o certificado sandbox (issue datada) | A · D |
| qua 30/09 | **Teste do README em máquina limpa** (procedimento abaixo); correções no README no mesmo dia | C executa · A corrige |
| qui 01/10 | Vídeo de backup; 2 ensaios cronometrados; tag `v0.1-n1` + Release no GitHub com APK debug e vídeo | D · todos · A |
| sex 02/10 | Apresentação (se a data marcada for anterior, o calendário anda um dia para trás e a tag sai na véspera) | todos |

Procedimento do teste do README em máquina limpa (C, qua 30/09):

1. Usar um notebook sem o projeto (ou uma conta de usuário nova do sistema operacional, ou VM) com apenas JDK 21, Docker e Android Studio instalados.
2. Seguir o README literalmente, sem perguntar a A: `git clone`, `docker compose up -d`, `./gradlew bootRun`, abrir `http://localhost:8080/swagger-ui.html`, logar com `cliente@demo.com` / `Senha123`.
3. Abrir `android/` no Android Studio, rodar no emulador, fazer login.
4. Anotar cada passo que falhou ou exigiu conhecimento não escrito; abrir issue `docs` com a lista.
5. Aceite: um integrante que não escreveu o README chega ao login no app em até 30 min sem ajuda.

## 17.9 Roteiro da demo da N1 (5 minutos)

Preparação: backend `release/n1` rodando no profile `simulado` com seed; emulador (ou celular via `adb`) espelhado no projetor; Swagger autenticado com o token de `cliente@demo.com` em uma aba e de `dono@demo.com` em outra; terminal com o resultado do `ReservaConcorrenciaIT`.

| Tempo | Quem | O que mostrar | O que dizer |
|---|---|---|---|
| 0:00–0:30 | A | Slide 1 | Problema (achar quadra e reservar sem WhatsApp), público (jogadores e donos), o que é a N1: auth, 2 perfis, CRUD de Quadra e HorarioFuncionamento, CEP, backend de reserva pronto |
| 0:30–1:00 | B | Figma | Fluxo CLIENTE (Quadras -> Detalhe -> Confirmar -> Pagamento) e fluxo DONO em 4 cliques; "as telas de reserva e pagamento são a N2" |
| 1:00–1:30 | B | Slide de arquitetura | Android Compose -> API REST `/api/v1` -> PostgreSQL; camadas; enum x tabela; slots calculados de `horario_funcionamento` |
| 1:30–3:00 | B (dirige), A (narra) | App ao vivo | Login `dono@demo.com` -> MinhasQuadras -> FormQuadra: CEP + "Buscar" preenche endereço e lat/lon (BrasilAPI) -> salvar -> HorariosQuadra: ligar segunda (POST), mudar hora (PUT), desligar domingo (DELETE) -> Sair -> Cadastro de um CLIENTE novo (auto-login, bottom-nav muda) -> Quadras com filtro por esporte -> DetalheQuadra |
| 3:00–4:00 | C | Swagger + terminal | `POST /reservas` na quadra recém-criada -> 201 com `pagamento{txid, pixCopiaECola}`; repetir o mesmo slot -> 409 `HORARIO_INDISPONIVEL` (`ProblemDetail` com `codigo`); terminal: `ReservaConcorrenciaIT` 10 threads = 1x201 e 9x409; "a garantia é o índice único parcial no banco (RN08)" |
| 4:00–4:30 | D | Swagger | `POST /dev/pagamentos/{txid}/confirmar` -> `GET /reservas/{id}` CONFIRMADA; `PixGateway` com `SimuladoPixGateway` hoje e `InterPixGateway` sandbox na N2; resultado dos gates de 02/09 e 04/09 |
| 4:30–5:00 | A | GitHub | `git shortlog -sn -- backend android docs` (4 nomes nas 3 pastas), board com milestones, docs/00; próximos passos: slots e reserva no app (S6), sandbox Inter (S7–S8), geolocalização e Render (S9) |

Plano B durante a demo: a árvore de decisão e a resposta a falhas ao vivo são as de **docs/19-riscos.md, seção 19.7.3** (fonte única; não repetir a lista aqui). O que muda especificamente na N1 é que a demo é toda local — não há Render nem sandbox do Inter em jogo: emulador travou -> celular via `adb`; backend caiu -> `docker compose up` leva 20 s, enquanto isso B mostra o Figma; se nada subir -> vídeo de backup de 2 min anexado ao Release `v0.1-n1` (o vídeo de 8 min citado em docs/19 é o da N2).
