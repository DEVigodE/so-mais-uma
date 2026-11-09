import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:so_mais_uma/src/features/perfil/presentation/perfil/contadores_perfil.dart';
import 'package:so_mais_uma/src/features/perfil/presentation/perfil/perfil_view.dart';
import 'package:so_mais_uma/src/shared/domain/entities/app_user.dart';
import 'package:so_mais_uma/src/shared/domain/enums.dart';
import 'package:so_mais_uma/src/theme/theme.dart';

import '../../reservas/reservas_quadra/traducoes_teste.dart';

/// Smoke test de layout do Perfil nas variantes CLIENTE e DONO.
Widget app(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(body: child),
      ),
    );

void main() {
  setUpAll(prepararAmbienteDeLayout);

  late List<TextEditingController> controllers;

  setUp(() {
    controllers = List.generate(5, (_) => TextEditingController());
  });

  tearDown(() {
    for (final c in controllers) {
      c.dispose();
    }
  });

  Widget view(
    AppUser usuario, {
    List<ContadorPerfil> contadores = const [],
    bool carregando = false,
    bool senhaExpandida = false,
    String? erroSenhaAtual,
  }) =>
      PerfilView(
        usuario: usuario,
        contadores: contadores,
        carregandoContadores: carregando,
        nomeController: controllers[0],
        telefoneController: controllers[1],
        senhaAtualController: controllers[2],
        novaSenhaController: controllers[3],
        confirmacaoController: controllers[4],
        salvandoDados: false,
        senhaExpandida: senhaExpandida,
        salvandoSenha: false,
        saindo: false,
        erroSenhaAtual: erroSenhaAtual,
        onEditarCampo: (_) {},
        onSalvarDados: () {},
        onAlternarSenha: () {},
        onAtualizarSenha: () {},
        onSair: () {},
      );

  testWidgets('CLIENTE com contadores e senha expandida', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 2600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(
        view(
          const AppUser(
            id: '1',
            email: 'lucas.silva@demo.com',
            name: 'Lucas Silva',
            telefone: '11987654321',
          ),
          contadores: const [
            ContadorPerfil('perfil.contadores.jogos', 3),
            ContadorPerfil('perfil.contadores.arenas', 2),
          ],
          senhaExpandida: true,
          erroSenhaAtual: 'perfil.senha.atual_incorreta'.tr(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    semExcecao(tester);
    expect(find.text('LS'), findsOneWidget);
    expect(find.text('perfil.perfil_cliente'.tr()), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('perfil.senha.atual_incorreta'.tr()), findsOneWidget);
    expect(find.text('perfil.sair.botao'.tr()), findsOneWidget);
  });

  testWidgets('DONO carregando contadores', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 2600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(
        view(
          const AppUser(
            id: '2',
            email: 'dono@demo.com',
            name: 'Dona Arena',
            perfil: PerfilUsuario.dono,
          ),
          carregando: true,
        ),
      ),
    );
    await tester.pump();
    semExcecao(tester);
    expect(find.text('perfil.perfil_dono'.tr()), findsOneWidget);
    expect(find.byIcon(Icons.stadium), findsOneWidget);
  });
}

/// Falha com o diagnóstico completo (widget que transbordou e sua origem).
void semExcecao(WidgetTester tester) {
  final erro = tester.takeException();
  if (erro != null) debugPrint('$erro');
  expect(erro, isNull);
}
