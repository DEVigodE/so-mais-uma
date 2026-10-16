import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:so_mais_uma/src/app.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App should build', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // easy_localization persists locale via SharedPreferences; mock it in tests
    // so platform channels do not hang when shared_preferences is not selected.
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('pt'),Locale('en'),Locale('es'),],
      path: 'assets/translations',
        fallbackLocale: const Locale('pt'),
        saveLocale: false,
      child: const App(),
      )
    );

    // Verify that our base app builds successfully.
    expect(find.byType(App), findsOneWidget);
  });
}
