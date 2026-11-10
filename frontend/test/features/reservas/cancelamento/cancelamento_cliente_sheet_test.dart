import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:so_mais_uma/src/config/injector.dart';
import 'package:so_mais_uma/src/features/reservas/presentation/cancelamento/cancelamento_cliente_sheet.dart';
import 'package:so_mais_uma/src/features/reservas/presentation/cancelamento/cancelamento_cliente_store.dart';
import 'package:so_mais_uma/src/shared/domain/domain.dart';

import '../minhas_reservas/fakes.dart';
import '../minhas_reservas/montar_view.dart';

final _reservas = FakeReservaRepository();

/// Registra o store do sheet com um repositório falso no injector global.
void _registrar() {
  if (injector.isAdded<CancelamentoClienteStore>()) return;
  injector
    ..uncommit()
    ..addInstance<ReservaRepository>(_reservas)
    ..addInstance<Relogio>(RelogioFixo(agoraBase))
    ..add<CancelamentoClienteStore>(CancelamentoClienteStore.new)
    ..commit();
}

void main() {
  final confirmada = reservaFake(
    id: 42,
    inicio: agoraBase.add(const Duration(days: 1)),
  );

  /// Botão que abre o sheet e guarda o resultado.
  Widget abridor(void Function(bool) aoFechar) => Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async => aoFechar(
                  await mostrarCancelamentoCliente(context, confirmada)),
              child: const Text('abrir'),
            ),
          ),
        ),
      );

  setUp(() {
    _registrar();
    _reservas.cancelamentos.clear();
  });

  testWidgets('foco inicial em "Manter reserva"; manter devolve false',
      (tester) async {
    bool? resultado;
    await montarView(tester, abridor((r) => resultado = r));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    final manter = find.ancestor(
      of: find.text('reservas.cancelamento_cliente.manter'),
      matching: find.byType(FilledButton),
    );
    final foco = tester.widget<FilledButton>(manter).focusNode!;
    expect(foco.hasFocus, isTrue);

    await tester.tap(find.text('reservas.cancelamento_cliente.manter'));
    await tester.pumpAndSettle();
    expect(resultado, isFalse);
    expect(_reservas.cancelamentos, isEmpty);
  });

  testWidgets('motivo curto mostra o aviso e mantém o botão desabilitado',
      (tester) async {
    await montarView(tester, abridor((_) {}));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Ops');
    await tester.pump();
    expect(find.text('reservas.cancelamento_cliente.motivo_curto'),
        findsOneWidget);

    await tester.tap(find.text('reservas.cancelamento_cliente.confirmar'));
    await tester.pump();
    expect(_reservas.cancelamentos, isEmpty);
  });

  testWidgets('chip preenche o motivo e confirmar cancela (devolve true)',
      (tester) async {
    _reservas.onCancelar = (id, motivo) => ok(
          reservaFake(
            id: id,
            inicio: confirmada.inicio,
            status: StatusReserva.cancelada,
          ),
        );
    bool? resultado;
    await montarView(tester, abridor((r) => resultado = r));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    final chip = find.text('reservas.cancelamento_cliente.motivo_clima');
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pump();
    final campo = tester.widget<TextField>(find.byType(TextField));
    expect(
        campo.controller!.text, 'reservas.cancelamento_cliente.motivo_clima');
    expect(campo.focusNode!.hasFocus, isTrue);

    await tester.ensureVisible(
      find.text('reservas.cancelamento_cliente.confirmar'),
    );
    await tester.tap(find.text('reservas.cancelamento_cliente.confirmar'));
    await tester.pumpAndSettle();

    expect(_reservas.cancelamentos, [
      (42, 'reservas.cancelamento_cliente.motivo_clima'),
    ]);
    expect(resultado, isTrue);
    expect(find.text('reservas.cancelamento_cliente.sucesso'), findsOneWidget);
  });
}
