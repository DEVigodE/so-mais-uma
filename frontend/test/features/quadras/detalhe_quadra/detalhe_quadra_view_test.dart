import 'package:flutter_test/flutter_test.dart';
import 'package:so_mais_uma/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:so_mais_uma/src/features/quadras/presentation/detalhe_quadra/detalhe_quadra_view.dart';
import 'package:so_mais_uma/src/features/quadras/presentation/detalhe_quadra/horarios_agrupados.dart';
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

const _horarios = [
  HorarioFuncionamento(
      diaSemana: 1, horaAbertura: '07:00', horaFechamento: '23:00'),
  HorarioFuncionamento(
      diaSemana: 2, horaAbertura: '07:00', horaFechamento: '23:00'),
  HorarioFuncionamento(
      diaSemana: 3, horaAbertura: '07:00', horaFechamento: '23:00'),
  HorarioFuncionamento(
      diaSemana: 4, horaAbertura: '07:00', horaFechamento: '23:00'),
  HorarioFuncionamento(
      diaSemana: 5, horaAbertura: '07:00', horaFechamento: '23:00'),
  HorarioFuncionamento(
      diaSemana: 6, horaAbertura: '08:00', horaFechamento: '22:00'),
];

Quadra _quadra({String? descricao, double? lat, double? lng}) => Quadra(
      id: 1,
      nome: 'Arena Champions Society',
      tipoEsporte: TipoEsporte.futebolSociety,
      precoHora: 90,
      cep: '01310100',
      logradouro: 'Av. das Nações Unidas',
      numero: '1420',
      bairro: 'Pinheiros',
      cidade: 'São Paulo',
      uf: 'SP',
      descricao: descricao,
      latitude: lat,
      longitude: lng,
      horarios: _horarios,
    );

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

DetalheQuadraView _view(
  RequestState<Quadra> estado, {
  bool naoEncontrada = false,
  ConstrutorSecaoReserva? secao,
  VoidCallback? onVoltar,
  void Function(Quadra)? onMapa,
}) {
  final grupos = switch (estado) {
    RequestSuccess(:final data) => agruparHorarios(data.horarios),
    _ => const <GrupoFuncionamento>[],
  };
  return DetalheQuadraView(
    estado: estado,
    grupos: grupos,
    naoEncontrada: naoEncontrada,
    onTentarNovamente: () {},
    onVoltar: onVoltar ?? () {},
    onAbrirMapa: onMapa ?? (_) {},
    secaoReserva: secao,
  );
}

void main() {
  setUpAll(() {
    injector.addInstance<SessionStore>(SessionStore(repository: _AuthFalso()));
    injector.commit();
  });

  testWidgets('parte estática com descrição, mapa e horários agrupados',
      (tester) async {
    Quadra? mapa;
    await _montar(
      tester,
      _view(
        RequestSuccess(
            _quadra(descricao: 'Gramado sintético.', lat: -23.5, lng: -46.6)),
        onMapa: (q) => mapa = q,
      ),
    );

    expect(find.text('Arena Champions Society'), findsOneWidget);
    expect(
      find.text('Av. das Nações Unidas, 1420 - Pinheiros, São Paulo'),
      findsOneWidget,
    );
    expect(find.text('quadras.detalhe.sobre'), findsOneWidget);
    expect(find.text('Gramado sintético.'), findsOneWidget);
    // 3 grupos: seg a sex, sáb, dom fechado.
    expect(
        find.textContaining('quadras.detalhe.rotulo_dias'), findsNWidgets(3));
    expect(find.textContaining('07:00 – 23:00'), findsOneWidget);
    expect(find.textContaining('quadras.detalhe.fechado'), findsOneWidget);

    await tester.tap(find.text('quadras.detalhe.abrir_maps'));
    expect(mapa?.id, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sem descrição nem coordenadas: sem "Sobre" e sem mapa',
      (tester) async {
    await _montar(tester, _view(RequestSuccess(_quadra())));
    expect(find.text('quadras.detalhe.sobre'), findsNothing);
    expect(find.text('quadras.detalhe.abrir_maps'), findsNothing);
  });

  testWidgets('com a seção de reserva, a barra fica fora da rolagem',
      (tester) async {
    await _montar(
      tester,
      _view(
        RequestSuccess(_quadra()),
        secao: (quadra, layout) => layout(
          const SizedBox(height: 600, child: Text('GRADE')),
          const SizedBox(height: 72, child: Text('BARRA')),
        ),
      ),
    );
    expect(find.text('BARRA'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(ListView), matching: find.text('BARRA')),
      findsNothing,
    );
    await tester.scrollUntilVisible(find.text('GRADE'), 300);
    expect(find.text('GRADE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('404 mostra "quadra não encontrada" com Voltar', (tester) async {
    var voltou = false;
    await _montar(
      tester,
      _view(
        const RequestFailure(ApiFailure(status: 404)),
        naoEncontrada: true,
        onVoltar: () => voltou = true,
      ),
    );
    expect(find.text('quadras.detalhe.nao_encontrada_titulo'), findsOneWidget);
    await tester.tap(find.text('comum.voltar'));
    expect(voltou, isTrue);
  });

  testWidgets('carregando no tema escuro', (tester) async {
    await _montar(tester, _view(const RequestLoading()),
        tema: buildDarkTheme());
    expect(tester.takeException(), isNull);
  });
}
