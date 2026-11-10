import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:so_mais_uma/src/features/reservas/presentation/cancelamento_dono/cancelamento_dono_store.dart';
import 'package:so_mais_uma/src/features/reservas/presentation/cancelamento_dono/cancelamento_dono_view.dart';
import 'package:so_mais_uma/src/features/reservas/presentation/reservas_quadra/reservas_quadra_view.dart';
import 'package:so_mais_uma/src/features/reservas/presentation/reservas_quadra/resumo_do_dia.dart';
import 'package:so_mais_uma/src/shared/domain/brasilia.dart';
import 'package:so_mais_uma/src/shared/domain/entities/quadra.dart';
import 'package:so_mais_uma/src/shared/domain/entities/reserva.dart';
import 'package:so_mais_uma/src/shared/domain/enums.dart';
import 'package:so_mais_uma/src/theme/theme.dart';
import 'package:so_mais_uma/src/utils/async_state.dart';
import 'package:so_mais_uma/src/utils/failure.dart';

import 'traducoes_teste.dart';

/// Smoke test de layout: as views renderizam sem exceção nos estados
/// principais, com o tema do app e a largura do protótipo (390 px).
Widget app(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(body: child),
      ),
    );

DateTime br(int dia, int hora) =>
    Brasilia.instante(DateTime.utc(2026, 11, dia, hora));

Quadra quadra(int id, TipoEsporte esporte) => Quadra(
      id: id,
      nome: 'Quadra $id',
      tipoEsporte: esporte,
      precoHora: 90,
      cep: '01310100',
      logradouro: 'Rua A',
      numero: '1',
      cidade: 'São Paulo',
      uf: 'SP',
    );

Reserva reserva(
  int id,
  StatusReserva status, {
  String? telefone = '11987654321',
  String? observacao,
  CanceladoPor? canceladoPor,
}) =>
    Reserva(
      id: id,
      quadraId: 1,
      quadraNome: 'Quadra Teste Usabilidade com um nome bem comprido',
      inicio: br(9, 18 + id),
      fim: br(9, 19 + id),
      status: status,
      valor: 90,
      clienteNome: 'Maria Souza',
      clienteTelefone: telefone,
      observacao: observacao,
      expiraEm: status == StatusReserva.pendentePagamento
          ? br(9, 15).add(const Duration(minutes: 11))
          : null,
      canceladoPor: canceladoPor,
      motivoCancelamento:
          status == StatusReserva.cancelada ? 'Chuva forte' : null,
    );

void main() {
  setUpAll(prepararAmbienteDeLayout);

  final agora = br(9, 15);
  final hoje = DateTime.utc(2026, 11, 9);
  final lista = [
    reserva(1, StatusReserva.confirmada, observacao: 'Separar coletes'),
    reserva(2, StatusReserva.pendentePagamento, telefone: null),
    reserva(3, StatusReserva.cancelada, canceladoPor: CanceladoPor.cliente),
    reserva(4, StatusReserva.expirada),
  ];

  Widget view({
    RequestState<void> carga = const RequestSuccess(null),
    List<Reserva>? reservas,
    DateTime? data,
  }) =>
      ReservasQuadraView(
        carga: carga,
        cargaLista: carga,
        quadras: [
          quadra(1, TipoEsporte.futebolSociety),
          quadra(2, TipoEsporte.beachTennis),
        ],
        quadraFiltro: null,
        faixa: faixaDeDatas(hoje),
        hoje: hoje,
        dataSelecionada: data ?? hoje,
        naFaixa: dataNaFaixa(data ?? hoje, hoje),
        reservas: reservas ?? lista,
        resumo: calcularResumoDoDia(
          reservas: reservas ?? lista,
          slotsDoDia: 25,
          agora: agora,
          hoje: true,
        ),
        agora: agora,
        atualizando: false,
        podeCancelar: (r) => donoPodeCancelar(r, agora),
        onAtualizar: () async {},
        onTentarNovamente: () {},
        onSelecionarData: (_) {},
        onOutroDia: () {},
        onSelecionarQuadra: (_) {},
        onLigar: (_) {},
        onWhatsapp: (_) {},
        onCancelar: (_) {},
      );

  testWidgets('ReservasQuadra com cards de todos os status', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 2600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(view()));
    await tester.pump();
    semExcecao(tester);

    // Contato só com telefone: ligar e WhatsApp do card 1, nenhum do card 2.
    expect(find.byIcon(Icons.call_outlined), findsOneWidget);
    expect(find.byIcon(Icons.chat_outlined), findsOneWidget);
    // Cancelar só nas ativas antes do início.
    expect(find.byIcon(Icons.cancel_outlined), findsNWidgets(2));
    expect(find.text('reservas.dono.status.cancelada_CLIENTE'.tr()),
        findsOneWidget);

    // Deixa o flutter_animate (pulso do "Aguardando Pix") iniciar.
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('ReservasQuadra em "Outro dia", vazia', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 2600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(view(reservas: const [], data: DateTime.utc(2026, 10, 1))),
    );
    await tester.pump();
    semExcecao(tester);
    expect(find.text('reservas.dono.vazio'.tr()), findsOneWidget);
  });

  testWidgets('ReservasQuadra com erro e carregando', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 2600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(view(carga: const RequestFailure(NetworkFailure('Sem conexão.')))),
    );
    semExcecao(tester);
    expect(find.text('Sem conexão.'), findsOneWidget);
    expect(find.text('comum.tentar_novamente'.tr()), findsOneWidget);

    await tester.pumpWidget(app(view(carga: const RequestLoading())));
    semExcecao(tester);
  });

  testWidgets('Sheet de cancelamento do dono com motivo livre', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 2600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = TextEditingController(text: 'ok');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      app(
        CancelamentoDonoView(
          reserva: lista.first,
          motivo: MotivoCancelamentoDono.outro,
          mostrarAvisoEstorno: true,
          motivoLivre: true,
          textoLivreController: controller,
          comprimentoTextoLivre: 2,
          enviando: false,
          podeConfirmar: false,
          erroMotivo: 'reservas.cancelamento_dono.erro_minimo'.tr(),
          onMotivo: (_) {},
          onTextoLivre: (_) {},
          onVoltar: () {},
          onConfirmar: () {},
        ),
      ),
    );
    await tester.pump();
    semExcecao(tester);
    expect(
      find.textContaining('reservas.cancelamento_dono.aviso_estorno'.tr()),
      findsOneWidget,
    );
    expect(find.text('reservas.cancelamento_dono.motivos.outro'.tr()),
        findsOneWidget);
    expect(
      find.text('reservas.cancelamento_dono.erro_minimo'.tr()),
      findsOneWidget,
    );
  });
}

/// Falha com o diagnóstico completo (widget que transbordou e sua origem).
void semExcecao(WidgetTester tester) {
  final erro = tester.takeException();
  if (erro != null) debugPrint('$erro');
  expect(erro, isNull);
}
