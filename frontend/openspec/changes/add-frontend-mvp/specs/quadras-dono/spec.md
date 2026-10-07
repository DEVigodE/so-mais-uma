## Purpose

Permite que o DONO acompanhe as próprias quadras com as métricas do dia, cadastre e edite quadras com
preenchimento de endereço pelo CEP e desative uma quadra sem deixar reservas futuras órfãs. É o primeiro dos
dois CRUDs completos exigidos pelo critério 3 da disciplina.

## ADDED Requirements

### Requirement: Fidelidade de MinhasQuadras ao protótipo
MinhasQuadras (`/dono/quadras`) SHALL reproduzir `docs/Protótipo de Alta Fidelidade/minhas_quadras/code.html`:
- barra com o logo, "Só mais uma", o rótulo "Área do Proprietário" e o avatar;
- cabeçalho "PAINEL DE GESTÃO" / "Minhas Quadras";
- painel em degradê verde com a pílula de operação, a data de hoje ("Hoje, 24 de Outubro"), o bloco
  "Total de Quadras" com o número e "cadastradas" e o bloco "Reservas Hoje" com o número e "confirmadas";
- linha "Espaços Esportivos" com a contagem e a indicação de ordem "Mais ativas";
- cards de quadra;
- rodapé "Sincronizado há X min • Conexão estável";
- botão flutuante estendido "Nova quadra".

A pílula de operação SHALL mostrar "Operação em tempo real" quando o backend está alcançável e
"Modo cache ativo" quando não está.

O card ativo SHALL ter:
- imagem com degradê, selo "Ativa", menu de opções e, sobre a imagem, o esporte, o nome e o bloco
  "por hora" com o preço;
- linha de atividade com o ícone do esporte, "<n> reservas hoje", "Próxima às <HH:mm>" e a ocupação
  "<p>% lotada";
- ações "Editar", "Horários" e "Reservas".

O card inativo SHALL ter a imagem dessaturada, o selo "Inativa", a linha "Horários suspensos" com
"<n> reservas hoje" e a etiqueta "Pausada", e as ações "Editar" e "Horários".

Elementos omitidos:
- o sino de notificações, porque push está fora do MVP;
- a ação "Reativar", porque não existe endpoint de reativação;
- o menu de opções no card inativo, que não teria ação.

(RF06, RF10)

#### Scenario: Card inativo sem reativar
- **GIVEN** o DONO com uma quadra desativada
- **WHEN** MinhasQuadras é exibida
- **THEN** o card dessa quadra mostra "Inativa", "Horários suspensos" e "Pausada"
- **AND** oferece só "Editar" e "Horários", sem "Reativar" e sem menu de opções

#### Scenario: Sem sino de notificações
- **WHEN** MinhasQuadras é exibida
- **THEN** a tela não tem botão de notificações

### Requirement: Métricas calculadas de MinhasQuadras
As métricas SHALL ser calculadas a partir de `quadra_cache` (escopo `MINHAS`, com `horarios_json`) e de
`reserva_cache`, no fuso de Brasília. As fórmulas SHALL ser:
- **"Total de Quadras"**: quantidade de quadras do escopo `MINHAS`, ativas e inativas;
- **"Reservas Hoje"**: quantidade de reservas `CONFIRMADA` com início hoje em todas as quadras do dono;
- **"<n> reservas hoje" do card**: quantidade de reservas `PENDENTE_PAGAMENTO` ou `CONFIRMADA` da quadra
  com início hoje;
- **"Próxima às"**: menor início futuro entre essas reservas, ou "Sem próximas hoje" quando não há;
- **ocupação**: `n` dividido pelo número de slots de hoje (horas entre abertura e fechamento da faixa do dia
  da semana), arredondado para o inteiro mais próximo;
- **sem faixa no dia**: o card mostra "Fechada hoje" no lugar da ocupação.

A ordem "Mais ativas" SHALL listar as ativas antes das inativas, depois `n` decrescente e, no empate, o nome.
Nenhuma métrica SHALL ser preenchida com valor fixo. (RF06, RF18, RN19)

#### Scenario: Ocupação do dia
- **GIVEN** uma quadra que abre das 08:00 às 22:00 hoje, com 6 reservas ativas hoje e a próxima às 18:00
- **WHEN** o DONO abre MinhasQuadras às 15:10
- **THEN** o card mostra "6 reservas hoje", "Próxima às 18:00" e "43% lotada"

#### Scenario: Quadra fechada hoje
- **GIVEN** uma quadra sem faixa de funcionamento no dia da semana de hoje
- **WHEN** MinhasQuadras é exibida
- **THEN** o card mostra "Fechada hoje" no lugar da ocupação

#### Scenario: Painel conta só confirmadas
- **GIVEN** hoje existem 3 reservas `CONFIRMADA` e 1 `PENDENTE_PAGAMENTO` nas quadras do dono
- **WHEN** o painel é exibido
- **THEN** "Reservas Hoje" mostra 3

### Requirement: Lista e ações de MinhasQuadras
MinhasQuadras SHALL sincronizar com `GET /quadras/minhas` e ligar as ações:
- **botão flutuante**: abre a FormQuadra nova (`/dono/quadras/nova`);
- **"Editar"**: abre `/dono/quadras/:id/editar`;
- **"Horários"**: abre `/dono/quadras/:id/horarios`;
- **"Reservas"**: abre `/dono/quadras/:id/reservas`;
- **toque no card fora dos botões**: abre a DetalheQuadra do DONO;
- **menu de opções**: oferece "Desativar quadra".

Sem quadras, a tela SHALL mostrar "Cadastre sua primeira quadra" com o botão "Nova quadra". Sem conexão,
"Nova quadra", "Editar" e "Desativar quadra" SHALL ficar desabilitados com o motivo, e "Horários" SHALL abrir
em modo leitura. (RF06, RNF06, RNF11, CT-08)

#### Scenario: Primeiro acesso do dono
- **GIVEN** um DONO recém-cadastrado
- **WHEN** MinhasQuadras é exibida
- **THEN** aparece "Cadastre sua primeira quadra" com o botão que abre a FormQuadra

#### Scenario: Quadra criada aparece na lista
- **WHEN** o DONO salva uma quadra nova pela FormQuadra
- **THEN** ao voltar, o card da quadra aparece em MinhasQuadras com o selo "Ativa"

### Requirement: Desativação de quadra
"Desativar quadra" SHALL abrir um diálogo de confirmação:
- título "Desativar <nome>?";
- texto "A quadra sai da busca dos atletas e continua na sua lista como inativa. Reservas já feitas não são
  afetadas.";
- botões "Cancelar" e "Desativar".

Confirmar SHALL enviar `DELETE /quadras/{id}`. O comportamento por resultado SHALL ser:
- **204**: sincroniza a lista e mostra o card como inativo;
- **409 `QUADRA_COM_RESERVAS`**: abre o diálogo "A quadra tem reservas futuras. Cancele-as em Reservas antes
  de desativar." com o atalho "Ver reservas", que abre a ReservasQuadra da quadra;
- **403**: mostra "Você não tem permissão para isso" e volta.

(RF06, RF10, RN16, CT-11)

#### Scenario: Desativação bloqueada por reserva futura
- **GIVEN** uma quadra com reserva `CONFIRMADA` para amanhã
- **WHEN** o DONO confirma a desativação
- **THEN** aparece o diálogo de reservas futuras com o atalho "Ver reservas"
- **AND** a quadra continua com o selo "Ativa"

#### Scenario: Desativação concluída
- **GIVEN** uma quadra sem reservas ativas futuras
- **WHEN** o DONO confirma a desativação
- **THEN** o card passa a "Inativa"
- **AND** a quadra deixa de aparecer no catálogo dos clientes

### Requirement: Fidelidade da FormQuadra ao protótipo
A FormQuadra (`/dono/quadras/nova` e `/dono/quadras/:id/editar`) SHALL reproduzir
`docs/Protótipo de Alta Fidelidade/nova_quadra/code.html`:
- barra com voltar e o título "Nova Quadra" ou "Editar Quadra";
- cartão de contexto "GESTÃO DO DONO" / "Configurar Arena";
- seção "Informações Básicas": "Nome da Quadra" com contador `x/100`, "Tipo de Esporte" com os 7 valores
  do enum, "Preço por hora" com o prefixo "R$" e a dica "Valor base cobrado dos atletas por cada intervalo
  de 60 min", e "Descrição da quadra" com contador `x/500`;
- seção "Localização & Endereço": "CEP" com máscara `00000-000` e o botão "Buscar CEP", a confirmação
  "Endereço encontrado via BrasilAPI" ou "via ViaCEP" conforme o campo `fonte`, "Logradouro", "Número",
  "Bairro", "Cidade" e "UF";
- bloco "Geolocalização Precisa" com Latitude e Longitude editáveis, a etiqueta "Preenchido auto" quando as
  coordenadas vieram do CEP e o texto "Usadas para calcular a distância exata até a quadra";
- seção "Foto da Quadra": "URL da Imagem de Destaque" com o botão de recarregar, e a
  "Pré-visualização do Anúncio" 16:9 com o esporte e o nome sobre a imagem;
- dica "Proporção recomendada 16:9.";
- barra de ações "Cancelar" e "Salvar Quadra".

Os campos obrigatórios SHALL seguir o `QuadraRequest`: o asterisco aparece em Nome, Tipo de Esporte, Preço,
CEP, Logradouro, Número, Cidade e UF, e Bairro fica opcional. O campo único "Cidade / UF" do protótipo SHALL
virar dois campos, porque o contrato separa cidade e UF. Elementos omitidos:
- o envio de arquivo ("Alterar" com upload) e a frase "Formatos aceitos: JPG, PNG até 5MB";
- o botão de ajuda;
- a pílula "RF06 / RF09";
- as opções "Vôlei de Praia" e "Futevôlei".

(RF06, RF09)

#### Scenario: Sem upload de foto
- **WHEN** a FormQuadra é exibida
- **THEN** a foto só pode ser informada por URL, e não há botão de enviar arquivo

#### Scenario: Bairro opcional
- **WHEN** o DONO salva uma quadra válida sem bairro
- **THEN** a quadra é criada e nenhum erro aparece no campo Bairro

### Requirement: Validação e gravação da quadra
A FormQuadra SHALL validar por campo com as regras do `QuadraRequest`. Ela SHALL converter o preço digitado
para a string decimal `"80.00"`, a UF para maiúsculas e o CEP para 8 dígitos. Salvar SHALL enviar
`POST /quadras` na criação ou `PUT /quadras/{id}` na edição. O comportamento por resultado SHALL ser:
- **2xx**: grava a quadra no cache, sincroniza a lista, volta para MinhasQuadras e mostra
  `Quadra "<nome>" salva com sucesso!`;
- **400 `VALIDACAO`**: marca os campos de `campos[]` e põe o foco no primeiro inválido;
- **403**: mostra "Você não tem permissão para isso" e volta;
- **404**: mostra "Quadra não encontrada" com o botão Voltar.

Durante o envio, o botão SHALL mostrar progresso e não aceitar segundo toque. (RF06, RNF06, CT-08)

#### Scenario: Preço inválido
- **WHEN** o DONO informa o preço `0,00` e toca "Salvar Quadra"
- **THEN** o campo de preço mostra o erro e nada é enviado

#### Scenario: Edição do preço
- **GIVEN** uma quadra a R$ 80,00 por hora
- **WHEN** o DONO muda o preço para `95,00` e salva
- **THEN** a API recebe `precoHora` igual a `"95.00"` e o card passa a mostrar R$ 95,00

### Requirement: Busca de endereço pelo CEP
"Buscar CEP" SHALL ficar habilitado quando o CEP tem 8 dígitos. Ao tocar, SHALL chamar apenas
`GET /cep/{cep}` do backend, nunca BrasilAPI ou ViaCEP diretamente, mostrando "Buscando..." no botão. O
comportamento por resultado SHALL ser:
- **sucesso**: preenche Logradouro, Bairro, Cidade e UF, preenche Latitude e Longitude quando vierem, e
  anuncia "Endereço preenchido";
- **404**: mostra "CEP não encontrado" no campo CEP;
- **503 `CEP_INDISPONIVEL`**: mostra "Serviço de CEP fora do ar; preencha o endereço manualmente" e mantém os
  campos editáveis;
- **400**: mostra "CEP inválido" no campo.

(RF09, CT-13)

#### Scenario: CEP com coordenadas
- **WHEN** o DONO busca o CEP `01001-000`
- **THEN** os campos ficam com Praça da Sé, Sé, São Paulo e SP, e as coordenadas são preenchidas
- **AND** aparecem "Endereço encontrado via BrasilAPI" e a etiqueta "Preenchido auto"

#### Scenario: Fonte sem coordenadas
- **GIVEN** a BrasilAPI fora do ar e o backend respondendo pela ViaCEP
- **WHEN** o DONO busca um CEP existente
- **THEN** o endereço é preenchido, aparece "Endereço encontrado via ViaCEP" e as coordenadas ficam vazias e editáveis

#### Scenario: Serviço de CEP indisponível
- **WHEN** a busca responde 503 `CEP_INDISPONIVEL`
- **THEN** aparece "Serviço de CEP fora do ar; preencha o endereço manualmente"
- **AND** o DONO consegue salvar a quadra digitando o endereço

### Requirement: Edição carregada do cache e do servidor
Na edição, a FormQuadra SHALL preencher os campos imediatamente a partir de `quadra_cache` (escopo `MINHAS`)
e atualizá-los com `GET /quadras/{id}` quando há rede, sem sobrescrever o que o DONO já alterou. Sem conexão,
o formulário SHALL abrir para leitura, com "Buscar CEP" e "Salvar Quadra" desabilitados e o texto
"Conecte-se para salvar". (RF06, RF23, RNF11)

#### Scenario: Editar em modo avião
- **GIVEN** o aparelho em modo avião
- **WHEN** o DONO toca "Editar" em uma quadra
- **THEN** os campos aparecem preenchidos e o botão de salvar está desabilitado com "Conecte-se para salvar"

### Requirement: Descartar alterações da quadra
Sair da FormQuadra com alterações não salvas SHALL abrir o diálogo "Descartar alterações?" com o texto
"As informações preenchidas serão perdidas." e os botões "Continuar editando" e "Descartar". Sem alterações,
a saída SHALL ser direta. (RNF06)

#### Scenario: Voltar com o formulário alterado
- **GIVEN** o DONO alterou o nome da quadra
- **WHEN** ele toca voltar
- **THEN** aparece "Descartar alterações?" e o formulário só fecha se ele escolher "Descartar"

### Requirement: Acessibilidade de MinhasQuadras e FormQuadra
As duas telas SHALL atender a estes pontos:
- o botão flutuante mostra o texto "Nova quadra";
- o menu do card tem tooltip "Opções da quadra" e também abre por toque longo;
- o seletor de esporte anuncia o valor escolhido;
- "Buscar CEP" tem o rótulo "Buscar endereço pelo CEP";
- o preenchimento automático é anunciado como `liveRegion`;
- Latitude e Longitude têm o texto explicativo associado.

(RNF07)

#### Scenario: Menu de opções acessível
- **GIVEN** o TalkBack ligado
- **WHEN** o foco chega ao menu do card
- **THEN** o leitor anuncia "Opções da quadra" e a ativação abre a opção "Desativar quadra"
