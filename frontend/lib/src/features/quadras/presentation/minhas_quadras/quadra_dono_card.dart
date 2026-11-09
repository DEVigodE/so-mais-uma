import 'package:so_mais_uma/src/imports/imports.dart';

import 'minhas_quadras_calculos.dart';

/// Card de quadra de MinhasQuadras (`<article>` de `minhas_quadras/code.html`).
///
/// Ativa: selo "Ativa", menu de opções, linha de atividade e as ações Editar,
/// Horários e Reservas. Inativa: imagem dessaturada, selo "Inativa", "Horários
/// suspensos" com "Pausada" e só Editar e Horários (sem "Reativar" nem menu,
/// porque não há endpoint de reativação).
class QuadraDonoCard extends StatefulWidget {
  const QuadraDonoCard({
    super.key,
    required this.item,
    required this.desativando,
    required this.onAbrir,
    required this.onEditar,
    required this.onHorarios,
    required this.onReservas,
    required this.onDesativar,
  });

  final QuadraComAtividade item;
  final bool desativando;
  final VoidCallback onAbrir;
  final VoidCallback onEditar;
  final VoidCallback onHorarios;
  final VoidCallback onReservas;
  final VoidCallback onDesativar;

  @override
  State<QuadraDonoCard> createState() => _QuadraDonoCardState();
}

class _QuadraDonoCardState extends State<QuadraDonoCard> {
  // Estado só de UI: permite abrir o menu de opções pelo toque longo no card.
  final _menuKey = GlobalKey<PopupMenuButtonState<_OpcaoCard>>();

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final quadra = widget.item.quadra;
    final ativa = quadra.ativa;

    return Opacity(
      opacity: ativa ? 1 : 0.9,
      child: Material(
        color: ativa
            ? cs.surfaceContainerLowest
            : cs.surfaceContainerLowest.withValues(alpha: 0.8),
        borderRadius: AppBorders.md,
        clipBehavior: Clip.antiAlias,
        elevation: 1,
        shadowColor: cs.shadow.withValues(alpha: 0.3),
        child: InkWell(
          onTap: widget.onAbrir,
          onLongPress:
              ativa ? () => _menuKey.currentState?.showButtonMenu() : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Midia(
                quadra: quadra,
                menu: ativa
                    ? _MenuOpcoes(
                        menuKey: _menuKey,
                        desativando: widget.desativando,
                        onDesativar: widget.onDesativar,
                      )
                    : null,
              ),
              Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (ativa)
                      _LinhaAtividade(
                        esporte: quadra.tipoEsporte,
                        atividade: widget.item.atividade,
                      )
                    else
                      _LinhaInativa(atividade: widget.item.atividade),
                    SizedBox(height: AppSpacing.sm + AppSpacing.xs),
                    Row(
                      children: [
                        Expanded(
                          child: _BotaoAcao(
                            icone: Icons.edit_outlined,
                            rotulo: 'quadras.minhas.editar'.tr(),
                            onTap: widget.onEditar,
                          ),
                        ),
                        SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: _BotaoAcao(
                            icone: Icons.schedule_outlined,
                            rotulo: 'quadras.minhas.horarios'.tr(),
                            onTap: widget.onHorarios,
                          ),
                        ),
                        if (ativa) ...[
                          SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: _BotaoAcao(
                              icone: Icons.calendar_month_outlined,
                              rotulo: 'quadras.minhas.reservas'.tr(),
                              onTap: widget.onReservas,
                              destaque: true,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _OpcaoCard { desativar }

/// Largura máxima dos selos à direita ("43% lotada", "Pausada"), para não
/// estourar a linha com fonte ampliada.
const double _larguraMaximaSelo = 128;

/// "6 reservas hoje" (zero, uma ou várias), ou "Reservas indisponíveis".
///
/// Resolve as formas `zero`/`one`/`other` pela chave aninhada em vez de
/// `plural()`, para a regra ser a mesma nos três idiomas (no pt, o CLDR põe o 0
/// na forma `one`).
String _reservasHoje(int? n) => switch (n) {
      null => 'quadras.minhas.reservas_indisponiveis'.tr(),
      0 => 'quadras.minhas.reservas_hoje.zero'.tr(),
      1 => 'quadras.minhas.reservas_hoje.one'.tr(),
      _ => 'quadras.minhas.reservas_hoje.other'.tr(args: ['$n']),
    };

/// Mídia de 160 px (144 px na inativa) com degradê, selo, menu e o bloco de
/// esporte, nome e preço sobre a imagem.
class _Midia extends StatelessWidget {
  const _Midia({required this.quadra, required this.menu});

  final Quadra quadra;
  final Widget? menu;

  static const double _alturaAtiva = 160;
  static const double _alturaInativa = 144;

  /// `grayscale-[0.6]`: mantém 40 % da saturação.
  static const ColorFilter _dessaturar = ColorFilter.matrix(<double>[
    0.5274, 0.4291, 0.0434, 0, 0, //
    0.1274, 0.8291, 0.0434, 0, 0, //
    0.1274, 0.4291, 0.4434, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final ativa = quadra.ativa;
    final url = quadra.fotoUrl;
    final placeholder = _ImagemPadrao(esporte: quadra.tipoEsporte);

    Widget imagem = (url == null || url.trim().isEmpty)
        ? placeholder
        : CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (context, url) => placeholder,
            errorWidget: (context, url, erro) => placeholder,
          );
    if (!ativa) imagem = ColorFiltered(colorFilter: _dessaturar, child: imagem);

    return SizedBox(
      height: ativa ? _alturaAtiva : _alturaInativa,
      child: Stack(
        fit: StackFit.expand,
        children: [
          imagem,
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  cs.scrim.withValues(alpha: ativa ? 0.7 : 0.8),
                  cs.scrim.withValues(alpha: ativa ? 0.2 : 0.4),
                  cs.scrim.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          Positioned(
            top: AppSpacing.ms,
            left: AppSpacing.ms,
            child: _SeloStatus(ativa: ativa),
          ),
          if (menu != null)
            Positioned(
              top: AppSpacing.ms,
              right: AppSpacing.ms,
              child: menu!,
            ),
          Positioned(
            left: AppSpacing.ms,
            right: AppSpacing.ms,
            bottom: AppSpacing.ms,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          quadra.tipoEsporte.rotuloKey.tr(),
                          style: tt.labelSmall?.copyWith(
                            color: Colors.white
                                .withValues(alpha: ativa ? 0.8 : 0.7),
                          ),
                        ),
                        Text(
                          quadra.nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.s10,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: cs.scrim.withValues(alpha: 0.35),
                    borderRadius: AppBorders.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'quadras.minhas.por_hora'.tr(),
                        style: tt.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                          height: 1,
                        ),
                      ),
                      Text(
                        Formatadores.moeda(quadra.precoHora),
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: ativa ? cs.primaryFixed : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagemPadrao extends StatelessWidget {
  const _ImagemPadrao({required this.esporte});

  final TipoEsporte esporte;

  static const double _icone = 56;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return ColoredBox(
      color: cs.surfaceContainer,
      child: Align(
        alignment: const Alignment(0, -0.3),
        child: Icon(
          esporte.icone,
          size: _icone,
          color: cs.outline.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _SeloStatus extends StatelessWidget {
  const _SeloStatus({required this.ativa});

  final bool ativa;

  static const double _ponto = 6;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.s10,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: ativa
            ? cs.primary.withValues(alpha: 0.95)
            : cs.surfaceContainerHighest.withValues(alpha: 0.9),
        borderRadius: AppBorders.full,
        boxShadow: AppShadows.subtle,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: _ponto,
            height: _ponto,
            decoration: BoxDecoration(
              color: ativa ? cs.primaryFixed : cs.error,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: AppSpacing.s6),
          Text(
            ativa ? 'quadras.minhas.ativa'.tr() : 'quadras.minhas.inativa'.tr(),
            style: context.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: ativa ? cs.onPrimary : cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuOpcoes extends StatelessWidget {
  const _MenuOpcoes({
    required this.menuKey,
    required this.desativando,
    required this.onDesativar,
  });

  final GlobalKey<PopupMenuButtonState<_OpcaoCard>> menuKey;
  final bool desativando;
  final VoidCallback onDesativar;

  static const double _tamanho = 32;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Material(
      color: cs.scrim.withValues(alpha: 0.4),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: _tamanho,
        height: _tamanho,
        child: desativando
            ? Padding(
                padding: EdgeInsets.all(AppSpacing.sm),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : PopupMenuButton<_OpcaoCard>(
                key: menuKey,
                tooltip: 'quadras.minhas.opcoes'.tr(),
                padding: EdgeInsets.zero,
                iconSize: 18,
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (_) => onDesativar(),
                itemBuilder: (context) => [
                  PopupMenuItem<_OpcaoCard>(
                    value: _OpcaoCard.desativar,
                    child: Row(
                      children: [
                        Icon(
                          Icons.block,
                          size: 20,
                          color: context.colors.error,
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            'quadras.minhas.desativar'.tr(),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: context.colors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _LinhaAtividade extends StatelessWidget {
  const _LinhaAtividade({required this.esporte, required this.atividade});

  final TipoEsporte esporte;
  final AtividadeQuadra atividade;

  static const double _circulo = 32;
  static const double _ponto = 6;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final raquete = esporte.icone == Icons.sports_tennis;
    final n = atividade.reservasHoje;
    final proxima = atividade.proxima;
    final selo = atividade.fechadaHoje
        ? 'quadras.minhas.fechada_hoje'.tr()
        : atividade.ocupacao == null
            ? null
            : 'quadras.minhas.ocupacao'.tr(args: ['${atividade.ocupacao}']);

    return Container(
      padding: EdgeInsets.all(AppSpacing.s10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: AppBorders.sm,
      ),
      child: Row(
        children: [
          Container(
            width: _circulo,
            height: _circulo,
            decoration: BoxDecoration(
              color: raquete ? cs.tertiaryFixed : cs.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              esporte.icone,
              size: 18,
              color: raquete ? cs.onTertiaryFixed : cs.primary,
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _reservasHoje(n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.labelMedium?.copyWith(color: cs.onSurface),
                ),
                Row(
                  children: [
                    Container(
                      width: _ponto,
                      height: _ponto,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        proxima == null
                            ? 'quadras.minhas.sem_proximas'.tr()
                            : 'quadras.minhas.proxima_as'.tr(
                                namedArgs: {'hora': Formatadores.hora(proxima)},
                              ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (selo != null) ...[
            SizedBox(width: AppSpacing.sm),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              constraints: const BoxConstraints(maxWidth: _larguraMaximaSelo),
              decoration: BoxDecoration(
                color: cs.surfaceContainer,
                borderRadius: AppBorders.sm,
              ),
              child: Text(
                selo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color:
                      atividade.fechadaHoje ? cs.onSurfaceVariant : cs.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LinhaInativa extends StatelessWidget {
  const _LinhaInativa({required this.atividade});

  final AtividadeQuadra atividade;

  static const double _circulo = 32;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final n = atividade.reservasHoje;
    return Container(
      padding: EdgeInsets.all(AppSpacing.s10),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.4),
        borderRadius: AppBorders.sm,
      ),
      child: Row(
        children: [
          Container(
            width: _circulo,
            height: _circulo,
            decoration: BoxDecoration(
              color: cs.errorContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.pause_circle_outlined,
              size: 18,
              color: cs.onErrorContainer,
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'quadras.minhas.horarios_suspensos'.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.labelMedium?.copyWith(color: cs.onErrorContainer),
                ),
                Text(
                  _reservasHoje(n),
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs,
            ),
            constraints: const BoxConstraints(maxWidth: _larguraMaximaSelo),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest.withValues(alpha: 0.8),
              borderRadius: AppBorders.xs,
            ),
            child: Text(
              'quadras.minhas.pausada'.tr(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotaoAcao extends StatelessWidget {
  const _BotaoAcao({
    required this.icone,
    required this.rotulo,
    required this.onTap,
    this.destaque = false,
  });

  final IconData icone;
  final String rotulo;
  final VoidCallback onTap;
  final bool destaque;

  static const double _alturaMinima = 44;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final cor = destaque ? cs.primary : cs.onSurfaceVariant;
    return Material(
      color: destaque ? cs.primary.withValues(alpha: 0.1) : cs.surfaceContainer,
      borderRadius: AppBorders.sm,
      child: InkWell(
        borderRadius: AppBorders.sm,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _alturaMinima),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icone, size: 18, color: cor),
                SizedBox(width: AppSpacing.s6),
                Flexible(
                  child: Text(
                    rotulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.labelMedium?.copyWith(
                      color: cor,
                      fontWeight: destaque ? FontWeight.w700 : null,
                    ),
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
