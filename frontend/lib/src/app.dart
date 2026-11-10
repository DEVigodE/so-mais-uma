import 'package:so_mais_uma/src/imports/core_imports.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    Widget current = _buildMaterialApp(context);
    current = AppPlatformScope(
      style: AppPlatformStyle.adaptive,
      child: current,
    );
    return ScreenUtilWrapper(child: current);
  }


  Widget _buildMaterialApp(BuildContext context) {
    // Formatadores (intl) seguem o idioma do easy_localization.
    Intl.defaultLocale = context.locale.toStringWithSeparator(separator: '_');
    return MaterialApp.router(
      title: 'Só mais uma',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      builder: (context, child) {
        Widget current = child!;
        current = SkeletonWrapper(child: current);
        return current;
      },
    );
  }
}
