import 'package:flutter/material.dart';

/// Avatar circular com as iniciais do usuário (o app não tem foto de perfil).
class AvatarIniciais extends StatelessWidget {
  const AvatarIniciais({
    super.key,
    required this.iniciais,
    this.tamanho = 32,
    this.semanticsLabel,
  });

  final String iniciais;
  final double tamanho;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: semanticsLabel != null,
      child: Container(
        width: tamanho,
        height: tamanho,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cs.primaryFixed,
          shape: BoxShape.circle,
        ),
        child: Text(
          iniciais,
          maxLines: 1,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            color: cs.onPrimaryFixed,
            fontWeight: FontWeight.w700,
            fontSize: tamanho * 0.4,
            height: 1,
          ),
        ),
      ),
    );
  }
}
