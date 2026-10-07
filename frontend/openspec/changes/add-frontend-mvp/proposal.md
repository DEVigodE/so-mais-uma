## Why

O backend do "Só mais uma" já está especificado e pronto (`backend/openspec/changes/add-backend-mvp`), mas
o app não existe. `frontend/` tem só o boilerplate gerado pelo FlutterInit: um fluxo de autenticação genérico
que chama rotas inexistentes no backend (`/auth/signup` com campo `password`, `/auth/me`, `/auth/logout`,
`/auth/forgot-password`), onboarding e home de um app de viagem, e nenhuma tela do domínio. Os docs falam em
"portar as 7 telas da N1 do app Android", mas `android/` nunca existiu no Git: as 13 telas e a Splash nascem
neste change. Sem `frontend/android/`, `frontend/config/` e `assets/images/` (declarado no `pubspec.yaml`), o
job `frontend` do CI quebraria hoje no `flutter build apk --debug --dart-define-from-file=config/dev.json.exemplo`.

O calendário não tem folga: o Checkpoint 2 (sex 06/11/2026) cobra o beta funcional com APK `v0.2-beta`
instalado em 2 celulares, os testes com usuários (09 a 13/11) exigem o APK via `adb`, e a Apresentação N2 é
de 07 a 11/12/2026. Ao mesmo tempo, a documentação descreve uma arquitetura que não é a do boilerplate
(provider, MVVM em `lib/{ui,data,model}`, drift com `build_runner`), e o protótipo de alta fidelidade
(`docs/Protótipo de Alta Fidelidade/`, 17 telas em `code.html`) diverge do docs/04 em vários pontos.

Este change converte o protótipo, o docs/04, o docs/05, o docs/12 e o docs/13 em requisitos verificáveis do
app. Cada divergência é resolvida de forma explícita: o protótipo vence na UI, o docs/04 no comportamento e
o boilerplate na stack. A construção é organizada em fases até o CP2.

## What Changes

- **Regra de fidelidade ao protótipo** (regra principal de UI):
  - o `code.html` de cada tela é a referência de layout, hierarquia, componentes, ícones, textos, cores e
    espaçamento, reproduzida tela a tela;
  - os valores de exemplo do protótipo são ilustrativos e os dados reais vêm da API;
  - elemento desenhado sem dado na API e não calculável é omitido, nunca preenchido com valor inventado;
  - elemento calculável a partir da API ou do cache é implementado como cálculo;
  - o que o docs/02 coloca fora do MVP sai mesmo desenhado;
  - marcações de requisito no texto ("(RN20)", "(RF04)", "RF06 / RF09"...) saem do texto exibido.
- **Telas**: Splash, Login, Cadastro, Quadras, DetalheQuadra, ConfirmarReserva, Pagamento (com o estado
  expirado), MinhasReservas, DetalheReserva (ativa e cancelada), sheet de cancelamento do cliente, Perfil
  (CLIENTE e DONO), MinhasQuadras, FormQuadra (nova e edição), HorariosQuadra e ReservasQuadra, com os
  estados de carregando, vazio, erro e offline de RNF06.
- **Tema a partir dos tokens do protótipo**: o `ColorScheme` claro sai do `tailwind.config` dos `code.html`
  (primary `#006b2c`) no lugar do seed `#16A34A`, com esquema escuro derivado, Inter empacotada como asset e
  os raios e espaçamentos do protótipo nos tokens `App*`.
- **Contrato com o backend** conforme `docs/api/openapi-n1.json`. O app aceita qualquer 2xx nos POST, envia
  `inicio` com offset `-03:00` e lê `codigo`/`subcodigo`/`campos[]`/`reservaId` do `ProblemDetail`. Também
  junta foto, esporte e coordenadas de `quadra_cache` às reservas, porque `ReservaResponse` não os traz.
- **Comportamento que diverge do docs/04 por decisão de produto**, a favor do protótipo:
  - tocar um slot LIVRE seleciona o slot e mostra a barra "Horário selecionado / Total / Continuar", em vez
    de abrir direto a ConfirmarReserva;
  - HorariosQuadra salva em lote com um único botão, disparando as operações individuais (POST/PUT/DELETE
    por dia) na sequência;
  - o motivo do cancelamento é obrigatório também para o CLIENTE (5 a 200 caracteres);
  - a ConfirmarReserva usa o layout do protótipo no estado anterior ao POST.
- **Correções do boilerplate**:
  - auth reescrito para `/auth/registrar` e `/auth/login`;
  - saem onboarding, home, recuperação de senha e ícones de login social;
  - sai o `SessionListenerWrapper`;
  - `initialLocation` passa de `/onboarding` para `/splash`;
  - o toast global de "sem internet" do `runTask` deixa de aparecer em leituras;
  - o tamanho de referência do ScreenUtil passa de 360×690 para 390×844;
  - o `UrlLauncherService` deixa de depender de `canLaunchUrl`;
  - o `catch` vazio do `AppErrorHandler` é corrigido;
  - o `test/widget_test.dart` é substituído.
- **CI**: o job `frontend` existente passa a ficar verde e publica o APK debug como artefato, sem mudança no
  workflow.
- **BREAKING (em relação à documentação, não ao código)**: as decisões abaixo seguem o boilerplate que já
  está em `frontend/` e substituem o que docs/04, 09, 12, 13, 15, 20, 21 e 23 descrevem:
  - estado com `signals` (stores com `signal` privado exposto como `ReadonlySignal`) e DI com
    `auto_injector`, no lugar de `provider` + `ChangeNotifier`;
  - arquitetura feature-first `lib/src/features/<feature>/{data,domain,presentation}`, no lugar do MVVM em
    `lib/{ui,data,model}`;
  - erros com `FutureEither<T>` e o `Failure` selado mais `ApiFailure`, no lugar de `Resultado`/`ErroApi`;
  - estado de tela com `RequestState<T>` mais as flags de offline e de última sincronização, no lugar de
    `XxxUiState` com `copyWith`;
  - cache local com sqflite e mapeamento escrito à mão, sem `build_runner` nem json_serializable, no lugar
    de drift;
  - configuração por `--dart-define-from-file` lida em `AppConfig`, no lugar da classe `Ambiente` e do
    `flutter_dotenv`;
  - applicationId `com.corebuild.so_mais_uma`, no lugar de `br.com.somaisuma.app`;
  - idiomas pt, en e es com easy_localization (pt padrão e fallback), no lugar de "só pt-BR";
  - navegação com `AppRoutes`, dois `StatefulShellRoute.indexedStack` e `redirect` alimentado pelo signal
    do `SessionStore`;
  - versões fixadas sem `^`.

### Suposições registradas

1. **Sincronização das reservas**: os dois perfis sincronizam `reserva_cache` com uma única chamada
   `GET /reservas`, sem `situacao`. Essa chamada já devolve as futuras e as dos últimos 12 meses. Ela
   substitui as duas chamadas do CLIENTE e a `?situacao=PROXIMAS` do DONO previstas em docs/12. As métricas
   do dia (MinhasQuadras e ReservasQuadra) precisam das reservas de hoje já encerradas, que `PROXIMAS` omite.
2. **Pagamento na listagem**: `GET /reservas` e `GET /quadras/{id}/reservas` devolvem `pagamento` nulo,
   porque o controller monta a resposta sem a cobrança. Por isso:
   - a substituição de `reserva_cache` preserva, pelo `id`, as colunas de pagamento já gravadas;
   - essas colunas só mudam com respostas que trazem a cobrança: criação, detalhe, edição, cancelamento e
     polling;
   - "Pago via Pix" é derivado do status `CONFIRMADA`.
3. **Colunas e chaves além de docs/12**:
   - `reserva_cache` ganha `cancelado_em`, `criado_em`, `pago_em` e `pagamento_provedor`, que a tela de
     reserva cancelada e o bloco de pagamento exibem;
   - `quadra_cache` ganha `cep`, necessário para editar a quadra a partir do cache;
   - a sessão ganha `usuario_email` e `usuario_telefone`, que o Perfil offline de docs/12 §12.6 exibe.
4. **Splash visível por no mínimo 1 s**: o native splash fica até a sessão sair de `SessionUnknown`. Depois
   disso, o `redirect` só deixa `/splash` quando a sessão está resolvida e a Splash do protótipo esteve na
   tela por 1 s. Sem esse mínimo, a tela desenhada nunca apareceria (docs/04 §3.0 previa < 300 ms).
5. **Pacote adicional**: `package_info_plus` 10.2.2 entra fixado para mostrar a versão real na Splash, no
   Login e no Perfil. Hoje ele chega só como dependência transitiva de `app_version_update`, que sai.
6. **Versões herdadas**:
   - os pacotes que já existem ficam fixados nas versões resolvidas hoje no `pubspec.lock`, sem saltos de
     versão major (por exemplo `cached_network_image` 3.4.1 e `internet_connection_checker_plus` 2.9.1+2);
   - `intl` 0.20.3 e `fake_async` 1.3.3 só entram se forem as versões exigidas pelo `flutter_localizations` e
     pelo `flutter_test` do Flutter 3.47.6; senão, ficam as do SDK;
   - o notebook de referência roda Flutter 3.44.2 (Dart 3.12.2) e precisa subir para 3.47.6, porque o
     `sdk: ^3.13.0` não resolve em versão anterior.
7. **Conectividade medida contra o backend**: "online" significa backend alcançável. O
   `internet_connection_checker_plus` é configurado para checar o `/actuator/health` derivado de
   `API_BASE_URL`. Assim, o kit de demo offline em hotspot sem internet não desabilita as escritas.
8. **Raios do protótipo**: valem os do `tailwind.config` dos `code.html` (`DEFAULT` 4, `lg` 8, `xl` 12, mais
   `2xl` 16 e `3xl` 24 do Tailwind), que divergem do frontmatter do `athletic_modernist/DESIGN.md`. A paleta
   da prosa desse arquivo (`#16A34A`, `#0F172A`...) não é usada.
9. **Resoluções de fidelidade não listadas no pedido**:
   - Futsal usa `sports_soccer`, porque o `cloud_upload` do protótipo é erro evidente; Tênis e Padel usam
     `sports_tennis`;
   - o provedor `INTER` é sempre rotulado como sandbox;
   - a linha "Aprovado pelo Banco Central • Liquidação instantânea" passa a mostrar o rótulo do provedor;
   - "gratuito e integral" perde "e integral" (RN14 não garante devolução);
   - saem os botões de ajuda e de notificações, o par "CONNECTING"/"FastBoot" da Splash, o mapa estático do
     detalhe da reserva e a frase "Estorno direto com arena realizado";
   - o selo "Online"/"Conectado"/"tempo real" reflete a conectividade.
10. **Validadores**:
    - espelham o Bean Validation do backend;
    - onde o protótipo e o docs/04 são mais estritos e concordam (nome com 2 a 100 caracteres, telefone com
      10 ou 11 dígitos), vale o mais estrito;
    - o preço segue o backend (maior que zero, até 8 dígitos inteiros e 2 decimais) e não a faixa
      1,00–9.999,99 do docs/04;
    - o telefone é enviado só com dígitos.
11. **Rota do DONO para o detalhe**: tocar o card em MinhasQuadras abre a DetalheQuadra do DONO em
    `/dono/quadras/:id`, sem grade e sem barra. Sem essa rota, RF08 seria inalcançável para o DONO, porque o
    link "ver como cliente" está fora do escopo.
12. **URL de produção**: `config/release.json` traz a URL do Render quando o backend for publicado (tarefa
    13.2 do backend). Até lá, o arquivo tem um marcador e o APK release não é distribuído.
13. **Ambiente dos testes com usuários**: toda a especificação assume o backend no profile `simulado` para
    desenvolvimento, CI e testes com usuários. O provedor `INTER` só muda o rótulo da tela Pagamento.

## Capabilities

### New Capabilities

- `plataforma-app`: projeto Android, configuração por ambiente, DI, tema a partir dos tokens do protótipo,
  i18n pt/en/es, cliente HTTP com `AuthInterceptor` (401 `TOKEN_INVALIDO` limpa sessão e cache uma única
  vez), conversão de `ProblemDetail` em `Failure`, formatadores, validadores, componentes do domínio, regra
  de fidelidade ao protótipo, acessibilidade básica (RNF07) e CI.
- `sessao-e-navegacao`: Splash, Login e Cadastro com auto-login, sessão persistente (token no secure storage,
  demais chaves no shared_preferences), `redirect` por sessão e perfil, dois shells com bottom-nav por perfil
  e as regras de pilha de docs/04 §4.3.
- `perfil-usuario`: Perfil nos dois shells (variantes CLIENTE e DONO) com `GET/PUT /usuarios/me`, troca de
  senha, preferência de notificação, última sincronização, versão e Sair.
- `quadras-cliente`: catálogo com busca por cidade ou bairro e chips de esporte aplicados localmente sobre
  `GET /quadras`, e a parte estática da DetalheQuadra com os horários agrupados.
- `quadras-dono`: MinhasQuadras com métricas calculadas, desativação com o 409 `QUADRA_COM_RESERVAS`, e
  FormQuadra (nova e edição) com busca de CEP pelo backend.
- `horarios-funcionamento`: HorariosQuadra com 7 cartões, salvamento em lote por operações individuais e
  tratamento de 409 por linha.
- `reservas-cliente`: grade de slots com seleção e barra Continuar, ConfirmarReserva, MinhasReservas,
  DetalheReserva com edição da observação e o sheet de cancelamento do cliente.
- `pagamento-pix`: tela Pagamento com QR gerado localmente, copia e cola, contador, polling com backoff,
  simulação em debug, cancelamento da pendente e estado expirado.
- `reservas-dono`: ReservasQuadra como aba e por quadra, com resumo do dia calculado, contato do cliente e
  cancelamento com motivo.
- `cache-offline`: banco local sqflite com `quadra_cache` e `reserva_cache`, sincronizador "cache primeiro,
  rede depois, servidor vence", escritas só online e o comportamento tela a tela de docs/12 §12.6.
- `geolocalizacao`: permissão pedida no card, cadeia de fallback da posição, distância Haversine, ordenação
  por proximidade e abertura no app de mapas pela URI `geo:`.
- `notificacao-local`: notificação "Reserva confirmada" no canal `reservas` na transição para PAGO, com
  permissão pedida uma única vez na tela Pagamento e toque que abre a DetalheReserva (Should Have).

### Modified Capabilities

Nenhuma: `frontend/openspec/specs/` está vazio. Este é o primeiro change do OpenSpec do app. Os nomes
`perfil-usuario` e `horarios-funcionamento` coincidem com capabilities do backend, mas vivem em outra raiz do
OpenSpec e descrevem o comportamento do app.

## Impact

- **Código**:
  - reescreve `frontend/lib/src/` sobre o boilerplate, com as features `auth`, `perfil`, `quadras`,
    `horarios`, `reservas` e `pagamento`;
  - acrescenta `frontend/android/` (via `flutter create`), `frontend/config/`, `frontend/assets/fonts/`
    (Inter), `frontend/assets/images/` (logo) e os testes em `frontend/test/`;
  - remove onboarding, home, recuperação de senha, `MediaService` e `VersionUpdateService`.
- **Dependências**:
  - adiciona `qr_flutter` 4.1.0, `geolocator` 14.1.1, `flutter_local_notifications` 22.3.1, `intl`,
    `sqflite` 2.4.4+1 e `package_info_plus` 10.2.2, e em dev `sqflite_common_ffi` 2.4.3 e `fake_async` 1.3.3;
  - atualiza `go_router` para 18.0.2 e `flutter_secure_storage` para 11.2.0;
  - remove `flutter_dotenv`, `image_picker` e `app_version_update`;
  - fixa todas as versões sem `^` e passa o `sdk` para `^3.13.0`.
- **CI**: nenhum arquivo do workflow muda. O job `frontend` passa a ter o que precisa (`android/`,
  `config/dev.json.exemplo`, assets) e publica `app-debug.apk`.
- **Backend**: nenhuma mudança. O app é consumidor do contrato `docs/api/openapi-n1.json` e não chama Inter,
  BrasilAPI nem ViaCEP.
- **Equipe**: as fatias seguem docs/15:
  - A: auth, perfil e navegação;
  - B: quadras, horários, CEP e `quadra_cache`;
  - C: reservas, slots, cache de reservas, geolocalização e notificação;
  - D: pagamento;
  - valem as contribuições cruzadas de docs/15 §15.5: grade de slots com B, MinhasReservas com A,
    ReservasQuadra com D.
- **Documentação** (atualização em um PR de docs separado, fora deste change):
  - ficam desatualizados o `README.md` e os docs 00, 02, 04, 05, 06 (RNF03, RNF08, RNF10), 09, 12, 13, 14,
    16, 18, 20, 21 e 23;
  - a busca pelos termos substituídos também encontrou menções em 01 (§4), 03 (§7), 07 (RN08), 08 (§8),
    10 (§2 e §7), 11 (§4), 15 (§15.2 e §15.6), 19 (R17, R23, R27, R28) e 22 (§3), que entram no mesmo PR de
    docs;
  - esses docs ainda descrevem provider/`ChangeNotifier`, MVVM em `lib/{ui,data,model}`, drift +
    json_serializable + `build_runner`, `Ambiente`, `Resultado`, `br.com.somaisuma.app` e "só pt-BR";
  - o docs/04 também diverge do protótipo nos pontos resolvidos aqui: seleção do slot e barra Continuar,
    horários salvos em lote, motivo obrigatório para o cliente e layout da ConfirmarReserva;
  - o comando `adb ... run-as br.com.somaisuma.app.debug` passa a ser
    `adb ... run-as com.corebuild.so_mais_uma.debug`, e o banco local passa a `databases/somaisuma.db`.
