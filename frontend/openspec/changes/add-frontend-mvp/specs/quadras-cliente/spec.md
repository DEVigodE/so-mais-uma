## Purpose

Permite que o cliente encontre uma quadra no catálogo, filtrando por cidade, bairro e esporte, e veja os
dados da quadra antes de escolher um horário. A filtragem roda sobre o catálogo guardado no aparelho, para
funcionar também sem rede. O DONO pode ver a parte estática do detalhe das próprias quadras.

## ADDED Requirements

### Requirement: Fidelidade da tela Quadras ao protótipo
A tela Quadras (`/quadras`) SHALL reproduzir `docs/Protótipo de Alta Fidelidade/quadras/code.html`:
- barra fixa com o logo, "Só mais uma", o ícone de localização com "Quadras" e o avatar de iniciais com o
  ponto de status, verde quando o backend está alcançável e cinza quando não está;
- campo de busca com o placeholder "Buscar por cidade ou bairro...";
- carrossel de chips "Todos" seguido dos 7 valores de `TipoEsporte`, nesta ordem: Futebol Society, Futsal,
  Beach Tennis, Vôlei, Basquete, Tênis e Padel;
- faixa "Quadras ordenadas por proximidade a você" quando há localização, ou o card de ativação de
  localização quando não há;
- lista de cards de quadra;
- rodapé com o ponto pulsante e "Sincronizado há X min • Disponibilidade em tempo real".

O card SHALL ter:
- imagem 16:9 com a etiqueta de distância no canto superior direito, quando há distância, e a etiqueta de
  esporte no canto inferior esquerdo;
- nome, linha de localização "<bairro>, <cidade>" (só a cidade quando o bairro é nulo) e bloco
  "A partir de" com o preço por hora seguido de "/h";
- botão "Ver horários".

Os ícones dos chips SHALL ser os do protótipo, com estas exceções: Futsal usa o ícone de bola de futebol,
porque o ícone de upload do protótipo é erro evidente; Tênis e Padel usam o ícone de tênis. Elementos
omitidos:
- as estrelas de avaliação;
- o selo "Últimos horários hoje";
- o botão de filtros avançados (`tune`);
- o chip "Futevôlei", que não existe no enum.

(RF07, RF22, RF23)

#### Scenario: Elementos sem dado não aparecem
- **WHEN** a tela Quadras é exibida com o catálogo do seed
- **THEN** nenhum card mostra estrelas de avaliação nem o selo "Últimos horários hoje"
- **AND** não existe botão de filtros avançados nem chip "Futevôlei"

#### Scenario: Chips de todos os esportes
- **WHEN** o usuário rola o carrossel de chips
- **THEN** ele encontra "Todos" e os chips Futebol Society, Futsal, Beach Tennis, Vôlei, Basquete, Tênis e Padel

#### Scenario: Rodapé de sincronização
- **GIVEN** a última sincronização do catálogo há 2 minutos e o backend alcançável
- **WHEN** o usuário rola até o fim da lista
- **THEN** o rodapé mostra "Sincronizado há 2 min • Disponibilidade em tempo real"

### Requirement: Catálogo filtrado localmente
O app SHALL sincronizar o catálogo com `GET /quadras` sem parâmetros e aplicar os filtros localmente:
- a busca encontra as quadras cuja `cidade` ou cujo `bairro` contém o texto digitado, ignorando acentos e
  caixa;
- o chip escolhe um único `TipoEsporte`, e "Todos" remove o filtro de esporte;
- busca e chip combinam com "e";
- a busca reage enquanto o usuário digita, com espera de 300 ms.

O comportamento por estado SHALL ser:
- **primeira carga sem cache**: esqueleto de 3 cards;
- **com cache**: a lista aparece na hora, e a sincronização roda em seguida com um indicador discreto;
- **filtro sem resultado**: "Nenhuma quadra encontrada" com o botão "Limpar filtros";
- **catálogo vazio**: "Ainda não há quadras cadastradas";
- **falha de carga sem cache**: a caixa de erro com "Tentar novamente";
- **falha com cache**: a lista é mantida e a falha aparece em snackbar.

O gesto de puxar para atualizar SHALL sincronizar de novo. (RF07, RNF04, RNF06, CT-12)

#### Scenario: Filtro por esporte
- **GIVEN** o catálogo com quadras de Futsal e de Futebol Society
- **WHEN** o usuário toca o chip "Futsal"
- **THEN** a lista mostra só as quadras de Futsal, e o chip aparece selecionado

#### Scenario: Busca por bairro sem acento
- **GIVEN** uma quadra no bairro "Jardim São Paulo"
- **WHEN** o usuário digita "jardim sao"
- **THEN** essa quadra aparece na lista

#### Scenario: Filtro sem resultado
- **WHEN** o usuário busca uma cidade que não existe no catálogo
- **THEN** aparece "Nenhuma quadra encontrada" com o botão "Limpar filtros"
- **AND** tocar "Limpar filtros" restaura a lista completa

#### Scenario: Quadra desativada some do catálogo
- **GIVEN** uma quadra desativada pelo dono depois da última sincronização
- **WHEN** o cliente puxa a lista para atualizar
- **THEN** essa quadra deixa de aparecer

### Requirement: Abertura do detalhe da quadra
Tocar o card ou o botão "Ver horários" SHALL abrir a DetalheQuadra da quadra (`/quadras/:id`) por cima do
shell, sem bottom-nav. (RF08)

#### Scenario: Ver horários
- **WHEN** o cliente toca "Ver horários" no card de uma quadra
- **THEN** abre a DetalheQuadra dessa quadra, e o voltar retorna à lista na mesma posição

### Requirement: Fidelidade da parte estática da DetalheQuadra
A DetalheQuadra SHALL reproduzir a parte superior de `docs/Protótipo de Alta Fidelidade/detalhe_da_quadra/code.html`:
- barra com voltar, logo, título "Detalhes Da Quadra" e avatar;
- imagem de destaque com cantos inferiores arredondados, degradê, etiqueta de esporte no canto superior
  esquerdo e o bloco "A partir de" com o preço seguido de "/ hora";
- nome da quadra;
- linha de endereço "<logradouro>, <número> - <bairro>, <cidade>";
- pílula "a X km de você", quando há distância, e botão "Abrir no Maps", quando a quadra tem coordenadas;
- cartão "Sobre o espaço" com a descrição, omitido quando a descrição é vazia;
- cartão "Horários de Funcionamento" com as linhas agrupadas.

Elementos omitidos:
- o selo "Padrão FIFA";
- a avaliação com estrelas e número de avaliações;
- a grade de comodidades (Chuveiro, Vagas, Churrasco, Wi-Fi).

(RF08, RF22)

#### Scenario: Quadra sem descrição e sem coordenadas
- **GIVEN** uma quadra sem descrição e sem latitude e longitude
- **WHEN** a DetalheQuadra é aberta
- **THEN** o cartão "Sobre o espaço" e o botão "Abrir no Maps" não aparecem
- **AND** a pílula de distância não aparece

#### Scenario: Comodidades e avaliação não aparecem
- **WHEN** a DetalheQuadra de qualquer quadra é aberta
- **THEN** não aparecem "Padrão FIFA", estrelas, número de avaliações nem a grade de comodidades

### Requirement: Horários de funcionamento agrupados
O cartão "Horários de Funcionamento" SHALL percorrer os dias de segunda a domingo e agrupar dias consecutivos
com o mesmo estado:
- mesma faixa de abertura e fechamento;
- ou fechado, que é o dia sem registro.

Cada grupo SHALL virar uma linha "<dias>: <HH:mm> – <HH:mm>" ou "<dias>: Fechado". O rótulo do grupo
SHALL ser:
- o nome do dia, quando o grupo tem um dia;
- "<primeiro> e <segundo>", quando tem dois dias;
- "<primeiro> a <último>", quando tem três ou mais.

O agrupamento SHALL NOT juntar domingo com a segunda-feira seguinte. Quadra sem nenhuma faixa SHALL mostrar
"Esta quadra ainda não tem horários cadastrados". (RF08, RN19, CT-31)

#### Scenario: Semana com fim de semana diferente
- **GIVEN** a quadra abre das 07:00 às 23:00 de segunda a sexta, das 08:00 às 22:00 no sábado e não tem faixa no domingo
- **WHEN** a DetalheQuadra é exibida
- **THEN** o cartão mostra "Segunda a Sexta: 07:00 – 23:00", "Sábado: 08:00 – 22:00" e "Domingo: Fechado"

#### Scenario: Dois dias iguais
- **GIVEN** sábado e domingo com a mesma faixa das 08:00 às 22:00
- **WHEN** o cartão é montado
- **THEN** a linha é "Sábado e Domingo: 08:00 – 22:00"

### Requirement: Carga do detalhe com cache e servidor
A DetalheQuadra SHALL mostrar na hora os dados da quadra guardados no cache. Com rede, SHALL buscar
`GET /quadras/{id}` e gravar a resposta no cache, atualizando a tela. O comportamento por resultado SHALL
ser:
- **404 `NAO_ENCONTRADO`**: a caixa de erro "Quadra não encontrada" com o botão Voltar, e a quadra sai do
  cache do catálogo;
- **sem rede**: a parte estática vem do cache, inclusive os horários de funcionamento.

(RF08, RF23, CT-31, CT-28)

#### Scenario: Quadra desativada aberta pelo cliente
- **GIVEN** a quadra ainda está no cache, mas foi desativada no servidor
- **WHEN** o cliente abre o detalhe com rede
- **THEN** aparece "Quadra não encontrada" com o botão Voltar

#### Scenario: Detalhe em modo avião
- **GIVEN** a quadra sincronizada antes e o aparelho em modo avião
- **WHEN** o cliente abre a DetalheQuadra
- **THEN** nome, endereço, preço, descrição e horários de funcionamento aparecem a partir do cache

### Requirement: DetalheQuadra do DONO
O DONO SHALL abrir a DetalheQuadra das próprias quadras em `/dono/quadras/:id`, tocando o card em
MinhasQuadras fora dos botões de ação. Essa variante SHALL mostrar apenas a parte estática, sem a seleção de
data, sem a grade de slots e sem a barra de horário selecionado, porque o DONO não reserva. (RF08, RN02)

#### Scenario: Dono vê a quadra sem grade
- **GIVEN** um DONO na tela MinhasQuadras
- **WHEN** ele toca o card de uma das quadras
- **THEN** abre o detalhe com foto, endereço, descrição e horários de funcionamento
- **AND** não aparecem a faixa de datas, a grade de slots nem a barra "Horário selecionado"

### Requirement: Acessibilidade de Quadras e DetalheQuadra
O conjunto de acessibilidade SHALL incluir:
- cada card tem um rótulo único, por exemplo "Quadra Arena Sul, futebol society, R$ 80,00 por hora, a 2,3 km";
- os chips anunciam o estado selecionado;
- o campo de busca tem o rótulo "Buscar quadras por cidade ou bairro";
- o botão de localização tem texto, e não só ícone;
- "Abrir no Maps" é anunciado como "Abrir endereço da quadra no aplicativo de mapas";
- a caixa de erro oferece "Tentar novamente" como alternativa ao gesto de puxar para atualizar.

(RNF07)

#### Scenario: Card lido de uma vez
- **GIVEN** o TalkBack ligado e a localização concedida
- **WHEN** o foco chega a um card de quadra
- **THEN** o leitor anuncia nome, esporte, preço por hora e distância em uma única frase
