import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:so_mais_uma/src/config/injector.dart';
import 'package:so_mais_uma/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:so_mais_uma/src/features/horarios/domain/salvar_horarios_use_case.dart';
import 'package:so_mais_uma/src/features/horarios/presentation/horarios_quadra/horarios_quadra_view.dart';
import 'package:so_mais_uma/src/shared/domain/entities/app_user.dart';
import 'package:so_mais_uma/src/shared/domain/entities/horario_funcionamento.dart';
import 'package:so_mais_uma/src/shared/domain/entities/quadra.dart';
import 'package:so_mais_uma/src/shared/domain/enums.dart';
import 'package:so_mais_uma/src/shared/session/session_store.dart';
import 'package:so_mais_uma/src/theme/theme.dart';
import 'package:so_mais_uma/src/utils/async_state.dart';
import 'package:so_mais_uma/src/utils/failure.dart';
import 'package:so_mais_uma/src/utils/typedefs.dart';

class AuthRepositoryFalso implements AuthRepository {
  @override
  Stream<AppUser?> get onAuthStateChanged => const Stream.empty();

  @override
  FutureEither<AppUser?> checkAuthState() async => const Right(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

const quadra = Quadra(
  id: 1,
  nome: 'Arena Champions Society',
  tipoEsporte: TipoEsporte.futebolSociety,
  precoHora: 90,
  cep: '01001000',
  logradouro: 'Rua A',
  numero: '1',
  cidade: 'São Paulo',
  uf: 'SP',
);

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
    injector
      ..addLazySingleton<SessionStore>(
        () => SessionStore(repository: AuthRepositoryFalso()),
      )
      ..commit();
  });

  final dias = semanaDoServidor(const [
    HorarioFuncionamento(
      id: 11,
      diaSemana: 1,
      horaAbertura: '07:00',
      horaFechamento: '23:00',
    ),
  ]);

  Future<void> montar(
    WidgetTester tester, {
    RequestState<void> carga = const RequestSuccess(null),
    Map<int, String> erros = const {},
    bool podeCopiar = true,
    bool salvando = false,
    ThemeData? tema,
    VoidCallback? onCopiar,
    void Function(int, int)? onFechamento,
    void Function(int, bool)? onAlternar,
  }) async {
    tester.view
      ..physicalSize = const Size(360 * 3, 800 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: tema ?? buildLightTheme(),
        home: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (context, _) => HorariosQuadraView(
            carga: carga,
            quadra: quadra,
            dias: dias,
            errosDia: erros,
            salvando: salvando,
            podeSalvar: true,
            podeCopiar: podeCopiar,
            semFaixas: false,
            onVoltar: () {},
            onTentarNovamente: () {},
            onAlternarDia: onAlternar ?? (a, b) {},
            onAbertura: (a, b) {},
            onFechamento: onFechamento ?? (a, b) {},
            onCopiar: onCopiar ?? () {},
            onSalvar: () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('7 cartões; dia fechado sem seletores', (tester) async {
    await montar(tester);

    expect(find.text('Arena Champions Society'), findsOneWidget);
    expect(find.text('07:00'), findsOneWidget);
    expect(find.text('23:00'), findsOneWidget);
    expect(find.byType(Switch), findsWidgets);
    expect(find.text('horarios.fechado_neste_dia'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(find.text('horarios.salvar'), 300);
    expect(tester.takeException(), isNull);
  });

  testWidgets('seletor de fechamento vai até 23:00', (tester) async {
    int? escolhido;
    await montar(tester, onFechamento: (_, h) => escolhido = h);

    await tester.tap(find.text('23:00'));
    await tester.pumpAndSettle();
    expect(find.text('01:00'), findsWidgets);
    expect(find.text('00:00'), findsNothing);
    await tester.tap(find.text('22:00').last);
    await tester.pumpAndSettle();
    expect(escolhido, 22);
  });

  testWidgets('copiar e alternar chamam os callbacks', (tester) async {
    var copias = 0;
    (int, bool)? alternado;
    await montar(
      tester,
      onCopiar: () => copias++,
      onAlternar: (d, a) => alternado = (d, a),
    );

    await tester.tap(find.text('horarios.copiar'));
    expect(copias, 1);
    await tester.tap(find.byType(Switch).at(1));
    expect(alternado, (2, true));
  });

  testWidgets('erro no dia, salvando e tema escuro', (tester) async {
    await montar(
      tester,
      erros: const {1: 'horarios.erro_fechamento'},
      salvando: true,
      podeCopiar: false,
      tema: buildDarkTheme(),
    );
    expect(find.text('horarios.erro_fechamento'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('horarios.salvando'), 300);
    expect(tester.takeException(), isNull);
  });

  testWidgets('falha de carga mostra a caixa de erro', (tester) async {
    await montar(
      tester,
      carga: const RequestFailure(NetworkFailure('sem conexão')),
    );
    expect(find.text('horarios.erro_carga'), findsOneWidget);
    expect(find.text('comum.tentar_novamente'), findsOneWidget);
  });
}
