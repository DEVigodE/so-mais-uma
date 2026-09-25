## Purpose

Permite que uma pessoa crie uma conta escolhendo seu perfil, entre com e-mail e senha e receba um
token que identifica quem ela é e o que pode fazer no restante da API, com as proteções mínimas
contra senha fraca e tentativa repetida de adivinhação.

## ADDED Requirements

### Requirement: Cadastro com escolha de perfil e auto-login
O sistema SHALL permitir que qualquer pessoa, sem autenticação, crie uma conta informando nome,
e-mail, senha, perfil (`CLIENTE` ou `DONO`) e, opcionalmente, telefone. O cadastro bem-sucedido
SHALL responder 201 com o token de acesso, seu instante de expiração e os dados do usuário criado,
de modo que não seja necessário um login subsequente. (RF01, RN20)

#### Scenario: Cadastro válido cria a conta e já autentica
- **WHEN** alguém envia `POST /api/v1/auth/registrar` com nome, e-mail inédito, senha válida e perfil `DONO`
- **THEN** a resposta é 201 com `token`, `expiraEm` e `usuario`
- **AND** o usuário criado tem perfil `DONO`
- **AND** o token devolvido já autoriza chamadas às rotas de DONO

#### Scenario: Telefone é opcional
- **WHEN** alguém se cadastra sem informar telefone
- **THEN** a conta é criada com telefone vazio e o cadastro é aceito

### Requirement: E-mail único e normalizado
O sistema SHALL tratar o e-mail como identificador único do usuário, armazenado em minúsculas. Uma
tentativa de cadastro com e-mail já existente SHALL responder 409 com `codigo`
`EMAIL_JA_CADASTRADO`. Qualquer outra violação de integridade na mesma operação SHALL NOT ser
traduzida para esse código: ela SHALL resultar em 500 com a exceção original registrada por completo
no log. (RF01, RN20)

#### Scenario: E-mail repetido é rejeitado
- **WHEN** alguém se cadastra com um e-mail que já existe, mesmo com caixa diferente
- **THEN** a resposta é 409 com `codigo` `EMAIL_JA_CADASTRADO`
- **AND** nenhuma conta nova é criada

### Requirement: Perfil imutável após o cadastro
O perfil escolhido no cadastro SHALL ser definitivo. O sistema SHALL NOT oferecer nenhuma operação
que altere o perfil ou o e-mail de um usuário existente. Quem precisar dos dois papéis SHALL usar
duas contas distintas. (RN20, RN02)

#### Scenario: Não há caminho para trocar de perfil
- **WHEN** um usuário autenticado tenta alterar seu próprio perfil ou e-mail por qualquer rota da API
- **THEN** o campo é ignorado ou rejeitado e o perfil e o e-mail permanecem os do cadastro

### Requirement: Política de senha
O sistema SHALL exigir senha com no mínimo 8 caracteres contendo ao menos uma letra e ao menos um
número, tanto no cadastro quanto na troca de senha. A senha SHALL ser armazenada apenas como hash
com algoritmo adaptativo de custo configurado, e SHALL NOT ser armazenada nem devolvida em texto
claro em nenhuma circunstância. (RF01, RF05, RNF01)

#### Scenario: Senha fraca é rejeitada
- **WHEN** alguém se cadastra com a senha `senhasenha`
- **THEN** a resposta é 400 com `codigo` `VALIDACAO` e uma entrada em `campos[]` para o campo da senha

#### Scenario: Senha nunca volta na resposta
- **WHEN** qualquer rota devolve dados de usuário
- **THEN** nem a senha nem o seu hash aparecem no corpo da resposta

### Requirement: Login por e-mail e senha
O sistema SHALL permitir login sem autenticação prévia informando e-mail e senha, respondendo 200
com o token de acesso, seu instante de expiração e os dados do usuário. Credencial incorreta SHALL
responder 401 com `codigo` `CREDENCIAL_INVALIDA`, sem revelar se o e-mail existe. (RF02)

#### Scenario: Login válido devolve token
- **WHEN** um usuário cadastrado envia `POST /api/v1/auth/login` com a senha correta
- **THEN** a resposta é 200 com `token`, `expiraEm` e `usuario`

#### Scenario: Senha incorreta
- **WHEN** um usuário cadastrado envia a senha errada
- **THEN** a resposta é 401 com `codigo` `CREDENCIAL_INVALIDA`

#### Scenario: E-mail inexistente responde como credencial inválida
- **WHEN** alguém tenta entrar com um e-mail que não existe
- **THEN** a resposta é 401 com `codigo` `CREDENCIAL_INVALIDA`, indistinguível da senha errada

### Requirement: Token de acesso e seu conteúdo
O token emitido SHALL ser um JWT assinado com algoritmo simétrico HS256, com validade de 7 dias e
segredo de no mínimo 32 bytes fornecido por variável de ambiente. O token SHALL conter o
identificador do usuário no `sub` e os claims `perfil`, `nome`, `iat` e `exp`. A aplicação SHALL
recusar iniciar se o segredo não atender ao tamanho mínimo. (RF02, RNF01)

#### Scenario: Conteúdo do token
- **WHEN** um login bem-sucedido devolve um token
- **THEN** o token decodificado traz `sub` com o id do usuário, `perfil` com `CLIENTE` ou `DONO`, `nome`, `iat` e `exp`
- **AND** `exp` corresponde a 7 dias após a emissão

#### Scenario: Segredo curto impede a subida
- **WHEN** a aplicação inicia com um segredo de assinatura menor que 32 bytes
- **THEN** a inicialização falha

### Requirement: Validação do token em rotas protegidas
O sistema SHALL operar sem sessão no servidor: toda rota não pública SHALL exigir o cabeçalho
`Authorization: Bearer <jwt>`. Token ausente, expirado, malformado ou com assinatura inválida SHALL
responder 401 com `codigo` `TOKEN_INVALIDO`. Não SHALL existir endpoint de logout nem revogação de
token: encerrar a sessão é responsabilidade do consumidor, e um token válido permanece aceito até
expirar. (RF02, RF03, RNF01, RNF03)

#### Scenario: Rota protegida sem token
- **WHEN** alguém chama `GET /api/v1/usuarios/me` sem o cabeçalho de autorização
- **THEN** a resposta é 401 com `codigo` `TOKEN_INVALIDO`

#### Scenario: Token expirado
- **WHEN** alguém chama uma rota protegida com um token cuja validade já passou
- **THEN** a resposta é 401 com `codigo` `TOKEN_INVALIDO`

### Requirement: Autorização por perfil e por propriedade
O sistema SHALL autorizar em duas etapas depois de validar o token: primeiro o perfil exigido pela
rota, respondendo 403 com `codigo` `ACESSO_NEGADO` quando o perfil não permite a operação; depois a
propriedade do recurso na camada de regras de negócio, respondendo 403 com `codigo` `ACESSO_NEGADO`
quando o recurso pertence a outro usuário. A resposta para recurso de outro usuário SHALL ser 403 e
SHALL NOT ser 404, para não revelar a existência do recurso. (RN01, RN02, RN03, RN04)

#### Scenario: Perfil sem permissão para a rota
- **WHEN** um usuário com perfil `CLIENTE` chama `POST /api/v1/quadras`
- **THEN** a resposta é 403 com `codigo` `ACESSO_NEGADO`

#### Scenario: Recurso de outro usuário
- **WHEN** um DONO tenta editar uma quadra existente que pertence a outro DONO
- **THEN** a resposta é 403 com `codigo` `ACESSO_NEGADO`
- **AND** a resposta não permite distinguir esse caso de uma quadra inexistente pela existência do recurso

### Requirement: Bloqueio temporário de login após falhas consecutivas
O sistema SHALL bloquear novas tentativas de login de um mesmo e-mail por 15 minutos após 5 falhas
consecutivas de credencial, respondendo 429 com `codigo` `LOGIN_BLOQUEADO` mesmo quando a senha
informada está correta. O contador SHALL ser reiniciado por um login bem-sucedido e SHALL expirar
sozinho ao fim do período de bloqueio. (RF04, RNF01)

#### Scenario: Sexta tentativa é bloqueada
- **WHEN** um mesmo e-mail acumula 5 respostas 401 `CREDENCIAL_INVALIDA` seguidas
- **THEN** a tentativa seguinte responde 429 com `codigo` `LOGIN_BLOQUEADO`, mesmo com a senha correta
- **AND** `detail` informa quanto tempo falta para liberar

#### Scenario: Bloqueio expira
- **WHEN** passam 15 minutos desde o início do bloqueio
- **THEN** um login com a senha correta volta a responder 200

#### Scenario: Login correto antes do limite zera o contador
- **WHEN** um e-mail acumula 3 falhas e em seguida faz um login bem-sucedido
- **THEN** o contador volta a zero e são necessárias 5 novas falhas para bloquear

### Requirement: Rotas públicas
O sistema SHALL expor sem autenticação exatamente `POST /api/v1/auth/registrar`,
`POST /api/v1/auth/login`, `POST /api/v1/webhooks/inter/pix/{segredo}`, `GET /actuator/health` e,
nos ambientes em que a documentação está ligada, `/swagger-ui.html` e `/v3/api-docs`. Qualquer outra
rota SHALL exigir token válido. (RNF01)

#### Scenario: Rota de negócio não listada exige token
- **WHEN** alguém chama uma rota de negócio fora dessa lista sem token
- **THEN** a resposta é 401 com `codigo` `TOKEN_INVALIDO`
