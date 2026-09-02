# Só mais uma

App Android para encontrar quadras esportivas, ver horários livres, reservar e pagar via Pix, com confirmação automática da reserva.

![Android](https://img.shields.io/badge/Android-Kotlin%20%2B%20Jetpack%20Compose-3DDC84) ![Backend](https://img.shields.io/badge/Backend-Spring%20Boot%204.1%20%2B%20JDK%2021-6DB33F) ![Banco](https://img.shields.io/badge/Banco-PostgreSQL%2018-336791) ![Pix](https://img.shields.io/badge/Pagamento-Pix%20Banco%20Inter%20(sandbox)-FF7A00) ![CI](https://img.shields.io/badge/CI-GitHub%20Actions-2088FF) ![Status](https://img.shields.io/badge/Status-planejamento%20(S1)-lightgrey)

## Visão do produto

Quem quer jogar perde tempo ligando para quadras para descobrir horário livre e combinar pagamento; quem administra uma quadra perde reservas e recebe sem controle. O "Só mais uma" resolve o fluxo central em um só app: o **CLIENTE** encontra a quadra mais perto (geolocalização), vê a grade de horários de 60 min, reserva um slot com exclusividade garantida no banco, paga por Pix (QR Code e copia e cola) e recebe a confirmação automática; o **DONO** cadastra suas quadras por CEP, define os horários de funcionamento e acompanha ou cancela as reservas recebidas. Projeto acadêmico de 4 estudantes entre 01/09 e 11/12/2026, com Pix real no sandbox do Banco Inter e um gateway simulado como fallback de demonstração. Detalhes em [docs/01-visao-do-produto.md](docs/01-visao-do-produto.md).

## Stack e versões (verificadas em 01/09/2026)

| Componente | Versão fixada | Onde |
|---|---|---|
| JDK | 21 LTS (Temurin); Java 25 também funciona | backend e Android |
| Spring Boot | 4.1.x (4.1.1 em 01/09/2026): Spring Framework 7, Spring Security 7.1, Hibernate 7, Jackson 3 (`tools.jackson.*`) | `backend/build.gradle.kts` |
| Starters | `starter-webmvc`, `data-jpa`, `security`, `oauth2-resource-server` (JWT HS256 via Nimbus), `validation`, `flyway` + `flyway-database-postgresql`, `spring-boot-docker-compose` (dev) | `backend/build.gradle.kts` |
| springdoc-openapi | 3.1.0 (`springdoc-openapi-starter-webmvc-ui`) | Swagger |
| PostgreSQL | 18 (`postgres:18-alpine`); driver 42.7.12 gerenciado pelo Boot; Flyway >= 12.4 gerenciado pelo Boot | `backend/compose.yaml` |
| Testes backend | JUnit 5, `spring-boot-starter-webmvc-test`, Testcontainers 2.x (`testcontainers-postgresql`), Mockito (`@MockitoBean`) | `backend/src/test` |
| Lombok | 1.18.48 (só nas entidades JPA; DTOs são records) | backend |
| Android Studio | Quail 4 (2026.1.4) | — |
| AGP / Gradle | 9.4.0 / wrapper 9.7.1 (Kotlin embutido; KSP em tudo, sem KAPT) | `android/gradle/libs.versions.toml` |
| Kotlin | 2.4.10 (plugin `org.jetbrains.kotlin.plugin.compose` na mesma versão) | catálogo |
| SDK | compileSdk = targetSdk = 37 (Android 17); minSdk 26 | `android/app/build.gradle.kts` |
| Jetpack Compose | BOM 2026.08.00 (Compose UI 1.12.0, Material 3 1.4.0) | catálogo |
| Navigation Compose | 2.10.0 (rotas tipadas `@Serializable`) | catálogo |
| Room | 3.0.2 (`androidx.room3`, KSP) | catálogo |
| DataStore Preferences | 1.2.1 | catálogo |
| Lifecycle / activity-compose | 2.11.0 / 1.13.0 | catálogo |
| Rede | Retrofit 3.0.0 + OkHttp 5.x (versão explícita) + `converter-kotlinx-serialization` + kotlinx.serialization 1.11.0 | catálogo |
| Localização | play-services-location 21.4.0 | catálogo |
| QR Code | ZXing core 3.5.4 (só geração) | catálogo |
| Imagens (recomendado) | Coil 3.6.1 | catálogo |
| Docker Desktop | versão atual estável (necessário para `compose.yaml` e Testcontainers) | — |

Por que estas escolhas: [docs/09-arquitetura.md](docs/09-arquitetura.md). O que ficou de fora e por quê: [docs/00-indice.md](docs/00-indice.md), seção 4.

## Estrutura do monorepo

```text
so-mais-uma/
├── backend/                 # Spring Boot 4.1 (Java, Gradle Kotlin DSL)
│   ├── src/main/java/br/com/somaisuma/{config,security,controller,service,repository,entity,dto,exception,integracao}
│   ├── src/main/resources/{application.yml,application-simulado.yml,application-inter-sandbox.yml,application-inter-prod.yml}
│   ├── src/main/resources/db/migration/V1__init.sql
│   ├── src/main/resources/db/migration/     # V1__init.sql e as migrations seguintes (V2, V3, ...)
│   ├── src/test/java/...    # *Test (unitários, @WebMvcTest) e *IT (Testcontainers)
│   ├── compose.yaml         # postgres:18-alpine
│   ├── Dockerfile           # multi-stage, eclipse-temurin:21-jre (Render)
│   └── .env.exemplo
├── android/                 # app Kotlin + Jetpack Compose
│   ├── app/src/main/java/br/com/somaisuma/app/{di,data,model,ui,util}
│   ├── app/src/test/java    # ViewModels com FakeApiService
│   └── gradle/libs.versions.toml
├── docs/                    # 00-indice.md ... 23-plano-de-testes.md
├── scripts/                 # *.http (token sandbox, cadastrar-webhook), reset-demo.sql
├── .github/workflows/ci.yml
├── CONTRIBUTING.md
└── README.md
```

## Pré-requisitos

| Ferramenta | Versão | Observação |
|---|---|---|
| JDK | 21 (Temurin) | `java -version` deve mostrar 21; o mesmo JDK serve para Gradle, Android Studio e Spring |
| Android Studio | Quail 4 (2026.1.4) ou superior | inclui SDK 37 e emulador |
| Docker Desktop | atual | precisa estar rodando para `docker compose` e para os testes `*IT` |
| Git | 2.40+ | — |
| Opcional | `adb` (vem com o Android SDK Platform-Tools), `curl`, `openssl` | instalação do APK e testes do sandbox Inter |

## Backend: instalação e execução

```bash
git clone https://github.com/<org>/so-mais-uma.git
cd so-mais-uma/backend
cp .env.exemplo .env            # edite JWT_SECRET e DEV_KEY (sem commitar o .env)
docker compose up -d            # sobe o PostgreSQL 18 (porta 5432)
./gradlew bootRun               # profile padrão: simulado (usa o .env via spring.config.import ou export)
```

No Windows use `gradlew.bat bootRun`. O `spring-boot-docker-compose` também sobe o banco sozinho ao rodar `bootRun`, então o `docker compose up -d` é opcional em dev. Flyway aplica `db/migration/V1__init.sql` (5 tabelas + índice único parcial) no primeiro start. Toda evolução de esquema começa em `V3__...`.

`backend/.env.exemplo` (valores de exemplo, nunca reais):

```properties
# obrigatórias em qualquer profile
spring.profiles.active=simulado          # simulado | inter-sandbox | inter-prod
JWT_SECRET=troque-por-uma-string-aleatoria-com-32-bytes-ou-mais
DEV_KEY=troque-por-uma-chave-do-endpoint-dev   # header X-Dev-Key de POST /api/v1/dev/pagamentos/{txid}/confirmar

# profile simulado
SIMULADO_PIX_CHAVE=chave-pix-ficticia@somaisuma.local   # chave usada no payload BR Code do SimuladoPixGateway
SIMULADO_PIX_NOME=SO MAIS UMA                           # nome do recebedor no payload BR Code
SIMULADO_PIX_CIDADE=SAO PAULO                           # cidade do recebedor no payload BR Code
# SIMULADO_AUTO_CONFIRMAR_SEGUNDOS=                     # confirmação automática do pagamento simulado

# opcionais (têm padrão na aplicação)
# JWT_VALIDADE_DIAS=7
# APP_FUSO_HORARIO=America/Sao_Paulo

# banco fora do docker compose (Render/Neon ou Postgres local próprio)
# spring.datasource.url=jdbc:postgresql://localhost:5432/somaisuma
# spring.datasource.username=somaisuma
# spring.datasource.password=somaisuma

# profiles inter-sandbox / inter-prod (só quem tem os arquivos; ver docs/11)
# caminho absoluto: este arquivo não passa por shell, então $HOME e ~ ficariam literais
# INTER_CLIENT_ID=
# INTER_CLIENT_SECRET=
# INTER_CRT=/home/<usuario>/.somaisuma/inter-sandbox.crt
# INTER_KEY=/home/<usuario>/.somaisuma/inter-sandbox.key
# no Windows: C:/Users/<usuario>/.somaisuma/inter-sandbox.crt
# INTER_CHAVE_PIX=
# INTER_WEBHOOK_SEGREDO=            # segmento secreto da URL de callback (UUID sem hifens); só se o webhook for cadastrado
# INTER_ESCOPOS=cob.write cob.read pix.read pix.write webhook.write webhook.read
```

O `.env` é carregado pela aplicação como arquivo de propriedades (`spring.config.import=optional:file:.env[.properties]`), não é interpretado por um shell: por isso os caminhos são absolutos e as propriedades do Spring aparecem na forma canônica com pontos e minúsculas. As versões em maiúsculas com sublinhado (`SPRING_PROFILES_ACTIVE`, `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`) só recebem a conversão automática de nome quando são variáveis de ambiente de verdade — use-as no `export` do shell e no painel do Render; dentro do arquivo, valem as chaves com pontos. As demais chaves (`JWT_SECRET`, `DEV_KEY`, `INTER_*`) são lidas por placeholder `${...}` nos `application*.yml` e funcionam igual nos dois lugares.

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

## App Android: execução

1. Abrir a pasta `android/` no Android Studio Quail 4 (File > Open) e aguardar o sync do Gradle (JDK 21 em Settings > Build Tools > Gradle > Gradle JDK).
2. Definir a URL do backend em `android/local.properties` (arquivo ignorado pelo Git; a propriedade vira `BuildConfig.API_BASE_URL`):

```bash
# emulador (10.0.2.2 é o localhost do computador visto pelo emulador)
API_BASE_URL=http://10.0.2.2:8080/api/v1
# celular físico na mesma rede Wi-Fi ou hotspot: IP da LAN do computador
# API_BASE_URL=http://192.168.0.10:8080/api/v1
```

   Se a propriedade não existir, o build `debug` usa `http://10.0.2.2:8080/api/v1`. Wi-Fi da faculdade bloqueando IPs locais: usar o hotspot do celular. Notebook fraco para emulador + Docker: usar celular físico via USB (`adb devices`).
3. Build variants:

| Variant | Pacote | Base URL | Cleartext HTTP | Botão "Simular pagamento" | Uso |
|---|---|---|---|---|---|
| `debug` | `br.com.somaisuma.app.debug` (`applicationIdSuffix ".debug"`) | `local.properties` ou `10.0.2.2` | permitido (`network_security_config` só em debug) | sim (`BuildConfig.DEV_KEY`, lido de `DEV_KEY=` em `android/local.properties`) | desenvolvimento, testes com usuários, kit de demo offline |
| `release` | `br.com.somaisuma.app` | URL do Render (HTTPS), fixada no `build.gradle.kts` | não | não | beta público, apresentação |

O sufixo `.debug` permite instalar as duas variantes no mesmo celular, o que o kit de demo offline exige.

4. Rodar pelo botão Run (emulador ou celular) ou gerar e instalar o APK:

```bash
cd android
./gradlew assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
# release assinado (keystore fora do repositório; ver CONTRIBUTING.md)
./gradlew assembleRelease
adb install -r app/build/outputs/apk/release/app-release.apk
```

Instalação sempre via `adb`: desde 30/09/2026 a verificação de desenvolvedor do Google no Brasil pode colocar o sideload por navegador em um fluxo com espera; `adb install` não é afetado (risco R7 em [docs/19-riscos.md](docs/19-riscos.md)). Permissões pedidas em runtime: localização (aproximada ou precisa) ao tocar "Ativar localização" na tela Quadras; notificações (Android 13+) na primeira abertura da tela Pagamento. O app funciona sem ambas, de forma degradada.

## Testes

```bash
# backend: unitários + @WebMvcTest + integração (Testcontainers exige Docker rodando)
cd backend && ./gradlew test
# só a corrida de 10 threads no mesmo slot (1x201, 9x409)
cd backend && ./gradlew test --tests '*ReservaConcorrenciaIT'
# android: ViewModels e utilitários na JVM
cd android && ./gradlew testDebugUnitTest
# android (opcional, exige emulador): teste de DAO do Room
cd android && ./gradlew connectedDebugAndroidTest
```

Relatórios em `backend/build/reports/tests/test/index.html` e `android/app/build/reports/tests/testDebugUnitTest/index.html`. Casos de teste manuais CT-01..CT-30, o que roda no CI e critérios de saída: [docs/23-plano-de-testes.md](docs/23-plano-de-testes.md). Testes com usuários (SUS): [docs/22-testes-com-usuarios.md](docs/22-testes-com-usuarios.md).

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
./gradlew bootRun
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

Cada integrante é dono de uma fatia vertical (backend + Android + documentação + testes) e suplente de outra; ninguém mergeia o próprio PR. Evidência do critério 7: `git shortlog -sn --no-merges -- backend android docs`.

| Integrante | Fatia | Suplente de |
|---|---|---|
| Integrante A | Autenticação, usuário, segurança (JWT, bloqueio de login), repositório, CI, Render/Neon, APK release, README | D |
| Integrante B | Quadra e HorarioFuncionamento (os 2 CRUDs), CEP (BrasilAPI/ViaCEP), modelagem do banco, protótipo Figma | C |
| Integrante C | Reserva, slots, concorrência (índice único + 10 threads), Room/sincronização/offline, geolocalização, testes com usuários | B |
| Integrante D | Pagamento Pix (Inter + simulado), webhook, burocracia do Inter, backlog/board, plano de testes, roteiro da demo | A |

Detalhes em [docs/15-divisao-equipe.md](docs/15-divisao-equipe.md) e regras de contribuição em `CONTRIBUTING.md`.

## Limitações conhecidas (MVP)

Fuso único `America/Sao_Paulo`; JWT de 7 dias sem revogação (logout só limpa o dispositivo); todo Pix é recebido na única chave configurada e o repasse ao dono ocorre fora do app; estorno é manual; webhook do Inter sem mTLS de entrada; sem paginação; publicação na Play Store fora do escopo. Lista completa e motivos em [docs/02-escopo-mvp.md](docs/02-escopo-mvp.md).

## Licença

Projeto acadêmico desenvolvido para a disciplina de desenvolvimento mobile (2026/2). Código-fonte sob licença MIT para fins de estudo; não há garantia de adequação a uso comercial. "Pix" é marca do Banco Central do Brasil e "Banco Inter" pertence ao respectivo titular; a integração usa o sandbox público de desenvolvedores. Nenhum dado pessoal real deve ser cadastrado nos ambientes de demonstração.
