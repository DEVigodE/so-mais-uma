import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:so_mais_uma/src/config/injector.dart';
import 'package:so_mais_uma/src/shared/domain/domain.dart';
import 'package:so_mais_uma/src/shared/session/session_store.dart';
import 'package:so_mais_uma/src/theme/theme.dart';

import 'fakes.dart';

const usuarioTeste =
    AppUser(id: '7', email: 'lucas@demo.com', name: 'Lucas Silva');

/// A `BarraSuperior` lê a sessão do injector; registra uma sessão falsa.
void registrarSessaoFake() {
  if (injector.isAdded<SessionStore>()) return;
  injector
    ..uncommit()
    ..addInstance<SessionStore>(
      SessionStore(repository: FakeAuthRepository(usuarioTeste)),
    )
    ..commit();
}

/// Monta [filho] com o tema do app, ScreenUtil e um navegador.
Future<void> montarView(
  WidgetTester tester,
  Widget filho, {
  bool escuro = false,
}) async {
  registrarSessaoFake();
  tester.view
    ..devicePixelRatio = 3
    ..physicalSize = const Size(390 * 3, 844 * 3);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp.router(
        theme: escuro ? buildDarkTheme() : buildLightTheme(),
        routerConfig: GoRouter(
          routes: [GoRoute(path: '/', builder: (context, state) => filho)],
        ),
      ),
    ),
  );
  await tester.pump();
}
