import 'package:flutter_test/flutter_test.dart';
import 'package:so_mais_uma/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:so_mais_uma/src/features/reservas/presentation/confirmar_reserva/confirmar_reserva_view.dart';
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

const _quadra = Quadra(
  id: 3,
  nome: 'Arena Champions Society',
  tipoEsporte: TipoEsporte.futebolSociety,
  precoHora: 90,
  cep: '01310100',
  logradouro: 'Av. das Nações Unidas',
  numero: '1420',
  bairro: 'Pinheiros',
  cidade: 'São Paulo',
  uf: 'SP',
);

final _inicio = DateTime.utc(2026, 10, 10, 22);

/// Superfície larga e `designSize` igual a ela: sem easy_localization
/// inicializado, os textos são as chaves, longas na fonte de teste.
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

ConfirmarReservaView _view({
  RequestState<Quadra> quadra = const RequestSuccess(_quadra),
  bool naoEncontrada = false,
  bool enviando = false,
  bool podeConfirmar = true,
  VoidCallback? onConfirmar,
  TextEditingController? controller,
}) =>
    ConfirmarReservaView(
      quadra: quadra,
      inicio: _inicio,
      naoEncontrada: naoEncontrada,
      observacaoController: controller ?? TextEditingController(),
      tamanhoObservacao: controller?.text.length ?? 0,
      enviando: enviando,
      podeConfirmar: podeConfirmar,
      onObservacao: (_) {},
      onConfirmar: onConfirmar ?? () {},
      onTentarNovamente: () {},
      onVoltar: () {},
    );

void main() {
  setUpAll(() {
    injector.addInstance<SessionStore>(SessionStore(repository: _AuthFalso()));
    injector.commit();
  });

  testWidgets('resumo antes do POST, sem QR nem contador', (tester) async {
    var confirmou = 0;
    await _montar(tester, _view(onConfirmar: () => confirmou++));

    expect(find.text('reservas.confirmar.aviso_pix'), findsOneWidget);
    expect(find.text('Arena Champions Society'), findsOneWidget);
    expect(
        find.text('Av. das Nações Unidas, 1420 - Pinheiros'), findsOneWidget);
    expect(find.text(r'R$ 90,00'), findsOneWidget);
    expect(find.text('reservas.confirmar.data_faixa'), findsOneWidget);
    expect(find.text('reservas.confirmar.contador'), findsOneWidget);
    expect(find.text('reservas.confirmar.confirmar'), findsOneWidget);

    await tester.tap(find.text('reservas.confirmar.confirmar'));
    expect(confirmou, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('enviando: botão com progresso e sem toque', (tester) async {
    var confirmou = 0;
    await _montar(
      tester,
      _view(
          enviando: true, podeConfirmar: false, onConfirmar: () => confirmou++),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('reservas.confirmar.confirmar'), findsNothing);
    await tester.tap(find.byType(FilledButton));
    expect(confirmou, 0);
  });

  testWidgets('observação limitada a 200 caracteres', (tester) async {
    final controller = TextEditingController();
    await _montar(tester, _view(controller: controller));
    await tester.enterText(find.byType(TextField), 'a' * 250);
    expect(controller.text.length, 200);
  });

  testWidgets('404 e carregando (tema escuro)', (tester) async {
    await _montar(
      tester,
      _view(
          quadra: const RequestFailure(ApiFailure(status: 404)),
          naoEncontrada: true),
      tema: buildDarkTheme(),
    );
    expect(find.text('reservas.confirmar.nao_encontrada'), findsOneWidget);
    expect(find.text('comum.voltar'), findsOneWidget);

    await _montar(tester, _view(quadra: const RequestLoading()),
        tema: buildDarkTheme());
    expect(tester.takeException(), isNull);
  });

  testWidgets('diálogo do 502 com o texto da spec fecha com "Fechar"',
      (tester) async {
    var fechou = false;
    await _montar(
      tester,
      Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () async {
              await showDialog<void>(
                context: context,
                builder: (_) => const DialogoPagamentoIndisponivel(),
              );
              fechou = true;
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(
        find.text('reservas.confirmar.pagamento_indisponivel'), findsOneWidget);
    await tester.tap(find.text('comum.fechar'));
    await tester.pumpAndSettle();
    expect(fechou, isTrue);
    expect(tester.takeException(), isNull);
  });
}
