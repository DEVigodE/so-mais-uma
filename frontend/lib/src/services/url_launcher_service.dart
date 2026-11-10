import '../imports/imports.dart';

/// Abre links externos (telefone, WhatsApp, mapas, web).
///
/// Chama `launchUrl` direto, sem `canLaunchUrl`: assim o manifest não precisa
/// de `<queries>`. Falha vira `Left`, e a tela mostra um snackbar.
class UrlLauncherService {
  UrlLauncherService._();
  static final UrlLauncherService instance = UrlLauncherService._();

  /// Abre uma URL qualquer (sem esquema, assume `https://`).
  FutureEither<void> launch(String url, {LaunchMode? mode}) {
    final formatada = url.contains('://') || url.contains(':')
        ? url
        : 'https://$url';
    return _abrir(Uri.parse(formatada), mode: mode);
  }

  /// Abre o discador com `tel:<dígitos>`.
  FutureEither<void> ligar(String telefone) =>
      _abrir(Uri(scheme: 'tel', path: _digitos(telefone)));

  /// Abre a conversa no WhatsApp por `https://wa.me/55<dígitos>`.
  FutureEither<void> whatsapp(String telefone) {
    final digitos = _digitos(telefone);
    final comPais = digitos.startsWith('55') && digitos.length > 11
        ? digitos
        : '55$digitos';
    return _abrir(Uri.parse('https://wa.me/$comPais'));
  }

  /// Abre o app de mapas pela URI `geo:`; sem coordenadas, busca o endereço.
  FutureEither<void> abrirMapa({
    double? latitude,
    double? longitude,
    String? nome,
    String? endereco,
  }) {
    final Uri uri;
    if (latitude != null && longitude != null) {
      final rotulo = Uri.encodeComponent(nome ?? '');
      uri = Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude($rotulo)');
    } else {
      uri = Uri.parse('geo:0,0?q=${Uri.encodeComponent(endereco ?? nome ?? '')}');
    }
    return _abrir(uri);
  }

  FutureEither<void> _abrir(Uri uri, {LaunchMode? mode}) => runTask(
        () async {
          final abriu = await launchUrl(
            uri,
            mode: mode ?? LaunchMode.externalApplication,
          );
          if (!abriu) throw Exception('Could not launch ${uri.scheme} url');
        },
        operation: 'urlLauncher.launch',
        category: LogCategory.app,
        context: {'scheme': uri.scheme},
      );

  String _digitos(String v) => v.replaceAll(RegExp(r'\D'), '');
}
