import 'dart:async';

// `fake_async` vem com o flutter_test (dependência transitiva).
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' show left, right;
import 'package:so_mais_uma/src/features/reservas/presentation/minhas_reservas/abas_reservas.dart';
import 'package:so_mais_uma/src/features/reservas/presentation/minhas_reservas/minhas_reservas_store.dart';
import 'package:so_mais_uma/src/shared/domain/domain.dart';
import 'package:so_mais_uma/src/utils/async_state.dart';
import 'package:so_mais_uma/src/utils/failure.dart';

import 'fakes.dart';

void main() {
  late FakeReservaRepository reservas;
  late FakeQuadraRepository quadras;
  late RelogioFixo relogio;
  late MinhasReservasStore store;

  final amanha = reservaFake(
    id: 1,
    inicio: agoraBase.add(const Duration(days: 1)),
  );
  final ontem = reservaFake(
    id: 2,
    inicio: agoraBase.subtract(const Duration(days: 1)),
  );
  final expirada = reservaFake(
    id: 3,
    quadraId: 99,
    inicio: agoraBase.add(const Duration(days: 2)),
    status: StatusReserva.expirada,
  );

  setUp(() {
    reservas = FakeReservaRepository();
    quadras = FakeQuadraRepository();
    relogio = RelogioFixo(agoraBase);
    store = MinhasReservasStore(reservas, quadras, relogio);
  });

  tearDown(() => store.dispose());

  test('carrega GET /reservas sem situacao e divide as abas', () async {
    reservas.onListar = () => ok([ontem, expirada, amanha]);

    await store.carregar();

    expect(reservas.situacoesListadas, [null]);
    expect(store.estado.value, isA<RequestSuccess<List<Reserva>>>());
    expect(store.abas.value.proximas, [amanha]);
    expect(store.abas.value.historico.map((r) => r.id), [3, 2]);
    expect(store.aba.value, AbaReservas.proximas);
  });

  test('mostra carregando e depois o erro quando ainda não há dados', () async {
    final completer = Completer<Resposta<List<Reserva>>>();
    reservas.onListar = () => completer.future;

    final carga = store.carregar();
    expect(store.estado.value, isA<RequestLoading<List<Reserva>>>());

    completer.complete(left(const NetworkFailure('sem rede')));
    await carga;

    final estado = store.estado.value;
    expect(estado, isA<RequestFailure<List<Reserva>>>());
    expect((estado as RequestFailure).failure, isA<NetworkFailure>());
  });

  test('atualizar com falha mantém a lista e emite aviso', () async {
    reservas.onListar = () => ok([amanha]);
    await store.carregar();

    reservas.onListar = () => falha(const NetworkFailure('sem rede'));
    final atualizacao = store.carregar();
    expect(store.atualizando.value, isTrue);
    expect(store.estado.value, isA<RequestSuccess<List<Reserva>>>());
    await atualizacao;

    expect(store.atualizando.value, isFalse);
    expect(store.estado.value, isA<RequestSuccess<List<Reserva>>>());
    expect(store.aviso.value?.mensagem, 'sem rede');
    store.consumirAviso();
    expect(store.aviso.value, isNull);
  });

  test('join best-effort com as quadras: falha não afeta a lista', () async {
    reservas.onListar = () => ok([amanha]);
    quadras.onListar = () => falha(const NetworkFailure('sem rede'));

    await store.carregar();
    await Future<void>.delayed(Duration.zero);

    expect(store.estado.value, isA<RequestSuccess<List<Reserva>>>());
    expect(store.quadras.value, isEmpty);
  });

  test('join best-effort com as quadras: indexa por id', () async {
    reservas.onListar = () => ok([amanha, expirada]);
    quadras.onListar = () => ok([quadraFake(id: 10)]);

    await store.carregar();
    await Future<void>.delayed(Duration.zero);

    expect(store.quadras.value.keys, [10]);
    // A quadra 99 (fora do catálogo) fica sem dados: placeholder na tela.
    expect(store.quadras.value[99], isNull);
  });

  test('não lista as quadras de novo quando todas já são conhecidas', () async {
    reservas.onListar = () => ok([amanha]);
    quadras.onListar = () => ok([quadraFake(id: 10)]);

    await store.carregar();
    await Future<void>.delayed(Duration.zero);
    await store.carregar();
    await Future<void>.delayed(Duration.zero);

    expect(quadras.listagens, 1);
  });

  test('troca de aba e "Ver todos" levam ao histórico', () {
    store.selecionarAba(AbaReservas.historico);
    expect(store.aba.value, AbaReservas.historico);
    store.selecionarAba(AbaReservas.proximas);
    store.verTodoHistorico();
    expect(store.aba.value, AbaReservas.historico);
  });

  test('a reserva que expirou no backend sai de Próximas ao recarregar',
      () async {
    final pendente = reservaFake(
      id: 5,
      inicio: agoraBase.add(const Duration(days: 1)),
      status: StatusReserva.pendentePagamento,
      expiraEm: agoraBase.add(const Duration(minutes: 5)),
    );
    reservas.onListar = () => ok([pendente]);
    await store.carregar();
    expect(store.abas.value.proximas, [pendente]);

    final expirou = reservaFake(
      id: 5,
      inicio: pendente.inicio,
      status: StatusReserva.expirada,
    );
    reservas.onListar = () => ok([expirou]);
    await store.carregar();

    expect(store.abas.value.proximas, isEmpty);
    expect(store.abas.value.historico, [expirou]);
  });

  test('resposta que chega depois do dispose é ignorada', () async {
    final completer = Completer<Resposta<List<Reserva>>>();
    reservas.onListar = () => completer.future;

    final carga = store.carregar();
    store.dispose();
    completer.complete(right([amanha]));

    await expectLater(carga, completes);
  });

  test('contador por segundo só com pendente; "Concluída" vira no minuto', () {
    fakeAsync((fake) {
      store.dispose();
      final relogioFake = RelogioFixo(agoraBase);
      store = MinhasReservasStore(reservas, quadras, relogioFake);
      final pendente = reservaFake(
        id: 9,
        inicio: agoraBase.add(const Duration(hours: 3)),
        status: StatusReserva.pendentePagamento,
        expiraEm: agoraBase.add(const Duration(minutes: 10)),
      );
      // Termina daqui a 30 s: deve ir para o histórico como "Concluída".
      final terminando = reservaFake(
        id: 8,
        inicio: agoraBase.subtract(const Duration(minutes: 59, seconds: 30)),
      );
      reservas.onListar = () => ok([pendente, terminando]);
      store.carregar();
      fake.flushMicrotasks();
      expect(store.abas.value.proximas.length, 2);

      relogioFake.valor = agoraBase.add(const Duration(seconds: 1));
      fake.elapse(const Duration(seconds: 1));
      expect(store.agora.value, relogioFake.valor);

      relogioFake.valor = agoraBase.add(const Duration(minutes: 1));
      fake.elapse(const Duration(minutes: 1));
      expect(store.abas.value.proximas, [pendente]);
      expect(
        SituacaoReserva.de(
            store.abas.value.historico.single, store.agora.value),
        SituacaoReserva.concluida,
      );

      // Sem pendente: "agora" anda a cada 30 s.
      reservas.onListar = () => ok([terminando]);
      store.carregar();
      fake.flushMicrotasks();
      final antes = store.agora.value;
      relogioFake.valor = antes.add(const Duration(seconds: 5));
      fake.elapse(const Duration(seconds: 5));
      expect(store.agora.value, antes);
      relogioFake.valor = antes.add(const Duration(seconds: 30));
      fake.elapse(const Duration(seconds: 25));
      expect(store.agora.value, relogioFake.valor);

      store.dispose();
      expect(fake.periodicTimerCount, 0);
    });
  });
}
