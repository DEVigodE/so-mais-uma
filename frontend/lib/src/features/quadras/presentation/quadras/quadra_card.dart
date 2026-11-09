import 'package:so_mais_uma/src/imports/imports.dart';

/// Card de quadra da lista (`<article>` de `quadras/code.html`).
///
/// O card inteiro é um único alvo de toque e um único nó de acessibilidade:
/// o leitor anuncia nome, esporte e preço por hora de uma vez.
class QuadraCard extends StatelessWidget {
  const QuadraCard({super.key, required this.quadra, required this.onTap});

  final Quadra quadra;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final preco = Formatadores.moeda(quadra.precoHora);

    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: 'quadras.lista.card_semantica'.tr(namedArgs: {
        'nome': quadra.nome,
        'esporte': quadra.tipoEsporte.rotuloKey.tr(),
        'preco': preco,
      }),
      onTap: onTap,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          borderRadius: AppBorders.md,
          boxShadow: AppShadows.card,
        ),
        child: Material(
          color: cs.surfaceContainerLowest,
          borderRadius: AppBorders.md,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FotoQuadra(
                        fotoUrl: quadra.fotoUrl,
                        esporte: quadra.tipoEsporte,
                      ),
                      Positioned(
                        left: AppSpacing.ms,
                        bottom: AppSpacing.ms,
                        child: EtiquetaEsporte(esporte: quadra.tipoEsporte),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quadra.nome,
                        style: tt.titleMedium?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: AppSpacing.xxs),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: cs.onSurfaceVariant,
                          ),
                          SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              quadra.localCurto,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.ms),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'quadras.lista.a_partir_de'.tr(),
                                  style: tt.labelSmall
                                      ?.copyWith(color: cs.onSurfaceVariant),
                                ),
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: preco,
                                        style: tt.headlineSmall?.copyWith(
                                          color: cs.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const TextSpan(text: ' '),
                                      TextSpan(
                                        text: 'comum.por_hora'.tr(),
                                        style: tt.bodySmall?.copyWith(
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: AppSpacing.sm),
                          _BotaoVerHorarios(onTap: onTap),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BotaoVerHorarios extends StatelessWidget {
  const _BotaoVerHorarios({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: AppBorders.sm,
        boxShadow: AppShadows.subtle,
      ),
      child: Material(
        color: cs.primary,
        borderRadius: AppBorders.sm,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppBorders.sm,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.s10,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'quadras.lista.ver_horarios'.tr(),
                    style: context.textTheme.labelMedium
                        ?.copyWith(color: cs.onPrimary),
                  ),
                  SizedBox(width: AppSpacing.s6),
                  Icon(Icons.chevron_right, size: 18, color: cs.onPrimary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Foto da quadra (`fotoUrl`) ou, sem foto ou com erro de carga, um
/// placeholder ilustrado com o ícone do esporte.
class FotoQuadra extends StatelessWidget {
  const FotoQuadra({
    super.key,
    required this.fotoUrl,
    required this.esporte,
    this.tamanhoIcone = 56,
  });

  final String? fotoUrl;
  final TipoEsporte esporte;
  final double tamanhoIcone;

  @override
  Widget build(BuildContext context) {
    final url = fotoUrl?.trim() ?? '';
    final placeholder = _PlaceholderFoto(
      esporte: esporte,
      tamanhoIcone: tamanhoIcone,
    );
    if (url.isEmpty) return placeholder;
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      fadeInDuration: AppDurations.normal,
      placeholder: (context, url) =>
          ColoredBox(color: context.colors.surfaceContainer),
      errorWidget: (context, url, erro) => placeholder,
    );
  }
}

class _PlaceholderFoto extends StatelessWidget {
  const _PlaceholderFoto({required this.esporte, required this.tamanhoIcone});

  final TipoEsporte esporte;
  final double tamanhoIcone;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.surfaceContainerHigh,
            cs.primaryFixed.withValues(alpha: 0.45),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          esporte.icone,
          size: tamanhoIcone,
          color: cs.primary.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

/// Etiqueta do esporte sobre a imagem (rótulo curto, D1).
class EtiquetaEsporte extends StatelessWidget {
  const EtiquetaEsporte({
    super.key,
    required this.esporte,
    this.estiloTexto,
    this.tamanhoIcone = 16,
  });

  final TipoEsporte esporte;
  final TextStyle? estiloTexto;
  final double tamanhoIcone;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest.withValues(alpha: 0.9),
        borderRadius: AppBorders.full,
        boxShadow: AppShadows.subtle,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.s10,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              esporte.icone,
              size: tamanhoIcone,
              color: corDoEsporte(cs, esporte),
            ),
            SizedBox(width: AppSpacing.xs),
            Text(
              esporte.rotuloCurtoKey.tr(),
              style: estiloTexto ??
                  context.textTheme.labelSmall?.copyWith(color: cs.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cor do ícone do esporte nas etiquetas: raquete em `tertiary`, como no
/// protótipo; os demais em `primary`.
Color corDoEsporte(ColorScheme cs, TipoEsporte esporte) => switch (esporte) {
      TipoEsporte.tenis ||
      TipoEsporte.beachTennis ||
      TipoEsporte.padel =>
        cs.tertiary,
      _ => cs.primary,
    };

/// Esqueleto de um card enquanto a primeira carga não chega.
class QuadraCardEsqueleto extends StatelessWidget {
  const QuadraCardEsqueleto({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: AppBorders.md,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AspectRatio(
            aspectRatio: 16 / 9,
            child: Bone(
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Bone.text(words: 3),
                SizedBox(height: AppSpacing.xs),
                const Bone.text(words: 2, fontSize: 12),
                SizedBox(height: AppSpacing.ms),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Bone.text(words: 2, fontSize: 20),
                    Bone.button(
                      width: 120,
                      height: 40,
                      borderRadius: AppBorders.sm,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
