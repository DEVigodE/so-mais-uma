import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:so_mais_uma/src/config/injector.dart';
import 'package:so_mais_uma/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:so_mais_uma/src/features/quadras/presentation/minhas_quadras/minhas_quadras_calculos.dart';
import 'package:so_mais_uma/src/features/quadras/presentation/minhas_quadras/minhas_quadras_store.dart';
import 'package:so_mais_uma/src/features/quadras/presentation/minhas_quadras/minhas_quadras_view.dart';
import 'package:so_mais_uma/src/shared/domain/entities/app_user.dart';
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

Quadra quadra(int id, String nome, {bool ativa = true, TipoEsporte? esporte}) =>
    Quadra(
      id: id,
      nome: nome,
      tipoEsporte: esporte ?? TipoEsporte.futebolSociety,
      precoHora: 90,
      cep: '01001000',
      logradouro: 'Rua A',
      numero: '1',
      cidade: 'São Paulo',
      uf: 'SP',
      ativa: ativa,
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

  Future<void> montar(
    WidgetTester tester,
    RequestState<List<Quadra>> estado, {
    List<QuadraComAtividade> cards = const [],
    ThemeData? tema,
    void Function(Quadra)? onDesativar,
    VoidCallback? onNovaQuadra,
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
          builder: (context, _) => MinhasQuadrasView(
            estado: estado,
            cards: cards,
            resumo: ResumoPainel(
              hoje: DateTime.utc(2026, 11, 9, 18),
              totalQuadras: estado is RequestSuccess ? cards.length : null,
              reservasHoje: 3,
            ),
            desativando: const {},
            onAtualizar: () async {},
            onTentarNovamente: () {},
            onNovaQuadra: onNovaQuadra ?? () {},
            onAbrir: (_) {},
            onEditar: (_) {},
            onHorarios: (_) {},
            onReservas: (_) {},
            onDesativar: onDesativar ?? (_) {},
            onPerfil: () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  final cards = [
    QuadraComAtividade(
      quadra(1, 'Arena Champions Society com um nome bem comprido'),
      AtividadeQuadra(
        reservasHoje: 6,
        proxima: DateTime.utc(2026, 11, 9, 21),
        ocupacao: 43,
      ),
    ),
    QuadraComAtividade(
      quadra(2, 'Beach & Tennis', esporte: TipoEsporte.beachTennis),
      const AtividadeQuadra(reservasHoje: 0, fechadaHoje: true),
    ),
    QuadraComAtividade(
      quadra(3, 'Gol de Placa', ativa: false),
      const AtividadeQuadra(reservasHoje: 0),
    ),
  ];

  testWidgets('lista com cards ativos e inativo', (tester) async {
    await montar(tester, RequestSuccess(cards.map((c) => c.quadra).toList()),
        cards: cards);

    expect(find.text('quadras.minhas.titulo'), findsOneWidget);
    expect(find.text('quadras.minhas.ocupacao'), findsOneWidget);
    expect(find.text('quadras.minhas.fechada_hoje'), findsOneWidget);
    expect(find.byTooltip('quadras.minhas.opcoes'), findsNWidgets(2));
    expect(find.text('quadras.minhas.nova_quadra'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(find.text('quadras.minhas.pausada'), 200);
    expect(find.text('quadras.minhas.horarios_suspensos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('menu de opções oferece "Desativar quadra"', (tester) async {
    Quadra? desativada;
    await montar(
      tester,
      RequestSuccess(cards.map((c) => c.quadra).toList()),
      cards: cards,
      onDesativar: (q) => desativada = q,
    );

    await tester.tap(find.byTooltip('quadras.minhas.opcoes').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('quadras.minhas.desativar'));
    await tester.pumpAndSettle();

    expect(desativada?.id, 1);
  });

  testWidgets('estado vazio com o botão de nova quadra', (tester) async {
    var novas = 0;
    await montar(tester, const RequestSuccess([]), onNovaQuadra: () => novas++);

    expect(find.text('quadras.minhas.vazio_titulo'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    await tester.tap(find.text('quadras.minhas.nova_quadra'));
    expect(novas, 1);
  });

  testWidgets('carregando e erro', (tester) async {
    await montar(tester, const RequestLoading());
    expect(tester.takeException(), isNull);

    await montar(
      tester,
      const RequestFailure(NetworkFailure('sem conexão')),
      tema: buildDarkTheme(),
    );
    expect(find.text('quadras.minhas.erro_carga'), findsOneWidget);
    expect(find.text('comum.tentar_novamente'), findsOneWidget);
  });
}
