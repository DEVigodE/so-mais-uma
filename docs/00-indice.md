# Índice da documentação — Só mais uma

Sumário de todos os documentos de planejamento do app de reserva de quadras "Só mais uma", matriz de rastreabilidade dos 7 critérios da disciplina, decisões-chave, complexidade evitada, glossário canônico e regras de manutenção dos arquivos.

## 1. Sumário

| Arquivo | Conteúdo em uma linha | Dono |
|---|---|---|
| [README.md](../README.md) | Instalação, execução do backend e do app, testes, profiles Spring, equipe | A |
| [01-visao-do-produto.md](01-visao-do-produto.md) | Problema, domínio, público-alvo e proposta de valor (critério 1) | A |
| [02-escopo-mvp.md](02-escopo-mvp.md) | Classificação Must Have (N1/N2), Should, Could e Fora do MVP com motivo | A |
| [03-perfis-e-permissoes.md](03-perfis-e-permissoes.md) | Perfis CLIENTE e DONO, matriz de permissões, autorização por role e propriedade | A |
| [04-telas.md](04-telas.md) | As 13 telas, grafo de navegação (`AppNavHost`), componentes e protótipo Figma (CP1): <link> · backup `docs/prototipo/figma-cp1.pdf` | B |
| [05-requisitos-funcionais.md](05-requisitos-funcionais.md) | RF01..RF24 com prioridade e módulo | A |
| [06-requisitos-nao-funcionais.md](06-requisitos-nao-funcionais.md) | RNF01..RNF12 (segurança, desempenho, usabilidade, acessibilidade, compatibilidade) | A |
| [07-regras-de-negocio.md](07-regras-de-negocio.md) | RN01..RN20, máquinas de estado e anti-dupla-reserva | C |
| [08-modelagem-banco.md](08-modelagem-banco.md) | DER, dicionário das 5 tabelas, `V1__init.sql`, índice único parcial | B |
| [09-arquitetura.md](09-arquitetura.md) | Visão geral, camadas do backend e do Android, justificativa das tecnologias, hospedagem | B |
| [10-api-rest.md](10-api-rest.md) | Contrato `/api/v1`, códigos de erro `ProblemDetail`, convenções | D |
| [11-integracao-pix-inter.md](11-integracao-pix-inter.md) | OAuth2 + mTLS, cobrança imediata, sandbox, polling/webhook, `SimuladoPixGateway`, gates datados | D |
| [12-persistencia-local.md](12-persistencia-local.md) | DataStore, Room (`quadra_cache`, `reserva_cache`), `Sincronizador`, comportamento offline | C |
| [13-recurso-nativo.md](13-recurso-nativo.md) | Geolocalização (principal) e notificação local (recomendada); permissões | C |
| [14-backlog.md](14-backlog.md) | Backlog priorizado, labels, estimativa P/M/G, board GitHub Projects | D |
| [15-divisao-equipe.md](15-divisao-equipe.md) | Fatias verticais A/B/C/D, suplentes, o que cada um defende na banca | coletivo (A edita) |
| [16-cronograma.md](16-cronograma.md) | S1..S15 (01/09 a 11/12), feriados, gates do Inter, entregas | coletivo (A edita) |
| [17-checklist-n1.md](17-checklist-n1.md) | O que precisa estar pronto e como provar na Entrega N1 (28/09 a 02/10) | coletivo (A edita) |
| [18-checklist-n2.md](18-checklist-n2.md) | Checklist da N2 e roteiro da demo de 8 minutos | D |
| [19-riscos.md](19-riscos.md) | R1..R26 com probabilidade, impacto e mitigação | coletivo (A edita) |
| [20-ordem-de-implementacao.md](20-ordem-de-implementacao.md) | Sequência de fatias finas ponta a ponta e por que a ordem "natural" foi alterada | coletivo (A edita) |
| [21-git-e-organizacao.md](21-git-e-organizacao.md) | Monorepo, branches, commits, PR cruzado, `git shortlog`, CI | A |
| [22-testes-com-usuarios.md](22-testes-com-usuarios.md) | Roteiro de 6 tarefas, SUS, termo, formulário, aceite, checklist de acessibilidade | C |
| [23-plano-de-testes.md](23-plano-de-testes.md) | Pirâmide, CT-01..CT-31 rastreados a RF/RN, comandos, CI, critérios de saída | D |

Ordem de leitura sugerida para a banca: README -> 01 -> 02 -> 05 -> 07 -> 08 -> 09 -> 11 -> 23. Para o grupo no dia a dia: 14 -> 16 -> 20 -> 21.

## 2. Matriz de rastreabilidade (critério da disciplina -> evidência)

| Critério | Evidência concreta (mostrável em < 1 min) | Arquivo(s) | Onde mostrar na apresentação | Quem defende |
|---|---|---|---|---|
| 1. Engenharia: problema, domínio, público-alvo, RF, RNF, RN | Seção de problema/domínio/público; RF01..RF24; RNF01..RNF12; RN01..RN20 com prioridade | 01, 02, 05, 06, 07 | Slide 2 (problema e público) e slide 3 (tabela resumida de RF/RN com prioridade) | A (RF/RNF), C (RN) |
| 2. Modelagem/arquitetura: arquitetura, justificativa das tecnologias, banco, entidades/relacionamentos, camadas | Diagrama de arquitetura; tabela de justificativas; `erDiagram` das 5 tabelas + `V1__init.sql`; árvore `controller/service/repository/entity/dto/exception` e `ui/data/model` | 08, 09 | Slide de arquitetura; abrir `backend/src/main/java/br/com/somaisuma` e `db/migration/V1__init.sql` no IDE | B (modelagem, tecnologias), A (camadas) |
| 3. Mobile: >= 6 telas, navegação estruturada, autenticação, >= 2 perfis, CRUD completo de >= 2 entidades | 13 telas (11 funcionais, 7 na N1; Perfil e ReservasQuadra complementares); `Rotas.kt` tipadas + `AppNavHost` com 2 grafos; JWT HS256 + `SessaoDataStore`; `PerfilUsuario{CLIENTE, DONO}` com bottom-nav por perfil; CRUD de Quadra (MinhasQuadras + FormQuadra) e de HorarioFuncionamento (HorariosQuadra) com POST/GET/PUT/DELETE individuais | 03, 04, 10 | Demo ao vivo: cadastro DONO -> quadra via CEP -> horários; login CLIENTE mostra outra bottom-nav; Swagger devolve 403 em `POST /quadras` com token CLIENTE | B (CRUD x2), A (auth, navegação, perfis) |
| 4. Persistência: local (DataStore + Room), remota (PostgreSQL), sincronização, >= 1 API externa | `SessaoDataStore`; `AppDatabase` com `quadra_cache` e `reserva_cache`; PostgreSQL 18 + Flyway; `Sincronizador.kt` ("cache primeiro, servidor vence") + `ultima_sincronizacao`; Banco Inter API Pix (sandbox) e BrasilAPI CEP v2 (fallback ViaCEP) | 08, 11, 12 | Modo avião ao vivo com `BannerOffline` e QR reaberto do cache; cobrança criada no sandbox; CEP preenchendo lat/lon | C (local e sync), B (PostgreSQL, CEP), D (Inter) |
| 5. Recurso nativo (>= 1) | Geolocalização: permissão em runtime, "a 2,3 km" em cada card, ordenação por distância, "Abrir no Maps"; notificação local "Reserva confirmada" (recomendada) | 13 | Pedir permissão ao vivo, lista reordena; notificação aparece após o pagamento | C |
| 6. Qualidade: validações, tratamento de erros, camadas, boas práticas, usabilidade, acessibilidade básica | Bean Validation nos records + validação por campo no Compose; `GlobalExceptionHandler` -> `ProblemDetail` RFC 9457 com `codigo`; estados carregando/vazio/erro em toda tela; checklist de acessibilidade; SUS >= 68 e >= 80 % de sucesso por tarefa; `ReservaConcorrenciaIT` (10 threads) | 06, 22, 23 | 2 celulares no mesmo slot (409 amigável); `./gradlew test --tests '*ReservaConcorrenciaIT'` no terminal; slide com SUS e top-5 corrigido | C (concorrência, usabilidade), D (SUS, plano de testes), todos |
| 7. Git: commits dos 4, commits descritivos, divisão clara, README com instalação/execução, backlog priorizado | Monorepo `backend/ android/ docs/`; `git shortlog -sn -- backend android docs`; commits `feat(reserva): ...`; PR cruzado com commit do revisor; README executável; GitHub Projects com labels `must-n1/must-n2/should/could/fora-mvp` | README, 14, 15, 21 | Rodar `git shortlog -sn --no-merges -- backend android docs` no terminal; abrir o board | A (repositório), D (board) |

## 3. Decisões-chave

| Decisão | Alternativas consideradas | Escolha | Motivo |
|---|---|---|---|
| Padrão de nomes | tudo em inglês; misto; português sem acento | português sem acento em código, colunas, rotas e telas; enums em MAIÚSCULAS; sufixos de padrão em inglês (`Repository`, `Gateway`, `Screen`, `ViewModel`) | domínio brasileiro, banca lê em português; um só padrão entre 4 pessoas |
| Perfis | CLIENTE+ADMIN; CLIENTE+DONO; três perfis; papéis dinâmicos | exatamente 2: `PerfilUsuario {CLIENTE, DONO}`, escolhido no cadastro | cumpre ">= 2 perfis" com autorização simples (role + propriedade); ADMIN global adiciona telas sem critério |
| TipoEsporte | tabela com CRUD; enum | enum `TipoEsporte` (7 valores) em VARCHAR | lista fixa; elimina 1 tabela, 1 FK, 1 tela e 4 endpoints |
| Disponibilidade | slots persistidos; intervalos livres; funcionamento semanal + slots calculados | `horario_funcionamento` (1 linha por dia, `dia_semana` 1..7 = `DayOfWeek`) + `SlotService` gerando slots de 60 min | sem job nem milhares de linhas; `(quadra_id, inicio)` identifica o slot; é o 2º CRUD completo |
| Anti-dupla-reserva | checagem no service; lock pessimista; `@Version`; `EXCLUDE gist`; índice único parcial | índice único parcial `ux_reserva_slot_ativo` + `saveAndFlush` + `DataIntegrityViolationException` -> 409; transições por UPDATE condicional | a garantia mora no banco; não há linha para travar antes do INSERT; provável com 10 threads |
| Cobrança Pix e transação | dentro (rollback automático); fora | fora: `ReservaFacade` commita a reserva e cria a cobrança depois; falha -> CANCELADA por SISTEMA + 502 | nenhuma chamada HTTP segurando o lock do índice; nenhum slot fica preso |
| Confirmação de pagamento | só webhook; só polling; ambos | polling obrigatório (app 5 s com backoff para 10 s + `ConsultaPagamentoJob` 60 s, <= 10 por ciclo); webhook recomendado se HTTPS até 30/10 | sandbox pode não disparar callback; polling funciona em localhost |
| Fallback de pagamento | só Inter produção; outro PSP; Inter + simulado | `PixGateway` com `InterPixGateway` (`inter-sandbox`/`inter-prod`) e `SimuladoPixGateway` (`simulado`, padrão) + `PixPayloadBuilder` próprio + `/dev/pagamentos/{txid}/confirmar` polimórfico | conta PJ e certificado estão fora do controle do grupo; mesma tela e mesmo banco em todos os cenários |
| Escopos OAuth Inter | `cob.write cob.read pix.read`; completo | `cob.write cob.read pix.read pix.write webhook.write webhook.read` | `pix.write` é exigido por `POST /pix/v2/cob/pagar/{txid}` no sandbox; `webhook.write` pelo cadastro do webhook |
| Ordem com o Inter | Inter primeiro; produção direto | simulado (S3) -> sandbox (S7-S8) -> produção só com conta PJ ativa até 16/10 | sandbox é self-service e conta como API externa real; produção é recomendada, nunca obrigatória |
| Injeção de dependência no Android | Hilt 2.60.1; Koin; manual | `AppContainer` + `ViewModelFactory` manuais | zero plugin Gradle; sem o bug Hilt 2.59 x AGP 9; explicável em 1 slide; migrável |
| Camadas do Android | Clean Architecture com use cases; MVVM + Repository | MVVM + Repository em módulo único | atende "camadas" sem dobrar o número de arquivos |
| Persistência local | só DataStore; Room com fila offline + WorkManager; cache de leitura | DataStore (sessão) + Room com 2 tabelas (PK composta `id, escopo`); leitura cache-primeiro, escrita sempre online; `fallbackToDestructiveMigration` | sem edição local não há conflito; reserva e pagamento exigem consistência forte |
| Recurso nativo | geolocalização; notificação; câmera; biometria | geolocalização (obrigatória) + notificação local (recomendada); biometria opcional; câmera fora | melhor relação facilidade x utilidade x demo; usa as coordenadas do CEP |
| Segunda API externa | nenhuma; Google Geocoding; Nominatim; ViaCEP; BrasilAPI | BrasilAPI CEP v2 com fallback ViaCEP via `GET /api/v1/cep/{cep}` no backend, obrigatória desde a N1 | sem token nem billing; devolve lat/lon; garante o critério 4 mesmo se o sandbox exigir CNPJ |
| Autenticação | sessão por cookie; jjwt; Nimbus (`oauth2-jose`); OAuth social | JWT HS256 com `NimbusJwtEncoder/Decoder`, 7 dias, BCrypt 10, senha >= 8 com letra e número, bloqueio 5 falhas/15 min, sem refresh/revogação | compatível com Jackson 3 e Boot 4; sem dependência extra; limitação documentada em RNF03 |
| Fuso horário | coluna por quadra; UTC puro; fuso único | constante `America/Sao_Paulo` no backend; app envia `OffsetDateTime` | elimina o slot deslocado em 3 h sem coluna nem lógica extra (RNF12) |
| Chaves primárias | UUID; BIGINT identity | `BIGINT GENERATED ALWAYS AS IDENTITY`; UUID sem hifens só no `txid` | ids curtos em URL e demo; txid precisa de 26-35 caracteres alfanuméricos |
| Exclusão | DELETE físico; híbrido; soft único | soft delete único (`quadra.ativa`, `usuario.ativo`, `reserva.status`) + 409 se houver reservas ativas futuras | preserva histórico e pagamentos; um caminho só |
| Hospedagem do beta | só localhost; VM + Compose + Caddy; Render + Neon | Render + Neon (deploy em S9) + kit de demo offline como plano B único | HTTPS grátis sem administrar servidor; cold start mitigado por aquecimento |
| Distribuição do APK | Play Store; link/navegador; adb | `adb install` do APK release assinado (testado em S9) + avaliar conta de distribuição limitada da Google | verificação de desenvolvedor no Brasil desde 30/09/2026 pode travar sideload por navegador |
| Organização do backend | package-by-feature; por camada | pacotes por camada (`controller/service/repository/entity/dto/exception/config/security/integracao`) | mapeia literalmente o critério 2; conflitos evitados por arquivos por domínio |
| Versões | Boot 3.5; Boot 4.1 + JDK 21; Room 2.8 vs 3.0 | Spring Boot 4.1.x + JDK 21 LTS + PostgreSQL 18; Kotlin 2.4.10 + AGP 9.4 + SDK 37/minSdk 26 + Compose BOM 2026.08.00 + Room 3.0.2 + Navigation 2.10 + Retrofit 3 | linhas estáveis verificadas em 01/09/2026; um JDK para tudo; KSP em tudo |

## 4. Complexidade evitada (o que NÃO fizemos e por quê)

| Não fizemos | Fizemos no lugar | Por quê |
|---|---|---|
| Microsserviços, API gateway, filas (Kafka/RabbitMQ), Kubernetes, CQRS | monólito Spring em 1 jar + 1 PostgreSQL | 4 pessoas, 15 semanas, nenhum critério pede |
| Lock pessimista (`SELECT FOR UPDATE`), `@Version`, `EXCLUDE USING gist`, lock distribuído | índice único parcial com slots fixos de 60 min | o índice já serializa; lock seria redundante |
| Tabela de slots pré-gerados + job de geração | slots calculados em memória pelo `SlotService` | sem dessincronização nem explosão de linhas |
| Entidade TipoEsporte, tabela Endereco, tabela de log de webhook | enum, colunas embutidas na quadra, log de aplicação | sem valor acadêmico adicional |
| Chamada HTTP ao Inter dentro da transação | cobrança criada fora da transação via `ReservaFacade` | não segurar lock durante rede |
| Webhook como caminho principal (mTLS de entrada, allowlist de IPs, retentativas de 2 h) | polling obrigatório; webhook bônus | sandbox pode não disparar; exige HTTPS público |
| SDK Java oficial do Inter (jar manual) e conversão para PFX | `RestClient` + SSL bundle PEM lendo `.crt/.key` | menos passos, explicável |
| Biblioteca GPL de BR Code, `zxing-android-embedded`, ML Kit | `PixPayloadBuilder` próprio (~60 linhas) e ZXing core só para gerar | sem risco de licença nem câmera |
| Hilt/Dagger/Koin | `AppContainer` manual | build nunca quebra por DI |
| Clean Architecture com use cases e módulos Gradle por camada | MVVM + Repository em módulo único | camadas suficientes |
| WorkManager periódico, fila offline (outbox), resolução de conflitos | sync on-resume + escritas online | reserva exclusiva não pode ser adiada |
| Migrations do Room com `exportSchema` | cache-only com `fallbackToDestructiveMigration` | cache é recriado no próximo sync |
| Refresh token, revogação de JWT, OAuth social, recuperação de senha por e-mail | JWT de 7 dias + reset manual no beta | limitação documentada em RNF03 |
| Perfil ADMIN, aprovação de quadras, troca de perfil | DONO administra as próprias quadras | terceiro perfil não pontua |
| Coluna de fuso por quadra | fuso único `America/Sao_Paulo` | RNF12 |
| DELETE físico ou híbrido | soft delete único + 409 | histórico preservado |
| Google Maps SDK, Nominatim, Google Geocoding | Haversine + Intent `geo:` + BrasilAPI CEP | sem API key nem billing |
| Upload de fotos, câmera, storage | `foto_url` texto opcional | storage de arquivo arrasta permissão e backend |
| Push FCM | notificação local disparada pelo app | sem Firebase |
| Estorno automático, cobv, Pix Automático, `x-conta-corrente`, split, repasse ao dono | fora do domínio do MVP (RN14, RN18) | dobram a superfície de erro |
| Paginação, cache HTTP, Redis, GraphQL | listas pequenas | documentado |
| VM + Docker Compose + Caddy + DuckDNS | Render + Neon | horas de operação economizadas |
| Publicação na Play Store | APK via adb | verificação de desenvolvedor e targetSdk |
| Dois repositórios | monorepo com um `git shortlog` | critério 7 em um comando |
| Maven no backend | Gradle Kotlin DSL nos dois projetos | uma ferramenta de build |
| jjwt + Jackson 2 | Nimbus (`oauth2-jose`) + `tools.jackson` | compatível com Boot 4 |
| KAPT | KSP em tudo (Room); plugin Compose na versão do Kotlin | AGP 9 não inclui KAPT |
| Testes E2E de UI automatizados em CI com emulador | testes de ViewModel com fakes + CT-xx manuais + SUS | custo alto e quebra por toolchain |
| Quartz ou fila com delay para expiração | `@Scheduled` com UPDATE em lote | 1 método |
| Dia da semana 0..6 com mapeamento manual | `DayOfWeek.getValue()` 1..7 direto | sem tabela de conversão |

## 5. Glossário canônico

| Termo | Definição |
|---|---|
| Perfis | `PerfilUsuario {CLIENTE, DONO}` — CLIENTE reserva e paga; DONO cadastra quadras e horários e acompanha reservas das suas quadras. Um usuário tem um perfil fixo (RN20). Autoridades Spring: `ROLE_CLIENTE`, `ROLE_DONO` |
| Esportes | `TipoEsporte {FUTEBOL_SOCIETY, FUTSAL, VOLEI, BASQUETE, TENIS, BEACH_TENNIS, PADEL}` |
| Status da reserva | `StatusReserva {PENDENTE_PAGAMENTO, CONFIRMADA, CANCELADA, EXPIRADA}` |
| Status do pagamento | `StatusPagamento {PENDENTE, PAGO, EXPIRADO, CANCELADO}` |
| Provedor | `ProvedorPagamento {INTER, SIMULADO}` |
| Slot | intervalo de 60 min começando em hora cheia (`America/Sao_Paulo`); `StatusSlot {LIVRE, OCUPADO, PASSADO, FECHADO}`, calculado pelo `SlotService`, nunca persistido |
| Cancelado por | `CanceladoPor {CLIENTE, DONO, SISTEMA}` |
| Tabelas | `usuario`, `quadra`, `horario_funcionamento`, `reserva`, `pagamento` (PK `BIGINT IDENTITY`; índice único parcial `ux_reserva_slot_ativo`) |
| Telas (13) | Login, Cadastro, Quadras, DetalheQuadra, ConfirmarReserva, Pagamento, MinhasReservas, DetalheReserva, Perfil, MinhasQuadras, FormQuadra, HorariosQuadra, ReservasQuadra (+ Splash de apoio) |
| Profiles Spring | `simulado` (padrão em dev, teste e CI), `inter-sandbox` (API Pix do Inter em `cdpj-sandbox.partners.uatinter.co`, 8h-20h seg-sex), `inter-prod` (conta PJ, recomendado) |
| Gateway de pagamento | interface `PixGateway`; implementações `SimuladoPixGateway` (com `PixPayloadBuilder`) e `InterPixGateway` (com `InterTokenService`, mTLS via SSL bundle PEM) |
| Jobs | `ExpiracaoReservaJob` (60 s, UPDATE em lote) e `ConsultaPagamentoJob` (60 s, <= 10 pendentes, só em `inter-*`) |
| Fachada | `ReservaFacade` — cria a reserva em transação própria e a cobrança fora dela |
| CEP | `CepClient` — BrasilAPI CEP v2 com fallback ViaCEP, exposto em `GET /api/v1/cep/{cep}` |
| Android | `AppContainer` (DI manual), `SessaoDataStore`, `AppDatabase` (`quadra_cache`, `reserva_cache`), `Sincronizador`, `LocalizacaoProvider`, `NotificadorReserva`, `QrCodeGerador`, `Rotas.kt`, `AppNavHost`, `FakeApiService` |
| Erros | `ProblemDetail` (RFC 9457) com campo `codigo` (ex.: `HORARIO_INDISPONIVEL`, `RESERVA_PENDENTE_EXISTENTE`, `PAGAMENTO_INDISPONIVEL`) — lista completa em docs/10-api-rest.md |
| txid | identificador da cobrança Pix: UUID sem hifens (32 caracteres), gerado pelo backend |
| Integrantes | A (auth, usuário, segurança, repositório, infra de entrega; suplente de D) · B (quadra, horários, CEP, modelagem; suplente de C) · C (reserva, slots, concorrência, sync local, geolocalização, usabilidade; suplente de B) · D (pagamento Pix, webhook, burocracia Inter, backlog, plano de testes; suplente de A) |
| Marcos | CP1 11/09 · N1 28/09-02/10 · CP2 06/11 · testes com usuários 09-13/11 · congelamento 27/11 · documentação final 04/12 · N2 07-11/12 |

## 6. Convenção de prioridade

| Etiqueta nos docs | Label no GitHub | Significado |
|---|---|---|
| Must Have (N1) / obrigatório | `must-n1` | precisa estar funcionando e documentado na Entrega N1 |
| Must Have (N2) / obrigatório | `must-n2` | precisa estar funcionando na Apresentação N2; sem isso um critério fica sem evidência |
| Should Have / recomendado | `should` | entra só com todos os obrigatórios verdes (regra de ouro: nenhum recomendado começa com bug aberto em obrigatório) |
| Could Have / opcional | `could` | entre 06/11 e 25/11, se sobrar tempo; nunca depois do congelamento |
| Fora do MVP | `fora-mvp` | registrado com motivo em docs/02-escopo-mvp.md; vira "trabalhos futuros" |

Nos requisitos, a citação usa o formato `RF01`, `RNF01`, `RN01` (sem hífen); a definição completa segue o padrão "RF01 — O sistema deve permitir ...".

## 7. Como manter os documentos

1. Cada arquivo tem um dono (tabela da seção 1); só o dono ou o suplente da fatia altera o conteúdo; qualquer integrante pode abrir issue `docs` apontando divergência.
2. Documentos coletivos (00, 15, 16, 17, 19, 20) recebem contribuições de todos por PR; Integrante A é o editor final e resolve conflitos.
3. Toda mudança de decisão (tabela da seção 3) exige: atualizar este índice, o arquivo específico e a issue correspondente no board; registrar a data e o motivo em uma linha.
4. Identificadores (RF, RNF, RN, enums, tabelas, telas, rotas) nunca são renumerados após o Checkpoint 1; itens removidos ficam marcados como "retirado em dd/mm" em vez de apagados.
5. Os docs acompanham o código: um PR que altera contrato da API, migration ou tela atualiza o doc correspondente no mesmo PR (revisor confere).
6. Marcos de revisão geral: 29/09 (congelamento `release/n1`), 04/11 (`release/beta`), 27/11 (congelamento de escopo) e 04/12 (documentação final, com a matriz da seção 2 revisada e a tabela de versões do README reconfirmada).
