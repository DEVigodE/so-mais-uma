# 14 — Backlog priorizado

Backlog do MVP "Só mais uma" organizado em 10 épicos e 70 itens de backlog (US-01 a US-60, com US-37 e US-47 desdobradas em a e b e US-05, US-22, US-30 e US-35 desdobradas em a, b e c), com prioridade MoSCoW, responsável, semana de entrega, estimativa P/M/G e rastreabilidade para os RF/RNF/RN, mais o modo de uso no GitHub Projects e o que é apresentado no Checkpoint 1.

## 14.1 Como ler este backlog

| Campo | Convenção |
|---|---|
| **ID** | `US-nn`, único e permanente; é o número usado no título da issue e nas mensagens de commit (`feat(reserva): ... (#US-25)`). |
| **User Story** | "Como [tipo de usuário], quero [funcionalidade] para [benefício]". Histórias técnicas usam "Como equipe". |
| **Prioridade** | **Must Have (N1)** = obrigatório na Entrega N1 (label `must-n1`) · **Must Have (N2)** = obrigatório na Apresentação N2 (`must-n2`) · **Should Have** = recomendado, entra só com todos os Must verdes (`should`) · **Could Have** = opcional, entre 06/11 e 25/11 (`could`) · **Won't** = fora do MVP (`fora-mvp`, lista na seção 14.13). Equivalência com docs/02-escopo-mvp.md: OBR-N1, OBR-N2, REC, OPC, FORA. |
| **Responsável** | A, B, C ou D (ver docs/15-divisao-equipe.md). "Todos" = cada integrante executa na própria fatia. O suplente (A<->D, B<->C) revisa o PR. |
| **Entrega prevista** | Marco + semana: **CP1** sex 11/09 · **N1** 28/09 a 02/10 · **CP2** sex 06/11 · **N2** 07 a 11/12. Semanas: S1 01–04/09, S2 07–11/09, S3 14–18/09, S4 21–25/09, S5 28/09–02/10, S6 05–09/10, S7 12–16/10, S8 19–23/10, S9 26–30/10, S10 02–06/11, S11 09–13/11, S12 16–20/11, S13 23–27/11, S14 30/11–04/12, S15 07–11/12 (detalhe em docs/16-cronograma.md). |
| **Estimativa** | **P** <= 3 h · **M** <= 8 h · **G** <= 16 h. Nenhuma história G permanece no board: toda G é quebrada em issues P/M antes de entrar na semana. |
| **RF relacionado** | Identificadores canônicos de docs/05-requisitos-funcionais.md, docs/06-requisitos-nao-funcionais.md e docs/07-regras-de-negocio.md. |

A ordem das histórias **dentro de cada épico é a ordem de implementação** (fatias finas ponta a ponta: endpoint -> tela -> cache -> teste, conforme docs/20-ordem-de-implementacao.md).

## 14.2 Resumo por marco

| Marco | Histórias | Horas (teto; "Todos" = 4x a estimativa) | O que fica demonstrável |
|---|---|---|---|
| CP1 (11/09) | US-01 a US-04, US-05a a US-05c, US-06, US-34, US-52 | ~65 h | dois projetos buildando, `V1__init.sql`, auth no Swagger, protótipo Figma navegável, board priorizado, gates Inter registrados |
| N1 (02/10) | US-07 a US-11, US-13 a US-21, US-24 a US-27, US-35a a US-35c, US-36, US-37a, US-47a, US-53, US-54 | ~213 h | 7 telas funcionais, CRUD x2, CEP, backend de reserva/pagamento simulado via Swagger, `ReservaConcorrenciaIT` verde, docs 01–13 v1, README |
| CP2 (06/11) | US-12, US-22a a US-22c, US-28, US-29, US-30a a US-30c, US-31 a US-33, US-37b, US-38 a US-40, US-43 a US-45, US-47b, US-48, US-51, US-57 a US-59 | ~203 h | beta funcional: reservar -> pagar (sandbox ou simulado) -> confirmação, offline, geolocalização, backend no Render, APK via adb |
| N2 (11/12) | US-23, US-41, US-42, US-46, US-49, US-50, US-55, US-56, US-60 + Could Have | ~110 h (sem os Could Have) | testes com usuários, correções, documentação final, apresentação, kit de demo |

As horas acima já contam, conforme a convenção de "Responsável" da seção 14.1, as histórias com responsável "Todos" **quatro vezes** a estimativa (US-47a, US-47b, US-48, US-50 e US-55 custam 32 h cada) e US-53, com três donos, três vezes (24 h). A soma das histórias é **591 h**.

**O cálculo consolidado de esforço (histórias + revisões de PR + rituais, por integrante e por fase) existe em um lugar só: docs/15-divisao-equipe.md §15.4.** Este backlog não repete o total consolidado; a coluna acima é apenas a soma por marco.

### Ajuste de escopo necessário

O esforço planejado não cabe no semestre, e isso precisa ser resolvido antes de qualquer promessa de entrega.

| Item | Horas |
|---|---|
| Histórias deste backlog (com "Todos" contando 4x) | 591 h |
| Revisões de PR (~1 h/semana x 4 pessoas x 15 semanas) | 60 h |
| Rituais semanais (planejamento + demo interna, mesma conta) | 60 h |
| **Esforço planejado** | **711 h** |
| Capacidade (4 x 10 h/semana x 15 semanas menos 4 feriados) | 560 h |
| **Déficit** | **151 h (27 % do orçamento)** |

Spikes, o bug bash de S13 e o ensaio da véspera ainda não estão quantificados e entram por cima desse total. O déficit também não está distribuído: a Fase 1 (S1–S5) tem 326 h planejadas contra ~190 h disponíveis (docs/15-divisao-equipe.md §15.4).

**A decisão de corte é do grupo, não deste documento.** Ela é tomada no Checkpoint 1 (sex 11/09) e registrada na ata do dia. Opções em ordem de preferência:

| Ordem | Corte | Economia |
|---|---|---|
| 1 | Adiar US-33 (listagem e cancelamento de reservas pelo dono) para Could Have | 8 h |
| 2 | Reduzir a quantidade de classes de teste por integrante em US-47a e US-47b (de M para P por integrante em cada história) | 40 h |
| 3 | Mover US-41 e US-42 (webhook e registro do webhook) para trabalhos futuros: o polling de US-38 é o caminho obrigatório e já confirma o pagamento sem o webhook | 16 h |
| 4 | Cortar os Should Have restantes (US-23 foto da quadra, US-46 notificação local) | 6 h |
| | **Soma das quatro opções** | **70 h** |

As quatro opções somam 70 h e **não** fecham o déficit de 151 h: as ~81 h restantes precisam sair de renegociação de itens Must Have na mesma reunião. Enquanto o grupo não decidir, este backlog está sobre-comprometido e o planejamento de horas não fecha.

## 14.3 Épico 1 — Fundação e organização

| ID | User Story | Prioridade | Resp. | Entrega | Est. | RF relacionado |
|---|---|---|---|---|---|---|
| US-01 | Como equipe, quero o monorepo `so-mais-uma/` (`backend/`, `android/`, `docs/`, `scripts/`) com `.gitignore` (`*.crt *.key *.pfx .env`), branch `main` protegida, GitHub Projects configurado e CI GitHub Actions (build + testes do backend, `assembleDebug` do Android) para que os 4 commitem desde o primeiro dia com segurança. | Must Have (N1) | A | CP1 · S1 | M | RNF10, RNF02 |
| US-02 | Como equipe, quero o esqueleto do backend (Spring Boot 4.1.x, JDK 21, Gradle Kotlin DSL, `compose.yaml` com `postgres:18-alpine`, Flyway, springdoc 3.1.0, profile padrão `simulado`) buildando nos 4 notebooks para que ninguém brigue sozinho com Boot 4/Jackson 3. | Must Have (N1) | A | CP1 · S1 | M | RNF10 |
| US-03 | Como equipe, quero o esqueleto do app Android (AGP 9.4, Kotlin 2.4.10, Compose BOM 2026.08.00, compileSdk/targetSdk 37, minSdk 26, `gradle/libs.versions.toml`, tema Material 3 com `lightColorScheme`/`darkColorScheme` explícitos, KSP apenas para Room) para que todas as telas nasçam no mesmo padrão. | Must Have (N1) | B | CP1 · S1 | M | RNF08, RNF10 |
| US-04 | Como equipe, quero `V1__init.sql` com as tabelas `usuario`, `quadra`, `horario_funcionamento`, `reserva`, `pagamento` e o índice único parcial `ux_reserva_slot_ativo` para que o DDL seja o contrato entre as 4 fatias antes de qualquer tela (V1 nunca é editado após a N1). | Must Have (N1) | C (revisão B) | CP1 · S2 | M | RN08, RN19, RNF10 |
| US-05a | Como equipe, quero criar a conta e a integração no sandbox do Inter para ter credencial do banco na semana 1. | Must Have (N1) | D (suplente A) | CP1 · S1 | P | RF19, RNF05 |
| US-05b | Como equipe, quero validar o mTLS por linha de comando para provar que a credencial funciona antes de escrever código de pagamento. | Must Have (N1) | D (suplente A) | CP1 · S1 | P | RF19, RNF02 |
| US-05c | Como equipe, quero registrar os gates do Inter em ata e agendar as renovações do certificado para que o maior risco externo tenha decisão e calendário. | Must Have (N1) | D (suplente A) | CP1 · S1 + recorrente | P | RF19, RNF05 |

Critérios de aceite das histórias desdobradas:

- **US-05a**: conta em developers.inter.co/sandbox criada; integração sandbox criada; `.crt` e `.key` baixados e guardados no gerenciador de senhas do grupo (nunca no Git).
- **US-05b**: `curl` mTLS com token 200 e `PUT /pix/v2/cob/{txid}` 201 até 04/09.
- **US-05c**: gates de 02/09 (PF conseguiu?) e 04/09 (há CNPJ não-MEI?) registrados em ata com a decisão de fallback; renovações do certificado (30 dias) agendadas em 29/09, 27/10 e 24/11.

## 14.4 Épico 2 — Autenticação e perfis

| ID | User Story | Prioridade | Resp. | Entrega | Est. | RF relacionado |
|---|---|---|---|---|---|---|
| US-06 | Como visitante, quero me cadastrar com nome, e-mail, telefone, senha e perfil (CLIENTE ou DONO) e fazer login por e-mail/senha recebendo um JWT (`POST /auth/registrar`, `POST /auth/login`, HS256 via Nimbus, BCrypt custo 10, `JWT_SECRET` >= 32 bytes, e-mail único -> 409 `EMAIL_JA_CADASTRADO`) para acessar o sistema conforme meu papel. | Must Have (N1) | A | CP1 · S2 | M | RF01, RF02, RNF01, RN20 |
| US-07 | Como visitante, quero as telas Login e Cadastro (radio "Quero reservar quadras"/"Quero anunciar minhas quadras", validação por campo, senha >= 8 com letra e número, erros 401/409/429 legíveis, auto-login após cadastro) para entrar no app sem ajuda. | Must Have (N1) | A | N1 · S3 | M | RF01, RF02, RNF06 |
| US-08 | Como usuário, quero que minha sessão fique salva (`SessaoDataStore`: `token_jwt`, `token_expira_em`, `usuario_id/nome/perfil`), que o Splash me leve direto à home do meu perfil e que "Sair" limpe DataStore e Room, com `AuthInterceptor` enviando o Bearer e tratando 401 `TOKEN_INVALIDO` uma única vez (sem loop) para não digitar senha a cada abertura. | Must Have (N1) | A | N1 · S3 | M | RF03, RNF03 |
| US-09 | Como equipe, quero `Rotas.kt` com rotas `@Serializable`, `AppNavHost` com os grafos CLIENTE e DONO, `BottomNavCliente`/`BottomNavDono` e os componentes base (`CampoTextoValidado`, `CarregandoBox`, `ErroBox`, `VazioBox`, `ChipStatus`) para que as 13 telas sejam plugadas sem retrabalho de navegação. | Must Have (N1) | A | N1 · S3 | M | RF03, RNF06 |
| US-10 | Como equipe, quero o `GlobalExceptionHandler` devolvendo `ProblemDetail` RFC 9457 com `codigo` e `campos[]` (enum `CodigoErro`) e o `ProblemDetailParser` + `Resultado<T>` (Ok/Erro(codigo)/Offline) no app para que toda tela trate 400/401/403/404/409/422/502 e offline do mesmo jeito. | Must Have (N1) | A | N1 · S4 | M | RNF09, RNF06 |
| US-11 | Como usuário, quero ver e editar meu perfil (nome, telefone, senha atual + nova) em `GET/PUT /usuarios/me` e na tela Perfil, com "última sincronização" e versão do app, para manter meus dados corretos. | Must Have (N1) | A | N1 · S4 | M | RF05, RN20 |
| US-12 | Como sistema, quero bloquear o login por 15 min após 5 falhas seguidas (`LoginTentativasService` em memória, 429 `LOGIN_BLOQUEADO`) para dificultar força bruta. | Must Have (N2) | A | CP2 · S6 | P | RF04, RNF01 |

## 14.5 Épico 3 — Quadras e horários (dono)

| ID | User Story | Prioridade | Resp. | Entrega | Est. | RF relacionado |
|---|---|---|---|---|---|---|
| US-13 | Como dono, quero cadastrar quadras (`POST /quadras` nasce com `dono_id` do logado) e listar (`GET /quadras?esporte=&cidade=`, `GET /quadras/{id}` com horários, `GET /quadras/minhas` incluindo inativas), com `scripts/seed-demo.sql` (`cliente@demo.com`, `dono@demo.com`, 3 quadras georreferenciadas, horários seg–dom 08–22h, 2 reservas) para que o catálogo exista desde a N1. | Must Have (N1) | B | N1 · S3 | M | RF06, RF07, RF08, RN01 |
| US-14 | Como dono, quero editar (`PUT /quadras/{id}`) e desativar (`DELETE /quadras/{id}` soft, `ativa=false`) apenas as minhas quadras (403 `ACESSO_NEGADO` para outro dono; 409 `QUADRA_COM_RESERVAS` se houver reserva ativa futura) para completar o CRUD nº 1 com as regras de propriedade. | Must Have (N1) | B | N1 · S3 | M | RF06, RF10, RN03, RN16 |
| US-15 | Como dono, quero o CRUD completo de HorarioFuncionamento (`POST/GET/PUT/DELETE /quadras/{id}/horarios-funcionamento[/{hid}]`, `dia_semana` 1..7, UNIQUE por dia -> 409 `DIA_JA_CADASTRADO`, `hora_fechamento > hora_abertura`) para definir quando cada quadra abre; a validação 409 `HORARIO_COM_RESERVAS` ao reduzir horário com reserva ativa entra na S8. | Must Have (N1) | B | N1 · S3 (409 em S8) | M | RF11, RN19, RN16 |
| US-16 | Como dono, quero informar o CEP e receber logradouro, bairro, cidade, UF e latitude/longitude (`GET /cep/{cep}` -> `CepClient` BrasilAPI CEP v2 com fallback ViaCEP, 503 `CEP_INDISPONIVEL`) para não digitar endereço e para a quadra ter coordenadas. | Must Have (N1) | B | N1 · S3 | P | RF09 |
| US-17 | Como dono, quero a tela MinhasQuadras (cards com nome, esporte, preço, ativa/inativa, FAB nova, ações Editar/Horários/Reservas, diálogo de desativação tratando 409) para gerenciar minhas quadras. | Must Have (N1) | B | N1 · S4 | M | RF06, RF10 |
| US-18 | Como dono, quero a tela FormQuadra (nome, esporte em dropdown do enum `TipoEsporte`, descrição, preço/h, CEP + botão "Buscar", número, lat/lon editáveis, `foto_url`, validação por campo) para criar e editar quadras. | Must Have (N1) | B | N1 · S4 | M | RF06, RF09, RNF06 |
| US-19 | Como dono, quero a tela HorariosQuadra com 7 linhas (seg..dom), switch aberto/fechado e `TimePicker` de abertura/fechamento, em que cada linha dispara `POST`, `PUT` ou `DELETE` individual, para configurar o funcionamento em uma tela só. | Must Have (N1) | B | N1 · S4 | M | RF11, RN19 |

## 14.6 Épico 4 — Busca e geolocalização

| ID | User Story | Prioridade | Resp. | Entrega | Est. | RF relacionado |
|---|---|---|---|---|---|---|
| US-20 | Como cliente, quero a tela Quadras com cards (nome, esporte, bairro/cidade, preço/h), chips de filtro por esporte e campo de filtro por cidade, pull-to-refresh e estados carregando/vazio/erro para encontrar uma quadra. | Must Have (N1) | B | N1 · S4 | M | RF07, RNF06 |
| US-21 | Como cliente, quero a tela DetalheQuadra (dados, endereço, horários de funcionamento por dia) para decidir se a quadra me serve; a grade de slots (US-28) e a distância (US-22b) são acopladas depois. | Must Have (N1) | B | N1 · S4 | M | RF08 |
| US-22a | Como cliente, quero conceder a permissão de localização a partir de um card "Ativar localização" para decidir quando o app pode me localizar. | Must Have (N2) | C | CP2 · S9 | P | RF22, RNF08 |
| US-22b | Como cliente, quero ver a distância até cada quadra para saber quais estão perto de mim. | Must Have (N2) | C | CP2 · S9 | M | RF22, RF08 |
| US-22c | Como cliente, quero ordenar as quadras por proximidade e abrir a escolhida no app de mapas para chegar até ela. | Must Have (N2) | C | CP2 · S9 | P | RF22, RF08 |
| US-23 | Como cliente, quero ver a foto da quadra (`foto_url` com Coil 3.6.1) para reconhecer o lugar. | Should Have | B | N2 · S9 | P | RF08 |

Critérios de aceite das histórias desdobradas:

- **US-22a**: `ACCESS_COARSE` + `ACCESS_FINE` pedidas juntas, nunca no launch; recusa e ausência de GMS degradam a tela sem quebrá-la.
- **US-22b**: `LocalizacaoProvider` com a cadeia `getCurrentLocation` -> `lastLocation` -> `ultima_lat/lon` do DataStore -> sem distância; `Geo.kt` com Haversine; card mostra "a 2,3 km".
- **US-22c**: ordenação por proximidade na tela Quadras; `Intent geo:` abre o app de mapas; sem distância disponível, a ordenação fica indisponível e a lista segue no padrão.

## 14.7 Épico 5 — Reservas e concorrência

| ID | User Story | Prioridade | Resp. | Entrega | Est. | RF relacionado |
|---|---|---|---|---|---|---|
| US-24 | Como cliente, quero a grade de slots de 60 min por data (`SlotService`, `GET /quadras/{id}/slots?data=`, status LIVRE/OCUPADO/PASSADO/FECHADO, hoje até hoje+14 -> 422 `DATA_FORA_DA_JANELA`, fuso único America/Sao_Paulo com `SlotServiceTest` cobrindo offset) para saber quando a quadra está livre. | Must Have (N1) | C | N1 · S3 | M | RF12, RN06, RN07, RN09, RNF12 |
| US-25 | Como cliente, quero criar a reserva PENDENTE_PAGAMENTO (`POST /reservas`, hora cheia -> 400, janela e funcionamento -> 422, `saveAndFlush` + `DataIntegrityViolationException` -> 409 `HORARIO_INDISPONIVEL`, uma pendente por cliente -> 422 `RESERVA_PENDENTE_EXISTENTE`) para garantir que ninguém reserva o mesmo horário. | Must Have (N1) | C | N1 · S3 | M | RF13, RN08, RN10, RN11 |
| US-26 | Como sistema, quero expirar reservas pendentes em 15 min (`ExpiracaoReservaJob`, UPDATE condicional por status a cada 60 s) e criar a cobrança fora da transação (`ReservaFacade`: falha do gateway -> CANCELADA por SISTEMA + 502 `PAGAMENTO_INDISPONIVEL`) para que nenhum slot fique preso. | Must Have (N1) | C | N1 · S4 | M | RF14, RN10, RN17 |
| US-27 | Como equipe, quero `ReservaConcorrenciaIT` (Testcontainers `postgres:18-alpine`, 10 threads com `CountDownLatch` no mesmo slot -> exatamente 1x201 e 9x409, `count(*)` ativo = 1) rodando no CI para provar a exclusividade antes da N1. | Must Have (N1) | C | N1 · S4 | M | RF13, RN08 |
| US-28 | Como cliente, quero o seletor de data (hoje+14) e a grade de slots dentro do DetalheQuadra, com slot LIVRE levando a ConfirmarReserva e mensagem "Conecte-se para ver horários" offline, para escolher o horário. | Must Have (N2) | B (fatia de C) | CP2 · S6 | M | RF12 |
| US-29 | Como cliente, quero a tela ConfirmarReserva (quadra, data/hora, valor, observação, aviso "15 min para pagar"; 409 -> snackbar e recarrega slots; 422 `RESERVA_PENDENTE_EXISTENTE` -> leva à reserva pendente; 502 -> "pagamento indisponível") para revisar antes de pagar. | Must Have (N2) | C | CP2 · S6 | M | RF13, RN11, RN17 |
| US-30a | Como cliente, quero listar minhas reservas separadas em próximas e histórico para acompanhar meus jogos. | Must Have (N2) | C | CP2 · S6 | P | RF15 |
| US-30b | Como cliente, quero detalhar uma reserva e editar a observação para corrigir o combinado sem abrir outra reserva. | Must Have (N2) | C | CP2 · S6 | P | RF15, RF16 |
| US-30c | Como cliente, quero cancelar uma reserva dentro do prazo para liberar o horário quando não puder jogar. | Must Have (N2) | C | CP2 · S6 | P | RF17, RN04, RN13, RN15 |
| US-31 | Como cliente, quero a tela MinhasReservas (abas Próximas/Histórico, `ChipStatus`, botão "Pagar" se pendente, pull-to-refresh) para acompanhar meus jogos. | Must Have (N2) | A (fatia de C) | CP2 · S6 | M | RF15 |
| US-32 | Como cliente, quero a tela DetalheReserva (dados, status, observação editável, pagamento com txid/status, regra de cancelamento, diálogo de cancelar, "Pagar agora" se pendente) para agir sobre uma reserva. | Must Have (N2) | C | CP2 · S6 | M | RF15, RF16, RF17 |
| US-33 | Como dono, quero ver as reservas das minhas quadras por data (`GET /quadras/{id}/reservas?data=`, nome e telefone do cliente, status, valor) na tela ReservasQuadra e cancelar até o início com motivo obrigatório (sem estorno automático) para administrar minha agenda. | Must Have (N2) | D (fatia de C) | CP2 · S8 | M | RF18, RF17, RN03, RN13, RN14 |

Critérios de aceite das histórias desdobradas:

- **US-30a**: `GET /reservas?situacao=PROXIMAS|HISTORICO`.
- **US-30b**: `GET /reservas/{id}`; `PATCH /reservas/{id}` altera apenas a observação.
- **US-30c**: `POST /reservas/{id}/cancelar`: PENDENTE a qualquer momento, CONFIRMADA até 2 h antes, senão 422 `CANCELAMENTO_FORA_DO_PRAZO`; transições por UPDATE condicional, 0 linhas -> 422 `TRANSICAO_INVALIDA`; reserva nunca é apagada.

US-33 saiu de C para D em S8: o caminho crítico do projeto passava quase todo por C (slots, reserva, concorrência, cache, geolocalização, testes com usuários) e D tem S8 com apenas o sandbox; a troca reduz a dependência de uma pessoa só sem mexer no suplente de C (B), que já é o mais carregado da Fase 1.

## 14.8 Épico 6 — Pagamento Pix

| ID | User Story | Prioridade | Resp. | Entrega | Est. | RF relacionado |
|---|---|---|---|---|---|---|
| US-34 | Como equipe, quero a interface `PixGateway` (`criarCobranca`, `consultar`, `removerCobranca`), o `SimuladoPixGateway` (`@Profile("simulado")`) e o `PixPayloadBuilder` (BR Code estático TLV + CRC16-CCITT, txid `***`, chave em `SIMULADO_PIX_CHAVE`) com `PixPayloadBuilderTest` contra payload conhecido para destravar a tela de Pagamento sem certificado nem horário de sandbox. | Must Have (N1) | D | CP1 · S2 | M | RF19, RF21 |
| US-35a | Como sistema, quero criar a cobrança do pagamento junto com a reserva para que o cliente receba um código Pix válido e com prazo. | Must Have (N1) | D | N1 · S3 | P | RF19, RN05, RNF02 |
| US-35b | Como sistema, quero confirmar o pagamento de forma idempotente para que nenhum pagamento confirme duas vezes. | Must Have (N1) | D | N1 · S3 | P | RF20, RN12 |
| US-35c | Como sistema, quero tratar o pagamento que chega atrasado ou de reserva cancelada para que nenhum valor recebido fique sem registro. | Must Have (N1) | D | N1 · S3 | P | RF20, RN12, RN14 |
| US-36 | Como desenvolvedor, quero `POST /dev/pagamentos/{txid}/confirmar` (JWT + header `X-Dev-Key`, existente só nos profiles `simulado` e `inter-sandbox`) para simular o pagamento em demo e testes. | Must Have (N1) | D | N1 · S3 | P | RF21 |
| US-37a | Como cliente, quero `GET /reservas/{id}/pagamento` (txid, status, valor, `pixCopiaECola` e expiração; `atualizar=true` força a consulta ao gateway) para acompanhar a cobrança pelo Swagger já na N1. | Must Have (N1) | D | N1 · S4 | P | RF19 |
| US-37b | Como cliente, quero a tela Pagamento v1 (QR gerado do `pixCopiaECola` com ZXing core 3.5.4 via `QrCodeGerador`/`PixQrCode`, "Copiar código", valor, contador regressivo, status Aguardando/Pago/Expirado, botão "Simular pagamento" só em `BuildConfig.DEBUG`) para pagar no app do meu banco. | Must Have (N2) | D | CP2 · S4–S6 | M | RF19, RNF06 |
| US-38 | Como cliente, quero que a confirmação chegue sozinha (polling do app a cada 5 s por 2 min e depois 10 s enquanto a tela está visível; `ConsultaPagamentoJob` a cada 60 s com no máximo 10 pendentes por ciclo, 429 pula o ciclo, sandbox fora do horário só loga) e ao PAGO ir para DetalheReserva, para não ficar apertando "já paguei". | Must Have (N2) | D | CP2 · S6 | M | RF20, RNF04, RNF05 |
| US-39 | Como equipe, quero o `InterPixGateway` no sandbox (`InterTokenService` com `client_credentials`, escopos `cob.write cob.read pix.read pix.write webhook.write webhook.read`, cache de 55 min; SSL bundle PEM `INTER_CRT`/`INTER_KEY`; `PUT /pix/v2/cob/{txid}` com `calendario.expiracao=900`, `valor.original`, `chave`, `solicitacaoPagador`, sem `devedor`) para que o app crie uma cobrança real no ambiente do banco. | Must Have (N2) | D | CP2 · S7 | M | RF19, RNF02 |
| US-40 | Como equipe, quero `consultar` (`GET /pix/v2/cob/{txid}` -> CONCLUIDA com `endToEndId`), `removerCobranca` (`PATCH` `REMOVIDA_PELO_USUARIO_RECEBEDOR`, best effort ao cancelar pendente) e o `/dev/.../confirmar` polimórfico repassando para `POST /pix/v2/cob/pagar/{txid}` no `inter-sandbox`, com o fluxo criar -> pagar -> CONCLUIDA detectado pelo job dentro do app até 23/10, para provar a API externa ponta a ponta. | Must Have (N2) | D | CP2 · S8 | M | RF20, RF21, RN12 |
| US-41 | Como equipe, quero o `InterWebhookController` (`POST /webhooks/inter/pix/{segredo}`, `permitAll`, aceita array JSON, valida txid PENDENTE e valor igual, ignora desconhecidos, idempotente) e o script `scripts/inter/05-webhook-cadastrar.http` (`PUT /pix/v2/webhook/{chave}`), cadastrado só se o Render estiver em HTTPS até 30/10 e após teste com ngrok na S8, para confirmar mais rápido quando o banco avisar. | Should Have | D | N2 · S9 | M | RF20 |
| US-42 | Como equipe, quero Pix em produção (conta PJ Inter Empresas com CNPJ não-MEI, integração solicitada até 18/09, go/no-go em 16/10 com cobrança real de R$ 1,00, profile `inter-prod` sem `/dev` nem Swagger) para apresentar com dinheiro real se a burocracia permitir. | Should Have | D | N2 · S7–S9 (gate 16/10) | M | RF19, RN18 |

Critérios de aceite das histórias desdobradas:

- **US-35a**: `PagamentoService` com txid = UUID sem hífens; expiração 900 s igual à da reserva; INSERT `pagamento` PENDENTE só com txid/valor/status/`pixCopiaECola`/location.
- **US-35b**: `UPDATE pagamento ... WHERE txid=? AND status='PENDENTE'` -> `UPDATE reserva ... WHERE status='PENDENTE_PAGAMENTO'`; `end_to_end_id` UNIQUE; valor igual exigido.
- **US-35c**: reserva EXPIRADA é reconfirmada se o slot estiver livre, senão gera log `ESTORNO_MANUAL`; reserva CANCELADA fica com pagamento PAGO + log.

## 14.9 Épico 7 — Persistência local e sincronização

| ID | User Story | Prioridade | Resp. | Entrega | Est. | RF relacionado |
|---|---|---|---|---|---|---|
| US-43 | Como equipe, quero o `AppDatabase` (Room 3.0.2, KSP, `exportSchema=false`, `fallbackToDestructiveMigration`) com `quadra_cache` (PK composta `id + escopo` CATALOGO/MINHAS, `horariosJson`) e o `Sincronizador` ("cache primeiro, rede depois, servidor vence": substitui o escopo, marca `ultima_sincronizacao_quadras`) para que Quadras, MinhasQuadras e HorariosQuadra abram instantaneamente. | Must Have (N2) | B | CP2 · S7 | M | RF23, RNF04, RNF11 |
| US-44 | Como cliente, quero `reserva_cache` (com `pixCopiaECola` e `expiraEm` para reabrir o QR offline, escopo MINHAS/QUADRA), `MonitorConectividade` (`NetworkCallback`) e o `BannerOffline` ("dados de 10/10 19:32") para consultar minhas reservas sem rede. | Must Have (N2) | C | CP2 · S7 | M | RF23, RNF11 |
| US-45 | Como equipe, quero a tabela de comportamento em modo avião verificada tela a tela (escritas desabilitadas, slots "Conecte-se", Pagamento "Aguardando conexão"), re-sync em `ON_RESUME` e na volta da rede, e logout limpando `clearAllTables()`; `QuadraDaoTest` (androidTest) fica como Should Have dentro desta história. | Must Have (N2) | C | CP2 · S8 | P | RF23, RF03, RNF11 |
| US-46 | Como cliente, quero receber a notificação local "Reserva confirmada! Quadra X, 10/10 às 19h" (canal `reservas`, `NotificadorReserva`, `POST_NOTIFICATIONS` pedida na primeira abertura da tela Pagamento em API >= 33, `PendingIntent` para DetalheReserva) para saber que o pagamento caiu mesmo fora da tela. | Should Have | C (`NotificadorReserva`, canal, PendingIntent) + D (card "Ativar avisos" e pedido de permissão na tela Pagamento) | N2 · S9 | P | RF24 |

## 14.10 Épico 8 — Qualidade, acessibilidade e testes

| ID | User Story | Prioridade | Resp. | Entrega | Est. | RF relacionado |
|---|---|---|---|---|---|---|
| US-47a | Como equipe, quero os testes automatizados da fatia da N1 rodando no CI — backend: `JwtServiceTest`, `AuthServiceTest`, `AuthControllerTest` (A); `QuadraServiceTest`, `HorarioFuncionamentoServiceTest`, `CepClientTest` com `MockRestServiceServer`, `MigracaoFlywayTest` (migração do banco) (B); `SlotServiceTest` (C); `PixPayloadBuilderTest` (D) — e Android: `CadastroViewModelTest`, `LoginViewModelTest`, `QuadrasViewModelTest` com `FakeApiService` — para que cada regra da N1 tenha prova executável. | Must Have (N1) | Todos (M por integrante) | N1 · S2–S4 | M | RNF10, todos os RN |
| US-47b | Como equipe, quero os testes automatizados da fatia da N2 rodando no CI — backend: `ReservaServiceTest`, `ReservaFacadeTest`, `ReservaControllerTest` (`@WebMvcTest`) (C, revisão de D); `PagamentoServiceTest`, `InterPixGatewayTest` (D) — e Android: `ConfirmarReservaViewModelTest`, `PagamentoViewModelTest`, `SincronizadorTest` com `FakeApiService` — para que cada regra de reserva e pagamento tenha prova executável. | Must Have (N2) | Todos (M por integrante) | CP2 · S6–S8 | M | RNF10, todos os RN |
| US-48 | Como usuário com necessidades de acessibilidade, quero `contentDescription` em ícones e no QR ("QR Code Pix, R$ 80,00"), alvos >= 48 dp, textos em `sp` funcionando a 200 %, contraste Material 3 e `ImeAction.Next` nos formulários, verificados com TalkBack em um bug bash cruzado (cada um testa a fatia do outro) para usar o app com leitor de tela. | Must Have (N2) | Todos (revisor de cada PR de tela) | CP2 · S10 | M | RNF07, RNF06 |
| US-49 | Como equipe, quero o roteiro de testes com usuários (6 tarefas, SUS, termo de consentimento, 3 perguntas abertas) e a condução de 5 a 8 sessões (mínimo 3 clientes e 2 donos, APK via adb, cada integrante conduz >= 1) para medir usabilidade real. | Must Have (N2) | C | N2 · S10–S11 | M | RNF06, RNF07 |
| US-50 | Como equipe, quero corrigir os 5 principais problemas encontrados (issues `usabilidade` com severidade) com aceite SUS >= 68 e >= 80 % de sucesso por tarefa para entregar um app usável, sem abrir features novas. | Must Have (N2) | Todos | N2 · S12 | M | RNF06 |
| US-51 | Como equipe, quero o plano de testes com casos CT-xx rastreáveis a cada RF (docs/23-plano-de-testes.md) executados e registrados antes do CP2 para provar cada requisito em menos de 1 min. | Must Have (N2) | D | CP2 · S10 | M | RNF10, RF01–RF24 |

## 14.11 Épico 9 — Documentação e apresentação

| ID | User Story | Prioridade | Resp. | Entrega | Est. | RF relacionado |
|---|---|---|---|---|---|---|
| US-52 | Como equipe, quero os documentos do Checkpoint 1 (docs/01 a 07 v1: visão, escopo, perfis, telas, RF, RNF, RN) e o protótipo Figma navegável das 13 telas, mais este backlog no GitHub Projects, para apresentar escopo, protótipo e backlog priorizado em 11/09. | Must Have (N1) | A (docs) + B (Figma) | CP1 · S2 | M | critério 1 e 7 |
| US-53 | Como equipe, quero os documentos técnicos v1 da N1 (docs/08 modelagem e 09 arquitetura por B; docs/10 API e 11 Pix por D; docs/12 persistência local e 13 recurso nativo por C) coerentes com o código do `main` para entregar modelagem e arquitetura. | Must Have (N1) | B, C, D | N1 · S4 | M | critério 2 |
| US-54 | Como equipe, quero o README executável (instalação, `docker compose up -d`, `./gradlew bootRun`, emulador em `10.0.2.2:8080`, tabela de versões verificada em 01/09/2026) testado em máquina limpa por outro integrante, a branch `release/n1` congelada na ter 29/09, o vídeo de 2 min e a tag `v0.1-n1` para entregar a N1 sem surpresas. | Must Have (N1) | A | N1 · S5 | P | RNF10, critério 7 |
| US-55 | Como equipe, quero a documentação final consolidada (docs/00-indice.md, revisão de todos os arquivos contra o código, matriz critério -> evidência -> defensor, docs/17 e 18 checklists preenchidos) até 04/12 para entregar a documentação técnica completa. | Must Have (N2) | Todos (A editor) | N2 · S14 | M | critérios 1–7 |
| US-56 | Como equipe, quero os slides (cada um apresenta a própria fatia), o roteiro de demo de 8 min (cadastro DONO -> quadra via CEP -> horários -> cadastro CLIENTE -> distância -> slots -> 2 celulares no mesmo slot -> QR Pix -> pagamento -> notificação -> modo avião -> Swagger + `git shortlog` + IT no terminal) e dois ensaios gerais para apresentar sem improviso. | Must Have (N2) | D (roteiro) + Todos | N2 · S14–S15 | M | critérios 3–7 |

## 14.12 Épico 10 — Infra e entrega

| ID | User Story | Prioridade | Resp. | Entrega | Est. | RF relacionado |
|---|---|---|---|---|---|---|
| US-57 | Como equipe, quero o `Dockerfile` multi-stage (`eclipse-temurin:21-jre`) e o pipeline de release (jar + `assembleRelease`) para que o backend rode igual no notebook e na nuvem. | Must Have (N2) | A | CP2 · S8 | P | RNF10 |
| US-58 | Como equipe, quero o backend no Render (Web Service Docker, HTTPS, deploy por push na `main`, `.crt/.key` como Secret Files, `SPRING_PROFILES_ACTIVE=inter-sandbox`) com PostgreSQL no Neon até 30/10, com `/actuator/health` para aquecer o cold start, para que testes com usuários e webhook tenham backend público. | Must Have (N2) | A | CP2 · S9 | M | RNF05, RNF09 |
| US-59 | Como equipe, quero o APK release assinado apontando para o Render via `BuildConfig.API_BASE_URL`, instalado por `adb install` em 2 celulares (a verificação de desenvolvedor do Google vigora no Brasil desde 30/09/2026 e não afeta o adb), e a avaliação da conta de distribuição limitada (até 20 dispositivos) para garantir "APK instalável" na banca. | Must Have (N2) | A | CP2 · S9 | P | RNF08 |
| US-60 | Como equipe, quero o kit de demo offline (jar + Postgres em `docker compose` no notebook, profile `simulado`, hotspot do celular, APK debug apontando para o IP do notebook) ensaiado e um vídeo de backup gravado para apresentar mesmo se Render, Neon ou sandbox falharem. | Must Have (N2) | D | N2 · S12–S13 | M | RNF05 |

## 14.13 Could Have e Won't

### Could Have (label `could`; só entre 06/11 e 25/11 e só com todos os Must verdes)

Recebem ID `US-` apenas se forem promovidas no planejamento de segunda-feira; até lá ficam na coluna Backlog.

| ID | User Story | Resp. | Est. | Referência |
|---|---|---|---|---|
| CH-01 | Como cliente, quero entrar com biometria reaproveitando o JWT salvo (`androidx.biometric 1.1.0`, `USE_BIOMETRIC` só no manifest) para não digitar a senha. | A | M | docs/02-escopo-mvp.md (OPC) |
| CH-02 | Como cliente, quero remarcar uma reserva PENDENTE_PAGAMENTO (`PATCH /reservas/{id}` com `inicio`) sem gerar nova cobrança. | C | M | RN15 |
| CH-03 | Como usuário, quero desativar minha conta (`DELETE /usuarios/me`, soft `ativo=false`). | A | P | RF05 |
| CH-04 | Como dono, quero bloquear um horário pontual (feriado/manutenção) sem alterar o funcionamento semanal. | B | G (quebrar) | RN16 |

### Won't (label `fora-mvp`; motivo em docs/02-escopo-mvp.md)

- Estorno/devolução Pix automática (estorno é manual, RN14).
- Cartão, cobv, Pix Automático, múltiplas contas (`x-conta-corrente`).
- Split do valor entre jogadores e repasse automático ao dono (RN18).
- mTLS de entrada e allowlist de IPs no webhook (limitação documentada em docs/11-integracao-pix-inter.md).
- Upload de fotos e câmera (`foto_url` texto cobre o visual).
- Mapa interativo com Maps SDK (distância + `Intent geo:` entregam o mesmo).
- Avaliações, favoritos, chat, reservas recorrentes.
- Push FCM (notificação local basta).
- Perfil ADMIN, aprovação de quadras, troca de perfil.
- Recuperação de senha por e-mail, refresh token, revogação de JWT.
- Fila offline de escritas e WorkManager periódico (RNF11).
- Publicação na Play Store (APK via adb).
- Quadras em fuso diferente de America/Sao_Paulo (RNF12).

## 14.14 Como usar no GitHub Projects

**Board** (um só projeto, `So mais uma — MVP`, dono do board: D; A é editor):

| Coluna | Regra de entrada | Regra de saída |
|---|---|---|
| Backlog | toda US e CH deste arquivo, uma issue por história (`US-25 Criar reserva PENDENTE com 409`) | recebe semana no planejamento de segunda |
| Semana atual | issues com campo `Semana` = semana corrente; no máximo ~40 h somadas (P=3, M=8) | alguém puxa e vira responsável |
| Em andamento | responsável atribuído e branch `feat/<area>-<descricao>` criada | PR aberto |
| Em revisão | PR < 400 linhas aberto, CI verde, suplente marcado como revisor | 1 aprovação + merge por quem não é o autor |
| Concluído | PR mergeado na `main` com `Closes #n` | demo de sexta |

**Labels** (todas as issues têm exatamente uma de prioridade e pelo menos uma de área):

| Grupo | Labels |
|---|---|
| Prioridade | `must-n1`, `must-n2`, `should`, `could`, `fora-mvp` |
| Área | `backend`, `android`, `docs`, `infra` |
| Tipo | `bug`, `usabilidade` (com `sev-1` a `sev-4` após os testes com usuários, escala de docs/22-testes-com-usuarios.md), `risco` (item vindo de docs/19-riscos.md), `contrato` (mudança de API ou de esquema), `inter` (burocracia do banco, com data no título), `spike` |

**Milestones** com data de vencimento: `CP1` (11/09), `N1` (02/10), `CP2` (06/11), `N2` (11/12). Uma issue muda de milestone só na reunião de segunda, com o motivo no comentário.

**Campos personalizados**: `Estimativa` (P/M/G), `Semana` (S1..S15), `RF` (texto, ex.: `RF13, RN08`), `Fatia` (A/B/C/D). Histórias G são fechadas como "épico local" e substituídas por sub-issues P/M com a mesma label e milestone antes de entrar em Semana atual.

**Views salvas**: "Por milestone" (tabela agrupada por milestone, ordenada por ID), "Semana atual" (board), "Por integrante" (agrupado por `Fatia`, usada na sexta junto com `git shortlog -sn -- backend android docs`), "Inter" (filtro `label:inter`, datas 02/09, 04/09, 18/09, 29/09, 16/10, 23/10, 27/10, 30/10, 24/11, 27/11).

**Fluxo de uma história**: issue criada a partir deste arquivo -> planejamento de segunda define `Semana` -> branch -> commits em português referenciando a issue -> PR com checklist (testes, acessibilidade se for tela, docs atualizados) -> revisão do suplente (que faz 1 commit de acessibilidade em PR de tela) -> merge -> demo na sexta. Detalhes em docs/21-git-e-organizacao.md.

## 14.15 O que mostrar no Checkpoint 1 (sex 11/09)

| Item pedido | Evidência | Quem mostra |
|---|---|---|
| Escopo definido | docs/02-escopo-mvp.md com Must/Should/Could/Won't e a lista FORA com motivo; docs/01-visao-do-produto.md (problema, domínio, público) | A |
| Protótipo navegável | Figma com as 13 telas ligadas pelo grafo de docs/04-telas.md, percorrido nos dois perfis (CLIENTE: Quadras -> DetalheQuadra -> ConfirmarReserva -> Pagamento; DONO: MinhasQuadras -> FormQuadra -> HorariosQuadra) | B |
| Backlog priorizado | board do GitHub Projects com os 70 itens, labels `must-n1/must-n2/should/could`, milestones CP1/N1/CP2/N2, estimativa P/M/G e semana; view "Por milestone" aberta | D |
| Requisitos | docs/05, 06 e 07 v0 com RF01–RF24, RNF01–RNF12, RN01–RN20 e as tags de prioridade | A |
| Modelagem inicial | `V1__init.sql` no repositório e DER de docs/08-modelagem-banco.md (rascunho) | C / B |
| Repositório | monorepo com CI verde, `git shortlog -sn` mostrando commits dos 4 (esqueletos, V1, docs), issues abertas | A |
| Riscos externos | ata dos gates de 02/09 e 04/09 (conta sandbox criada? CNPJ disponível?) e a decisão de fallback correspondente (docs/19-riscos.md, R1–R3) | D |

O que **não** se promete no CP1: telas funcionais no celular (isso é N1), Inter dentro do app (S7–S8) e geolocalização (S9).
