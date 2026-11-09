import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' show right;
import 'package:so_mais_uma/src/features/reservas/presentation/cancelamento/cancelamento_cliente_store.dart';
import 'package:so_mais_uma/src/features/reservas/presentation/cancelamento/prazo_cancelamento.dart';
import 'package:so_mais_uma/src/shared/domain/domain.dart';
import 'package:so_mais_uma/src/utils/async_state.dart';
import 'package:so_mais_uma/src/utils/failure.dart';

import '../minhas_reservas/fakes.dart';

void main() {
  late FakeReservaRepository reservas;
  late CancelamentoClienteStore store;

  final confirmada = reservaFake(
    id: 42,
    inicio: agoraBase.add(const Duration(days: 1)),
  );
  final cancelada = reservaFake(
    id: 42,
    inicio: confirmada.inicio,
    status: StatusReserva.cancelada,
    canceladoPor: CanceladoPor.cliente,
    motivoCancelamento: 'Condições climáticas',
  );

  setUp(() {
    reservas = FakeReservaRepository();
    store = CancelamentoClienteStore(reservas, RelogioFixo(agoraBase))
      ..iniciar(confirmada);
  });

  tearDown(() => store.dispose());

  test('motivo curto mostra o aviso e não habilita o botão', () {
    store.alterarMotivo('Ops');
    expect(store.motivoCurto.value, isTrue);
    expect(store.motivoValido.value, isFalse);
    expect(store.podeConfirmar.value, isFalse);
    expect(store.tamanho.value, 3);
  });

  test('motivo vazio ou só com espaços não mostra aviso e não habilita', () {
    store.alterarMotivo('    ');
    expect(store.motivoCurto.value, isFalse);
    expect(store.podeConfirmar.value, isFalse);
  });

  test('motivo de 5 a 200 caracteres habilita o botão', () {
    store.alterarMotivo('Condições climáticas');
    expect(store.motivoCurto.value, isFalse);
    expect(store.podeConfirmar.value, isTrue);

    store.alterarMotivo('a' * 201);
    expect(store.podeConfirmar.value, isFalse);
  });

  test('confirmar com motivo inválido não chama a API', () async {
    store.alterarMotivo('Ops');
    await store.confirmar();
    expect(reservas.cancelamentos, isEmpty);
  });

  test('2xx: envia o motivo sem espaços nas pontas e fecha como cancelada',
      () async {
    reservas.onCancelar = (id, motivo) => ok(cancelada);
    store.alterarMotivo('  Condições climáticas  ');

    await store.confirmar();

    expect(reservas.cancelamentos, [(42, 'Condições climáticas')]);
    expect(store.envio.value, isA<RequestSuccess<Reserva>>());
    expect(store.resultado.value, ResultadoCancelamento.cancelada);
    expect(store.erro.value, isNull);
  });

  test('mostra "Cancelando..." e não envia duas vezes', () async {
    final completer = Completer<Resposta<Reserva>>();
    reservas.onCancelar = (id, motivo) => completer.future;
    store.alterarMotivo('Mudança de planos');

    final primeiro = store.confirmar();
    expect(store.envio.value.isLoading, isTrue);
    expect(store.podeConfirmar.value, isFalse);
    await store.confirmar();
    completer.complete(right(cancelada));
    await primeiro;

    expect(reservas.cancelamentos.length, 1);
  });

  test('422 CANCELAMENTO_FORA_DO_PRAZO mostra a regra e mantém o sheet',
      () async {
    reservas.onCancelar = (id, motivo) => falha(
          const ApiFailure(
            status: 422,
            codigo: 'REGRA_NEGOCIO',
            subcodigo: 'CANCELAMENTO_FORA_DO_PRAZO',
          ),
        );
    store.alterarMotivo('Imprevisto de equipe');

    await store.confirmar();

    expect(
      store.erro.value,
      'reservas.cancelamento_cliente.erro_fora_do_prazo',
    );
    expect(store.resultado.value, isNull);
    expect(store.envio.value, isA<RequestFailure<Reserva>>());
    expect(store.podeConfirmar.value, isTrue);
  });

  test('422 TRANSICAO_INVALIDA fecha pedindo recarga da reserva', () async {
    reservas.onCancelar = (id, motivo) => falha(
          const ApiFailure(
            status: 422,
            codigo: 'REGRA_NEGOCIO',
            subcodigo: 'TRANSICAO_INVALIDA',
          ),
        );
    store.alterarMotivo('Imprevisto de equipe');

    await store.confirmar();

    expect(store.resultado.value, ResultadoCancelamento.mudouSituacao);
    expect(
      store.erro.value,
      'reservas.cancelamento_cliente.erro_mudou_situacao',
    );
  });

  test('falha de rede mostra a mensagem e não fecha', () async {
    reservas.onCancelar =
        (id, motivo) => falha(const NetworkFailure('Sem conexão'));
    store.alterarMotivo('Problema de saúde');

    await store.confirmar();

    expect(store.erro.value, 'Sem conexão');
    expect(store.resultado.value, isNull);
    store.alterarMotivo('Problema de saúde!');
    expect(store.erro.value, isNull);
  });

  test('prazo calculado para a reserva do sheet', () {
    expect(store.prazo.value?.situacao, SituacaoPrazo.dentro);
  });

  test('resposta depois do dispose é ignorada', () async {
    final completer = Completer<Resposta<Reserva>>();
    reservas.onCancelar = (id, motivo) => completer.future;
    store.alterarMotivo('Problema de saúde');

    final envio = store.confirmar();
    store.dispose();
    completer.complete(right(cancelada));

    await expectLater(envio, completes);
  });
}
