## Purpose

Permite que um DONO publique e mantenha as quadras que aluga e que qualquer pessoa autenticada
encontre e consulte as quadras disponíveis, com endereço, esporte, preço por hora e horários de
funcionamento.

## ADDED Requirements

### Requirement: Cadastro de quadra pelo DONO
O sistema SHALL permitir que um usuário com perfil `DONO` crie uma quadra em `POST /api/v1/quadras`,
respondendo 201 com a quadra criada e o cabeçalho `Location` apontando para ela. A quadra criada
SHALL ter como dono o usuário autenticado, ignorando qualquer dono informado no corpo, e SHALL
nascer ativa. Usuário com perfil `CLIENTE` SHALL receber 403 com `codigo` `ACESSO_NEGADO`.
(RF06, RN01)

#### Scenario: DONO cria uma quadra
- **WHEN** um DONO envia `POST /api/v1/quadras` com nome, esporte, preço por hora e endereço válidos
- **THEN** a resposta é 201 com a quadra criada, `ativa` verdadeiro e `donoId` igual ao do usuário autenticado
- **AND** o cabeçalho `Location` aponta para a quadra criada

#### Scenario: Dono informado no corpo é ignorado
- **WHEN** um DONO envia a criação informando o identificador de outro usuário como dono
- **THEN** a quadra é criada com o usuário autenticado como dono

#### Scenario: CLIENTE não cria quadra
- **WHEN** um CLIENTE envia `POST /api/v1/quadras`
- **THEN** a resposta é 403 com `codigo` `ACESSO_NEGADO`

### Requirement: Dados obrigatórios e validados da quadra
O sistema SHALL exigir nome, esporte, preço por hora, CEP, logradouro, número, cidade e UF para
criar ou editar uma quadra, e SHALL aceitar como opcionais descrição, bairro, latitude, longitude e
URL da foto. O esporte SHALL ser um dos valores de `TipoEsporte`: `FUTEBOL_SOCIETY`, `FUTSAL`,
`VOLEI`, `BASQUETE`, `TENIS`, `BEACH_TENNIS`, `PADEL`. O preço por hora SHALL ser maior que zero. O
CEP SHALL ter exatamente 8 dígitos e a UF exatamente 2 letras maiúsculas. Latitude SHALL estar entre
-90 e 90 e longitude entre -180 e 180. Todo limite de tamanho SHALL espelhar o limite da coluna
correspondente, de modo que entrada grande demais resulte em 400 `VALIDACAO` e nunca em 500.
(RF06, RNF06)

#### Scenario: Campos inválidos são apontados um a um
- **WHEN** um DONO envia a criação com preço por hora zero, CEP com 5 dígitos e UF com 3 letras
- **THEN** a resposta é 400 com `codigo` `VALIDACAO`
- **AND** `campos[]` traz uma entrada para cada um dos três campos

#### Scenario: Texto acima do limite da coluna vira erro de validação
- **WHEN** um DONO envia um nome com mais caracteres do que o limite definido para a coluna
- **THEN** a resposta é 400 com `codigo` `VALIDACAO` e não 500

### Requirement: Listagem pública de quadras ativas com filtros
O sistema SHALL permitir que qualquer usuário autenticado liste as quadras em
`GET /api/v1/quadras`, devolvendo somente quadras ativas, ordenadas por nome, com filtros opcionais
por esporte e por cidade informados em query string. A comparação de cidade SHALL ignorar caixa e
acentuação. Filtro ausente SHALL significar ausência de filtro. Não SHALL haver paginação.
(RF07)

#### Scenario: Filtro por esporte
- **WHEN** um usuário autenticado chama `GET /api/v1/quadras?esporte=FUTSAL`
- **THEN** a resposta é 200 contendo apenas quadras ativas cujo esporte é `FUTSAL`

#### Scenario: Filtro por cidade ignora acento e caixa
- **WHEN** um usuário autenticado chama a listagem filtrando a cidade por `sao paulo`
- **THEN** quadras cadastradas na cidade `São Paulo` aparecem no resultado

#### Scenario: Quadra desativada some da listagem
- **WHEN** uma quadra é desativada e a listagem é chamada de novo
- **THEN** essa quadra não aparece no resultado

#### Scenario: Nenhuma quadra corresponde ao filtro
- **WHEN** o filtro não corresponde a nenhuma quadra ativa
- **THEN** a resposta é 200 com uma lista vazia

### Requirement: Detalhe da quadra com horários de funcionamento
O sistema SHALL permitir que qualquer usuário autenticado obtenha o detalhe de uma quadra em
`GET /api/v1/quadras/{id}`, incluindo na resposta a lista de horários de funcionamento cadastrados.
Quadra inexistente SHALL responder 404 com `codigo` `NAO_ENCONTRADO`. Quadra inativa SHALL responder
404 para usuários que não sejam o seu dono. (RF08, RN09)

#### Scenario: Detalhe traz os horários embutidos
- **WHEN** um usuário autenticado consulta uma quadra ativa que tem horários cadastrados
- **THEN** a resposta é 200 e inclui `horariosFuncionamento` com uma entrada por dia cadastrado

#### Scenario: Quadra inativa é invisível para quem não é o dono
- **WHEN** um CLIENTE consulta uma quadra que foi desativada
- **THEN** a resposta é 404 com `codigo` `NAO_ENCONTRADO`

### Requirement: Listagem das quadras do DONO
O sistema SHALL permitir que um DONO liste as próprias quadras em `GET /api/v1/quadras/minhas`,
incluindo as inativas, com o estado de ativação visível em cada item. A rota SHALL devolver apenas
quadras do usuário autenticado. (RF06, RN03)

#### Scenario: DONO vê as próprias quadras ativas e inativas
- **WHEN** um DONO com uma quadra ativa e uma desativada chama `GET /api/v1/quadras/minhas`
- **THEN** a resposta é 200 com as duas quadras
- **AND** cada item indica se está ativa

#### Scenario: Quadras de outro dono não aparecem
- **WHEN** um DONO chama a rota
- **THEN** nenhuma quadra de outro dono aparece no resultado

### Requirement: Edição de quadra pelo próprio dono
O sistema SHALL permitir que o dono de uma quadra edite seus campos em `PUT /api/v1/quadras/{id}`,
respondendo 200 com a quadra atualizada. Um DONO que não é o dono da quadra SHALL receber 403 com
`codigo` `ACESSO_NEGADO`, mesmo que a quadra exista. Quadra inexistente SHALL responder 404. A
alteração do preço por hora SHALL NOT afetar o valor de reservas já criadas. (RF06, RN01, RN03, RN07)

#### Scenario: Dono altera o preço
- **WHEN** o dono da quadra envia `PUT /api/v1/quadras/{id}` com um preço por hora novo
- **THEN** a resposta é 200 com o preço novo
- **AND** o valor das reservas já existentes nessa quadra permanece o que era no momento de cada reserva

#### Scenario: DONO de outra quadra recebe 403
- **WHEN** um DONO tenta editar uma quadra de outro dono
- **THEN** a resposta é 403 com `codigo` `ACESSO_NEGADO`

### Requirement: Desativação de quadra por exclusão lógica
O sistema SHALL desativar a quadra em `DELETE /api/v1/quadras/{id}`, respondendo 204 e mantendo o
registro no banco para preservar o histórico. A quadra desativada SHALL sair da listagem pública e
SHALL permanecer visível para o seu dono. O sistema SHALL NOT oferecer exclusão física de quadra.
Apenas o dono SHALL poder desativar. (RF06, RN01, RN03)

#### Scenario: Desativação preserva o registro
- **WHEN** o dono chama `DELETE /api/v1/quadras/{id}` de uma quadra sem reservas ativas futuras
- **THEN** a resposta é 204
- **AND** a quadra continua aparecendo em `GET /api/v1/quadras/minhas` marcada como inativa
- **AND** a quadra deixa de aparecer em `GET /api/v1/quadras`

### Requirement: Desativação bloqueada por reservas ativas futuras
O sistema SHALL recusar a desativação de uma quadra que tenha ao menos uma reserva com status
`PENDENTE_PAGAMENTO` ou `CONFIRMADA` e início no futuro, respondendo 409 com `codigo`
`QUADRA_COM_RESERVAS` e informando em `detail` quantas reservas impedem a operação. Depois que essas
reservas forem canceladas, a mesma operação SHALL responder 204. (RF10, RN16)

#### Scenario: Reserva futura impede a desativação
- **WHEN** o dono tenta desativar uma quadra que tem uma reserva `CONFIRMADA` para amanhã
- **THEN** a resposta é 409 com `codigo` `QUADRA_COM_RESERVAS`
- **AND** a quadra permanece ativa

#### Scenario: Reserva encerrada não impede a desativação
- **WHEN** a única reserva futura da quadra está `CANCELADA` ou `EXPIRADA`
- **THEN** a desativação responde 204

#### Scenario: Reserva no passado não impede a desativação
- **WHEN** a quadra só tem reservas confirmadas cujo início já passou
- **THEN** a desativação responde 204
