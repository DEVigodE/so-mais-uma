import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:so_mais_uma/src/features/reservas/presentation/reservas_quadra/reservas_quadra_store.dart';
import 'package:so_mais_uma/src/shared/domain/brasilia.dart';
import 'package:so_mais_uma/src/shared/domain/entities/horario_funcionamento.dart';
import 'package:so_mais_uma/src/shared/domain/entities/quadra.dart';
import 'package:so_mais_uma/src/shared/domain/entities/reserva.dart';
import 'package:so_mais_uma/src/shared/domain/enums.dart';
import 'package:so_mais_uma/src/shared/domain/repositories/repositorios.dart';
import 'package:so_mais_uma/src/utils/async_state.dart';
import 'package:so_mais_uma/src/utils/failure.dart';
import 'package:so_mais_uma/src/utils/typedefs.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────

class RelogioFixo extends Relogio {
  RelogioFixo(this.instante);
  DateTime instante;
  @override
  DateTime agora() => instante;
}

Quadra quadra(int id, {bool ativa = true}) => Quadra(
      id: id,
      nome: 'Quadra $id',
      tipoEsporte: TipoEsporte.futebolSociety,
      precoHora: 90,
      cep: '01310100',
      logradouro: 'Av. Paulista',
      numero: '1000',
      cidade: 'São Paulo',
      uf: 'SP',
      ativa: ativa,
    );

DateTime br(int ano, int mes, int dia, int hora) =>
    Brasilia.instante(DateTime.utc(ano, mes, dia, hora));

Reserva reserva(
  int id, {
  required DateTime inicio,
  int quadraId = 1,
  StatusReserva status = StatusReserva.confirmada,
  double valor = 90,
  DateTime? expiraEm,
  String? clienteNome,
}) =>
    Reserva(
      id: id,
      quadraId: quadraId,
      quadraNome: 'Quadra $quadraId',
      inicio: inicio,
      fim: inicio.add(const Duration(hours: 1)),
      status: status,
      valor: valor,
      expiraEm: expiraEm,
      clienteNome: clienteNome ?? 'Cliente $id',
      clienteTelefone: '11987654321',
    );

class FakeQuadraRepository implements QuadraRepository {
  Either<Failure, List<Quadra>> resposta = right(const []);
  int chamadasMinhas = 0;

  @override
  FutureEither<List<Quadra>> minhas() async {
    chamadasMinhas++;
    return resposta;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeReservaRepository implements ReservaRepository {
  Either<Failure, List<Reserva>> respostaListar = right(const []);
  Completer<Either<Failure, List<Reserva>>>? listarPendente;
  final Map<int, List<Reserva>> agenda = {};
  final Set<int> agendaFalha = {};
  final List<(int, DateTime?)> chamadasAgenda = [];
  int chamadasListar = 0;

  @override
  FutureEither<List<Reserva>> listar({String? situacao}) {
    chamadasListar++;
    return listarPendente?.future ?? Future.value(respostaListar);
  }

  @override
  FutureEither<List<Reserva>> agendaDaQuadra(int quadraId,
      {DateTime? data}) async {
    chamadasAgenda.add((quadraId, data));
    if (agendaFalha.contains(quadraId)) {
      return left(const NetworkFailure('sem conexão'));
    }
    return right(agenda[quadraId] ?? const []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHorarioRepository implements HorarioRepository {
  final Map<int, List<HorarioFuncionamento>> faixas = {};

  @override
  FutureEither<List<HorarioFuncionamento>> listar(int quadraId) async {
    final f = faixas[quadraId];
    return f == null ? left(const NetworkFailure('falhou')) : right(f);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Faixa de [horas] slots em todos os dias da semana.
List<HorarioFuncionamento> todosOsDias(int abertura, int fechamento) => [
      for (var d = 1; d <= 7; d++)
        HorarioFuncionamento(
          diaSemana: d,
          horaAbertura: HorarioFuncionamento.hora(abertura),
          horaFechamento: HorarioFuncionamento.hora(fechamento),
        ),
    ];

Future<void> esvaziarFila() => Future<void>.delayed(Duration.zero);

void main() {
  // Segunda, 9/11/2026, 15:00 em Brasília.
  final agora = br(2026, 11, 9, 15);
  final hoje = DateTime.utc(2026, 11, 9);
  final amanha = DateTime.utc(2026, 11, 10);

  late FakeQuadraRepository quadras;
  late FakeReservaRepository reservas;
  late FakeHorarioRepository horarios;
  late ReservasQuadraStore store;

  setUp(() {
    quadras = FakeQuadraRepository()
      ..resposta = right([quadra(1), quadra(2), quadra(3, ativa: false)]);
    reservas = FakeReservaRepository()
      ..respostaListar = right([
        reserva(1, inicio: br(2026, 11, 9, 19)),
        reserva(2, inicio: br(2026, 11, 9, 17), quadraId: 2),
        reserva(
          3,
          inicio: br(2026, 11, 9, 20),
          status: StatusReserva.pendentePagamento,
          expiraEm: agora.add(const Duration(minutes: 11)),
        ),
        reserva(4,
            inicio: br(2026, 11, 9, 16), status: StatusReserva.cancelada),
        reserva(5, inicio: br(2026, 11, 10, 19), clienteNome: 'Maria Souza'),
        reserva(6, inicio: br(2026, 10, 1, 19)),
      ]);
    horarios = FakeHorarioRepository()
      ..faixas[1] = todosOsDias(8, 18) // 10 slots
      ..faixas[2] = todosOsDias(18, 23) // 5 slots
      ..faixas[3] = todosOsDias(8, 20); // inativa: fora da soma de "Todas"
    store =
        ReservasQuadraStore(quadras, reservas, horarios, RelogioFixo(agora));
  });

  tearDown(() => store.dispose());

  group('carga e faixa de datas', () {
    test('carrega as quadras e as reservas de hoje, por início', () async {
      expect(store.carga.value, isA<RequestInitial<void>>());
      await store.carregar();

      expect(store.carga.value, isA<RequestSuccess<void>>());
      expect(store.quadras.value.map((q) => q.id), [1, 2, 3]);
      expect(store.dataSelecionada.value, hoje);
      expect(store.faixa.value, hasLength(15));
      expect(store.faixa.value.first, hoje);
      expect(store.faixa.value.last, DateTime.utc(2026, 11, 23));
      expect(store.reservas.value.map((r) => r.id), [4, 2, 1, 3]);
    });

    test('aberta por uma quadra começa com o chip dela', () async {
      await store.carregar(quadraId: 2);
      expect(store.quadraFiltro.value, 2);
      expect(store.reservas.value.map((r) => r.id), [2]);
    });

    test('data da faixa filtra localmente, sem chamada online', () async {
      await store.carregar();
      await store.selecionarData(amanha);

      expect(store.naFaixa.value, isTrue);
      expect(store.reservas.value.map((r) => r.id), [5]);
      expect(reservas.chamadasAgenda, isEmpty);
      expect(store.resumo.value.hoje, isFalse);
    });

    test('filtro por quadra', () async {
      await store.carregar();
      await store.selecionarQuadra(1);
      expect(store.reservas.value.map((r) => r.id), [4, 1, 3]);
      await store.selecionarQuadra(null);
      expect(store.reservas.value, hasLength(4));
    });

    test('falha na primeira carga vira estado de erro', () async {
      quadras.resposta = left(const NetworkFailure('sem conexão'));
      await store.carregar();
      expect(store.carga.value, isA<RequestFailure<void>>());
      expect(store.mensagem.value, isNull);
    });

    test('falha ao atualizar mantém a lista e avisa por mensagem', () async {
      await store.carregar();
      reservas.respostaListar = left(const NetworkFailure('sem conexão'));
      await store.atualizar();

      expect(store.carga.value, isA<RequestSuccess<void>>());
      expect(store.reservas.value, hasLength(4));
      expect(store.mensagem.value, 'sem conexão');
      store.consumirMensagem();
      expect(store.mensagem.value, isNull);
    });

    test('atualizar sinaliza o andamento e ignora toques repetidos', () async {
      await store.carregar();
      final pendente = Completer<Either<Failure, List<Reserva>>>();
      reservas.listarPendente = pendente;
      final antes = reservas.chamadasListar;

      final atualizacao = store.atualizar();
      expect(store.atualizando.value, isTrue);
      await store.atualizar();
      expect(reservas.chamadasListar, antes + 1);

      pendente.complete(right(const []));
      await atualizacao;
      expect(store.atualizando.value, isFalse);
      expect(store.reservas.value, isEmpty);
    });

    test('resposta depois do dispose é ignorada', () async {
      final pendente = Completer<Either<Failure, List<Reserva>>>();
      reservas.listarPendente = pendente;
      final carga = store.carregar();
      store.dispose();
      pendente.complete(right([reserva(1, inicio: br(2026, 11, 9, 19))]));
      await carga;
      // Sem exceção ao escrever em signals descartados.
      store =
          ReservasQuadraStore(quadras, reservas, horarios, RelogioFixo(agora));
    });
  });

  group('"Outro dia"', () {
    final mesPassado = DateTime.utc(2026, 10, 1);

    test('consulta online uma vez por quadra do filtro', () async {
      reservas.agenda[1] = [reserva(6, inicio: br(2026, 10, 1, 19))];
      reservas.agenda[2] = [
        reserva(7, inicio: br(2026, 10, 1, 9), quadraId: 2)
      ];
      await store.carregar();
      await store.selecionarData(mesPassado);

      expect(store.naFaixa.value, isFalse);
      expect(reservas.chamadasAgenda, [
        (1, mesPassado),
        (2, mesPassado),
        (3, mesPassado),
      ]);
      expect(store.cargaLista.value, isA<RequestSuccess<void>>());
      expect(store.reservas.value.map((r) => r.id), [7, 6]);
      expect(store.resumo.value.hoje, isFalse);
    });

    test('com chip selecionado consulta só a quadra e completa ao trocar',
        () async {
      reservas.agenda[1] = [reserva(6, inicio: br(2026, 10, 1, 19))];
      reservas.agenda[2] = [
        reserva(7, inicio: br(2026, 10, 1, 9), quadraId: 2)
      ];
      await store.carregar(quadraId: 1);
      await store.selecionarData(mesPassado);

      expect(reservas.chamadasAgenda, [(1, mesPassado)]);
      expect(store.reservas.value.map((r) => r.id), [6]);

      await store.selecionarQuadra(null);
      expect(
        reservas.chamadasAgenda,
        [(1, mesPassado), (2, mesPassado), (3, mesPassado)],
        reason: 'a quadra 1 já consultada não é repetida',
      );
      expect(store.reservas.value.map((r) => r.id), [7, 6]);
    });

    test('falha online mostra a caixa de erro e "Tentar novamente" repete',
        () async {
      reservas.agendaFalha.add(2);
      await store.carregar();
      await store.selecionarData(mesPassado);
      expect(store.cargaLista.value, isA<RequestFailure<void>>());

      reservas.agendaFalha.clear();
      reservas.chamadasAgenda.clear();
      await store.tentarNovamente();
      expect(store.cargaLista.value, isA<RequestSuccess<void>>());
      expect(reservas.chamadasAgenda, hasLength(3));
    });

    test('voltar para uma data da faixa usa a lista sincronizada', () async {
      await store.carregar();
      await store.selecionarData(mesPassado);
      reservas.chamadasAgenda.clear();
      await store.selecionarData(hoje);

      expect(store.naFaixa.value, isTrue);
      expect(store.cargaLista.value, isA<RequestSuccess<void>>());
      expect(store.reservas.value, hasLength(4));
      expect(reservas.chamadasAgenda, isEmpty);
    });
  });

  group('resumo do dia', () {
    test('ocupação pelas faixas das quadras ativas, sem bloquear a carga',
        () async {
      await store.carregar();
      // Antes das faixas chegarem a ocupação é omitida.
      expect(store.resumo.value.ocupacaoPercentual, isNull);
      await esvaziarFila();

      final r = store.resumo.value;
      expect(store.slotsDoDia.value, 15,
          reason: '10 + 5; a quadra 3 está inativa');
      expect(r.agendadas, 2);
      expect(r.aguardando, 1);
      expect(r.expiraEmMinutos, 11);
      expect(r.ocupacaoPercentual, 20); // 3 ativas / 15 slots
      expect(r.previsao, 270);
      expect(r.hoje, isTrue);
    });

    test('ocupação segue o chip selecionado', () async {
      await store.carregar();
      await esvaziarFila();
      await store.selecionarQuadra(2);
      expect(store.slotsDoDia.value, 5);
      expect(store.resumo.value.ocupacaoPercentual, 20); // 1 / 5
    });

    test('faixa que falhou deixa a ocupação omitida', () async {
      horarios.faixas.remove(2);
      await store.carregar();
      await esvaziarFila();
      expect(store.resumo.value.ocupacaoPercentual, isNull);
      await store.selecionarQuadra(1);
      expect(store.resumo.value.ocupacaoPercentual, 20); // 2 ativas / 10
    });

    test('recalcula depois do cancelamento pelo dono', () async {
      await store.carregar();
      await esvaziarFila();
      expect(store.resumo.value.agendadas, 2);

      final cancelada = Reserva(
        id: 1,
        quadraId: 1,
        quadraNome: 'Quadra 1',
        inicio: br(2026, 11, 9, 19),
        fim: br(2026, 11, 9, 20),
        status: StatusReserva.cancelada,
        valor: 90,
        canceladoPor: CanceladoPor.dono,
        motivoCancelamento: 'Manutenção emergencial da quadra',
      );
      store.aplicarCancelamento(cancelada);

      final atualizada = store.reservas.value.firstWhere((r) => r.id == 1);
      expect(atualizada.status, StatusReserva.cancelada);
      expect(atualizada.canceladoPor, CanceladoPor.dono);
      expect(atualizada.clienteNome, 'Cliente 1', reason: 'contato preservado');
      expect(store.resumo.value.agendadas, 1);
      expect(store.resumo.value.previsao, 180);
      expect(store.resumo.value.ocupacaoPercentual, 13); // round(200 / 15)
    });
  });
}
