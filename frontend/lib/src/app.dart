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
    return MaterialApp.router(
      title: 'so_mais_uma',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(primaryColorHex: '#16A34A'),
      darkTheme: buildDarkTheme(primaryColorHex: '#16A34A'),
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      builder: (context, child) {
        Widget current = child!;
        current = SkeletonWrapper(child: current);
        current = SessionListenerWrapper(child: current);
        return current;
      },
    );
  }
}
