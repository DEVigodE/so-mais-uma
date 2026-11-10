import 'package:so_mais_uma/src/imports/imports.dart';

import 'minhas_quadras_calculos.dart';
import 'minhas_quadras_store.dart';
import 'quadra_dono_card.dart';

/// View sem estado de MinhasQuadras (`minhas_quadras/code.html`).
///
/// Omitidos (fora do MVP ou sem serviço): o sino de notificações, a pílula
/// "Operação em tempo real" e o rodapé "Sincronizado há X min • Conexão
/// estável" (não há serviço de conectividade nem cache).
class MinhasQuadrasView extends StatelessWidget {
  const MinhasQuadrasView({
    super.key,
    required this.estado,
    required this.cards,
    required this.resumo,
    required this.desativando,
    required this.onAtualizar,
    required this.onTentarNovamente,
    required this.onNovaQuadra,
    required this.onAbrir,
    required this.onEditar,
    required this.onHorarios,
    required this.onReservas,
    required this.onDesativar,
    required this.onPerfil,
  });

  final RequestState<List<Quadra>> estado;
  final List<QuadraComAtividade> cards;
  final ResumoPainel resumo;
  final Set<int> desativando;
  final Future<void> Function() onAtualizar;
  final VoidCallback onTentarNovamente;
  final VoidCallback onNovaQuadra;
  final ValueChanged<Quadra> onAbrir;
  final ValueChanged<Quadra> onEditar;
  final ValueChanged<Quadra> onHorarios;
  final ValueChanged<Quadra> onReservas;
  final ValueChanged<Quadra> onDesativar;
  final VoidCallback onPerfil;

  /// Espaço no fim da lista para o botão flutuante não cobrir o último card.
  static const double _folgaFab = 88;

  bool get _vazia => estado is RequestSuccess<List<Quadra>> && cards.isEmpty;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final mostrarFab = estado is RequestSuccess<List<Quadra>> && !_vazia;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: BarraSuperior(
        titulo: 'comum.app_nome'.tr(),
        // Raiz da aba: nunca tem voltar.
        mostrarVoltar: false,
        subtitulo: Text(
          'quadras.minhas.area_proprietario'.tr(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.labelSmall?.copyWith(color: cs.primary),
        ),
        onAvatar: onPerfil,
      ),
      floatingActionButton: mostrarFab
          ? FloatingActionButton.extended(
              onPressed: onNovaQuadra,
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              shape: const StadiumBorder(),
              icon: const Icon(Icons.add),
              label: Text(
                'quadras.minhas.nova_quadra'.tr(),
                style: context.textTheme.labelLarge,
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: onAtualizar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: AppSpacing.xl),
          children: [
            _Cabecalho(resumo: resumo),
            ..._corpo(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _corpo(BuildContext context) {
    final margem = EdgeInsets.symmetric(horizontal: AppSpacing.md);
    switch (estado) {
      case RequestInitial() || RequestLoading():
        return [
          Padding(
            padding: margem.copyWith(top: AppSpacing.md),
            child: const _CardsCarregando(),
          ),
        ];
      case RequestFailure(:final failure):
        return [
          Padding(
            padding: margem.copyWith(top: AppSpacing.md),
            child: _CaixaErro(
              mensagem: failure.message,
              onTentarNovamente: onTentarNovamente,
            ),
          ),
        ];
      case RequestSuccess():
        if (cards.isEmpty) {
          return [
            Padding(
              padding: margem.copyWith(top: AppSpacing.md),
              child: _PrimeiraQuadra(onNovaQuadra: onNovaQuadra),
            ),
          ];
        }
        return [
          _LinhaEspacos(quantidade: cards.length),
          Padding(
            padding: margem.copyWith(top: AppSpacing.xs, bottom: _folgaFab),
            child: Column(
              children: [
                for (final item in cards) ...[
                  QuadraDonoCard(
                    key: ValueKey(item.quadra.id),
                    item: item,
                    desativando: desativando.contains(item.quadra.id),
                    onAbrir: () => onAbrir(item.quadra),
                    onEditar: () => onEditar(item.quadra),
                    onHorarios: () => onHorarios(item.quadra),
                    onReservas: () => onReservas(item.quadra),
                    onDesativar: () => onDesativar(item.quadra),
                  ),
                  SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
          ),
        ];
    }
  }
}

/// "PAINEL DE GESTÃO" / "Minhas Quadras" e o painel em degradê.
class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.resumo});

  final ResumoPainel resumo;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'quadras.minhas.painel_gestao'.tr().toUpperCase(),
            style: tt.labelSmall?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          Semantics(
            header: true,
            child: Text(
              'quadras.minhas.titulo'.tr(),
              style: tt.headlineSmall?.copyWith(color: cs.onSurface),
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          _Painel(resumo: resumo),
        ],
      ),
    );
  }
}

class _Painel extends StatelessWidget {
  const _Painel({required this.resumo});

  final ResumoPainel resumo;

  static const double _decoracao = 128;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final dia = Brasilia.dia(resumo.hoje);
    final data = 'quadras.minhas.hoje_data'.tr(namedArgs: {
      'dia': '${dia.day}',
      'mes': Formatadores.nomeMes(dia),
    });

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primaryContainer, cs.primary],
        ),
        borderRadius: AppBorders.md,
        boxShadow: AppShadows.subtle,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -AppSpacing.lg,
            bottom: -AppSpacing.lg,
            child: IgnorePointer(
              child: CustomPaint(
                size: const Size.square(_decoracao),
                painter: _CampoPainter(cs.onPrimary.withValues(alpha: 0.15)),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  data,
                  style: tt.labelSmall
                      ?.copyWith(color: cs.onPrimary.withValues(alpha: 0.8)),
                ),
                SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _BlocoMetrica(
                        icone: Icons.stadium_outlined,
                        rotulo: 'quadras.minhas.total_quadras'.tr(),
                        valor: resumo.totalQuadras,
                        unidade: 'quadras.minhas.cadastradas'.tr(),
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _BlocoMetrica(
                        icone: Icons.event_available_outlined,
                        rotulo: 'quadras.minhas.reservas_hoje_painel'.tr(),
                        valor: resumo.reservasHoje,
                        unidade: 'quadras.minhas.confirmadas'.tr(),
                      ),
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

class _BlocoMetrica extends StatelessWidget {
  const _BlocoMetrica({
    required this.icone,
    required this.rotulo,
    required this.valor,
    required this.unidade,
  });

  final IconData icone;
  final String rotulo;
  final int? valor;
  final String unidade;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final suave = cs.onPrimary.withValues(alpha: 0.8);
    final numero = valor?.toString() ?? 'quadras.minhas.sem_valor'.tr();
    return MergeSemantics(
      child: Container(
        padding: EdgeInsets.all(AppSpacing.ms),
        decoration: BoxDecoration(
          color: cs.scrim.withValues(alpha: 0.1),
          borderRadius: AppBorders.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icone, size: 18, color: suave),
                SizedBox(width: AppSpacing.s6),
                Expanded(
                  child: Text(
                    rotulo,
                    style: tt.labelMedium?.copyWith(color: suave),
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    numero,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.headlineLarge?.copyWith(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    unidade,
                    overflow: TextOverflow.ellipsis,
                    style: tt.labelSmall?.copyWith(
                      color: cs.onPrimary.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Decoração de campo (círculo, linha do meio e círculo central) do painel.
class _CampoPainter extends CustomPainter {
  _CampoPainter(this.cor);

  final Color cor;

  @override
  void paint(Canvas canvas, Size size) {
    final escala = size.width / 100;
    final pincel = Paint()
      ..color = cor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 * escala;
    final centro = Offset(size.width / 2, size.height / 2);
    canvas
      ..drawCircle(centro, 42 * escala, pincel)
      ..drawLine(
        Offset(8 * escala, centro.dy),
        Offset(92 * escala, centro.dy),
        pincel,
      )
      ..drawCircle(centro, 12 * escala, pincel);
  }

  @override
  bool shouldRepaint(_CampoPainter oldDelegate) => oldDelegate.cor != cor;
}

/// "Espaços Esportivos" com a contagem e a indicação "Mais ativas".
class _LinhaEspacos extends StatelessWidget {
  const _LinhaEspacos({required this.quantidade});

  final int quantidade;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'quadras.minhas.espacos'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleSmall?.copyWith(color: cs.onSurface),
                  ),
                ),
                SizedBox(width: AppSpacing.xs),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: AppBorders.full,
                  ),
                  child: Text(
                    '$quantidade',
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.swap_vert, size: 18, color: cs.primary),
                SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    'quadras.minhas.mais_ativas'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
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

/// Estado vazio: primeiro acesso do dono.
class _PrimeiraQuadra extends StatelessWidget {
  const _PrimeiraQuadra({required this.onNovaQuadra});

  final VoidCallback onNovaQuadra;

  static const double _circulo = 64;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: AppBorders.md,
        boxShadow: AppShadows.subtle,
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Container(
              width: _circulo,
              height: _circulo,
              decoration: BoxDecoration(
                color: cs.primaryFixed.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.stadium_outlined, size: 32, color: cs.primary),
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              'quadras.minhas.vazio_titulo'.tr(),
              textAlign: TextAlign.center,
              style: tt.titleMedium?.copyWith(color: cs.onSurface),
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              'quadras.minhas.vazio_mensagem'.tr(),
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onNovaQuadra,
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                shape: const StadiumBorder(),
                textStyle: tt.labelLarge,
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.ms,
                ),
              ),
              icon: const Icon(Icons.add),
              label: Text('quadras.minhas.nova_quadra'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardsCarregando extends StatelessWidget {
  const _CardsCarregando();

  static const double _midia = 160;
  static const double _linha = 52;
  static const double _botao = 44;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    Widget card() => DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            borderRadius: AppBorders.md,
            boxShadow: AppShadows.subtle,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ClipRRect(
                borderRadius: AppBorders.md,
                child: Bone(height: _midia, borderRadius: BorderRadius.zero),
              ),
              Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    const Bone(height: _linha, borderRadius: AppBorders.sm),
                    SizedBox(height: AppSpacing.ms),
                    Row(
                      children: [
                        for (var i = 0; i < 3; i++) ...[
                          if (i > 0) SizedBox(width: AppSpacing.xs),
                          const Expanded(
                            child: Bone(
                              height: _botao,
                              borderRadius: AppBorders.sm,
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
        );

    return Semantics(
      label: 'comum.carregando'.tr(),
      child: Skeletonizer.zone(
        child: Column(
          children: [
            card(),
            SizedBox(height: AppSpacing.md),
            card(),
          ],
        ),
      ),
    );
  }
}

class _CaixaErro extends StatelessWidget {
  const _CaixaErro({required this.mensagem, required this.onTentarNovamente});

  final String mensagem;
  final VoidCallback onTentarNovamente;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: AppBorders.md,
        boxShadow: AppShadows.subtle,
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Icon(Icons.cloud_off_outlined, size: 40, color: cs.error),
            SizedBox(height: AppSpacing.sm),
            Text(
              'quadras.minhas.erro_carga'.tr(),
              textAlign: TextAlign.center,
              style: tt.titleMedium?.copyWith(color: cs.onSurface),
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            SizedBox(height: AppSpacing.md),
            FilledButton.tonalIcon(
              onPressed: onTentarNovamente,
              icon: const Icon(Icons.refresh),
              label: Text('comum.tentar_novamente'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
