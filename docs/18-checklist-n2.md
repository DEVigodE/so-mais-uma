# 18. Checklist da Apresentação N2 (07 a 11/12/2026)

Lista verificável do que precisa estar pronto para a N2 ("app completo"), o roteiro de 8 minutos da demo, o checklist do dia, a divisão da fala entre A, B, C e D e as perguntas prováveis da banca com quem responde.

Escopo da N2 (ver docs/02-escopo-mvp.md e docs/05-requisitos-funcionais.md): todos os Must Have (N1 e N2) = RF01–RF23; Should Have = RF24, webhook do RF20, Pix em produção; Could Have só se entrou antes do congelamento de sex 27/11. Convenção: **Resp.** (titular; suplente revisa) e **Evidência** (mostrável em menos de 1 minuto).

## 18.1 Funcionalidades

- [ ] RF01–RF04 auth: cadastro com perfil e auto-login, login JWT, sessão persistente, logout limpa DataStore + Room, bloqueio 5 falhas/15 min — **Resp.:** A · **Evidência:** demo (cadastro DONO e CLIENTE) + `AuthServiceTest`
- [ ] RF05 perfil: `PUT /usuarios/me` (nome, telefone, senha) na tela Perfil — **Resp.:** A · **Evidência:** CT-07 executado em docs/23
- [ ] RF06, RF10 CRUD Quadra completo com soft delete e 409 `QUADRA_COM_RESERVAS` — **Resp.:** B · **Evidência:** demo (FormQuadra) + `QuadraServiceTest`
- [ ] RF07, RF08 lista com filtro por esporte e cidade, detalhe com distância e "Abrir no Maps" — **Resp.:** B e C · **Evidência:** demo
- [ ] RF09 CEP -> endereço + lat/lon (BrasilAPI v2, fallback ViaCEP) — **Resp.:** B · **Evidência:** demo com CEP real; `CepClientTest`
- [ ] RF11 CRUD HorarioFuncionamento com POST/PUT/DELETE individuais e 409 `HORARIO_COM_RESERVAS` — **Resp.:** B · **Evidência:** demo (HorariosQuadra)
- [ ] RF12 grade de slots por data (hoje até hoje+14) com LIVRE/OCUPADO/PASSADO/FECHADO — **Resp.:** C · **Evidência:** demo (DetalheQuadra)
- [ ] RF13 reserva PENDENTE_PAGAMENTO com 409 `HORARIO_INDISPONIVEL` (RN08) e 422 `RESERVA_PENDENTE_EXISTENTE` (RN11) — **Resp.:** C · **Evidência:** demo com 2 celulares + `ReservaConcorrenciaIT`
- [ ] RF14 expiração de pendente em 15 min (`ExpiracaoReservaJob`) — **Resp.:** C · **Evidência:** CT-22 (reserva criada com `expira_em` no passado via seed de teste) + log do job
- [ ] RF15, RF16, RF17 MinhasReservas (Próximas/Histórico), DetalheReserva, editar observação, cancelar conforme RN13 — **Resp.:** C · **Evidência:** demo + `ReservaServiceTest`
- [ ] RF18 ReservasQuadra do DONO por data com cancelamento com motivo — **Resp.:** C · **Evidência:** CT-27; opcional na demo (se sobrar tempo)
- [ ] RF19 cobrança Pix com QR + copia e cola (Inter sandbox/produção ou simulado) — **Resp.:** D · **Evidência:** demo (tela Pagamento)
- [ ] RF20 confirmação automática (polling do app + `ConsultaPagamentoJob`; webhook se [REC] entrou) -> CONFIRMADA — **Resp.:** D · **Evidência:** demo
- [ ] RF21 `POST /dev/pagamentos/{txid}/confirmar` nos profiles `simulado` e `inter-sandbox` (JWT + `X-Dev-Key`); inexistente em `inter-prod` — **Resp.:** D · **Evidência:** botão "Simular pagamento" em build debug; Swagger de prod sem a rota
- [ ] RF22 geolocalização: permissão no card, distância por card, ordenação, "Abrir no Maps", funciona sem permissão — **Resp.:** C · **Evidência:** demo
- [ ] RF23 cache Room (`quadra_cache`, `reserva_cache`) + `Sincronizador` + leitura offline com `BannerOffline` — **Resp.:** B e C · **Evidência:** demo em modo avião
- [ ] RF24 notificação local "Reserva confirmada" [REC] — **Resp.:** C · **Evidência:** demo (aparece na barra ao confirmar)
- [ ] 13 telas navegáveis + Splash; rotas tipadas em `Rotas.kt`; bottom-nav por perfil (critério 3) — **Resp.:** A · **Evidência:** docs/04 x app

## 18.2 Estabilidade

- [ ] Todas as telas com estados carregando/vazio/erro e "Tentar novamente" (RNF06) — **Resp.:** cada titular · **Evidência:** desligar o backend em cada tela durante o bug bash (registro em docs/23)
- [ ] Validação por campo em Cadastro, FormQuadra, HorariosQuadra, ConfirmarReserva, Perfil; backend com Bean Validation e `ProblemDetail` com `campos[]` — **Resp.:** A/B/C · **Evidência:** CT de validação em docs/23
- [ ] 401 `TOKEN_INVALIDO` -> Login uma única vez, sem loop, inclusive durante o polling de pagamento — **Resp.:** A · **Evidência:** CT-06
- [ ] 409 na ConfirmarReserva -> snackbar + recarrega slots; 502 -> "Não foi possível gerar a cobrança"; 422 -> mensagem da regra — **Resp.:** C · **Evidência:** demo (409) + CT-19, CT-23 e CT-20
- [ ] Back da tela Pagamento vai para MinhasReservas (nunca reenvia `POST /reservas`) — **Resp.:** D · **Evidência:** CT-25
- [ ] Polling com backoff (5 s por 2 min, depois 10 s) só com a tela visível (`repeatOnLifecycle`) — **Resp.:** D · **Evidência:** log do OkHttp em debug
- [ ] `ConsultaPagamentoJob` limita 50 por ciclo, pula o ciclo em 429 e loga `INFO` quando o sandbox está fora do horário — **Resp.:** D · **Evidência:** `PagamentoServiceTest` + log
- [ ] Fuso `America/Sao_Paulo` em slots e reservas (RNF12), `SlotServiceTest` com caso de offset — **Resp.:** C · **Evidência:** teste verde
- [ ] Sem crash em 30 min de bug bash cruzado após o congelamento (27/11) — **Resp.:** todos · **Evidência:** issue "bug bash final" fechada
- [ ] Render: cold start conhecido (~30–60 s); `/actuator/health` responde; Neon ativo — **Resp.:** A · **Evidência:** health verde no ensaio geral
- [ ] Kit de demo offline ensaiado (jar + `postgres:18-alpine` no notebook, profile `simulado`, hotspot, APK debug com IP do notebook) — **Resp.:** D · **Evidência:** ensaio registrado em S12 e S14
- [ ] CI verde em `main` e na tag `v1.0`; nenhum teste ignorado — **Resp.:** A · **Evidência:** aba Actions

## 18.3 Pagamento

- [ ] Profile oficial da apresentação fixado em 27/11 e registrado em docs/11 (`inter-prod` > `inter-sandbox` > `simulado`) — **Resp.:** D · **Evidência:** seção "profile da demo" em docs/11
- [ ] Certificado sandbox renovado em ter 24/11 (válido até 24/12); `.crt/.key` como Secret Files no Render e no notebook do kit offline — **Resp.:** D (suplente A) · **Evidência:** issue datada fechada + `curl` de token 200 no ensaio
- [ ] Escopos do token: `cob.write cob.read pix.read pix.write webhook.write webhook.read`; `InterTokenService` com cache de 55 min — **Resp.:** D · **Evidência:** `application-inter-sandbox.yml`
- [ ] Troca para `simulado` por variável `SPRING_PROFILES_ACTIVE` sem rebuild (Render e kit offline) — **Resp.:** D · **Evidência:** ensaio nos dois modos
- [ ] Payload do `SimuladoPixGateway` (`PixPayloadBuilder`) decodificável por um app de banco (CRC16 válido, txid `***`) — **Resp.:** D · **Evidência:** `PixPayloadBuilderTest` + leitura do QR pelo app do banco de um integrante no ensaio
- [ ] Idempotência: UPDATE condicional + `end_to_end_id` UNIQUE; valor divergente rejeitado; pagamento tardio -> PAGO + log `ESTORNO_MANUAL` (RN12, RN14) — **Resp.:** D · **Evidência:** `PagamentoServiceTest`
- [ ] Cobrança e reserva expiram juntas (900 s, RN10); cancelar PENDENTE tenta `PATCH /pix/v2/cob/{txid}` REMOVIDA (best effort) — **Resp.:** D e C · **Evidência:** teste + log
- [ ] Webhook [REC]: `POST /webhooks/inter/pix/{segredo}` aceita o array oficial, valida txid + PENDENTE + valor, responde 200; status no sandbox registrado (dispara ou não) — **Resp.:** D · **Evidência:** `InterWebhookControllerTest` + docs/11
- [ ] Nenhum dado do pagador armazenado; `client_secret`, `.crt/.key`, `JWT_SECRET`, `DEV_KEY` só em variáveis de ambiente (RN05, RNF02) — **Resp.:** D e A · **Evidência:** `\d pagamento` + `git log --all -- '*.key' '*.crt' '.env'` vazio
- [ ] RN18 explicada: todo Pix cai na única chave `INTER_CHAVE_PIX`; repasse ao dono fora do app; estorno manual (RN14) — **Resp.:** D · **Evidência:** slide de limitações

## 18.4 Recurso nativo

- [ ] `ACCESS_COARSE_LOCATION` + `ACCESS_FINE_LOCATION` no manifest; sem background location; permissão pedida no card "Ativar localização", não no launch — **Resp.:** C · **Evidência:** demo
- [ ] Cadeia `getCurrentLocation` -> `lastLocation` -> `ultima_lat/lon` do DataStore -> sem distância; funciona com precisão "aproximada" e sem Google Play Services (RNF08) — **Resp.:** C · **Evidência:** CT-29 (negar permissão; celular sem GMS ou `runCatching` simulado)
- [ ] Distância Haversine por card, ordenação por proximidade, quadras sem lat/lon ao fim — **Resp.:** C · **Evidência:** demo
- [ ] "Abrir no Maps" via Intent `geo:` — **Resp.:** C · **Evidência:** demo
- [ ] Notificação local (RF24, [REC]): canal `reservas`, `POST_NOTIFICATIONS` pedida na primeira abertura da tela Pagamento (API >= 33), `PendingIntent` para DetalheReserva; "não é FCM" dito na apresentação — **Resp.:** C · **Evidência:** demo
- [ ] Celulares de demo com GPS ligado e coordenadas testadas no local da apresentação; emulador com Extended Controls > Location como backup — **Resp.:** C · **Evidência:** checklist do dia

## 18.5 Testes

- [ ] Backend: `JwtServiceTest`, `AuthServiceTest`, `AuthControllerTest`, `QuadraServiceTest`, `HorarioFuncionamentoServiceTest`, `CepClientTest`, `SlotServiceTest`, `ReservaServiceTest`, `PixPayloadBuilderTest`, `PagamentoServiceTest`, `InterPixGatewayTest`, `InterWebhookControllerTest` [REC] — **Resp.:** cada titular · **Evidência:** relatório do Gradle no CI
- [ ] `ReservaConcorrenciaIT` (Testcontainers, 10 threads: 1x201, 9x409, `count(*)` ativo = 1) — **Resp.:** C · **Evidência:** rodado ao vivo na demo
- [ ] Android: `LoginViewModelTest`, `CadastroViewModelTest`, `QuadrasViewModelTest`, `QuadrasCacheViewModelTest`, `ConfirmarReservaViewModelTest`, `PagamentoViewModelTest`, `SincronizadorTest`; `QuadraDaoTest` [REC] — **Resp.:** cada titular · **Evidência:** `./gradlew test` no CI
- [ ] docs/23-plano-de-testes.md com CT-xx por RF (RF01–RF24), resultado (passou/falhou/data) e responsável — **Resp.:** D · **Evidência:** tabela preenchida
- [ ] docs/22-testes-com-usuarios.md: 5–8 usuários, 6 tarefas, taxa de sucesso por tarefa >= 80 %, SUS >= 68, top-5 problemas e o que foi corrigido em S12 — **Resp.:** C · **Evidência:** tabela + gráfico do SUS
- [ ] Checklist de acessibilidade por tela (RNF07): `contentDescription`, alvos >= 48 dp, fonte 200 %, TalkBack em Quadras, DetalheQuadra, Pagamento e FormQuadra — **Resp.:** C (com o revisor de cada tela) · **Evidência:** tabela em docs/22

## 18.6 Documentação

- [ ] docs/00 a docs/23 finais e consistentes (identificadores RF/RNF/RN canônicos, nomes de telas e rotas iguais ao código) — **Resp.:** A (editor) · **Evidência:** revisão cruzada em S14
- [ ] README final: instalação/execução em 3 modos (local `simulado`, `inter-sandbox` com `.crt/.key`, Render), usuários de demo, tabela de versões verificada em 01/09/2026, como instalar o APK via `adb` — **Resp.:** A · **Evidência:** teste em máquina limpa repetido em S14 (por B)
- [ ] Matriz de rastreabilidade critério (1–7) -> evidência -> documento -> quem defende — **Resp.:** A · **Evidência:** tabela no README ou docs/00
- [ ] Limitações conscientes documentadas: sem estorno automático, JWT sem revogação, fuso único, webhook sem mTLS de entrada, DONO não reserva, sem paginação — **Resp.:** A e D · **Evidência:** seção "Limitações" em docs/02 e docs/11
- [ ] Trabalhos futuros: split entre jogadores ("só mais uma rachando"), repasse ao dono, mapa, fotos, avaliações — **Resp.:** A · **Evidência:** docs/02
- [ ] Tag `v1.0` e Release no GitHub com APK release, vídeo de backup e PDF dos slides — **Resp.:** A · **Evidência:** aba Releases

## 18.7 APK

- [ ] APK release assinado (`app-release.apk`), `versionName 1.0`, `BuildConfig.API_BASE_URL` apontando para o Render — **Resp.:** A · **Evidência:** `aapt dump badging`
- [ ] APK debug apontando para o IP do notebook (kit offline), `network_security_config` cleartext só em debug — **Resp.:** A · **Evidência:** ensaio do kit offline
- [ ] Instalado via `adb install` em 2 celulares de demo (verificação de desenvolvedor do Google vigente no Brasil desde 30/09/2026 não afeta `adb`) — **Resp.:** A · **Evidência:** checklist do dia
- [ ] Conta de distribuição limitada do Google avaliada em S9 (resultado em docs/19, R7); se disponível, link para o avaliador instalar sem `adb` — **Resp.:** A · **Evidência:** docs/19
- [ ] Funciona em minSdk 26 e em Android 17 (API 37); testado sem localização e com fonte 200 % — **Resp.:** A e C · **Evidência:** CT em docs/23
- [ ] Ícone, nome "Só mais uma" e tema claro/escuro explícitos (dynamic color desligado) — **Resp.:** B · **Evidência:** demo

## 18.8 Apresentação

- [ ] Slides (máx. 10): problema e público, arquitetura, modelagem, fluxo de reserva e pagamento, concorrência, persistência local, recurso nativo, testes e SUS, Git, limitações e trabalhos futuros — **Resp.:** A (montagem) · **Evidência:** PDF em `docs/apresentacao/n2.pdf`
- [ ] Roteiro de 8 min (18.9) ensaiado 2 vezes (S14 e véspera) dentro de 8h–20h com Render e com kit offline; tempos anotados — **Resp.:** D · **Evidência:** issue do ensaio
- [ ] Vídeo de backup (8 min, mesma sequência) gravado em S14 no profile oficial — **Resp.:** D · **Evidência:** link no Release `v1.0`
- [ ] Divisão da fala (18.11) e perguntas prováveis (18.12) revisadas por todos — **Resp.:** todos · **Evidência:** ensaio
- [ ] Checklist do dia (18.10) impresso ou no celular de A — **Resp.:** A · **Evidência:** marcado no dia

## 18.9 Roteiro da demo (8 minutos)

Montagem: **celular 1** (CLIENTE novo, criado ao vivo) espelhado no projetor via `scrcpy`; **celular 2** (CLIENTE `cliente@demo.com`, já logado, na mesma quadra e data); **notebook** com Swagger, terminal e GitHub. Um DONO é cadastrado ao vivo; a quadra criada por ele é usada por todos os passos seguintes (horários seg–dom 08–22 para garantir slot livre no horário da apresentação). O `ReservaConcorrenciaIT` é disparado no terminal no minuto 0 e sua saída é mostrada no fim.

| Tempo | Quem | Passo | O que mostrar / dizer |
|---|---|---|---|
| 0:00–0:45 | A | Abertura | Problema, público, 1 slide de arquitetura (Compose -> REST `/api/v1` -> PostgreSQL; Inter e BrasilAPI só pelo backend). Dispara `./gradlew test --tests '*ReservaConcorrenciaIT*'` no terminal |
| 0:45–2:00 | B | Fluxo do DONO (celular 1) | Cadastro com radio "Quero anunciar minhas quadras" -> auto-login, bottom-nav do dono -> MinhasQuadras vazio (`VazioBox`) -> FormQuadra: CEP + "Buscar" preenche endereço e lat/lon -> salvar -> HorariosQuadra: ligar seg–dom 08–22 (POST), ajustar uma hora (PUT), desligar e religar um dia (DELETE/POST) -> Sair. Frase: "CRUD completo de duas entidades, com validação por campo e 409 se houver reservas" |
| 2:00–3:15 | C | Fluxo do CLIENTE (celular 1) | Cadastro CLIENTE -> Quadras -> card "Ativar localização" -> permissão -> lista reordena com "a 1,2 km" -> DetalheQuadra -> "Abrir no Maps" (volta) -> seletor de data -> grade de slots (LIVRE/OCUPADO/PASSADO/FECHADO). Frase: "slots são calculados do horário de funcionamento, não persistidos" |
| 3:15–4:15 | C | Corrida (celulares 1 e 2) | Os dois tocam o mesmo slot -> ConfirmarReserva nos dois -> "Confirmar" quase ao mesmo tempo: um vai para Pagamento (201); o outro recebe snackbar "Esse horário acabou de ser reservado" (409 `HORARIO_INDISPONIVEL`) e a grade recarrega com OCUPADO. Frase: "a garantia é o índice único parcial no PostgreSQL; a aplicação só traduz para 409 (RN08)" |
| 4:15–5:45 | D | Pagamento (celular 1 + notebook) | Tela Pagamento: QR, "Copiar código", contador de 15 min; log do backend com `PUT /pix/v2/cob/{txid}` 201 (sandbox/produção) ou `SimuladoPixGateway`. Pagar: em produção, app do banco com R$ 1,00; em sandbox, botão "Simular pagamento" (debug) -> `POST /dev/.../confirmar` -> `POST /pix/v2/cob/pagar/{txid}` -> job detecta CONCLUIDA; em simulado, o mesmo botão marca PAGO. Polling do app troca para "Pago" -> notificação local "Reserva confirmada" -> DetalheReserva CONFIRMADA. Frase: "mesma tela, mesmo DTO, três provedores atrás de `PixGateway`; confirmação idempotente" |
| 5:45–6:30 | C | Offline (celular 1) | Modo avião -> MinhasReservas abre na hora com `BannerOffline` "dados de hh:mm" -> DetalheReserva mostra o QR do cache -> Quadras com cache e distância da última posição; reservar desabilitado -> desligar modo avião -> re-sincroniza. Frase: "cache primeiro, servidor vence; toda escrita é online". Se sobrar tempo: celular 2 logado como `dono@demo.com` mostra ReservasQuadra com a reserva recebida |
| 6:30–7:30 | A | Notebook | Swagger: `POST /quadras` com token CLIENTE -> 403 `ProblemDetail` com `codigo`; terminal: saída do `ReservaConcorrenciaIT` (1x201, 9x409); `git shortlog -sn -- backend`, `-- android`, `-- docs` com os 4 nomes; board com milestones; docs/00 |
| 7:30–8:00 | A | Fechamento | Testes com usuários (SUS e taxa de sucesso), limitações conscientes (sem estorno automático, JWT sem revogação, fuso único, repasse fora do app), trabalhos futuros ("só mais uma rachando") |

Plano B por falha durante a demo: a lista completa de sintomas e respostas (Render, sandbox, pagamento que não confirma, corrida sem 409, lista sem distância, notificação, modo avião, Wi-Fi, APK, notebook travado, projetor incompatível, "tudo falhou") é a de **docs/19-riscos.md, seção 19.7.3**, que é a única fonte — não repetir aqui. Abaixo ficam só as duas respostas específicas deste roteiro de 8 minutos:

| Falha | Ação imediata | Quem |
|---|---|---|
| `scrcpy` falha e o celular 1 (usado do minuto 0:45 ao 6:30) não espelha | câmera do celular no projetor ou vídeo de backup do trecho | B |
| Celular 2 não conecta e a corrida de 3:15–4:15 fica sem par | 409 demonstrado pelo Swagger com o token de `cliente@demo.com` no mesmo slot | C |

## 18.10 Checklist do dia

| Quando | Item | Resp. |
|---|---|---|
| Véspera | Ensaio geral 2 completo (Render e kit offline); `ReservaConcorrenciaIT` roda em < 2 min no notebook; celulares carregados; vídeo de backup copiado para o notebook e para um pendrive | todos / D |
| Véspera | `adb install -r app-release.apk` nos 2 celulares; `adb install` do APK debug (kit offline), que convive com o release por usar `applicationIdSuffix ".debug"`; login prévio de `cliente@demo.com` no celular 2 | A |
| Véspera | Seed conferido no banco da demo (Render/Neon): `dono@demo.com`, `cliente@demo.com`, 3 quadras; reservas antigas expiradas/canceladas para não ocupar o slot da demo | B |
| T-60 min | Hotspot do próprio celular ligado e testado nos 2 celulares e no notebook (não depender do Wi-Fi da faculdade) | A |
| T-60 min | Se profile `inter-sandbox`: confirmar que a apresentação cai entre 8h e 20h de um dia útil e que o certificado (renovado 24/11) está válido: `curl` de token 200 | D |
| T-30 min | Kit offline de pé: `docker compose up -d` (postgres + api jar, profile `simulado`), `GET http://<ip-do-notebook>:8080/actuator/health` = UP a partir do celular | D |
| T-10 min | `GET https://<render>/actuator/health` = UP (aquecer o cold start); repetir a cada 3 min até começar | A |
| T-10 min | Swagger aberto e autenticado nas duas abas (CLIENTE e DONO); terminal pronto com o comando do IT; GitHub aberto no board e no `git shortlog` | A |
| T-10 min | `scrcpy` conectado ao celular 1; brilho no máximo; notificações de outros apps silenciadas; modo "não perturbe" com exceção do app | B |
| T-5 min | Celular 2 na tela DetalheQuadra da quadra da demo (ou pronto para navegar até ela); GPS ligado nos dois celulares | C |
| T-0 | Cronômetro; A abre | A |
| Após | Anotar perguntas da banca e falhas ocorridas em issue `apresentacao-n2` para a documentação final de lições aprendidas | D |

## 18.11 Divisão da fala

| Integrante | Blocos | Minutos | O que defende sozinho se perguntado |
|---|---|---|---|
| A | Abertura; Swagger/403; Git; fechamento | ~2:15 | JWT HS256 com Nimbus (sem jjwt), sessão stateless, bloqueio de login, navegação tipada e sessão no DataStore, CI e organização do monorepo, deploy no Render |
| B | Fluxo do DONO; arquitetura e modelagem nos slides | ~1:45 | enum x tabela para esporte, slots derivados de `horario_funcionamento`, CEP -> lat/lon, CRUD x2, DER, justificativa das tecnologias |
| C | Fluxo do CLIENTE, corrida, offline, geolocalização | ~2:30 | índice único parcial + 409 + teste de 10 threads, expiração por UPDATE condicional, "servidor vence", Room e sincronização, geolocalização, resultados do SUS |
| D | Pagamento | ~1:30 | OAuth2 + mTLS, cobrança imediata, idempotência, por que existe o simulado e como o BR Code é montado, gates do Inter, plano de testes |

Regra: quem responde é o titular da fatia; se ele travar, o suplente assume (A <-> D, B <-> C).

## 18.12 Perguntas prováveis da banca e quem responde

| Pergunta | Resposta curta | Quem |
|---|---|---|
| Como vocês garantem que dois clientes não reservam o mesmo horário? | Índice único parcial `ux_reserva_slot_ativo` em `(quadra_id, inicio)` para status ativos; `saveAndFlush` + `DataIntegrityViolationException` -> 409; sem lock pessimista porque não há linha para travar antes do INSERT; provado por `ReservaConcorrenciaIT` | C |
| Por que a cobrança Pix fica fora da transação da reserva? | Para não segurar o lock do índice durante uma chamada HTTP ao Inter; se a cobrança falha, `ReservaFacade` cancela por SISTEMA e devolve 502, liberando o slot (RN17) | C / D |
| O pagamento é real? | Sim no sandbox do Inter (API externa real, mTLS + OAuth2, `PUT /pix/v2/cob/{txid}`); produção depende de conta PJ e foi decidida no go/no-go de 16/10; o `SimuladoPixGateway` existe para dev, CI e como seguro da demo | D |
| O que acontece se o pagamento chegar depois da reserva expirar ou ser cancelada? | Pagamento vira PAGO, reserva EXPIRADA tenta reconfirmar se o slot ainda estiver livre; caso contrário log `ESTORNO_MANUAL`; estorno é manual e fora do app (RN14) | D |
| Por que polling e não webhook? | Polling funciona em localhost e no sandbox (que pode não disparar callback); webhook é recomendado e foi implementado/registrado se o Render estava em HTTPS até 30/10; mesmo com webhook o job continua | D |
| Onde ficam os dados do pagador? | Não são armazenados: só txid, valor, status, `pixCopiaECola`, `location`, `endToEndId` (RN05, RNF02) | D |
| Como funciona a autenticação e por que não usaram jjwt? | JWT HS256 via `NimbusJwtEncoder/Decoder` do `spring-security-oauth2-jose`, compatível com Jackson 3 do Boot 4; BCrypt custo 10; bloqueio 5 falhas/15 min; limitação: sem revogação (JWT de 7 dias) | A |
| Quais são os dois perfis e como a autorização é feita? | `CLIENTE` e `DONO`; `@PreAuthorize(hasRole)` nas rotas + checagem de propriedade no service (403); DONO não reserva (RN02) | A |
| Quais são as duas entidades com CRUD completo? | Quadra (`POST/GET/PUT/DELETE /quadras`) e HorarioFuncionamento (`POST/GET/PUT/DELETE` por item); telas MinhasQuadras, FormQuadra e HorariosQuadra | B |
| Por que `TipoEsporte` é enum e não tabela? | Lista fixa de 7 valores; tabela exigiria FK, DTO, repositório e tela sem valor acadêmico; Bean Validation valida de graça | B |
| Como os slots são gerados? | Calculados em memória pelo `SlotService` a partir de `horario_funcionamento` (1 linha por dia da semana) menos reservas ativas menos passado, em slots de 60 min no fuso `America/Sao_Paulo` | B / C |
| Como funciona a persistência local e a sincronização? | DataStore para sessão e preferências; Room com `quadra_cache` e `reserva_cache` (PK `id + escopo`); leitura cache-primeiro, resposta do servidor substitui o escopo; escritas sempre online; sem fila offline porque reserva exclusiva não pode ser adiada | C |
| Qual é o recurso nativo? | Geolocalização (FusedLocationProvider, permissão em runtime, distância Haversine, ordenação, Intent `geo:`); segundo: notificação local ao confirmar pagamento (não é FCM) | C |
| E se o usuário negar a localização ou o celular não tiver Google Play Services? | Cadeia `getCurrentLocation` -> `lastLocation` -> última posição no DataStore -> lista sem distância; app 100 % usável (RNF08) | C |
| Por que DI manual e não Hilt? | Zero plugin Gradle/KSP extra, sem o bug Hilt 2.59 x AGP 9, explicável em um slide; construtores já recebem dependências, então migrar é local | A / B |
| Como testaram usabilidade e acessibilidade? | 5–8 usuários em 09–13/11, 6 tarefas, SUS >= 68 e >= 80 % de sucesso; top-5 corrigido em S12; `contentDescription`, alvos 48 dp, fonte 200 %, TalkBack | C |
| Como provam que os 4 trabalharam em todas as camadas? | `git shortlog -sn -- backend android docs`; fatias verticais; PR revisado pelo suplente com commit do revisor; board com issues por pessoa | A |
| O que ficou fora e por quê? | Estorno automático, cartão, split, repasse ao dono, mapa interativo, fotos, push FCM, ADMIN, recuperação de senha, Play Store — cada um com motivo em docs/02; fuso único e JWT sem revogação são limitações documentadas | A |
| Como instalar o app sem `adb`? | Verificação de desenvolvedor do Google vigente no Brasil desde 30/09/2026 pode exigir fluxo avançado no sideload; usamos `adb` e avaliamos a conta de distribuição limitada (docs/19, R7) | A |
| O que fariam a seguir? | "Só mais uma rachando" (split entre jogadores), repasse ao dono, webhook com mTLS de entrada, refresh token, mapa | A / D |
