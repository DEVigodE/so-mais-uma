## Purpose

Permite que o dono de uma quadra preencha o endereço a partir do CEP, incluindo coordenadas
geográficas quando disponíveis, consultando serviços públicos de CEP sempre pelo backend, nunca
diretamente pelo aplicativo.

## ADDED Requirements

### Requirement: Consulta de CEP pelo backend
O sistema SHALL expor `GET /api/v1/cep/{cep}` para usuários com perfil `DONO`, respondendo 200 com
CEP, logradouro, bairro, cidade, UF, latitude e longitude quando disponíveis, e a fonte que
respondeu. O aplicativo consumidor SHALL NOT chamar os serviços de CEP diretamente. (RF09)

#### Scenario: CEP encontrado com coordenadas
- **WHEN** um DONO chama `GET /api/v1/cep/01001000`
- **THEN** a resposta é 200 com logradouro, bairro, cidade e UF preenchidos
- **AND** `latitude` e `longitude` vêm preenchidas quando a fonte as fornece
- **AND** `fonte` indica qual serviço respondeu

#### Scenario: CLIENTE não consulta CEP
- **WHEN** um CLIENTE chama a rota de CEP
- **THEN** a resposta é 403 com `codigo` `ACESSO_NEGADO`

### Requirement: Validação do formato do CEP
O sistema SHALL aceitar apenas CEP com exatamente 8 dígitos. Qualquer outro formato SHALL responder
400 com `codigo` `VALIDACAO`, sem chamar nenhum serviço externo. (RF09)

#### Scenario: CEP com formato inválido
- **WHEN** um DONO chama a rota com `0100-100` ou com 5 dígitos
- **THEN** a resposta é 400 com `codigo` `VALIDACAO`
- **AND** nenhum serviço externo é chamado

### Requirement: Fonte primária com fallback
O sistema SHALL consultar primeiro a fonte primária de CEP e, quando ela falhar ou não responder no
tempo limite, SHALL consultar a fonte secundária antes de devolver erro. A resposta SHALL indicar
qual das duas fontes foi usada. Quando a fonte usada não fornece coordenadas, `latitude` e
`longitude` SHALL vir vazias e o restante do endereço SHALL ser devolvido normalmente. (RF09)

#### Scenario: Fonte primária indisponível
- **WHEN** a fonte primária responde com erro e a secundária responde com sucesso
- **THEN** a resposta é 200 com o endereço da fonte secundária
- **AND** `fonte` indica a fonte secundária

#### Scenario: Fonte sem coordenadas
- **WHEN** a fonte que respondeu não fornece coordenadas
- **THEN** a resposta é 200 com `latitude` e `longitude` vazias
- **AND** o consumidor pode preencher as coordenadas manualmente ao cadastrar a quadra

### Requirement: CEP inexistente e indisponibilidade das fontes
O sistema SHALL responder 404 com `codigo` `NAO_ENCONTRADO` quando o CEP consultado não existe, e
SHALL responder 503 com `codigo` `CEP_INDISPONIVEL` quando as duas fontes falharem. O consumidor
SHALL continuar podendo cadastrar a quadra informando o endereço manualmente nesse caso. (RF09)

#### Scenario: CEP inexistente
- **WHEN** um DONO consulta um CEP com formato válido que não existe em nenhuma das fontes
- **THEN** a resposta é 404 com `codigo` `NAO_ENCONTRADO`

#### Scenario: Ambas as fontes falham
- **WHEN** a fonte primária e a secundária falham ou estouram o tempo limite
- **THEN** a resposta é 503 com `codigo` `CEP_INDISPONIVEL`

### Requirement: Limite de tempo da consulta externa
O sistema SHALL aplicar um limite de tempo curto a cada consulta externa de CEP, de modo que a
indisponibilidade de um serviço não prenda a requisição do usuário. Estourar o tempo limite SHALL
ser tratado como falha daquela fonte e SHALL acionar o fallback. (RF09, RNF04)

#### Scenario: Fonte primária lenta aciona o fallback
- **WHEN** a fonte primária não responde dentro do limite de tempo
- **THEN** o sistema consulta a fonte secundária
- **AND** a requisição do usuário termina sem esperar indefinidamente
