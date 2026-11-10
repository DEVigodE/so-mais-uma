import 'package:auto_injector/auto_injector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:so_mais_uma/src/config/injector.dart';
import 'package:so_mais_uma/src/features/pagamento/presentation/pagamento/pagamento_store.dart';
import 'package:so_mais_uma/src/features/reservas/presentation/cancelamento/cancelamento_cliente_store.dart';
import 'package:so_mais_uma/src/features/reservas/presentation/detalhe_reserva/detalhe_reserva_store.dart';
import 'package:so_mais_uma/src/features/reservas/presentation/minhas_reservas/minhas_reservas_store.dart';
import 'package:so_mais_uma/src/shared/domain/domain.dart';
import 'package:so_mais_uma/src/shared/session/session_store.dart';

import '../../pagamento/pagamento/fakes_pagamento.dart' show FakeQuadras;
import 'fakes.dart';

class _FakePagamentos implements PagamentoRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('registrarStoresReservasCliente resolve os stores por tipo', () {
    final i = AutoInjector(tag: 'teste-reservas-cliente')
      ..addInstance<ReservaRepository>(FakeReservaRepository())
      ..addInstance<QuadraRepository>(FakeQuadras())
      ..addInstance<PagamentoRepository>(_FakePagamentos())
      ..addInstance<Relogio>(RelogioFixo(agoraBase))
      ..addInstance<SessionStore>(
        SessionStore(repository: FakeAuthRepository(null)),
      );
    registrarStoresReservasCliente(i);
    i.commit();

    final minhas = i.get<MinhasReservasStore>();
    final detalhe = i.get<DetalheReservaStore>();
    final cancelamento = i.get<CancelamentoClienteStore>();
    final pagamento = i.get<PagamentoStore>();

    // Fábrica: uma instância por abertura de tela.
    final outra = i.get<MinhasReservasStore>();
    expect(identical(minhas, outra), isFalse);

    for (final descartar in [
      minhas.dispose,
      outra.dispose,
      detalhe.dispose,
      cancelamento.dispose,
      pagamento.dispose,
    ]) {
      descartar();
    }
  });
}
