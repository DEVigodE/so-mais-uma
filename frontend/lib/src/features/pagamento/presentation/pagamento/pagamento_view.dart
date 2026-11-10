import 'package:qr_flutter/qr_flutter.dart';
import 'package:so_mais_uma/src/imports/imports.dart';

import 'contador_pix.dart';
import 'pagamento_store.dart';

/// Tela Pagamento (`pagamento_pix/code.html` e `pagamento_expirado/code.html`),
/// sem estado.
class PagamentoView extends StatelessWidget {
  const PagamentoView({
    super.key,
    required this.fase,
    required this.falhaCarga,
    required this.reserva,
    required this.pagamento,
    required this.quadra,
    required this.restante,
    required this.progresso,
    required this.statusVerificacao,
    required this.verificacaoManual,
    required this.simulando,
    required this.copiado,
    required this.mostrarSimulacao,
    required this.onVoltar,
    required this.onTentarNovamente,
    required this.onCopiar,
    required this.onJaRealizei,
    required this.onSimular,
    required this.onCancelar,
    required this.onEscolherOutroHorario,
  });

  final FasePagamento fase;
  final Failure? falhaCarga;
  final Reserva? reserva;
  final Pagamento? pagamento;
  final Quadra? quadra;

  /// Lidos só pelo cartão do contador, que se reconstrói a cada segundo.
  final ReadonlySignal<Duration> restante;
  final ReadonlySignal<double> progresso;
  final StatusVerificacao statusVerificacao;
  final VerificacaoManual verificacaoManual;
  final bool simulando;
  final bool copiado;

  /// Botão "Simular confirmação Pix" (só em debug, com `DEV_KEY`).
  final bool mostrarSimulacao;
  final VoidCallback onVoltar;
  final VoidCallback onTentarNovamente;
  final VoidCallback onCopiar;
  final VoidCallback onJaRealizei;
  final VoidCallback onSimular;
  final VoidCallback onCancelar;
  final VoidCallback onEscolherOutroHorario;

  @override
  Widget build(BuildContext context) {
    final expirada = fase == FasePagamento.expirada;
    return Scaffold(
      appBar: BarraSuperior(
        titulo: expirada
            ? 'pagamento.titulo_expirado'.tr()
            : 'pagamento.titulo'.tr(),
        onVoltar: onVoltar,
      ),
      body: _corpo(context),
    );
  }

  Widget _corpo(BuildContext context) {
    final r = reserva;
    final p = pagamento;
    switch (fase) {
      case FasePagamento.carregando:
      case FasePagamento.saindo:
        return AppLoading(message: 'comum.carregando'.tr());
      case FasePagamento.erro:
        return _Erro(
          falha: falhaCarga,
          onTentarNovamente: onTentarNovamente,
          onVoltar: onVoltar,
        );
      case FasePagamento.expirada:
        if (r == null) return AppLoading(message: 'comum.carregando'.tr());
        return _ConteudoExpirado(
          reserva: r,
          pagamento: p,
          quadra: quadra,
          onEscolherOutroHorario: onEscolherOutroHorario,
          onVoltar: onVoltar,
        );
      case FasePagamento.aguardando:
        if (r == null || p == null) {
          return AppLoading(message: 'comum.carregando'.tr());
        }
        return _ConteudoAguardando(
          reserva: r,
          pagamento: p,
          quadra: quadra,
          restante: restante,
          progresso: progresso,
          statusVerificacao: statusVerificacao,
          verificacaoManual: verificacaoManual,
          simulando: simulando,
          copiado: copiado,
          mostrarSimulacao: mostrarSimulacao,
          onCopiar: onCopiar,
          onJaRealizei: onJaRealizei,
          onSimular: onSimular,
          onVoltar: onVoltar,
          onCancelar: onCancelar,
        );
    }
  }
}

// ── Apoio ────────────────────────────────────────────────────────────────────

/// `#RES-<id>`.
String _codigo(int id) => '#RES-$id';

/// "Sáb, 26 de outubro".
String _diaCurto(DateTime instante) {
  final parede = Brasilia.parede(instante);
  final dia = DateFormat.E().format(parede).replaceAll('.', '');
  final diaMaiusculo =
      dia.isEmpty ? dia : '${dia[0].toUpperCase()}${dia.substring(1)}';
  return 'pagamento.data_resumo'.tr(
    namedArgs: {'dia': diaMaiusculo, 'data': DateFormat.MMMMd().format(parede)},
  );
}

String _minutos(Reserva r) => '${r.fim.difference(r.inicio).inMinutes}';

/// QR legível também no tema escuro: módulos escuros sobre fundo claro, com
/// os tokens do esquema claro.
final Color _fundoQr = appLightColorScheme.surfaceContainerLowest;
final Color _moduloQr = appLightColorScheme.onSurface;

/// Texto com trechos em negrito marcados por `**` (vindos da tradução).
class _TextoComNegrito extends StatelessWidget {
  const _TextoComNegrito(this.texto, {this.style, this.estiloNegrito});

  final String texto;
  final TextStyle? style;
  final TextStyle? estiloNegrito;

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
    );
  }
}

class _Cartao extends StatelessWidget {
  const _Cartao({required this.child, this.cor, this.padding});

  final Widget child;
  final Color? cor;
  final EdgeInsetsGeometry? padding;

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

class _Pilula extends StatelessWidget {
  const _Pilula({
    required this.texto,
    required this.fundo,
    required this.frente,
    this.icone,
    this.maiusculas = false,
  });

  final String texto;
  final Color fundo;
  final Color frente;
  final IconData? icone;
  final bool maiusculas;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: fundo, borderRadius: AppBorders.full),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icone != null) ...[
              Icon(icone, size: AppSpacing.s14, color: frente),
              SizedBox(width: AppSpacing.xs),
            ],
            Flexible(
              child: Text(
                maiusculas ? texto.toUpperCase() : texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.labelSmall?.copyWith(
                  color: frente,
                  fontWeight: maiusculas ? FontWeight.w600 : null,
                  letterSpacing: maiusculas ? 0.8 : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botão largo (`h-12 rounded-xl`) com ícone ou indicador.
class _Botao extends StatelessWidget {
  const _Botao({
    required this.rotulo,
    required this.fundo,
    required this.frente,
    required this.onPressed,
    this.icone,
    this.corIcone,
    this.girando = false,
    this.estilo,
  });

  final String rotulo;
  final Color fundo;
  final Color frente;
  final VoidCallback? onPressed;
  final IconData? icone;
  final Color? corIcone;
  final bool girando;
  final TextStyle? estilo;

  @override
  Widget build(BuildContext context) {
    final style =
        (estilo ?? context.textTheme.labelLarge)?.copyWith(color: frente);
    Widget? iconeWidget;
    if (icone != null) {
      iconeWidget = Icon(icone, size: AppSpacing.ml, color: corIcone ?? frente);
      if (girando) {
        iconeWidget = iconeWidget
            .animate(onPlay: (c) => c.repeat())
            .rotate(duration: AppDurations.shimmer);
      }
    }
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: fundo,
        foregroundColor: frente,
        disabledBackgroundColor: fundo,
        disabledForegroundColor: frente.withValues(alpha: 0.8),
        minimumSize: const Size.fromHeight(kMinInteractiveDimension),
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
        shape: const RoundedRectangleBorder(borderRadius: AppBorders.md),
        elevation: 0,
        textStyle: style,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconeWidget != null) ...[
            iconeWidget,
            SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Text(
              rotulo,
              style: style,
              maxLines: 2,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Aguardando pagamento ─────────────────────────────────────────────────────

class _ConteudoAguardando extends StatelessWidget {
  const _ConteudoAguardando({
    required this.reserva,
    required this.pagamento,
    required this.quadra,
    required this.restante,
    required this.progresso,
    required this.statusVerificacao,
    required this.verificacaoManual,
    required this.simulando,
    required this.copiado,
    required this.mostrarSimulacao,
    required this.onCopiar,
    required this.onJaRealizei,
    required this.onSimular,
    required this.onVoltar,
    required this.onCancelar,
  });

  final Reserva reserva;
  final Pagamento pagamento;
  final Quadra? quadra;
  final ReadonlySignal<Duration> restante;
  final ReadonlySignal<double> progresso;
  final StatusVerificacao statusVerificacao;
  final VerificacaoManual verificacaoManual;
  final bool simulando;
  final bool copiado;
  final bool mostrarSimulacao;
  final VoidCallback onCopiar;
  final VoidCallback onJaRealizei;
  final VoidCallback onSimular;
  final VoidCallback onVoltar;
  final VoidCallback onCancelar;

  @override
  Widget build(BuildContext context) {
    final espaco = SizedBox(height: AppSpacing.md);
    final valor = Formatadores.moeda(pagamento.valor);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        _CartaoContador(restante: restante, progresso: progresso),
        espaco,
        _CartaoResumo(reserva: reserva, quadra: quadra, valor: valor),
        espaco,
        _CartaoQr(
          pagamento: pagamento,
          valor: valor,
          statusVerificacao: statusVerificacao,
        ),
        espaco,
        _CartaoCopiaECola(
          codigo: pagamento.pixCopiaECola ?? '',
          copiado: copiado,
          onCopiar: onCopiar,
        ),
        espaco,
        _ComoPagar(valor: valor),
        SizedBox(height: AppSpacing.lg),
        _Acoes(
          verificacaoManual: verificacaoManual,
          simulando: simulando,
          mostrarSimulacao: mostrarSimulacao,
          onJaRealizei: onJaRealizei,
          onSimular: onSimular,
          onVoltar: onVoltar,
          onCancelar: onCancelar,
        ),
      ],
    );
  }
}

class _CartaoContador extends StatelessWidget {
  const _CartaoContador({required this.restante, required this.progresso});

  final ReadonlySignal<Duration> restante;
  final ReadonlySignal<double> progresso;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    return _Cartao(
      cor: cs.surfaceContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.timer, size: AppSpacing.ml, color: cs.tertiary),
              SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'pagamento.tempo_para_pagamento'.tr().toUpperCase(),
                  style: tt.labelMedium?.copyWith(
                    color: cs.tertiary,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              // O valor muda a cada segundo; o leitor de tela recebe só os
              // anúncios de 5 min, 1 min e zero (feitos pelo contêiner).
              ExcludeSemantics(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.tertiaryFixed,
                    borderRadius: AppBorders.full,
                    boxShadow: AppShadows.subtle,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xxs,
                    ),
                    child: SignalBuilder(
                      builder: (context) => Text(
                        formatarContadorPix(restante.value),
                        style: tt.headlineSmall?.copyWith(
                          color: cs.onTertiaryFixed,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: AppBorders.full,
              child: SignalBuilder(
                builder: (context) => LinearProgressIndicator(
                  value: progresso.value,
                  minHeight: AppSpacing.sm,
                  color: cs.tertiary,
                  backgroundColor: cs.surfaceContainerHighest,
                ),
              ),
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'pagamento.aviso_prazo'.tr(),
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _CartaoResumo extends StatelessWidget {
  const _CartaoResumo({
    required this.reserva,
    required this.quadra,
    required this.valor,
  });

  final Reserva reserva;
  final Quadra? quadra;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final esporte = quadra?.tipoEsporte;
    final linha = tt.bodySmall?.copyWith(color: cs.onSurfaceVariant);
    return _Cartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _codigo(reserva.id),
                  style: tt.labelSmall?.copyWith(
                    color: cs.outline,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Flexible(
                child: _Pilula(
                  texto: 'pagamento.aguardando_pagamento'.tr(),
                  icone: Icons.schedule,
                  fundo: cs.tertiary.withValues(alpha: 0.1),
                  frente: cs.tertiary,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.ms),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox.square(
                dimension: AppSpacing.xl + AppSpacing.sm,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: AppBorders.sm,
                  ),
                  child: Icon(
                    esporte?.icone ?? TipoEsporte.outro.icone,
                    size: AppSpacing.lg,
                    color: cs.primary,
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reserva.quadraNome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleMedium?.copyWith(color: cs.onSurface),
                    ),
                    if (esporte != null)
                      Text(esporte.rotuloKey.tr(), style: linha),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.ms),
          DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: AppBorders.sm,
            ),
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: AppSpacing.md + AppSpacing.xxs,
                    color: cs.primary,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _TextoComNegrito(
                      'pagamento.linha_horario'.tr(
                        namedArgs: {
                          'data': _diaCurto(reserva.inicio),
                          'faixa': Formatadores.faixaHorario(
                            reserva.inicio,
                            reserva.fim,
                          ),
                          'min': _minutos(reserva),
                        },
                      ),
                      style: linha,
                      estiloNegrito: linha?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: AppSpacing.ms),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  'pagamento.valor_total'.tr(),
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              Text(
                valor,
                style: tt.headlineMedium?.copyWith(color: cs.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CartaoQr extends StatelessWidget {
  const _CartaoQr({
    required this.pagamento,
    required this.valor,
    required this.statusVerificacao,
  });

  final Pagamento pagamento;
  final String valor;
  final StatusVerificacao statusVerificacao;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final tamanhoQr = AppSpacing.xxxl * 3;
    final (iconeStatus, textoStatus) = switch (statusVerificacao) {
      StatusVerificacao.ok => (null, null),
      StatusVerificacao.semConexao => (
          Icons.cloud_off_outlined,
          'pagamento.status_sem_conexao'.tr(),
        ),
      StatusVerificacao.falha => (
          Icons.sync_problem,
          'pagamento.status_falha'.tr(),
        ),
    };

    return _Cartao(
      child: Column(
        children: [
          _Pilula(
            texto: pagamento.provedor.rotuloKey.tr(),
            icone: Icons.terminal,
            fundo: cs.secondaryContainer,
            frente: cs.onSecondaryContainer,
          ),
          SizedBox(height: AppSpacing.md),
          Semantics(
            container: true,
            image: true,
            label: 'pagamento.qr_semantica'.tr(namedArgs: {'valor': valor}),
            child: ExcludeSemantics(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _fundoQr,
                  borderRadius: AppBorders.md,
                  boxShadow: AppShadows.card,
                ),
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: QrImageView(
                    data: pagamento.pixCopiaECola ?? '',
                    size: tamanhoQr,
                    padding: EdgeInsets.zero,
                    backgroundColor: _fundoQr,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                    eyeStyle: QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: _moduloQr,
                    ),
                    dataModuleStyle: QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: _moduloQr,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'pagamento.qr_legenda'.tr(),
            textAlign: TextAlign.center,
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          if (textoStatus != null) ...[
            SizedBox(height: AppSpacing.sm),
            Semantics(
              liveRegion: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(iconeStatus, size: AppSpacing.md, color: cs.error),
                  SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      textoStatus,
                      textAlign: TextAlign.center,
                      style: tt.labelMedium?.copyWith(color: cs.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CartaoCopiaECola extends StatelessWidget {
  const _CartaoCopiaECola({
    required this.codigo,
    required this.copiado,
    required this.onCopiar,
  });

  final String codigo;
  final bool copiado;
  final VoidCallback onCopiar;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    return _Cartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.content_copy_outlined,
                  size: AppSpacing.ml, color: cs.primary),
              SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'pagamento.copia_e_cola_titulo'.tr(),
                  style: tt.titleSmall?.copyWith(color: cs.onSurface),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: AppBorders.sm,
            ),
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.sm),
              child: Text(
                codigo,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          _Botao(
            rotulo: copiado
                ? 'pagamento.codigo_copiado'.tr()
                : 'pagamento.copiar_codigo'.tr(),
            icone: copiado ? Icons.check : Icons.content_copy_outlined,
            fundo: cs.primary.withValues(alpha: 0.1),
            frente: cs.primary,
            onPressed: onCopiar,
          ),
          if (copiado) ...[
            SizedBox(height: AppSpacing.sm),
            Semantics(
              liveRegion: true,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: AppBorders.sm,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.s6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle,
                          size: AppSpacing.md, color: cs.onPrimary),
                      SizedBox(width: AppSpacing.s6),
                      Flexible(
                        child: Text(
                          'pagamento.copiado_area_transferencia'.tr(),
                          style: tt.labelSmall?.copyWith(color: cs.onPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ComoPagar extends StatelessWidget {
  const _ComoPagar({required this.valor});

  final String valor;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final corpo = tt.bodyMedium?.copyWith(color: cs.onSurface);
    final passos = [
      ('pagamento.passo_1'.tr(), null),
      ('pagamento.passo_2'.tr(), null),
      ('pagamento.passo_3'.tr(), null),
      (
        'pagamento.passo_4'.tr(namedArgs: {'valor': valor}),
        corpo?.copyWith(color: cs.primary, fontWeight: FontWeight.w600),
      ),
    ];
    return _Cartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'pagamento.como_pagar'.tr(),
              style: tt.titleMedium?.copyWith(color: cs.onSurface),
            ),
          ),
          for (var i = 0; i < passos.length; i++) ...[
            SizedBox(height: i == 0 ? AppSpacing.sm : AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox.square(
                  dimension: AppSpacing.lg,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: tt.labelMedium?.copyWith(color: cs.onSurface),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _TextoComNegrito(
                    passos[i].$1,
                    style: corpo,
                    estiloNegrito: passos[i].$2 ??
                        corpo?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Acoes extends StatelessWidget {
  const _Acoes({
    required this.verificacaoManual,
    required this.simulando,
    required this.mostrarSimulacao,
    required this.onJaRealizei,
    required this.onSimular,
    required this.onVoltar,
    required this.onCancelar,
  });

  final VerificacaoManual verificacaoManual;
  final bool simulando;
  final bool mostrarSimulacao;
  final VoidCallback onJaRealizei;
  final VoidCallback onSimular;
  final VoidCallback onVoltar;
  final VoidCallback onCancelar;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final (rotulo, icone) = switch (verificacaoManual) {
      VerificacaoManual.ociosa => (
          'pagamento.ja_realizei'.tr(),
          Icons.verified_outlined,
        ),
      VerificacaoManual.verificando => (
          'pagamento.verificando'.tr(),
          Icons.sync,
        ),
      VerificacaoManual.aguardandoCompensacao => (
          'pagamento.aguardando_compensacao'.tr(),
          Icons.hourglass_empty,
        ),
    };
    final ociosa = verificacaoManual == VerificacaoManual.ociosa;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: !ociosa,
          child: _Botao(
            rotulo: rotulo,
            icone: icone,
            girando: verificacaoManual == VerificacaoManual.verificando,
            fundo: cs.primary,
            frente: cs.onPrimary,
            onPressed: ociosa ? onJaRealizei : null,
          ),
        ),
        if (mostrarSimulacao) ...[
          SizedBox(height: AppSpacing.sm),
          _Botao(
            rotulo: simulando
                ? 'pagamento.simulando'.tr()
                : 'pagamento.simular'.tr(),
            icone: simulando ? Icons.sync : Icons.developer_mode,
            corIcone: simulando ? null : cs.tertiary,
            girando: simulando,
            fundo: cs.surfaceContainer,
            frente: cs.onSurfaceVariant,
            estilo: tt.labelMedium,
            onPressed: simulando ? null : onSimular,
          ),
        ],
        SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: onVoltar,
          style: TextButton.styleFrom(
            foregroundColor: cs.secondary,
            minimumSize: const Size.fromHeight(kMinInteractiveDimension),
            textStyle: tt.labelMedium,
          ),
          child: Text('pagamento.voltar_minhas_reservas'.tr()),
        ),
        Text(
          'pagamento.permanecera_pendente'.tr(),
          textAlign: TextAlign.center,
          style: tt.labelSmall?.copyWith(color: cs.outline),
        ),
        SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: onCancelar,
          style: TextButton.styleFrom(
            foregroundColor: cs.secondary,
            minimumSize: const Size.fromHeight(kMinInteractiveDimension),
            textStyle: tt.labelMedium,
            shape: const RoundedRectangleBorder(borderRadius: AppBorders.md),
          ),
          child: Text('pagamento.cancelar_reserva'.tr()),
        ),
      ],
    );
  }
}

// ── Expirado ─────────────────────────────────────────────────────────────────

class _ConteudoExpirado extends StatelessWidget {
  const _ConteudoExpirado({
    required this.reserva,
    required this.pagamento,
    required this.quadra,
    required this.onEscolherOutroHorario,
    required this.onVoltar,
  });

  final Reserva reserva;
  final Pagamento? pagamento;
  final Quadra? quadra;
  final VoidCallback onEscolherOutroHorario;
  final VoidCallback onVoltar;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final expiraEm = pagamento?.expiraEm ?? reserva.expiraEm;
    final esporte = quadra?.tipoEsporte;
    final secao = SizedBox(height: AppSpacing.lg);
    final textoAlerta = tt.bodyMedium
        ?.copyWith(color: cs.onErrorContainer.withValues(alpha: 0.9));

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        Semantics(
          liveRegion: true,
          child: _Cartao(
            cor: cs.errorContainer,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox.square(
                  dimension: AppSpacing.xxl,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.error,
                      shape: BoxShape.circle,
                      boxShadow: AppShadows.card,
                    ),
                    child: Icon(
                      Icons.timer_off,
                      size: AppSpacing.lg + AppSpacing.xs,
                      color: cs.onError,
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'pagamento.expirado_titulo'.tr(),
                        style:
                            tt.titleLarge?.copyWith(color: cs.onErrorContainer),
                      ),
                      SizedBox(height: AppSpacing.xs),
                      _TextoComNegrito(
                        expiraEm == null
                            ? 'pagamento.expirado_texto_sem_hora'.tr()
                            : 'pagamento.expirado_texto'.tr(
                                namedArgs: {
                                  'hora': Formatadores.hora(expiraEm),
                                },
                              ),
                        style: textoAlerta,
                        estiloNegrito:
                            tt.titleSmall?.copyWith(color: cs.onErrorContainer),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        secao,
        _Cartao(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'pagamento.codigo_reserva'.tr(),
                          style: tt.labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        Text(
                          _codigo(reserva.id),
                          style: tt.titleSmall?.copyWith(
                            color: cs.onSurface,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: _Pilula(
                      texto: 'pagamento.expirado'.tr(),
                      icone: Icons.cancel_outlined,
                      fundo: cs.errorContainer,
                      frente: cs.onErrorContainer,
                      maiusculas: true,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Divider(
                  height: 1,
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: AppBorders.sm,
                    child: SizedBox.square(
                      dimension: AppSpacing.xxxl + AppSpacing.md,
                      child: _Miniatura(quadra: quadra),
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reserva.quadraNome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.titleMedium?.copyWith(color: cs.onSurface),
                        ),
                        if (esporte != null) ...[
                          SizedBox(height: AppSpacing.xxs),
                          Row(
                            children: [
                              Icon(esporte.icone,
                                  size: AppSpacing.md, color: cs.primary),
                              SizedBox(width: AppSpacing.xs),
                              Flexible(
                                child: Text(
                                  esporte.rotuloKey.tr(),
                                  style: tt.bodySmall
                                      ?.copyWith(color: cs.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                        ],
                        SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: AppSpacing.md,
                              color: cs.secondary,
                            ),
                            SizedBox(width: AppSpacing.xs),
                            Flexible(
                              child: Text(
                                '${_diaCurto(reserva.inicio)} • '
                                '${Formatadores.faixaHorario(reserva.inicio, reserva.fim)}',
                                style: tt.bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.md),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: AppBorders.sm,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'pagamento.valor_total'.tr(),
                          style: tt.bodyMedium
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ),
                      Text(
                        Formatadores.moeda(reserva.valor),
                        style: tt.headlineSmall?.copyWith(color: cs.onSurface),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        secao,
        _Cartao(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: AppBorders.full,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.ms,
                    vertical: AppSpacing.s6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule,
                        size: AppSpacing.md + AppSpacing.xxs,
                        color: cs.onSurfaceVariant,
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Text(
                        formatarContadorPix(Duration.zero),
                        style: tt.labelLarge?.copyWith(
                          color: cs.error,
                          letterSpacing: 1.6,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          '• ${'pagamento.expirado'.tr()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.md),
              const _QrDesativado(),
              SizedBox(height: AppSpacing.md),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh.withValues(alpha: 0.6),
                  borderRadius: AppBorders.sm,
                ),
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: AppSpacing.ml, color: cs.secondary),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'pagamento.nao_transfira'.tr(),
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        secao,
        _Botao(
          rotulo: 'pagamento.escolher_outro_horario'.tr(),
          icone: Icons.event_available_outlined,
          fundo: cs.primary,
          frente: cs.onPrimary,
          onPressed: onEscolherOutroHorario,
        ),
        SizedBox(height: AppSpacing.sm),
        _Botao(
          rotulo: 'pagamento.voltar_minhas_reservas'.tr(),
          icone: Icons.calendar_month_outlined,
          fundo: cs.surfaceContainer,
          frente: cs.onSurface,
          onPressed: onVoltar,
        ),
      ],
    );
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.quadra});

  final Quadra? quadra;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final placeholder = ColoredBox(
      color: cs.surfaceContainerHigh,
      child: Icon(
        quadra?.tipoEsporte.icone ?? TipoEsporte.outro.icone,
        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    );
    final url = quadra?.fotoUrl?.trim();
    if (url == null || url.isEmpty) return placeholder;
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (context, url) => placeholder,
      errorWidget: (context, url, error) => placeholder,
    );
  }
}

/// Bloco do QR desativado: padrão decorativo (nunca o QR real) com a
/// sobreposição "Código Pix Cancelado".
class _QrDesativado extends StatelessWidget {
  const _QrDesativado();

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final lado = AppSpacing.xxxl * 3 + AppSpacing.xl;
    return SizedBox.square(
      dimension: lado,
      child: ClipRRect(
        borderRadius: AppBorders.md,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: cs.surfaceContainer),
            Padding(
              padding: EdgeInsets.all(AppSpacing.ms),
              child: Opacity(
                opacity: 0.15,
                child: CustomPaint(
                  painter: _PadraoQrDecorativo(cor: cs.onSurface),
                ),
              ),
            ),
            ColoredBox(
              color: cs.surfaceDim.withValues(alpha: 0.8),
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox.square(
                      dimension: AppSpacing.xxl + AppSpacing.sm,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          shape: BoxShape.circle,
                          boxShadow: AppShadows.card,
                        ),
                        child: Icon(Icons.block,
                            size: AppSpacing.xl, color: cs.error),
                      ),
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Text(
                      'pagamento.codigo_cancelado'.tr(),
                      textAlign: TextAlign.center,
                      style: tt.titleSmall?.copyWith(color: cs.onSurface),
                    ),
                    SizedBox(height: AppSpacing.xxs),
                    Text(
                      'pagamento.invalido_para_pagamento'.tr(),
                      textAlign: TextAlign.center,
                      style:
                          tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Padrão decorativo com cara de QR (três marcadores e alguns módulos) numa
/// grade de 21 x 21. Não codifica nada.
class _PadraoQrDecorativo extends CustomPainter {
  const _PadraoQrDecorativo({required this.cor});

  final Color cor;

  static const int _grade = 21;

  /// Módulos (coluna, linha) fora dos marcadores.
  static const List<(int, int)> _modulos = [
    (9, 1),
    (11, 1),
    (9, 3),
    (10, 3),
    (12, 4),
    (8, 5),
    (11, 6),
    (1, 9),
    (3, 9),
    (5, 10),
    (2, 11),
    (4, 12),
    (9, 9),
    (10, 9),
    (11, 9),
    (9, 10),
    (11, 10),
    (9, 11),
    (10, 11),
    (11, 11),
    (14, 9),
    (16, 10),
    (19, 9),
    (15, 12),
    (18, 12),
    (9, 14),
    (12, 15),
    (10, 17),
    (13, 18),
    (9, 19),
    (15, 15),
    (17, 16),
    (19, 17),
    (16, 19),
    (18, 19),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final celula = size.shortestSide / _grade;
    final cheio = Paint()..color = cor;

    void marcador(int col, int lin) {
      final origem = Offset(col * celula, lin * celula);
      final contorno = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(origem & Size.square(celula * 7))
        ..addRect((origem + Offset(celula, celula)) & Size.square(celula * 5));
      canvas
        ..drawPath(contorno, cheio)
        ..drawRect(
          (origem + Offset(celula * 2, celula * 2)) & Size.square(celula * 3),
          cheio,
        );
    }

    marcador(0, 0);
    marcador(_grade - 7, 0);
    marcador(0, _grade - 7);
    for (final (col, lin) in _modulos) {
      canvas.drawRect(
        Offset(col * celula, lin * celula) & Size.square(celula),
        cheio,
      );
    }
  }

  @override
  bool shouldRepaint(_PadraoQrDecorativo oldDelegate) => oldDelegate.cor != cor;
}

// ── Erro ─────────────────────────────────────────────────────────────────────

class _Erro extends StatelessWidget {
  const _Erro({
    required this.falha,
    required this.onTentarNovamente,
    required this.onVoltar,
  });

  final Failure? falha;
  final VoidCallback onTentarNovamente;
  final VoidCallback onVoltar;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final semRede = falha is NetworkFailure;
    final titulo = semRede
        ? 'pagamento.erro_sem_conexao'.tr()
        : 'pagamento.erro_titulo'.tr();
    final mensagem = semRede ? null : falha?.message;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: AppSpacing.xxxl,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  semRede ? Icons.cloud_off_outlined : Icons.qr_code_2,
                  size: AppSpacing.xl,
                  color: cs.onErrorContainer,
                ),
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
                mensagem,
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(color: cs.secondary),
              ),
            ],
            SizedBox(height: AppSpacing.lg),
            _Botao(
              rotulo: 'comum.tentar_novamente'.tr(),
              icone: Icons.refresh,
              fundo: cs.primary,
              frente: cs.onPrimary,
              onPressed: onTentarNovamente,
            ),
            SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: onVoltar,
              style: TextButton.styleFrom(
                foregroundColor: cs.secondary,
                minimumSize: const Size.fromHeight(kMinInteractiveDimension),
                textStyle: tt.labelMedium,
              ),
              child: Text('pagamento.voltar_minhas_reservas'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
