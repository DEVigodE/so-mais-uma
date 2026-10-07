## Purpose

Mostra ao cliente quais quadras estão mais perto. Cobre:
- obter a posição do aparelho com permissão pedida no momento certo;
- calcular a distância até cada quadra e ordenar a lista por proximidade;
- abrir o endereço no app de mapas.

O app continua utilizável sem permissão, sem fix de GPS e sem Google Play Services. É o recurso nativo
principal do critério 5.

## ADDED Requirements

### Requirement: Permissão pedida no card, nunca na abertura
O app SHALL NOT pedir permissão de localização na abertura nem na Splash. Sem permissão concedida, a tela
Quadras SHALL mostrar, no topo da lista e no estilo visual do protótipo, o card "Ativar localização para ver
as quadras perto de você" com o botão "Ativar". "Ativar" SHALL pedir `ACCESS_COARSE_LOCATION` e
`ACCESS_FINE_LOCATION` juntas, pelo diálogo do sistema. As respostas SHALL ser tratadas assim:
- **concedida, precisa ou aproximada**: obtém a posição, reordena a lista e esconde o card;
- **negada**: mantém a ordem alfabética e o card com "Ative a localização para ver a distância", e grava
  `permissao_localizacao_pedida`, para não pedir de novo sozinho;
- **negada permanentemente**: o card passa a "Permita a localização nas configurações" e o botão abre as
  configurações do app.

A permissão SHALL ser reavaliada quando o app volta ao primeiro plano. (RF22, RNF08, CT-29)

#### Scenario: Conceder localização aproximada
- **GIVEN** a tela Quadras sem permissão de localização
- **WHEN** o cliente toca "Ativar" e escolhe "aproximada"
- **THEN** o card some, a lista é reordenada por distância e cada card mostra "a X,X km"

#### Scenario: Negar a permissão
- **WHEN** o cliente nega a permissão no diálogo
- **THEN** a lista fica em ordem alfabética e o card mostra "Ative a localização para ver a distância"
- **AND** reabrir a tela não abre o diálogo sozinho

#### Scenario: Permissão concedida nas configurações
- **GIVEN** a permissão negada permanentemente
- **WHEN** o cliente toca o card, concede a localização nas configurações e volta ao app
- **THEN** a lista passa a mostrar as distâncias sem novo toque

### Requirement: Cadeia de fallback da posição
A posição SHALL ser obtida nesta ordem, e cada etapa que falhar ou lançar exceção cai na seguinte, sem
erro visível:
1. posição atual com precisão média e limite de 10 s;
2. última posição conhecida do sistema;
3. `ultima_lat` e `ultima_lon` gravadas pelo app;
4. nenhuma posição.

Toda posição nova SHALL ser gravada em `ultima_lat` e `ultima_lon`. Enquanto a posição é buscada, o card
SHALL mostrar "Obtendo sua localização..." sem bloquear a lista. Se a cadeia terminar sem posição, o card
SHALL mostrar "Não foi possível obter sua localização". A posição SHALL ser obtida ao abrir a tela, no gesto
de puxar para atualizar e ao voltar ao primeiro plano, nunca em segundo plano. (RF22, RNF08, CT-29)

#### Scenario: Ambiente fechado sem fix
- **GIVEN** a permissão concedida e o GPS sem fix em 10 s
- **WHEN** a tela Quadras busca a posição
- **THEN** o app usa a última posição conhecida ou a última gravada, e a lista mostra as distâncias calculadas com ela

#### Scenario: Sem nenhuma posição
- **GIVEN** a permissão concedida, sem fix, sem última posição conhecida e sem posição gravada
- **WHEN** a busca termina
- **THEN** a lista fica em ordem alfabética e aparece "Não foi possível obter sua localização"

### Requirement: Distância e ordenação por proximidade
A distância até cada quadra com latitude e longitude SHALL ser calculada pela fórmula de Haversine, com raio
médio da Terra de 6371 km. O formato SHALL ser "a 850 m" ou "a 2,3 km". As regras de exibição e ordem SHALL
ser:
- **com posição**: a lista é ordenada pela distância crescente, com desempate pelo nome; quadras sem
  coordenadas vão para o fim com "distância indisponível", e nunca são escondidas;
- **faixa de proximidade**: aparece "Quadras ordenadas por proximidade a você"; o botão "Alterar" troca
  para a ordem alfabética ("Quadras em ordem alfabética") e de volta;
- **sem posição**: a ordem é alfabética.

O filtro de esporte e a busca SHALL continuar valendo em qualquer ordem. (RF22, CT-29)

#### Scenario: Quadra sem coordenadas no fim
- **GIVEN** a posição obtida e três quadras, uma delas sem coordenadas
- **WHEN** a lista é exibida
- **THEN** as duas quadras com coordenadas aparecem da mais próxima para a mais distante
- **AND** a terceira vem por último com "distância indisponível"

#### Scenario: Alternar a ordem
- **WHEN** o cliente toca "Alterar" na faixa de proximidade
- **THEN** a lista passa à ordem alfabética e a faixa mostra "Quadras em ordem alfabética"

### Requirement: Distância no detalhe da quadra
Com posição disponível, a DetalheQuadra SHALL mostrar a pílula "a X,X km de você" calculada da mesma forma.
Sem posição ou sem coordenadas da quadra, a pílula SHALL ficar oculta. (RF08, RF22, CT-31)

#### Scenario: Detalhe com distância
- **GIVEN** a posição obtida e uma quadra a 1,2 km
- **WHEN** o cliente abre a DetalheQuadra
- **THEN** aparece a pílula "a 1,2 km de você"

### Requirement: Abrir no Maps e Como chegar
"Abrir no Maps", na DetalheQuadra, e "Como chegar", nas reservas, SHALL abrir o app de mapas instalado pela
URI `geo:<lat>,<lon>?q=<lat>,<lon>(<nome da quadra>)`, sem SDK de mapas e sem chave. As regras SHALL ser:
- "Abrir no Maps" aparece só quando a quadra tem coordenadas;
- "Como chegar", sem coordenadas no cache, usa `geo:0,0?q=<endereço da reserva>`;
- o app não consulta antes se existe app de mapas;
- quando a abertura falha, aparece o snackbar "Nenhum app de mapas instalado".

(RF22, CT-29, CT-31)

#### Scenario: Abrir a quadra no Maps
- **WHEN** o cliente toca "Abrir no Maps" em uma quadra com coordenadas
- **THEN** o app de mapas abre no ponto da quadra com o nome dela

#### Scenario: Aparelho sem app de mapas
- **GIVEN** um aparelho sem nenhum app que responda à URI `geo:`
- **WHEN** o cliente toca "Como chegar"
- **THEN** aparece o snackbar "Nenhum app de mapas instalado"

### Requirement: Funcionamento degradado sem Google Play Services
O app SHALL funcionar em aparelho sem Google Play Services e sem permissão de localização: a lista, o
detalhe e a reserva continuam disponíveis, só sem distância. Nenhuma falha de localização SHALL derrubar a
tela ou exigir ação do usuário. (RNF08, CT-29)

#### Scenario: Emulador sem Google Play Services
- **GIVEN** um emulador com imagem AOSP, sem Google Play Services
- **WHEN** o cliente concede a permissão e abre Quadras
- **THEN** a lista aparece sem erro, com distância se o serviço de localização do Android der posição e em ordem alfabética caso contrário

### Requirement: Acessibilidade da localização
A distância SHALL ser anunciada por extenso ("a 2,3 quilômetros"). O botão do card de localização SHALL ter
texto. "Abrir no Maps" SHALL ter o rótulo do destino. Os alvos de toque do card e dos botões SHALL ter no
mínimo 48 dp. (RNF07)

#### Scenario: Distância lida por extenso
- **GIVEN** o TalkBack ligado
- **WHEN** o foco chega à etiqueta "a 2,3 km"
- **THEN** o leitor anuncia "a 2,3 quilômetros"
