# 05 — Requisitos funcionais

Lista completa dos 24 requisitos funcionais (RF01..RF24) do app "Só mais uma", agrupados por módulo, com prioridade, perfil, telas, endpoints, critério de aceite e a tabela de rastreabilidade RF → tela → endpoint → integrante. Este arquivo é a referência oficial de identificadores: qualquer outro documento cita "RF13" com o significado definido aqui.

## Convenções

| Item | Convenção |
|---|---|
| Formato | `RFnn — O sistema deve permitir/garantir ...` (sem hífen no identificador ao citar: RF13). |
| Prioridade | **Must Have (N1)** = obrigatório na Entrega N1 (28/09–02/10/2026); **Must Have (N2)** = obrigatório na Apresentação N2 (07–11/12/2026); **Should Have** = recomendado, entra só com todos os Must verdes; **Could Have** = opcional. Equivalem às etiquetas `must-n1`, `must-n2`, `should`, `could` do backlog (docs/14-backlog.md). |
| Perfil | `PerfilUsuario {CLIENTE, DONO}` (docs/03-perfis-e-permissoes.md). "público" = sem JWT. |
| Endpoints | Todos sob o prefixo `/api/v1` (docs/10-api-rest.md). Erros seguem `ProblemDetail` RFC 9457 com campo `codigo` (RNF09). |
| Telas | Nomes das 13 telas de docs/04-telas.md (`Login`, `Cadastro`, `Quadras`, `DetalheQuadra`, `ConfirmarReserva`, `Pagamento`, `MinhasReservas`, `DetalheReserva`, `Perfil`, `MinhasQuadras`, `FormQuadra`, `HorariosQuadra`, `ReservasQuadra`) + `Splash` de apoio. |
| Regras | Regras de negócio citadas como RNnn (docs/07-regras-de-negocio.md); requisitos não funcionais como RNFnn (docs/06-requisitos-nao-funcionais.md). |
| Critério de aceite | Frase única, verificável em menos de 1 minuto na banca (Swagger, celular ou terminal). Os casos de teste CT-xx por RF estão em docs/23-plano-de-testes.md. |

Resumo por prioridade:

| Prioridade | RFs |
|---|---|
| Must Have (N1) | RF01, RF02, RF03, RF05, RF06, RF07, RF08, RF09, RF10, RF11 (telas funcionais) + backend de RF12, RF13, RF14 e RF19 demonstrável via Swagger |
| Must Have (N2) | RF04, RF12, RF13, RF14, RF15, RF16, RF17, RF18, RF19, RF20, RF21, RF22, RF23 |
| Should Have | RF24; webhook do RF20; Pix em produção (`inter-prod`) no RF19/RF20 |
| Could Have | biometria no login, remarcar reserva (`PATCH inicio` enquanto PENDENTE_PAGAMENTO), desativar conta (`DELETE /usuarios/me`), bloqueio pontual de horário pelo dono — não recebem RF numerado; vivem no backlog como `could` |

## Módulo Autenticação

### RF01 — O sistema deve permitir que uma pessoa se cadastre informando nome, e-mail, telefone (opcional), senha e perfil (CLIENTE ou DONO), entrando automaticamente após o cadastro (auto-login).

| Prioridade | Perfil | Tela(s) | Endpoint(s) |
|---|---|---|---|
| Must Have (N1) | público | `Cadastro` | `POST /api/v1/auth/registrar` → 201 `TokenResponse{token, expiraEm, usuario}`; 400 `VALIDACAO`; 409 `EMAIL_JA_CADASTRADO` |

Critério de aceite: preencher o formulário com senha válida (RNF01) e perfil DONO cria a linha em `usuario` com `perfil='DONO'`, grava o token em `SessaoDataStore` e abre `HomeDono` sem passar por `Login`; repetir o mesmo e-mail devolve 409 e a tela mostra "E-mail já cadastrado" no campo. Regras: RN20 (e-mail único, perfil imutável).

### RF02 — O sistema deve permitir login por e-mail e senha, devolvendo um token JWT (HS256, 7 dias) com o perfil do usuário.

| Prioridade | Perfil | Tela(s) | Endpoint(s) |
|---|---|---|---|
| Must Have (N1) | público | `Login` | `POST /api/v1/auth/login` → 200 `TokenResponse`; 401 `CREDENCIAL_INVALIDA`; 429 `LOGIN_BLOQUEADO` (RF04) |

Critério de aceite: `cliente@demo.com` / `Senha123` (seed `scripts/seed-demo.sql`) recebe 200 e o app abre `HomeCliente` com a bottom-nav Quadras | Reservas | Perfil; `dono@demo.com` abre `HomeDono` com MinhasQuadras | Reservas | Perfil; senha errada mostra "E-mail ou senha inválidos" sem sair da tela.

### RF03 — O sistema deve permitir manter a sessão no dispositivo entre aberturas do app e sair (logout), limpando o DataStore e o banco Room local.

| Prioridade | Perfil | Tela(s) | Endpoint(s) |
|---|---|---|---|
| Must Have (N1) | CLIENTE, DONO | `Splash`, `Perfil` | nenhum (local); qualquer 401 `TOKEN_INVALIDO` em rota protegida também encerra a sessão |

Critério de aceite: fechar e reabrir o app com token válido vai direto para a home do perfil sem chamar a API (`Splash` lê `token_jwt` e `token_expira_em`; se faltar menos de 5 min para expirar, vai para `Login`); tocar "Sair" em `Perfil` executa `SessaoDataStore.clear()` + `AppDatabase.clearAllTables()` e navega para `Login` com `popUpTo(0)`; um 401 em rota protegida gera um único evento `SessaoExpirada` (sem retry, sem loop). Ver RNF03.

### RF04 — O sistema deve bloquear novas tentativas de login de um e-mail por 15 minutos após 5 falhas consecutivas.

| Prioridade | Perfil | Tela(s) | Endpoint(s) |
|---|---|---|---|
| Must Have (N2) | público | `Login` | `POST /api/v1/auth/login` → 429 `LOGIN_BLOQUEADO` |

Critério de aceite: 5 chamadas com senha errada para o mesmo e-mail fazem a 6ª devolver 429 mesmo com a senha correta; após 15 min (ou reinício do backend, pois `LoginTentativasService` guarda o contador em memória) o login volta a funcionar; a tela mostra "Muitas tentativas. Tente novamente em 15 minutos". Teste `AuthServiceTest` cobre o contador. Observação: o backend desta regra é implementado junto com RF02 na S2; a exigência formal é na N2. Ver RNF01.

## Módulo Usuários

### RF05 — O sistema deve permitir que o usuário logado veja e edite o próprio perfil (nome, telefone e senha), sem alterar e-mail nem perfil.

| Prioridade | Perfil | Tela(s) | Endpoint(s) |
|---|---|---|---|
| Must Have (N1) | CLIENTE, DONO | `Perfil` | `GET /api/v1/usuarios/me` → 200 `UsuarioResponse`; `PUT /api/v1/usuarios/me` `{nome, telefone, senhaAtual?, novaSenha?}` → 200; 422 `REGRA_NEGOCIO` (senha atual incorreta); 400 `VALIDACAO` |

Critério de aceite: alterar o telefone e salvar atualiza `usuario.telefone` e o valor aparece após reabrir a tela; trocar a senha exige `senhaAtual` correta e `novaSenha` no padrão de RNF01; o próximo login funciona só com a senha nova. Regras: RN20.

## Módulo Quadras

### RF06 — O sistema deve permitir ao DONO o CRUD completo de Quadra: criar, listar as suas (inclusive inativas), editar e desativar.

| Prioridade | Perfil | Tela(s) | Endpoint(s) |
|---|---|---|---|
| Must Have (N1) | DONO | `MinhasQuadras`, `FormQuadra` | `POST /api/v1/quadras` → 201 + `Location`; `GET /api/v1/quadras/minhas` → 200; `GET /api/v1/quadras/{id}` → 200/404; `PUT /api/v1/quadras/{id}` → 200/403/404; `DELETE /api/v1/quadras/{id}` (soft, `ativa=false`) → 204/403/409 |

Critério de aceite: com token DONO, criar quadra `FUTEBOL_SOCIETY` a R$ 80,00/h faz ela aparecer em `MinhasQuadras` e na lista pública `GET /quadras`; editar o preço reflete em `GET /quadras/{id}`; desativar remove da lista pública e mantém em `MinhasQuadras` com etiqueta "Inativa"; com token CLIENTE, `POST /quadras` devolve 403 `ACESSO_NEGADO` (evidência do critério 3 da disciplina, CRUD nº 1). Regras: RN01, RN03, RN16.

### RF07 — O sistema deve permitir listar as quadras ativas com filtro por esporte e por cidade.

| Prioridade | Perfil | Tela(s) | Endpoint(s) |
|---|---|---|---|
| Must Have (N1) | CLIENTE (o DONO não tem a aba Quadras; só alcança a lista pelo link Could Have do `Perfil`) | `Quadras` | `GET /api/v1/quadras?esporte=FUTSAL&cidade=Curitiba` → 200 `List<QuadraResponse>` (só `ativa=true`) |

Critério de aceite: a tela mostra cards com nome, esporte, bairro/cidade e preço/hora; tocar o chip `FUTSAL` reduz a lista às quadras desse `tipo_esporte`; campo de cidade filtra por `quadra.cidade` (comparação sem acento/caixa no backend); lista vazia mostra `VazioBox` ("Nenhuma quadra encontrada"); pull-to-refresh recarrega. Ordenação por distância é RF22.

### RF08 — O sistema deve permitir ver o detalhe de uma quadra: dados, endereço completo, horários de funcionamento por dia da semana e, quando disponível, a distância até o usuário.

| Prioridade | Perfil | Tela(s) | Endpoint(s) |
|---|---|---|---|
| Must Have (N1) | CLIENTE, DONO | `DetalheQuadra` | `GET /api/v1/quadras/{id}` → 200 `QuadraResponse` com `horariosFuncionamento[]`; 404 `NAO_ENCONTRADO` |

Critério de aceite: a tela exibe nome, esporte, descrição, preço/hora, `logradouro, numero - bairro, cidade/UF`, os 7 dias com "08:00–22:00" ou "Fechado" e o botão "Abrir no Maps" (RF22); na N1 a grade de slots (RF12) ainda não aparece; quadra inexistente ou inativa mostra `ErroBox` "Quadra não encontrada". A distância ("a 2,3 km") aparece a partir de RF22 (N2).

### RF09 — O sistema deve permitir buscar um CEP e preencher automaticamente logradouro, bairro, cidade, UF, latitude e longitude no cadastro da quadra, usando BrasilAPI CEP v2 com fallback ViaCEP, sempre via backend.

| Prioridade | Perfil | Tela(s) | Endpoint(s) |
|---|---|---|---|
| Must Have (N1) | DONO | `FormQuadra` | `GET /api/v1/cep/{cep}` → 200 `CepResponse{cep, logradouro, bairro, cidade, uf, latitude?, longitude?}`; 404 (CEP inexistente); 503 `CEP_INDISPONIVEL` (as duas APIs falharam) |

Critério de aceite: digitar `01001000` e tocar "Buscar" preenche Praça da Sé / Sé / São Paulo / SP e lat/lon `-23.5503898, -46.633081`; se BrasilAPI falhar, `CepClient` chama ViaCEP e preenche o endereço sem coordenadas, deixando lat/lon editáveis; o Android nunca chama BrasilAPI/ViaCEP diretamente (só o backend, `CepController`). Esta é a segunda API externa exigida pelo critério 4 e garante o critério mesmo se o sandbox Inter falhar (docs/19-riscos.md, R2). Teste `CepClientTest` com `MockRestServiceServer` cobre o fallback.

### RF10 — O sistema deve impedir a desativação de uma quadra que tenha reservas ativas (PENDENTE_PAGAMENTO ou CONFIRMADA) com início no futuro, respondendo 409.

| Prioridade | Perfil | Tela(s) | Endpoint(s) |
|---|---|---|---|
| Must Have (N1) | DONO | `MinhasQuadras` (diálogo "Desativar") | `DELETE /api/v1/quadras/{id}` → 409 `QUADRA_COM_RESERVAS` |

Critério de aceite: com a reserva CONFIRMADA de amanhã do seed, desativar a quadra devolve 409 e o app mostra "Há 1 reserva futura. Cancele-a antes de desativar"; após cancelar a reserva (RF17), o mesmo `DELETE` devolve 204. Regras: RN16.

## Módulo Horários

### RF11 — O sistema deve permitir ao DONO o CRUD completo de HorarioFuncionamento da quadra, uma faixa por dia da semana (1 = segunda .. 7 = domingo), com criação, leitura, alteração e remoção individuais.

| Prioridade | Perfil | Tela(s) | Endpoint(s) |
|---|---|---|---|
| Must Have (N1) | DONO (leitura: ambos) | `HorariosQuadra` | `POST /api/v1/quadras/{id}/horarios-funcionamento` `{diaSemana, horaAbertura, horaFechamento}` → 201; 400; 409 `DIA_JA_CADASTRADO` · `GET .../horarios-funcionamento` → 200 · `PUT .../horarios-funcionamento/{hid}` → 200; 409 `HORARIO_COM_RESERVAS` · `DELETE .../horarios-funcionamento/{hid}` → 204; 409 `HORARIO_COM_RESERVAS` |

Critério de aceite: a tela mostra 7 linhas; ligar o switch de "Sábado" dispara `POST` e cria a linha `dia_semana=6`; alterar a hora de fechamento no `TimePicker` dispara `PUT /{hid}`; desligar o switch dispara `DELETE /{hid}` e a linha volta a "Fechado"; hora de fechamento menor ou igual à de abertura devolve 400 com `campos[]`; cada operação aparece separada no Swagger (evidência do CRUD nº 2, critério 3). Regras: RN03, RN16, RN19.

## Módulo Reservas

### RF12 — O sistema deve exibir, para uma quadra e uma data (hoje até hoje + 14 dias), a grade de slots de 60 minutos com status LIVRE, OCUPADO, PASSADO ou FECHADO.

| Prioridade | Perfil | Tela(s) | Endpoint(s) |
|---|---|---|---|
| Must Have (N2); backend pronto na N1 | CLIENTE (DONO consulta a agenda em `ReservasQuadra`, RF18) | `DetalheQuadra` (seletor de data + grade) | `GET /api/v1/quadras/{id}/slots?data=2026-10-10` → 200 `[{inicio, fim, valor, status}]`; 404; 422 `DATA_FORA_DA_JANELA` |

Critério de aceite: para uma quadra aberta 08:00–22:00 o backend devolve 14 slots por dia; o slot da reserva CONFIRMADA do seed vem `OCUPADO`; slots de hoje anteriores à hora atual vêm `PASSADO`; dia sem `horario_funcionamento` devolve todos `FECHADO`; `data=hoje+15` devolve 422; o app só permite tocar slots `LIVRE`. Cálculo em `SlotService` no fuso `America/Sao_Paulo` (RNF12), com `SlotServiceTest`. Regras: RN06, RN07, RN09, RN19.

### RF13 — O sistema deve permitir ao CLIENTE criar uma reserva em status PENDENTE_PAGAMENTO para um slot livre, garantindo exclusividade do slot no banco (409 HORARIO_INDISPONIVEL para o concorrente).

| Prioridade | Perfil | Tela(s) | Endpoint(s) |
|---|---|---|---|
| Must Have (N2); backend pronto na N1 | CLIENTE | `ConfirmarReserva` | `POST /api/v1/reservas` `{quadraId, inicio, observacao?}` → 201 `ReservaResponse{..., pagamento{txid, pixCopiaECola, valor, expiraEm, status}}`; 400 `VALIDACAO` (hora não cheia, passado); 404; **409 `HORARIO_INDISPONIVEL`**; 422 `FORA_DO_FUNCIONAMENTO` / `DATA_FORA_DA_JANELA` / `RESERVA_PENDENTE_EXISTENTE`; 502 `PAGAMENTO_INDISPONIVEL` |

Critério de aceite: dois celulares tocam "Confirmar" no mesmo slot: um recebe 201 e vai para `Pagamento`, o outro recebe 409, vê o snackbar "Esse horário acabou de ser reservado. Escolha outro" e volta à grade recarregada; `ReservaConcorrenciaIT` (10 threads) resulta em exatamente 1×201, 9×409 e `count(*)`=1 de reservas ativas no slot. Regras: RN06 a RN11 (detalhe da concorrência em docs/07-regras-de-negocio.md, RN08).

### RF14 — O sistema deve expirar automaticamente reservas PENDENTE_PAGAMENTO não pagas em 15 minutos, liberando o slot e marcando o pagamento como EXPIRADO.

| Prioridade | Perfil | Tela(s) | Endpoint(s) |
|---|---|---|---|
| Must Have (N2); backend pronto na N1 | sistema | `Pagamento` (status "Expirado"), `MinhasReservas` (`ChipStatus` EXPIRADA) | nenhum: `ExpiracaoReservaJob` `@Scheduled(fixedDelay = 60_000)` com `UPDATE` condicional em `reserva` e `pagamento` |

Critério de aceite: criar reserva, não pagar e esperar até 16 min: `reserva.status='EXPIRADA'`, `pagamento.status='EXPIRADO'`, o slot volta `LIVRE` em `GET /slots` e outro cliente consegue reservá-lo (o índice `ux_reserva_slot_ativo` ignora linhas EXPIRADA); em teste, `expira_em` pode ser reduzido por propriedade `app.reserva.minutos-para-pagar`. Regras: RN10.

### RF15 — O sistema deve permitir ao CLIENTE listar as próprias reservas separadas em Próximas e Histórico e ver o detalhe de cada uma, incluindo o status do pagamento.

| Prioridade | Perfil | Tela(s) | Endpoint(s) |
|---|---|---|---|
| Must Have (N2) | CLIENTE | `MinhasReservas`, `DetalheReserva` | `GET /api/v1/reservas?situacao=PROXIMAS\|HISTORICO` → 200; `GET /api/v1/reservas/{id}` → 200 (com `pagamento`); 403 (reserva de outro cliente); 404 |

Critério de aceite: aba Próximas mostra PENDENTE_PAGAMENTO e CONFIRMADA com `inicio` futuro; Histórico mostra as demais (CANCELADA, EXPIRADA e passadas); o detalhe mostra quadra, data/hora, valor, observação, `ChipStatus`, `txid` e status do pagamento e a regra de cancelamento aplicável ("Cancelamento gratuito até 2 h antes"); pedir `GET /reservas/{id}` de outro cliente devolve 403 `ACESSO_NEGADO`. Regras: RN04, RN15.

### RF16 — O sistema deve permitir ao CLIENTE editar a observação da própria reserva enquanto ela estiver ativa.

| Prioridade | Perfil | Tela(s) | Endpoint(s) |
|---|---|---|---|
| Must Have (N2) | CLIENTE | `DetalheReserva` | `PATCH /api/v1/reservas/{id}` `{observacao}` (máx. 200) → 200; 403; 422 `TRANSICAO_INVALIDA` (reserva CANCELADA/EXPIRADA) |

Critério de aceite: alterar a observação para "Levar 2 bolas" e salvar atualiza `reserva.observacao` e o valor volta no `GET`; em reserva CANCELADA o campo fica desabilitado e o backend responde 422. Só a observação é editável no MVP (remarcar `inicio` é Could Have). Regras: RN15.

### RF17 — O sistema deve permitir cancelar uma reserva: o CLIENTE cancela a própria (PENDENTE a qualquer momento; CONFIRMADA até 2 h antes do início) e o DONO cancela reservas das suas quadras até o início, com motivo obrigatório.

| Prioridade | Perfil | Tela(s) | Endpoint(s) |
|---|---|---|---|
| Must Have (N2) | CLIENTE, DONO | `DetalheReserva` (cliente), `ReservasQuadra` (dono) | `POST /api/v1/reservas/{id}/cancelar` `{motivo?}` → 200; 400 `VALIDACAO` (DONO sem motivo); 403; 422 `CANCELAMENTO_FORA_DO_PRAZO` / `TRANSICAO_INVALIDA` |

Critério de aceite: cliente cancela reserva CONFIRMADA de amanhã → 200, `status='CANCELADA'`, `cancelado_por='CLIENTE'`, slot volta `LIVRE`; cliente tenta cancelar reserva CONFIRMADA que começa em 1 h → 422 e o app mostra "Cancelamento permitido até 2 h antes"; dono cancela com motivo "Manutenção do piso" → 200 e `motivo_cancelamento` gravado; cancelar PENDENTE marca `pagamento.status='CANCELADO'` e tenta remover a cobrança no Inter (best effort). Regras: RN13, RN14 (sem estorno automático).

### RF18 — O sistema deve permitir ao DONO listar as reservas recebidas nas suas quadras por data (ou as próximas, sem data), com nome e telefone do cliente, status e valor.

| Prioridade | Perfil | Tela(s) | Endpoint(s) |
|---|---|---|---|
| Must Have (N2) | DONO | `ReservasQuadra` (por quadra, via `MinhasQuadras`) e aba Reservas (todas as quadras) | `GET /api/v1/quadras/{id}/reservas?data=2026-10-10` → 200; 403 (quadra de outro dono) · `GET /api/v1/reservas?situacao=PROXIMAS` (DONO: das suas quadras) → 200 |

Critério de aceite: o dono do seed vê a reserva CONFIRMADA de amanhã com `clienteNome`, `clienteTelefone`, "19:00–20:00", R$ 80,00 e `ChipStatus`; a resposta nunca inclui dados do pagador Pix (RN05); dono de outra quadra recebe 403. Regras: RN03, RN05.

## Módulo Pagamentos

### RF19 — O sistema deve gerar uma cobrança Pix imediata (QR Code + código copia e cola) no ato da criação da reserva, com expiração igual à da reserva (900 s), via `PixGateway` (Inter sandbox/produção ou simulado).

| Prioridade | Perfil | Tela(s) | Endpoint(s) |
|---|---|---|---|
| Must Have (N2); backend pronto na N1 (profile `simulado` via Swagger); Pix em produção = Should Have | CLIENTE | `Pagamento` | incluído na resposta de `POST /api/v1/reservas` (`pagamento{txid, pixCopiaECola, valor, expiraEm, status}`); `GET /api/v1/reservas/{id}/pagamento` → 200; 502 `PAGAMENTO_INDISPONIVEL` na criação |

Critério de aceite: após o 201 a tela mostra o QR gerado localmente do `pixCopiaECola` (ZXing core 3.5.4), o valor, o botão "Copiar código" (`ClipboardManager`) e o contador regressivo até `expiraEm`; no profile `inter-sandbox` a cobrança existe no Inter (`GET /pix/v2/cob/{txid}` → `ATIVA`) com `txid` = UUID sem hífens (32 chars); no profile `simulado` o payload BR Code estático gerado por `PixPayloadBuilder` passa no `PixPayloadBuilderTest` (CRC16-CCITT contra payload conhecido) e é reconhecido por um app de banco; se o gateway falhar, a reserva é cancelada por SISTEMA e o app mostra "Não foi possível gerar a cobrança, tente novamente" (RN17). Detalhes em docs/11-integracao-pix-inter.md. Regras: RN10, RN17, RN18. Segurança: RNF02.

### RF20 — O sistema deve confirmar o pagamento automaticamente (polling do app + job do backend; webhook do Inter recomendado) e mudar a reserva para CONFIRMADA de forma idempotente.

| Prioridade | Perfil | Tela(s) | Endpoint(s) |
|---|---|---|---|
| Must Have (N2) (polling + job); webhook = Should Have | CLIENTE (tela); sistema | `Pagamento` → `DetalheReserva` | `GET /api/v1/reservas/{id}/pagamento` (polling a cada 5 s por 2 min, depois 10 s, enquanto a tela estiver STARTED) · `ConsultaPagamentoJob` `@Scheduled(60 s)`, até 10 pendentes por ciclo, `GET /pix/v2/cob/{txid}` · [Should] `POST /api/v1/webhooks/inter/pix/{segredo}` (público, array JSON do Inter) → 200/400 |

Critério de aceite: ao pagar no sandbox (ou simular, RF21) o status na tela passa de "Aguardando" para "Pago" em até 30 s sem ação do usuário e o app navega para `DetalheReserva` com `ChipStatus` CONFIRMADA; `PagamentoServiceTest` prova que confirmar duas vezes o mesmo `txid` (job + webhook) altera 1 linha na primeira e 0 na segunda; valor divergente da cobrança não confirma e gera log `WARN`. Regras: RN12, RN14.

### RF21 — O sistema deve permitir simular a confirmação de um pagamento em ambiente de desenvolvimento e sandbox, por endpoint protegido inexistente em produção.

| Prioridade | Perfil | Tela(s) | Endpoint(s) |
|---|---|---|---|
| Must Have (N2) | CLIENTE (JWT) + header `X-Dev-Key` | `Pagamento` (botão "Simular pagamento", só em `BuildConfig.DEBUG`) | `POST /api/v1/dev/pagamentos/{txid}/confirmar` → 200; 404; profiles `simulado` (marca PAGO) e `inter-sandbox` (repassa para `POST /pix/v2/cob/pagar/{txid}` no sandbox, escopo `pix.write`); ausente em `inter-prod` |

Critério de aceite: em `simulado`, o botão confirma em menos de 5 s (próximo ciclo do polling); em `inter-sandbox`, o botão faz o sandbox marcar a cobrança como `CONCLUIDA` e o `ConsultaPagamentoJob` detecta e confirma em até 60 s; sem `X-Dev-Key` → 403; com `SPRING_PROFILES_ACTIVE=inter-prod` a rota não existe (404). Opcional: `simulado.auto-confirmar-segundos=20`.

## Módulo Geolocalização (recurso nativo)

### RF22 — O sistema deve obter a localização do usuário (com permissão), mostrar a distância até cada quadra, ordenar a lista por proximidade e abrir a quadra no app de mapas do celular.

| Prioridade | Perfil | Tela(s) | Endpoint(s) |
|---|---|---|---|
| Must Have (N2) | CLIENTE (o DONO só vê a distância se alcançar a lista pelo link Could Have do `Perfil`) | `Quadras` (card "Ativar localização", "a 2,3 km", ordenação), `DetalheQuadra` ("Abrir no Maps") | nenhum novo: usa `latitude`/`longitude` de `GET /api/v1/quadras`; `FusedLocationProviderClient.getCurrentLocation` (`play-services-location 21.4.0`); `Intent(ACTION_VIEW, "geo:lat,lon?q=lat,lon(Nome)")` |

Critério de aceite: ao conceder `ACCESS_COARSE_LOCATION`/`ACCESS_FINE_LOCATION` (pedidas juntas, no toque do card e não no launch) a lista reordena pela distância Haversine (`Geo.distanciaKm`) e cada card mostra "a X,X km"; quadras sem coordenadas vão para o fim; permissão negada → ordem alfabética e texto "Ative a localização para ver a distância"; sem fix de GPS a cadeia é `getCurrentLocation` → `lastLocation` → `ultima_lat/lon` do DataStore → sem distância; "Abrir no Maps" abre o app de mapas instalado sem SDK. Detalhes em docs/13-recurso-nativo.md. RNF08 cobre celular sem Google Play Services.

## Módulo Persistência local

### RF23 — O sistema deve manter cache local de quadras e reservas (Room) com sincronização "cache primeiro, servidor vence" e leitura offline das telas de consulta.

| Prioridade | Perfil | Tela(s) | Endpoint(s) |
|---|---|---|---|
| Must Have (N2) | CLIENTE, DONO | `Quadras`, `DetalheQuadra`, `MinhasReservas`, `DetalheReserva`, `Pagamento` (QR do cache), `MinhasQuadras`, `HorariosQuadra`, `ReservasQuadra` (todas com `BannerOffline`) | nenhum novo: `Sincronizador.sincronizar()` chama `GET /quadras`, `GET /quadras/minhas`, `GET /reservas`, `GET /quadras/{id}/reservas` e substitui o escopo em `quadra_cache` / `reserva_cache` |

Critério de aceite: com o app em modo avião, `Quadras` abre instantaneamente com os dados da última sincronização e o banner "Dados de 10/10 19:32"; `DetalheReserva` reabre o QR Pix a partir de `pixCopiaECola` em cache; botões de escrita (Reservar, Cancelar, Salvar) ficam desabilitados; ao voltar a rede (`MonitorConectividade`) a lista é atualizada e reservas apagadas no servidor somem do cache (servidor vence). Detalhes em docs/12-persistencia-local.md. RNF11.

## Módulo Notificações

Nota de escopo: o módulo inteiro é **recomendado** (Should Have), e não obrigatório, porque o critério de recurso nativo da disciplina já está coberto pela geolocalização (RF22); se o item for cortado por falta de prazo, ele deve ser marcado como **retirado, com a data da decisão**, em vez de apagado deste documento, para que o módulo pedido pelo grupo continue registrado e rastreável na banca.

### RF24 — O sistema deve emitir uma notificação local "Reserva confirmada" no dispositivo quando o pagamento for confirmado enquanto o app estiver aberto.

| Prioridade | Perfil | Tela(s) | Endpoint(s) |
|---|---|---|---|
| Should Have | CLIENTE | `Pagamento` (pede `POST_NOTIFICATIONS` na primeira abertura, API 33+) | nenhum: `PagamentoViewModel` detecta PENDENTE → PAGO e chama `NotificadorReserva.confirmada(reserva)` (`NotificationCompat`, canal `reservas`) |

Critério de aceite: ao confirmar o pagamento, aparece na barra a notificação "Reserva confirmada! Quadra X, 10/10 às 19h" cujo toque abre `DetalheReserva`; permissão negada = nenhuma notificação e nenhum erro; o switch `notificar_confirmacao` em `Perfil` desliga o recurso. Não é push (FCM) — dito explicitamente na apresentação. Entra só com todos os Must verdes (regra de ouro do backlog).

## Rastreabilidade RF → tela → endpoint → integrante

Integrante titular (suplente entre parênteses) conforme docs/15-divisao-equipe.md: A (D) = auth/usuário/infra; B (C) = quadra/horários/CEP; C (B) = reserva/slots/sync/geolocalização; D (A) = pagamento Pix.

| RF | Prioridade | Tela(s) | Endpoint(s) / componente | Integrante |
|---|---|---|---|---|
| RF01 | Must (N1) | Cadastro | `POST /auth/registrar` | A (D) |
| RF02 | Must (N1) | Login | `POST /auth/login` | A (D) |
| RF03 | Must (N1) | Splash, Perfil | `SessaoDataStore`, `AuthInterceptor` | A (D) |
| RF04 | Must (N2) | Login | `POST /auth/login` 429, `LoginTentativasService` | A (D) |
| RF05 | Must (N1) | Perfil | `GET/PUT /usuarios/me` | A (D) |
| RF06 | Must (N1) | MinhasQuadras, FormQuadra | `POST/GET/PUT/DELETE /quadras`, `GET /quadras/minhas` | B (C) |
| RF07 | Must (N1) | Quadras | `GET /quadras?esporte=&cidade=` | B (C) |
| RF08 | Must (N1) | DetalheQuadra | `GET /quadras/{id}` | B (C); distância: C |
| RF09 | Must (N1) | FormQuadra | `GET /cep/{cep}`, `CepClient` | B (C) |
| RF10 | Must (N1) | MinhasQuadras | `DELETE /quadras/{id}` 409 | B (C) |
| RF11 | Must (N1) | HorariosQuadra | `POST/GET/PUT/DELETE /quadras/{id}/horarios-funcionamento[/{hid}]` | B (C) |
| RF12 | Must (N2) (backend N1) | DetalheQuadra | `GET /quadras/{id}/slots?data=`, `SlotService` | C (B) |
| RF13 | Must (N2) (backend N1) | ConfirmarReserva | `POST /reservas`, `ReservaService`, `ReservaFacade`, `ux_reserva_slot_ativo` | C (B) |
| RF14 | Must (N2) (backend N1) | Pagamento, MinhasReservas | `ExpiracaoReservaJob` | C (B) |
| RF15 | Must (N2) | MinhasReservas, DetalheReserva | `GET /reservas?situacao=`, `GET /reservas/{id}` | C (B) |
| RF16 | Must (N2) | DetalheReserva | `PATCH /reservas/{id}` | C (B) |
| RF17 | Must (N2) | DetalheReserva, ReservasQuadra | `POST /reservas/{id}/cancelar` | C (B) |
| RF18 | Must (N2) | ReservasQuadra | `GET /quadras/{id}/reservas?data=`, `GET /reservas` (DONO) | C (B) |
| RF19 | Must (N2) (backend N1); produção Should | Pagamento | `POST /reservas` (pagamento), `PixGateway`, `SimuladoPixGateway`, `InterPixGateway` | D (A) |
| RF20 | Must (N2); webhook Should | Pagamento, DetalheReserva | `GET /reservas/{id}/pagamento`, `ConsultaPagamentoJob`, `POST /webhooks/inter/pix/{segredo}` | D (A) |
| RF21 | Must (N2) | Pagamento (debug) | `POST /dev/pagamentos/{txid}/confirmar` | D (A) |
| RF22 | Must (N2) | Quadras, DetalheQuadra | `LocalizacaoProvider`, `Geo.kt`, Intent `geo:` | C (B) |
| RF23 | Must (N2) | 8 telas com `BannerOffline` | `AppDatabase`, `Sincronizador`, `MonitorConectividade` | C (B); `quadra_cache`: B |
| RF24 | Should | Pagamento | `NotificadorReserva` | C (B) |

Cobertura dos critérios da disciplina por RF: critério 3 (≥ 6 telas, navegação, autenticação, 2 perfis, CRUD ×2) → RF01–RF03, RF06, RF11 e as 13 telas; critério 4 (persistência local, remota, sincronização, API externa) → RF03, RF09, RF19, RF23; critério 5 (recurso nativo) → RF22 (principal) e RF24 (secundário); critério 6 (qualidade) → critérios de aceite de todos os RFs + RNF06/RNF07. A matriz completa está em docs/00-indice.md.
