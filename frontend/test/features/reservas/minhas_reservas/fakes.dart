import 'package:fpdart/fpdart.dart' show Either, left, right;
import 'package:so_mais_uma/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:so_mais_uma/src/shared/domain/domain.dart';
import 'package:so_mais_uma/src/utils/failure.dart';
import 'package:so_mais_uma/src/utils/typedefs.dart';

/// "Agora" controlado pelos testes.
class RelogioFixo extends Relogio {
  RelogioFixo(this.valor);

  DateTime valor;

  @override
  DateTime agora() => valor;
}

/// Agora de referência: 09/11/2026 15:00 em Brasília (18:00 UTC).
final DateTime agoraBase = DateTime.utc(2026, 11, 9, 18);

Pagamento pagamentoFake({
  StatusPagamento status = StatusPagamento.pendente,
  DateTime? expiraEm,
  DateTime? pagoEm,
  double valor = 90,
}) =>
    Pagamento(
      txid: 'TX123',
      status: status,
      provedor: ProvedorPagamento.simulado,
      valor: valor,
      pixCopiaECola: '00020126580014br.gov.bcb.pix',
      expiraEm: expiraEm,
      pagoEm: pagoEm,
    );

Reserva reservaFake({
  int id = 1,
  int quadraId = 10,
  String quadraNome = 'Arena Champions',
  required DateTime inicio,
  Duration duracao = const Duration(hours: 1),
  StatusReserva status = StatusReserva.confirmada,
  double valor = 90,
  String? observacao,
  DateTime? expiraEm,
  CanceladoPor? canceladoPor,
  String? motivoCancelamento,
  DateTime? canceladoEm,
  Pagamento? pagamento,
}) =>
    Reserva(
      id: id,
      quadraId: quadraId,
      quadraNome: quadraNome,
      quadraEndereco: 'Av. das Nações Unidas, 1420 - Pinheiros, São Paulo/SP',
      inicio: inicio,
      fim: inicio.add(duracao),
      status: status,
      valor: valor,
      observacao: observacao,
      expiraEm: expiraEm,
      canceladoPor: canceladoPor,
      motivoCancelamento: motivoCancelamento,
      canceladoEm: canceladoEm,
      pagamento: pagamento,
    );

Quadra quadraFake({int id = 10, String? fotoUrl}) => Quadra(
      id: id,
      nome: 'Arena Champions',
      tipoEsporte: TipoEsporte.futebolSociety,
      precoHora: 90,
      cep: '05425070',
      logradouro: 'Av. das Nações Unidas',
      numero: '1420',
      bairro: 'Pinheiros',
      cidade: 'São Paulo',
      uf: 'SP',
      fotoUrl: fotoUrl,
    );

FutureEither<T> ok<T>(T valor) => Future.value(right<Failure, T>(valor));
FutureEither<T> falha<T>(Failure f) => Future.value(left<Failure, T>(f));

class FakeReservaRepository implements ReservaRepository {
  FutureEither<List<Reserva>> Function()? onListar;
  FutureEither<Reserva> Function(int id)? onDetalhar;
  FutureEither<Reserva> Function(int id, String? observacao)? onObservacao;
  FutureEither<Reserva> Function(int id, String motivo)? onCancelar;

  final List<String?> situacoesListadas = [];
  final List<int> detalhados = [];
  final List<(int, String?)> observacoes = [];
  final List<(int, String)> cancelamentos = [];

  @override
  FutureEither<List<Reserva>> listar({String? situacao}) {
    situacoesListadas.add(situacao);
    return onListar?.call() ?? ok(const <Reserva>[]);
  }

  @override
  FutureEither<Reserva> detalhar(int id) {
    detalhados.add(id);
    return onDetalhar!(id);
  }

  @override
  FutureEither<Reserva> atualizarObservacao(int id, String? observacao) {
    observacoes.add((id, observacao));
    return onObservacao!(id, observacao);
  }

  @override
  FutureEither<Reserva> cancelar(int id, String motivo) {
    cancelamentos.add((id, motivo));
    return onCancelar!(id, motivo);
  }

  @override
  FutureEither<Reserva> criar({
    required int quadraId,
    required DateTime inicio,
    String? observacao,
  }) =>
      throw UnimplementedError();

  @override
  FutureEither<List<Reserva>> agendaDaQuadra(int quadraId, {DateTime? data}) =>
      throw UnimplementedError();
}

class FakeQuadraRepository implements QuadraRepository {
  FutureEither<List<Quadra>> Function()? onListar;
  FutureEither<Quadra> Function(int id)? onDetalhar;
  int listagens = 0;

  @override
  FutureEither<List<Quadra>> listar({TipoEsporte? esporte, String? cidade}) {
    listagens++;
    return onListar?.call() ?? ok(const <Quadra>[]);
  }

  @override
  FutureEither<Quadra> detalhar(int id) =>
      onDetalhar?.call(id) ??
      falha(const ApiFailure(status: 404, codigo: 'NAO_ENCONTRADO'));

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

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository(this.usuario);

  final AppUser? usuario;

  @override
  Stream<AppUser?> get onAuthStateChanged => const Stream.empty();

  @override
  FutureEither<AppUser?> checkAuthState() => ok(usuario);

  @override
  FutureEither<void> logout() => ok(null);

  @override
  FutureEither<AppUser> login(
          {required String email, required String password}) =>
      throw UnimplementedError();

  @override
  FutureEither<AppUser> signUp({
    required String name,
    required String email,
    required String password,
  }) =>
      throw UnimplementedError();

  @override
  FutureEither<void> forgotPassword({required String email}) =>
      throw UnimplementedError();
}

/// Tipo usado nos testes para respostas com `Either`.
typedef Resposta<T> = Either<Failure, T>;
