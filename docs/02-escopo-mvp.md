# Escopo do MVP

Resumo: este documento fixa o que entra em cada entrega (N1 e N2), o que é recomendado, o que é opcional e o que fica fora do MVP com o motivo de cada item, e mostra por que o escopo cabe em 4 estudantes durante 15 semanas. As datas oficiais estão em `docs/16-cronograma.md`; os RF citados estão definidos em `docs/05-requisitos-funcionais.md`.

## 1. Critério de corte

Uma funcionalidade só entra no MVP se atender a pelo menos uma das duas condições:

1. **Pontua em um critério da disciplina** (engenharia, modelagem/arquitetura, mobile, persistência, recurso nativo, qualidade, Git); ou
2. **Está no fluxo principal** "encontrar quadra -> ver horário -> reservar -> pagar -> confirmação" (`docs/01-visao-do-produto.md`, seção 7).

Tudo o mais fica **fora** (seção 6) ou vira **opcional** (seção 5). Regras de desempate aplicadas em todas as decisões: enum antes de tabela; constraint no banco antes de lock; polling antes de webhook; injeção de dependência manual antes de framework; tudo o que depende de terceiros (Banco Inter, Google, hospedagem) tem fallback implementado e data-limite.

## 2. Etiquetas de prioridade

| Etiqueta (docs e labels do GitHub) | Equivalente | Significado |
|---|---|---|
| **Must Have (N1)** — label `must-n1` | OBR-N1 | Obrigatório na Entrega N1 (28/09 a 02/10/2026) |
| **Must Have (N2)** — label `must-n2` | OBR-N2 | Obrigatório na Apresentação N2 (07 a 11/12/2026) |
| **Should Have** — label `should` | REC | Recomendado; entra somente com todos os Must verdes (regra de ouro, seção 7) |
| **Could Have** — label `could` | OPC | Opcional; só entre 06/11 e 25/11 e se sobrar tempo |
| **Fora do MVP** — label `fora-mvp` | FORA | Não será feito; registrado com motivo para a banca |

## 3. Must Have (N1) — Entrega N1, 28/09 a 02/10/2026

Meta da N1, conforme o enunciado: "aplicação parcialmente funcional" com documentação, modelagem, arquitetura, protótipo e repositório organizado. O grupo escolheu uma N1 **leve na interface e completa no backend**: autenticação, os dois CRUDs completos e a busca de CEP nas telas; o backend de reserva e pagamento pronto e demonstrável pelo Swagger, ainda sem telas.

### 3.1 Funcionalidades com tela

| RF | Funcionalidade | Telas | Endpoints | Responsável | Tamanho |
|---|---|---|---|---|---|
| RF01 | Cadastro com perfil (CLIENTE/DONO) e auto-login | `Cadastro` | `POST /auth/registrar` | A | M |
| RF02 | Login por e-mail/senha com JWT | `Login` | `POST /auth/login` | A | M |
| RF03 | Manter sessão local e sair | `Splash`, `Perfil` (botão Sair) | — (`SessaoDataStore`) | A | P |
| RF05 | Ver e editar o próprio perfil | `Perfil` | `GET /usuarios/me`, `PUT /usuarios/me` | A | P |
| RF06 | CRUD completo de Quadra pelo DONO | `MinhasQuadras`, `FormQuadra` | `POST /quadras`, `GET /quadras/minhas`, `PUT /quadras/{id}`, `DELETE /quadras/{id}` | B | G |
| RF07 | Listar quadras ativas com filtro por esporte e cidade | `Quadras` | `GET /quadras?esporte=&cidade=` | B | M |
| RF08 | Detalhe da quadra (dados, endereço, horários; distância entra na N2 com RF22) | `DetalheQuadra` | `GET /quadras/{id}` | B | M |
| RF09 | Buscar CEP e preencher endereço + latitude/longitude (BrasilAPI CEP v2, fallback ViaCEP, via backend) | `FormQuadra` | `GET /cep/{cep}` | B | M |
| RF10 | Impedir desativação de quadra com reservas ativas futuras (409) | `MinhasQuadras` (diálogo) | `DELETE /quadras/{id}` -> 409 `QUADRA_COM_RESERVAS` | B | P |
| RF11 | CRUD completo de HorarioFuncionamento por dia da semana | `HorariosQuadra` | `POST/GET/PUT/DELETE /quadras/{id}/horarios-funcionamento[/{hid}]` | B | G |

São **7 telas funcionais** na N1 (Login, Cadastro, Quadras, DetalheQuadra, MinhasQuadras, FormQuadra, HorariosQuadra), mais Perfil e Splash de apoio. O RF09 é obrigatório já na N1 porque `FormQuadra` existe na N1 e a geolocalização da N2 (RF22) depende das coordenadas que ele grava.

### 3.2 Backend pronto e demonstrável via Swagger (sem tela)

| RF | O que fica pronto | Evidência na N1 |
|---|---|---|
| RF12 | `SlotService` e `GET /quadras/{id}/slots?data=` | Swagger devolve a grade LIVRE/OCUPADO/PASSADO/FECHADO |
| RF13 | `POST /reservas` com índice único parcial `ux_reserva_slot_ativo` e 409 `HORARIO_INDISPONIVEL` | `ReservaConcorrenciaIT` (10 threads: 1x201, 9x409) verde no CI |
| RF14 | `ExpiracaoReservaJob` (UPDATE condicional a cada 60 s) | Reserva criada no Swagger vira `EXPIRADA` após 15 min |
| RF19 | `PixGateway` + `SimuladoPixGateway` + `PixPayloadBuilder`; cobrança criada fora da transação (`ReservaFacade`) | `POST /reservas` no Swagger devolve `pagamento.pixCopiaECola` válido |
| RF21 | `POST /dev/pagamentos/{txid}/confirmar` (profile `simulado`) | Confirmação ponta a ponta no Swagger em sex 18/09 |

### 3.3 Entregáveis não funcionais da N1

- Documentação: obrigatórios `README.md` e `docs/00` a `docs/11`, `docs/14-backlog.md` priorizado (GitHub Projects com labels e estimativa P/M/G), `docs/15`, `docs/16`, `docs/19`, `docs/20-ordem-de-implementacao.md` e `docs/21`; recomendados como esqueleto `docs/12`, `docs/13`, `docs/22` e `docs/23`; lista Fora do MVP (esta seção 6). `docs/17-checklist-n1.md` e `docs/18-checklist-n2.md` são checklists vivos que acompanham as entregas: o primeiro é conferido item a item até o congelamento da N1 e o segundo é aberto na N1 e mantido atualizado até a apresentação da N2.
- Modelagem: `V1__init.sql` (5 tabelas + índice único parcial) e DER em `docs/08-modelagem-banco.md`; `V1` nunca é editado após a N1 (migrations aditivas, RNF10).
- Protótipo navegável no Figma com as 13 telas (Checkpoint 1, 11/09).
- Repositório: monorepo `backend/`, `android/`, `docs/`; commits dos 4 integrantes em `backend/`, `android/` e `docs/`; branch `release/n1` congelada na terça 29/09; tag `v0.1-n1`.

## 4. Must Have (N2) — Apresentação N2, 07 a 11/12/2026

Meta: "app completo" com APK instalável, testes, documentação e demonstração. Tudo da N1 continua obrigatório.

| RF | Funcionalidade | Telas | Endpoints / componentes | Responsável | Tamanho |
|---|---|---|---|---|---|
| RF04 | Bloquear login por 15 min após 5 falhas | `Login` (erro 429) | `LoginTentativasService` | A | P |
| RF12 | Grade de slots de 60 min por data (hoje até hoje+14) | `DetalheQuadra` | `GET /quadras/{id}/slots?data=` | C | M |
| RF13 | Criar reserva PENDENTE_PAGAMENTO com exclusividade do slot | `ConfirmarReserva` | `POST /reservas` (409/422/502 tratados na tela) | C | G |
| RF14 | Expirar reserva pendente não paga em 15 min | `Pagamento` (status Expirado), `MinhasReservas` | `ExpiracaoReservaJob` | C | P |
| RF15 | Listar minhas reservas (próximas/histórico) e ver detalhe | `MinhasReservas`, `DetalheReserva` | `GET /reservas?situacao=`, `GET /reservas/{id}` | C | M |
| RF16 | Editar observação da reserva | `DetalheReserva` | `PATCH /reservas/{id}` | C | P |
| RF17 | Cancelar reserva (cliente e dono, RN13) | `DetalheReserva`, `ReservasQuadra` | `POST /reservas/{id}/cancelar` | C | M |
| RF18 | Reservas das quadras do DONO por data | `ReservasQuadra` | `GET /quadras/{id}/reservas?data=` | C | M |
| RF19 | Gerar cobrança Pix (QR Code + copia e cola) na tela | `Pagamento` | `PixQrCode` (ZXing core), `InterPixGateway` em sandbox ou `SimuladoPixGateway` | D | G |
| RF20 | Confirmar pagamento automaticamente (polling do app + job do backend) e reserva -> CONFIRMADA | `Pagamento` | `GET /reservas/{id}/pagamento`, `ConsultaPagamentoJob`, `PagamentoService.confirmar` idempotente | D | G |
| RF21 | Simular pagamento em desenvolvimento/sandbox | `Pagamento` (botão só em debug) | `POST /dev/pagamentos/{txid}/confirmar` (JWT + `X-Dev-Key`) | D | P |
| RF22 | Geolocalização: distância, ordenação por proximidade, abrir no app de mapas | `Quadras`, `DetalheQuadra` | `LocalizacaoProvider`, `Geo.kt`, Intent `geo:` | C | M |
| RF23 | Cache local de quadras e reservas com sincronização e leitura offline | todas as listas e detalhes; `BannerOffline` | `AppDatabase` (`quadra_cache`, `reserva_cache`), `Sincronizador`, `MonitorConectividade` | B (quadras) / C (reservas) | G |

Também obrigatórios na N2 (critérios 6 e 7):

- Qualidade: Bean Validation no backend e validação por campo no Compose; `ProblemDetail` RFC 9457 com `codigo`; estados carregando/vazio/erro em toda tela (RNF06); acessibilidade básica com `contentDescription`, alvos de 48 dp, fonte a 200 % e teste com TalkBack (RNF07).
- Testes: `ReservaConcorrenciaIT`, testes unitários de services, ViewModels com fakes, `docs/23-plano-de-testes.md` com casos CT-xx por RF, testes com 5 a 8 usuários (09 a 13/11) com SUS >= 68 e >= 80 % de sucesso por tarefa (`docs/22-testes-com-usuarios.md`).
- Entrega: APK release assinado instalado via `adb`; backend no Render + Neon com profile `inter-sandbox` (ou `simulado`); kit de demo offline ensaiado; 13 telas, das quais 11 funcionais (7 já na N1).

## 5. Should Have e Could Have

### 5.1 Should Have (recomendado) — só com todos os Must verdes

| Item | RF | Por que é recomendado e não obrigatório | Data-limite / gate |
|---|---|---|---|
| Notificação local "Reserva confirmada" (segundo recurso nativo, ~40 linhas) | RF24 | O critério 5 já é coberto pela geolocalização (RF22); a notificação melhora a demonstração | S9 (26 a 30/10) |
| Webhook do Inter `POST /webhooks/inter/pix/{segredo}` | complemento do RF20 | Depende de backend público em HTTPS e a pesquisa não confirma que o sandbox dispara callbacks; o polling já cumpre o requisito | Render em HTTPS até 30/10; senão sai do backlog |
| Pix em produção (conta PJ Inter Empresas) | complemento do RF19/RF20 | Exige CNPJ não-MEI e aprovação da integração, fora do controle do grupo; sandbox já conta como API externa real | Go/no-go em 16/10 |
| Exibir `foto_url` com Coil | RF08 | Puramente visual; o campo texto já existe | S9 |

### 5.2 Could Have (opcional) — entre 06/11 e 25/11, na prática raramente

| Item | Escopo | Custo estimado | Condição |
|---|---|---|---|
| Login por biometria reaproveitando o JWT (`androidx.biometric 1.1.0`) | `Login` | P | Todos os Must e Should verdes; não pontua critério novo |
| Desativar conta (`DELETE /usuarios/me`) | `Perfil` | P | Idem |
| Remarcar reserva (`PATCH /reservas/{id}` com `inicio`) enquanto PENDENTE_PAGAMENTO | `DetalheReserva` | M | Idem; exige revalidar o slot (RN08) |
| Bloqueio pontual de horário pelo dono (feriado/manutenção) | nova entidade | M | Idem; entidade extra sem critério |

## 6. Fora do MVP (com motivo por item)

| Funcionalidade | Motivo | Registro |
|---|---|---|
| Estorno/devolução Pix automática | Exige `pix.write` para devolução e tratamento bancário; cancelamento não estorna; estorno manual fora do app | RN13, RN14 |
| Cartão de crédito, Pix com vencimento (`cobv`), Pix Automático, múltiplas contas (`x-conta-corrente`) | Segundo meio de pagamento não pontua e dobra a superfície de erro | `docs/11-integracao-pix-inter.md` |
| Split do valor entre jogadores ("racha") | Múltiplos pagamentos por reserva; "trabalhos futuros" | `docs/01`, seção 8 |
| Repasse ao dono da quadra | Todo Pix cai na única chave configurada; repasse fora do app | RN18 |
| mTLS de entrada / allowlist de IPs no webhook | Configurar client-auth no Tomcat/Render é desproporcional; validação por txid + valor + idempotência; limitação documentada | `docs/11` |
| Upload de fotos, câmera | Storage de arquivos + permissão; `foto_url` como texto cobre o visual | `docs/13-recurso-nativo.md` |
| Mapa interativo (Maps SDK) | API key + billing; distância Haversine + Intent `geo:` entregam o mesmo valor | RF22 |
| Avaliações, favoritos, chat, reservas recorrentes | Entidades e regras extras sem critério correspondente | — |
| Push FCM | Firebase + servidor; notificação local basta | RF24 |
| Perfil ADMIN, aprovação de quadras, troca de perfil | Terceiro perfil sem pontuação; DONO administra apenas o que é seu | `docs/03-perfis-e-permissoes.md`, RN20 |
| Recuperação de senha por e-mail, refresh token, revogação de JWT | SMTP e tabela de sessão; JWT de 7 dias + reset manual no beta; limitação documentada | RNF01, RNF03 |
| Fila offline de escritas, WorkManager periódico | Conflitos insolúveis com reserva exclusiva; sync on-resume basta | RNF11, `docs/12-persistencia-local.md` |
| Publicação na Play Store | Verificação de desenvolvedor (Brasil, 30/09/2026) e requisitos de targetSdk; APK via `adb` atende "instalável" | `docs/19-riscos.md` |
| Quadras em fuso diferente de `America/Sao_Paulo` | Fuso único no MVP | RNF12 |
| Paginação, cache HTTP, Redis, microsserviços, filas | Listas pequenas; monólito em um jar + um PostgreSQL | `docs/09-arquitetura.md` |
| Testes E2E de UI automatizados em CI | Emulador em CI custa horas; testes de ViewModel com fakes + plano manual CT-xx + SUS | `docs/23-plano-de-testes.md` |

## 7. Regra de ouro

**Nenhum item Should Have ou Could Have começa enquanto houver bug aberto em um item Must Have.** Operacionalmente:

1. Na reunião de segunda-feira, A (editor do backlog com D) filtra o board por `must-n1`/`must-n2` com status diferente de Concluído; se houver qualquer item, os `should`/`could` ficam em Bloqueado.
2. Um bug em Must reportado por outro integrante, por usuário de teste ou pelo CI tem prioridade sobre qualquer feature nova, inclusive Must ainda não iniciado da mesma fatia.
3. Após o congelamento de escopo (sexta 27/11) só entram correções; item novo, mesmo pequeno, entra como `could` para o "pós-disciplina".
4. Quem decide exceções: os 4 em ata; sem ata, a regra vale.

## 8. Por que o MVP cabe em 4 estudantes durante 15 semanas

### 8.1 Orçamento de horas

| Item | Valor |
|---|---|
| Integrantes | 4 (A, B, C, D), cada um dono de uma fatia vertical: backend + Android + documento + teste |
| Dedicação | ~10 h por pessoa por semana = **~40 h/semana** |
| Período | 01/09 a 11/12/2026 = 15 semanas de calendário; a S1 começa na terça e a S15 é a semana da apresentação |
| Feriados descontados | 07/09, 12/10, 02/11 e 20/11 (4 dias, ~32 h) |
| Total útil | **~560 h** |

### 8.2 Distribuição por fase (aproximada)

| Fase | Semanas | Horas | O que consome |
|---|---|---|---|
| Fundação, burocracia do Inter e spikes | S1–S2 (01/09–11/09) | ~70 h | Esqueletos dos 2 projetos com versões fixadas, `V1__init.sql`, CI, conta sandbox, 3 h de spike por pessoa (Compose/Navigation tipada; Boot 4/Jackson 3), Figma, Checkpoint 1 |
| N1 | S3–S5 (14/09–02/10) | ~120 h | Auth ponta a ponta, CRUD Quadra + HorarioFuncionamento + CEP, 7 telas, backend de reserva + `ReservaConcorrenciaIT`, simulado via Swagger, docs da N1, congelamento e tag |
| Reserva, pagamento e cache | S6–S8 (05/10–23/10) | ~120 h | Telas de reserva e pagamento com simulado, `InterPixGateway` em sandbox, polling + job, Room + `Sincronizador`, telas do dono |
| Recurso nativo, deploy e Checkpoint 2 | S9–S10 (26/10–06/11) | ~80 h | Geolocalização, Render + Neon, APK assinado + `adb install`, bug bash, acessibilidade, `release/beta` |
| Testes com usuários e correções | S11–S12 (09/11–20/11) | ~70 h | 5 a 8 sessões, SUS, top-5 correções, ensaio da demo |
| Congelamento, documentação e apresentação | S13–S15 (23/11–11/12) | ~70 h | Estabilização, documentação final (04/12), slides, vídeo de backup, ensaios |
| Folga / absorção de imprevistos | distribuída em S6 e S12 | ~30 h | Provas de outras disciplinas, ausências, toolchain nova |
| **Total** | | **~560 h** | |

### 8.3 Estimativa por RF (tetos P <= 3 h, M <= 8 h, G <= 16 h)

Usando os tamanhos das tabelas das seções 3 e 4 (7 itens P, 10 itens M, 6 itens G), o teto de esforço das 23 funcionalidades dimensionadas é **7×3 + 10×8 + 6×16 = 197 h**, ou seja, cerca de 35 % do orçamento. Os ~360 h restantes cobrem infraestrutura, testes automatizados, documentação, protótipo, testes com usuários, reuniões e apresentação. Itens G são obrigatoriamente quebrados em issues de até 8 h no board (`docs/14-backlog.md`).

### 8.4 Decisões que mantêm o escopo dentro do orçamento

| Decisão | Efeito no esforço |
|---|---|
| N1 leve na interface (7 telas) e completa no backend | A parte de maior risco técnico (concorrência de reserva, gateway Pix) é resolvida cedo, quando ainda é barata; as telas de reserva/pagamento entram em S6 com o backend estável |
| Dois CRUDs simples e inequívocos (Quadra e HorarioFuncionamento) | Cumprem o critério 3 sem entidades extras; `TipoEsporte` é enum, endereço é embutido, slots são calculados |
| Fallback interno (`SimuladoPixGateway`) desde S1–S3 | O fluxo de pagamento não espera certificado, horário do sandbox (8h–20h, seg–sex) nem conta PJ; o Inter entra depois como "troca de bean" |
| Gates datados para tudo o que depende de terceiros (02/09, 04/09, 18/09, 16/10, 23/10, 30/10, 27/11) | Nenhuma incerteza externa consome mais que a semana prevista; consequência definida em `docs/19-riscos.md` |
| Complexidade evitada (Hilt, Clean Architecture com use cases, WorkManager, webhook como caminho principal, mTLS de entrada, Maps SDK, upload de fotos) | Cada item removido economiza de 8 a 30 h e reduz risco de toolchain |
| Fatias verticais com suplente (A<->D, B<->C) e PR revisado pelo suplente | Ausência de um integrante não bloqueia a fatia; os 4 aparecem no Git em `backend/`, `android/` e `docs/` |
| Folga explícita em S6 e S12 | Absorve feriados adicionais, provas e o bug inesperado sem estourar o congelamento de 27/11 |

### 8.5 O que acontece se o tempo apertar (ordem de corte)

1. Could Have some inteiramente (nunca começou).
2. Should Have: Pix em produção -> webhook -> Coil -> notificação local (a última a sair, por ser barata e valiosa na demo).
3. Dentro dos Must (N2), o grupo reduz **profundidade**, não funcionalidade: menos testes unitários por service, menos casos CT-xx, sessões de teste com 5 usuários em vez de 8.
4. Nenhum Must Have é cortado; se isso parecer necessário, o problema é reportado ao professor antes do Checkpoint 2 (06/11), não no dia da apresentação.
