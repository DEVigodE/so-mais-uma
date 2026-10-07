# 06 — Requisitos não funcionais

Os 12 requisitos não funcionais (RNF01..RNF12) do app "Só mais uma": segurança, desempenho, disponibilidade, usabilidade, acessibilidade, compatibilidade Android, comunicação com a API, manutenibilidade, consistência e fuso horário — cada um com categoria, prioridade, descrição objetiva, forma de verificação e a limitação consciente aceita pelo grupo.

Atualizado em 06/10/2026: app passou de Android nativo (Kotlin + Compose) para Flutter (decisão do projeto). Nenhum RNF foi renumerado ou retirado; mudaram as evidências do lado do app (RNF03, RNF04, RNF06, RNF07, RNF08, RNF10, RNF11 e RNF12) e o token passou a ficar no armazenamento seguro (Android Keystore).

## Nível de exigência

Este é um projeto acadêmico de 15 semanas feito por 4 estudantes com cerca de 40 h/semana no total. Os RNFs abaixo foram calibrados para esse contexto: cada um precisa ser **verificável em menos de 1 minuto** na apresentação (um teste, um comando, uma tela) e **implementável em poucas dezenas de linhas**. Não há metas de escala (milhares de usuários), SLA contratual, auditoria de segurança externa nem conformidade formal com WCAG ou LGPD; onde uma prática de mercado ficou de fora, isso está registrado como "limitação consciente" para ser dito na banca em vez de descoberto por ela. A regra do brief vale aqui: constraint no banco antes de lock, polling antes de webhook, DI manual antes de framework.

## Visão geral

| RNF | Categoria | Prioridade | Critério da disciplina | Responsável (suplente) | Evidência principal |
|---|---|---|---|---|---|
| RNF01 | Segurança — autenticação | Must Have (N1) | 3 (autenticação), 6 | A (D) | `JwtServiceTest`, `AuthServiceTest`, Swagger 429 |
| RNF02 | Segurança — dados de pagamento | Must Have (N1) | 6 | D (A) | `V1__init.sql` (tabela `pagamento`), `.gitignore`, `PagamentoResponse` |
| RNF03 | Segurança — credenciais no app | Must Have (N1) | 3, 4 | A (D) | `sessao_store.dart`, logout em modo avião |
| RNF04 | Desempenho | Must Have (N2) | 6 | C (B) | tempo de `GET /quadras` no Render; abertura em modo avião |
| RNF05 | Disponibilidade | Must Have (N2) | 7 (execução) | A (D) / D | `/actuator/health`, kit de demo offline |
| RNF06 | Usabilidade | Must Have (N2) | 6 | C (B) | estados por tela, SUS ≥ 68 (docs/22) |
| RNF07 | Acessibilidade básica | Must Have (N2) | 6 | todos (revisor do PR) | checklist por tela, TalkBack |
| RNF08 | Compatibilidade Android | Must Have (N2) | 3, 5 | A (D) / C | `frontend/android/app/build.gradle.kts`, teste em API 26 e 36 |
| RNF09 | Comunicação com a API | Must Have (N1) | 2, 6 | A (D) | Swagger, `GlobalExceptionHandler`, `ProblemDetail` |
| RNF10 | Manutenibilidade | Must Have (N1) | 2, 7 | A (D) / B | árvore de pacotes, Flyway, CI, README |
| RNF11 | Consistência | Must Have (N2) | 4 | C (B) | `sincronizador.dart`, demo do 409 |
| RNF12 | Fuso horário | Must Have (N1) | 6 | C (B) | `FusoConfig`, `SlotServiceTest` |

Todos os doze são obrigatórios (Must Have); a marca entre parênteses diz **a partir de quando o requisito passa a valer**: "N1" vale desde a primeira entrega (segurança, contrato da API, manutenibilidade e fuso horário, que moldam o código desde o início) e "N2" passa a ser cobrado na segunda entrega, quando existe app rodando com backend publicado. Partes apenas **recomendadas** que convivem dentro de um requisito obrigatório são marcadas com **[REC]** no texto da ficha e não bloqueiam o aceite do RNF.

## Requisitos

### RNF01 — As senhas devem ter no mínimo 8 caracteres com letra e número e ser guardadas só como hash BCrypt, o acesso deve usar JWT HS256 de 7 dias e o login deve ser bloqueado por 15 minutos após 5 falhas

| Campo | Conteúdo |
|---|---|
| Categoria | Segurança (autenticação e sessão) |
| Descrição | Senha com **mínimo de 8 caracteres contendo ao menos uma letra e um número** (`@Pattern("^(?=.*[A-Za-z])(?=.*\\d).{8,}$")` em `RegistrarRequest` e na troca de senha); armazenada só como hash **BCrypt custo 10** (`senha_hash VARCHAR(72)`); token **JWT HS256 com validade de 7 dias** emitido por `NimbusJwtEncoder.withSecretKey` (`spring-security-oauth2-jose`, sem jjwt), claims `sub` = id do usuário e `perfil`; **`JWT_SECRET` com ≥ 32 bytes lido de variável de ambiente**, nunca do repositório; **bloqueio de login por 15 min após 5 falhas** consecutivas por e-mail (`LoginTentativasService`, resposta 429 `LOGIN_BLOQUEADO`, RF04); rotas protegidas devolvem 401 `TOKEN_INVALIDO` e o login inválido devolve 401 `CREDENCIAL_INVALIDA`, para o app distinguir sessão expirada de senha errada. `SecurityConfig` é stateless, CSRF desligado, `oauth2ResourceServer(jwt)`. |
| Verificação | `JwtServiceTest` (token válido, expirado, assinatura errada); `AuthServiceTest` (6ª tentativa → 429; contador zera no sucesso); `AuthControllerTest` (`@WebMvcTest`); no Swagger, `POST /quadras` com token CLIENTE → 403 e sem token → 401; `JwtConfig` falha no start (`IllegalStateException`) se `JWT_SECRET` tiver menos de 32 bytes — demonstrável subindo o backend sem a variável. |
| Limitação consciente | **Sem revogação nem refresh de JWT**: logout só apaga o token no dispositivo; um token copiado continua válido até 7 dias (aceito por ser um beta acadêmico, ver RNF03). Bloqueio de login em memória (`ConcurrentHashMap`): zera ao reiniciar o backend e não é compartilhado entre instâncias (há uma só). Sem recuperação de senha por e-mail (reset manual no banco durante o beta) e sem rate limit no cadastro. |

### RNF02 — O sistema não deve armazenar dados do pagador nem de cartão, guardando apenas os campos públicos da cobrança Pix, e os segredos e certificados devem viver só em variáveis de ambiente

| Campo | Conteúdo |
|---|---|
| Categoria | Segurança (dados sensíveis e segredos) |
| Descrição | O sistema **nunca armazena dados do pagador** (CPF/CNPJ, nome, `infoPagador`, `devedor`, `componentesValor`, dados bancários, chave Pix do cliente) nem dados de cartão (não existe cartão no MVP). A tabela `pagamento` guarda somente `txid`, `provedor`, `valor`, `status`, `pix_copia_e_cola`, `location`, `end_to_end_id`, `expira_em`, `pago_em` e timestamps. A cobrança é criada **sem o campo `devedor`**. Segredos e certificados (`INTER_CLIENT_ID`, `INTER_CLIENT_SECRET`, `INTER_CRT`, `INTER_KEY`, `INTER_CHAVE_PIX`, `JWT_SECRET`, `DEV_KEY`) vivem só em variáveis de ambiente ou Secret Files do Render; `.gitignore` do primeiro commit contém `*.crt`, `*.key`, `*.pfx`, `.env`. O webhook (recomendado) valida `txid` existente + status PENDENTE + `valor` igual ao da cobrança e ignora todos os outros campos do array do Inter. |
| Verificação | `V1__init.sql` não tem coluna de CPF/nome de pagador; `grep -ri "cpf\|devedor\|infoPagador" backend/src/main` devolve apenas o comentário do DTO que descarta o campo; `git log --all -- '*.crt' '*.key' '.env'` vazio; `PagamentoResponse` e `ReservaResponse` (visão do dono) inspecionados no Swagger não expõem dados do pagador (RN05); `InterWebhookControllerTest` com o array oficial de exemplo do Inter mostra que `infoPagador` é descartado. |
| Limitação consciente | `pix_copia_e_cola` e `location` são armazenados porque são dados públicos de cobrança (necessários para reabrir o QR offline, RF23). O endpoint de webhook não faz mTLS de entrada nem allowlist dos IPs do Inter (configurar client-auth no Tomcat/Render é desproporcional para o TCC; a proteção é a validação de `txid`/status/valor + idempotência). Se um segredo vazar no Git, a integração Inter é cancelada e recriada (risco R15 em docs/19-riscos.md). |

### RNF03 — O token de sessão deve ficar no armazenamento seguro do app (flutter_secure_storage, Android Keystore), a senha nunca deve ser salva no dispositivo e o logout ou um 401 deve apagar token, preferências e todo o cache

| Campo | Conteúdo |
|---|---|
| Categoria | Segurança (app Flutter no Android) |
| Descrição | O token JWT (`token_jwt`) fica no **flutter_secure_storage 11.2.0**, cifrado com chave do **Android Keystore**; os demais dados de sessão (`token_expira_em`, `usuario_id`, `usuario_nome`, `usuario_perfil`) e as preferências ficam no **shared_preferences 2.5.6** (`SharedPreferencesAsync`). Os dois ficam atrás do `SessaoStore` (`lib/data/local/sessao_store.dart`), dentro do sandbox privado do app. **A senha nunca é salva** no dispositivo (nem no `SessaoStore`, nem no drift, nem em log). O logout (`Perfil` → Sair) e qualquer 401 `TOKEN_INVALIDO` executam `SessaoStore.limpar()` e `AppDatabase.limparTudo()`, apagando token, preferências e todo o cache. O `Splash` decide a rota lendo `token_expira_em` localmente (sem chamada de rede). |
| Verificação | Inspeção de `sessao_store.dart` (nenhuma chave `senha`; só `token_jwt` vai para o flutter_secure_storage); após "Sair", a extensão drift do Flutter DevTools (ou o arquivo `somaisuma.sqlite` copiado do aparelho com `adb`, via `run-as br.com.somaisuma.app.debug`) mostra `quadra_cache` e `reserva_cache` sem linhas e o app reaberto vai para `Login`; `LoginViewModelTest` prova que o campo senha não é persistido; teste manual: sair em modo avião funciona sem rede. |
| Limitação consciente | Só o token é cifrado: as demais chaves do shared_preferences (nome, perfil, datas de sincronização, última coordenada) ficam em texto claro no sandbox do app. Guardar o token no Keystore é uma melhoria em relação ao texto claro do DataStore usado até 06/10/2026, mas em dispositivo com root ele ainda pode ser recuperado por quem executar código como o app — e, combinado com a **ausência de revogação** (RNF01), um token copiado continua válido por até 7 dias; esse continua sendo o principal risco de segurança conhecido do MVP, aceito e documentado. Biometria para reabrir o app é Could Have (`local_auth`). |

### RNF04 — As listagens devem responder em menos de 2 segundos com o backend aquecido, e as telas de consulta devem abrir a partir do cache local

| Campo | Conteúdo |
|---|---|
| Categoria | Desempenho e responsividade |
| Descrição | Listagens (`GET /quadras`, `GET /reservas`, `GET /quadras/{id}/slots`) respondem em **menos de 2 s** em rede móvel normal com o backend aquecido; telas de consulta abrem **instantaneamente** a partir do cache drift (`Stream` do `.watch()` assinado pelo ViewModel) enquanto a sincronização roda em segundo plano; polling de pagamento a **cada 5 s nos 2 primeiros minutos e depois a cada 10 s** (backoff simples), só enquanto a tela `Pagamento` está visível (`Timer` do ViewModel pausado/retomado por `AppLifecycleListener` e cancelado no `dispose()`); o `ConsultaPagamentoJob` consulta no máximo 10 cobranças por ciclo de 60 s (10 chamadas/min, bem abaixo do limite de 120/min do Inter) e pula o ciclo em 429; token OAuth do Inter cacheado por 55 min (limite de 5 chamadas/min no endpoint de token). Sem paginação porque as listas são pequenas (dezenas de linhas). |
| Verificação | `curl -w "%{time_total}"` em `GET /api/v1/quadras` no Render aquecido, registrado em docs/23-plano-de-testes.md (meta < 2 s); abertura de `Quadras` em modo avião medida a olho (< 1 s) sempre em build `--profile` ou `--release` (o modo debug roda em JIT e é bem mais lento, então não vale como medida); log do app mostra o intervalo do polling mudando de 5 s para 10 s após 2 min; `PagamentoViewModelTest` cobre o backoff; índices `idx_quadra_dono`, `idx_reserva_cliente`, `idx_reserva_quadra_inicio` presentes em `V1__init.sql`. |
| Limitação consciente | Primeiro acesso após inatividade no plano gratuito do Render leva 30–60 s (cold start): mitigado aquecendo `/actuator/health` 10 min antes de qualquer demo e, se incomodar, plano Starter em nov–dez. Não há testes de carga; o dimensionamento é o pool padrão do Hikari (10 conexões), suficiente para o `ReservaConcorrenciaIT` de 10 threads e para os poucos usuários do beta. |

### RNF05 — O backend beta deve estar no ar em horário comercial nas datas de teste com usuários e de avaliação, com um kit de demo offline ensaiado como plano B

| Campo | Conteúdo |
|---|---|
| Categoria | Disponibilidade e operação |
| Descrição | O backend beta (Render Web Service Docker + Neon PostgreSQL, deploy em S9, 26–30/10) precisa estar no ar **em horário comercial nos dias de testes com usuários (09–13/11), Checkpoint 2 (06/11) e Apresentação N2 (07–11/12)**. O sandbox Pix do Inter só funciona **das 8h às 20h, de segunda a sexta**; fora disso o profile `inter-sandbox` responde 502 `PAGAMENTO_INDISPONIVEL` na criação e o job registra `INFO` e pula o ciclo sem alterar status. Existe um **kit de demo offline** (jar do backend + `postgres:18-alpine` no Docker do notebook + hotspot do celular + APK debug apontando para o IP do notebook, profile `simulado`) ensaiado em S12/S13 como plano B único, além de um vídeo de backup. O profile é trocado por variável de ambiente sem rebuild (`SPRING_PROFILES_ACTIVE`). |
| Verificação | `GET /actuator/health` → `{"status":"UP"}` no Render; checklist do dia da apresentação em docs/18-checklist-n2.md (health 10 min antes, sandbox no horário senão `simulado`, celulares instalados via `adb`, hotspot); ensaio do kit offline registrado com data em docs/16-cronograma.md. |
| Limitação consciente | Sem SLA, sem monitoramento, sem réplica: a "disponibilidade" é operacional (alguém aquece o serviço). Fora de horário comercial o beta pode estar dormindo e o sandbox fechado; demos são agendadas em dia útil entre 8h e 20h. Certificado sandbox vale 30 dias e é renovado em 29/09, 27/10 e 24/11 (responsável D, suplente A). |

### RNF06 — Toda tela com dados remotos deve ter os estados de carregando, vazio e erro, com validação por campo e mensagens em português acionável, atingindo SUS ≥ 68 e ≥ 80 % de sucesso por tarefa

| Campo | Conteúdo |
|---|---|
| Categoria | Usabilidade |
| Descrição | **Toda tela com dados remotos tem os três estados**: carregando (`CarregandoBox`), vazio (`VazioBox` com texto orientando a próxima ação) e erro (`ErroBox` com "Tentar novamente"); formulários validam **por campo** (`CampoTextoValidado`, mensagens abaixo do campo, `TextInputAction.next`), espelhando o Bean Validation do backend e exibindo `campos[]` do `ProblemDetail`; mensagens de erro em português claro e acionável ("Esse horário acabou de ser reservado. Escolha outro." em vez de "409"); ações destrutivas (cancelar reserva, desativar quadra) pedem confirmação em diálogo; a tela `Pagamento` mostra contador regressivo e o estado "Aguardando / Pago / Expirado"; offline é comunicado por `BannerOffline` com a data da última sincronização. Meta de aceite nos testes com usuários: **SUS ≥ 68 e ≥ 80 % de sucesso por tarefa** (6 tarefas, 5–8 usuários, 09–13/11). |
| Verificação | Checklist de estados por tela em docs/04-telas.md marcado no PR de cada tela; `FakeApiClient` permite forçar os três estados no emulador e nos widget tests das Screens; resultado do SUS e taxa de sucesso por tarefa em docs/22-testes-com-usuarios.md; top-5 problemas corrigidos em S12 antes do congelamento (27/11), aprovados por C. |
| Limitação consciente | Sem teste com especialista em UX nem redesign amplo depois do beta: apenas as 5 correções de maior severidade entram. Tema escuro existe (`ThemeData` escuro com `ColorScheme` explícito; o Flutter não usa dynamic color sem pacote extra, então a demo fica previsível), mas não há personalização adicional. |

### RNF07 — As 13 telas devem ter rótulo semântico (Semantics) em ícones e imagens com função, alvos de toque de no mínimo 48 dp e uso correto com TalkBack e fonte do sistema a 200 %

| Campo | Conteúdo |
|---|---|
| Categoria | Acessibilidade |
| Descrição | Rótulo semântico em todo ícone e imagem com função — `Semantics(label: ...)`, `semanticLabel` em `Icon`/`Image`, `tooltip` em `IconButton` (inclusive no QR: "QR Code Pix, R$ 80,00"); **alvos de toque ≥ 48 dp** lógicos (`kMinInteractiveDimension`, `MaterialTapTargetSize.padded`); textos escalados pelo `TextScaler` do sistema (`MediaQuery.textScalerOf`) e layout que continua utilizável com **fonte do sistema a 200 %**; contraste das cores do tema Material 3 (`ThemeData` claro e escuro com `ColorScheme` explícito) sem cores customizadas abaixo do contraste padrão; foco e leitura corretos com **TalkBack** nas 13 telas; estados de erro comunicados por texto, não apenas por cor. |
| Verificação | Checklist de acessibilidade por tela preenchido pelo revisor do PR (cada PR de tela recebe 1 commit do revisor com ajustes de acessibilidade); sessão de TalkBack + fonte 200 % nas 13 telas registrada em docs/22-testes-com-usuarios.md em S10 (antes do CP2); widget tests das Screens com `meetsGuideline(androidTapTargetGuideline)`, `meetsGuideline(labeledTapTargetGuideline)` e `meetsGuideline(textContrastGuideline)`, e o Widget Inspector do Flutter DevTools para alvos < 48 dp. |
| Limitação consciente | Não há auditoria formal WCAG/ABNT NBR 17060 nem teste com pessoas com deficiência; o alvo é "básica" como pede o critério 6. |

### RNF08 — O app deve rodar de minSdk 26 ao targetSdk definido pelo Flutter (36 no 3.47.6) e continuar funcionando de forma degradada sem Google Play Services e sem permissão de localização

| Campo | Conteúdo |
|---|---|
| Categoria | Compatibilidade e portabilidade |
| Descrição | **`minSdk 26`** (Android 8.0, cobre ~95 % dos dispositivos ativos e permite `NotificationChannel` sem fallback), fixado em `frontend/android/app/build.gradle.kts`, e **`targetSdk`/`compileSdk` herdados do Flutter** (`flutter.targetSdkVersion`/`flutter.compileSdkVersion`, **36** no Flutter 3.47.6, Android 16; o flutter_local_notifications exige compileSdk ≥ 36). Permissões de runtime pedidas no contexto certo: `ACCESS_COARSE_LOCATION` + `ACCESS_FINE_LOCATION` juntas via `Geolocator.requestPermission()` (Android 12+ deixa o usuário escolher precisão; o app funciona com aproximada, `LocationAccuracy.medium`) e `POST_NOTIFICATIONS` (API 33+) na primeira abertura de `Pagamento`; sem `ACCESS_BACKGROUND_LOCATION`; todas declaradas em `frontend/android/app/src/main/AndroidManifest.xml`. O app **funciona sem Google Play Services** (o geolocator cai para o `LocationManager` do Android; se ainda assim não houver posição, o `LocalizacaoService` segue a cadeia de fallback e devolve `null` sem lançar exceção, e a lista fica sem distância) e **sem localização** (permissão negada → ordem alfabética). Distribuição por `adb install` do APK release assinado (a verificação de desenvolvedor do Google vigora no Brasil desde 30/09/2026 e pode travar o sideload por navegador; `adb` não é afetado); publicação na Play Store fora do MVP. |
| Verificação | `frontend/android/app/build.gradle.kts` com `minSdk = 26` e `targetSdk = flutter.targetSdkVersion` (36 no Flutter 3.47.6); execução em emulador API 26 e API 36 e em 2 celulares físicos (registrado em docs/23-plano-de-testes.md); teste "negar localização" e "emulador sem GMS" (imagem AOSP) mostram a lista sem crash (com distância se o `LocationManager` obtiver posição, sem distância caso contrário); `adb install app-release.apk` testado em S9 em 2 celulares. |
| Limitação consciente | Não há testes em tablets, dobráveis, Wear ou Android TV; orientação retrato apenas; sem suporte a idiomas além de pt-BR; sem Play Store (conta de distribuição limitada do Google avaliada em S9 apenas como alternativa). |

### RNF09 — O app deve falar com um único backend em `/api/v1` sobre HTTPS, com datas ISO-8601 com offset e erros em `ProblemDetail`, e o contrato só pode mudar de forma aditiva após a N1

| Campo | Conteúdo |
|---|---|
| Categoria | Interoperabilidade e contrato |
| Descrição | Um único backend, prefixo **`/api/v1`**, JSON em camelCase, autenticação `Authorization: Bearer <jwt>`; **HTTPS em todo ambiente fora do desenvolvimento** (Render fornece TLS; cleartext só para `10.0.2.2`/IP da LAN em build debug, via `android:usesCleartextTraffic="true"` apenas em `frontend/android/app/src/debug/AndroidManifest.xml`); **datas ISO-8601 com offset** (`2026-10-10T19:00:00-03:00`), valores monetários como string decimal (`"80.00"`), ids `Long` (`int` de 64 bits no Dart); **erros como `ProblemDetail` RFC 9457** com campo extra `codigo` (enum `CodigoErro`) e `campos[]` na validação, gerados pelo `GlobalExceptionHandler`; contrato publicado pelo springdoc 3.1.0 (`/swagger-ui.html`, desligado em `inter-prod`); **após a N1 o contrato só recebe mudanças aditivas** (campos novos opcionais; nada é removido ou renomeado) para o APK instalado nos celulares de teste continuar funcionando. O app nunca fala com Inter ou BrasilAPI diretamente (RNF02). |
| Verificação | Swagger acessível e coerente com docs/10-api-rest.md; `ProblemDetailParser` no app converte qualquer erro em `Resultado.Erro(codigo)` (teste unitário); `git diff v0.1-n1..main -- backend/src/main/java/**/dto` revisado no PR para provar que só houve adições; `curl -i` mostra 401 em rota protegida sem token e 400 com `campos[]` em `POST /quadras` inválido. |
| Limitação consciente | Sem versionamento real além do prefixo (`/v2` não está previsto), sem paginação, sem cache HTTP/ETag, sem compressão configurada. Cleartext HTTP existe apenas em build debug apontando para a LAN. |

### RNF10 — O código deve seguir camadas explícitas com versões fixadas e migrations Flyway aditivas, e todo PR deve passar pelo CI com aprovação do suplente, mantendo o README executável em máquina limpa

| Campo | Conteúdo |
|---|---|
| Categoria | Manutenibilidade e processo |
| Descrição | Backend em camadas explícitas (`controller/service/repository/entity/dto/exception/config/security/integracao`), com a regra "controller valida e converte DTO; service tem regra e `@Transactional`; repository só JPA; entity nunca sai do controller"; app Flutter em MVVM + Repository (`ui → ViewModel (ChangeNotifier) → Repository → ApiClient \| Dao \| SessaoStore`) com DI pelo pacote `provider` (lista de providers montada à mão em `lib/config/dependencias.dart`, sem framework de DI); **migrations Flyway aditivas** (`V1__init.sql` nunca editado após a N1; mudanças em `V3+`); **versões fixadas** no `frontend/pubspec.yaml` + `frontend/pubspec.lock` versionado (app, com Flutter 3.47.6 igual em todas as máquinas e no CI) e no `build.gradle.kts` do backend, com tabela de versões verificada em 01/09/2026 no README (versões do app reverificadas em 06/10/2026); **CI GitHub Actions** rodando `./gradlew test` do backend (Testcontainers) e, no job `frontend`, `flutter analyze`, `flutter test` e `flutter build apk --debug` em todo PR; PR < 400 linhas com 1 aprovação do suplente e ninguém mergeia o próprio PR; **README executável** (`docker compose up -d`, `./gradlew bootRun`; no app, `flutter pub get`, `dart run build_runner build --delete-conflicting-outputs` e `flutter run --dart-define-from-file=config/dev.json`) testado em máquina limpa por outro integrante antes da N1. Testes automatizados mínimos por fatia: unitários de service, `@WebMvcTest` de controller, `ReservaConcorrenciaIT`, testes de ViewModel com fakes (`flutter test`). |
| Verificação | Árvore de pacotes no repositório; `git log --oneline -- backend/src/main/resources/db/migration/V1__init.sql` sem commits após a tag `v0.1-n1`; badge/histórico verde do CI; README seguido do zero por um integrante que não o escreveu (registrado na issue); `git shortlog -sn --no-merges -- backend frontend docs` mostrando os 4 integrantes nas 3 pastas. |
| Limitação consciente | Sem cobertura mínima obrigatória, sem testes E2E de UI em CI (`integration_test` é opcional e roda só em emulador local), sem análise estática além do lint padrão (`flutter analyze` com `flutter_lints` no app), sem ambiente de staging separado do beta. O drift recria as tabelas no `onUpgrade` da `MigrationStrategy` (sem migrations escritas) porque é cache: mudança de `schemaVersion` recria o banco local e o próximo sync o repovoa. |

### RNF11 — As escritas devem exigir rede e ir direto ao backend, e as leituras devem vir do cache local (drift) substituído por escopo a cada sincronização, com o servidor como única verdade

| Campo | Conteúdo |
|---|---|
| Categoria | Consistência de dados |
| Descrição | **Escritas somente online**: reservar, pagar, cancelar, editar quadra/horário/perfil exigem rede e vão direto ao backend; sucesso é gravado no drift (write-through) e a lista é re-sincronizada. **Leituras com cache**: a UI observa o drift (via `Stream` assinado pelo ViewModel) e o `Sincronizador` substitui o escopo inteiro (`CATALOGO`/`MINHAS`/`QUADRA`) com a resposta do servidor — linha ausente no servidor é apagada localmente. **A verdade é o servidor**: a grade de slots é "melhor esforço" e a exclusividade real é o 409 do índice único parcial (RN08); slots não vão para o cache justamente para um slot "livre" velho não induzir reserva errada. Sem fila offline, sem tarefa em segundo plano (WorkManager ou equivalente), sem merge de conflitos, porque o app nunca edita localmente. Confirmação de pagamento e expiração usam `UPDATE` condicional (idempotentes) — ver docs/07-regras-de-negocio.md. |
| Verificação | Demo em modo avião: botões de escrita desabilitados e `BannerOffline`; ao reconectar, uma reserva cancelada pelo dono no servidor desaparece de `MinhasReservas`; `SincronizadorTest` (fake de API devolvendo lista menor apaga linhas locais); demo dos 2 celulares no mesmo slot com 409. |
| Limitação consciente | Uma ação iniciada sem rede simplesmente não acontece (não é enfileirada); o usuário precisa repetir quando reconectar. Slot mostrado como LIVRE pode já estar ocupado no instante do toque — o 409 e a recarga automática da grade resolvem. |

### RNF12 — Todo cálculo de horário, slot, janela de reserva e prazo de cancelamento deve usar a zona `America/Sao_Paulo`, com instantes em `TIMESTAMPTZ` e conversão do offset recebido

| Campo | Conteúdo |
|---|---|
| Categoria | Corretude de tempo |
| Descrição | Todo cálculo de "hora cheia", horário de funcionamento, slot, janela de reserva (hoje+14) e prazo de cancelamento (2 h antes) usa a zona **`America/Sao_Paulo`**, definida em `FusoConfig` (propriedade `app.fuso-horario`). Colunas `TIMESTAMPTZ` guardam instantes; `horario_funcionamento.hora_abertura/hora_fechamento` são `TIME` interpretados nessa zona; o app envia a data ISO-8601 com offset (`-03:00`) e o backend converte com `atZoneSameInstant(FUSO)` antes de validar. O app formata datas com `formatadores.dart` (intl) no mesmo fuso, usando deslocamento fixo UTC-3, porque o Dart só conhece UTC e o fuso local do aparelho. |
| Verificação | `SlotServiceTest` com casos de meia-noite, limite hoje+14 e reserva enviada com offset diferente de -03:00 (deve cair no mesmo slot); teste de `POST /reservas` com `inicio` `19:30` → 400; conferência visual de que 19:00 na tela é 19:00 no banco (`select inicio at time zone 'America/Sao_Paulo'`). |
| Limitação consciente | Quadras em UF com offset diferente (AM, AC, MS, MT, RR, RO) ficam fora do MVP: não há coluna de fuso por quadra (decisão registrada em docs/09-arquitetura.md). O Brasil não tem horário de verão em 2026, mas a zona `America/Sao_Paulo` já trata isso se voltar no backend; no app, o deslocamento fixo UTC-3 teria de ser trocado pelo pacote `timezone`. |

## Rastreabilidade RNF → onde é evidenciado

| RNF | Código / artefato | Documento que detalha |
|---|---|---|
| RNF01 | `security/JwtService`, `LoginTentativasService`, `config/JwtConfig`, `RegistrarRequest` | docs/03-perfis-e-permissoes.md, docs/09-arquitetura.md |
| RNF02 | `V1__init.sql` (tabela `pagamento`), `.gitignore`, `InterWebhookController`, `application-inter-*.yml` | docs/11-integracao-pix-inter.md, docs/08-modelagem-banco.md |
| RNF03 | `lib/data/local/sessao_store.dart`, `AuthInterceptor` | docs/12-persistencia-local.md |
| RNF04 | índices em `V1__init.sql`, `PagamentoViewModel` (backoff), `ConsultaPagamentoJob` | docs/11-integracao-pix-inter.md, docs/23-plano-de-testes.md |
| RNF05 | `Dockerfile`, Render/Neon, `scripts/`, kit offline | docs/09-arquitetura.md, docs/18-checklist-n2.md, docs/19-riscos.md |
| RNF06 | `lib/ui/componentes/*_box.dart`, `CampoTextoValidado`, SUS | docs/04-telas.md, docs/22-testes-com-usuarios.md |
| RNF07 | checklist por tela, `Semantics`, widget tests com `meetsGuideline`, TalkBack | docs/04-telas.md, docs/22-testes-com-usuarios.md |
| RNF08 | `frontend/android/app/build.gradle.kts`, `AndroidManifest.xml`, `LocalizacaoService` | docs/13-recurso-nativo.md, docs/21-git-e-organizacao.md |
| RNF09 | `GlobalExceptionHandler`, `CodigoErro`, springdoc | docs/10-api-rest.md |
| RNF10 | árvore de pacotes, Flyway, `pubspec.yaml` + `pubspec.lock`, CI, README | docs/09-arquitetura.md, docs/21-git-e-organizacao.md, README.md |
| RNF11 | `sincronizador.dart`, `ux_reserva_slot_ativo` | docs/12-persistencia-local.md, docs/07-regras-de-negocio.md |
| RNF12 | `FusoConfig`, `SlotService`, `formatadores.dart` | docs/07-regras-de-negocio.md (RN06), docs/08-modelagem-banco.md |
