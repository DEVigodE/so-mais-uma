Fases N1 (entrega de 02/10/2026) e N2 (apresentação de 07–11/12/2026), na ordem do caminho crítico
de `docs/20-ordem-de-implementacao.md`. Cada fatia é fina e completa: endpoint, regra, teste e
atualização do contrato vivo no mesmo passo. Os grupos 1 a 9 formam o escopo da N1; os grupos 10 a 13
formam o da N2.

## 1. Fundação do módulo (N1)

- [ ] 1.1 Mover o conteúdo de `backend/so-mais-uma/` para `backend/` (`pom.xml`, `mvnw`, `mvnw.cmd`, `.mvn/`, `src/`, `.gitignore`, `.gitattributes`) e remover o diretório vazio; confirmar que `./mvnw -v` funciona a partir de `backend/`
- [ ] 1.2 Confirmar, contra o gerenciamento de dependências do parent `spring-boot-starter-parent:4.1.1`, o identificador exato de cada starter do Boot 4 listado em design.md D13 (web MVC, data JPA, security, servidor de recursos OAuth2, validação, Flyway, actuator, fatias de teste, suporte a Testcontainers e a Docker Compose)
- [ ] 1.3 Acrescentar ao `pom.xml` as dependências de produção confirmadas no passo anterior, mais `flyway-database-postgresql`, `org.postgresql:postgresql` em runtime e `org.springdoc:springdoc-openapi-starter-webmvc-ui:3.1.0` com versão explícita
- [ ] 1.4 Acrescentar Lombok apenas no escopo de compilação e provar que o processamento de anotações funciona no JDK 25 compilando uma classe de teste com `@Getter`/`@Setter`; se falhar, remover o Lombok do `pom.xml` e registrar a decisão de escrever acessores à mão
- [ ] 1.5 Acrescentar as dependências de teste (starter de teste do Boot, fatia de teste de web MVC, suporte a Testcontainers, `org.testcontainers:postgresql`, suporte de teste do Spring Security)
- [ ] 1.6 Criar `backend/compose.yaml` com `postgres:18-alpine`, volume nomeado, usuário, senha e banco da aplicação
- [ ] 1.7 Criar `application.yml` com prefixo `/api/v1`, ambiente padrão `simulado`, Flyway habilitado, `ddl-auto=validate`, fuso `America/Sao_Paulo` e pool de agendamento com duas threads
- [ ] 1.8 Criar `application-simulado.yml`, `application-inter-sandbox.yml` e `application-inter-prod.yml` com a matriz de componentes por ambiente de design.md D7, incluindo o desligamento da documentação em `inter-prod`
- [ ] 1.9 Criar `backend/.env.exemplo` com todas as variáveis de design.md D14, com valores de exemplo e nenhum valor real
- [ ] 1.10 Garantir no `.gitignore` do backend as entradas `*.crt`, `*.key`, `*.pfx`, `*.p12`, `*.jks`, `*.keystore` e `.env`
- [ ] 1.11 Habilitar o agendamento na classe de aplicação e subir a aplicação no ambiente padrão sem nenhuma credencial externa, verificando `GET /actuator/health`

## 2. Contrato do banco (N1)

- [ ] 2.1 Escrever `src/main/resources/db/migration/V1__init.sql` com as cinco tabelas, restrições de verificação, chaves estrangeiras e os seis índices exatamente como em design.md D9, incluindo `ux_reserva_slot_ativo` e `ux_pagamento_end_to_end`
- [ ] 2.2 Criar os sete enums do domínio: `PerfilUsuario`, `TipoEsporte`, `StatusReserva`, `StatusPagamento`, `ProvedorPagamento`, `CanceladoPor` e `StatusSlot` (este último apenas de resposta, sem coluna)
- [ ] 2.3 Mapear as entidades `Usuario`, `Quadra`, `HorarioFuncionamento`, `Reserva` e `Pagamento`, com enums persistidos por nome e atualização automática de `atualizado_em`
- [ ] 2.4 Criar a classe base de teste de integração com contêiner `postgres:18-alpine` conectado automaticamente à aplicação
- [ ] 2.5 Escrever `FlywayMigracaoIT`, que sobe o contexto contra o contêiner, prova que `V1` foi aplicada e que a validação de esquema passa
- [ ] 2.6 Escrever um teste que confirme a existência e a definição de `ux_reserva_slot_ativo`, incluindo a cláusula de status ativo

## 3. Plataforma da API (N1)

- [ ] 3.1 Criar o enum `CodigoErro` com os 15 códigos e o enum `SubcodigoErro` com os 6 subcódigos do catálogo da capability `plataforma-backend`
- [ ] 3.2 Criar as exceções de domínio: não encontrado (404), acesso negado (403), conflito (409), horário indisponível (409), regra de negócio com subcódigo (422), pagamento indisponível (502) e a exceção interna de integração externa
- [ ] 3.3 Implementar o tratador global de exceções, convertendo cada exceção em `ProblemDetail` com `codigo`, `timestamp`, `subcodigo` quando 422, `campos[]` nos erros de validação e `reservaId` quando aplicável, sem expor stack trace
- [ ] 3.4 Implementar a configuração de fuso horário, expondo o fuso e o relógio de referência como beans para que os testes possam fixá-los
- [ ] 3.5 Configurar a serialização de instantes em ISO-8601 normalizados para o fuso de referência e de valores monetários como string decimal com duas casas
- [ ] 3.6 Implementar a configuração da documentação da API com esquema de segurança de portador, agrupamento por área e desligamento no ambiente `inter-prod`
- [ ] 3.7 Escrever teste de fatia web que prova o formato de erro de validação, incluindo `campos[]`, e o formato do erro 422 com subcódigo

## 4. Autenticação e perfil do usuário (N1)

- [ ] 4.1 Implementar a configuração de segurança sem estado, com as rotas públicas exatas da capability `autenticacao`, proteção de requisição forjada desligada e servidor de recursos com validação de token
- [ ] 4.2 Implementar a emissão e a decodificação do token HS256 com segredo vindo do ambiente e validade de 7 dias, recusando a subida da aplicação se o segredo tiver menos de 32 bytes
- [ ] 4.3 Implementar o conversor do claim de perfil para autoridade e o registro de usuário autenticado usado pelos controllers
- [ ] 4.4 Implementar o codificador de senha com algoritmo adaptativo de custo 10 e a validação de política de senha (mínimo 8 caracteres com letra e número) nos DTOs de cadastro e de troca de senha
- [ ] 4.5 Implementar `POST /api/v1/auth/registrar` com auto-login, normalização do e-mail em minúsculas e tradução da violação de `ux_usuario_email` para 409 `EMAIL_JA_CADASTRADO` pelo nome da constraint
- [ ] 4.6 Implementar `POST /api/v1/auth/login` devolvendo token, expiração e usuário, com 401 `CREDENCIAL_INVALIDA` indistinguível entre e-mail inexistente e senha errada
- [ ] 4.7 Implementar o serviço de bloqueio de login em memória (5 falhas, 15 minutos), com 429 `LOGIN_BLOQUEADO`, tempo restante em `detail`, reinício por login bem-sucedido e limpeza periódica dos bloqueios vencidos
- [ ] 4.8 Implementar `GET /api/v1/usuarios/me` e `PUT /api/v1/usuarios/me` com alteração de nome, telefone e senha, 422 `SENHA_ATUAL_INCORRETA` e campos de e-mail e perfil ignorados
- [ ] 4.9 Escrever `JwtServiceTest` (conteúdo dos claims, expiração de 7 dias, recusa de token adulterado) e `AuthServiceTest` (cadastro, e-mail duplicado, contador de bloqueio, troca de senha)
- [ ] 4.10 Escrever `AuthControllerTest` em fatia web, cobrindo os códigos 201, 400, 401, 409 e 429

## 5. Quadras (N1)

- [ ] 5.1 Criar os DTOs de quadra com Bean Validation espelhando cada limite de coluna de `V1__init.sql`, de modo que entrada grande demais resulte em 400 e nunca em 500
- [ ] 5.2 Implementar `POST /api/v1/quadras` restrito ao perfil DONO, gravando o dono como o usuário autenticado e ignorando qualquer dono enviado no corpo, com cabeçalho `Location`
- [ ] 5.3 Implementar `GET /api/v1/quadras` devolvendo apenas quadras ativas, ordenadas por nome, com filtros opcionais por esporte e por cidade, comparando cidade sem acento e sem diferenciar caixa
- [ ] 5.4 Implementar `GET /api/v1/quadras/{id}` com os horários de funcionamento embutidos e 404 para quadra inativa consultada por quem não é o dono
- [ ] 5.5 Implementar `GET /api/v1/quadras/minhas` devolvendo as quadras do DONO autenticado, inclusive as inativas
- [ ] 5.6 Implementar `PUT /api/v1/quadras/{id}` com checagem de propriedade no serviço respondendo 403 e não 404
- [ ] 5.7 Implementar `DELETE /api/v1/quadras/{id}` como exclusão lógica, com 409 `QUADRA_COM_RESERVAS` quando existir reserva ativa futura e a contagem em `detail`
- [ ] 5.8 Escrever `QuadraServiceTest` cobrindo propriedade (dono A editando quadra do dono B), exclusão lógica, bloqueio por reserva futura e liberação depois do cancelamento

## 6. Horários de funcionamento (N1)

- [ ] 6.1 Criar os DTOs de faixa de funcionamento com validação de dia entre 1 e 7, horas cheias e fechamento posterior à abertura
- [ ] 6.2 Implementar `POST /api/v1/quadras/{id}/horarios-funcionamento` com tradução da violação de `ux_horario_quadra_dia` para 409 `DIA_JA_CADASTRADO` pelo nome da constraint
- [ ] 6.3 Implementar `GET /api/v1/quadras/{id}/horarios-funcionamento` devolvendo de zero a sete faixas
- [ ] 6.4 Implementar `PUT /api/v1/quadras/{id}/horarios-funcionamento/{hid}` com 409 `HORARIO_COM_RESERVAS` quando a nova faixa deixaria reserva ativa futura fora do funcionamento, permitindo sempre a ampliação
- [ ] 6.5 Implementar `DELETE /api/v1/quadras/{id}/horarios-funcionamento/{hid}` com a mesma verificação de reservas ativas futuras naquele dia da semana
- [ ] 6.6 Escrever `HorarioFuncionamentoServiceTest` cobrindo dia duplicado, redução com e sem reserva afetada, remoção bloqueada e propriedade da quadra

## 7. CEP (N1)

- [ ] 7.1 Configurar o cliente HTTP de CEP com limite de tempo curto de conexão e de leitura
- [ ] 7.2 Implementar o cliente de CEP com fonte primária, fallback para a fonte secundária e indicação da fonte usada na resposta
- [ ] 7.3 Implementar `GET /api/v1/cep/{cep}` restrito ao perfil DONO, com 400 para formato inválido sem chamar serviço externo, 404 para CEP inexistente e 503 `CEP_INDISPONIVEL` quando as duas fontes falham
- [ ] 7.4 Escrever `CepClientTest` com servidor HTTP simulado, cobrindo sucesso na fonte primária, fallback para a secundária, resposta sem coordenadas e falha das duas fontes

## 8. Disponibilidade e reservas (N1)

- [ ] 8.1 Implementar o serviço de slots gerando blocos de 60 minutos em hora cheia a partir das faixas de funcionamento do dia, no fuso de referência
- [ ] 8.2 Implementar a classificação de cada slot em `FECHADO`, `PASSADO`, `OCUPADO` e `LIVRE` conforme a capability `disponibilidade-slots`
- [ ] 8.3 Implementar `GET /api/v1/quadras/{id}/slots` com validação da janela de hoje até hoje mais 14 dias, 422 `DATA_FORA_DA_JANELA` e 400 para data malformada
- [ ] 8.4 Implementar a validação de reserva compartilhada com os slots: hora cheia (400), quadra ativa (404), janela de 14 dias (422) e faixa de funcionamento (422)
- [ ] 8.5 Criar o utilitário que identifica a violação de integridade pelo nome da constraint devolvida pelo banco, para uso em reservas, cadastro e pagamentos
- [ ] 8.6 Implementar a criação de reserva pendente em transação curta, com verificação de reserva pendente existente (422 com `reservaId`), gravação de fim, valor e expiração, `saveAndFlush` e tradução seletiva da violação de `ux_reserva_slot_ativo` para 409 `HORARIO_INDISPONIVEL`
- [ ] 8.7 Implementar as consultas de alteração condicional de status da reserva (expirar em lote, confirmar, cancelar, reconfirmar expirada), todas com guarda pelo status esperado
- [ ] 8.8 Implementar a fachada de criação de reserva sem transação, orquestrando reserva commitada, criação da cobrança e cancelamento por sistema com 502 `PAGAMENTO_INDISPONIVEL` em caso de falha de integração
- [ ] 8.9 Implementar `POST /api/v1/reservas` restrito ao perfil CLIENTE, devolvendo 201 com a cobrança embutida e cabeçalho `Location`
- [ ] 8.10 Implementar o job de expiração a cada 60 segundos, alterando em lote reservas e pagamentos vencidos e limpando bloqueios de login expirados, com prazo de pagamento configurável para testes
- [ ] 8.11 Escrever `SlotServiceTest` cobrindo os quatro status, a grade de uma quadra aberta das 08:00 às 22:00, dia sem faixa e instante enviado em outro offset
- [ ] 8.12 Escrever `ReservaServiceTest` cobrindo hora não cheia, passado, fora da janela, fora do funcionamento, reserva pendente existente e alteração condicional que afeta zero linhas
- [ ] 8.13 Escrever `ReservaFacadeTest` com gateway que lança falha de integração, provando o cancelamento por sistema e o 502

## 9. Pagamento simulado e evidência da N1

- [ ] 9.1 Definir a interface do gateway Pix e os tipos de retorno de cobrança e de status de cobrança
- [ ] 9.2 Implementar o construtor de payload Pix estático com estrutura de campos e dígito verificador CRC-16/CCITT-FALSE
- [ ] 9.3 Implementar o gateway simulado, ativo apenas no ambiente padrão, usando a chave, o nome e a cidade configurados
- [ ] 9.4 Implementar a criação da cobrança persistindo identificador de transação, provedor, valor, status, código copia e cola e expiração igual à da reserva
- [ ] 9.5 Implementar o ponto único de confirmação de pagamento conforme design.md D5, com comparação de valor, alteração condicional, releitura do status no banco e captura da violação de `ux_pagamento_end_to_end` pelo nome da constraint
- [ ] 9.6 Implementar `GET /api/v1/reservas/{id}/pagamento` restrito ao cliente dono da reserva, sem expor dados do pagador nem o identificador fim a fim
- [ ] 9.7 Implementar `POST /api/v1/dev/pagamentos/{txid}/confirmar`, ativo apenas em `simulado` e `inter-sandbox`, exigindo token e a chave de desenvolvimento, verificando a propriedade da cobrança antes de qualquer efeito
- [ ] 9.8 Escrever `PixPayloadBuilderTest` comparando o payload gerado com um payload conhecido e verificando o dígito verificador
- [ ] 9.9 Escrever `ReservaConcorrenciaIT`: 10 clientes distintos disputando o mesmo par de quadra e início, provando exatamente 1 resposta 201 e 9 respostas 409, contagem de reservas ativas igual a 1, exatamente uma cobrança criada e nenhuma exceção não tratada no log
- [ ] 9.10 Criar `scripts/seed-demo.sql` com um cliente e um dono de demonstração, três quadras georreferenciadas, faixas de funcionamento e duas reservas em estados distintos, aplicável fora das migrações
- [ ] 9.11 Verificar no contrato vivo que todas as rotas da N1 aparecem documentadas, com autenticação de portador funcionando e os códigos de erro declarados por operação
- [ ] 9.12 Configurar o fluxo de integração contínua com os três trabalhos: varredura de segredos versionados, construção e testes do backend com Maven e JDK 25, e o trabalho do aplicativo

## 10. Provedor Pix externo (N2)

- [ ] 10.1 Configurar o cliente HTTP do provedor externo com pacote TLS lendo os arquivos de certificado e chave, limite de conexão de 5 segundos e de leitura de 10 segundos
- [ ] 10.2 Implementar o serviço de token de acesso com credenciais de cliente, cache pela validade do token e obtenção sincronizada, sem persistir o token
- [ ] 10.3 Implementar o gateway do provedor externo: criar cobrança com expiração de 900 segundos e sem dados do pagador, consultar cobrança e remover cobrança em regime de melhor esforço
- [ ] 10.4 Mapear os status do provedor para os status internos e tratar os erros específicos: limite de chamadas excedido (pula o ciclo), token inválido (invalida o cache e tenta uma vez) e certificado expirado (erro de integração com log)
- [ ] 10.5 Fazer o endpoint de simulação repassar o pedido de pagamento ao provedor no ambiente de homologação, deixando a confirmação para o fluxo normal de detecção
- [ ] 10.6 Escrever `InterPixGatewayTest` com servidor HTTP simulado, cobrindo criação, consulta, remoção e cada caminho de erro do passo 10.4

## 11. Confirmação automática e pagamento tardio (N2)

- [ ] 11.1 Implementar o job de consulta periódica de pagamentos, ativo apenas nos ambientes integrados, a cada 60 segundos e com no máximo 10 cobranças pendentes por ciclo
- [ ] 11.2 Implementar o serviço de reconfirmação tardia em bean separado com transação própria que exige nova transação, sem capturar a violação do índice de slot dentro do método
- [ ] 11.3 Implementar o tratamento de pagamento tardio na ordem correta: tentar reconfirmar a reserva expirada e só então marcar a cobrança como paga, com registro de reconfirmação ou de necessidade de estorno manual contendo identificador de transação, reserva e valor
- [ ] 11.4 Implementar o cancelamento da cobrança junto com o cancelamento da reserva pendente, com pedido de remoção ao provedor em regime de melhor esforço que não faz o cancelamento falhar
- [ ] 11.5 Implementar o receptor de webhook do provedor, público e ativo apenas nos ambientes integrados, protegido por segmento secreto na URL, respondendo 404 para segmento incorreto, 400 para corpo que não seja lista e 200 para corpo válido mesmo sem efeito (item opcional, ver design.md — Open Questions)
- [ ] 11.6 Escrever `PagamentoServiceTest` cobrindo confirmação dupla (1 linha e depois 0 linhas), corrida entre job e webhook, valor divergente, identificador fim a fim repetido, pagamento tardio com slot livre e pagamento tardio com slot tomado
- [ ] 11.7 Escrever `InterWebhookControllerTest` cobrindo segmento secreto incorreto, corpo malformado, identificador de transação desconhecido e notificação válida

## 12. Ciclo completo de reservas (N2)

- [ ] 12.1 Implementar `GET /api/v1/reservas` com filtro por situação, escopo por perfil (cliente vê as suas, dono vê as das suas quadras), ordenação por início e limite dos últimos 12 meses
- [ ] 12.2 Implementar `GET /api/v1/reservas/{id}` com a cobrança embutida, acesso para o cliente dono e para o dono da quadra, e nome e telefone do cliente apenas para o dono
- [ ] 12.3 Implementar `PATCH /api/v1/reservas/{id}` aceitando apenas a observação, com 422 `TRANSICAO_INVALIDA` em reserva encerrada e demais campos ignorados
- [ ] 12.4 Implementar `POST /api/v1/reservas/{id}/cancelar` com as regras de prazo por perfil, motivo obrigatório para o dono, gravação de quem cancelou, motivo e instante, e 422 nos dois subcódigos aplicáveis
- [ ] 12.5 Implementar `GET /api/v1/quadras/{id}/reservas` para o dono, com filtro opcional por data e sem nenhum dado do pagador
- [ ] 12.6 Escrever os testes de fatia web das rotas de reserva, cobrindo 403 para reserva de outro cliente, 403 para quadra de outro dono e 400 para cancelamento pelo dono sem motivo

## 13. Publicação e operação (N2)

- [ ] 13.1 Criar o `Dockerfile` multiestágio construindo com Maven e executando sobre imagem de tempo de execução Java compatível com o JDK alvo
- [ ] 13.2 Publicar o backend no provedor de hospedagem com TLS, apontando para o banco PostgreSQL gerenciado, com variáveis e arquivos secretos configurados fora do repositório
- [ ] 13.3 Aplicar a carga de demonstração no ambiente publicado fora das migrações e verificar o fluxo completo de ponta a ponta pelo contrato vivo
- [ ] 13.4 Exportar o contrato OpenAPI da entrega e commitá-lo como o instantâneo de referência para a regra de evolução aditiva
- [ ] 13.5 Verificar, com a aplicação publicada, cada requisito de ambiente da capability `plataforma-backend`: ausência do endpoint de simulação e da documentação no ambiente de produção e presença deles nos demais
- [ ] 13.6 Atualizar `README.md`, `docs/09-arquitetura.md`, `docs/21-git-e-organizacao.md` e `docs/23-plano-de-testes.md` para refletir Maven, pacote `br.com.puc.so_mais_uma`, JDK 25 e os comandos reais de construção e teste
