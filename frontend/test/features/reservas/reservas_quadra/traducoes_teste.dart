import 'dart:convert';
import 'dart:io';

// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Ambiente dos widget tests de layout: textos reais e fonte com métricas
/// reais (a fonte padrão dos testes desenha cada glifo com 1 em de largura,
/// o que acusa transbordos que não existem no aparelho).
Future<void> prepararAmbienteDeLayout() async {
  carregarTraducoesPtBr();
  await carregarFonteRoboto();
}

/// Carrega `assets/translations/pt-BR.json` no easy_localization para os
/// widget tests renderizarem os textos reais (e `plural()` funcionar).
///
/// `--dart-define=I18N_FRAGMENTO=<caminho>` mescla um fragmento ainda não
/// incorporado ao arquivo do app.
void carregarTraducoesPtBr() {
  final base = _ler('assets/translations/pt-BR.json');
  const fragmento = String.fromEnvironment('I18N_FRAGMENTO');
  if (fragmento.isNotEmpty) _mesclar(base, _ler(fragmento));
  Localization.load(
    const Locale('pt', 'BR'),
    translations: Translations(base),
  );
}

/// Registra a Roboto do SDK do Flutter (`bin/cache/artifacts/material_fonts`)
/// como a família "Roboto" do tema. Sem o SDK por perto, mantém a fonte de
/// teste.
Future<void> carregarFonteRoboto() async {
  final pasta = _pastaFontesMaterial();
  if (pasta == null) return;
  final loader = FontLoader('Roboto');
  var algum = false;
  for (final nome in const [
    'roboto-regular.ttf',
    'roboto-italic.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
  ]) {
    final arquivo = File('${pasta.path}${Platform.pathSeparator}$nome');
    if (!arquivo.existsSync()) continue;
    algum = true;
    loader.addFont(
      Future.value(ByteData.sublistView(arquivo.readAsBytesSync())),
    );
  }
  if (algum) await loader.load();
}

Directory? _pastaFontesMaterial() {
  final raiz = Platform.environment['FLUTTER_ROOT'];
  final candidatos = <Directory>[
    if (raiz != null) Directory('$raiz/bin/cache/artifacts/material_fonts'),
  ];
  // flutter_tester fica em <sdk>/bin/cache/artifacts/engine/<plataforma>/.
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 6; i++) {
    candidatos.add(Directory('${dir.path}/material_fonts'));
    dir = dir.parent;
  }
  for (final d in candidatos) {
    if (d.existsSync()) return d;
  }
  return null;
}

Map<String, dynamic> _ler(String caminho) =>
    jsonDecode(File(caminho).readAsStringSync()) as Map<String, dynamic>;

void _mesclar(Map<String, dynamic> alvo, Map<String, dynamic> origem) {
  origem.forEach((chave, valor) {
    final atual = alvo[chave];
    if (atual is Map<String, dynamic> && valor is Map<String, dynamic>) {
      _mesclar(atual, valor);
    } else {
      alvo[chave] = valor;
    }
  });
}
