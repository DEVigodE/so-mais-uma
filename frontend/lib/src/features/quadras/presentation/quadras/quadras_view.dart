import 'package:so_mais_uma/src/imports/imports.dart';

import 'quadra_card.dart';
import 'quadras_store.dart';

/// View sem estado da tela Quadras (`quadras/code.html`).
class QuadrasView extends StatelessWidget {
  const QuadrasView({
    super.key,
    required this.situacao,
    required this.esporte,
    required this.buscaController,
    required this.onBusca,
    required this.onEsporte,
    required this.onLimparFiltros,
    required this.onAtualizar,
    required this.onTentarNovamente,
    required this.onAbrirQuadra,
  });

  final SituacaoQuadras situacao;

  /// Chip selecionado; `null` = "Todos".
  final TipoEsporte? esporte;
  final TextEditingController buscaController;
  final ValueChanged<String> onBusca;
  final ValueChanged<TipoEsporte?> onEsporte;
  final VoidCallback onLimparFiltros;
  final Future<void> Function() onAtualizar;
  final VoidCallback onTentarNovamente;
  final ValueChanged<Quadra> onAbrirQuadra;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: BarraSuperior(
        titulo: 'comum.app_nome'.tr(),
        subtitulo: Row(
          children: [
            Icon(Icons.location_on_outlined, size: 14, color: cs.primary),
            SizedBox(width: AppSpacing.xs),
            Text(
              'quadras.lista.subtitulo'.tr(),
              style: context.textTheme.labelSmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: onAtualizar,
        color: cs.primary,
        backgroundColor: cs.surfaceContainerHigh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: _CampoBusca(
                  controller: buscaController,
                  onChanged: onBusca,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child:
                  _ChipsEsporte(selecionado: esporte, onSelecionar: onEsporte),
            ),
            ..._conteudo(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _conteudo(BuildContext context) {
    return switch (situacao) {
      QuadrasCarregando() => [
          SliverPadding(
            padding: _paddingLista,
            sliver: SliverToBoxAdapter(
              child: Skeletonizer.zone(
                child: Column(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) SizedBox(height: AppSpacing.md),
                      const QuadraCardEsqueleto(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      QuadrasErro(:final failure) => [
          SliverFillRemaining(
            hasScrollBody: false,
            child: EstadoQuadras(
              icone: failure is NetworkFailure
                  ? Icons.wifi_off_outlined
                  : Icons.error_outline,
              titulo: 'quadras.lista.erro_titulo'.tr(),
              mensagem: failure.message,
              rotuloAcao: 'comum.tentar_novamente'.tr(),
              onAcao: onTentarNovamente,
            ),
          ),
        ],
      QuadrasCatalogoVazio() => [
          SliverFillRemaining(
            hasScrollBody: false,
            child: EstadoQuadras(
              icone: Icons.stadium_outlined,
              titulo: 'quadras.lista.vazio_titulo'.tr(),
              mensagem: 'quadras.lista.vazio_mensagem'.tr(),
            ),
          ),
        ],
      QuadrasSemResultado() => [
          SliverFillRemaining(
            hasScrollBody: false,
            child: EstadoQuadras(
              icone: Icons.search_off_outlined,
              titulo: 'quadras.lista.sem_resultado_titulo'.tr(),
              mensagem: 'quadras.lista.sem_resultado_mensagem'.tr(),
              rotuloAcao: 'quadras.lista.limpar_filtros'.tr(),
              onAcao: onLimparFiltros,
            ),
          ),
        ],
      QuadrasLista(:final quadras) => [
          SliverPadding(
            padding: _paddingLista,
            sliver: SliverList.separated(
              itemCount: quadras.length,
              separatorBuilder: (context, _) => SizedBox(height: AppSpacing.md),
              itemBuilder: (context, i) => QuadraCard(
                quadra: quadras[i],
                onTap: () => onAbrirQuadra(quadras[i]),
              ),
            ),
          ),
        ],
    };
  }

  EdgeInsets get _paddingLista => EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.lg,
      );
}

class _CampoBusca extends StatelessWidget {
  const _CampoBusca({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

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
      child: SizedBox(
        height: 48,
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, valor, _) => Row(
            children: [
              Expanded(
                // Rótulo acessível próprio, separado do placeholder.
                child: MergeSemantics(
                  child: Semantics(
                    label: 'quadras.lista.busca_rotulo'.tr(),
                    child: TextField(
                      controller: controller,
                      onChanged: onChanged,
                      textInputAction: TextInputAction.search,
                      style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: 'quadras.lista.busca_placeholder'.tr(),
                        hintStyle:
                            tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                        prefixIcon:
                            Icon(Icons.search, size: 20, color: cs.secondary),
                        prefixIconConstraints:
                            const BoxConstraints(minWidth: 40),
                      ),
                    ),
                  ),
                ),
              ),
              if (valor.text.isNotEmpty)
                IconButton(
                  tooltip: 'quadras.lista.limpar_busca'.tr(),
                  icon: Icon(Icons.close, size: 20, color: cs.onSurfaceVariant),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipsEsporte extends StatelessWidget {
  const _ChipsEsporte({required this.selecionado, required this.onSelecionar});

  final TipoEsporte? selecionado;
  final ValueChanged<TipoEsporte?> onSelecionar;

  @override
  Widget build(BuildContext context) {
    final opcoes = <TipoEsporte?>[null, ...TipoEsporte.selecionaveis];
    return SizedBox(
      height: 36 + AppSpacing.sm * 2,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        itemCount: opcoes.length,
        separatorBuilder: (context, _) => SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, i) {
          final esporte = opcoes[i];
          return _ChipEsporte(
            icone: esporte?.icone ?? Icons.sports,
            rotulo: esporte == null
                ? 'quadras.lista.todos'.tr()
                : esporte.rotuloKey.tr(),
            selecionado: esporte == selecionado,
            onTap: () => onSelecionar(esporte),
          );
        },
      ),
    );
  }
}

class _ChipEsporte extends StatelessWidget {
  const _ChipEsporte({
    required this.icone,
    required this.rotulo,
    required this.selecionado,
    required this.onTap,
  });

  final IconData icone;
  final String rotulo;
  final bool selecionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final fundo = selecionado ? cs.primary : cs.surfaceContainerLowest;
    final texto = selecionado ? cs.onPrimary : cs.onSurface;
    final corIcone = selecionado ? cs.onPrimary : cs.secondary;
    return Semantics(
      button: true,
      selected: selecionado,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          borderRadius: AppBorders.full,
          boxShadow: AppShadows.subtle,
        ),
        child: Material(
          color: fundo,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icone, size: 18, color: corIcone),
                  SizedBox(width: AppSpacing.s6),
                  Text(
                    rotulo,
                    style:
                        context.textTheme.labelMedium?.copyWith(color: texto),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Estado sem desenho no protótipo (vazio, sem resultado, erro), na mesma
/// linguagem visual dos cartões: ícone em círculo tonal, título e ação.
class EstadoQuadras extends StatelessWidget {
  const EstadoQuadras({
    super.key,
    required this.icone,
    required this.titulo,
    this.mensagem,
    this.rotuloAcao,
    this.onAcao,
  });

  final IconData icone;
  final String titulo;
  final String? mensagem;
  final String? rotuloAcao;
  final VoidCallback? onAcao;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Icon(icone, size: 32, color: cs.primary),
            ),
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: tt.titleMedium?.copyWith(color: cs.onSurface),
          ),
          if (mensagem != null) ...[
            SizedBox(height: AppSpacing.xs),
            Text(
              mensagem!,
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          if (rotuloAcao != null && onAcao != null) ...[
            SizedBox(height: AppSpacing.lg),
            AppButton(label: rotuloAcao!, onPressed: onAcao),
          ],
        ],
      ),
    );
  }
}
