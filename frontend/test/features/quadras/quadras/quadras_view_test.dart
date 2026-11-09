import 'package:flutter_test/flutter_test.dart';
import 'package:so_mais_uma/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:so_mais_uma/src/features/quadras/presentation/quadras/quadra_card.dart';
import 'package:so_mais_uma/src/features/quadras/presentation/quadras/quadras_store.dart';
import 'package:so_mais_uma/src/features/quadras/presentation/quadras/quadras_view.dart';
import 'package:so_mais_uma/src/imports/imports.dart';

class _AuthFalso implements AuthRepository {
  @override
  FutureEither<AppUser?> checkAuthState() async =>
      const Right(AppUser(id: '1', email: 'c@demo.com', name: 'Cliente Demo'));
  @override
  Stream<AppUser?> get onAuthStateChanged => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Quadra _quadra(int id, String nome, TipoEsporte esporte) => Quadra(
      id: id,
      nome: nome,
      tipoEsporte: esporte,
      precoHora: 90,
      cep: '01310100',
      logradouro: 'Rua A',
      numero: '1',
      bairro: 'Pinheiros',
      cidade: 'São Paulo',
      uf: 'SP',
    );

/// Monta a tela com GoRouter e ScreenUtil. A largura é maior que a de um
/// celular porque, sem easy_localization inicializado, os textos são as
/// chaves (longas) desenhadas na fonte de teste.
Future<void> _montar(WidgetTester tester, Widget tela,
    {ThemeData? tema}) async {
  tester.view.physicalSize = const Size(2400, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (context, state) => tela)],
  );
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(800, 844),
      minTextAdapt: true,
      builder: (context, _) => MaterialApp.router(
        theme: tema ?? buildLightTheme(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
}

QuadrasView _view(
  SituacaoQuadras situacao, {
  TipoEsporte? esporte,
  void Function(TipoEsporte?)? onEsporte,
  VoidCallback? onLimpar,
  void Function(Quadra)? onAbrir,
}) =>
    QuadrasView(
      situacao: situacao,
      esporte: esporte,
      buscaController: TextEditingController(),
      onBusca: (_) {},
      onEsporte: onEsporte ?? (_) {},
      onLimparFiltros: onLimpar ?? () {},
      onAtualizar: () async {},
      onTentarNovamente: () {},
      onAbrirQuadra: onAbrir ?? (_) {},
    );

void main() {
  setUpAll(() {
    injector.addInstance<SessionStore>(SessionStore(repository: _AuthFalso()));
    injector.commit();
  });

  testWidgets('lista: cards, chips de todos os esportes e toque abre',
      (tester) async {
    Quadra? aberta;
    TipoEsporte? escolhido;
    final quadras = [
      _quadra(1, 'Arena Sul', TipoEsporte.futebolSociety),
      _quadra(2, 'Beach Club', TipoEsporte.beachTennis),
    ];
    await _montar(
      tester,
      _view(
        QuadrasLista(quadras),
        onAbrir: (q) => aberta = q,
        onEsporte: (e) => escolhido = e,
      ),
    );

    expect(find.byType(QuadraCard), findsNWidgets(2));
    expect(find.text('Arena Sul'), findsOneWidget);
    expect(find.text('Pinheiros, São Paulo'), findsNWidgets(2));
    expect(find.textContaining('90,00'), findsNWidgets(2));
    // "Todos" + 7 esportes (sem Futevôlei).
    expect(find.text('esportes.FUTSAL'), findsOneWidget);
    expect(find.text('esportes.OUTRO'), findsNothing);

    await tester.tap(find.text('Arena Sul'));
    expect(aberta?.id, 1);

    await tester.tap(find.text('esportes.FUTSAL'));
    expect(escolhido, TipoEsporte.futsal);
    expect(tester.takeException(), isNull);
  });

  testWidgets('carregando mostra 3 esqueletos', (tester) async {
    await _montar(tester, _view(const QuadrasCarregando()));
    expect(find.byType(QuadraCardEsqueleto), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('sem resultado oferece limpar filtros', (tester) async {
    var limpou = false;
    await _montar(
      tester,
      _view(const QuadrasSemResultado(), onLimpar: () => limpou = true),
    );
    expect(find.text('quadras.lista.sem_resultado_titulo'), findsOneWidget);
    await tester.tap(find.text('quadras.lista.limpar_filtros'));
    expect(limpou, isTrue);
  });

  testWidgets('vazio e erro no tema escuro', (tester) async {
    await _montar(tester, _view(const QuadrasCatalogoVazio()),
        tema: buildDarkTheme());
    expect(find.text('quadras.lista.vazio_titulo'), findsOneWidget);
    await _montar(
      tester,
      _view(const QuadrasErro(NetworkFailure('sem rede'))),
      tema: buildDarkTheme(),
    );
    expect(find.text('comum.tentar_novamente'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
