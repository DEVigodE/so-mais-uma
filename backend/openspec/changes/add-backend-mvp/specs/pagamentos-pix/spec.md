## Purpose

Cobra a reserva por Pix no instante em que ela é criada, entrega ao cliente um código copia e cola
com prazo, detecta o pagamento por mais de um caminho sem nunca confirmar a mesma cobrança duas
vezes e trata o dinheiro que chega fora do prazo sem perder o registro.

## ADDED Requirements

### Requirement: Cobrança Pix imediata criada com a reserva
O sistema SHALL criar uma cobrança Pix imediata para cada reserva no momento em que ela é criada,
com valor igual ao da reserva, expiração de 900 segundos e identificador de transação gerado pelo
próprio backend. O identificador de transação SHALL ser alfanumérico, único, com 26 a 35 caracteres,
e SHALL ser produzido como um UUID sem hifens. A cobrança SHALL nascer com status `PENDENTE` e com o
mesmo instante de expiração da reserva. A resposta da criação da reserva SHALL trazer a cobrança
embutida. (RF19, RN10, RN18)

#### Scenario: Cobrança devolvida junto com a reserva
- **WHEN** um CLIENTE cria uma reserva com sucesso
- **THEN** a resposta 201 traz `pagamento` com `txid`, `provedor`, `status` `PENDENTE`, `valor`, `pixCopiaECola` e `expiraEm`
- **AND** `expiraEm` da cobrança é igual ao `expiraEm` da reserva

#### Scenario: Identificador de transação no formato esperado
- **WHEN** uma cobrança é criada
- **THEN** o `txid` tem 32 caracteres alfanuméricos
- **AND** nenhum outro pagamento no sistema tem o mesmo `txid`

### Requirement: Relação um para no máximo um entre reserva e cobrança
O sistema SHALL manter no máximo uma cobrança por reserva. Quando a criação da cobrança falha, a
reserva SHALL ser cancelada pelo sistema e SHALL NOT existir cobrança associada a ela.
(RF19, RN17)

#### Scenario: Reserva sem cobrança após falha do provedor
- **WHEN** a criação da cobrança falha e a reserva é cancelada pelo sistema
- **THEN** não existe nenhuma cobrança associada àquela reserva

### Requirement: Provedores de pagamento intercambiáveis
O sistema SHALL acessar o provedor Pix por uma única abstração que ofereça criar cobrança, consultar
cobrança e remover cobrança, com pelo menos duas implementações selecionadas pelo ambiente de
execução: uma simulada, ativa no ambiente padrão, e uma que integra o provedor externo real, ativa
nos ambientes de homologação e de produção. Trocar de implementação SHALL exigir apenas mudança de
variável de ambiente, sem reconstruir o artefato, e SHALL NOT alterar o contrato exposto ao
consumidor. A resposta SHALL indicar o provedor usado em `ProvedorPagamento`. (RF19)

#### Scenario: Mesmo contrato em qualquer provedor
- **WHEN** o sistema roda no ambiente padrão e depois no ambiente de homologação
- **THEN** o formato de `PagamentoResponse` é o mesmo nos dois casos
- **AND** apenas o valor de `provedor` muda entre `SIMULADO` e `INTER`

#### Scenario: Ambiente padrão não depende de terceiro
- **WHEN** o sistema roda no ambiente padrão sem credenciais externas
- **THEN** a criação de reservas e cobranças funciona de ponta a ponta

### Requirement: Código copia e cola válido no provedor simulado
No ambiente padrão, o sistema SHALL gerar por conta própria um código Pix copia e cola estático
válido, contendo a chave configurada, o nome e a cidade do recebedor, e um dígito verificador
calculado corretamente, de modo que o código seja reconhecido por aplicativos de banco reais.
(RF19, RN18)

#### Scenario: Código gerado passa na verificação do dígito
- **WHEN** o provedor simulado gera um código copia e cola para uma cobrança
- **THEN** o dígito verificador ao final do código confere com o conteúdo do código
- **AND** o código pode ser lido por um aplicativo de banco

### Requirement: Chave Pix única da plataforma
Todo recebimento SHALL usar a única chave Pix configurada para o ambiente. O sistema SHALL NOT
suportar chave por quadra, divisão de valores entre partes nem repasse automático ao dono da quadra;
o repasse SHALL ocorrer fora do aplicativo. (RN18)

#### Scenario: Cobrança usa sempre a chave configurada
- **WHEN** cobranças são criadas para quadras de donos diferentes
- **THEN** todas usam a mesma chave Pix configurada para o ambiente

### Requirement: Consulta do estado da cobrança pelo cliente
O sistema SHALL expor `GET /api/v1/reservas/{id}/pagamento` para o cliente dono da reserva,
devolvendo o estado atual da cobrança para que o consumidor possa consultar repetidamente até
detectar a confirmação. A resposta SHALL conter apenas identificador de transação, provedor, status,
valor, código copia e cola, instante de expiração e instante do pagamento. Reserva de outro cliente
SHALL responder 403 com `codigo` `ACESSO_NEGADO`, e reserva sem cobrança SHALL responder 404 com
`codigo` `NAO_ENCONTRADO`. (RF20, RN04, RN05)

#### Scenario: Cliente acompanha a cobrança
- **WHEN** o cliente dono da reserva consulta o estado da cobrança
- **THEN** a resposta é 200 com o status atual
- **AND** a resposta não contém nenhum dado do pagador nem o identificador fim a fim da transação

#### Scenario: Cobrança de outro cliente
- **WHEN** um CLIENTE consulta a cobrança de uma reserva de outro cliente
- **THEN** a resposta é 403 com `codigo` `ACESSO_NEGADO`

### Requirement: Detecção do pagamento por consulta periódica
Nos ambientes integrados ao provedor externo, o sistema SHALL consultar periodicamente, a cada 60
segundos, as cobranças ainda pendentes e confirmar as que o provedor já registra como pagas. Cada
ciclo SHALL consultar no máximo 10 cobranças pendentes, para respeitar os limites de chamada do
provedor. Falha ou indisponibilidade do provedor em um ciclo SHALL ser registrada em log e SHALL
NOT alterar o status de nenhuma cobrança. (RF20, RNF04)

#### Scenario: Pagamento detectado pelo ciclo periódico
- **WHEN** o provedor externo registra a cobrança como paga
- **THEN** no ciclo seguinte o sistema marca a cobrança como `PAGO` e a reserva como `CONFIRMADA`

#### Scenario: Limite de cobranças por ciclo
- **WHEN** existem 25 cobranças pendentes
- **THEN** um único ciclo consulta no máximo 10 delas

#### Scenario: Provedor indisponível durante o ciclo
- **WHEN** o provedor externo está fora do ar durante um ciclo
- **THEN** nenhum status é alterado e a ocorrência é registrada em log

### Requirement: Recebimento de notificação do provedor externo
O sistema MAY expor `POST /api/v1/webhooks/inter/pix/{segredo}` como rota pública nos ambientes
integrados ao provedor externo, para receber a notificação de pagamentos. A rota SHALL ser protegida
por um segmento secreto na própria URL e SHALL responder 404 quando o segmento não confere. Corpo
que não seja uma lista de pagamentos SHALL responder 400. Pagamento cujo identificador de transação
é desconhecido SHALL ser ignorado com resposta 200. A rota SHALL responder 200 sempre que o corpo
for válido, mesmo quando a notificação não produz efeito, para que o provedor não reenvie a
notificação. (RF20)

#### Scenario: Notificação válida confirma a cobrança
- **WHEN** o provedor envia uma notificação válida para uma cobrança pendente com o valor correto
- **THEN** a resposta é 200 e a cobrança passa a `PAGO` e a reserva a `CONFIRMADA`

#### Scenario: Segmento secreto incorreto
- **WHEN** alguém chama a rota com um segmento secreto diferente do configurado
- **THEN** a resposta é 404 e nenhum efeito é produzido

#### Scenario: Identificador de transação desconhecido
- **WHEN** a notificação traz um identificador de transação que não existe no sistema
- **THEN** a resposta é 200 e a ocorrência é registrada em log, sem erro

#### Scenario: Corpo malformado
- **WHEN** a notificação não é uma lista de pagamentos
- **THEN** a resposta é 400

### Requirement: Confirmação de pagamento idempotente
O sistema SHALL ter um único ponto de confirmação de pagamento, usado pelos três caminhos possíveis:
consulta periódica, notificação do provedor e endpoint de simulação. A confirmação SHALL marcar a
cobrança como `PAGO` somente quando ela está `PENDENTE`, por operação condicional atômica, e em
seguida SHALL confirmar a reserva somente quando ela está `PENDENTE_PAGAMENTO`. Uma segunda
confirmação da mesma cobrança SHALL NOT produzir efeito nem erro. O identificador fim a fim da
transação SHALL ser único no sistema, e a tentativa de aplicar o mesmo identificador a outra
cobrança SHALL ser tratada como já processada, respondendo com sucesso. (RF20, RN12)

#### Scenario: Confirmação dupla pelo mesmo caminho
- **WHEN** a mesma cobrança é confirmada duas vezes
- **THEN** a primeira confirmação altera a cobrança e a reserva
- **AND** a segunda não altera nada e não gera erro

#### Scenario: Consulta periódica e notificação confirmam ao mesmo tempo
- **WHEN** o ciclo periódico e a notificação do provedor confirmam a mesma cobrança simultaneamente
- **THEN** exatamente um dos dois efetiva a confirmação
- **AND** o outro termina sem efeito e sem erro
- **AND** a reserva fica `CONFIRMADA` uma única vez

#### Scenario: Mesmo identificador fim a fim em outra cobrança
- **WHEN** chega uma confirmação com um identificador fim a fim já usado em outra cobrança
- **THEN** o sistema trata como já processada, registra a ocorrência em log e responde com sucesso
- **AND** nenhuma cobrança adicional é marcada como paga

### Requirement: Valor recebido deve conferir com o valor da cobrança
O sistema SHALL confirmar o pagamento apenas quando o valor recebido for exatamente igual ao valor
da cobrança. Valor divergente SHALL NOT confirmar a cobrança nem a reserva, SHALL ser registrado em
log para tratamento manual e, quando vier por notificação do provedor, SHALL responder 200 para
evitar reenvio. (RN12)

#### Scenario: Valor menor que o cobrado
- **WHEN** chega uma confirmação com valor diferente do valor da cobrança
- **THEN** a cobrança permanece `PENDENTE` e a reserva permanece `PENDENTE_PAGAMENTO`
- **AND** a divergência é registrada em log

### Requirement: Pagamento recebido fora do prazo
Quando um pagamento chega para uma cobrança que já está `EXPIRADO` ou `CANCELADO`, o sistema SHALL
primeiro tentar reconfirmar a reserva correspondente, apenas se ela estiver `EXPIRADA` e o slot
continuar livre, em transação própria e isolada, e só então SHALL marcar a cobrança como `PAGO`,
porque o dinheiro efetivamente entrou. Se a reconfirmação tiver sucesso, o sistema SHALL registrar a
reconfirmação em log; caso contrário SHALL registrar a necessidade de estorno manual, com o
identificador de transação, a reserva e o valor. O sistema SHALL NOT realizar devolução automática.
(RN14)

#### Scenario: Pagamento tardio com slot ainda livre
- **WHEN** chega um pagamento para uma reserva `EXPIRADA` cujo slot continua livre
- **THEN** a reserva volta a `CONFIRMADA` e a cobrança passa a `PAGO`
- **AND** a reconfirmação é registrada em log

#### Scenario: Pagamento tardio com slot já tomado
- **WHEN** chega um pagamento para uma reserva `EXPIRADA` cujo slot já foi reservado por outro cliente
- **THEN** a reserva permanece `EXPIRADA` e a cobrança passa a `PAGO`
- **AND** o sistema registra em log a necessidade de estorno manual, com identificador de transação, reserva e valor
- **AND** a reserva do outro cliente permanece intacta

#### Scenario: Pagamento tardio para reserva cancelada
- **WHEN** chega um pagamento para uma reserva `CANCELADA`
- **THEN** a reserva permanece `CANCELADA` e a cobrança passa a `PAGO`
- **AND** o sistema registra em log a necessidade de estorno manual

### Requirement: Cancelamento da cobrança junto com a reserva
Quando uma reserva `PENDENTE_PAGAMENTO` é cancelada, o sistema SHALL marcar a cobrança associada
como `CANCELADO` e SHALL tentar remover a cobrança no provedor externo em regime de melhor esforço.
A falha dessa remoção SHALL ser apenas registrada em log e SHALL NOT fazer o cancelamento da reserva
falhar. (RF17, RN13)

#### Scenario: Cancelamento marca a cobrança
- **WHEN** o cliente cancela uma reserva `PENDENTE_PAGAMENTO`
- **THEN** a cobrança associada passa a `CANCELADO`

#### Scenario: Remoção no provedor falha
- **WHEN** a remoção da cobrança no provedor externo falha
- **THEN** o cancelamento da reserva continua bem-sucedido
- **AND** a falha é registrada em log

### Requirement: Transições permitidas da cobrança
O status de uma cobrança SHALL seguir exclusivamente as transições: de inexistente para `PENDENTE`
na criação; de `PENDENTE` para `PAGO`, `EXPIRADO` ou `CANCELADO`; e de `EXPIRADO` ou `CANCELADO`
para `PAGO` somente no caso de pagamento recebido fora do prazo. `PAGO` SHALL ser terminal, pois não
há devolução pelo sistema. (RN12, RN14)

#### Scenario: Cobrança paga não muda mais
- **WHEN** qualquer fluxo tenta alterar o status de uma cobrança `PAGO`
- **THEN** a cobrança permanece `PAGO`

### Requirement: Simulação de pagamento em ambientes não produtivos
O sistema SHALL expor `POST /api/v1/dev/pagamentos/{txid}/confirmar` apenas nos ambientes `simulado`
e `inter-sandbox`. A rota SHALL exigir token válido e também um cabeçalho com a chave de
desenvolvimento configurada; chave ausente ou incorreta SHALL responder 403 com `codigo`
`ACESSO_NEGADO`. O sistema SHALL verificar que a cobrança pertence ao usuário autenticado antes de
qualquer efeito; cobrança de outro usuário SHALL responder 403 mesmo com a chave correta. No
ambiente `simulado` a rota SHALL confirmar a cobrança diretamente; no ambiente `inter-sandbox` SHALL
pedir ao provedor que registre o pagamento e deixar a confirmação para o fluxo normal de detecção.
(RF21)

#### Scenario: Simulação confirma no ambiente padrão
- **WHEN** o cliente dono da reserva chama a rota de simulação com token e chave corretos no ambiente `simulado`
- **THEN** a resposta é 200 e a cobrança passa a `PAGO`
- **AND** uma consulta seguinte mostra a reserva `CONFIRMADA`

#### Scenario: Chave de desenvolvimento ausente
- **WHEN** alguém chama a rota de simulação com token válido mas sem a chave
- **THEN** a resposta é 403 com `codigo` `ACESSO_NEGADO`

#### Scenario: Cobrança de outro usuário
- **WHEN** um CLIENTE chama a rota de simulação para a cobrança de outro cliente, com a chave correta
- **THEN** a resposta é 403 com `codigo` `ACESSO_NEGADO`

#### Scenario: Rota inexistente em produção
- **WHEN** a aplicação roda no ambiente `inter-prod`
- **THEN** a rota de simulação responde 404

### Requirement: Credenciais do provedor externo protegidas
Nos ambientes integrados ao provedor externo, o sistema SHALL autenticar-se com credenciais de
cliente e certificado mútuo fornecidos por variáveis de ambiente e arquivos secretos, SHALL manter o
token de acesso obtido apenas em memória e reutilizá-lo durante sua validade, e SHALL NOT persistir
esse token, as credenciais nem os certificados no banco de dados ou no repositório. Falha de
autenticação, certificado expirado ou indisponibilidade do provedor SHALL resultar em erro de
integração tratado, nunca em vazamento de credencial na resposta ou no log. (RNF02, RN17)

#### Scenario: Token de acesso reutilizado enquanto vale
- **WHEN** várias cobranças são criadas dentro da validade do token de acesso
- **THEN** o sistema obtém o token uma única vez e o reutiliza

#### Scenario: Certificado expirado
- **WHEN** o certificado usado na comunicação com o provedor está expirado
- **THEN** a criação da cobrança falha com erro de integração e a reserva é cancelada pelo sistema
- **AND** nenhuma credencial aparece na resposta ao consumidor
