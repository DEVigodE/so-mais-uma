import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:so_mais_uma/src/features/quadras/presentation/minhas_quadras/minhas_quadras_store.dart';
import 'package:so_mais_uma/src/shared/domain/brasilia.dart';
import 'package:so_mais_uma/src/shared/domain/entities/horario_funcionamento.dart';
import 'package:so_mais_uma/src/shared/domain/entities/quadra.dart';
import 'package:so_mais_uma/src/shared/domain/entities/reserva.dart';
import 'package:so_mais_uma/src/shared/domain/enums.dart';
import 'package:so_mais_uma/src/shared/domain/repositories/repositorios.dart';
import 'package:so_mais_uma/src/utils/async_state.dart';
import 'package:so_mais_uma/src/utils/failure.dart';
import 'package:so_mais_uma/src/utils/typedefs.dart';

class RelogioFixo extends Relogio {
  RelogioFixo(this.instante);

  final DateTime instante;

  @override
  DateTime agora() => instante;
}

class QuadraRepositoryFalso implements QuadraRepository {
  QuadraRepositoryFalso(this.lista);

  List<Quadra> lista;
  Failure? falhaMinhas;
  Failure? falhaDesativar;
  var chamadasMinhas = 0;
  final desativadas = <int>[];

  @override
  FutureEither<List<Quadra>> minhas() async {
    chamadasMinhas++;
    final f = falhaMinhas;
    return f == null ? Right(List.of(lista)) : Left(f);
  }

  @override
  FutureEither<void> desativar(int id) async {
    final f = falhaDesativar;
    if (f != null) return Left(f);
    desativadas.add(id);
    lista =
        lista.map((q) => q.id == id ? q.copyWith(ativa: false) : q).toList();
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class ReservaRepositoryFalso implements ReservaRepository {
  ReservaRepositoryFalso(this.lista);

  final List<Reserva> lista;
  Failure? falha;

  @override
  FutureEither<List<Reserva>> listar({String? situacao}) async {
    final f = falha;
    return f == null ? Right(lista) : Left(f);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class HorarioRepositoryFalso implements HorarioRepository {
  final porQuadra = <int, List<HorarioFuncionamento>>{};
  final consultadas = <int>[];

  @override
  FutureEither<List<HorarioFuncionamento>> listar(int quadraId) async {
    consultadas.add(quadraId);
    return Right(porQuadra[quadraId] ?? const []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// 09/11/2026 (segunda) em Brasília.
DateTime br(int hora, {int minuto = 0}) =>
    DateTime.utc(2026, 11, 9, hora + 3, minuto);

Quadra quadra(int id, String nome, {bool ativa = true}) => Quadra(
      id: id,
      nome: nome,
      tipoEsporte: TipoEsporte.futebolSociety,
      precoHora: 90,
      cep: '01001000',
      logradouro: 'Rua A',
      numero: '1',
      cidade: 'São Paulo',
      uf: 'SP',
      ativa: ativa,
    );

Reserva reserva(int id, int quadraId, int hora, StatusReserva status) =>
    Reserva(
      id: id,
      quadraId: quadraId,
      quadraNome: 'Q$quadraId',
      inicio: br(hora),
      fim: br(hora + 1),
      status: status,
      valor: 90,
    );

void main() {
  setUpAll(() => EasyLocalization.logger.enableBuildModes = []);

  late QuadraRepositoryFalso quadras;
  late ReservaRepositoryFalso reservas;
  late HorarioRepositoryFalso horarios;
  late MinhasQuadrasStore store;

  setUp(() {
    quadras = QuadraRepositoryFalso([
      quadra(1, 'Arena Champions'),
      quadra(2, 'Beach & Tennis'),
      quadra(3, 'Gol de Placa', ativa: false),
    ]);
    reservas = ReservaRepositoryFalso([
      reserva(1, 2, 9, StatusReserva.confirmada),
      reserva(2, 2, 18, StatusReserva.confirmada),
      reserva(3, 2, 19, StatusReserva.pendentePagamento),
      reserva(4, 1, 20, StatusReserva.confirmada),
    ]);
    horarios = HorarioRepositoryFalso()
      ..porQuadra[1] = const [
        HorarioFuncionamento(
          id: 10,
          diaSemana: 1,
          horaAbertura: '08:00',
          horaFechamento: '22:00',
        ),
      ]
      ..porQuadra[2] = const [];
    store = MinhasQuadrasStore(
      quadras,
      reservas,
      horarios,
      RelogioFixo(br(15, minuto: 10)),
    );
  });

  tearDown(() => store.dispose());

  test('carrega a lista na ordem "Mais ativas" com o painel', () async {
    await store.carregar();

    expect(store.estado.value, isA<RequestSuccess<List<Quadra>>>());
    expect(store.cards.value.map((c) => c.quadra.id), [2, 1, 3]);
    expect(store.resumo.value.totalQuadras, 3);
    expect(store.resumo.value.reservasHoje, 3);
    expect(store.cards.value.first.atividade.reservasHoje, 3);
    expect(store.cards.value.first.atividade.proxima, br(18));
  });

  test('busca as faixas das quadras ativas sem bloquear a lista', () async {
    await store.carregar();
    await pumpEventQueue();

    expect(horarios.consultadas, unorderedEquals([1, 2]));
    final porId = {for (final c in store.cards.value) c.quadra.id: c};
    expect(porId[1]!.atividade.ocupacao, 7); // 1 de 14 slots
    expect(porId[2]!.atividade.fechadaHoje, isTrue);
  });

  test('falha das reservas deixa as métricas desconhecidas', () async {
    reservas.falha = const NetworkFailure('sem conexão');
    await store.carregar();

    expect(store.estado.value, isA<RequestSuccess<List<Quadra>>>());
    expect(store.resumo.value.reservasHoje, isNull);
    expect(store.cards.value.first.atividade.reservasHoje, isNull);
  });

  test('falha da primeira carga vira RequestFailure', () async {
    quadras.falhaMinhas = const NetworkFailure('sem conexão');
    await store.carregar();
    expect(store.estado.value, isA<RequestFailure<List<Quadra>>>());
  });

  test('falha ao atualizar mantém a lista e avisa', () async {
    await store.carregar();
    quadras.falhaMinhas = const NetworkFailure('sem conexão');
    await store.carregar();

    expect(store.estado.value, isA<RequestSuccess<List<Quadra>>>());
    expect(store.evento.value, isA<FalhaMinhasQuadras>());
  });

  test('sem quadras: lista vazia (primeiro acesso)', () async {
    quadras.lista = [];
    await store.carregar();
    expect(store.cards.value, isEmpty);
    expect(store.resumo.value.totalQuadras, 0);
  });

  group('desativar', () {
    test('409 QUADRA_COM_RESERVAS: diálogo e a quadra continua ativa',
        () async {
      await store.carregar();
      quadras.falhaDesativar = const ApiFailure(
        status: 409,
        codigo: 'QUADRA_COM_RESERVAS',
        message: 'há reservas',
      );

      await store.desativar(quadras.lista.first);

      final evento = store.evento.value;
      expect(evento, isA<DesativacaoBloqueada>());
      expect((evento! as DesativacaoBloqueada).quadraId, 1);
      final q1 = store.cards.value.firstWhere((c) => c.quadra.id == 1);
      expect(q1.quadra.ativa, isTrue);
      expect(store.desativando.value, isEmpty);
      expect(quadras.chamadasMinhas, 1, reason: 'não sincroniza no 409');
    });

    test('204: o card passa a inativo e a lista sincroniza', () async {
      await store.carregar();

      await store.desativar(quadras.lista.first);

      expect(quadras.desativadas, [1]);
      expect(store.evento.value, isA<QuadraDesativada>());
      final q1 = store.cards.value.firstWhere((c) => c.quadra.id == 1);
      expect(q1.quadra.ativa, isFalse);
      expect(store.cards.value.last.quadra.ativa, isFalse);
      await pumpEventQueue();
      expect(quadras.chamadasMinhas, 2);
    });

    test('403: sem permissão', () async {
      await store.carregar();
      quadras.falhaDesativar = const ApiFailure(status: 403, message: 'negado');

      await store.desativar(quadras.lista.first);

      expect(store.evento.value, isA<SemPermissao>());
    });
  });

  test('respostas depois do dispose são ignoradas', () async {
    final futuro = store.carregar();
    store.dispose();
    await futuro;
    // Recria para o tearDown.
    store = MinhasQuadrasStore(
      quadras,
      reservas,
      horarios,
      RelogioFixo(br(15)),
    );
  });
}
