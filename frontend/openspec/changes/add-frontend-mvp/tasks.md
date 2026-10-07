Fases na ordem de docs/20, com as datas de docs/16. Os grupos 1 a 7 levam ao beta funcional do Checkpoint 2
(sex 06/11/2026), e o grupo 8 fecha a qualidade e a entrega antes dele. Cada grupo traz o responsável da
fatia, com o suplente entre parênteses, conforme docs/15, e um critério de pronto verificável. Toda tarefa de
tela entrega no mesmo PR:
- o store, a view e os testes;
- as strings em pt, en e es;
- na descrição do PR, o print do app lado a lado com o `code.html` correspondente renderizado.

A atualização dos documentos em `docs/` vai em um PR separado, fora deste change.

## 1. Fundação (S6, até sex 09/10)

Responsável: A (D). Pronto quando:
- `flutter analyze` e `flutter test` passam com o Flutter 3.47.6 nos 4 notebooks;
- o job `frontend` do CI fica verde e publica `apk-debug`;
- o APK debug abre no emulador a Splash do protótipo com o tema e a fonte Inter;
- não sobra onboarding, home, `flutter_dotenv` nem `.env` em assets.

- [ ] 1.1 Instalar o Flutter 3.47.6 nos 4 notebooks e registrar o `flutter --version` de cada um na issue da fundação, porque o `sdk: ^3.13.0` não resolve no 3.44.2 instalado hoje
- [ ] 1.2 Rodar `flutter create . --platforms android --org com.corebuild --project-name so_mais_uma` em `frontend/` e conferir no diff que `lib/` e `pubspec.yaml` não foram sobrescritos
- [ ] 1.3 Configurar `android/app/build.gradle.kts` conforme design.md D10: applicationId e namespace `com.corebuild.so_mais_uma`, `applicationIdSuffix ".debug"`, `minSdk` 26, `compileSdk` e `targetSdk` do Flutter, core library desugaring e assinatura de release lida de `key.properties`
- [ ] 1.4 Declarar no manifest principal as permissões de docs/13 §13.6, `uses-feature` de GPS opcional, `allowBackup="false"` e o rótulo "Só mais uma"; liberar cleartext só em `src/debug`; acrescentar `ic_notificacao` monocromático e `res/raw/keep.xml`
- [ ] 1.5 Reescrever o `pubspec.yaml` com as versões fixadas de design.md D20 e `sdk: ^3.13.0`, removendo `flutter_dotenv`, `image_picker` e `app_version_update`; resolver o `intl` exigido pelo SDK; versionar o `pubspec.lock`
- [ ] 1.6 Criar `config/dev.json.exemplo` e `config/release.json` (com marcador), pôr `config/dev.json` no `.gitignore` de `frontend/` e reescrever o `AppConfig` com `String.fromEnvironment` (`API_BASE_URL`, `DEV_KEY` e a URI de health); remover o `.env` dos assets e o `dotenv.load`
- [ ] 1.7 Aplicar as correções do boilerplate de design.md D21: remover onboarding, home, recuperação de senha, ícones sociais, `MediaService`, `VersionUpdateService` e o `SessionListenerWrapper`; ajustar `runTask`, `AppErrorHandler`, `UrlLauncherService`, `StorageService` (`SharedPreferencesAsync`) e o ScreenUtil para 390×844
- [ ] 1.8 Implementar o tema de design.md D2: `ColorScheme` claro explícito, escuro derivado, `AppColorsExtension`, `TextTheme` com os tokens, apelidos de `AppBorders`, `AppSpacing.s6`, `s10` e `s14`, `AppShadows.topBar` e `bottomBar`; atualizar `frontend/DESIGN.md`, `CLAUDE.md` e `AGENTS.md`
- [ ] 1.9 Empacotar a fonte Inter (pesos 400, 500, 600 e 700) em `assets/fonts/` com a licença OFL e declará-la no `pubspec.yaml`
- [ ] 1.10 Versionar `assets/images/logo.svg` e o `splash.png` exportados de `so_mais_uma_logo`; gerar o ícone adaptativo; configurar `flutter_native_splash.yaml` com `#f7f9fb` e a superfície escura; rodar `dart run flutter_native_splash:create`
- [ ] 1.11 Montar a base de i18n: `pt.json`, `en.json` e `es.json` com as chaves `comum.*` e `erros.*` de todos os `codigo` e `subcodigo` do catálogo; `LocalizationWrapper` com pt como fallback; teste `traducoes_test.dart` de paridade de chaves
- [ ] 1.12 Criar `AppRoutes` com todos os caminhos de design.md D9, os dois `StatefulShellRoute.indexedStack` com a bottom-nav do protótipo e telas provisórias, e o `redirect` como função pura com `redirect_test.dart` cobrindo cada regra
- [ ] 1.13 Criar `EstadoTela`, `Relogio` injetável e os primeiros registros do `injector.dart` (design.md D4 e D5)
- [ ] 1.14 Substituir o `test/widget_test.dart` do boilerplate e confirmar o job `frontend` verde, com `app-debug.apk` instalável por `adb install -r`

## 2. Walking skeleton: sessão, Splash, Login, Cadastro e Sair (S6)

Responsável: A (D). Pronto quando:
- no emulador contra o backend em `simulado`, Splash -> Cadastro -> home do perfil -> Sair -> Login ->
  `cliente@demo.com` funciona;
- reabrir o app com sessão vai direto para a home sem chamar a API;
- trocar o `JWT_SECRET` do backend com o app aberto leva ao Login uma única vez, com "Sua sessão expirou.
  Entre novamente.".

- [ ] 2.1 Implementar `ApiFailure`, `ProblemDetailParser` e a tradução de `DioException` de design.md D6, com `problem_detail_parser_test.dart` cobrindo `codigo`, `subcodigo`, `campos[]`, `reservaId` e corpo inválido
- [ ] 2.2 Implementar o `ApiClient` (Dio único com os timeouts e o log sem `Authorization`) e o `AuthInterceptor`, com `auth_interceptor_test.dart` provando Bearer só fora de `/auth/*` e um único encerramento para dois 401 `TOKEN_INVALIDO`
- [ ] 2.3 Evoluir o `SessionStore` para `shared/session/` com as chaves de design.md D8 (token primeiro, falha do Keystore igual a sessão ausente, token a menos de 5 minutos encerrado) e criar `EncerrarSessao`; testes com armazenamentos falsos
- [ ] 2.4 Criar os modelos `Usuario`, `TokenResponse` e `Sessao` com JSON escrito à mão e o `AuthRepository` (`POST /auth/login`, `POST /auth/registrar`)
- [ ] 2.5 Construir a Splash a partir de `splash_screen/code.html`, com o mínimo de 1 s, a remoção do native splash e a versão real vinda do `AppInfoService`; view test, strings e comparação
- [ ] 2.6 Construir o Login a partir de `login/code.html`: validação, 401, 429 com botão desabilitado por 30 s, falta de conexão, "Acesso do Gestor de Quadra" e aviso de sessão expirada; `login_store_test.dart`, view test, strings e comparação
- [ ] 2.7 Construir o Cadastro a partir de `cadastro/code.html`: cartões de perfil, medidor de força, máscara de telefone, confirmação, 409 no campo e auto-login; `cadastro_store_test.dart`, view test, strings e comparação
- [ ] 2.8 Criar a primeira versão do Perfil nos dois shells, com nome, perfil e o botão "Sair da conta com segurança" com o diálogo, encerrando a sessão
- [ ] 2.9 Validar o walking skeleton no emulador contra a API real (`http://10.0.2.2:8080/api/v1`), inclusive o 401 com o segredo trocado, e anexar o vídeo curto na issue

## 3. Telas do critério 3 (S6–S7, até sex 16/10)

Responsável:
- B (C): quadras, horários e CEP;
- A (D): Perfil completo.

Pronto quando:
- os dois CRUDs completos (Quadra e HorarioFuncionamento) funcionam pelo app contra a API real, com CT-08,
  CT-09, CT-11, CT-12, CT-13, CT-14 e CT-31 executados;
- o Perfil edita dados e senha (CT-07);
- todas as telas do grupo têm o print lado a lado aprovado.

- [ ] 3.1 Criar os enums e as entidades compartilhadas (`TipoEsporte` com rótulos, ícones e rótulo curto, `Quadra`, `HorarioFuncionamento`, `EscopoQuadra`) com JSON escrito à mão; testes de enum desconhecido para `OUTRO` e de campo extra ignorado
- [ ] 3.2 Implementar `QuadraRepository` e `CepRepository` com o contrato de design.md D13, ainda sem cache (os signals carregados da rede)
- [ ] 3.3 Construir os componentes de domínio de quadra: chips de esporte, card de quadra com placeholder ilustrado e etiqueta de distância, barra superior com o avatar de iniciais
- [ ] 3.4 Construir a tela Quadras a partir de `quadras/code.html` (busca local por cidade ou bairro, chips, estados de carregando, vazio e erro, puxar para atualizar, rodapé de sincronização); `quadras_store_test.dart`, view test, strings e comparação
- [ ] 3.5 Implementar o agrupamento de horários de funcionamento (design.md D14) com testes dos casos de 1, 2 e 3 ou mais dias e dos dias fechados
- [ ] 3.6 Construir a parte estática da DetalheQuadra a partir de `detalhe_da_quadra/code.html` (CLIENTE em `/quadras/:id` e DONO em `/dono/quadras/:id`, com o parâmetro para a seção de reserva); store test, view test, strings e comparação
- [ ] 3.7 Construir MinhasQuadras a partir de `minhas_quadras/code.html`, ainda sem as métricas do dia: lista, selos, ações, menu "Desativar quadra", diálogo de 409 com "Ver reservas" e estado vazio; store test, view test, strings e comparação
- [ ] 3.8 Construir a FormQuadra a partir de `nova_quadra/code.html` (nova e edição, validações do `QuadraRequest`, preço em `"80.00"`, busca de CEP com 404, 503 e `fonte`, Cidade e UF separados, pré-visualização da foto, diálogo de descartar); store test, view test, strings e comparação
- [ ] 3.9 Implementar `HorarioRepository` e `SalvarHorariosUseCase` com `salvar_horarios_use_case_test.dart` provando a ordem de POST, PUT e DELETE, a reversão só da linha com 409 e a interrupção por falha de rede
- [ ] 3.10 Construir HorariosQuadra a partir de `hor_rios_de_funcionamento/code.html` (7 cartões, seletores de hora cheia até 23:00, "Copiar", confirmação de fechamento, salvamento em lote, diálogo de descartar); store test, view test, strings e comparação
- [ ] 3.11 Completar o Perfil a partir de `perfil_do_usu_rio/code.html` (variantes CLIENTE e DONO, `GET` e `PUT /usuarios/me`, troca de senha com 422 no campo, preferência de aviso, versão e última sincronização); `perfil_store_test.dart`, view test, strings e comparação
- [ ] 3.12 Executar no app os CT-07, CT-08, CT-09, CT-11, CT-12, CT-13, CT-14 e CT-31 contra a API real e registrar o resultado na planilha de execução

## 4. Reserva e pagamento no profile `simulado` (S6–S7, até sex 16/10)

Responsável: C (B), com as contribuições cruzadas de docs/15 §15.5:
- B: grade e faixa de datas (US-28);
- A: MinhasReservas (US-31);
- D: tela Pagamento.

Pronto quando, no app contra o backend em `simulado`:
- reservar -> pagar pela simulação -> ver "Confirmada" funciona de ponta a ponta;
- o 409 com dois celulares volta à grade recarregada;
- o 422 leva à reserva pendente;
- o back da tela Pagamento cai em MinhasReservas;
- a expiração aparece em até 16 minutos;
- CT-16, CT-18, CT-19, CT-20, CT-22, CT-23, CT-25 (sem a notificação), CT-26 e CT-27 (cliente) foram
  executados.

- [ ] 4.1 Criar as entidades `Slot`, `Reserva` e `Pagamento` com JSON escrito à mão e testes de enum desconhecido; implementar `SlotRepository`, `ReservaRepository` e `PagamentoRepository` conforme design.md D13, ainda sem cache
- [ ] 4.2 Implementar os cálculos de reserva de design.md D14 (abas, "Concluída", prazo de cancelamento, "Estorno pendente", contador Pix, faixa de datas) com testes de cada fórmula
- [ ] 4.3 Construir a faixa de datas, a grade de slots, a seleção e a barra "Continuar" a partir de `detalhe_da_quadra/code.html` (B, US-28), com a busca da próxima data livre e o pedido de recarga na volta; `grade_slots_store_test.dart`, view test, strings e comparação
- [ ] 4.4 Construir a ConfirmarReserva a partir de `confirmar_reserva/code.html` no estado anterior ao POST, com o tratamento de 2xx, 409, 422 (diálogo com `reservaId`), 502 e falta de conexão, sem POST duplicado; `confirmar_reserva_store_test.dart`, view test, strings e comparação
- [ ] 4.5 Construir a tela Pagamento a partir de `pagamento_pix/code.html` e `pagamento_expirado/code.html` (D): QR local, copia e cola, contador por `expiraEm`, consulta com a máquina de estados de design.md D15, "Já realizei o pagamento", simulação só em debug, voltar para MinhasReservas, cancelar a pendente, estados expirado e cancelado; `pagamento_store_test.dart` com `fakeAsync`, view test, strings e comparação
- [ ] 4.6 Construir MinhasReservas a partir de `minhas_reservas/code.html` (A, US-31): abas com contadores, cards pendente e confirmado, "Concluída", histórico recente, cartão final sem números inventados e estados vazios; store test, view test, strings e comparação
- [ ] 4.7 Construir a DetalheReserva a partir de `detalhe_da_reserva/code.html` e `detalhe_da_reserva_cancelada/code.html` (ativa, pendente com "Pagar agora (Pix)", cancelada, expirada e concluída), com a observação editável e a política de cancelamento calculada; store test, view test, strings e comparação
- [ ] 4.8 Construir o sheet de cancelamento do cliente a partir de `cancelar_reserva_confirma_o/code.html` (motivo de 5 a 200 caracteres, chips, foco inicial em "Manter reserva", 422 tratados), aberto pela DetalheReserva e pela tela Pagamento; store test, view test, strings e comparação
- [ ] 4.9 Executar no app, com 2 celulares quando o caso pedir, os CT-16, CT-18, CT-19, CT-20, CT-22, CT-23, CT-25 (sem a notificação), CT-26 (cliente) e CT-27 (cliente) e registrar o resultado

## 5. Cache offline (S7–S8, até sex 23/10)

Responsável:
- B (C): banco, `quadra_cache`, sincronizador e métricas de MinhasQuadras;
- C (B): `reserva_cache`, conectividade, banner e `SincronizadorTest`, conforme docs/15 §15.5;
- D: QR offline;
- A: Perfil e logout.

Pronto quando:
- o roteiro do modo avião de docs/12 §12.6 passa tela a tela (CT-28);
- a tela Quadras abre do cache em build `--profile` sem esperar a rede;
- sair do app deixa as duas tabelas vazias (CT-06);
- reabrir o QR da pendente funciona sem rede.

- [ ] 5.1 Criar o `AppDatabase` com o DDL de design.md D11, `version` 1, `onUpgrade` e `onDowngrade` destrutivos e `limparTudo()`, e ligá-lo ao `EncerrarSessao`
- [ ] 5.2 Implementar o `QuadraCacheDao` e o mapeamento entre linha e entidade, com testes de mapeamento; [Should] `quadra_cache_dao_test.dart` com `sqflite_common_ffi` em memória provando que substituir `CATALOGO` não toca `MINHAS`
- [ ] 5.3 Implementar o `Sincronizador` e o `sincronizador_test.dart` (C), provando que a falha de rede não apaga o cache, que o sucesso substitui o escopo e marca a sincronização e que o servidor vence
- [ ] 5.4 Passar o `QuadraRepository` para cache primeiro (escopos `CATALOGO` e `MINHAS`, gravação depois das escritas, 404 removendo do escopo) sem mudar o contrato usado pelas telas
- [ ] 5.5 Implementar o `ReservaCacheDao` com a preservação das colunas de cobrança na substituição e `atualizarCobranca`, com testes de mapeamento; [Should] `reserva_cache_dao_test.dart` em memória
- [ ] 5.6 Passar o `ReservaRepository` e o `PagamentoRepository` para cache primeiro (`GET /reservas` sem `situacao`, gravação completa na criação, no detalhe, na edição e no cancelamento, status derivado na consulta do pagamento)
- [ ] 5.7 Implementar o `ConectividadeService` contra `/actuator/health`, o banner "Modo cache ativo", os selos de conectividade e os gatilhos de sincronização (abrir, puxar para atualizar, volta ao primeiro plano, volta da rede)
- [ ] 5.8 Aplicar o comportamento offline de cada tela conforme a spec `cache-offline` (escritas desabilitadas com o motivo, grade "Conecte-se para ver os horários", QR do cache na tela Pagamento, primeiro uso sem cache), cada titular na própria tela
- [ ] 5.9 Implementar as métricas de MinhasQuadras de design.md D14 (painel, reservas hoje, próxima, ocupação, "Fechada hoje", ordem "Mais ativas") com testes de cálculo e o view test atualizado
- [ ] 5.10 Calcular os contadores do Perfil a partir do cache ("Jogos" e "Arenas" do CLIENTE, "Quadras" e "Reservas" do DONO) com testes
- [ ] 5.11 Executar o CT-06 e o CT-28 em aparelho (modo avião, fechar e reabrir, voltar a rede) e registrar o resultado

## 6. ReservasQuadra do dono (S8, até sex 23/10)

Responsável: D (A), na fatia de C (US-33, docs/14 e docs/15). Pronto quando:
- o DONO do seed vê a reserva de amanhã com nome, telefone, status e valor, liga e abre o WhatsApp;
- o DONO cancela com motivo e o resumo do dia se recalcula;
- "Outro dia" consulta uma data passada online;
- CT-26 (dono) e CT-27 (dono) foram executados.

- [ ] 6.1 Implementar o resumo do dia de design.md D14 (agendadas e ocupação, aguardando e expiração, previsão) com testes
- [ ] 6.2 Construir ReservasQuadra a partir de `reservas_da_quadra_dono/code.html`, como aba e por quadra: faixa de datas do cache, "Outro dia" online com uma chamada por quadra, chips, cards com contato por `tel:` e `https://wa.me/55`, estados vazio, erro e offline; store test, view test, strings e comparação
- [ ] 6.3 Construir o sheet de cancelamento do dono (quatro motivos, "Outro motivo operacional" com texto de 5 a 200 caracteres, aviso de estorno só para `CONFIRMADA`, 422 tratados) com store test e view test
- [ ] 6.4 Executar o CT-26 (dono) e o CT-27 (dono) e a tarefa T6 de docs/22 em aparelho, e registrar o resultado

## 7. Geolocalização (S9, até sex 30/10) e notificação local (Should Have)

Responsável:
- C (B): geolocalização e `NotificadorReserva`;
- D: card "Ativar avisos" na tela Pagamento.

A notificação só começa com todos os itens Must verdes e sem defeito aberto (docs/16 §16.6, regra de ouro).
Pronto quando:
- a lista mostra "a X,X km" e ordena com a permissão concedida (precisa ou aproximada);
- a lista fica alfabética sem a permissão e funciona em emulador sem Google Play Services;
- "Abrir no Maps" e "Como chegar" abrem o app de mapas;
- CT-29 foi executado;
- se a notificação entrar, o CT-25 completo passa com permissão concedida e negada, e o toque abre a reserva
  com o app aberto e fechado.

- [ ] 7.1 Implementar o `LocalizacaoService` com a cadeia de fallback de design.md D16 e o fluxo de permissão (negada, negada permanentemente com abertura das configurações, reavaliação na volta ao primeiro plano), com testes usando o geolocator falso
- [ ] 7.2 Implementar Haversine, o formato da distância e a ordenação por proximidade com as quadras sem coordenadas no fim e desempate pelo nome; `geo_test.dart` e casos no `quadras_store_test.dart`
- [ ] 7.3 Ligar à tela Quadras o card de ativação de localização, a etiqueta de distância, a faixa "Quadras ordenadas por proximidade a você" com "Alterar" e o estado "Obtendo sua localização..."; atualizar o view test e a comparação
- [ ] 7.4 Ligar a pílula de distância e "Abrir no Maps" à DetalheQuadra, e "Como chegar" às reservas, com a URI `geo:`, o fallback pelo endereço e o snackbar "Nenhum app de mapas instalado"
- [ ] 7.5 Executar o CT-29 (precisa, aproximada, negada, sem fix, emulador AOSP sem Google Play Services) e registrar o resultado
- [ ] 7.6 [Should] Implementar o `NotificadorReserva` (inicialização no `main()`, canal `reservas`, ícone monocromático, detalhes de abertura pela notificação e destino pendente consumido pelo `redirect`)
- [ ] 7.7 [Should] Mostrar na tela Pagamento o card "Quer ser avisado quando o pagamento for confirmado?" (D), pedir `POST_NOTIFICATIONS` uma única vez e gravar `permissao_notificacao_pedida`
- [ ] 7.8 [Should] Notificar uma única vez na transição para `PAGO` respeitando `notificar_confirmacao`, com o caso no `pagamento_store_test.dart`, e executar o CT-25 completo

## 8. Qualidade e entrega (S9–S10, até o CP2 de sex 06/11)

Responsáveis: todos (cada titular nas próprias telas), com A na entrega dos APKs e D na organização dos CT.
Pronto quando:
- todas as views têm widget test com as três diretrizes de acessibilidade nos temas claro e escuro;
- o checklist de acessibilidade de docs/22 §11 não tem item vermelho em Login, Quadras, DetalheQuadra,
  Pagamento e FormQuadra;
- o APK release assinado está instalado em 2 celulares;
- pelo menos 90 % dos CT do app foram aprovados no mutirão;
- a tag `v0.2-beta` saiu em 04/11 com os APKs anexados.

- [ ] 8.1 Fazer a passagem de acessibilidade em cada tela (rótulos, 48 dp, fonte do sistema em 200 %, TalkBack, ordem de foco), com um commit do revisor por PR de tela (docs/15 §15.3)
- [ ] 8.2 Garantir um widget test por view com `androidTapTargetGuideline`, `labeledTapTargetGuideline` e `textContrastGuideline` nos dois temas, incluindo o rótulo "QR Code Pix, R$ 80,00"
- [ ] 8.3 Revisar as traduções en e es de todos os textos do protótipo e manter a paridade de chaves verde
- [ ] 8.4 Gerar o APK release assinado com `flutter build apk --release --dart-define-from-file=config/release.json`, com a keystore e o `key.properties` fora do Git, e conferir com `aapt dump badging` o pacote, a versão e as permissões
- [ ] 8.5 Instalar os APKs debug e release por `adb install -r` em 2 celulares, testar em API 26 e API 36, sem localização e com fonte em 200 %, e registrar o resultado
- [ ] 8.6 Executar no mutirão da S10 os CT do app (CT-01 a 03, 05 a 09, 11 a 14, 16, 18 a 20, 22, 23, 25 a 29 e 31), cada integrante na fatia de outro, com o resultado na planilha de execução
- [ ] 8.7 Corrigir os defeitos do bug bash cruzado até não restar nenhum de severidade 4, com os de severidade 3 com issue e responsável
- [ ] 8.8 Congelar `release/beta` na qua 04/11 e criar a tag `v0.2-beta` com `app-release.apk` e `app-debug.apk` anexados
