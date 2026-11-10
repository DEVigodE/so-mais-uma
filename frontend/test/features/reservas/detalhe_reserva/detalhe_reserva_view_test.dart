import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:so_mais_uma/src/features/reservas/presentation/cancelamento/prazo_cancelamento.dart';
import 'package:so_mais_uma/src/features/reservas/presentation/detalhe_reserva/detalhe_reserva_store.dart';
import 'package:so_mais_uma/src/features/reservas/presentation/detalhe_reserva/detalhe_reserva_view.dart';
import 'package:so_mais_uma/src/shared/domain/domain.dart';
import 'package:so_mais_uma/src/utils/async_state.dart';
import 'package:so_mais_uma/src/utils/failure.dart';

import '../minhas_reservas/fakes.dart';
import '../minhas_reservas/montar_view.dart';

void main() {
  final controller = TextEditingController();
  tearDownAll(controller.dispose);

  Widget view(
    RequestState<Reserva> estado, {
    bool editando = false,
    bool salva = false,
    Quadra? quadra,
    VoidCallback? onCancelar,
    VoidCallback? onPagar,
  }) {
    final reserva = estado is RequestSuccess<Reserva> ? estado.data : null;
    final prazo =
        reserva == null ? null : calcularPrazoCancelamento(reserva, agoraBase);
    return DetalheReservaView(
      estado: estado,
      quadra: quadra,
      agora: agoraBase,
      prazo: prazo,
      podeEditar: reserva != null &&
          reserva.status.ativa &&
          reserva.fim.isAfter(agoraBase),
      editando: editando,
      salvando: false,
      observacaoSalva: salva,
      copiado: null,
      usuario: usuarioTeste,
      observacaoController: controller,
      onVoltarErro: () {},
      onTentarNovamente: () {},
      onCopiarCodigo: () {},
      onCopiarTxid: () {},
      onComoChegar: () {},
      onEditar: () {},
      onCancelarEdicao: () {},
      onSalvar: () {},
      onCancelarReserva: onCancelar ?? () {},
      onPagar: onPagar ?? () {},
      onVoltarMinhasReservas: () {},
      onBuscarQuadras: () {},
    );
  }

  Future<void> rolarAte(WidgetTester tester, String texto) =>
      tester.scrollUntilVisible(
        find.text(texto),
        200,
        scrollable: find.byType(Scrollable).first,
      );

  final confirmada = reservaFake(
    id: 42,
    inicio: agoraBase.add(const Duration(hours: 48)),
    observacao: 'Levar coletes',
    pagamento: pagamentoFake(
      status: StatusPagamento.pago,
      pagoEm: agoraBase.subtract(const Duration(hours: 1)),
    ),
  );

  testWidgets('confirmada: pagamento, observação e política calculada',
      (tester) async {
    final semantica = tester.ensureSemantics();
    var cancelou = false;
    await montarView(
      tester,
      view(
        RequestSuccess(confirmada),
        quadra: quadraFake(),
        onCancelar: () => cancelou = true,
      ),
    );

    expect(find.text('#RES-42'), findsOneWidget);
    expect(find.text('status_reserva.CONFIRMADA'), findsOneWidget);
    await rolarAte(tester, 'reservas.detalhe.pagamento_liquidado');
    await rolarAte(tester, 'reservas.detalhe.observacao_entre_aspas');
    expect(find.text('reservas.detalhe.editar'), findsOneWidget);
    await rolarAte(tester, 'reservas.detalhe.politica_titulo');
    await rolarAte(tester, 'reservas.detalhe.cancelar_reserva');
    // Elementos omitidos (D1): PDF, contatar arena.
    expect(find.textContaining('PDF'), findsNothing);
    await tester.tap(find.text('reservas.detalhe.cancelar_reserva'));
    expect(cancelou, isTrue);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    expect(tester.takeException(), isNull);
    semantica.dispose();
  });

  testWidgets('menos de 2 h: botão Cancelar visível e desabilitado',
      (tester) async {
    var cancelou = false;
    final logo = reservaFake(
      id: 1,
      inicio: agoraBase.add(const Duration(hours: 1)),
    );
    await montarView(
      tester,
      view(RequestSuccess(logo), onCancelar: () => cancelou = true),
    );
    await rolarAte(tester, 'reservas.detalhe.cancelar_reserva');
    await tester.tap(find.text('reservas.detalhe.cancelar_reserva'));
    expect(cancelou, isFalse);
  });

  testWidgets('pendente: "Pagar agora (Pix)" e edição da observação',
      (tester) async {
    var pagou = false;
    final pendente = reservaFake(
      id: 5,
      inicio: agoraBase.add(const Duration(days: 1)),
      status: StatusReserva.pendentePagamento,
      expiraEm: agoraBase.add(const Duration(minutes: 12)),
      pagamento:
          pagamentoFake(expiraEm: agoraBase.add(const Duration(minutes: 12))),
    );
    await montarView(
      tester,
      view(
        RequestSuccess(pendente),
        editando: true,
        salva: false,
        onPagar: () => pagou = true,
      ),
    );
    await rolarAte(tester, 'reservas.detalhe.salvar_alteracao');
    await rolarAte(tester, 'reservas.detalhe.pagar_agora');
    await tester.tap(find.text('reservas.detalhe.pagar_agora'));
    expect(pagou, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expirada: somente leitura, sem política nem cancelar',
      (tester) async {
    final expirada = reservaFake(
      id: 6,
      inicio: agoraBase.add(const Duration(days: 1)),
      status: StatusReserva.expirada,
      pagamento: pagamentoFake(status: StatusPagamento.expirado),
    );
    await montarView(tester, view(RequestSuccess(expirada)));
    await rolarAte(tester, 'reservas.detalhe.voltar_minhas_reservas');
    expect(find.text('reservas.detalhe.editar'), findsNothing);
    expect(find.text('reservas.detalhe.politica_titulo'), findsNothing);
    expect(find.text('reservas.detalhe.cancelar_reserva'), findsNothing);
    expect(find.text('reservas.detalhe.somente_leitura'), findsOneWidget);
  });

  testWidgets('cancelada depois de paga: estorno pendente e titular',
      (tester) async {
    final cancelada = reservaFake(
      id: 7,
      inicio: agoraBase.add(const Duration(days: 1)),
      status: StatusReserva.cancelada,
      canceladoPor: CanceladoPor.dono,
      motivoCancelamento: 'Manutenção na quadra',
      canceladoEm: agoraBase,
      pagamento: pagamentoFake(
        status: StatusPagamento.pago,
        pagoEm: agoraBase.subtract(const Duration(hours: 2)),
      ),
    );
    await montarView(
        tester, view(RequestSuccess(cancelada), quadra: quadraFake()));
    expect(find.text('reservas.detalhe.cancelada_por_dono'), findsOneWidget);
    await rolarAte(tester, 'reservas.detalhe.estorno_titulo');
    await rolarAte(tester, 'reservas.detalhe.estorno_pendente');
    await rolarAte(tester, 'Lucas Silva');
    await rolarAte(tester, 'reservas.detalhe.buscar_outra_quadra');
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelada sem pagamento: sem estorno; sistema com motivo fixo',
      (tester) async {
    final cancelada = reservaFake(
      id: 8,
      inicio: agoraBase.add(const Duration(days: 1)),
      status: StatusReserva.cancelada,
      canceladoPor: CanceladoPor.sistema,
      motivoCancelamento: 'Falha ao gerar a cobrança Pix',
      pagamento: pagamentoFake(status: StatusPagamento.cancelado),
    );
    await montarView(tester, view(RequestSuccess(cancelada)));
    expect(find.text('reservas.detalhe.cancelada_por_sistema'), findsOneWidget);
    expect(find.text('Falha ao gerar a cobrança Pix'), findsNothing);
    await rolarAte(tester, 'reservas.detalhe.pagamento_cancelado');
    expect(find.text('reservas.detalhe.estorno_titulo'), findsNothing);
    expect(find.text('reservas.detalhe.estorno_pendente'), findsNothing);
  });

  testWidgets('403 e 404 mostram a caixa de erro com Voltar', (tester) async {
    await montarView(
      tester,
      view(const RequestFailure(
          ApiFailure(status: 403, codigo: 'ACESSO_NEGADO'))),
    );
    expect(find.text('reservas.detalhe.erro_sem_permissao'), findsOneWidget);
    expect(find.text('comum.voltar'), findsOneWidget);

    await montarView(
      tester,
      view(const RequestFailure(
          ApiFailure(status: 404, codigo: 'NAO_ENCONTRADO'))),
    );
    expect(find.text('reservas.detalhe.erro_nao_encontrada'), findsOneWidget);
  });

  testWidgets('tema escuro e carregando sem exceções', (tester) async {
    await montarView(tester, view(const RequestLoading()));
    await montarView(
      tester,
      view(RequestSuccess(confirmada), quadra: quadraFake()),
      escuro: true,
    );
    expect(tester.takeException(), isNull);
  });

  test('ItemCopiado cobre código e TxID', () {
    expect(ItemCopiado.values, [ItemCopiado.codigo, ItemCopiado.txid]);
  });
}
