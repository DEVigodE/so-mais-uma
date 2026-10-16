import '../../imports/core_imports.dart';

/// A wrapper to initialize [EasyLocalization] with supported locales.
class LocalizationWrapper extends StatelessWidget {
  final Widget child;

  const LocalizationWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return EasyLocalization(
      supportedLocales: const [
        Locale('pt', 'BR'),
        Locale('en'),
        Locale('es'),
      ],
      path: 'assets/translations',
      // Always start in pt-BR, regardless of the device language.
      startLocale: const Locale('pt', 'BR'),
      fallbackLocale: const Locale('pt', 'BR'),
      child: child,
    );
  }
}
