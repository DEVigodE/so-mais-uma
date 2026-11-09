import '../../../utils/typedefs.dart';
import '../entities/app_user.dart';
import '../entities/endereco_cep.dart';
import '../entities/horario_funcionamento.dart';
import '../entities/pagamento.dart';
import '../entities/quadra.dart';
import '../entities/reserva.dart';
import '../entities/slot.dart';
import '../enums.dart';

/// Contratos dos repositórios do domínio (design D13, sem cache local).
///
/// As telas dependem só destes contratos; os testes usam implementações
/// falsas. Todos os erros saem como `Failure` (`NetworkFailure` para falta de
/// conexão, `ApiFailure` para respostas de erro da API).

abstract class QuadraRepository {
  /// `GET /quadras` — quadras ativas, com filtro opcional.
  FutureEither<List<Quadra>> listar({TipoEsporte? esporte, String? cidade});

  /// `GET /quadras/minhas` — quadras do DONO, inclusive as inativas.
  FutureEither<List<Quadra>> minhas();

  /// `GET /quadras/{id}` — detalhe com os horários de funcionamento.
  FutureEither<Quadra> detalhar(int id);

  /// `POST /quadras`.
  FutureEither<Quadra> criar(QuadraDados dados);

  /// `PUT /quadras/{id}`.
  FutureEither<Quadra> atualizar(int id, QuadraDados dados);

  /// `DELETE /quadras/{id}` — desativação lógica. 409 `QUADRA_COM_RESERVAS`
  /// quando há reservas futuras.
  FutureEither<void> desativar(int id);
}

abstract class CepRepository {
  /// `GET /cep/{cep}` — `cep` com 8 dígitos. 404 quando não existe e 503
  /// `CEP_INDISPONIVEL` quando os provedores falham.
  FutureEither<EnderecoCep> buscar(String cep);
}

abstract class HorarioRepository {
  /// `GET /quadras/{id}/horarios-funcionamento`.
  FutureEither<List<HorarioFuncionamento>> listar(int quadraId);

  /// `POST /quadras/{id}/horarios-funcionamento` (409 `DIA_JA_CADASTRADO`).
  FutureEither<HorarioFuncionamento> criar(
    int quadraId, {
    required int diaSemana,
    required String horaAbertura,
    required String horaFechamento,
  });

  /// `PUT /quadras/{id}/horarios-funcionamento/{hid}` (409
  /// `HORARIO_COM_RESERVAS`).
  FutureEither<HorarioFuncionamento> atualizar(
    int quadraId,
    int horarioId, {
    required String horaAbertura,
    required String horaFechamento,
  });

  /// `DELETE /quadras/{id}/horarios-funcionamento/{hid}` (409
  /// `HORARIO_COM_RESERVAS`).
  FutureEither<void> remover(int quadraId, int horarioId);
}

abstract class SlotRepository {
  /// `GET /quadras/{id}/slots?data=yyyy-MM-dd` (hoje até hoje + 14).
  /// `data` é uma data de parede de Brasília (ver `Brasilia`).
  FutureEither<List<Slot>> slots(int quadraId, DateTime data);
}

abstract class ReservaRepository {
  /// `GET /reservas` — do cliente ou das quadras do dono (últimos 12 meses e
  /// futuras). `situacao` opcional (`PROXIMAS`, ...). `pagamento` vem nulo.
  FutureEither<List<Reserva>> listar({String? situacao});

  /// `GET /reservas/{id}` — com a cobrança.
  FutureEither<Reserva> detalhar(int id);

  /// `POST /reservas` — cria `PENDENTE_PAGAMENTO` e devolve a cobrança Pix.
  /// 409 `HORARIO_INDISPONIVEL`; 422 `RESERVA_PENDENTE_EXISTENTE` (com
  /// `reservaId`), `DATA_FORA_DA_JANELA`, `FORA_DO_FUNCIONAMENTO`; 502
  /// `PAGAMENTO_INDISPONIVEL`.
  FutureEither<Reserva> criar({
    required int quadraId,
    required DateTime inicio,
    String? observacao,
  });

  /// `PATCH /reservas/{id}` — só a observação (nula ou vazia apaga).
  FutureEither<Reserva> atualizarObservacao(int id, String? observacao);

  /// `POST /reservas/{id}/cancelar` — motivo de 5 a 200 caracteres.
  /// 422 `CANCELAMENTO_FORA_DO_PRAZO` ou `TRANSICAO_INVALIDA`.
  FutureEither<Reserva> cancelar(int id, String motivo);

  /// `GET /quadras/{id}/reservas[?data=]` — agenda da quadra para o dono: da
  /// data informada (data de parede) ou, sem data, as próximas.
  FutureEither<List<Reserva>> agendaDaQuadra(int quadraId, {DateTime? data});
}

abstract class PagamentoRepository {
  /// `GET /reservas/{id}/pagamento` — estado atual da cobrança (polling).
  FutureEither<Pagamento> estado(int reservaId);

  /// `POST /dev/pagamentos/{txid}/confirmar` com `X-Dev-Key` — só em debug,
  /// contra o backend no profile `simulado`.
  FutureEither<void> simular(String txid);
}

abstract class UsuarioRepository {
  /// `GET /usuarios/me`.
  FutureEither<AppUser> obter();

  /// `PUT /usuarios/me` — nome e telefone (só dígitos) e, opcionalmente, a
  /// troca de senha (422 `SENHA_ATUAL_INCORRETA`). Atualiza a sessão.
  FutureEither<AppUser> atualizar({
    required String nome,
    String? telefone,
    String? senhaAtual,
    String? novaSenha,
  });
}
