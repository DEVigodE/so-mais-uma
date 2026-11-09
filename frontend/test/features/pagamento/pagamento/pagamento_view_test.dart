import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:signals/signals_flutter.dart';
import 'package:so_mais_uma/src/features/pagamento/presentation/pagamento/pagamento_store.dart';
import 'package:so_mais_uma/src/features/pagamento/presentation/pagamento/pagamento_view.dart';
import 'package:so_mais_uma/src/utils/failure.dart';

import '../../reservas/minhas_reservas/montar_view.dart';
import 'fakes_pagamento.dart';

void main() {
  final restante = signal(const Duration(minutes: 11, seconds: 10));
  final progresso = signal(0.744);

  Widget view(
    FasePagamento fase, {
    Failure? falha,
    StatusVerificacao status = StatusVerificacao.ok,
    VerificacaoManual manual = VerificacaoManual.ociosa,
    bool copiado = false,
    bool simulacao = false,
    VoidCallback? onCopiar,
    VoidCallback? onCancelar,
    VoidCallback? onVoltar,
  }) {
    final reserva = reservaPendente();
    return PagamentoView(
      fase: fase,
      falhaCarga: falha,
      reserva: reserva,
      pagamento: reserva.pagamento,
      quadra: null,
      restante: restante,
      progresso: progresso,
      statusVerificacao: status,
      verificacaoManual: manual,
      simulando: false,
      copiado: copiado,
      mostrarSimulacao: simulacao,
      onVoltar: onVoltar ?? () {},
      onTentarNovamente: () {},
      onCopiar: onCopiar ?? () {},
      onJaRealizei: () {},
      onSimular: () {},
      onCancelar: onCancelar ?? () {},
      onEscolherOutroHorario: () {},
    );
  }

  Future<void> rolarAte(WidgetTester tester, String texto) async {
    await tester.scrollUntilVisible(
      find.text(texto),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text(texto));
    await tester.pump();
  }

  testWidgets('aguardando: contador, QR com rótulo semântico e passos',
      (tester) async {
    final semantica = tester.ensureSemantics();
    var copiou = false;
    var cancelou = false;
    await montarView(
      tester,
      view(
        FasePagamento.aguardando,
        onCopiar: () => copiou = true,
        onCancelar: () => cancelou = true,
      ),
    );

    expect(find.text('11:10'), findsOneWidget);
    expect(find.text('#RES-7'), findsOneWidget);
    expect(find.text('pagamento.aguardando_pagamento'), findsOneWidget);
    await rolarAte(tester, 'pagamento.qr_legenda');
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.bySemanticsLabel('pagamento.qr_semantica'), findsOneWidget);
    expect(find.text('provedor_pagamento.SIMULADO'), findsOneWidget);

    await rolarAte(tester, 'pagamento.copiar_codigo');
    await tester.tap(find.text('pagamento.copiar_codigo'));
    expect(copiou, isTrue);

    await rolarAte(tester, 'pagamento.passo_4');
    await rolarAte(tester, 'pagamento.cancelar_reserva');
    // Release/sem DEV_KEY: o botão de simulação não existe na árvore.
    expect(find.text('pagamento.simular'), findsNothing);
    await tester.tap(find.text('pagamento.cancelar_reserva'));
    expect(cancelou, isTrue);

    restante.value = const Duration(minutes: 11, seconds: 9);
    await tester.pump();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    expect(tester.takeException(), isNull);
    semantica.dispose();
  });

  testWidgets('copiado, simulação em debug e status de verificação',
      (tester) async {
    await montarView(
      tester,
      view(
        FasePagamento.aguardando,
        copiado: true,
        simulacao: true,
        status: StatusVerificacao.semConexao,
        manual: VerificacaoManual.verificando,
      ),
    );
    await rolarAte(tester, 'pagamento.status_sem_conexao');
    await rolarAte(tester, 'pagamento.copiado_area_transferencia');
    expect(find.text('pagamento.codigo_copiado'), findsOneWidget);
    await rolarAte(tester, 'pagamento.verificando');
    await rolarAte(tester, 'pagamento.simular');
    expect(tester.takeException(), isNull);
    // O ícone girando (flutter_animate) deixa um timer; desmonta e esgota.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('expirado: QR desativado, sem código real nem copiar',
      (tester) async {
    await montarView(tester, view(FasePagamento.expirada));
    expect(find.text('pagamento.titulo_expirado'), findsOneWidget);
    expect(find.text('pagamento.expirado_titulo'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    await rolarAte(tester, 'pagamento.codigo_cancelado');
    expect(find.text('pagamento.copiar_codigo'), findsNothing);
    await rolarAte(tester, 'pagamento.escolher_outro_horario');
    expect(tester.takeException(), isNull);
  });

  testWidgets('erro sem rede: "Conecte-se" e tentar novamente', (tester) async {
    await montarView(
      tester,
      view(FasePagamento.erro, falha: const NetworkFailure('sem rede')),
    );
    expect(find.text('pagamento.erro_sem_conexao'), findsOneWidget);
    expect(find.text('comum.tentar_novamente'), findsOneWidget);
  });

  testWidgets('voltar da barra chama onVoltar; tema escuro sem exceções',
      (tester) async {
    var voltou = false;
    await montarView(
      tester,
      view(FasePagamento.aguardando, onVoltar: () => voltou = true),
      escuro: true,
    );
    await tester.tap(find.byTooltip('comum.voltar'));
    expect(voltou, isTrue);
    expect(tester.takeException(), isNull);
  });
}
