import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:so_mais_uma/src/features/reservas/presentation/confirmar_reserva/confirmar_reserva_store.dart';
import 'package:so_mais_uma/src/shared/domain/entities/quadra.dart';
import 'package:so_mais_uma/src/shared/domain/entities/reserva.dart';
import 'package:so_mais_uma/src/shared/domain/enums.dart';
import 'package:so_mais_uma/src/shared/domain/repositories/repositorios.dart';
import 'package:so_mais_uma/src/utils/async_state.dart';
import 'package:so_mais_uma/src/utils/failure.dart';
import 'package:so_mais_uma/src/utils/typedefs.dart';

const _quadra = Quadra(
  id: 3,
  nome: 'Arena Champions',
  tipoEsporte: TipoEsporte.futebolSociety,
  precoHora: 90,
  cep: '01310100',
  logradouro: 'Av. das Nações Unidas',
  numero: '1420',
  bairro: 'Pinheiros',
  cidade: 'São Paulo',
  uf: 'SP',
);

// Sábado, 10/10/2026, 19:00 em Brasília.
final _inicio = DateTime.utc(2026, 10, 10, 22);

Reserva _reserva(int id) => Reserva(
      id: id,
      quadraId: 3,
      quadraNome: 'Arena Champions',
      inicio: _inicio,
      fim: _inicio.add(const Duration(hours: 1)),
      status: StatusReserva.pendentePagamento,
      valor: 90,
    );

class _QuadrasFalsas implements QuadraRepository {
  Either<Failure, Quadra> resposta = const Right(_quadra);

  @override
  FutureEither<Quadra> detalhar(int id) async => resposta;

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

class _ReservasFalsas implements ReservaRepository {
  final criacoes = <({int quadraId, DateTime inicio, String? observacao})>[];
  Completer<Either<Failure, Reserva>> resposta = Completer();

  @override
  FutureEither<Reserva> criar({
    required int quadraId,
    required DateTime inicio,
    String? observacao,
  }) {
    criacoes.add((quadraId: quadraId, inicio: inicio, observacao: observacao));
    return resposta.future;
  }

  @override
  FutureEither<List<Reserva>> listar({String? situacao}) =>
      throw UnimplementedError();
  @override
  FutureEither<Reserva> detalhar(int id) => throw UnimplementedError();
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

void main() {
  late _QuadrasFalsas quadras;
  late _ReservasFalsas reservas;
  late ConfirmarReservaStore store;

  setUp(() async {
    quadras = _QuadrasFalsas();
    reservas = _ReservasFalsas();
    store = ConfirmarReservaStore(quadras, reservas);
    await store.carregar(3, _inicio);
  });

  tearDown(() => store.dispose());

  test('carrega o resumo e habilita o confirmar', () {
    expect(store.quadra.value, isA<RequestSuccess<Quadra>>());
    expect(store.inicio.value, _inicio);
    expect(store.podeConfirmar.value, isTrue);
    expect(store.enviando.value, isFalse);
  });

  test('2xx emite a ida ao pagamento com o id da reserva', () async {
    store.alterarObservacao('  Levar 2 bolas  ');
    final futuro = store.confirmar();
    expect(store.enviando.value, isTrue);
    expect(store.podeConfirmar.value, isFalse);
    reservas.resposta.complete(Right(_reserva(42)));
    await futuro;

    final evento = store.evento.value;
    expect(evento, isA<IrParaPagamento>());
    expect((evento as IrParaPagamento).reservaId, 42);
    expect(reservas.criacoes.single.quadraId, 3);
    expect(reservas.criacoes.single.inicio, _inicio);
    expect(reservas.criacoes.single.observacao, 'Levar 2 bolas');
    // Continua bloqueado até a navegação.
    expect(store.enviando.value, isTrue);
    store.consumirEvento();
    await store.confirmar();
    expect(reservas.criacoes, hasLength(1));
  });

  test('observação vazia é omitida', () async {
    store.alterarObservacao('   ');
    final futuro = store.confirmar();
    reservas.resposta.complete(Right(_reserva(1)));
    await futuro;
    expect(reservas.criacoes.single.observacao, isNull);
  });

  test('sem POST duplicado enquanto a resposta não chega', () async {
    final primeiro = store.confirmar();
    final segundo = store.confirmar();
    final terceiro = store.confirmar();
    expect(reservas.criacoes, hasLength(1));
    reservas.resposta.complete(Right(_reserva(7)));
    await Future.wait([primeiro, segundo, terceiro]);
    expect(reservas.criacoes, hasLength(1));
  });

  /// Confirma e responde com [failure]; devolve o evento emitido.
  Future<EventoConfirmacao?> confirmarCom(Failure failure) async {
    final futuro = store.confirmar();
    reservas.resposta.complete(Left(failure));
    await futuro;
    return store.evento.value;
  }

  /// Depois de um evento que sai da tela, o botão segue bloqueado e um novo
  /// toque não gera outro POST.
  Future<void> esperarBloqueado() async {
    expect(store.enviando.value, isTrue);
    expect(store.podeConfirmar.value, isFalse);
    store.consumirEvento();
    await store.confirmar();
    expect(reservas.criacoes, hasLength(1));
  }

  test('409 HORARIO_INDISPONIVEL pede a volta com recarga', () async {
    final evento = await confirmarCom(
      const ApiFailure(status: 409, codigo: 'HORARIO_INDISPONIVEL'),
    );
    expect(evento, isA<HorarioIndisponivel>());
    expect(evento!.saiDaTela, isTrue);
    await esperarBloqueado();
  });

  test('422 RESERVA_PENDENTE_EXISTENTE traz o reservaId', () async {
    final futuro = store.confirmar();
    reservas.resposta.complete(
      const Left(ApiFailure(
        status: 422,
        codigo: 'REGRA_NEGOCIO',
        subcodigo: 'RESERVA_PENDENTE_EXISTENTE',
        reservaId: 99,
      )),
    );
    await futuro;
    final evento = store.evento.value;
    expect(evento, isA<ReservaPendenteExistente>());
    expect((evento as ReservaPendenteExistente).reservaId, 99);
    expect(store.enviando.value, isFalse);
  });

  test('502 PAGAMENTO_INDISPONIVEL abre o diálogo e volta com recarga',
      () async {
    final evento = await confirmarCom(
      const ApiFailure(status: 502, codigo: 'PAGAMENTO_INDISPONIVEL'),
    );
    expect(evento, isA<PagamentoIndisponivel>());
    await esperarBloqueado();
  });

  test('422 FORA_DO_FUNCIONAMENTO: aviso com a regra e volta com recarga',
      () async {
    final evento = await confirmarCom(
      const ApiFailure(
        status: 422,
        codigo: 'REGRA_NEGOCIO',
        subcodigo: 'FORA_DO_FUNCIONAMENTO',
        message: 'A quadra não funciona neste horário.',
      ),
    );
    expect(evento, isA<HorarioForaDaRegra>());
    expect(
      (evento as HorarioForaDaRegra).mensagem,
      'A quadra não funciona neste horário.',
    );
    await esperarBloqueado();
  });

  test('422 DATA_FORA_DA_JANELA: aviso com a regra e volta com recarga',
      () async {
    final evento = await confirmarCom(
      const ApiFailure(
        status: 422,
        codigo: 'REGRA_NEGOCIO',
        subcodigo: 'DATA_FORA_DA_JANELA',
        message: 'Só é possível reservar de hoje até 14 dias à frente.',
      ),
    );
    expect(evento, isA<HorarioForaDaRegra>());
    expect((evento as HorarioForaDaRegra).mensagem, contains('14 dias'));
    await esperarBloqueado();
  });

  test('400 no campo inicio (início no passado) volta à grade', () async {
    final evento = await confirmarCom(
      const ApiFailure(
        status: 400,
        codigo: 'VALIDACAO',
        campos: {'inicio': 'não pode estar no passado'},
      ),
    );
    expect(evento, isA<InicioNoPassado>());
    await esperarBloqueado();
  });

  test('404 no POST: "quadra não encontrada" e volta', () async {
    final evento = await confirmarCom(
      const ApiFailure(status: 404, codigo: 'NAO_ENCONTRADO'),
    );
    expect(evento, isA<QuadraIndisponivel>());
    await esperarBloqueado();
  });

  test('outro erro inesperado mostra a mensagem e a tela permanece', () async {
    final evento = await confirmarCom(
      const ApiFailure(status: 500, codigo: 'ERRO_INTERNO', message: 'Erro'),
    );
    expect(evento, isA<FalhaConfirmacao>());
    expect(evento!.saiDaTela, isFalse);
    expect(store.enviando.value, isFalse);
    expect(store.podeConfirmar.value, isTrue);
  });

  test('falha de rede: mensagem e permite tentar de novo', () async {
    final futuro = store.confirmar();
    reservas.resposta.complete(const Left(NetworkFailure('sem rede')));
    await futuro;
    final evento = store.evento.value;
    expect(evento, isA<FalhaConfirmacao>());
    expect((evento as FalhaConfirmacao).failure, isA<NetworkFailure>());
    expect(store.enviando.value, isFalse);
    expect(store.podeConfirmar.value, isTrue);
  });

  test('observação acima de 200 caracteres desabilita o confirmar', () async {
    store.alterarObservacao('a' * 201);
    expect(store.podeConfirmar.value, isFalse);
    await store.confirmar();
    expect(reservas.criacoes, isEmpty);
    store.alterarObservacao('a' * 200);
    expect(store.podeConfirmar.value, isTrue);
  });

  test('404 no resumo vira "quadra não encontrada" e bloqueia o confirmar',
      () async {
    final outroQuadras = _QuadrasFalsas()
      ..resposta =
          const Left(ApiFailure(status: 404, codigo: 'NAO_ENCONTRADO'));
    final outro = ConfirmarReservaStore(outroQuadras, reservas);
    await outro.carregar(3, _inicio);
    expect(outro.naoEncontrada.value, isTrue);
    expect(outro.podeConfirmar.value, isFalse);
    await outro.confirmar();
    expect(reservas.criacoes, isEmpty);
    outro.dispose();
  });

  test('resposta do POST depois do dispose é descartada', () async {
    final futuro = store.confirmar();
    store.dispose();
    reservas.resposta.complete(Right(_reserva(5)));
    await expectLater(futuro, completes);
    // O tearDown chama dispose de novo: precisa ser seguro.
  });
}
