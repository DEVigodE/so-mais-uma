import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signals/signals_flutter.dart';
import 'package:so_mais_uma/src/features/reservas/presentation/minhas_reservas/abas_reservas.dart';
import 'package:so_mais_uma/src/features/reservas/presentation/minhas_reservas/minhas_reservas_view.dart';
import 'package:so_mais_uma/src/shared/domain/domain.dart';
import 'package:so_mais_uma/src/utils/async_state.dart';
import 'package:so_mais_uma/src/utils/failure.dart';

import 'fakes.dart';
import 'montar_view.dart';

void main() {
  final agora = signal(agoraBase);

  final pendente = reservaFake(
    id: 1,
    inicio: agoraBase.add(const Duration(hours: 4)),
    status: StatusReserva.pendentePagamento,
    expiraEm: agoraBase.add(const Duration(minutes: 10, seconds: 29)),
  );
  final confirmada = reservaFake(
    id: 2,
    quadraNome: 'Complexo Beach & Tennis',
    inicio: agoraBase.add(const Duration(days: 2)),
  );
  final concluida = reservaFake(
    id: 3,
    inicio: agoraBase.subtract(const Duration(days: 3)),
  );
  final todas = [pendente, confirmada, concluida];

  Widget view({
    RequestState<List<Reserva>>? estado,
    AbaReservas aba = AbaReservas.proximas,
    List<Reserva>? reservas,
    Map<int, Quadra> quadras = const {},
    void Function(Reserva)? onPagar,
    VoidCallback? onVerTodos,
  }) {
    final lista = reservas ?? todas;
    return MinhasReservasView(
      estado: estado ?? RequestSuccess(lista),
      aba: aba,
      abas: separarAbas(lista, agoraBase),
      quadras: quadras,
      agora: agora,
      onAtualizar: () async {},
      onTentarNovamente: () {},
      onSelecionarAba: (_) {},
      onVerTodoHistorico: onVerTodos ?? () {},
      onPagar: onPagar ?? (_) {},
      onDetalhes: (_) {},
      onComoChegar: (_) {},
      onEncontrarQuadras: () {},
    );
  }

  testWidgets('próximas: cards pendente e confirmado, histórico recente',
      (tester) async {
    final semantica = tester.ensureSemantics();
    Reserva? paga;
    await montarView(
      tester,
      view(quadras: {10: quadraFake()}, onPagar: (r) => paga = r),
    );

    expect(find.text('reservas.minhas.aguardando_pagamento'), findsOneWidget);
    expect(find.text('10:29'), findsOneWidget);
    expect(find.text('reservas.minhas.pago_via_pix'), findsOneWidget);
    await tester.tap(find.text('reservas.minhas.pagar_agora'));
    expect(paga, pendente);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    final lista = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('reservas.minhas.como_chegar'),
      200,
      scrollable: lista,
    );
    expect(find.text('reservas.minhas.como_chegar'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('status_reserva.CONCLUIDA'),
      200,
      scrollable: lista,
    );
    expect(find.text('reservas.minhas.historico_recente'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('reservas.minhas.nova_partida_texto'),
      200,
      scrollable: lista,
    );
    expect(tester.takeException(), isNull);
    semantica.dispose();
  });

  testWidgets('contador zerado mostra "Expirado" e desabilita o pagamento',
      (tester) async {
    Reserva? paga;
    await montarView(tester, view(onPagar: (r) => paga = r));
    agora.value = agoraBase.add(const Duration(minutes: 11));
    await tester.pump();

    expect(find.text('reservas.minhas.expirado'), findsOneWidget);
    await tester.tap(find.text('reservas.minhas.pagar_agora'));
    expect(paga, isNull);
    agora.value = agoraBase;
  });

  testWidgets('histórico em formato compacto', (tester) async {
    await montarView(tester, view(aba: AbaReservas.historico));
    expect(find.text('status_reserva.CONCLUIDA'), findsOneWidget);
    expect(find.text('reservas.minhas.pagar_agora'), findsNothing);
  });

  testWidgets('estados vazios por aba', (tester) async {
    await montarView(tester, view(reservas: const []));
    expect(find.text('reservas.minhas.vazio_proximas'), findsOneWidget);
    expect(find.text('reservas.minhas.historico_recente'), findsNothing);

    await montarView(
      tester,
      view(reservas: const [], aba: AbaReservas.historico),
    );
    expect(find.text('reservas.minhas.vazio_historico'), findsOneWidget);
  });

  testWidgets('carregando e erro', (tester) async {
    await montarView(tester, view(estado: const RequestLoading()));
    expect(find.text('reservas.minhas.subtitulo'), findsOneWidget);

    await montarView(
      tester,
      view(estado: const RequestFailure(NetworkFailure('Sem conexão'))),
    );
    expect(find.text('reservas.minhas.erro_titulo'), findsOneWidget);
    expect(find.text('comum.tentar_novamente'), findsOneWidget);
  });

  testWidgets('tema escuro sem exceções', (tester) async {
    await montarView(tester, view(quadras: {10: quadraFake()}), escuro: true);
    expect(tester.takeException(), isNull);
  });
}
