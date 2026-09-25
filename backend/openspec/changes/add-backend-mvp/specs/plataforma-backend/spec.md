## Purpose

Define as convenções transversais que toda a API do backend obedece: prefixo e formato das rotas,
representação de datas, dinheiro e enums, formato único de erro, fuso horário de referência,
superfície exposta em cada ambiente de execução e as regras de evolução do esquema e do contrato.

## ADDED Requirements

### Requirement: Prefixo e formato das rotas de negócio
Toda rota de negócio SHALL ficar sob o prefixo `/api/v1` e trocar JSON com
`Content-Type: application/json; charset=utf-8`, sem envelope: o corpo da resposta é o próprio
recurso ou a lista de recursos, com chaves em camelCase. As únicas rotas fora do prefixo SHALL ser
`/actuator/health`, `/swagger-ui.html` e `/v3/api-docs`. (RNF09)

#### Scenario: Rota de negócio responde sob o prefixo
- **WHEN** um cliente chama `GET /api/v1/quadras` com token válido
- **THEN** a resposta é 200 com um array JSON de quadras no corpo, sem campo agregador `data` ou `success`
- **AND** as chaves usam camelCase, como `precoHora` e `tipoEsporte`

#### Scenario: Health check fica fora do prefixo
- **WHEN** alguém chama `GET /actuator/health` sem autenticação
- **THEN** a resposta é 200 indicando que a aplicação está no ar

### Requirement: Representação de datas, dinheiro e enums
A API SHALL representar instantes em ISO-8601 com offset, valores monetários como string decimal
com duas casas e ponto, identificadores como inteiros longos e enums como as strings maiúsculas
exatas do domínio. Datas puras (`2026-10-10`) e horas puras (`08:00`) SHALL ser usadas apenas nos
campos que o contrato declara como tais. Um valor de enum desconhecido na entrada SHALL gerar 400
com `codigo` `VALIDACAO`. (RNF09, RNF12)

#### Scenario: Instante e dinheiro em uma resposta de reserva
- **WHEN** a API devolve uma reserva
- **THEN** `inicio` vem no formato `2026-10-10T19:00:00-03:00` e `valor` vem como a string `"80.00"`
- **AND** `valor` nunca é um número JSON

#### Scenario: Enum desconhecido na entrada
- **WHEN** um DONO envia `POST /api/v1/quadras` com `tipoEsporte` igual a `HANDEBOL`
- **THEN** a resposta é 400 com `codigo` `VALIDACAO`

### Requirement: Formato único de erro
Toda resposta de erro SHALL ser um `ProblemDetail` conforme a RFC 9457 com as extensões `codigo`
(estável, é o que o consumidor usa para decidir o comportamento) e `timestamp` sempre presentes,
`subcodigo` presente somente nas respostas 422, `campos[]` presente nos erros de validação e
`reservaId` presente no 422 de reserva pendente existente. O campo `detail` SHALL ser uma frase em
português pronta para exibição e SHALL NOT ser usado pelo consumidor para decidir comportamento.
Nenhuma resposta de erro SHALL expor stack trace. (RNF06, RNF09, RNF10)

#### Scenario: Erro de validação traz os campos
- **WHEN** um DONO envia `POST /api/v1/quadras` com `precoHora` abaixo do mínimo e `cep` com 5 dígitos
- **THEN** a resposta é 400 com `codigo` `VALIDACAO` e `timestamp` preenchido
- **AND** `campos[]` contém uma entrada para `precoHora` e outra para `cep`, cada uma com `campo` e `mensagem`

#### Scenario: Erro 422 traz subcódigo
- **WHEN** uma regra de negócio é violada
- **THEN** a resposta é 422 com `codigo` `REGRA_NEGOCIO` e um `subcodigo` que identifica a regra violada

#### Scenario: Exceção não mapeada
- **WHEN** ocorre uma falha inesperada durante o processamento
- **THEN** a resposta é 500 com `codigo` `ERRO_INTERNO` e sem stack trace no corpo
- **AND** a exceção original é registrada por completo no log da aplicação

### Requirement: Catálogo estável de códigos de erro
O sistema SHALL usar exclusivamente os seguintes pares de status e `codigo`: 400 `VALIDACAO`;
401 `CREDENCIAL_INVALIDA`; 401 `TOKEN_INVALIDO`; 403 `ACESSO_NEGADO`; 404 `NAO_ENCONTRADO`;
409 `EMAIL_JA_CADASTRADO`; 409 `HORARIO_INDISPONIVEL`; 409 `DIA_JA_CADASTRADO`;
409 `QUADRA_COM_RESERVAS`; 409 `HORARIO_COM_RESERVAS`; 422 `REGRA_NEGOCIO`; 429 `LOGIN_BLOQUEADO`;
500 `ERRO_INTERNO`; 502 `PAGAMENTO_INDISPONIVEL`; 503 `CEP_INDISPONIVEL`. Os valores de `subcodigo`
válidos em 422 SHALL ser `DATA_FORA_DA_JANELA`, `FORA_DO_FUNCIONAMENTO`,
`RESERVA_PENDENTE_EXISTENTE`, `CANCELAMENTO_FORA_DO_PRAZO`, `TRANSICAO_INVALIDA` e
`SENHA_ATUAL_INCORRETA`. (RNF09)

#### Scenario: Consumidor decide pelo par código e subcódigo
- **WHEN** o consumidor recebe uma resposta 422
- **THEN** `codigo` é sempre `REGRA_NEGOCIO`
- **AND** `subcodigo` é um dos seis valores do catálogo

### Requirement: Fuso horário único de referência
Todo cálculo de data e hora com efeito de negócio SHALL usar o fuso `America/Sao_Paulo`. A API
SHALL aceitar instantes em qualquer offset e convertê-los para esse fuso antes de aplicar regras, e
SHALL responder sempre com o offset correspondente a esse fuso. O instante de referência para as
regras ("agora") SHALL ser o relógio do backend nesse fuso. Quadras em fusos diferentes estão fora
do escopo. (RNF12, RN06)

#### Scenario: Instante enviado em outro offset cai no mesmo slot
- **WHEN** um CLIENTE envia `inicio` como `2026-10-10T22:00:00Z`
- **THEN** o sistema trata o valor como `2026-10-10T19:00:00-03:00`
- **AND** a reserva criada disputa o mesmo slot de quem enviou `2026-10-10T19:00:00-03:00`

### Requirement: Superfície exposta por ambiente de execução
O sistema SHALL suportar três ambientes de execução selecionáveis por variável de ambiente, sem
reconstruir o artefato: `simulado` (padrão), `inter-sandbox` e `inter-prod`. O endpoint de simulação
de pagamento SHALL existir apenas em `simulado` e `inter-sandbox`; o receptor de webhook do provedor
externo e a consulta periódica de pagamentos SHALL existir apenas em `inter-sandbox` e `inter-prod`;
a documentação interativa da API SHALL estar disponível em `simulado` e `inter-sandbox` e desligada
em `inter-prod`. O ambiente padrão SHALL subir sem exigir nenhuma credencial de terceiro. (RNF05, RNF02)

#### Scenario: Ambiente padrão sobe sem credencial externa
- **WHEN** a aplicação inicia sem nenhuma variável de credencial do provedor Pix externo
- **THEN** ela sobe no ambiente `simulado` e responde o health check indicando que está no ar

#### Scenario: Endpoint de simulação não existe em produção
- **WHEN** a aplicação está no ambiente `inter-prod`
- **THEN** `POST /api/v1/dev/pagamentos/{txid}/confirmar` responde 404
- **AND** `/swagger-ui.html` e `/v3/api-docs` não respondem

### Requirement: Documentação viva da API
O sistema SHALL publicar o contrato OpenAPI em `/v3/api-docs` e uma interface interativa em
`/swagger-ui.html` nos ambientes em que a documentação está ligada, com esquema de segurança
`bearerAuth` aplicado globalmente, agrupamento por área funcional e os valores de `codigo` possíveis
declarados em cada operação. (RNF10)

#### Scenario: Autenticar e executar pela documentação interativa
- **WHEN** alguém abre `/swagger-ui.html`, obtém um token por `POST /api/v1/auth/login` e o informa no botão de autorização
- **THEN** as chamadas seguintes feitas pela interface enviam o cabeçalho `Authorization: Bearer <token>`
- **AND** todas as rotas de negócio documentadas aparecem agrupadas por área

### Requirement: Dados que o sistema não armazena
O sistema SHALL NOT armazenar dados do pagador Pix (nome, documento, `infoPagador`, `devedor`),
dados bancários ou de cartão, senha em texto claro, credenciais do provedor externo, o segredo de
assinatura do token, a chave do endpoint de simulação, certificados ou o token emitido a um usuário.
Segredos SHALL ser fornecidos apenas por variável de ambiente ou arquivo secreto do ambiente de
execução e SHALL NOT ser versionados no repositório. (RNF02, RN05)

#### Scenario: Resposta de pagamento não expõe pagador
- **WHEN** o consumidor lê o estado de uma cobrança
- **THEN** a resposta contém apenas `txid`, `provedor`, `status`, `valor`, `pixCopiaECola`, `expiraEm` e `pagoEm`
- **AND** não contém nenhum dado de quem efetuou o pagamento nem o identificador fim a fim da transação

### Requirement: Evolução controlada do esquema do banco
O esquema do banco SHALL ser criado e evoluído exclusivamente por migrações versionadas aplicadas na
inicialização, e o mapeamento objeto-relacional SHALL apenas validar o esquema existente, nunca
alterá-lo. Depois da primeira entrega, as migrações SHALL ser somente aditivas: é permitido
acrescentar tabela, coluna, índice ou restrição de verificação, e SHALL NOT ser permitido remover ou
renomear coluna nem alterar o tipo de uma coluna existente. A carga de dados de demonstração SHALL
ficar fora das migrações. (RNF10)

#### Scenario: Esquema divergente impede a subida
- **WHEN** a aplicação inicia contra um banco cujo esquema não corresponde ao mapeamento das entidades
- **THEN** a inicialização falha com erro de validação de esquema
- **AND** nenhuma alteração automática de esquema é aplicada

### Requirement: Contrato aditivo após a primeira entrega
A partir da primeira entrega etiquetada, a API SHALL evoluir de forma aditiva: campos de resposta só
podem ser acrescentados e sempre opcionais; campos novos de requisição são opcionais com valor
padrão no servidor; valores de enum não são removidos; `codigo` e `subcodigo` não são renomeados;
rotas e métodos existentes não mudam de semântica. Uma mudança incompatível SHALL exigir um novo
prefixo de versão. (RNF09)

#### Scenario: Aplicação instalada continua funcionando após evolução
- **WHEN** o backend acrescenta um campo opcional a uma resposta e um novo valor a um enum
- **THEN** um consumidor construído contra o contrato anterior continua processando a resposta sem erro
