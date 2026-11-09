import 'package:flutter_test/flutter_test.dart';
import 'package:so_mais_uma/src/features/reservas/presentation/grade/faixa_datas.dart';
import 'package:so_mais_uma/src/features/reservas/presentation/grade/grade_slots_store.dart';
import 'package:so_mais_uma/src/features/reservas/presentation/grade/grade_slots_view.dart';
import 'package:so_mais_uma/src/imports/imports.dart';

final _hoje = DateTime.utc(2026, 10, 10);
final _datas = gerarFaixaDatas(DateTime.utc(2026, 10, 10, 20, 30));

Slot _slot(int hora, StatusSlot status) {
  final inicio =
      Brasilia.instante(DateTime.utc(_hoje.year, _hoje.month, _hoje.day, hora));
  return Slot(
    inicio: inicio,
    fim: inicio.add(const Duration(hours: 1)),
    status: status,
    valor: 90,
  );
}

final _slots = [
  _slot(16, StatusSlot.passado),
  _slot(17, StatusSlot.passado),
  _slot(18, StatusSlot.ocupado),
  _slot(19, StatusSlot.livre),
  _slot(20, StatusSlot.livre),
];

/// Superfície larga e `designSize` igual a ela: sem easy_localization
/// inicializado, os textos são as chaves, longas na fonte de teste.
Future<void> _montar(WidgetTester tester, Widget corpo,
    {ThemeData? tema}) async {
  tester.view.physicalSize = const Size(2400, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(800, 844),
      minTextAdapt: true,
      builder: (context, _) => MaterialApp(
        theme: tema ?? buildLightTheme(),
        home: Scaffold(body: corpo),
      ),
    ),
  );
  await tester.pump();
}

Widget _tela({
  RequestState<List<Slot>>? grade,
  List<Slot>? visiveis,
  Slot? selecionado,
  bool semLivre = false,
  ProximaDataLivre proxima = const ProximaNaoAplicavel(),
  void Function(Slot)? onSlot,
  void Function(DataFaixa)? onData,
  VoidCallback? onContinuar,
}) =>
    Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              GradeSlotsView(
                datas: _datas,
                dataSelecionada: _datas.first,
                grade: grade ?? RequestSuccess(_slots),
                visiveis: visiveis ?? _slots,
                selecionado: selecionado,
                semLivre: semLivre,
                proxima: proxima,
                onData: onData ?? (_) {},
                onSlot: onSlot ?? (_) {},
                onTentarNovamente: () {},
              ),
            ],
          ),
        ),
        BarraHorarioSelecionado(
          slot: selecionado,
          data: _datas.first,
          onContinuar: onContinuar ?? () {},
        ),
      ],
    );

void main() {
  testWidgets('grade com os quatro estados e toque só no livre',
      (tester) async {
    final tocados = <Slot>[];
    await _montar(tester, _tela(onSlot: tocados.add));

    expect(find.text('16:00 - 17:00'), findsOneWidget);
    expect(find.text('reservas.grade.reservado'), findsOneWidget);
    expect(find.text('reservas.grade.disponivel'), findsNWidgets(2));
    expect(find.text(r'R$ 90'), findsNWidgets(2));
    expect(find.text('reservas.grade.horario_selecionado'.toUpperCase()),
        findsNothing);

    await tester.tap(find.text('18:00 - 19:00'));
    await tester.tap(find.text('16:00 - 17:00'));
    await tester.tap(find.text('19:00 - 20:00'));
    expect(tocados, [_slots[3]]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('slot selecionado mostra a barra com Continuar', (tester) async {
    var continuou = false;
    await _montar(
      tester,
      _tela(selecionado: _slots[3], onContinuar: () => continuou = true),
    );
    expect(find.text(r'R$ 90,00'), findsOneWidget);
    expect(find.text('reservas.grade.barra_dia'), findsOneWidget);
    expect(find.text('reservas.grade.total'), findsOneWidget);
    await tester.tap(find.text('comum.continuar'));
    expect(continuou, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('faixa de datas: 15 datas e troca de data', (tester) async {
    DataFaixa? escolhida;
    await _montar(tester, _tela(onData: (d) => escolhida = d));
    expect(find.text('comum.hoje'.toUpperCase()), findsOneWidget);
    expect(find.text('comum.amanha'.toUpperCase()), findsOneWidget);
    await tester.tap(find.text('11'));
    expect(escolhida, _datas[1]);
  });

  testWidgets('sem horário livre oferece a próxima data', (tester) async {
    DataFaixa? escolhida;
    await _montar(
      tester,
      _tela(
        visiveis: [_slots[0], _slots[2]],
        semLivre: true,
        proxima: ProximaEncontrada(_datas[2]),
        onData: (d) => escolhida = d,
      ),
    );
    expect(find.text('reservas.grade.sem_livre'), findsOneWidget);
    await tester.tap(find.text('reservas.grade.ver_data'));
    expect(escolhida, _datas[2]);
  });

  testWidgets('carregando, dia fechado e sem conexão (tema escuro)',
      (tester) async {
    final escuro = buildDarkTheme();
    await _montar(
      tester,
      _tela(grade: const RequestLoading(), visiveis: const []),
      tema: escuro,
    );
    expect(tester.takeException(), isNull);

    await _montar(
      tester,
      _tela(
        grade: const RequestSuccess([]),
        visiveis: const [],
        semLivre: true,
        proxima: const ProximaBuscando(),
      ),
      tema: escuro,
    );
    expect(find.text('reservas.grade.dia_fechado'), findsOneWidget);
    expect(find.text('reservas.grade.buscando_proxima'), findsOneWidget);

    await _montar(
      tester,
      _tela(
        grade: const RequestFailure(NetworkFailure('sem rede')),
        visiveis: const [],
      ),
      tema: escuro,
    );
    expect(find.text('reservas.grade.sem_conexao'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
