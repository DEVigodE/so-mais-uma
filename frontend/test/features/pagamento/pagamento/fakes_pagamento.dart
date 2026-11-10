// `fake_async` vem com o flutter_test (dependência transitiva).
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:fpdart/fpdart.dart' show Either, left, right;
import 'package:so_mais_uma/src/shared/domain/domain.dart';
import 'package:so_mais_uma/src/utils/failure.dart';
import 'package:so_mais_uma/src/utils/typedefs.dart';

/// Agora de referência: 09/11/2026 15:00 em Brasília.
final DateTime base = DateTime.utc(2026, 11, 9, 18);

/// Relógio que anda junto com o `FakeAsync`.
class RelogioFake extends Relogio {
  RelogioFake(this._fake);

  final FakeAsync _fake;

  @override
  DateTime agora() => base.add(_fake.elapsed);
}

FutureEither<T> ok<T>(T valor) => Future.value(right<Failure, T>(valor));
FutureEither<T> erro<T>(Failure f) => Future.value(left<Failure, T>(f));

const String codigoPix = '00020126580014br.gov.bcb.pix0136abc520400005303986';

Pagamento cobranca({
  StatusPagamento status = StatusPagamento.pendente,
  Duration expiraEm = const Duration(minutes: 15),
  ProvedorPagamento provedor = ProvedorPagamento.simulado,
}) =>
    Pagamento(
      txid: 'TX7',
      status: status,
      provedor: provedor,
      valor: 90,
      pixCopiaECola: codigoPix,
      expiraEm: base.add(expiraEm),
    );

Reserva reservaPendente({
  Duration expiraEm = const Duration(minutes: 15),
  StatusReserva status = StatusReserva.pendentePagamento,
  StatusPagamento statusPagamento = StatusPagamento.pendente,
}) =>
    Reserva(
      id: 7,
      quadraId: 3,
      quadraNome: 'Arena Champions',
      quadraEndereco: 'Av. das Nações Unidas, 1420 - Pinheiros, São Paulo/SP',
      inicio: base.add(const Duration(days: 1)),
      fim: base.add(const Duration(days: 1, hours: 1)),
      status: status,
      valor: 90,
      expiraEm: base.add(expiraEm),
      pagamento: cobranca(status: statusPagamento, expiraEm: expiraEm),
    );

class FakeReservas implements ReservaRepository {
  FakeReservas(this.onDetalhar);

  FutureEither<Reserva> Function(int id) onDetalhar;
  int detalhes = 0;

  @override
  FutureEither<Reserva> detalhar(int id) {
    detalhes++;
    return onDetalhar(id);
  }

  @override
  FutureEither<List<Reserva>> listar({String? situacao}) =>
      throw UnimplementedError();

  @override
  FutureEither<Reserva> criar({
    required int quadraId,
    required DateTime inicio,
    String? observacao,
  }) =>
      throw UnimplementedError();

  @override
  FutureEither<Reserva> atualizarObservacao(int id, String? observacao) =>
      throw UnimplementedError();

  @override
  FutureEither<Reserva> cancelar(int id, String motivo) =>
      throw UnimplementedError();

  @override
  FutureEither<List<Reserva>> agendaDaQuadra(int quadraId, {DateTime? data}) =>
      throw UnimplementedError();
}

/// Registra o instante (tempo do `FakeAsync`) de cada consulta da cobrança.
class FakePagamentos implements PagamentoRepository {
  FakePagamentos(this._fake);

  final FakeAsync _fake;
  final List<Duration> consultas = [];
  final List<String> simulacoes = [];

  /// Resposta da n-ésima consulta (começa em 0). Padrão: pendente.
  Either<Failure, Pagamento> Function(int n) resposta =
      (_) => right(cobranca());
  FutureEither<void> Function(String txid) onSimular = (_) => ok(null);

  @override
  FutureEither<Pagamento> estado(int reservaId) {
    final n = consultas.length;
    consultas.add(_fake.elapsed);
    return Future.value(resposta(n));
  }

  @override
  FutureEither<void> simular(String txid) {
    simulacoes.add(txid);
    return onSimular(txid);
  }
}

class FakeQuadras implements QuadraRepository {
  @override
  FutureEither<Quadra> detalhar(int id) =>
      erro(const ApiFailure(status: 404, codigo: 'NAO_ENCONTRADO'));

  @override
  FutureEither<List<Quadra>> listar({TipoEsporte? esporte, String? cidade}) =>
      throw UnimplementedError();

  @override
  FutureEither<List<Quadra>> minhas() => throw UnimplementedError();

  @override
  FutureEither<Quadra> criar(QuadraDados dados) => throw UnimplementedError();

  @override
  FutureEither<Quadra> atualizar(int id, QuadraDados dados) =>
      throw UnimplementedError();

  @override
  FutureEither<void> desativar(int id) => throw UnimplementedError();
}

/// Segundos de cada consulta, para comparar sequências.
List<int> segundos(List<Duration> instantes) =>
    instantes.map((d) => d.inSeconds).toList();
