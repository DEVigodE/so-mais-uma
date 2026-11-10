import 'package:so_mais_uma/src/imports/imports.dart';

/// Mensagem de snackbar emitida por um store: uma chave de tradução ou um
/// texto já pronto (como `Failure.message`, que já vem traduzida).
class AvisoTela {
  const AvisoTela.chave(String chave, {this.erro = false})
      : _chave = chave,
        _texto = null;

  const AvisoTela.texto(String texto, {this.erro = true})
      : _texto = texto,
        _chave = null;

  final String? _chave;
  final String? _texto;
  final bool erro;

  /// Chave de tradução, quando o aviso foi criado por chave.
  String? get chave => _chave;

  String get mensagem => _texto ?? _chave!.tr();

  void mostrar(BuildContext context) => showAppSnack(
        context,
        mensagem,
        type: erro ? SnackBarType.error : SnackBarType.info,
      );
}

/// Texto com trechos em negrito marcados por `**` (vindos da tradução).
class TextoComNegrito extends StatelessWidget {
  const TextoComNegrito(
    this.texto, {
    super.key,
    this.style,
    this.estiloNegrito,
    this.textAlign,
  });

  final String texto;
  final TextStyle? style;
  final TextStyle? estiloNegrito;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final negrito = estiloNegrito ?? base.copyWith(fontWeight: FontWeight.w700);
    final partes = texto.split('**');
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          for (var i = 0; i < partes.length; i++)
            if (partes[i].isNotEmpty)
              TextSpan(text: partes[i], style: i.isOdd ? negrito : null),
        ],
      ),
      textAlign: textAlign,
    );
  }
}

/// Foto da quadra com placeholder (quadra fora do catálogo ou sem foto).
class ImagemQuadra extends StatelessWidget {
  const ImagemQuadra({super.key, this.url, this.icone = Icons.sports});

  final String? url;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: context.colors.surfaceContainerHigh,
      child: Center(
        child: Icon(
          icone,
          size: AppSpacing.xl,
          color: context.colors.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );
    final endereco = url?.trim();
    if (endereco == null || endereco.isEmpty) return placeholder;
    return CachedNetworkImage(
      imageUrl: endereco,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => placeholder,
      errorWidget: (context, url, error) => placeholder,
    );
  }
}

/// Pílula com ícone e texto (etiquetas de status do protótipo).
class Pilula extends StatelessWidget {
  const Pilula({
    super.key,
    required this.texto,
    required this.fundo,
    required this.frente,
    this.icone,
    this.estilo,
    this.raio = AppBorders.full,
    this.maiusculas = false,
    this.maxLinhas = 1,
  });

  final String texto;
  final Color fundo;
  final Color frente;
  final IconData? icone;
  final TextStyle? estilo;
  final BorderRadius raio;
  final bool maiusculas;
  final int maxLinhas;

  @override
  Widget build(BuildContext context) {
    final style = (estilo ?? context.textTheme.labelSmall)?.copyWith(
      color: frente,
      fontWeight: FontWeight.w700,
      letterSpacing: maiusculas ? 0.6 : null,
    );
    return DecoratedBox(
      decoration: BoxDecoration(color: fundo, borderRadius: raio),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.ms,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icone != null) ...[
              Icon(icone, size: AppSpacing.s14, color: frente),
              SizedBox(width: AppSpacing.s6),
            ],
            Flexible(
              child: Text(
                maiusculas ? texto.toUpperCase() : texto,
                style: style,
                maxLines: maxLinhas,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cartão branco arredondado com sombra leve (`rounded-xl shadow-sm`).
class CartaoReserva extends StatelessWidget {
  const CartaoReserva({
    super.key,
    required this.child,
    this.padding,
    this.cor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cor ?? context.colors.surfaceContainerLowest,
        borderRadius: AppBorders.md,
        boxShadow: AppShadows.subtle,
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.all(AppSpacing.md),
        child: child,
      ),
    );
  }
}

/// Estado de erro na linguagem visual das telas de reserva.
class EstadoErroReservas extends StatelessWidget {
  const EstadoErroReservas({
    super.key,
    required this.titulo,
    this.mensagem,
    this.icone = Icons.error_outline,
    this.rotuloAcao,
    this.onAcao,
  });

  final String titulo;
  final String? mensagem;
  final IconData icone;
  final String? rotuloAcao;
  final VoidCallback? onAcao;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: cs.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.ms),
                child: Icon(icone,
                    size: AppSpacing.xl, color: cs.onErrorContainer),
              ),
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: tt.titleMedium?.copyWith(color: cs.onSurface),
            ),
            if (mensagem != null) ...[
              SizedBox(height: AppSpacing.sm),
              Text(
                mensagem!,
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(color: cs.secondary),
              ),
            ],
            if (rotuloAcao != null && onAcao != null) ...[
              SizedBox(height: AppSpacing.lg),
              FilledButton.tonal(
                onPressed: onAcao,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, kMinInteractiveDimension),
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  shape:
                      const RoundedRectangleBorder(borderRadius: AppBorders.md),
                ),
                child: Text(rotuloAcao!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Botão largo do protótipo (`min-h-[48px] rounded-xl`), com ícone opcional.
class BotaoReserva extends StatelessWidget {
  const BotaoReserva({
    super.key,
    required this.rotulo,
    required this.fundo,
    required this.frente,
    this.icone,
    this.onPressed,
    this.carregando = false,
    this.estilo,
    this.altura,
    this.semanticsLabel,
    this.autofocus = false,
    this.focusNode,
  });

  final String rotulo;
  final Color fundo;
  final Color frente;
  final IconData? icone;
  final VoidCallback? onPressed;
  final bool carregando;
  final TextStyle? estilo;
  final double? altura;
  final String? semanticsLabel;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final style =
        (estilo ?? context.textTheme.labelLarge)?.copyWith(color: frente);
    final habilitado = onPressed != null && !carregando;
    final botao = FilledButton(
      onPressed: habilitado ? onPressed : null,
      autofocus: autofocus,
      focusNode: focusNode,
      style: FilledButton.styleFrom(
        backgroundColor: fundo,
        foregroundColor: frente,
        disabledBackgroundColor: fundo.withValues(alpha: 0.5),
        disabledForegroundColor: frente.withValues(alpha: 0.7),
        minimumSize: Size.fromHeight(altura ?? kMinInteractiveDimension),
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.ms),
        shape: const RoundedRectangleBorder(borderRadius: AppBorders.md),
        elevation: 0,
        textStyle: style,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (carregando)
            SizedBox.square(
              dimension: AppSpacing.ml,
              child: CircularProgressIndicator(strokeWidth: 2, color: frente),
            )
          else if (icone != null)
            Icon(icone, size: AppSpacing.ml),
          if (carregando || icone != null) SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              rotulo,
              style: style,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
    if (semanticsLabel == null) return botao;
    return Semantics(
      button: true,
      enabled: habilitado,
      label: semanticsLabel,
      excludeSemantics: true,
      onTap: habilitado ? onPressed : null,
      child: botao,
    );
  }
}

/// Bloco de esqueleto para estados de carregamento.
class BlocoEsqueleto extends StatelessWidget {
  const BlocoEsqueleto(
      {super.key, required this.altura, this.raio = AppBorders.md});

  final double altura;
  final BorderRadius raio;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: altura,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerHigh,
          borderRadius: raio,
        ),
      ),
    );
  }
}
