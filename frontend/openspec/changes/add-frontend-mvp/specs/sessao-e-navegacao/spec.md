## Purpose

Leva a pessoa da abertura do app até a home do seu perfil e a mantém lá. Cobre:
- Splash, Login e Cadastro com auto-login;
- sessão guardada no aparelho e encerramento da sessão;
- `redirect` por sessão e perfil;
- duas navegações inteiras, uma por perfil, e as regras de pilha que impedem voltar a telas que repetiriam
  uma ação.

## ADDED Requirements

### Requirement: Fidelidade da Splash ao protótipo
A Splash (`/splash`) SHALL reproduzir `docs/Protótipo de Alta Fidelidade/splash_screen/code.html`:
- fundo com as linhas de campo decorativas;
- cartão do logo com brilho e o selo de bola no canto;
- rótulo "Arena Digital", título "Só mais uma" e subtítulo "Sua arena esportiva a um toque";
- indicador circular com o ícone de cronômetro e a linha de status;
- pílula "Modo seguro · Sincronização local" e a versão real do app no rodapé, no formato `v<versão>`.

A linha de status SHALL mostrar "Carregando suas partidas..." enquanto a sessão é lida e
"Tudo pronto para o jogo!" quando ela está resolvida. Elementos omitidos:
- a pílula "CONNECTING" e o rótulo "FastBoot", porque a Splash não conecta à rede;
- a mensagem "Sincronizando quadras próximas...", porque não há sincronização na Splash;
- a marcação "RNF08 / RNF11".

(RF03)

#### Scenario: Versão real no rodapé
- **GIVEN** o app com `version: 1.0.0+1` no `pubspec.yaml`
- **WHEN** a Splash é exibida
- **THEN** o rodapé mostra `v1.0.0 (Build 1)` e não `v1.0.0 (Build 2026)`
- **AND** não aparece "RNF08 / RNF11", "CONNECTING" nem "FastBoot"

### Requirement: Decisão da rota inicial sem chamar a API
O app SHALL começar em `/splash` com o native splash preservado até a sessão sair de `SessionUnknown`. A
leitura da sessão SHALL ser local (armazenamento seguro e shared_preferences), sem chamada de rede. O
`redirect` SHALL tirar o usuário de `/splash` quando a sessão está resolvida e a Splash esteve visível por no
mínimo 1 s:
- para `/login` quando não há `token_jwt` ou `usuario_id`;
- para `/login` quando `token_expira_em` é menor que o instante atual mais 5 minutos;
- para `/quadras` quando o perfil é `CLIENTE`;
- para `/dono/quadras` quando o perfil é `DONO`.

Falha ao ler o token do Keystore SHALL contar como sessão ausente e limpar a sessão, sem travar o app.
Token a menos de 5 minutos de expirar SHALL ser limpo junto com o cache, como no logout. (RF03, RNF03,
RNF08, CT-06)

#### Scenario: Reabrir com sessão válida em modo avião
- **GIVEN** um CLIENTE que entrou ontem e fechou o app
- **WHEN** o app é reaberto com o aparelho em modo avião
- **THEN** a Splash aparece e em seguida a tela Quadras com a bottom-nav do CLIENTE
- **AND** nenhuma requisição de rede é feita para decidir a rota

#### Scenario: Token perto de expirar
- **GIVEN** uma sessão cujo `token_expira_em` cai daqui a 3 minutos
- **WHEN** o app é aberto
- **THEN** o usuário vai para o Login, e a sessão e o cache local estão vazios

#### Scenario: Chave do Keystore perdida
- **GIVEN** o token não pode ser decifrado porque a chave do Keystore foi perdida
- **WHEN** o app é aberto
- **THEN** o app vai para o Login sem erro e sem travar

### Requirement: Fidelidade do Login ao protótipo
O Login (`/login`) SHALL reproduzir `docs/Protótipo de Alta Fidelidade/login/code.html`:
- logo, selo "Só mais uma", título "Acesse sua conta" e o subtítulo;
- cartão do formulário com o campo E-mail (ícone de envelope; dica "Formato válido" e marca de confirmação
  quando o formato é válido);
- campo Senha com ícone de cadeado e alternador de visibilidade;
- cartão "Proteção de Acesso Ativa" com o texto sobre o bloqueio temporário após 5 tentativas incorretas,
  sem o código "(RF04)";
- botão "Entrar", chamada "Não tem uma conta? Criar conta", divisor "ou" e botão
  "Acesso do Gestor de Quadra";
- rodapé "Versão <versão> (Build <build>) · Só mais uma" com a versão real.

Elementos omitidos: "Esqueceu a senha?", porque recuperação de senha está fora do MVP, e os links
"Termos de Uso", "Privacidade" e "Suporte", porque não existem esses documentos. "Criar conta" SHALL abrir o
Cadastro. "Acesso do Gestor de Quadra" SHALL abrir o Cadastro com o perfil DONO pré-selecionado, porque o
login é único para os dois perfis. (RF02, RF04)

#### Scenario: Elementos fora do MVP não aparecem
- **WHEN** o Login é exibido
- **THEN** não existe "Esqueceu a senha?" nem links de Termos de Uso, Privacidade ou Suporte
- **AND** o cartão de proteção tem o título "Proteção de Acesso Ativa", sem "(RF04)"

#### Scenario: Atalho do gestor
- **WHEN** o usuário toca "Acesso do Gestor de Quadra"
- **THEN** o Cadastro abre com o cartão "Quero anunciar minhas quadras" selecionado

### Requirement: Login por e-mail e senha
O Login SHALL validar localmente o e-mail com `@` e domínio e a senha não vazia, sem validar a composição da
senha. Em seguida SHALL enviar `POST /auth/login` com `{email, senha}`. O comportamento por resultado SHALL
ser:
- **sucesso**: grava a sessão e vai para a home do perfil com `go`, substituindo a pilha;
- **401 `CREDENCIAL_INVALIDA`**: mostra "E-mail ou senha incorretos" abaixo do botão Entrar e limpa o campo
  senha;
- **429 `LOGIN_BLOQUEADO`**: mostra "Muitas tentativas. Tente novamente em 15 minutos." e desabilita o
  botão por 30 s;
- **sem rede**: mostra "Sem conexão. Verifique a internet e tente de novo".

Durante a chamada, o botão SHALL mostrar o indicador de progresso e os campos ficam desabilitados. A tecla
de ação do teclado no campo senha SHALL disparar o Entrar. (RF02, RF04, RNF06, CT-04, CT-05)

#### Scenario: Login do CLIENTE de demonstração
- **WHEN** `cliente@demo.com` entra com `Senha123`
- **THEN** o app abre `/quadras` com a bottom-nav Quadras | Reservas | Perfil
- **AND** o botão voltar do sistema não retorna ao Login

#### Scenario: Senha incorreta
- **WHEN** o usuário entra com a senha errada
- **THEN** aparece "E-mail ou senha incorretos" abaixo do botão e o campo senha fica vazio
- **AND** a sessão continua inexistente

#### Scenario: Bloqueio após 5 falhas
- **GIVEN** um e-mail com 5 falhas seguidas
- **WHEN** o usuário tenta entrar pela sexta vez, mesmo com a senha correta
- **THEN** aparece "Muitas tentativas. Tente novamente em 15 minutos." e o botão Entrar fica desabilitado por 30 s

### Requirement: Fidelidade do Cadastro ao protótipo
O Cadastro (`/cadastro`) SHALL reproduzir `docs/Protótipo de Alta Fidelidade/cadastro/code.html`:
- barra com voltar, logo e marca, título "Criar nova conta" e subtítulo;
- bloco "Tipo de Perfil" com o rótulo "Obrigatório" e os cartões "Quero reservar quadras / Atleta / Jogador"
  (CLIENTE) e "Quero anunciar minhas quadras / Proprietário / Arena" (DONO);
- aviso "O perfil de acesso não pode ser alterado depois da criação da conta.";
- campos Nome completo, E-mail, Telefone celular ("Opcional", com máscara `(11) 98765-4321`), Senha (com o
  medidor de força de 3 barras e a dica "Mínimo 8 caracteres, com letra e número.") e Confirmar senha;
- botão "Cadastrar e começar" e chamada "Já tem uma conta? Entrar".

Elementos omitidos e ajustes: o checkbox de Termos de Uso e Política de Privacidade sai, porque não existe
documento de termos; as marcações "(RN20)" e "(RNF01)" saem do texto. O cartão CLIENTE SHALL vir
selecionado por padrão, salvo quando o Cadastro foi aberto pelo atalho do gestor. (RF01, RN20, RNF01)

#### Scenario: Sem checkbox de termos
- **WHEN** o Cadastro é exibido
- **THEN** não há checkbox de Termos de Uso e o botão "Cadastrar e começar" depende só dos campos válidos

#### Scenario: Medidor de força
- **WHEN** o usuário digita `abc12345` na senha
- **THEN** as três barras do medidor ficam na cor primária

### Requirement: Cadastro com perfil e auto-login
O Cadastro SHALL validar por campo:
- nome com 2 a 100 caracteres;
- e-mail válido, normalizado em minúsculas;
- telefone vazio ou com 10 ou 11 dígitos;
- senha na política de RNF01;
- confirmação igual à senha, com o erro "As senhas não coincidem.".

Em seguida SHALL enviar `POST /auth/registrar` com `{nome, email, senha, perfil, telefone}`, com o telefone
só com dígitos ou ausente. O comportamento por resultado SHALL ser:
- **2xx**: grava a sessão e vai para a home do perfil com `go`, sem passar pelo Login;
- **409 `EMAIL_JA_CADASTRADO`**: erro "E-mail já cadastrado" no campo e-mail, com o link "Entrar";
- **400 `VALIDACAO`**: as mensagens de `campos[]` vão para os respectivos campos;
- **sem rede**: botão desabilitado com snackbar de falta de conexão.

(RF01, RN20, RNF01, RNF06, CT-01, CT-02, CT-03)

#### Scenario: Cadastro de DONO abre a home do dono
- **WHEN** alguém se cadastra com perfil DONO e dados válidos
- **THEN** o app abre `/dono/quadras` com a bottom-nav Minhas quadras | Reservas | Perfil

#### Scenario: E-mail repetido em maiúsculas
- **WHEN** alguém tenta se cadastrar com `CLIENTE@DEMO.COM`
- **THEN** o campo e-mail mostra "E-mail já cadastrado" com o link "Entrar"

#### Scenario: Senha fora da política antes do envio
- **WHEN** o usuário informa a senha `12345678` e toca fora do campo
- **THEN** o campo mostra o erro de política e nenhuma requisição é enviada

### Requirement: Sessão persistente no aparelho
O `SessionStore` SHALL guardar `token_jwt` apenas no flutter_secure_storage. No shared_preferences
(`SharedPreferencesAsync`) SHALL guardar:
- `token_expira_em`, `usuario_id`, `usuario_nome`, `usuario_perfil`, `usuario_email` e `usuario_telefone`;
- `ultima_lat` e `ultima_lon`;
- `ultima_sincronizacao_quadras` e `ultima_sincronizacao_reservas`;
- `notificar_confirmacao`, `permissao_localizacao_pedida` e `permissao_notificacao_pedida`.

No login e no cadastro, o token SHALL ser gravado primeiro. A sessão só SHALL ser reconhecida quando existem
`token_jwt` e `usuario_id`. O estado da sessão SHALL ser um signal selado com `SessionUnknown`,
`SessionAuthenticated` e `SessionUnauthenticated`. (RF03, RNF03)

#### Scenario: App morto no meio do login
- **GIVEN** o app foi encerrado depois de gravar o token e antes de gravar `usuario_id`
- **WHEN** o app é reaberto
- **THEN** a sessão é tratada como ausente e o usuário vai para o Login

#### Scenario: Nome atualizado aparece no cabeçalho
- **WHEN** o usuário altera o nome no Perfil com sucesso
- **THEN** `usuario_nome` é atualizado e as iniciais do avatar mudam em todas as telas

### Requirement: Encerramento da sessão
Encerrar a sessão, pelo botão Sair do Perfil ou pelo 401 `TOKEN_INVALIDO`, SHALL executar sem chamada de
rede, porque não existe endpoint de logout, e SHALL funcionar sem rede:
- apaga todas as chaves do armazenamento seguro e do shared_preferences;
- apaga as duas tabelas do banco local;
- remove as notificações do app ainda exibidas;
- muda a sessão para `SessionUnauthenticated`.

O `redirect` SHALL então levar a `/login` com as pilhas das abas descartadas. (RF03, RNF03, CT-06)

#### Scenario: Sair em modo avião
- **GIVEN** um usuário logado com o aparelho em modo avião
- **WHEN** ele toca Sair e confirma
- **THEN** o app abre o Login
- **AND** o banco local não tem nenhuma linha em `quadra_cache` nem em `reserva_cache`

#### Scenario: Trocar de usuário no mesmo aparelho
- **GIVEN** o CLIENTE saiu do app
- **WHEN** o DONO entra no mesmo aparelho
- **THEN** nenhuma reserva ou quadra do CLIENTE aparece para o DONO

### Requirement: Redirect global por sessão e perfil
O `GoRouter` SHALL ter um `redirect` global reavaliado sempre que o signal de sessão muda, por meio de um
`refreshListenable` alimentado por esse signal. As regras SHALL ser:
- **sessão em `SessionUnknown`**: mantém `/splash`;
- **sessão ausente ou token a menos de 5 minutos de expirar**: qualquer rota protegida vai para `/login`;
- **sessão válida em `/splash`, `/login` ou `/cadastro`**: vai para a home do perfil;
- **rota do outro perfil**: vai para a home do perfil logado.

O `SessionListenerWrapper` do boilerplate SHALL ser removido. Um destino pendente vindo do toque em
notificação SHALL ser aplicado depois que a sessão for resolvida, e só para o perfil CLIENTE. (RF03, RN02,
RN04)

#### Scenario: DONO tenta abrir rota do cliente
- **GIVEN** um DONO logado
- **WHEN** o app recebe a navegação para `/quadras/7/reservar?inicio=...`
- **THEN** o `redirect` leva o DONO para `/dono/quadras`

#### Scenario: Usuário logado volta ao Login
- **GIVEN** um CLIENTE logado
- **WHEN** a rota `/login` é solicitada
- **THEN** o `redirect` leva para `/quadras`

### Requirement: Duas navegações por perfil
O app SHALL ter dois `StatefulShellRoute.indexedStack`, um por perfil, cada um com três abas e uma pilha por
aba preservada ao trocar de aba:
- **CLIENTE**: Quadras (`/quadras`, ícone de bola de futebol), Reservas (`/reservas`, ícone de evento
  disponível) e Perfil (`/perfil`, ícone de pessoa);
- **DONO**: Minhas quadras (`/dono/quadras`, ícone de estádio), Reservas (`/dono/reservas`, ícone de nota de
  evento) e Perfil (`/dono/perfil`, ícone de pessoa).

A bottom-nav SHALL seguir o desenho do protótipo, com indicador em pílula no item ativo. Ela SHALL aparecer
apenas nos destinos raiz de cada aba. As telas de detalhe SHALL abrir no navigator raiz, por cima do shell e
sem bottom-nav. Tocar a aba atual SHALL voltar à raiz dela. Os caminhos SHALL ficar centralizados em
`AppRoutes`, sem strings soltas nas telas. (RF02, RN02, CT-09)

#### Scenario: Bottom-nav muda com o perfil
- **WHEN** o CLIENTE sai e o DONO entra
- **THEN** a bottom-nav passa de "Quadras | Reservas | Perfil" para "Minhas quadras | Reservas | Perfil"

#### Scenario: Estado preservado ao trocar de aba
- **GIVEN** o CLIENTE rolou a lista de Quadras e filtrou por Futsal
- **WHEN** ele vai à aba Reservas e volta à aba Quadras
- **THEN** a lista mantém o filtro e a posição de rolagem

#### Scenario: CLIENTE não vê MinhasQuadras
- **WHEN** um CLIENTE navega por todas as abas
- **THEN** não existe aba Minhas quadras nem botão de nova quadra

### Requirement: Regras de pilha de navegação
A navegação SHALL seguir as regras de docs/04 §4.3:

| Situação | Comportamento |
|---|---|
| login ou cadastro bem-sucedido | `go` para a home do perfil, removendo Login e Cadastro da pilha |
| reserva criada com 2xx | `go` para a tela Pagamento, removendo a ConfirmarReserva e impedindo repetir o POST |
| back físico ou seta na tela Pagamento | vai para MinhasReservas, nunca para a ConfirmarReserva |
| pagamento detectado como PAGO | `go` para a DetalheReserva, com a pilha MinhasReservas -> DetalheReserva na aba Reservas |
| 409 `HORARIO_INDISPONIVEL` | `pop(true)` de volta à DetalheQuadra, que recarrega a grade |
| 422 `RESERVA_PENDENTE_EXISTENTE` | `go` para a DetalheReserva do `reservaId` |

O estado das telas SHALL sobreviver à rotação do aparelho. (RF13, RF20, CT-25)

#### Scenario: Voltar não reenvia a reserva
- **GIVEN** o cliente criou uma reserva e está na tela Pagamento
- **WHEN** ele usa o back físico duas vezes
- **THEN** passa por MinhasReservas e sai da aba
- **AND** em nenhum momento a ConfirmarReserva é exibida de novo

### Requirement: Acessibilidade de Splash, Login e Cadastro
Estas telas SHALL atender aos pontos de docs/04 §6.2:
- o logo da Splash tem `semanticLabel` "Só mais uma" e nada na Splash é interativo;
- o alternador de senha tem tooltip "Mostrar senha" ou "Ocultar senha";
- o erro geral do Login é anunciado como `liveRegion`;
- os cartões de perfil do Cadastro são anunciados como opções mutuamente exclusivas sob o título do grupo,
  com o estado selecionado, e o aviso de perfil fixo fica ligado ao grupo;
- a dica de senha fica visível antes do erro.

(RNF07)

#### Scenario: TalkBack nos cartões de perfil
- **GIVEN** o TalkBack ligado
- **WHEN** o foco chega ao cartão "Quero anunciar minhas quadras"
- **THEN** o leitor anuncia o cartão como opção do grupo "Tipo de Perfil" e informa se está selecionado
