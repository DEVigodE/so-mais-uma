# 06 — Requisitos não funcionais

Os 12 requisitos não funcionais (RNF01..RNF12) do app "Só mais uma": segurança, desempenho, disponibilidade, usabilidade, acessibilidade, compatibilidade Android, comunicação com a API, manutenibilidade, consistência e fuso horário — cada um com categoria, prioridade, descrição objetiva, forma de verificação e a limitação consciente aceita pelo grupo.

## Nível de exigência

Este é um projeto acadêmico de 15 semanas feito por 4 estudantes com cerca de 40 h/semana no total. Os RNFs abaixo foram calibrados para esse contexto: cada um precisa ser **verificável em menos de 1 minuto** na apresentação (um teste, um comando, uma tela) e **implementável em poucas dezenas de linhas**. Não há metas de escala (milhares de usuários), SLA contratual, auditoria de segurança externa nem conformidade formal com WCAG ou LGPD; onde uma prática de mercado ficou de fora, isso está registrado como "limitação consciente" para ser dito na banca em vez de descoberto por ela. A regra do brief vale aqui: constraint no banco antes de lock, polling antes de webhook, DI manual antes de framework.

## Visão geral

| RNF | Categoria | Prioridade | Critério da disciplina | Responsável (suplente) | Evidência principal |
|---|---|---|---|---|---|
| RNF01 | Segurança — autenticação | Must Have (N1) | 3 (autenticação), 6 | A (D) | `JwtServiceTest`, `AuthServiceTest`, Swagger 429 |
| RNF02 | Segurança — dados de pagamento | Must Have (N1) | 6 | D (A) | `V1__init.sql` (tabela `pagamento`), `.gitignore`, `PagamentoResponse` |
| RNF03 | Segurança — credenciais no app | Must Have (N1) | 3, 4 | A (D) | `SessaoDataStore.kt`, logout em modo avião |
| RNF04 | Desempenho | Must Have (N2) | 6 | C (B) | tempo de `GET /quadras` no Render; abertura em modo avião |
| RNF05 | Disponibilidade | Must Have (N2) | 7 (execução) | A (D) / D | `/actuator/health`, kit de demo offline |
| RNF06 | Usabilidade | Must Have (N2) | 6 | C (B) | estados por tela, SUS ≥ 68 (docs/22) |
| RNF07 | Acessibilidade básica | Must Have (N2) | 6 | todos (revisor do PR) | checklist por tela, TalkBack |
| RNF08 | Compatibilidade Android | Must Have (N2) | 3, 5 | A (D) / C | `build.gradle.kts`, teste em API 26 e 37 |
| RNF09 | Comunicação com a API | Must Have (N1) | 2, 6 | A (D) | Swagger, `GlobalExceptionHandler`, `ProblemDetail` |
| RNF10 | Manutenibilidade | Must Have (N1) | 2, 7 | A (D) / B | árvore de pacotes, Flyway, CI, README |
| RNF11 | Consistência | Must Have (N2) | 4 | C (B) | `Sincronizador.kt`, demo do 409 |
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

### RNF03 — O token de sessão deve ficar no DataStore privado do app, a senha nunca deve ser salva no dispositivo e o logout ou um 401 deve apagar token, preferências e todo o cache

| Campo | Conteúdo |
|---|---|
| Categoria | Segurança (cliente Android) |
| Descrição | O token JWT e os dados de sessão (`token_jwt`, `token_expira_em`, `usuario_id`, `usuario_nome`, `usuario_perfil`) ficam em **DataStore Preferences** (`SessaoDataStore`, `datastore-preferences 1.2.1`), dentro do sandbox privado do app. **A senha nunca é salva** no dispositivo (nem em DataStore, nem em Room, nem em log). O logout (`Perfil` → Sair) e qualquer 401 `TOKEN_INVALIDO` executam `SessaoDataStore.clear()` e `AppDatabase.clearAllTables()`, apagando token, preferências e todo o cache. O `Splash` decide a rota lendo `token_expira_em` localmente (sem chamada de rede). |
| Verificação | Inspeção de `SessaoDataStore.kt` (nenhuma chave `senha`); após "Sair", `adb shell run-as br.com.somaisuma.app ls files/datastore` mostra o arquivo vazio/recriado e `somaisuma.db` sem linhas; `LoginViewModelTest` prova que o campo senha não é persistido; teste manual: sair em modo avião funciona sem rede. |
| Limitação consciente | DataStore não é criptografado (a `EncryptedSharedPreferences` foi depreciada e o valor é o sandbox do sistema por app); em dispositivo com root o token de 7 dias pode ser lido — combinado com a ausência de revogação (RNF01), esse é o principal risco de segurança conhecido do MVP, aceito e documentado. Biometria para reabrir o app é Could Have. |

### RNF04 — As listagens devem responder em menos de 2 segundos com o backend aquecido, e as telas de consulta devem abrir a partir do cache local

| Campo | Conteúdo |
|---|---|
| Categoria | Desempenho e responsividade |
| Descrição | Listagens (`GET /quadras`, `GET /reservas`, `GET /quadras/{id}/slots`) respondem em **menos de 2 s** em rede móvel normal com o backend aquecido; telas de consulta abrem **instantaneamente** a partir do cache Room (`Flow` observado pela UI) enquanto a sincronização roda em segundo plano; polling de pagamento a **cada 5 s nos 2 primeiros minutos e depois a cada 10 s** (backoff simples), só enquanto a tela `Pagamento` está visível (`repeatOnLifecycle(STARTED)`); o `ConsultaPagamentoJob` consulta no máximo 10 cobranças por ciclo de 60 s (10 chamadas/min, bem abaixo do limite de 120/min do Inter) e pula o ciclo em 429; token OAuth do Inter cacheado por 55 min (limite de 5 chamadas/min no endpoint de token). Sem paginação porque as listas são pequenas (dezenas de linhas). |
| Verificação | `curl -w "%{time_total}"` em `GET /api/v1/quadras` no Render aquecido, registrado em docs/23-plano-de-testes.md (meta < 2 s); abertura de `Quadras` em modo avião medida a olho (< 1 s); log do app mostra o intervalo do polling mudando de 5 s para 10 s após 2 min; `PagamentoViewModelTest` cobre o backoff; índices `idx_quadra_dono`, `idx_reserva_cliente`, `idx_reserva_quadra_inicio` presentes em `V1__init.sql`. |
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
| Descrição | **Toda tela com dados remotos tem os três estados**: carregando (`CarregandoBox`), vazio (`VazioBox` com texto orientando a próxima ação) e erro (`ErroBox` com "Tentar novamente"); formulários validam **por campo** (`CampoTextoValidado`, mensagens abaixo do campo, `ImeAction.Next`), espelhando o Bean Validation do backend e exibindo `campos[]` do `ProblemDetail`; mensagens de erro em português claro e acionável ("Esse horário acabou de ser reservado. Escolha outro." em vez de "409"); ações destrutivas (cancelar reserva, desativar quadra) pedem confirmação em diálogo; a tela `Pagamento` mostra contador regressivo e o estado "Aguardando / Pago / Expirado"; offline é comunicado por `BannerOffline` com a data da última sincronização. Meta de aceite nos testes com usuários: **SUS ≥ 68 e ≥ 80 % de sucesso por tarefa** (6 tarefas, 5–8 usuários, 09–13/11). |
| Verificação | Checklist de estados por tela em docs/04-telas.md marcado no PR de cada tela; `FakeApiService` permite forçar os três estados no emulador; resultado do SUS e taxa de sucesso por tarefa em docs/22-testes-com-usuarios.md; top-5 problemas corrigidos em S12 antes do congelamento (27/11), aprovados por C. |
| Limitação consciente | Sem teste com especialista em UX nem redesign amplo depois do beta: apenas as 5 correções de maior severidade entram. Tema escuro existe (`darkColorScheme` explícito, dynamic color desligado para a demo ficar previsível), mas não há personalização adicional. |

### RNF07 — As 13 telas devem ter contentDescription em ícones e imagens com função, alvos de toque de no mínimo 48 dp e uso correto com TalkBack e fonte do sistema a 200 %

| Campo | Conteúdo |
|---|---|
| Categoria | Acessibilidade |
| Descrição | `contentDescription` em todo ícone e imagem com função (inclusive no QR: "QR Code Pix, R$ 80,00"); **alvos de toque ≥ 48 dp**; textos em `sp` e layout que continua utilizável com **fonte do sistema a 200 %**; contraste das cores do tema Material 3 (`lightColorScheme`/`darkColorScheme`) sem cores customizadas abaixo do contraste padrão; foco e leitura corretos com **TalkBack** nas 13 telas; estados de erro comunicados por texto, não apenas por cor. |
| Verificação | Checklist de acessibilidade por tela preenchido pelo revisor do PR (cada PR de tela recebe 1 commit do revisor com ajustes de acessibilidade); sessão de TalkBack + fonte 200 % nas 13 telas registrada em docs/22-testes-com-usuarios.md em S10 (antes do CP2); inspeção com o Layout Inspector para alvos < 48 dp. |
| Limitação consciente | Não há auditoria formal WCAG/ABNT NBR 17060 nem teste com pessoas com deficiência; o alvo é "básica" como pede o critério 6. |

### RNF08 — O app deve rodar de minSdk 26 a targetSdk 37 e continuar funcionando de forma degradada sem Google Play Services e sem permissão de localização

| Campo | Conteúdo |
|---|---|
| Categoria | Compatibilidade e portabilidade |
| Descrição | **`minSdk 26`** (Android 8.0, cobre ~95 % dos dispositivos ativos e permite `NotificationChannel` sem fallback) e **`targetSdk = compileSdk = 37`** (Android 17; Compose BOM 2026.08.00 exige compileSdk 37). Permissões de runtime pedidas no contexto certo: `ACCESS_COARSE_LOCATION` + `ACCESS_FINE_LOCATION` juntas (Android 12+ deixa o usuário escolher precisão; o app funciona com aproximada) e `POST_NOTIFICATIONS` (API 33+) na primeira abertura de `Pagamento`; sem `ACCESS_BACKGROUND_LOCATION`. O app **funciona de forma degradada sem Google Play Services** (`LocalizacaoProvider` devolve `null` via `runCatching`; lista sem distância) e **sem localização** (permissão negada → ordem alfabética). Distribuição por `adb install` do APK release assinado (a verificação de desenvolvedor do Google vigora no Brasil desde 30/09/2026 e pode travar o sideload por navegador; `adb` não é afetado); publicação na Play Store fora do MVP. |
| Verificação | `android/app/build.gradle.kts` com `minSdk = 26`, `targetSdk = 37`; execução em emulador API 26 e API 37 e em 2 celulares físicos (registrado em docs/23-plano-de-testes.md); teste "negar localização" e "emulador sem GMS" (imagem AOSP) mostram a lista sem distância e sem crash; `adb install app-release.apk` testado em S9 em 2 celulares. |
| Limitação consciente | Não há testes em tablets, dobráveis, Wear ou Android TV; orientação retrato apenas; sem suporte a idiomas além de pt-BR; sem Play Store (conta de distribuição limitada do Google avaliada em S9 apenas como alternativa). |

### RNF09 — O app deve falar com um único backend em `/api/v1` sobre HTTPS, com datas ISO-8601 com offset e erros em `ProblemDetail`, e o contrato só pode mudar de forma aditiva após a N1

| Campo | Conteúdo |
|---|---|
| Categoria | Interoperabilidade e contrato |
| Descrição | Um único backend, prefixo **`/api/v1`**, JSON em camelCase, autenticação `Authorization: Bearer <jwt>`; **HTTPS em todo ambiente fora do desenvolvimento** (Render fornece TLS; cleartext só para `10.0.2.2`/IP da LAN em build debug via `network_security_config`); **datas ISO-8601 com offset** (`2026-10-10T19:00:00-03:00`), valores monetários como string decimal (`"80.00"`), ids `Long`; **erros como `ProblemDetail` RFC 9457** com campo extra `codigo` (enum `CodigoErro`) e `campos[]` na validação, gerados pelo `GlobalExceptionHandler`; contrato publicado pelo springdoc 3.1.0 (`/swagger-ui.html`, desligado em `inter-prod`); **após a N1 o contrato só recebe mudanças aditivas** (campos novos opcionais; nada é removido ou renomeado) para o APK instalado nos celulares de teste continuar funcionando. O Android nunca fala com Inter ou BrasilAPI diretamente (RNF02). |
| Verificação | Swagger acessível e coerente com docs/10-api-rest.md; `ProblemDetailParser` no app converte qualquer erro em `Resultado.Erro(codigo)` (teste unitário); `git diff v0.1-n1..main -- backend/src/main/java/**/dto` revisado no PR para provar que só houve adições; `curl -i` mostra 401 em rota protegida sem token e 400 com `campos[]` em `POST /quadras` inválido. |
| Limitação consciente | Sem versionamento real além do prefixo (`/v2` não está previsto), sem paginação, sem cache HTTP/ETag, sem compressão configurada. Cleartext HTTP existe apenas em build debug apontando para a LAN. |

### RNF10 — O código deve seguir camadas explícitas com versões fixadas e migrations Flyway aditivas, e todo PR deve passar pelo CI com aprovação do suplente, mantendo o README executável em máquina limpa

| Campo | Conteúdo |
|---|---|
| Categoria | Manutenibilidade e processo |
| Descrição | Backend em camadas explícitas (`controller/service/repository/entity/dto/exception/config/security/integracao`), com a regra "controller valida e converte DTO; service tem regra e `@Transactional`; repository só JPA; entity nunca sai do controller"; Android em MVVM + Repository (`ui → ViewModel → Repository → Api | Dao | DataStore`) com DI manual (`AppContainer`); **migrations Flyway aditivas** (`V1__init.sql` nunca editado após a N1; mudanças em `V3+`); **versões fixadas** em `gradle/libs.versions.toml` (Android) e no `build.gradle.kts` do backend, com tabela de versões verificada em 01/09/2026 no README; **CI GitHub Actions** rodando `./gradlew test` do backend (Testcontainers) e `assembleDebug` do Android em todo PR; PR < 400 linhas com 1 aprovação do suplente e ninguém mergeia o próprio PR; **README executável** (`docker compose up -d`, `./gradlew bootRun`, abrir no Android Studio Quail 4) testado em máquina limpa por outro integrante antes da N1. Testes automatizados mínimos por fatia: unitários de service, `@WebMvcTest` de controller, `ReservaConcorrenciaIT`, testes de ViewModel com fakes. |
| Verificação | Árvore de pacotes no repositório; `git log --oneline -- backend/src/main/resources/db/migration/V1__init.sql` sem commits após a tag `v0.1-n1`; badge/histórico verde do CI; README seguido do zero por um integrante que não o escreveu (registrado na issue); `git shortlog -sn -- backend android docs` mostrando os 4 integrantes nas 3 pastas. |
| Limitação consciente | Sem cobertura mínima obrigatória, sem testes E2E de UI (Espresso/Compose UI test em CI), sem análise estática além do lint padrão, sem ambiente de staging separado do beta. Room usa `fallbackToDestructiveMigration` porque é cache: mudança de schema recria o banco local no próximo sync. |

### RNF11 — As escritas devem exigir rede e ir direto ao backend, e as leituras devem vir do cache Room substituído por escopo a cada sincronização, com o servidor como única verdade

| Campo | Conteúdo |
|---|---|
| Categoria | Consistência de dados |
| Descrição | **Escritas somente online**: reservar, pagar, cancelar, editar quadra/horário/perfil exigem rede e vão direto ao backend; sucesso é gravado no Room (write-through) e a lista é re-sincronizada. **Leituras com cache**: a UI observa o Room e o `Sincronizador` substitui o escopo inteiro (`CATALOGO`/`MINHAS`/`QUADRA`) com a resposta do servidor — linha ausente no servidor é apagada localmente. **A verdade é o servidor**: a grade de slots é "melhor esforço" e a exclusividade real é o 409 do índice único parcial (RN08); slots não vão para o cache justamente para um slot "livre" velho não induzir reserva errada. Sem fila offline, sem WorkManager, sem merge de conflitos, porque o app nunca edita localmente. Confirmação de pagamento e expiração usam `UPDATE` condicional (idempotentes) — ver docs/07-regras-de-negocio.md. |
| Verificação | Demo em modo avião: botões de escrita desabilitados e `BannerOffline`; ao reconectar, uma reserva cancelada pelo dono no servidor desaparece de `MinhasReservas`; `SincronizadorTest` (fake de API devolvendo lista menor apaga linhas locais); demo dos 2 celulares no mesmo slot com 409. |
| Limitação consciente | Uma ação iniciada sem rede simplesmente não acontece (não é enfileirada); o usuário precisa repetir quando reconectar. Slot mostrado como LIVRE pode já estar ocupado no instante do toque — o 409 e a recarga automática da grade resolvem. |

### RNF12 — Todo cálculo de horário, slot, janela de reserva e prazo de cancelamento deve usar a zona `America/Sao_Paulo`, com instantes em `TIMESTAMPTZ` e conversão do offset recebido

| Campo | Conteúdo |
|---|---|
| Categoria | Corretude de tempo |
| Descrição | Todo cálculo de "hora cheia", horário de funcionamento, slot, janela de reserva (hoje+14) e prazo de cancelamento (2 h antes) usa a zona **`America/Sao_Paulo`**, definida em `FusoConfig` (propriedade `app.fuso-horario`). Colunas `TIMESTAMPTZ` guardam instantes; `horario_funcionamento.hora_abertura/hora_fechamento` são `TIME` interpretados nessa zona; o app envia `OffsetDateTime` com offset (`-03:00`) e o backend converte com `atZoneSameInstant(FUSO)` antes de validar. O app formata datas com `Formatadores.kt` no mesmo fuso. |
| Verificação | `SlotServiceTest` com casos de meia-noite, limite hoje+14 e reserva enviada com offset diferente de -03:00 (deve cair no mesmo slot); teste de `POST /reservas` com `inicio` `19:30` → 400; conferência visual de que 19:00 na tela é 19:00 no banco (`select inicio at time zone 'America/Sao_Paulo'`). |
| Limitação consciente | Quadras em UF com offset diferente (AM, AC, MS, MT, RR, RO) ficam fora do MVP: não há coluna de fuso por quadra (decisão registrada em docs/09-arquitetura.md). O Brasil não tem horário de verão em 2026, mas a zona `America/Sao_Paulo` já trata isso se voltar. |

## Rastreabilidade RNF → onde é evidenciado

| RNF | Código / artefato | Documento que detalha |
|---|---|---|
| RNF01 | `security/JwtService`, `LoginTentativasService`, `config/JwtConfig`, `RegistrarRequest` | docs/03-perfis-e-permissoes.md, docs/09-arquitetura.md |
| RNF02 | `V1__init.sql` (tabela `pagamento`), `.gitignore`, `InterWebhookController`, `application-inter-*.yml` | docs/11-integracao-pix-inter.md, docs/08-modelagem-banco.md |
| RNF03 | `data/local/SessaoDataStore.kt`, `AuthInterceptor` | docs/12-persistencia-local.md |
| RNF04 | índices em `V1__init.sql`, `PagamentoViewModel` (backoff), `ConsultaPagamentoJob` | docs/11-integracao-pix-inter.md, docs/23-plano-de-testes.md |
| RNF05 | `Dockerfile`, Render/Neon, `scripts/`, kit offline | docs/09-arquitetura.md, docs/18-checklist-n2.md, docs/19-riscos.md |
| RNF06 | `ui/components/*Box`, `CampoTextoValidado`, SUS | docs/04-telas.md, docs/22-testes-com-usuarios.md |
| RNF07 | checklist por tela, TalkBack | docs/04-telas.md, docs/22-testes-com-usuarios.md |
| RNF08 | `build.gradle.kts`, `AndroidManifest.xml`, `LocalizacaoProvider` | docs/13-recurso-nativo.md, docs/21-git-e-organizacao.md |
| RNF09 | `GlobalExceptionHandler`, `CodigoErro`, springdoc | docs/10-api-rest.md |
| RNF10 | árvore de pacotes, Flyway, `libs.versions.toml`, CI, README | docs/09-arquitetura.md, docs/21-git-e-organizacao.md, README.md |
| RNF11 | `Sincronizador.kt`, `ux_reserva_slot_ativo` | docs/12-persistencia-local.md, docs/07-regras-de-negocio.md |
| RNF12 | `FusoConfig`, `SlotService`, `Formatadores.kt` | docs/07-regras-de-negocio.md (RN06), docs/08-modelagem-banco.md |
