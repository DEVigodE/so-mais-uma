## Purpose

Permite que CLIENTE e DONO vejam e mantenham os próprios dados e a própria senha, acompanhem quando o app
sincronizou pela última vez, ajustem a preferência de aviso de pagamento e encerrem a sessão. Nada disso
deixa alterar o e-mail ou o perfil.

## ADDED Requirements

### Requirement: Fidelidade do Perfil ao protótipo
O Perfil (`/perfil` para CLIENTE e `/dono/perfil` para DONO) SHALL reproduzir
`docs/Protótipo de Alta Fidelidade/perfil_do_usu_rio/code.html`:
- barra com logo e título "Perfil Do Usuário";
- cartão de cabeçalho com o avatar grande de iniciais, o nome, o e-mail e a pílula de perfil com o texto
  "(Perfil Fixo)";
- faixa de contadores;
- seção "Dados Pessoais" com Nome completo (ícone de lápis), "E-mail cadastrado" com a pílula
  "Somente leitura" e cadeado, "Telefone / WhatsApp" (ícone de telefone) e o botão "Salvar alterações";
- seção "Segurança e Senha" com o item recolhível "Alterar senha / Proteja o acesso à sua conta e partidas",
  os campos "Senha atual" e "Nova senha" e o botão "Atualizar credenciais";
- seção "Preferências e Notificações" com o switch "Confirmação de reserva";
- rodapé com a pílula de última sincronização, a versão e o botão "Sair da conta com segurança".

Elementos omitidos, conforme RN20 e docs/02:
- o botão de câmera e a troca de foto;
- o contador "Presença";
- o switch "Lembrete 1h antes da partida";
- o cartão "Modo Proprietário";
- as marcações "RF05", "(RN20 · Perfil Fixo)" e "(N2 REC)", que dão lugar a "(Perfil Fixo)" e aos títulos
  limpos.

Ajustes de texto:
- a descrição do switch passa a "Aviso neste aparelho quando o pagamento da sua reserva for confirmado", em
  vez de push e SMS;
- o rodapé de versão é "Versão <versão> (Build <build>) · Só mais uma".

(RF05, RF03, RN20)

#### Scenario: Elementos fora do MVP não aparecem
- **WHEN** um CLIENTE abre o Perfil
- **THEN** não existem botão de câmera, contador "Presença", switch "Lembrete 1h antes da partida" nem cartão "Modo Proprietário"
- **AND** a pílula de perfil mostra "Cliente / Atleta (Perfil Fixo)"

#### Scenario: Descrição honesta do aviso
- **WHEN** a seção de preferências é exibida
- **THEN** a descrição do switch não menciona push nem SMS

### Requirement: Variante do Perfil para o DONO
O DONO SHALL ver o mesmo layout com os textos de proprietário:
- pílula "Proprietário / Arena (Perfil Fixo)" com o ícone de estádio;
- contadores "Quadras", com o total de quadras cadastradas, e "Reservas", com as reservas confirmadas
  recebidas nos últimos 12 meses do cache;
- sem a seção "Preferências e Notificações", porque o aviso de pagamento só existe para o cliente.

(RF05, RN20)

#### Scenario: DONO sem preferência de aviso
- **WHEN** um DONO abre o Perfil
- **THEN** a pílula mostra "Proprietário / Arena (Perfil Fixo)" e a seção de notificações não aparece

### Requirement: Consulta e edição dos dados pessoais
O Perfil SHALL mostrar imediatamente os dados guardados na sessão. Com rede, SHALL atualizar esses dados com
`GET /usuarios/me`. Salvar SHALL enviar `PUT /usuarios/me` com `{nome, telefone}`, este só com dígitos,
depois de validar o nome com 2 a 100 caracteres e o telefone vazio ou com 10 ou 11 dígitos. O sucesso SHALL:
- atualizar `usuario_nome`, `usuario_telefone` e as iniciais do avatar;
- mostrar "Alterações salvas com sucesso!".

400 `VALIDACAO` SHALL marcar os campos de `campos[]`. Outros erros SHALL aparecer em snackbar, mantendo os
dados locais. (RF05, RNF06, CT-07)

#### Scenario: Telefone alterado persiste
- **WHEN** o usuário troca o telefone para `(11) 91234-5678` e toca "Salvar alterações"
- **THEN** a API recebe `11912345678` e a tela mostra "Alterações salvas com sucesso!"
- **AND** ao reabrir o Perfil o telefone novo aparece

#### Scenario: Nome curto demais
- **WHEN** o usuário apaga o nome e deixa uma única letra
- **THEN** o campo mostra o erro de tamanho e nada é enviado

### Requirement: Troca de senha
O item "Alterar senha" SHALL expandir os campos "Senha atual" e "Nova senha". A nova senha SHALL seguir a
política de RNF01, e a senha atual SHALL ser obrigatória quando a nova é preenchida. "Atualizar credenciais"
SHALL enviar `PUT /usuarios/me` com o nome e o telefone já salvos, mais `senhaAtual` e `novaSenha`, para
alterar apenas a senha. O comportamento por resultado SHALL ser:
- **422 `SENHA_ATUAL_INCORRETA`**: "Senha atual incorreta" no campo "Senha atual";
- **sucesso**: os dois campos são limpos e aparece a confirmação.

O próximo login só SHALL funcionar com a senha nova. (RF05, RNF01, CT-07)

#### Scenario: Senha atual errada
- **WHEN** o usuário informa a senha atual errada e uma nova senha válida
- **THEN** o campo "Senha atual" mostra "Senha atual incorreta"
- **AND** a senha antiga continua valendo

#### Scenario: Troca bem-sucedida
- **WHEN** o usuário informa a senha atual correta e `NovaSenha9`
- **THEN** os campos de senha são limpos e a próxima entrada só aceita `NovaSenha9`

### Requirement: E-mail e perfil não editáveis
O e-mail e o perfil SHALL ser exibidos como somente leitura, anunciados como tal ao leitor de tela, e SHALL
NOT ser enviados no `PUT /usuarios/me`. (RF05, RN20, CT-07)

#### Scenario: Campo de e-mail bloqueado
- **WHEN** o usuário toca no campo "E-mail cadastrado"
- **THEN** o campo não abre teclado e permanece com o valor do cadastro

### Requirement: Contadores calculados do Perfil
Os contadores SHALL ser calculados de `reserva_cache` e `quadra_cache`, sem endpoint próprio:
- **CLIENTE**: "Jogos" é a quantidade de reservas `CONFIRMADA` cujo fim já passou, e "Arenas" é a quantidade
  de quadras distintas entre essas reservas;
- **DONO**: "Quadras" é o total do escopo `MINHAS`, e "Reservas" é a quantidade de reservas `CONFIRMADA` no
  cache.

Os contadores refletem os últimos 12 meses que a API devolve. (RF15, RF23)

#### Scenario: Jogos e arenas do cliente
- **GIVEN** no cache 3 reservas `CONFIRMADA` já encerradas em 2 quadras diferentes, 1 `CONFIRMADA` futura e 1 `CANCELADA`
- **WHEN** o CLIENTE abre o Perfil
- **THEN** o contador "Jogos" mostra 3 e o contador "Arenas" mostra 2

### Requirement: Preferência de aviso de confirmação
O switch "Confirmação de reserva" SHALL ler e gravar `notificar_confirmacao`, com padrão ligado. Desligado,
nenhuma notificação local de confirmação é emitida. (RF24)

#### Scenario: Aviso desligado
- **GIVEN** o switch desligado
- **WHEN** um pagamento é confirmado com a tela Pagamento aberta
- **THEN** o app navega para a DetalheReserva sem emitir notificação

### Requirement: Última sincronização e versão
O rodapé SHALL mostrar "Última sincronização: <quando>" com o instante mais recente entre
`ultima_sincronizacao_quadras` e `ultima_sincronizacao_reservas`, seguido de "· Conectado" quando o backend
está alcançável ou "· Offline" quando não está. A versão SHALL ser lida do pacote instalado. (RF23, RF03)

#### Scenario: Última sincronização offline
- **GIVEN** a última sincronização às 19:32 de hoje e o aparelho em modo avião
- **WHEN** o Perfil é aberto
- **THEN** o rodapé mostra "Última sincronização: hoje às 19:32 · Offline"

### Requirement: Sair da conta
"Sair da conta com segurança" SHALL abrir um diálogo com o texto
"Deseja realmente encerrar a sessão? Seus dados sincronizados estarão seguros." e confirmar antes de encerrar
a sessão. O botão SHALL funcionar também sem rede. (RF03, RNF03, CT-06)

#### Scenario: Cancelar a saída
- **WHEN** o usuário toca Sair e depois cancela o diálogo
- **THEN** a sessão continua ativa e o Perfil permanece aberto

### Requirement: Perfil sem conexão
Sem conexão com o backend, o Perfil SHALL exibir os dados da sessão. "Salvar alterações" e
"Atualizar credenciais" SHALL ficar desabilitados com o texto "Conecte-se para alterar". O botão Sair SHALL
continuar funcionando. (RNF11, RF23, CT-28)

#### Scenario: Perfil em modo avião
- **GIVEN** o aparelho em modo avião
- **WHEN** o usuário abre o Perfil
- **THEN** nome, e-mail, telefone e perfil aparecem, e os botões de gravação estão desabilitados com "Conecte-se para alterar"

### Requirement: Acessibilidade do Perfil
Os campos somente leitura SHALL ser anunciados com o valor e o estado desabilitado. O switch SHALL ter o
rótulo clicável. O item recolhível SHALL anunciar se está expandido. O botão Sair SHALL ter texto, além da
cor de erro. (RNF07)

#### Scenario: Item recolhível anunciado
- **GIVEN** o TalkBack ligado
- **WHEN** o foco chega em "Alterar senha"
- **THEN** o leitor anuncia o item como recolhido e, após o toque, como expandido
