# Só mais uma

App Flutter (Android) para encontrar quadras esportivas, ver horários livres, reservar e pagar via Pix, com confirmação automática da reserva.

![App](https://img.shields.io/badge/App-Flutter%203.47%20%2B%20Dart%203.13-02569B) ![Backend](https://img.shields.io/badge/Backend-Spring%20Boot%204.1%20%2B%20JDK%2021-6DB33F) ![Banco](https://img.shields.io/badge/Banco-PostgreSQL%2018-336791) ![Pix](https://img.shields.io/badge/Pagamento-Pix%20Banco%20Inter%20(sandbox)-FF7A00) ![CI](https://img.shields.io/badge/CI-GitHub%20Actions-2088FF) ![Status](https://img.shields.io/badge/Status-planejamento%20(S1)-lightgrey)

## Visão do produto

Quem quer jogar perde tempo ligando para quadras para descobrir horário livre e combinar pagamento; quem administra uma quadra perde reservas e recebe sem controle. O "Só mais uma" resolve o fluxo central em um só app: o **CLIENTE** encontra a quadra mais perto (geolocalização), vê a grade de horários de 60 min, reserva um slot com exclusividade garantida no banco, paga por Pix (QR Code e copia e cola) e recebe a confirmação automática; o **DONO** cadastra suas quadras por CEP, define os horários de funcionamento e acompanha ou cancela as reservas recebidas. Projeto acadêmico de 4 estudantes entre 01/09 e 11/12/2026, com Pix real no sandbox do Banco Inter e um gateway simulado como fallback de demonstração. Detalhes em [docs/01-visao-do-produto.md](docs/01-visao-do-produto.md).

## Stack e versões (backend verificado em 01/09/2026; app verificado em 06/10/2026)

Atualizado em 06/10/2026: o app passou de Android nativo (Kotlin + Jetpack Compose) para Flutter. O backend não mudou. Equivalências componente a componente em [docs/09-arquitetura.md](docs/09-arquitetura.md), seção 4.

| Componente | Versão fixada | Onde |
|---|---|---|
| JDK | 25 LTS no backend (`java.version` 25 no `pom.xml`); 21 LTS (Temurin ou o JBR do Android Studio) para o Gradle do Android usado pelo `flutter build apk` | backend e `frontend/android/` |
| Spring Boot | 4.1.x (4.1.1 em 01/09/2026): Spring Framework 7, Spring Security 7.1, Hibernate 7, Jackson 3 (`tools.jackson.*`) | `backend/pom.xml` (Maven, parent `spring-boot-starter-parent:4.1.1`) |
| Starters | `starter-webmvc`, `data-jpa`, `security`, `security-oauth2-resource-server` (JWT HS256 via Nimbus), `validation`, `flyway` + `flyway-database-postgresql`, `actuator`, `restclient`, `spring-boot-docker-compose` (dev) | `backend/pom.xml` |
| springdoc-openapi | 3.1.0 (`springdoc-openapi-starter-webmvc-ui`) | Swagger |
| PostgreSQL | 18 (`postgres:18-alpine`); driver 42.7.12 gerenciado pelo Boot; Flyway >= 12.4 gerenciado pelo Boot | `backend/compose.yaml` |
| Testes backend | JUnit 5, `spring-boot-starter-webmvc-test`, Testcontainers 2.x (`testcontainers-postgresql`), Mockito (`@MockitoBean`) | `backend/src/test` |
| Lombok | 1.18.48 (só nas entidades JPA; DTOs são records) | backend |
| Flutter / Dart | 3.47.6 stable (01/10/2026) / 3.13.5 | `frontend/pubspec.yaml` (`environment: sdk: ^3.13.0`); CI fixa `flutter-version: 3.47.6` |
| Android (alvo do MVP) | compileSdk = targetSdk = 36 (padrão do Flutter 3.47.6); minSdk 26; applicationId `br.com.somaisuma.app` | `frontend/android/app/build.gradle.kts` (Gradle/AGP/Kotlin gerados pelo `flutter create`, sem edição manual) |
| Arquitetura | MVVM + Repository do guia oficial do Flutter: `ChangeNotifier` + `provider` 6.1.5+1 (DI) | `frontend/lib/` |
| Navegação | go_router 18.0.2 (`StatefulShellRoute` por perfil) | `pubspec.yaml` |
| Rede | dio 5.11.1 + json_serializable 6.14.1 / json_annotation 4.12.0 | `pubspec.yaml` |
| Cache local | drift 2.35.1 + drift_flutter 0.3.1 (código gerado com build_runner 2.16.1) | `pubspec.yaml` |
| Sessão | flutter_secure_storage 11.2.0 (token JWT) + shared_preferences 2.5.6 (demais chaves) | `pubspec.yaml` |
| Recursos nativos | geolocator 14.1.1, url_launcher 6.3.3 (`geo:`), flutter_local_notifications 22.3.1, connectivity_plus 7.3.2 | `pubspec.yaml` |
| QR Code / formatação | qr_flutter 4.1.0 (só geração) / intl 0.20.3 | `pubspec.yaml` |
| Imagens (recomendado) | cached_network_image 4.0.4 | `pubspec.yaml` |
| Testes e lint do app | `flutter_test`, mocktail 1.0.5 (opcional), flutter_lints 6.0.0 | `frontend/test` |
| IDE do app | VS Code com extensões Dart e Flutter (ou Android Studio com plugin Flutter); Android SDK e emulador continuam necessários | — |
| Docker Desktop | versão atual estável (necessário para `compose.yaml` e Testcontainers) | — |

Por que estas escolhas: [docs/09-arquitetura.md](docs/09-arquitetura.md). O que ficou de fora e por quê: [docs/00-indice.md](docs/00-indice.md), seção 4.

## Estrutura do monorepo

```text
so-mais-uma/
├── backend/                 # Spring Boot 4.1 (Java 25, Maven: pom.xml + mvnw)
│   ├── src/main/java/br/com/puc/so_mais_uma/{config,security,controller,service,repository,entity,dto,exception,integracao}
│   ├── src/main/resources/{application.yml,application-simulado.yml,application-inter-sandbox.yml,application-inter-prod.yml}
│   ├── src/main/resources/db/migration/V1__init.sql
│   ├── src/main/resources/db/migration/     # V1__init.sql e as migrations seguintes (V2, V3, ...)
│   ├── src/test/java/...    # *Test (unitários, @WebMvcTest) e *IT (Testcontainers)
│   ├── compose.yaml         # postgres:18-alpine
│   ├── Dockerfile           # multi-stage, eclipse-temurin:25-jdk -> eclipse-temurin:25-jre (Render)
│   └── .env.exemplo
├── frontend/                # app Flutter (Dart), alvo Android
│   ├── lib/{config,data,model,ui,util}   # main.dart, app.dart na raiz de lib/
│   ├── test/                # ViewModels com FakeApiClient, widgets, DAO drift em memória
│   ├── config/              # dev.json.exemplo (modelo), dev.json (ignorado), release.json
│   ├── android/             # Gradle gerado pelo flutter create (applicationId, minSdk, assinatura)
│   └── pubspec.yaml · pubspec.lock
├── docs/                    # 00-indice.md ... 23-plano-de-testes.md
├── scripts/                 # *.http (token sandbox, cadastrar-webhook), reset-demo.sql
├── .github/workflows/ci.yml
├── CONTRIBUTING.md
└── README.md
```

## Pré-requisitos

| Ferramenta | Versão | Observação |
|---|---|---|
| JDK | 25 (backend) e 21 (Gradle do Android) | o Maven Wrapper do backend usa o 25; o `flutter build apk` usa o 21 (Temurin ou o JBR do Android Studio; `flutter config --jdk-dir` se houver mais de um) |
| Flutter SDK | 3.47.6 stable (traz Dart 3.13.5) | `flutter --version` igual em todos e no CI; `flutter upgrade` se estiver em versão anterior; caminho do SDK sem espaços |
| Android SDK + emulador | via Android Studio (SDK Manager / Device Manager) ou cmdline-tools | platform 36, build-tools e platform-tools; `flutter doctor --android-licenses` uma vez |
| IDE | VS Code com Dart + Flutter (recomendadas no `so-mais-uma.code-workspace`) ou Android Studio com plugin Flutter | — |
| Docker Desktop | atual | precisa estar rodando para `docker compose` e para os testes `*IT` |
| Git | 2.40+ | — |
| Opcional | `adb` (vem com o Android SDK Platform-Tools), `curl`, `openssl` | instalação do APK e testes do sandbox Inter |

`flutter doctor` precisa mostrar Flutter e Android toolchain verdes antes do primeiro build.

## Backend: instalação e execução

```bash
git clone https://github.com/<org>/so-mais-uma.git
cd so-mais-uma/backend
cp .env.exemplo .env            # edite JWT_SECRET e DEV_KEY (sem commitar o .env)
docker compose up -d            # sobe o PostgreSQL 18 (porta 5432)
./mvnw spring-boot:run          # profile padrão: simulado (lê o .env via spring.config.import)
```

No Windows use `mvnw.cmd spring-boot:run`. O `spring-boot-docker-compose` também sobe o banco sozinho ao rodar `spring-boot:run`, então o `docker compose up -d` é opcional em dev. Flyway aplica `db/migration/V1__init.sql` (5 tabelas + índice único parcial) no primeiro start. Toda evolução de esquema começa em `V3__...`.

`backend/.env.exemplo` (valores de exemplo, nunca reais):

```properties
# Copie para .env (nunca versionado). A aplicação lê este arquivo como propriedades
# (spring.config.import=optional:file:.env[.properties]); ele não passa por shell, então
# use caminhos absolutos. Valores abaixo são apenas exemplos.

# obrigatórias em qualquer profile
# simulado | inter-sandbox | inter-prod
spring.profiles.active=simulado
JWT_SECRET=troque-por-uma-string-aleatoria-com-32-bytes-ou-mais
# header X-Dev-Key de POST /api/v1/dev/pagamentos/{txid}/confirmar
DEV_KEY=troque-por-uma-chave-do-endpoint-dev

# profile simulado
# chave usada no payload BR Code do SimuladoPixGateway
SIMULADO_PIX_CHAVE=chave-pix-ficticia@somaisuma.local
# nome do recebedor no payload BR Code
SIMULADO_PIX_NOME=SO MAIS UMA
# cidade do recebedor no payload BR Code
SIMULADO_PIX_CIDADE=BELO HORIZONTE

# opcionais (têm padrão na aplicação)
# JWT_VALIDADE_DIAS=7
# APP_FUSO_HORARIO=America/Sao_Paulo
# prazo de pagamento da reserva (reduzir só em testes)
# RESERVA_PRAZO_PAGAMENTO=PT15M
# PORT=8080

# banco fora do docker compose (Render/Neon ou Postgres local próprio)
# spring.datasource.url=jdbc:postgresql://localhost:5432/somaisuma
# spring.datasource.username=somaisuma
# spring.datasource.password=somaisuma

# profiles inter-sandbox / inter-prod (só quem tem os arquivos; ver docs/11)
# INTER_CLIENT_ID=
# INTER_CLIENT_SECRET=
# INTER_CRT=/home/<usuario>/.somaisuma/inter-sandbox.crt
# INTER_KEY=/home/<usuario>/.somaisuma/inter-sandbox.key
# no Windows: C:/Users/<usuario>/.somaisuma/inter-sandbox.crt
# INTER_CHAVE_PIX=
# segmento secreto da URL de callback (UUID sem hifens)
# INTER_WEBHOOK_SEGREDO=
# INTER_ESCOPOS=cob.write cob.read pix.read pix.write webhook.write webhook.read
# INTER_BASE_URL=https://cdpj-sandbox.partners.uatinter.co
```

O `.env` é carregado pela aplicação como arquivo de propriedades (`spring.config.import=optional:file:.env[.properties]`), não é interpretado por um shell: por isso os caminhos são absolutos, os comentários ficam em linha própria (em `.properties`, um `#` no meio da linha vira parte do valor) e as propriedades do Spring aparecem na forma canônica com pontos e minúsculas. As versões em maiúsculas com sublinhado (`SPRING_PROFILES_ACTIVE`, `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`) só recebem a conversão automática de nome quando são variáveis de ambiente de verdade — use-as no `export` do shell e no painel do Render; dentro do arquivo, valem as chaves com pontos. As demais chaves (`JWT_SECRET`, `DEV_KEY`, `INTER_*`) são lidas por placeholder `${...}` nos `application*.yml` e funcionam igual nos dois lugares.

Após subir:

| Recurso | URL |
|---|---|
| Swagger UI | http://localhost:8080/swagger-ui.html |
| OpenAPI JSON | http://localhost:8080/v3/api-docs |
| Health | http://localhost:8080/actuator/health |
| Prefixo da API | `http://localhost:8080/api/v1` |

Usuários de demonstração criados pelo seed (`scripts/seed-demo.sql`, aplicado com `psql` fora do Flyway):

| E-mail | Senha | Perfil | Dados |
|---|---|---|---|
| `cliente@demo.com` | `Senha123` | CLIENTE | 2 reservas (uma CONFIRMADA amanhã, uma EXPIRADA ontem) |
| `dono@demo.com` | `Senha123` | DONO | 3 quadras georreferenciadas na cidade do grupo, horários seg-dom 08h-22h |

Fluxo rápido no Swagger: `POST /api/v1/auth/login` -> copiar `token` -> botão Authorize -> `GET /api/v1/quadras` -> `GET /api/v1/quadras/{id}/slots?data=<amanhã>` -> `POST /api/v1/reservas` -> `POST /api/v1/dev/pagamentos/{txid}/confirmar` (header `X-Dev-Key`) -> `GET /api/v1/reservas/{id}` com status `CONFIRMADA`.

## App Flutter: execução

1. Baixar dependências e gerar o código do drift e do json_serializable (os `*.g.dart` não são versionados; repetir sempre que mudar uma tabela ou um DTO):

```bash
cd frontend
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

2. Definir a URL do backend em `frontend/config/dev.json` (ignorado pelo Git; copiar de `config/dev.json.exemplo`). Os valores entram no app por `--dart-define-from-file` e são lidos em `lib/config/ambiente.dart` (`Ambiente.apiBaseUrl`, `Ambiente.devKey`):

```json
{
  "API_BASE_URL": "http://10.0.2.2:8080/api/v1",
  "DEV_KEY": "mesmo-valor-do-DEV_KEY-do-backend"
}
```

   `10.0.2.2` é o localhost do computador visto pelo emulador; para celular físico na mesma rede Wi-Fi ou hotspot, usar o IP da LAN do computador (`http://192.168.0.10:8080/api/v1`). Sem o arquivo, o app usa `http://10.0.2.2:8080/api/v1`. Wi-Fi da faculdade bloqueando IPs locais: usar o hotspot do celular. Notebook fraco para emulador + Docker: usar celular físico via USB (`adb devices` / `flutter devices`).
3. Modos de build:

| Modo | Pacote | Base URL | Cleartext HTTP | Botão "Simular pagamento" | Uso |
|---|---|---|---|---|---|
| debug | `br.com.somaisuma.app.debug` (`applicationIdSuffix ".debug"` no `frontend/android/app/build.gradle.kts`) | `config/dev.json` ou `10.0.2.2` | permitido (`android:usesCleartextTraffic="true"` só em `frontend/android/app/src/debug/AndroidManifest.xml`) | sim (`kDebugMode && Ambiente.devKey.isNotEmpty`) | desenvolvimento, testes com usuários, kit de demo offline |
| release | `br.com.somaisuma.app` | URL do Render (HTTPS) em `config/release.json` (versionado, sem segredo) | não | não | beta público, apresentação |

O sufixo `.debug` permite instalar as duas variantes no mesmo celular, o que o kit de demo offline exige.

4. Rodar com hot reload (emulador ou celular) ou gerar e instalar o APK:

```bash
cd frontend
flutter run --dart-define-from-file=config/dev.json
flutter build apk --debug --dart-define-from-file=config/dev.json
adb install -r build/app/outputs/flutter-apk/app-debug.apk
# release assinado (keystore e android/key.properties fora do repositório; ver CONTRIBUTING.md)
flutter build apk --release --dart-define-from-file=config/release.json
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

   Desempenho (RNF04) só se mede em `--release` ou `--profile`: o modo debug roda em JIT e é bem mais lento.

Instalação sempre via `adb`: desde 30/09/2026 a verificação de desenvolvedor do Google no Brasil pode colocar o sideload por navegador em um fluxo com espera; `adb install` não é afetado (risco R7 em [docs/19-riscos.md](docs/19-riscos.md)). Permissões pedidas em runtime: localização (aproximada ou precisa) ao tocar "Ativar localização" na tela Quadras; notificações (Android 13+) na primeira abertura da tela Pagamento. O app funciona sem ambas, de forma degradada.

## Testes

```bash
# backend: unitários + @WebMvcTest + integração (Testcontainers exige Docker rodando)
cd backend && ./mvnw verify
# só a corrida de 10 threads no mesmo slot (1x201, 9x409)
cd backend && ./mvnw verify -Dtest=NONE -Dsurefire.failIfNoSpecifiedTests=false -Dit.test=ReservaConcorrenciaIT
# app: análise estática + ViewModels, widgets, DAO do drift em memória e utilitários (sem emulador)
cd frontend && flutter analyze && flutter test
# app (opcional, exige emulador): testes de integração
cd frontend && flutter test integration_test
```

Relatórios em `backend/target/surefire-reports/` e `backend/target/failsafe-reports/`; o resultado do app sai no terminal do `flutter test` (cobertura opcional com `flutter test --coverage` em `frontend/coverage/lcov.info`). Casos de teste manuais CT-01..CT-30, o que roda no CI e critérios de saída: [docs/23-plano-de-testes.md](docs/23-plano-de-testes.md). Testes com usuários (SUS): [docs/22-testes-com-usuarios.md](docs/22-testes-com-usuarios.md).

## Profiles Spring e pagamento Pix

| Profile | Gateway | Quando usar | Requisitos |
|---|---|---|---|
| `simulado` (padrão) | `SimuladoPixGateway`: gera payload BR Code estático válido (`PixPayloadBuilder`, CRC16) e confirma via `POST /api/v1/dev/pagamentos/{txid}/confirmar` | dev, testes, CI, testes com usuários, kit de demo offline | `SIMULADO_PIX_CHAVE`, `DEV_KEY` |
| `inter-sandbox` | `InterPixGateway` contra `https://cdpj-sandbox.partners.uatinter.co` (OAuth2 client_credentials + mTLS); o endpoint `/dev/.../confirmar` repassa para `POST /pix/v2/cob/pagar/{txid}` do sandbox | demonstração da API externa real; disponível 8h-20h seg-sex; certificado vale 30 dias | integração criada em developers.inter.co/sandbox; `INTER_CLIENT_ID`, `INTER_CLIENT_SECRET`, `INTER_CRT`, `INTER_KEY`, `INTER_CHAVE_PIX` |
| `inter-prod` | `InterPixGateway` contra `https://cdpj.partners.bancointer.com.br`; sem endpoint `/dev`; Swagger desligado | recomendado, só com conta PJ Inter Empresas (CNPJ não-MEI) e integração aprovada; go/no-go em 16/10 | mesmos arquivos, emitidos no Internet Banking PJ (validade 1 ano) |

Como ativar `inter-sandbox` sem colocar segredos no repositório:

```bash
cd backend
# 1. baixe o certificado e a chave no portal, guarde FORA do repo em ~/.somaisuma/ e renomeie para
#    inter-sandbox.crt e inter-sandbox.key
# 2. exporte as variáveis apenas no seu shell; no .env (que está no .gitignore) use as
#    chaves com pontos e caminhos absolutos, como no exemplo acima
export SPRING_PROFILES_ACTIVE=inter-sandbox
export INTER_CLIENT_ID=... INTER_CLIENT_SECRET=... INTER_CHAVE_PIX=...
export INTER_CRT="$HOME/.somaisuma/inter-sandbox.crt"
export INTER_KEY="$HOME/.somaisuma/inter-sandbox.key"
# 3. prova rápida fora do app (token 200), depois suba o backend
curl --cert "$INTER_CRT" --key "$INTER_KEY" -X POST https://cdpj-sandbox.partners.uatinter.co/oauth/v2/token \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d "client_id=$INTER_CLIENT_ID&client_secret=$INTER_CLIENT_SECRET&grant_type=client_credentials&scope=cob.write cob.read pix.read pix.write webhook.write webhook.read"
./mvnw spring-boot:run
```

O `.gitignore` bloqueia `*.crt`, `*.key`, `*.pfx` e `.env`; no Render os arquivos entram como Secret Files e as variáveis no painel. Escopos, fluxo de cobrança, webhook (recomendado), rate limits, gates datados e limitações: [docs/11-integracao-pix-inter.md](docs/11-integracao-pix-inter.md).

## Documentação

Comece por [docs/00-indice.md](docs/00-indice.md) (sumário, matriz de rastreabilidade dos 7 critérios, decisões-chave, glossário). Atalhos:

- Produto e escopo: [01-visao-do-produto](docs/01-visao-do-produto.md) · [02-escopo-mvp](docs/02-escopo-mvp.md) · [03-perfis-e-permissoes](docs/03-perfis-e-permissoes.md) · [04-telas](docs/04-telas.md)
- Requisitos: [05-requisitos-funcionais](docs/05-requisitos-funcionais.md) · [06-requisitos-nao-funcionais](docs/06-requisitos-nao-funcionais.md) · [07-regras-de-negocio](docs/07-regras-de-negocio.md)
- Técnico: [08-modelagem-banco](docs/08-modelagem-banco.md) · [09-arquitetura](docs/09-arquitetura.md) · [10-api-rest](docs/10-api-rest.md) · [11-integracao-pix-inter](docs/11-integracao-pix-inter.md) · [12-persistencia-local](docs/12-persistencia-local.md) · [13-recurso-nativo](docs/13-recurso-nativo.md)
- Gestão: [14-backlog](docs/14-backlog.md) · [15-divisao-equipe](docs/15-divisao-equipe.md) · [16-cronograma](docs/16-cronograma.md) · [17-checklist-n1](docs/17-checklist-n1.md) · [18-checklist-n2](docs/18-checklist-n2.md) · [19-riscos](docs/19-riscos.md) · [20-ordem-de-implementacao](docs/20-ordem-de-implementacao.md) · [21-git-e-organizacao](docs/21-git-e-organizacao.md)
- Qualidade: [22-testes-com-usuarios](docs/22-testes-com-usuarios.md) · [23-plano-de-testes](docs/23-plano-de-testes.md)
- Protótipo Figma (CP1): <link> · backup `docs/prototipo/figma-cp1.pdf`

## Equipe

Cada integrante é dono de uma fatia vertical (backend + app Flutter + documentação + testes) e suplente de outra; ninguém mergeia o próprio PR. Evidência do critério 7: `git shortlog -sn --no-merges -- backend frontend docs`.

| Integrante | Fatia | Suplente de |
|---|---|---|
| Integrante A | Autenticação, usuário, segurança (JWT, bloqueio de login), repositório, CI, Render/Neon, APK release, README | D |
| Integrante B | Quadra e HorarioFuncionamento (os 2 CRUDs), CEP (BrasilAPI/ViaCEP), modelagem do banco, protótipo Figma | C |
| Integrante C | Reserva, slots, concorrência (índice único + 10 threads), cache drift/sincronização/offline, geolocalização, testes com usuários | B |
| Integrante D | Pagamento Pix (Inter + simulado), webhook, burocracia do Inter, backlog/board, plano de testes, roteiro da demo | A |

Detalhes em [docs/15-divisao-equipe.md](docs/15-divisao-equipe.md) e regras de contribuição em `CONTRIBUTING.md`.

## Limitações conhecidas (MVP)

Fuso único `America/Sao_Paulo`; JWT de 7 dias sem revogação (logout só limpa o dispositivo); todo Pix é recebido na única chave configurada e o repasse ao dono ocorre fora do app; estorno é manual; webhook do Inter sem mTLS de entrada; sem paginação; publicação na Play Store fora do escopo; iOS fora do MVP (o código Flutter não impede gerar a plataforma depois, mas exige macOS, Xcode e conta Apple). Lista completa e motivos em [docs/02-escopo-mvp.md](docs/02-escopo-mvp.md).

## Licença

Projeto acadêmico desenvolvido para a disciplina de desenvolvimento mobile (2026/2). Código-fonte sob licença MIT para fins de estudo; não há garantia de adequação a uso comercial. "Pix" é marca do Banco Central do Brasil e "Banco Inter" pertence ao respectivo titular; a integração usa o sandbox público de desenvolvedores. Nenhum dado pessoal real deve ser cadastrado nos ambientes de demonstração.
