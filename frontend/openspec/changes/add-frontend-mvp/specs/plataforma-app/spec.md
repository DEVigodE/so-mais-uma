## Purpose

Define a base sobre a qual todas as telas do app nascem:
- projeto Android e configuração por ambiente;
- injeção de dependências e o padrão de estado com signals;
- cliente HTTP e tradução dos erros da API;
- formatos de dados, validadores, tema a partir do protótipo e idiomas;
- regra de fidelidade ao protótipo, componentes do domínio, acessibilidade básica e integração contínua.

## ADDED Requirements

### Requirement: Projeto Android do app
O app SHALL ser um projeto Flutter com plataforma Android, criado em `frontend/` com
`flutter create . --platforms android --org com.corebuild --project-name so_mais_uma`, com applicationId
`com.corebuild.so_mais_uma` e `applicationIdSuffix ".debug"` no build debug, para que os dois APKs convivam
no mesmo aparelho. O projeto SHALL ter:
- `minSdk` 26, e `compileSdk` e `targetSdk` herdados do Flutter;
- core library desugaring habilitado;
- rótulo do aplicativo "Só mais uma" e ícone derivado do logo do protótipo;
- assinatura de release lida de `frontend/android/key.properties`, mantido fora do Git.

O manifest principal SHALL declarar:
- `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION` e
  `POST_NOTIFICATIONS`;
- `android.hardware.location.gps` com `required="false"`;
- `android:allowBackup="false"`.

O manifest principal SHALL NOT declarar `CAMERA`, permissões de armazenamento, `READ_MEDIA_*` nem
`ACCESS_BACKGROUND_LOCATION`. Tráfego HTTP em texto claro SHALL ser liberado apenas em
`src/debug/AndroidManifest.xml`. iOS SHALL ficar fora do projeto. (RNF08, RNF09, RNF03, CT-06)

#### Scenario: APK debug e release convivem no mesmo aparelho
- **GIVEN** o APK release instalado em um celular
- **WHEN** o APK debug é instalado com `adb install -r` no mesmo celular
- **THEN** os dois aparecem como apps distintos, com pacotes `com.corebuild.so_mais_uma` e `com.corebuild.so_mais_uma.debug`

#### Scenario: Release não fala HTTP em texto claro
- **GIVEN** um APK release gerado com `config/release.json`
- **WHEN** a URL configurada usa `http://`
- **THEN** a plataforma recusa a conexão em texto claro e o app trata a falha como sem conexão
- **AND** o manifest mesclado do release não contém `usesCleartextTraffic="true"`

#### Scenario: Permissões declaradas são exatamente as do recurso nativo
- **WHEN** o manifest mesclado do release é inspecionado com `aapt dump permissions`
- **THEN** ele contém `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION` e `POST_NOTIFICATIONS`
- **AND** não contém `CAMERA`, `ACCESS_BACKGROUND_LOCATION` nem permissões de armazenamento

### Requirement: Configuração por ambiente sem segredo no APK
O app SHALL receber `API_BASE_URL` e `DEV_KEY` por `--dart-define-from-file` e lê-los com
`String.fromEnvironment` em `AppConfig`. Os arquivos SHALL ser:
- `frontend/config/dev.json.exemplo`, versionado, com `API_BASE_URL` igual a `http://10.0.2.2:8080/api/v1`
  e `DEV_KEY` igual a `troque`;
- `frontend/config/release.json`, versionado, apenas com a URL HTTPS do backend publicado;
- `frontend/config/dev.json`, ignorado pelo Git.

Sem definição, `API_BASE_URL` SHALL valer `http://10.0.2.2:8080/api/v1` e `DEV_KEY` SHALL ser vazia. O app
SHALL NOT usar `flutter_dotenv`, arquivo `.env` em assets nem chamada `dotenv.load`. (RNF09, RNF02, RF21)

#### Scenario: Build do CI com o arquivo de exemplo
- **WHEN** o CI executa `flutter build apk --debug --dart-define-from-file=config/dev.json.exemplo`
- **THEN** o build termina com sucesso e o APK aponta para `http://10.0.2.2:8080/api/v1`

#### Scenario: Release não carrega a chave de desenvolvimento
- **GIVEN** um APK gerado com `--dart-define-from-file=config/release.json`
- **WHEN** a tela Pagamento é aberta com uma reserva pendente
- **THEN** o botão "Simular confirmação Pix (Dev Sandbox)" não aparece

#### Scenario: Nenhum arquivo .env empacotado
- **WHEN** o `pubspec.yaml` é inspecionado
- **THEN** a seção de assets não contém `.env`
- **AND** `flutter_dotenv` não aparece entre as dependências

### Requirement: Versões fixadas das dependências
O `pubspec.yaml` SHALL fixar a versão exata de toda dependência, sem `^`, `>=`, `any` ou `latest`, com
`environment.sdk` igual a `^3.13.0`. O `pubspec.lock` SHALL ser versionado. As dependências diretas SHALL
incluir:
- go_router 18.0.2, dio 5.11.1, flutter_secure_storage 11.2.0 e shared_preferences 2.5.6;
- qr_flutter 4.1.0, geolocator 14.1.1, flutter_local_notifications 22.3.1, sqflite, intl e
  package_info_plus;
- em desenvolvimento, sqflite_common_ffi e fake_async;
- os pacotes herdados do boilerplate que continuam em uso, incluindo internet_connection_checker_plus e
  cached_network_image.

O app SHALL NOT depender de `flutter_dotenv`, `image_picker`, `app_version_update`, `provider`, `drift`,
`json_serializable` nem `build_runner`. Todos os integrantes e o CI SHALL usar o Flutter 3.47.6. (RNF10)

#### Scenario: Dependência com faixa de versão é recusada na revisão
- **GIVEN** um PR que acrescenta uma dependência com `^` no `pubspec.yaml`
- **WHEN** o revisor aplica o checklist do PR
- **THEN** o PR não é aprovado até a versão ser fixada

#### Scenario: Resolução com o Flutter do CI
- **WHEN** `flutter pub get` roda com o Flutter 3.47.6
- **THEN** todas as dependências resolvem sem conflito de versão, inclusive o `intl` exigido pelo SDK

### Requirement: Injeção de dependências com auto_injector
Todas as dependências do app SHALL ser registradas em `lib/src/config/injector.dart` e resolvidas pelo
`auto_injector`:
- stores de tela com `add` (uma instância por abertura da tela);
- stores globais, repositórios, banco local e serviços com `addLazySingleton`, com descarte configurado
  quando seguram recursos.

Nenhum widget SHALL instanciar `Dio`, banco ou repositório diretamente. (RNF10)

#### Scenario: Cada abertura de tela recebe um store novo
- **WHEN** a tela Quadras é aberta, fechada e aberta de novo
- **THEN** cada abertura recebe uma instância diferente do store da tela
- **AND** a instância anterior foi descartada, com seus efeitos encerrados

#### Scenario: Repositório é único no app
- **WHEN** duas telas resolvem o repositório de reservas
- **THEN** as duas recebem a mesma instância

### Requirement: Estado de tela com signals e separação entre contêiner e view
Cada store SHALL:
- guardar o estado em `signal` privado e expô-lo como `ReadonlySignal`;
- derivar valores com `computed`;
- criar os `effect` fora do `build` e liberar signals, computeds e efeitos em `dispose()`.

O estado de uma tela com dados remotos SHALL combinar `RequestState<T>` com as flags de offline e de última
sincronização, cobrindo carregando, vazio, erro e offline (RNF06). Cada tela SHALL separar:
- um contêiner, que cria o store, os efeitos de navegação e snackbar, os `TextEditingController` e o
  `AppLifecycleListener`;
- uma view sem estado, que recebe o estado e os callbacks e reconstrói por `SignalBuilder`.

Nenhuma regra de negócio SHALL ficar no `build`. (RNF06, RNF10)

#### Scenario: View renderiza os quatro estados a partir de estado fixo
- **GIVEN** a view de uma tela de lista montada em teste com estado fixo
- **WHEN** o estado é carregando, vazio, erro com mensagem ou offline com data de sincronização
- **THEN** a view mostra respectivamente o esqueleto de carga, o estado vazio com a ação sugerida, a caixa de erro com "Tentar novamente" e o banner de modo cache
- **AND** nenhum desses casos exige store, rede ou banco

#### Scenario: Resposta que chega depois de sair da tela é descartada
- **GIVEN** uma tela com uma chamada de rede em andamento
- **WHEN** o usuário sai da tela antes da resposta chegar
- **THEN** o store descartado não altera estado nem dispara navegação ou snackbar

### Requirement: Cliente HTTP e AuthInterceptor
O app SHALL usar um único `Dio`. Esse `Dio` SHALL:
- usar a URL base `API_BASE_URL`;
- enviar `Content-Type: application/json; charset=utf-8` e `Accept: application/json`;
- usar limite de conexão de 10 s e de envio e recebimento de 15 s.

O `AuthInterceptor` SHALL ler o token do armazenamento seguro de forma assíncrona e enviar
`Authorization: Bearer <token>` em toda rota fora de `/auth/*`.

Quando uma resposta 401 com `codigo` `TOKEN_INVALIDO` chegar de uma rota fora de `/auth/*`, o interceptor
SHALL executar uma única vez a limpeza de sessão e de cache do logout, até o próximo login bem-sucedido. Em
seguida SHALL repassar o mesmo erro, sem retry. Um 401 de `/auth/login` (`CREDENCIAL_INVALIDA`) SHALL NOT
limpar a sessão.

Nenhuma requisição SHALL ser repetida automaticamente pelo app. Os logs de rede SHALL registrar método,
caminho, status e duração, e SHALL NOT registrar o cabeçalho `Authorization` nem corpos com senha.
(RF03, RNF03, RNF09, CT-06)

#### Scenario: Token expirado durante o polling do pagamento
- **GIVEN** a tela Pagamento com polling ativo e o token já recusado pelo servidor
- **WHEN** chegam duas respostas 401 `TOKEN_INVALIDO` seguidas
- **THEN** a sessão e o cache são limpos exatamente uma vez
- **AND** o app vai para `/login` sem loop e sem nova tentativa da requisição

#### Scenario: Credencial errada não derruba nada
- **WHEN** `POST /auth/login` responde 401 `CREDENCIAL_INVALIDA`
- **THEN** a sessão e o cache permanecem intactos e o erro é tratado pela tela Login

#### Scenario: Aviso de sessão expirada no Login
- **GIVEN** a sessão foi encerrada por um 401 `TOKEN_INVALIDO`
- **WHEN** o Login aparece
- **THEN** ele mostra uma única vez a mensagem "Sua sessão expirou. Entre novamente."

### Requirement: Tradução de erros da API em Failure
Os repositórios SHALL devolver `FutureEither<T>`. O `Failure` selado SHALL ganhar
`ApiFailure(status, codigo, subcodigo, detail, campos, reservaId)`, montado por um `ProblemDetailParser` a
partir de `err.response?.data`. A conversão de `DioException` SHALL seguir o `type`:
- `connectionError`, `connectionTimeout`, `sendTimeout` e `receiveTimeout` viram `NetworkFailure`, tratado
  como offline;
- `badResponse` vira `ApiFailure`;
- os demais viram `UnknownFailure`.

Corpo de erro que não seja `ProblemDetail` SHALL virar `ApiFailure` com o status HTTP e `codigo` vazio. A
mensagem exibida SHALL seguir esta ordem:
1. a chave de tradução do `subcodigo`, quando existe;
2. senão, a do `codigo`;
3. senão, o `detail` do servidor;
4. senão, "Algo deu errado. Tente novamente.".

Leituras sem rede SHALL NOT disparar o toast global de falta de conexão: a tela mostra o banner de modo cache.
(RNF06, RNF09)

#### Scenario: 422 de reserva pendente traz o id
- **WHEN** `POST /reservas` responde 422 com `codigo` `REGRA_NEGOCIO`, `subcodigo` `RESERVA_PENDENTE_EXISTENTE` e `reservaId` 42
- **THEN** o repositório devolve `ApiFailure` com status 422, esse `subcodigo` e `reservaId` igual a 42

#### Scenario: Erro de validação chega campo a campo
- **WHEN** a API responde 400 `VALIDACAO` com `campos[]` contendo `precoHora` e `cep`
- **THEN** o `ApiFailure` traz os dois campos com as mensagens
- **AND** o formulário mostra cada mensagem abaixo do campo correspondente

#### Scenario: Timeout vira offline sem toast
- **GIVEN** a tela Quadras com cache populado
- **WHEN** a sincronização falha por `receiveTimeout`
- **THEN** a falha é `NetworkFailure`, o cache continua na tela e aparece o banner de modo cache
- **AND** nenhum toast global de "sem internet" é exibido

#### Scenario: Erro 500 sem corpo legível
- **WHEN** a API responde 500 com corpo que não é JSON
- **THEN** a tela mostra "Algo deu errado. Tente novamente."

### Requirement: Contrato de dados com o backend
Os modelos do app SHALL usar exatamente os nomes de campo de `docs/api/openapi-n1.json`. Também SHALL valer:
- identificadores são `int`;
- valores monetários circulam como a string decimal recebida (`"80.00"`) e só viram texto formatado na
  exibição;
- instantes são ISO-8601 com offset;
- `inicio` é enviado com offset `-03:00`;
- horas de funcionamento são `HH:mm`.

`fromJson` e `toJson` SHALL ser escritos à mão com pattern matching, sem geração de código, e SHALL ignorar
chaves desconhecidas. Valor de enum desconhecido SHALL cair em `OUTRO` e ser exibido de forma neutra, sem
derrubar o app. Todo POST SHALL aceitar qualquer status 2xx como sucesso. (RNF09, RNF12)

#### Scenario: Campo novo na resposta não quebra o APK instalado
- **WHEN** o backend passa a devolver um campo opcional que o app não conhece em `QuadraResponse`
- **THEN** a lista de quadras continua carregando normalmente

#### Scenario: Status de reserva desconhecido
- **WHEN** uma reserva chega com `status` igual a `EM_ANALISE`
- **THEN** o app a classifica como `OUTRO` e mostra o chip de status neutro, sem erro

#### Scenario: POST aceita 200 ou 201
- **WHEN** `POST /quadras` responde 200 em vez de 201 com a quadra no corpo
- **THEN** o app trata a criação como bem-sucedida

### Requirement: Formatadores de dinheiro, data, distância e código
Os formatadores SHALL produzir, no idioma pt:
- dinheiro como `R$ 90,00`, e na forma compacta usada nos slots livres como `R$ 90` quando os centavos são
  zero;
- datas e horas no fuso de Brasília por deslocamento fixo UTC-3, independentemente do fuso do aparelho;
- distância como `a 850 m` abaixo de 1 km e `a 2,3 km` com uma casa decimal a partir de 1 km;
- código da reserva como `#RES-<id>`;
- telefone exibido como `(11) 98765-4321` a partir dos dígitos;
- tempo desde a última sincronização como "agora", "há X min", "hoje às HH:mm" ou "em dd/MM às HH:mm".

(RNF12, RF22)

#### Scenario: Instante em UTC é exibido no horário de Brasília
- **GIVEN** o aparelho configurado no fuso UTC
- **WHEN** a API devolve `inicio` igual a `2026-11-20T22:00:00Z`
- **THEN** a tela mostra o horário 19:00

#### Scenario: Envio do início com offset fixo
- **WHEN** o cliente escolhe o slot das 19:00 de 10/10/2026
- **THEN** o app envia `inicio` igual a `2026-10-10T19:00:00-03:00`

#### Scenario: Distância abaixo de 1 km
- **WHEN** a distância calculada é 0,85 km
- **THEN** o card mostra `a 850 m`

### Requirement: Validadores que espelham o backend
Os validadores locais SHALL espelhar o Bean Validation do backend. As regras SHALL ser:
- nome com 2 a 100 caracteres, como no protótipo e no docs/04;
- e-mail válido com até 150 caracteres, normalizado em minúsculas;
- senha com 8 a 72 caracteres contendo letra e número;
- telefone vazio ou com 10 ou 11 dígitos depois de remover a máscara, enviado só com dígitos;
- preço maior que zero, com até 8 dígitos inteiros e 2 decimais;
- CEP com exatamente 8 dígitos, logradouro até 150 caracteres, número até 10, bairro até 80 e cidade até 80;
- UF com 2 letras maiúsculas;
- latitude entre -90 e 90 e longitude entre -180 e 180, preenchidas juntas ou vazias juntas;
- descrição até 500 caracteres, URL da foto até 300 e começando com `http`;
- observação até 200 caracteres;
- motivo de cancelamento com 5 a 200 caracteres depois de remover espaços das pontas.

O erro SHALL aparecer abaixo do campo depois do primeiro toque fora dele ou ao enviar, e o servidor
continua sendo a autoridade. (RNF06, RNF01, RF01, RF06)

#### Scenario: Senha só com letras
- **WHEN** o usuário digita `senhasenha` no cadastro e toca fora do campo
- **THEN** o campo mostra o erro de política de senha antes de qualquer envio

#### Scenario: Coordenada preenchida sozinha
- **WHEN** o dono informa latitude e deixa a longitude vazia
- **THEN** o formulário aponta a longitude como obrigatória quando a latitude está preenchida

### Requirement: Tema a partir dos tokens do protótipo
O tema claro SHALL usar um `ColorScheme` explícito com os tokens do `tailwind.config` dos `code.html` do
protótipo, que substituem o seed `#16A34A`:
- primary `#006b2c`, primary-container `#00873a`;
- surface `#f7f9fb`, secondary `#565e74`;
- tertiary `#755800`, error `#ba1a1a`;
- as famílias surface-container, fixed e inverse.

O tema escuro SHALL ser derivado dos mesmos tokens (inverse-primary `#62df7d` como primary escuro), e o app
SHALL seguir o tema do sistema. A tipografia SHALL usar a fonte Inter empacotada como asset, sem busca na
rede, nos tamanhos de display, headline, title, body e label do protótipo. Os tokens `AppSpacing`,
`AppBorders` e `AppShadows` SHALL refletir os espaçamentos, raios e sombras do protótipo. Widgets de feature
SHALL NOT usar cor hexadecimal, raio ou espaçamento literal. (RNF07, RNF06)

#### Scenario: Cor primária do protótipo
- **WHEN** o app abre no tema claro
- **THEN** o botão "Entrar" usa o fundo `#006b2c` com texto `#ffffff`

#### Scenario: Tema escuro segue o sistema
- **GIVEN** o aparelho em modo escuro
- **WHEN** o app é aberto
- **THEN** todas as telas usam o esquema escuro derivado, sem texto ilegível sobre superfície escura

#### Scenario: Fonte não depende de rede
- **GIVEN** o aparelho em modo avião desde a instalação
- **WHEN** o app é aberto pela primeira vez
- **THEN** os textos são exibidos em Inter

### Requirement: Idiomas pt, en e es
O app SHALL usar easy_localization com os idiomas pt, en e es. O idioma do aparelho SHALL ser usado quando
for um dos três, e pt SHALL ser usado nos demais casos e como fallback de chave ausente. Os textos do
protótipo SHALL ser a versão pt; en e es SHALL ser traduções desses textos. Toda string visível SHALL vir dos
arquivos `assets/translations/*.json`, inclusive as mensagens de erro, que usam chaves por `codigo` e
`subcodigo` com o `detail` do servidor como último recurso. Um teste SHALL verificar que os três arquivos têm
o mesmo conjunto de chaves. (RNF06)

#### Scenario: Aparelho em espanhol
- **GIVEN** o aparelho configurado em espanhol
- **WHEN** o Login é aberto
- **THEN** os textos da tela aparecem em espanhol

#### Scenario: Aparelho em idioma não suportado
- **GIVEN** o aparelho configurado em francês
- **WHEN** o app é aberto
- **THEN** os textos aparecem em português

#### Scenario: Chave faltando em um idioma
- **WHEN** uma chave existe em `pt.json` e falta em `en.json`
- **THEN** o teste de paridade das traduções falha no CI

### Requirement: Fidelidade ao protótipo como contrato de UI
O `code.html` de cada tela em `docs/Protótipo de Alta Fidelidade/` SHALL ser a referência de layout,
hierarquia, componentes, ícones, textos, cores e espaçamento, reproduzida tela a tela. A precedência SHALL
ser:
1. em conflito de UI com o docs/04, vence o protótipo;
2. em comportamento, vale o docs/04, salvo as resoluções registradas nas specs deste change.

A aplicação da regra SHALL seguir estes pontos:
- os valores de exemplo do protótipo (nomes de quadra, preços, datas, códigos, pessoas) SHALL NOT aparecer;
  os dados exibidos vêm da API ou do cache;
- elemento desenhado cujo dado não existe na API e não pode ser calculado SHALL ser omitido, nunca preenchido
  com valor fixo;
- elemento calculável a partir da API ou do cache SHALL ser implementado como cálculo;
- o que o docs/02 coloca fora do MVP SHALL sair mesmo desenhado;
- as marcações de requisito do texto ("(RN20)", "(RNF01)", "(RF04)", "RF06 / RF09", "Regra RN14:")
  SHALL sair do texto exibido, mantendo o conteúdo da regra;
- os ícones SHALL ser os equivalentes em `Icons` do Material dos Material Symbols do HTML, na variante
  outlined quando houver e preenchida quando o HTML usa `FILL 1`;
- telas e estados sem desenho (vazio, erro, offline, card de localização, card de permissão de notificação,
  diálogos) SHALL nascer na mesma linguagem visual e com os mesmos componentes.

(RNF06, RNF07)

#### Scenario: Exemplo do protótipo nunca aparece
- **GIVEN** o catálogo do backend sem nenhuma quadra chamada "Arena Champions Society"
- **WHEN** qualquer tela do app é percorrida
- **THEN** o texto "Arena Champions Society" não aparece em nenhum lugar

#### Scenario: Anotação de requisito sai do texto
- **WHEN** o Cadastro é exibido
- **THEN** o rótulo ao lado de "Tipo de Perfil" é "Obrigatório", sem "(RN20)"

#### Scenario: Quadra sem foto
- **GIVEN** uma quadra com `fotoUrl` nulo
- **WHEN** o card da quadra é exibido
- **THEN** a área da imagem mostra o placeholder ilustrado no mesmo formato 16:9, sem imagem de exemplo

### Requirement: Evidência de fidelidade por tela
Toda tarefa de tela SHALL entregar, no mesmo PR:
- o store da tela e seus testes;
- a view com widget test;
- as strings nos três idiomas;
- na descrição do PR, o print do app lado a lado com o `code.html` correspondente renderizado no
  navegador.

O revisor SHALL conferir cada item da lista de omissões e cálculos da tela antes de aprovar. (RNF06, RNF07)

#### Scenario: PR de tela sem comparação visual
- **GIVEN** um PR que entrega a tela MinhasReservas
- **WHEN** a descrição do PR não traz o print lado a lado com `minhas_reservas/code.html`
- **THEN** o revisor não aprova o PR

### Requirement: Barra superior, avatar e imagens
As telas SHALL usar a barra superior do protótipo:
- logo de `so_mais_uma_logo` em 32 px com cantos arredondados e o título ou marca da tela;
- seta de voltar nas telas internas;
- avatar à direita com as iniciais de `usuario_nome` (primeira letra do primeiro e do último nome), já que o
  app não tem foto de usuário.

O mesmo logo SHALL ser usado no splash nativo, na Splash, nos cabeçalhos e como ícone do app. Imagens de
quadra SHALL usar o `AppCachedImage` com placeholder ilustrado quando `fotoUrl` é nulo ou falha.
(RF08, RNF07)

#### Scenario: Iniciais do usuário
- **GIVEN** a sessão de "Lucas Pereira Silva"
- **WHEN** a barra superior é exibida
- **THEN** o avatar mostra "LS"

#### Scenario: URL de foto quebrada
- **WHEN** o download da `fotoUrl` falha
- **THEN** a imagem cai no placeholder ilustrado, sem ícone de erro vermelho

### Requirement: Componentes do domínio
Os componentes usados por mais de uma feature SHALL viver em `lib/src/shared/` e seguir o desenho do
protótipo:
- chips de esporte com ícone e rótulo;
- faixa horizontal de datas;
- grade de slots;
- card de quadra, card de reserva e chip de status com texto e ícone;
- banner de sincronização e de modo cache;
- barra de seleção de horário;
- QR Pix;
- sheets de cancelamento do cliente e do dono;
- avatar de iniciais e caixas de carregando, vazio e erro.

Status SHALL ser comunicado por texto e ícone, nunca apenas por cor. (RNF06, RNF07)

#### Scenario: Chip de status legível sem cor
- **WHEN** um chip de reserva `CONFIRMADA` é exibido em escala de cinza
- **THEN** o status continua identificável pelo texto "Confirmada" e pelo ícone

### Requirement: Acessibilidade básica
Todas as telas SHALL atender a estes pontos de acessibilidade:
- todo ícone clicável e toda imagem com função têm rótulo semântico (`tooltip`, `semanticLabel` ou
  `Semantics`), e imagens decorativas ficam fora da árvore semântica;
- alvos de toque têm no mínimo 48 dp lógicos;
- os textos usam o `TextTheme` e escalam com a fonte do sistema até 200 % sem corte nem sobreposição;
- o contraste atende às diretrizes nos temas claro e escuro;
- formulários usam `TextInputAction.next` e `done`;
- erros de campo aparecem no `errorText`;
- os estados de carregando e de erro são anunciados (`liveRegion`).

Os widget tests das views SHALL verificar `androidTapTargetGuideline`, `labeledTapTargetGuideline` e
`textContrastGuideline`. (RNF07, CT-25)

#### Scenario: Teste de diretrizes falha com alvo pequeno
- **GIVEN** uma view com um ícone clicável de 32 dp sem área de toque ampliada
- **WHEN** o widget test da view roda
- **THEN** a verificação de `androidTapTargetGuideline` falha

#### Scenario: Fonte do sistema em 200 %
- **GIVEN** a fonte do sistema em 200 %
- **WHEN** o usuário percorre Login, Quadras, DetalheQuadra, Pagamento e FormQuadra
- **THEN** nenhum texto é cortado e todos os botões continuam alcançáveis por rolagem

### Requirement: Dados que o app nunca guarda nem registra
O app SHALL NOT guardar nem registrar em log:
- a senha, mesmo como hash, e e-mail e senha "lembrados";
- dados do pagador Pix e o identificador fim a fim;
- credenciais do Inter e o token em texto claro fora do armazenamento seguro.

O app SHALL NOT chamar Inter, BrasilAPI nem ViaCEP diretamente; toda integração externa passa pelo backend.
(RNF02, RNF03, RN05)

#### Scenario: Senha não persiste após o login
- **WHEN** o usuário entra com sucesso
- **THEN** nem o armazenamento seguro, nem o shared_preferences, nem o banco local contêm a senha digitada

### Requirement: Integração contínua do app
O job `frontend` do CI SHALL executar `flutter pub get`, `flutter analyze` e `flutter test` com o Flutter
3.47.6, sem emulador e sem `build_runner`. Depois SHALL gerar o APK debug com
`--dart-define-from-file=config/dev.json.exemplo` e publicá-lo como artefato `apk-debug`. Todo PR do app SHALL
passar por esse job antes do merge. O `test/widget_test.dart` do boilerplate SHALL ser substituído pelos
testes do app. (RNF10)

#### Scenario: PR com teste quebrado
- **WHEN** um PR faz um teste de store falhar
- **THEN** o job `frontend` fica vermelho e o merge é bloqueado

#### Scenario: Artefato do APK debug
- **WHEN** o job `frontend` termina com sucesso
- **THEN** o artefato `apk-debug` contém `app-debug.apk` instalável com `adb install -r`
