import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:so_mais_uma/src/config/injector.dart';
import 'package:so_mais_uma/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:so_mais_uma/src/features/quadras/presentation/form_quadra/form_quadra_campos.dart';
import 'package:so_mais_uma/src/features/quadras/presentation/form_quadra/form_quadra_store.dart';
import 'package:so_mais_uma/src/features/quadras/presentation/form_quadra/form_quadra_view.dart';
import 'package:so_mais_uma/src/shared/domain/entities/app_user.dart';
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

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
    injector
      ..addLazySingleton<SessionStore>(
        () => SessionStore(repository: AuthRepositoryFalso()),
      )
      ..commit();
  });

  late Map<CampoQuadra, TextEditingController> controladores;
  late Map<CampoQuadra, FocusNode> focos;

  setUp(() {
    controladores = {
      for (final c in CampoQuadra.values) c: TextEditingController(),
    };
    focos = {for (final c in CampoQuadra.values) c: FocusNode()};
  });

  tearDown(() {
    for (final c in controladores.values) {
      c.dispose();
    }
    for (final f in focos.values) {
      f.dispose();
    }
  });

  Future<void> montar(
    WidgetTester tester, {
    RequestState<void> carga = const RequestSuccess(null),
    FormQuadraCampos campos = const FormQuadraCampos(),
    Map<CampoQuadra, String> erros = const {},
    EstadoCep estadoCep = const CepOcioso(),
    bool coordenadasAuto = false,
    bool podeBuscarCep = false,
    bool salvando = false,
    ThemeData? tema,
    void Function(CampoQuadra, String)? onAlterar,
    VoidCallback? onBuscarCep,
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
          builder: (context, _) => FormQuadraView(
            edicao: false,
            carga: carga,
            campos: campos,
            erros: erros,
            estadoCep: estadoCep,
            coordenadasAuto: coordenadasAuto,
            urlPreview: '',
            salvando: salvando,
            podeBuscarCep: podeBuscarCep,
            controladores: controladores,
            focos: focos,
            onAlterar: onAlterar ?? (a, b) {},
            onEsporte: (_) {},
            onBuscarCep: onBuscarCep ?? () {},
            onAtualizarPreview: () {},
            onVoltar: () {},
            onSalvar: () {},
            onTentarNovamente: () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('formulário completo sem upload de foto', (tester) async {
    await montar(tester);

    expect(find.text('quadras.form.titulo_nova'), findsOneWidget);
    Finder rotulo(String chave) => find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText() == '$chave *',
        );
    expect(rotulo('quadras.form.nome'), findsOneWidget);
    final rolagem = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(rotulo('quadras.form.uf'), 200,
        scrollable: rolagem);
    expect(rotulo('quadras.form.cidade'), findsOneWidget);
    expect(find.text('quadras.form.bairro', findRichText: true), findsOneWidget,
        reason: 'Bairro é opcional (sem asterisco)');
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(find.text('quadras.form.salvar'), 300,
        scrollable: rolagem);
    expect(find.text('quadras.form.preview'), findsWidgets);
    expect(find.byIcon(Icons.cloud_upload_outlined), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('seletor de esporte oferece os 7 valores', (tester) async {
    await montar(tester);

    final seletor = find.byType(DropdownButtonFormField<TipoEsporte>);
    await tester.ensureVisible(seletor);
    await tester.pumpAndSettle();
    await tester.tap(seletor);
    await tester.pumpAndSettle();
    for (final e in TipoEsporte.selecionaveis) {
      expect(find.text(e.rotuloKey), findsWidgets);
    }
    expect(find.text(TipoEsporte.outro.rotuloKey), findsNothing);
  });

  testWidgets('digitar repassa ao store; Buscar CEP habilitado',
      (tester) async {
    final digitado = <(CampoQuadra, String)>[];
    var buscas = 0;
    await montar(
      tester,
      podeBuscarCep: true,
      onAlterar: (c, v) => digitado.add((c, v)),
      onBuscarCep: () => buscas++,
    );

    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.controller == controladores[CampoQuadra.cep],
      ),
      '01001000',
    );
    expect(digitado.last, (CampoQuadra.cep, '01001-000'));

    await tester.ensureVisible(find.text('quadras.form.cep_buscar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('quadras.form.cep_buscar'));
    expect(buscas, 1);
  });

  testWidgets('erros, CEP indisponível e coordenadas automáticas',
      (tester) async {
    await montar(
      tester,
      erros: const {
        CampoQuadra.nome: 'comum.campo_obrigatorio',
        CampoQuadra.cep: 'quadras.form.cep_nao_encontrado',
        CampoQuadra.latitude: 'quadras.form.erro_coordenadas',
      },
      coordenadasAuto: true,
      salvando: true,
      tema: buildDarkTheme(),
    );
    expect(find.text('comum.campo_obrigatorio'), findsOneWidget);
    expect(find.text('quadras.form.cep_nao_encontrado'), findsOneWidget);
    expect(find.text('quadras.form.geo_auto'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await montar(
      tester,
      estadoCep: const CepIndisponivel('quadras.form.cep_indisponivel'),
    );
    expect(find.text('quadras.form.cep_indisponivel'), findsOneWidget);

    await montar(tester, estadoCep: const CepEncontrado(FonteCep.viaCep));
    expect(find.text('quadras.form.cep_via_viacep'), findsOneWidget);
  });

  testWidgets('quadra não encontrada oferece Voltar', (tester) async {
    await montar(
      tester,
      carga: const RequestFailure(ApiFailure(status: 404, message: 'x')),
    );
    expect(find.text('quadras.form.nao_encontrada'), findsOneWidget);
    expect(find.text('comum.voltar'), findsOneWidget);
  });
}
