## Purpose

Permite que a pessoa autenticada consulte e mantenha atualizados os próprios dados de contato e a
própria senha, sem poder alterar o que identifica a conta (e-mail) nem o que define suas permissões
(perfil).

## ADDED Requirements

### Requirement: Consulta dos próprios dados
O sistema SHALL permitir que qualquer usuário autenticado, de qualquer perfil, obtenha os próprios
dados em `GET /api/v1/usuarios/me`, respondendo 200 com identificador, nome, e-mail, telefone,
perfil e instante de criação da conta. A rota SHALL devolver sempre os dados do portador do token e
SHALL NOT aceitar identificador de outro usuário. (RF05, RN04)

#### Scenario: Usuário lê o próprio cadastro
- **WHEN** um usuário autenticado chama `GET /api/v1/usuarios/me`
- **THEN** a resposta é 200 com `id`, `nome`, `email`, `telefone`, `perfil` e `criadoEm` do próprio usuário
- **AND** o hash da senha não aparece na resposta

### Requirement: Edição de nome e telefone
O sistema SHALL permitir que o usuário autenticado altere o próprio nome e o próprio telefone em
`PUT /api/v1/usuarios/me`, respondendo 200 com os dados atualizados. Valores que violem os limites
de tamanho SHALL responder 400 com `codigo` `VALIDACAO` e `campos[]`. (RF05)

#### Scenario: Telefone alterado persiste
- **WHEN** um usuário envia `PUT /api/v1/usuarios/me` com um telefone novo
- **THEN** a resposta é 200 com o telefone novo
- **AND** uma consulta seguinte a `GET /api/v1/usuarios/me` devolve o telefone novo

#### Scenario: Nome em branco é rejeitado
- **WHEN** um usuário envia `PUT /api/v1/usuarios/me` com nome vazio
- **THEN** a resposta é 400 com `codigo` `VALIDACAO` e uma entrada em `campos[]` para o nome

### Requirement: Troca de senha exigindo a senha atual
O sistema SHALL permitir a troca de senha na mesma operação de edição do perfil, exigindo a senha
atual junto da nova. Senha atual incorreta SHALL responder 422 com `codigo` `REGRA_NEGOCIO` e
`subcodigo` `SENHA_ATUAL_INCORRETA`. A nova senha SHALL obedecer à mesma política de senha do
cadastro. Após a troca, apenas a senha nova SHALL ser aceita no login. (RF05, RNF01)

#### Scenario: Troca de senha bem-sucedida
- **WHEN** um usuário envia senha atual correta e uma nova senha válida
- **THEN** a resposta é 200
- **AND** um login seguinte com a senha antiga responde 401 `CREDENCIAL_INVALIDA`
- **AND** um login seguinte com a senha nova responde 200

#### Scenario: Senha atual incorreta
- **WHEN** um usuário envia uma senha atual que não confere
- **THEN** a resposta é 422 com `codigo` `REGRA_NEGOCIO` e `subcodigo` `SENHA_ATUAL_INCORRETA`
- **AND** a senha armazenada permanece inalterada

#### Scenario: Nova senha fora da política
- **WHEN** um usuário envia senha atual correta e uma nova senha com menos de 8 caracteres
- **THEN** a resposta é 400 com `codigo` `VALIDACAO`
- **AND** a senha armazenada permanece inalterada

### Requirement: E-mail e perfil não são editáveis
A operação de edição do próprio perfil SHALL NOT aceitar alteração de e-mail nem de perfil. Esses
campos SHALL ser ignorados quando enviados no corpo da requisição. (RF05, RN20)

#### Scenario: Tentativa de trocar o e-mail é ignorada
- **WHEN** um usuário envia `PUT /api/v1/usuarios/me` incluindo um e-mail e um perfil diferentes dos atuais
- **THEN** a resposta é 200 e os dados devolvidos mantêm o e-mail e o perfil originais

### Requirement: Desativação da própria conta
O sistema MAY oferecer `DELETE /api/v1/usuarios/me` para que o usuário desative a própria conta por
exclusão lógica, respondendo 204. Quando o usuário é DONO e possui reservas ativas futuras em suas
quadras, a operação SHALL ser recusada com 409 e `codigo` `QUADRA_COM_RESERVAS`. Este requisito é
opcional no MVP e pode ser deixado de fora sem afetar os demais. (RN16)

#### Scenario: Desativação bloqueada por reservas futuras
- **WHEN** um DONO com uma reserva ativa futura em uma de suas quadras chama `DELETE /api/v1/usuarios/me`
- **THEN** a resposta é 409 com `codigo` `QUADRA_COM_RESERVAS`
- **AND** a conta permanece ativa
