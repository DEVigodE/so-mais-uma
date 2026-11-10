// `fake_async` vem com o flutter_test (dependência transitiva).
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:so_mais_uma/src/features/reservas/presentation/cancelamento/prazo_cancelamento.dart';
import 'package:so_mais_uma/src/features/reservas/presentation/detalhe_reserva/detalhe_reserva_store.dart';
import 'package:so_mais_uma/src/shared/domain/domain.dart';
import 'package:so_mais_uma/src/shared/session/session_store.dart';
import 'package:so_mais_uma/src/utils/async_state.dart';
import 'package:so_mais_uma/src/utils/failure.dart';

import '../minhas_reservas/fakes.dart';

void main() {
  late FakeReservaRepository reservas;
  late FakeQuadraRepository quadras;
  late RelogioFixo relogio;
  late SessionStore sessao;
  late DetalheReservaStore store;

  const usuario =
      AppUser(id: '7', email: 'lucas@demo.com', name: 'Lucas Silva');

  final confirmada = reservaFake(
    id: 42,
    inicio: agoraBase.add(const Duration(days: 2)),
    observacao: 'Levar coletes',
    pagamento: pagamentoFake(
      status: StatusPagamento.pago,
      pagoEm: agoraBase.subtract(const Duration(hours: 1)),
    ),
  );

  DetalheReservaStore criar() =>
      DetalheReservaStore(reservas, quadras, relogio, sessao);

  Reserva? atual() => switch (store.estado.value) {
        RequestSuccess(:final data) => data,
        _ => null,
      };

  setUp(() {
    reservas = FakeReservaRepository();
    quadras = FakeQuadraRepository();
    relogio = RelogioFixo(agoraBase);
    sessao = SessionStore(repository: FakeAuthRepository(usuario));
    store = criar();
  });

  tearDown(() {
    store.dispose();
    sessao.dispose();
  });

  test('carrega GET /reservas/{id} e a quadra (best-effort)', () async {
    reservas.onDetalhar = (id) => ok(confirmada);
    quadras.onDetalhar = (id) => ok(quadraFake(id: id));

    await store.carregar(42);
    await Future<void>.delayed(Duration.zero);

    expect(reservas.detalhados, [42]);
    expect(atual(), confirmada);
    expect(store.quadra.value?.id, 10);
    expect(store.prazo.value?.situacao, SituacaoPrazo.dentro);
    expect(store.podeEditarObservacao.value, isTrue);
    expect(store.usuario.value, usuario);
  });

  test('quadra fora do catálogo não impede o detalhe', () async {
    reservas.onDetalhar = (id) => ok(confirmada);

    await store.carregar(42);
    await Future<void>.delayed(Duration.zero);

    expect(atual(), confirmada);
    expect(store.quadra.value, isNull);
  });

  test('404 e 403 viram falha (a view mostra a caixa de erro com Voltar)',
      () async {
    reservas.onDetalhar =
        (id) => falha(const ApiFailure(status: 404, codigo: 'NAO_ENCONTRADO'));
    await store.carregar(42);
    final estado = store.estado.value;
    expect(estado, isA<RequestFailure<Reserva>>());
    expect(((estado as RequestFailure).failure as ApiFailure).status, 404);
  });

  test('expirada e concluída não editam a observação nem têm política',
      () async {
    final expirada = reservaFake(
      id: 1,
      inicio: agoraBase.add(const Duration(days: 1)),
      status: StatusReserva.expirada,
    );
    reservas.onDetalhar = (id) => ok(expirada);
    await store.carregar(1);
    expect(store.podeEditarObservacao.value, isFalse);
    expect(store.prazo.value?.situacao, SituacaoPrazo.naoAplica);

    final concluida = reservaFake(
      id: 2,
      inicio: agoraBase.subtract(const Duration(hours: 3)),
    );
    reservas.onDetalhar = (id) => ok(concluida);
    await store.carregar(2);
    expect(store.podeEditarObservacao.value, isFalse);
    expect(store.prazo.value?.situacao, SituacaoPrazo.naoAplica);
  });

  test('menos de 2 h para o início: prazo encerrado', () async {
    final logo = reservaFake(
      id: 3,
      inicio: agoraBase.add(const Duration(hours: 1)),
    );
    reservas.onDetalhar = (id) => ok(logo);
    await store.carregar(3);
    expect(store.prazo.value?.situacao, SituacaoPrazo.encerrado);
    expect(store.prazo.value?.podeCancelar, isFalse);
  });

  group('observação', () {
    setUp(() async {
      reservas.onDetalhar = (id) => ok(confirmada);
      await store.carregar(42);
    });

    test('PATCH com o texto sem espaços; sucesso atualiza e avisa', () async {
      final nova = reservaFake(
        id: 42,
        inicio: confirmada.inicio,
        observacao: 'Levar 2 bolas',
        pagamento: confirmada.pagamento,
      );
      reservas.onObservacao = (id, obs) => ok(nova);

      store.iniciarEdicao();
      expect(store.editando.value, isTrue);
      await store.salvarObservacao('  Levar 2 bolas  ');

      expect(reservas.observacoes, [(42, 'Levar 2 bolas')]);
      expect(atual()?.observacao, 'Levar 2 bolas');
      expect(store.editando.value, isFalse);
      expect(store.observacaoSalva.value, isTrue);
    });

    test('texto vazio apaga a observação (envia nulo)', () async {
      reservas.onObservacao = (id, obs) => ok(
            reservaFake(id: 42, inicio: confirmada.inicio),
          );
      store.iniciarEdicao();
      await store.salvarObservacao('   ');
      expect(reservas.observacoes, [(42, null)]);
    });

    test('mantém a cobrança quando a resposta do PATCH vem sem ela', () async {
      reservas.onObservacao = (id, obs) => ok(
            reservaFake(id: 42, inicio: confirmada.inicio, observacao: obs),
          );
      store.iniciarEdicao();
      await store.salvarObservacao('Outra');
      expect(atual()?.pagamento, confirmada.pagamento);
    });

    test('422 TRANSICAO_INVALIDA avisa e recarrega a reserva', () async {
      reservas.onObservacao = (id, obs) => falha(
            const ApiFailure(
              status: 422,
              codigo: 'REGRA_NEGOCIO',
              subcodigo: 'TRANSICAO_INVALIDA',
            ),
          );
      final expirada = reservaFake(
        id: 42,
        inicio: confirmada.inicio,
        status: StatusReserva.expirada,
      );
      reservas.onDetalhar = (id) => ok(expirada);

      store.iniciarEdicao();
      await store.salvarObservacao('Nova');

      expect(store.aviso.value?.chave, 'reservas.detalhe.mudou_situacao');
      expect(store.editando.value, isFalse);
      expect(reservas.detalhados, [42, 42]);
      expect(atual()?.status, StatusReserva.expirada);
    });

    test('outra falha mantém a edição aberta e mostra a mensagem', () async {
      reservas.onObservacao =
          (id, obs) => falha(const NetworkFailure('Sem conexão'));
      store.iniciarEdicao();
      await store.salvarObservacao('Nova');
      expect(store.editando.value, isTrue);
      expect(store.aviso.value?.mensagem, 'Sem conexão');
      expect(atual()?.observacao, 'Levar coletes');
    });
  });

  test('recarga depois de cancelar mostra a reserva cancelada', () async {
    reservas.onDetalhar = (id) => ok(confirmada);
    await store.carregar(42);

    final cancelada = reservaFake(
      id: 42,
      inicio: confirmada.inicio,
      status: StatusReserva.cancelada,
      canceladoPor: CanceladoPor.cliente,
      motivoCancelamento: 'Condições climáticas',
      canceladoEm: agoraBase,
      pagamento: confirmada.pagamento,
    );
    reservas.onDetalhar = (id) => ok(cancelada);

    final recarga = store.recarregar();
    // Recarregar mantém a reserva na tela (sem voltar a "carregando").
    expect(store.estado.value, isA<RequestSuccess<Reserva>>());
    await recarga;

    expect(atual()?.status, StatusReserva.cancelada);
    expect(atual()?.estornoPendente, isTrue);
    expect(store.prazo.value?.situacao, SituacaoPrazo.naoAplica);
    expect(store.podeEditarObservacao.value, isFalse);
  });

  test('"Copiado!" por 2 s e "observação salva" por 3 s', () {
    fakeAsync((fake) {
      store.dispose();
      store = criar();
      reservas.onDetalhar = (id) => ok(confirmada);
      reservas.onObservacao = (id, obs) => ok(confirmada);
      store.carregar(42);
      fake.flushMicrotasks();

      store.marcarCopiado(ItemCopiado.txid);
      expect(store.copiado.value, ItemCopiado.txid);
      fake.elapse(const Duration(milliseconds: 1900));
      expect(store.copiado.value, ItemCopiado.txid);
      fake.elapse(const Duration(milliseconds: 200));
      expect(store.copiado.value, isNull);

      store.iniciarEdicao();
      store.salvarObservacao('Levar coletes');
      fake.flushMicrotasks();
      expect(store.observacaoSalva.value, isTrue);
      fake.elapse(const Duration(seconds: 3));
      expect(store.observacaoSalva.value, isFalse);

      store.dispose();
      expect(fake.periodicTimerCount, 0);
      expect(fake.nonPeriodicTimerCount, 0);
    });
  });
}
