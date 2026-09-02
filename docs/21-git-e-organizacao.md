# 21 — Git e organização do repositório

Regras de trabalho no monorepo `so-mais-uma`: estrutura, `.gitignore`, branches, commits, pull requests, issues e board, CI, rituais, prova do histórico dos quatro integrantes, política de segredos, tags de release e o README como contrato com a banca.

## 21.1 Estrutura do monorepo

Um único repositório GitHub privado (público opcional após a N2), com backend, app e documentação lado a lado. Motivo: um `git shortlog` prova o critério 7 de uma vez, um PR pode alterar contrato e tela juntos, e o board tem uma fonte só.

```text
so-mais-uma/
├── README.md                      # contrato com a banca (seção 21.12)
├── CONTRIBUTING.md                # resumo operacional deste documento + armadilhas de toolchain
├── .gitignore
├── .github/
│   ├── workflows/ci.yml           # build backend + assembleDebug (seção 21.7)
│   ├── PULL_REQUEST_TEMPLATE.md
│   ├── ISSUE_TEMPLATE/tarefa.md
│   ├── ISSUE_TEMPLATE/bug.md
│   └── CODEOWNERS                 # titular + suplente por pasta (recomendado)
├── backend/                       # Spring Boot 4.1, JDK 21, Gradle Kotlin DSL
│   ├── build.gradle.kts
│   ├── settings.gradle.kts
│   ├── gradlew, gradlew.bat, gradle/
│   ├── compose.yaml               # postgres:18-alpine
│   ├── Dockerfile                 # multi-stage, eclipse-temurin:21-jre
│   ├── .env.exemplo               # nomes das variaveis, sem valores
│   └── src/
│       ├── main/java/br/com/somaisuma/
│       │   ├── config/ security/ controller/ service/ repository/
│       │   ├── entity/ dto/ exception/
│       │   └── integracao/pix/ integracao/pix/inter/ integracao/cep/
│       ├── main/resources/
│       │   ├── application.yml
│       │   ├── application-simulado.yml
│       │   ├── application-inter-sandbox.yml
│       │   ├── application-inter-prod.yml
│       │   └── db/migration/V1__init.sql
│       └── test/java/br/com/somaisuma/
├── android/                       # Kotlin 2.4.10, AGP 9.4, Compose BOM 2026.08.00
│   ├── build.gradle.kts
│   ├── settings.gradle.kts
│   ├── gradle/libs.versions.toml  # todas as versoes fixadas
│   └── app/
│       ├── build.gradle.kts
│       └── src/
│           ├── main/java/br/com/somaisuma/app/
│           │   ├── di/ data/remote/ data/local/ data/repository/
│           │   ├── model/ ui/navigation/ ui/theme/ ui/components/
│           │   ├── ui/auth/ ui/quadras/ ui/reservas/ ui/pagamento/ ui/dono/ ui/perfil/
│           │   └── util/
│           ├── main/res/xml/network_security_config.xml
│           ├── test/                # ViewModels com fakes
│           └── androidTest/         # QuadraDaoTest (recomendado)
├── docs/                          # 00-indice.md ... 23-plano-de-testes.md
│   ├── prototipo/                 # export do prototipo do Figma (figma-cp1.pdf)
│   ├── apresentacao/              # n1.pdf, n2.pdf
│   ├── anexos/                    # anexos de docs/22 e docs/23
│   ├── atas/                      # AAAA-MM-DD.md, uma por ritual
│   ├── api/                       # openapi-n1.json
│   └── imagens/                   # DER, prints, diagramas exportados
└── scripts/
    ├── inter/                     # roteiros do Inter (docs/11 secao 13)
    │   ├── 01-token.http          # token OAuth2 + mTLS
    │   ├── 02-criar-cob.http      # PUT /pix/v2/cob/{txid}
    │   ├── 03-consultar-cob.http  # GET /pix/v2/cob/{txid}
    │   ├── 04-pagar-sandbox.http  # POST /pix/v2/cob/pagar/{txid}
    │   ├── 05-webhook-cadastrar.http
    │   ├── 06-webhook-consultar.http
    │   └── 07-webhook-remover.http
    ├── api/                       # roteiros da propria API (inclui pagamento-dev.http)
    ├── http-client.env.json       # variaveis sem valores (versionado)
    ├── http-client.private.env.json  # valores reais (ignorado)
    ├── seed-demo.sql              # dados de demonstracao (psql; fora do Flyway)
    ├── reset-demo.sql             # limpa reservas/pagamentos e recria a quadra de teste
    └── kit-demo-offline/          # compose.yaml (postgres + jar) + README
```

Regras: nada fora dessas pastas; arquivos gerados (`build/`, `.gradle/`, `.idea/`) nunca entram; `docs/imagens/` guarda PNG/SVG exportados (o Figma fica no link, com backup em PDF em `docs/prototipo/`); o keystore de release fica fora do repositório com o integrante A e uma cópia no gerenciador de senhas do grupo.

## 21.2 `.gitignore` essencial (primeiro commit)

```gitignore
# Segredos e credenciais - nunca versionar
.env
.env.*
!.env.exemplo
*.crt
*.key
*.pem
*.pfx
*.p12
*.jks
*.keystore
keystore.properties
local.properties
google-services.json
scripts/http-client.private.env.json

# Build e caches
build/
.gradle/
out/
*.class
*.jar
!gradle/wrapper/gradle-wrapper.jar
*.apk
*.aab
captures/
.cxx/

# IDE e sistema operacional
.idea/
*.iml
.vscode/
.DS_Store
Thumbs.db

# Logs e temporarios
*.log
*.tmp
hs_err_pid*
```

O CI (seção 21.7) falha se um arquivo `*.key`, `*.crt`, `*.pfx`, `*.jks` ou `.env` aparecer no diff; a política completa está na seção 21.10.

## 21.3 Estratégia de branches

| Branch | Uso | Regra |
|---|---|---|
| `main` | Sempre executável em profile `simulado`; é o que roda na demo interna de sexta | Protegida: PR obrigatório, 1 aprovação (do suplente), CI verde, sem force push, sem commit direto, conversas resolvidas |
| `feat/<area>-<descricao>` | Funcionalidade nova. Ex.: `feat/reserva-indice-unico-parcial`, `feat/quadras-tela-lista` | Vida máxima de 5 dias úteis; nasce da `main`; um PR por branch |
| `fix/<area>-<descricao>` | Correção de bug. Ex.: `fix/pagamento-polling-backoff` | Idem |
| `docs/<assunto>` | Só documentação. Ex.: `docs/08-modelagem-banco` | Revisão leve (um comentário "ok" basta) |
| `chore/<assunto>` | Build, CI, versões, `.gitignore`. Ex.: `chore/ci-assemble-debug` | Idem `feat` |
| `spike/<nome>` | Experimentos de aprendizado (S1) | Nunca mesclada; apagada após a S2 |
| `release/n1`, `release/beta` | Congelamento para a N1 (ter 29/09) e para o CP2 (qua 04/11) | Só `fix/` entra, via PR; a `main` continua recebendo funcionalidades; tag criada a partir dela |

Áreas válidas em nomes de branch e escopo de commit: `auth`, `usuario`, `quadra`, `horario`, `slot`, `reserva`, `pagamento`, `pix`, `cep`, `geo`, `sync`, `notificacao`, `ui`, `infra`, `docs`, `testes`.

Fluxo diário:

```bash
git switch main && git pull
git switch -c feat/reserva-cancelar-cliente
# ... commits pequenos ...
git fetch origin && git rebase origin/main      # antes de abrir o PR, para o CI rodar sobre a main atual
git push -u origin feat/reserva-cancelar-cliente
gh pr create --fill                             # ou pelo site, com o template
```

Método de merge no GitHub: "Create a merge commit" (ou "Rebase and merge"). Squash é proibido: ele apagaria o commit do revisor no PR de tela e reduziria o histórico individual que o critério 7 exige. Depois do merge, a branch é apagada automaticamente (configuração do repositório).

## 21.4 Convenção de commits

Formato Conventional Commits em português:

```text
<tipo>(<escopo>): <descricao no imperativo, minuscula, sem ponto final> (#<issue>)

<corpo opcional: o porque da mudanca, nao o que - o diff ja mostra o que>

Co-authored-by: Nome <email-do-github>   # quando dois programaram juntos
```

| Tipo | Quando usar |
|---|---|
| `feat` | Funcionalidade nova visível (endpoint, tela, regra) |
| `fix` | Correção de comportamento errado |
| `test` | Só testes (novo teste, fake, fixture) |
| `docs` | Só arquivos em `docs/`, README ou comentários |
| `refactor` | Mudança interna sem alterar comportamento |
| `chore` | Build, versões, `.gitignore`, scripts |
| `ci` | Workflow do GitHub Actions |
| `style` | Formatação sem mudança de lógica (raro; evitar PR só disso) |

Regras: um commit por ideia (a regra prática é "o título cabe em 72 caracteres sem 'e'"); referência à issue em todo commit de `feat`, `fix` e `test`; identificadores exatamente como no código (`ux_reserva_slot_ativo`, `ReservaFacade`); acentuação permitida no texto, opcional; nada de `wip`, `ajustes`, `final`, `final2`. Trabalho em par recebe `Co-authored-by` para que os dois apareçam em Insights.

| Bom | Ruim | Por quê |
|---|---|---|
| `feat(reserva): cria indice unico parcial anti-dupla-reserva (#12)` | `ajustes no banco` | Diz o que entrou e onde; rastreável à issue |
| `fix(pagamento): aplica backoff de 5 s para 10 s no polling apos 2 min (#41)` | `fix bug` | Nomeia o comportamento corrigido |
| `test(reserva): adiciona ReservaConcorrenciaIT com 10 threads no mesmo slot (#12)` | `testes` | Nomeia a classe e o cenário |
| `docs(08): descreve ux_reserva_slot_ativo e RN08 na modelagem (#20)` | `atualiza docs` | Nomeia o documento e o conteúdo |
| `feat(quadras): adiciona busca de CEP com preenchimento de lat/lon no FormQuadra (#27)` | `tela de quadra pronta` | Escopo certo, verbo no imperativo, issue |
| `chore(infra): fixa Kotlin 2.4.10 e AGP 9.4.0 no catalogo de versoes (#3)` | `update gradle` | Versões explícitas, em português |
| `refactor(auth): extrai LoginTentativasService do AuthService (#8)` | `refatoracao geral` | Uma mudança, nomeada |

## 21.5 Pull requests

| Regra | Detalhe | Prioridade |
|---|---|---|
| Tamanho | Menos de 400 linhas alteradas (sem contar arquivos gerados e `scripts/seed-demo.sql`); acima disso, o revisor pode pedir para dividir | Obrigatório |
| Revisão | 1 aprovação do suplente da fatia (A<->D, B<->C); se o suplente não responder em 24 h úteis, qualquer outro integrante revisa; ninguém aprova o próprio PR | Obrigatório |
| CI | Verde (build backend com testes + `assembleDebug` + verificação de segredos) | Obrigatório |
| Título | Mesma convenção do commit: `feat(reserva): tela ConfirmarReserva com tratamento de 409/422/502 (#33)` | Obrigatório |
| Commit do revisor | Em PR de tela, o revisor faz ao menos um commit de acessibilidade (contentDescription, alvos de 48 dp, `ImeAction.Next`, texto de erro) antes de aprovar | Obrigatório |
| Rascunho | PR aberto como Draft assim que a branch existe, para o grupo ver o andamento | Recomendado |
| Prazo | Revisão em até 24 h úteis; PR aberto há mais de 48 h é assunto do ritual de segunda | Obrigatório |
| Segredos | O revisor olha o diff inteiro procurando `.env`, chaves, tokens, URLs com credencial | Obrigatório |

`.github/PULL_REQUEST_TEMPLATE.md`:

```markdown
## O que este PR entrega
<!-- uma frase; qual RF/RN/RNF ele cobre, ex.: RF13 + RN08 -->

## Issue
Fecha #

## Fatia completa?
- [ ] Endpoint no Swagger (ou N/A)
- [ ] Tela funcionando contra a API real (ou N/A)
- [ ] Cache/Room atualizado (ou N/A)
- [ ] Teste automatizado incluido
- [ ] Documento da fatia atualizado (docs/xx)

## Como testar
<!-- passos exatos: profile, usuario de seed, rota, o que esperar -->

## Checklist
- [ ] Menos de 400 linhas
- [ ] Nenhum segredo, certificado ou .env no diff
- [ ] Contrato aditivo (nenhum campo removido/renomeado apos a N1)
- [ ] Migrations aditivas (V1__init.sql nao editado apos a N1; toda mudanca de esquema entra como V2, V3, ...)
- [ ] Nenhum item Must Have com bug aberto (se este PR for Should/Could)
- [ ] Em PR de tela: commit de acessibilidade do revisor
```

Checklist do revisor (em 10 min): roda o `main` + a branch localmente ou lê o "Como testar"; confere se o nome dos identificadores segue docs/08 e docs/10; procura `com.fasterxml.jackson`, `kapt`, `@MockBean`, `@Data` em entidade; confere estados carregando/vazio/erro em tela nova; faz o commit de acessibilidade; aprova ou pede mudança com comentário objetivo.

## 21.6 Issues, labels, milestones e board

Toda tarefa é uma issue antes de virar branch. Issues são criadas pelo titular da fatia; D é o dono do board (docs/15-divisao-equipe.md) e garante que nada está "Em andamento" sem estimativa.

| Grupo de labels | Valores | Uso |
|---|---|---|
| Prioridade (obrigatório, uma por issue) | `must-n1`, `must-n2`, `should`, `could`, `fora-mvp` | Equivalem a Must Have (N1), Must Have (N2), Should Have, Could Have, Fora do MVP de docs/14-backlog.md |
| Camada (uma ou mais) | `backend`, `android`, `docs`, `infra` | Permite ver no board se cada integrante está tocando as três pastas |
| Estimativa (obrigatório; campo personalizado do board, não label) | `P` (<= 3 h), `M` (<= 8 h), `G` (<= 16 h, precisa ser quebrada) | Base do cálculo de 40 h/semana |
| Tipo | `bug`, `usabilidade`, `risco`, `contrato`, `inter`, `spike` | `usabilidade` vem dos testes da S11 com a severidade em label própria; `risco` cita o ID de docs/19-riscos.md; `contrato` exige aprovação de A e B; `inter` é burocracia do banco com data; `spike` é experimento de aprendizado |
| Severidade (só em `bug` e `usabilidade`) | `sev-1`, `sev-2`, `sev-3`, `sev-4` | Escala de docs/22-testes-com-usuarios.md, seção 9 |
| Área | `auth`, `usuario`, `quadra`, `horario`, `reserva`, `pagamento`, `geo`, `sync` | Mesmos nomes dos escopos de commit |

| Milestone | Data | Conteúdo mínimo |
|---|---|---|
| `CP1` | 11/09/2026 | Escopo, protótipo navegável, backlog priorizado, lista Fora do MVP |
| `N1` | 02/10/2026 | 7 telas funcionais, CRUD x2, CEP, backend de reserva via Swagger, docs 01-09, README |
| `CP2` | 06/11/2026 | Beta funcional em `inter-sandbox` ou `simulado`, geolocalização, offline, deploy |
| `N2` | 11/12/2026 | App completo, APK, testes, documentação final, apresentação |

Board (GitHub Projects, visão por status, dono D — mesmas colunas de docs/14-backlog.md, seção 14.14): `Backlog` -> `Semana atual` (tem estimativa e milestone) -> `Em andamento` (máximo 2 por pessoa) -> `Em revisão` (PR aberto) -> `Concluído` (PR mesclado na `main`). A estimativa P/M/G é um campo personalizado do Projects, não uma label. Filtro salvo por integrante e por milestone; A confere na segunda se há item `Em andamento` há mais de uma semana.

`.github/ISSUE_TEMPLATE/tarefa.md`:

```markdown
---
name: Tarefa
about: Item do backlog (RF, RNF, RN, doc ou infra)
labels: ''
---
**Requisito:** RFxx / RNxx / RNFxx (ou doc/infra)
**Fatia:** backend / android / docs / infra
**Criterio de pronto:**
- [ ] ...
**Estimativa:** P / M / G
**Dependencias:** #
```

## 21.7 CI mínima (GitHub Actions)

`.github/workflows/ci.yml`:

```yaml
name: ci
on:
  pull_request:
  push:
    branches: [main]

jobs:
  segredos:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Bloqueia certificados, chaves e .env versionados
        run: |
          if git ls-files | grep -E '(^|/)(\.env(\..*)?|.*\.(key|crt|pem|pfx|p12|jks|keystore))$' | grep -v '\.env\.exemplo$'; then
            echo 'Segredo versionado encontrado'; exit 1; fi

  backend:
    runs-on: ubuntu-latest
    defaults: { run: { working-directory: backend } }
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { distribution: temurin, java-version: '21' }
      - uses: gradle/actions/setup-gradle@v4
      - name: Build e testes (Testcontainers usa o Docker do runner)
        run: ./gradlew build --no-daemon
        env:
          SPRING_PROFILES_ACTIVE: simulado
          JWT_SECRET: ci-somente-teste-chave-com-mais-de-32-bytes-0123
          DEV_KEY: ci-dev-key

  android:
    runs-on: ubuntu-latest
    defaults: { run: { working-directory: android } }
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { distribution: temurin, java-version: '21' }
      - uses: gradle/actions/setup-gradle@v4
      - name: Testes unitarios e APK debug
        run: ./gradlew testDebugUnitTest assembleDebug --no-daemon
```

O que a CI garante: backend compila e passa nos testes (incluindo `ReservaConcorrenciaIT` com Testcontainers, pois o runner `ubuntu-latest` tem Docker); Android compila, roda os testes de ViewModel e gera o APK debug; nenhum segredo está versionado. O que ela não faz (decisão consciente): testes instrumentados com emulador, análise estática, deploy (o Render faz deploy por push na `main`). Recomendado, se sobrar tempo na S9: job `gitleaks/gitleaks-action` para varrer o histórico, e job de release que anexa o APK à tag.

O badge do CI vai na primeira linha do README.

## 21.8 Rituais

| Quando | Duração | O que acontece | Registro |
|---|---|---|---|
| Segunda, 30 min | Planejamento | Cada um diz o que entrega até sexta (issues com estimativa); redistribuição de tarefa atrasada há mais de 1 semana; PRs abertos há mais de 48 h | Comentário na issue "Ritual de segunda Sxx" |
| Sexta, 15 min | Demo interna | Cada um mostra o que roda a partir do `main` (não da branch); A roda `git shortlog -sn --no-merges -- backend android docs` e percorre docs/19-riscos.md; D atualiza o board | Saída do shortlog e riscos disparados na issue "Ritual de sexta Sxx" |
| Diário, assíncrono | 1 mensagem | "Ontem / hoje / bloqueio" no chat do grupo; bloqueio vira issue se durar mais de 1 dia | Chat |
| Revisão de PR | Até 24 h úteis | Suplente revisa; após 24 h qualquer um | GitHub |
| Datas do Inter | 29/09, 27/10, 24/11 | Renovação do certificado sandbox (D, suplente A) | Issues `inter` datadas |
| Congelamentos | 29/09, 04/11, 25/11 | `release/n1`, `release/beta`, última funcionalidade | Tags (seção 21.11) |

## 21.9 Como provar o histórico dos quatro

Critério 7 da disciplina: commits dos quatro, descritivos, com divisão clara. A prova em menos de 1 minuto na apresentação:

```bash
# visao geral (sem merges, por pasta)
git shortlog -sn --no-merges -- backend android docs
# por camada, para mostrar que todos tocaram backend E android
git shortlog -sn --no-merges -- backend
git shortlog -sn --no-merges -- android
git shortlog -sn --no-merges -- docs
# historia de um integrante em uma area
git log --no-merges --date=short --format='%h %ad %an %s' --author='Integrante B' -- android
# commits por semana (para o relatorio final)
git log --no-merges --date=format:'S%V' --format='%ad %an' | sort | uniq -c
```

No GitHub: Insights > Contributors (gráfico por pessoa), Insights > Pulse (PRs e revisões da semana) e a aba de PRs filtrada por `reviewed-by:` para provar a revisão cruzada.

Armadilhas e como evitar:

| Armadilha | Efeito | Prevenção |
|---|---|---|
| `user.email` diferente do e-mail do GitHub | Commits sem avatar e fora do gráfico de Contributors | Conferir no dia 1; se já aconteceu, arquivo `.mailmap` na raiz mapeando e-mails para o nome canônico |
| Squash merge | Commits do revisor desaparecem; um PR vira um commit | Método de merge fixado em "Create a merge commit" |
| Um integrante só em `docs/` | Critério 7 pede código dos quatro | Fatias verticais; shortlog de sexta por pasta; issue P de código para quem estiver zerado |
| Commits gigantes na véspera | Histórico não descritivo | PR < 400 linhas; commits por ideia; CI por PR |
| Commit em nome do colega (mesmo notebook) | Atribuição errada | Cada um usa a própria máquina ou `git -c user.name=... -c user.email=... commit` e `Co-authored-by` |

Meta verificável: até 25/09 cada integrante tem commits em `backend/`, `android/` e `docs/`; até 27/11 nenhum integrante tem menos de 15 % dos commits sem merge. O consolidado por semana vai para docs/15-divisao-equipe.md na S12.

## 21.10 Política de segredos e resposta a vazamento

| Segredo | Dev local | CI | Render | Nunca |
|---|---|---|---|---|
| `JWT_SECRET` (>= 32 bytes) | `.env` ignorado, carregado pela IDE ou `export` | GitHub Secret | Environment variable | No `application*.yml`, no código, no chat |
| `DEV_KEY` (header `X-Dev-Key`) | `.env` | GitHub Secret | Environment variable | Idem |
| `INTER_CLIENT_ID`, `INTER_CLIENT_SECRET`, `INTER_CHAVE_PIX` | `.env` de quem tem acesso (D, A) | Não usado (CI roda em `simulado`) | Environment variable | Idem |
| `INTER_CRT`, `INTER_KEY` (arquivos) | `~/inter/` fora do repositório | Não usado | Secret Files | No repositório, em anexo de issue, em print |
| Keystore de release e senhas | Com A, fora do repositório; cópia no gerenciador de senhas | Não usado | Não usado | Idem |
| Senhas do Neon/Render | Painel dos serviços; gerenciador de senhas | — | — | Idem |
| Senha `Senha123` dos usuários de seed | `scripts/seed-demo.sql` (dado público de demonstração) | ok | Só com profile que carrega o seed | Não é segredo, mas nunca reutilizar em conta real |

Regras: `.env.exemplo` versionado com os nomes das variáveis e valores vazios; `application-inter-*.yml` referencia só `${VARIAVEL}`; segredos são compartilhados por gerenciador de senhas do grupo (cofre compartilhado), nunca por chat em texto plano; antes de cada commit, `git diff --cached --stat` para conferir os arquivos incluídos; o job `segredos` do CI e a revisão de PR são a segunda barreira; se o repositório for público, ativar Secret scanning e Push protection nas configurações do GitHub (gratuitos em repositórios públicos); em repositório privado, o job `gitleaks` (recomendado) cobre.

Se um segredo vazar (mesmo em branch, mesmo por 1 minuto), nas próximas 24 h:

1. Avisar o grupo no chat e abrir issue `risco R15` com o que vazou e o commit.
2. Revogar antes de limpar: `JWT_SECRET` e `DEV_KEY` novos no Render e nos `.env` (todos os usuários precisarão logar de novo, aceitável no beta); credenciais Inter: cancelar a integração no portal (irreversível) e criar uma nova, baixando novo `.crt/.key`; keystore de release vazado: gerar keystore novo (os APKs anteriores deixam de atualizar por cima; reinstalar via `adb`).
3. Remover do histórico com `git filter-repo` (nunca só um commit "remove segredo": o histórico continua acessível) e fazer force push da `main` com o grupo avisado; todos clonam de novo.
4. Conferir forks, PRs fechados e artefatos do CI que possam ter cópia.
5. Registrar em docs/19-riscos.md a data, a causa e a correção do processo (ex.: novo padrão no `.gitignore`).

## 21.11 Tags de release

Tags anotadas a partir da branch de congelamento (ou da `main` quando não houver), com GitHub Release contendo notas curtas e, a partir do beta, o APK como anexo.

| Tag | Data | Criada a partir de | Conteúdo | Anexos |
|---|---|---|---|---|
| `v0.1-n1` | 29/09 a 02/10 | `release/n1` | Entrega N1: 7 telas, CRUD x2, CEP, backend de reserva, docs 01-09, README | Vídeo de 2 min (link) |
| `v0.2-beta` | 04/11 | `release/beta` | Beta do CP2: fluxo completo em `inter-sandbox`/`simulado`, geolocalização, offline, deploy | `app-release.apk`, `app-debug.apk` (kit offline) |
| `v0.9-rc` | 20/11 | `main` | Correções dos testes com usuários | APK |
| `v1.0-rc1` | 27/11 | `main` | Escopo congelado | APK final candidato |
| `v1.0` | 04/12 | `main` | Versão da apresentação; documentação final | `app-release.apk`, `app-debug.apk`, jar do backend para o kit offline |

```bash
git switch release/n1 && git pull
git tag -a v0.1-n1 -m "Entrega N1: 7 telas, CRUD Quadra e HorarioFuncionamento, CEP, backend de reserva"
git push origin v0.1-n1
gh release create v0.1-n1 --title "v0.1-n1" --notes-file docs/17-checklist-n1.md
```

Depois da tag, nenhuma mudança na branch de release; correções vão para a `main` e, se necessário, geram `v0.1.1-n1`.

## 21.12 README como contrato

O README é a primeira coisa que a banca abre e a última que o grupo pode explicar pessoalmente; ele é tratado como um contrato: tudo o que está lá funciona em uma máquina limpa, e o que não funciona não está lá. Dono: A; revisão obrigatória por outro integrante em máquina limpa antes da N1 (29/09) e antes da N2 (04/12).

Seções obrigatórias, nesta ordem:

1. Nome, uma frase do produto, badge do CI, link para docs/00-indice.md.
2. Integrantes, fatias e suplentes (tabela de docs/15-divisao-equipe.md resumida).
3. Stack e tabela de versões fixadas, com a data de verificação (01/09/2026).
4. Pré-requisitos (JDK 21, Docker, Android Studio Quail 4, `adb`).
5. Como rodar o backend em 3 comandos (`git clone`, `cd backend`, `./gradlew bootRun`) e o que esperar (`/actuator/health`, Swagger, usuários de seed `cliente@demo.com` e `dono@demo.com` com senha `Senha123`).
6. Como rodar o app (abrir `android/` no Android Studio, `API_BASE_URL` por build type, `10.0.2.2` no emulador, IP da LAN no celular, `adb install`).
7. Profiles e variáveis de ambiente (`simulado` padrão; `inter-sandbox` e `inter-prod` com a lista de variáveis do `.env.exemplo`); aviso de que o sandbox funciona só entre 8h e 20h, de segunda a sexta.
8. Como rodar os testes (`./gradlew test` no backend, `./gradlew testDebugUnitTest` no Android) e o que o `ReservaConcorrenciaIT` prova.
9. Backlog e board (link do Projects) e convenções (link para este documento e para o `CONTRIBUTING.md`).
10. Matriz critério da disciplina -> evidência -> onde ver (uma linha por critério, apontando arquivo, tela ou comando).
11. Limitações conhecidas (JWT sem revogação, fuso único, Pix recebido na chave da plataforma, estorno manual, sem mTLS de entrada no webhook).

Critério de aceite do README: um integrante que não escreveu o código clona o repositório numa máquina sem nada configurado e, seguindo apenas o README, sobe o backend, instala o app e faz login em até 10 minutos.

## 21.13 `CONTRIBUTING.md` e `CODEOWNERS`

`CONTRIBUTING.md` (dono A) é a versão de uma página deste documento: fluxo de branch, formato de commit, checklist de PR, e a lista de armadilhas da toolchain que cada um descobriu no spike (imports `tools.jackson.*`, lambda DSL do Security 7, `@MockitoBean`, `spring-boot-starter-webmvc`, Kotlin embutido no AGP 9, KSP em vez de KAPT, plugin do Compose na versão do Kotlin, `androidx.room3`). Toda armadilha nova encontrada durante o projeto entra ali no mesmo PR que a resolveu.

`.github/CODEOWNERS` (recomendado) faz o GitHub pedir revisão automaticamente ao titular e ao suplente de cada pasta, substituindo os placeholders pelos usuários reais:

```text
# titular + suplente por fatia (ver docs/15-divisao-equipe.md)
/backend/src/main/java/br/com/somaisuma/security/        @integrante-a @integrante-d
/backend/src/main/java/br/com/somaisuma/config/          @integrante-a @integrante-d
/backend/src/main/java/br/com/somaisuma/integracao/pix/  @integrante-d @integrante-a
/backend/src/main/java/br/com/somaisuma/integracao/cep/  @integrante-b @integrante-c
/backend/src/main/resources/db/migration/                @integrante-b @integrante-c
/android/app/src/main/java/br/com/somaisuma/app/ui/auth/       @integrante-a @integrante-d
/android/app/src/main/java/br/com/somaisuma/app/ui/quadras/    @integrante-b @integrante-c
/android/app/src/main/java/br/com/somaisuma/app/ui/dono/       @integrante-b @integrante-c
/android/app/src/main/java/br/com/somaisuma/app/ui/reservas/   @integrante-c @integrante-b
/android/app/src/main/java/br/com/somaisuma/app/ui/pagamento/  @integrante-d @integrante-a
/android/app/src/main/java/br/com/somaisuma/app/data/local/    @integrante-c @integrante-b
/.github/                                                 @integrante-a
/docs/                                                    @integrante-a
```
