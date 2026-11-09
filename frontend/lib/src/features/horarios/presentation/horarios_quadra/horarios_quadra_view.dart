import 'package:so_mais_uma/src/imports/imports.dart';

import '../../domain/salvar_horarios_use_case.dart';

/// View sem estado de HorariosQuadra (`hor_rios_de_funcionamento/code.html`).
class HorariosQuadraView extends StatelessWidget {
  const HorariosQuadraView({
    super.key,
    required this.carga,
    required this.quadra,
    required this.dias,
    required this.errosDia,
    required this.salvando,
    required this.podeSalvar,
    required this.podeCopiar,
    required this.semFaixas,
    required this.onVoltar,
    required this.onTentarNovamente,
    required this.onAlternarDia,
    required this.onAbertura,
    required this.onFechamento,
    required this.onCopiar,
    required this.onSalvar,
  });

  final RequestState<void> carga;
  final Quadra? quadra;
  final List<FaixaDia> dias;
  final Map<int, String> errosDia;
  final bool salvando;
  final bool podeSalvar;
  final bool podeCopiar;
  final bool semFaixas;
  final VoidCallback onVoltar;
  final VoidCallback onTentarNovamente;
  final void Function(int diaSemana, bool aberto) onAlternarDia;
  final void Function(int diaSemana, int hora) onAbertura;
  final void Function(int diaSemana, int hora) onFechamento;
  final VoidCallback onCopiar;
  final VoidCallback onSalvar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: BarraSuperior(
        titulo: 'horarios.titulo'.tr(),
        tituloStyle: context.textTheme.titleLarge
            ?.copyWith(color: context.colors.onSurface),
        mostrarVoltar: true,
        onVoltar: onVoltar,
      ),
      body: switch (carga) {
        RequestInitial() || RequestLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
        RequestFailure(:final failure) => _CaixaErro(
            mensagem: failure.message,
            onTentarNovamente: onTentarNovamente,
          ),
        RequestSuccess() => _Conteudo(view: this),
      },
    );
  }
}

class _Conteudo extends StatelessWidget {
  const _Conteudo({required this.view});

  final HorariosQuadraView view;

  @override
  Widget build(BuildContext context) {
    final editavel = !view.salvando;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg + context.safeArea.bottom,
      ),
      children: [
        _CartaoQuadra(quadra: view.quadra),
        SizedBox(height: AppSpacing.md),
        _CartaoCopiar(habilitado: view.podeCopiar, onCopiar: view.onCopiar),
        SizedBox(height: AppSpacing.md),
        _Aviso(
          icone: Icons.info_outlined,
          texto: 'horarios.regra'.tr(),
        ),
        if (view.semFaixas) ...[
          SizedBox(height: AppSpacing.sm),
          _Aviso(
            icone: Icons.toggle_on_outlined,
            texto: 'horarios.sem_faixas'.tr(),
            destaque: true,
          ),
        ],
        SizedBox(height: AppSpacing.md),
        for (final dia in view.dias) ...[
          _CartaoDia(
            dia: dia,
            erro: view.errosDia[dia.diaSemana],
            editavel: editavel,
            onAlternar: (aberto) => view.onAlternarDia(dia.diaSemana, aberto),
            onAbertura: (h) => view.onAbertura(dia.diaSemana, h),
            onFechamento: (h) => view.onFechamento(dia.diaSemana, h),
          ),
          SizedBox(height: AppSpacing.sm),
        ],
        SizedBox(height: AppSpacing.sm),
        _BotaoSalvar(
          salvando: view.salvando,
          onSalvar: view.podeSalvar ? view.onSalvar : null,
        ),
      ],
    );
  }
}

class _CartaoQuadra extends StatelessWidget {
  const _CartaoQuadra({required this.quadra});

  final Quadra? quadra;

  static const double _iconeEstadio = 40;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final q = quadra;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: AppBorders.md,
        boxShadow: AppShadows.subtle,
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (q != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _EtiquetaEsporte(esporte: q.tipoEsporte),
                        SizedBox(height: AppSpacing.xs),
                        Text(
                          q.nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.titleLarge?.copyWith(color: cs.onSurface),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Container(
                    width: _iconeEstadio,
                    height: _iconeEstadio,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.stadium_outlined, color: cs.primary),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.sm),
            ],
            Row(
              children: [
                Icon(Icons.schedule_outlined, size: 16, color: cs.outline),
                SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'horarios.fuso'.tr(),
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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

class _EtiquetaEsporte extends StatelessWidget {
  const _EtiquetaEsporte({required this.esporte});

  final TipoEsporte esporte;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.s10,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: AppBorders.full,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(esporte.icone, size: 14, color: cs.onSecondaryContainer),
          SizedBox(width: AppSpacing.s6),
          Flexible(
            child: Text(
              esporte.rotuloKey.tr(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.labelSmall
                  ?.copyWith(color: cs.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartaoCopiar extends StatelessWidget {
  const _CartaoCopiar({required this.habilitado, required this.onCopiar});

  final bool habilitado;
  final VoidCallback onCopiar;

  static const double _circulo = 36;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final corBotao =
        habilitado ? cs.primary : cs.onSurface.withValues(alpha: 0.38);
    final botao = Material(
      color: cs.surfaceContainerLowest,
      borderRadius: AppBorders.sm,
      elevation: habilitado ? 1 : 0,
      child: InkWell(
        borderRadius: AppBorders.sm,
        onTap: habilitado ? onCopiar : null,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.ms,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'horarios.copiar'.tr(),
                style: tt.labelMedium?.copyWith(color: corBotao),
              ),
              SizedBox(width: AppSpacing.s6),
              Icon(Icons.arrow_forward, size: 16, color: corBotao),
            ],
          ),
        ),
      ),
    );
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.primaryFixed.withValues(alpha: 0.25),
        borderRadius: AppBorders.md,
      ),
      child: Row(
        children: [
          Container(
            width: _circulo,
            height: _circulo,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
              boxShadow: AppShadows.subtle,
            ),
            child: Icon(
              Icons.content_copy_outlined,
              size: 20,
              color: cs.onPrimaryContainer,
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'horarios.copiar_titulo'.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleSmall?.copyWith(color: cs.onSurface),
                ),
                Text(
                  'horarios.copiar_subtitulo'.tr(),
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          if (habilitado)
            botao
          else
            Tooltip(
              message: 'horarios.copiar_desabilitado'.tr(),
              child: botao,
            ),
        ],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({
    required this.icone,
    required this.texto,
    this.destaque = false,
  });

  final IconData icone;
  final String texto;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: destaque ? cs.secondaryContainer : cs.surfaceContainerLow,
        borderRadius: AppBorders.md,
      ),
      child: Row(
        children: [
          Icon(
            icone,
            size: 20,
            color: destaque ? cs.primary : cs.secondary,
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              texto,
              style: context.textTheme.bodySmall?.copyWith(
                color: destaque ? cs.onSecondaryContainer : cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartaoDia extends StatelessWidget {
  const _CartaoDia({
    required this.dia,
    required this.erro,
    required this.editavel,
    required this.onAlternar,
    required this.onAbertura,
    required this.onFechamento,
  });

  final FaixaDia dia;
  final String? erro;
  final bool editavel;
  final ValueChanged<bool> onAlternar;
  final ValueChanged<int> onAbertura;
  final ValueChanged<int> onFechamento;

  static const double _ponto = 8;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final nome = Formatadores.nomeDiaSemana(dia.diaSemana);
    final resumo = dia.aberto
        ? 'horarios.a11y_aberto'.tr(namedArgs: {
            'dia': nome,
            'abre': '${dia.abertura}',
            'fecha': '${dia.fechamento}',
          })
        : 'horarios.a11y_fechado'.tr(namedArgs: {'dia': nome});

    return Semantics(
      container: true,
      label: resumo,
      child: AnimatedOpacity(
        duration: AppDurations.fast,
        opacity: dia.aberto ? 1 : 0.8,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            borderRadius: AppBorders.md,
            boxShadow: AppShadows.subtle,
          ),
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: _ponto,
                      height: _ponto,
                      decoration: BoxDecoration(
                        color: dia.aberto ? cs.primary : cs.outline,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: ExcludeSemantics(
                        child: Text(
                          nome,
                          style: tt.titleSmall?.copyWith(color: cs.onSurface),
                        ),
                      ),
                    ),
                    Semantics(
                      label: nome,
                      child: Switch(
                        value: dia.aberto,
                        onChanged: editavel ? onAlternar : null,
                      ),
                    ),
                    SizedBox(width: AppSpacing.s10),
                    ExcludeSemantics(
                      child: Text(
                        dia.aberto
                            ? 'horarios.aberto'.tr()
                            : 'horarios.fechado'.tr(),
                        style: tt.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: dia.aberto ? cs.primary : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.sm),
                if (dia.aberto)
                  Row(
                    children: [
                      Expanded(
                        child: _SeletorHora(
                          rotulo: 'horarios.abre'.tr(),
                          semantica: 'horarios.a11y_abertura'
                              .tr(namedArgs: {'dia': nome}),
                          hora: dia.abertura,
                          minima: FaixaDia.aberturaMinima,
                          maxima: FaixaDia.aberturaMaxima,
                          habilitado: editavel,
                          onSelecionar: onAbertura,
                        ),
                      ),
                      Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                        child: ExcludeSemantics(
                          child: Text(
                            'horarios.as'.tr(),
                            style: tt.titleSmall?.copyWith(color: cs.outline),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _SeletorHora(
                          rotulo: 'horarios.fecha'.tr(),
                          semantica: 'horarios.a11y_fechamento'
                              .tr(namedArgs: {'dia': nome}),
                          hora: dia.fechamento,
                          minima: FaixaDia.fechamentoMinimo,
                          maxima: FaixaDia.fechamentoMaximo,
                          habilitado: editavel,
                          onSelecionar: onFechamento,
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Icon(Icons.block, size: 18, color: cs.secondary),
                      SizedBox(width: AppSpacing.s6),
                      Expanded(
                        child: Text(
                          'horarios.fechado_neste_dia'.tr(),
                          style: tt.bodySmall?.copyWith(
                            color: cs.secondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                if (erro != null) ...[
                  SizedBox(height: AppSpacing.sm),
                  Semantics(
                    liveRegion: true,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline, size: 16, color: cs.error),
                        SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            erro!,
                            style: tt.bodySmall?.copyWith(color: cs.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SeletorHora extends StatelessWidget {
  const _SeletorHora({
    required this.rotulo,
    required this.semantica,
    required this.hora,
    required this.minima,
    required this.maxima,
    required this.habilitado,
    required this.onSelecionar,
  });

  final String rotulo;
  final String semantica;
  final int hora;
  final int minima;
  final int maxima;
  final bool habilitado;
  final ValueChanged<int> onSelecionar;

  /// Largura máxima do botão de hora em relação à caixa.
  static const double _fracaoBotao = 0.75;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final texto = HorarioFuncionamento.hora(hora);
    return Container(
      padding: EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: AppBorders.sm,
      ),
      // O botão fica com a largura natural (até 75 % da caixa, reduzindo com
      // fonte ampliada) e o rótulo usa o resto.
      child: LayoutBuilder(
        builder: (context, restricoes) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: ExcludeSemantics(
                child: Text(
                  rotulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ),
            SizedBox(width: AppSpacing.xs),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: restricoes.maxWidth * _fracaoBotao,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Semantics(
                  button: true,
                  label: semantica,
                  value: texto,
                  excludeSemantics: true,
                  child: PopupMenuButton<int>(
                    enabled: habilitado,
                    initialValue: hora,
                    tooltip: semantica,
                    onSelected: onSelecionar,
                    itemBuilder: (context) => [
                      for (var h = minima; h <= maxima; h++)
                        PopupMenuItem<int>(
                          value: h,
                          child: Text(HorarioFuncionamento.hora(h)),
                        ),
                    ],
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.s10,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLowest,
                        borderRadius: AppBorders.sm,
                        boxShadow: AppShadows.subtle,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            texto,
                            style: tt.titleSmall?.copyWith(color: cs.onSurface),
                          ),
                          SizedBox(width: AppSpacing.xs),
                          Icon(Icons.expand_more, size: 16, color: cs.outline),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotaoSalvar extends StatelessWidget {
  const _BotaoSalvar({required this.salvando, required this.onSalvar});

  final bool salvando;
  final VoidCallback? onSalvar;

  static const double _altura = 48;
  static const double _spinner = 20;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return SizedBox(
      width: double.infinity,
      height: _altura,
      child: FilledButton(
        onPressed: salvando ? null : onSalvar,
        style: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          shape: const RoundedRectangleBorder(borderRadius: AppBorders.md),
          textStyle: context.textTheme.labelLarge,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (salvando)
              SizedBox(
                width: _spinner,
                height: _spinner,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.onSurface.withValues(alpha: 0.38),
                ),
              )
            else
              const Icon(Icons.check, size: 20),
            SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                salvando ? 'horarios.salvando'.tr() : 'horarios.salvar'.tr(),
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            borderRadius: AppBorders.md,
            boxShadow: AppShadows.subtle,
          ),
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_outlined, size: 40, color: cs.error),
                SizedBox(height: AppSpacing.sm),
                Text(
                  'horarios.erro_carga'.tr(),
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
        ),
      ),
    );
  }
}
