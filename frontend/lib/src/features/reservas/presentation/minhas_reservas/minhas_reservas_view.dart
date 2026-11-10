import 'dart:ui' show SemanticsRole;

import 'package:so_mais_uma/src/imports/imports.dart';

import 'abas_reservas.dart';
import 'componentes_reserva.dart';

/// MinhasReservas (`minhas_reservas/code.html`), sem estado.
class MinhasReservasView extends StatelessWidget {
  const MinhasReservasView({
    super.key,
    required this.estado,
    required this.aba,
    required this.abas,
    required this.quadras,
    required this.agora,
    required this.onAtualizar,
    required this.onTentarNovamente,
    required this.onSelecionarAba,
    required this.onVerTodoHistorico,
    required this.onPagar,
    required this.onDetalhes,
    required this.onComoChegar,
    required this.onEncontrarQuadras,
  });

  final RequestState<List<Reserva>> estado;
  final AbaReservas aba;
  final AbasReservas abas;
  final Map<int, Quadra> quadras;

  /// "Agora" a cada segundo, lido só pelo contador dos cards pendentes.
  final ReadonlySignal<DateTime> agora;
  final Future<void> Function() onAtualizar;
  final VoidCallback onTentarNovamente;
  final ValueChanged<AbaReservas> onSelecionarAba;
  final VoidCallback onVerTodoHistorico;
  final ValueChanged<Reserva> onPagar;
  final ValueChanged<Reserva> onDetalhes;
  final ValueChanged<Reserva> onComoChegar;
  final VoidCallback onEncontrarQuadras;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BarraSuperior(
        sobretitulo: 'comum.app_nome'.tr(),
        titulo: 'reservas.minhas.titulo'.tr(),
        mostrarVoltar: false,
      ),
      body: switch (estado) {
        RequestInitial() || RequestLoading() => const _Carregando(),
        RequestFailure(:final failure) => EstadoErroReservas(
            titulo: 'reservas.minhas.erro_titulo'.tr(),
            mensagem: failure.message,
            icone: failure is NetworkFailure
                ? Icons.cloud_off_outlined
                : Icons.error_outline,
            rotuloAcao: 'comum.tentar_novamente'.tr(),
            onAcao: onTentarNovamente,
          ),
        RequestSuccess() => RefreshIndicator(
            onRefresh: onAtualizar,
            color: context.colors.primary,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              children: _conteudo(context),
            ),
          ),
      },
    );
  }

  List<Widget> _conteudo(BuildContext context) {
    final espaco = SizedBox(height: AppSpacing.md);
    final cards = <Widget>[];
    if (aba == AbaReservas.proximas) {
      if (abas.proximas.isEmpty) {
        cards.add(_VazioAba(
          icone: Icons.event_available_outlined,
          titulo: 'reservas.minhas.vazio_proximas'.tr(),
          rotuloAcao: 'reservas.minhas.encontrar_quadra'.tr(),
          onAcao: onEncontrarQuadras,
        ));
      } else {
        for (final r in abas.proximas) {
          cards
            ..add(_CardReserva(
              reserva: r,
              quadra: quadras[r.quadraId],
              agora: agora,
              onPagar: () => onPagar(r),
              onDetalhes: () => onDetalhes(r),
              onComoChegar: () => onComoChegar(r),
            ))
            ..add(espaco);
        }
        cards.removeLast();
      }
      if (abas.historico.isNotEmpty) {
        cards
          ..add(SizedBox(height: AppSpacing.lg))
          ..add(_TituloHistoricoRecente(
            total: abas.historico.length,
            onVerTodos: onVerTodoHistorico,
          ))
          ..add(SizedBox(height: AppSpacing.sm));
        for (final r in abas.historico.take(3)) {
          cards
            ..add(_ItemHistorico(
              reserva: r,
              quadra: quadras[r.quadraId],
              agora: agora.value,
              onTap: () => onDetalhes(r),
            ))
            ..add(SizedBox(height: AppSpacing.sm));
        }
        cards.removeLast();
      }
    } else {
      if (abas.historico.isEmpty) {
        cards.add(_VazioAba(
          icone: Icons.history,
          titulo: 'reservas.minhas.vazio_historico'.tr(),
        ));
      } else {
        for (final r in abas.historico) {
          cards
            ..add(_ItemHistorico(
              reserva: r,
              quadra: quadras[r.quadraId],
              agora: agora.value,
              onTap: () => onDetalhes(r),
            ))
            ..add(SizedBox(height: AppSpacing.sm));
        }
        cards.removeLast();
      }
    }

    return [
      const _Cabecalho(),
      espaco,
      _AbasSegmentadas(
        aba: aba,
        proximas: abas.proximas.length,
        historico: abas.historico.length,
        onSelecionar: onSelecionarAba,
      ),
      espaco,
      ...cards,
      SizedBox(height: AppSpacing.lg),
      _CartaoNovaPartida(onEncontrar: onEncontrarQuadras),
    ];
  }
}

// ── Cabeçalho e abas ─────────────────────────────────────────────────────────

class _Cabecalho extends StatelessWidget {
  const _Cabecalho();

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            'reservas.minhas.titulo'.tr(),
            style: tt.headlineSmall?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(height: AppSpacing.xs),
        Text(
          'reservas.minhas.subtitulo'.tr(),
          style: tt.bodyMedium?.copyWith(color: cs.secondary),
        ),
      ],
    );
  }
}

class _AbasSegmentadas extends StatelessWidget {
  const _AbasSegmentadas({
    required this.aba,
    required this.proximas,
    required this.historico,
    required this.onSelecionar,
  });

  final AbaReservas aba;
  final int proximas;
  final int historico;
  final ValueChanged<AbaReservas> onSelecionar;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHigh,
        borderRadius: AppBorders.md,
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xs),
        child: Semantics(
          role: SemanticsRole.tabBar,
          container: true,
          explicitChildNodes: true,
          child: Row(
            children: [
              Expanded(
                child: _Aba(
                  rotulo: 'reservas.minhas.aba_proximas'.tr(),
                  contador: proximas,
                  selecionada: aba == AbaReservas.proximas,
                  onTap: () => onSelecionar(AbaReservas.proximas),
                ),
              ),
              Expanded(
                child: _Aba(
                  rotulo: 'reservas.minhas.aba_historico'.tr(),
                  contador: historico,
                  selecionada: aba == AbaReservas.historico,
                  onTap: () => onSelecionar(AbaReservas.historico),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Aba extends StatelessWidget {
  const _Aba({
    required this.rotulo,
    required this.contador,
    required this.selecionada,
    required this.onTap,
  });

  final String rotulo;
  final int contador;
  final bool selecionada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    return Semantics(
      role: SemanticsRole.tab,
      selected: selecionada,
      label: 'reservas.minhas.aba_semantica'
          .tr(namedArgs: {'aba': rotulo, 'n': '$contador'}),
      onTap: onTap,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppDurations.quick,
        decoration: BoxDecoration(
          color: selecionada ? cs.surfaceContainerLowest : Colors.transparent,
          borderRadius: AppBorders.sm,
          boxShadow: selecionada ? AppShadows.subtle : AppShadows.none,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: AppBorders.sm,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: kMinInteractiveDimension,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      rotulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleSmall?.copyWith(
                        color: selecionada ? cs.primary : cs.secondary,
                        fontWeight:
                            selecionada ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: AppSpacing.ml,
                      minHeight: AppSpacing.ml,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: selecionada
                            ? cs.primary
                            : cs.surfaceContainerHighest,
                        borderRadius: AppBorders.full,
                      ),
                      child: Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: AppSpacing.s6),
                        child: Center(
                          widthFactor: 1,
                          child: Text(
                            '$contador',
                            style: tt.labelSmall?.copyWith(
                              color: selecionada
                                  ? cs.onPrimary
                                  : cs.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
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

// ── Cards ────────────────────────────────────────────────────────────────────

/// "Hoje, 24 de outubro", "Amanhã, 25 de outubro" ou "Sábado, 26 de outubro".
String _rotuloDia(DateTime inicio, DateTime agora) {
  final dia = Brasilia.dia(inicio);
  final hoje = Brasilia.dia(agora);
  final diaMes = DateFormat.MMMMd().format(Brasilia.parede(inicio));
  if (dia == hoje) return '${'comum.hoje'.tr()}, $diaMes';
  if (dia == hoje.add(const Duration(days: 1))) {
    return '${'comum.amanha'.tr()}, $diaMes';
  }
  return Formatadores.dataSemAno(inicio);
}

class _CardReserva extends StatelessWidget {
  const _CardReserva({
    required this.reserva,
    required this.quadra,
    required this.agora,
    required this.onPagar,
    required this.onDetalhes,
    required this.onComoChegar,
  });

  final Reserva reserva;
  final Quadra? quadra;
  final ReadonlySignal<DateTime> agora;
  final VoidCallback onPagar;
  final VoidCallback onDetalhes;
  final VoidCallback onComoChegar;

  bool get _pendente => reserva.status == StatusReserva.pendentePagamento;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final agoraInicial = agora.value;
    final dia = _rotuloDia(reserva.inicio, agoraInicial);
    final faixa = Formatadores.faixaHorario(reserva.inicio, reserva.fim);
    final esporte = quadra?.tipoEsporte;
    final situacao = SituacaoReserva.de(reserva, agoraInicial);

    final resumo = [
      reserva.quadraNome,
      situacao.rotuloKey.tr(),
      dia,
      faixa,
      Formatadores.moeda(reserva.valor),
    ].join(', ');

    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: AppBorders.lg,
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: cs.surfaceContainerLowest,
        borderRadius: AppBorders.lg,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              label: resumo,
              onTap: onDetalhes,
              excludeSemantics: true,
              child: InkWell(
                onTap: onDetalhes,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: AppSpacing.xxxl * 2,
                      child: _ImagemCard(
                        reserva: reserva,
                        quadra: quadra,
                        agora: agora,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.md,
                        0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  reserva.quadraNome,
                                  style: tt.titleMedium?.copyWith(
                                    color: cs.onSurface,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (reserva.status ==
                                  StatusReserva.confirmada) ...[
                                SizedBox(width: AppSpacing.sm),
                                Flexible(
                                  child: Pilula(
                                    texto: 'reservas.minhas.pago_via_pix'.tr(),
                                    fundo: cs.surfaceContainer,
                                    frente: cs.secondary,
                                    raio: AppBorders.xs,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (esporte != null)
                            Text(
                              esporte.rotuloKey.tr(),
                              style:
                                  tt.bodySmall?.copyWith(color: cs.secondary),
                            ),
                          SizedBox(height: AppSpacing.ms),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: AppSpacing.sm,
                            children: [
                              Icon(
                                _pendente
                                    ? Icons.calendar_today_outlined
                                    : Icons.calendar_month_outlined,
                                size: AppSpacing.ml,
                                color: cs.primary,
                              ),
                              Text(
                                dia,
                                style: tt.labelMedium
                                    ?.copyWith(color: cs.onSurface),
                              ),
                              Text(
                                '•',
                                style: tt.labelMedium
                                    ?.copyWith(color: cs.outlineVariant),
                              ),
                              Text(
                                faixa,
                                style:
                                    tt.labelMedium?.copyWith(color: cs.primary),
                              ),
                            ],
                          ),
                          if (reserva.quadraEndereco != null) ...[
                            SizedBox(height: AppSpacing.s6),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: AppSpacing.ml,
                                  color: cs.secondary,
                                ),
                                SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    reserva.quadraEndereco!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: tt.bodySmall
                                        ?.copyWith(color: cs.secondary),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          SizedBox(height: AppSpacing.ms),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: _pendente
                  ? _acoesPendente(context)
                  : _acoesConfirmada(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _acoesPendente(BuildContext context) {
    final cs = context.colors;
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: SignalBuilder(
            builder: (context) {
              final restante = restantePagamento(reserva, agora.value);
              final expirado = restante != null && restante == Duration.zero;
              return BotaoReserva(
                rotulo: 'reservas.minhas.pagar_agora'.tr(),
                icone: Icons.qr_code_2,
                fundo: cs.primary,
                frente: cs.onPrimary,
                onPressed: expirado ? null : onPagar,
                semanticsLabel: 'reservas.minhas.pagar_agora_semantica'
                    .tr(namedArgs: {'quadra': reserva.quadraNome}),
              );
            },
          ),
        ),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 2,
          child: BotaoReserva(
            rotulo: 'reservas.minhas.ver_detalhes'.tr(),
            fundo: cs.surfaceContainerHigh,
            frente: cs.onSurface,
            estilo: context.textTheme.labelMedium,
            onPressed: onDetalhes,
          ),
        ),
      ],
    );
  }

  Widget _acoesConfirmada(BuildContext context) {
    final cs = context.colors;
    return Row(
      children: [
        Expanded(
          child: BotaoReserva(
            rotulo: 'reservas.minhas.ver_detalhes'.tr(),
            icone: Icons.receipt_long_outlined,
            fundo: cs.surfaceContainerHigh,
            frente: cs.onSurface,
            estilo: context.textTheme.labelMedium,
            onPressed: onDetalhes,
          ),
        ),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: BotaoReserva(
            rotulo: 'reservas.minhas.como_chegar'.tr(),
            icone: Icons.navigation_outlined,
            fundo: cs.secondaryContainer,
            frente: cs.onSecondaryContainer,
            estilo: context.textTheme.labelMedium,
            onPressed: onComoChegar,
          ),
        ),
      ],
    );
  }
}

class _ImagemCard extends StatelessWidget {
  const _ImagemCard({
    required this.reserva,
    required this.quadra,
    required this.agora,
  });

  final Reserva reserva;
  final Quadra? quadra;
  final ReadonlySignal<DateTime> agora;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final pendente = reserva.status == StatusReserva.pendentePagamento;
    final esporte = quadra?.tipoEsporte;
    final claro = cs.surfaceContainerLowest;

    return Stack(
      fit: StackFit.expand,
      children: [
        ImagemQuadra(
          url: quadra?.fotoUrl,
          icone: esporte?.icone ?? TipoEsporte.outro.icone,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                cs.onSurface.withValues(alpha: 0.8),
                cs.onSurface.withValues(alpha: pendente ? 0.3 : 0.2),
                cs.onSurface.withValues(alpha: 0),
              ],
            ),
          ),
        ),
        Positioned(
          top: AppSpacing.ms,
          left: AppSpacing.ms,
          child: pendente
              ? Pilula(
                  texto: 'reservas.minhas.aguardando_pagamento'.tr(),
                  icone: Icons.hourglass_top,
                  fundo: cs.tertiaryFixed,
                  frente: cs.onTertiaryFixed,
                )
              : Pilula(
                  texto: 'status_reserva.CONFIRMADA'.tr(),
                  icone: Icons.check_circle,
                  fundo: cs.primaryFixed,
                  frente: cs.onPrimaryFixed,
                ),
        ),
        if (pendente)
          Positioned(
            top: AppSpacing.ms,
            right: AppSpacing.ms,
            child: SignalBuilder(
              builder: (context) {
                final restante = restantePagamento(reserva, agora.value);
                if (restante == null) return const SizedBox.shrink();
                final texto = restante == Duration.zero
                    ? 'reservas.minhas.expirado'.tr()
                    : formatarMmSs(restante);
                return Pilula(
                  texto: texto,
                  icone: Icons.timer_outlined,
                  fundo: claro.withValues(alpha: 0.9),
                  frente: cs.error,
                );
              },
            ),
          ),
        Positioned(
          left: AppSpacing.ms,
          right: AppSpacing.ms,
          bottom: AppSpacing.ms,
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: esporte == null
                      ? const SizedBox.shrink()
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            color: claro.withValues(alpha: 0.2),
                            borderRadius: AppBorders.xs,
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xxs,
                            ),
                            child: Text(
                              esporte.rotuloCurtoKey.tr().toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.labelSmall?.copyWith(
                                color: claro,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Text(
                Formatadores.moeda(reserva.valor),
                style: tt.titleLarge?.copyWith(
                  color: claro,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TituloHistoricoRecente extends StatelessWidget {
  const _TituloHistoricoRecente(
      {required this.total, required this.onVerTodos});

  final int total;
  final VoidCallback onVerTodos;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              'reservas.minhas.historico_recente'.tr(),
              style: tt.titleSmall?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        TextButton(
          onPressed: onVerTodos,
          style: TextButton.styleFrom(
            foregroundColor: cs.primary,
            minimumSize: const Size(
              kMinInteractiveDimension,
              kMinInteractiveDimension,
            ),
            textStyle: tt.labelMedium,
          ),
          child: Text(
            'reservas.minhas.ver_todos'.tr(namedArgs: {'n': '$total'}),
          ),
        ),
      ],
    );
  }
}

class _ItemHistorico extends StatelessWidget {
  const _ItemHistorico({
    required this.reserva,
    required this.quadra,
    required this.agora,
    required this.onTap,
  });

  final Reserva reserva;
  final Quadra? quadra;
  final DateTime agora;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final situacao = SituacaoReserva.de(reserva, agora);
    final data =
        '${DateFormat.MMMMd().format(Brasilia.parede(reserva.inicio))} • '
        '${Formatadores.hora(reserva.inicio)}';
    final valor = Formatadores.moeda(reserva.valor);
    final status = situacao.rotuloKey.tr();

    return Semantics(
      button: true,
      label: [reserva.quadraNome, status, data, valor].join(', '),
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: AppBorders.md,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.s14),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: AppSpacing.xxl - AppSpacing.xs,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainer,
                      borderRadius: AppBorders.sm,
                    ),
                    child: Icon(
                      quadra?.tipoEsporte.icone ?? TipoEsporte.outro.icone,
                      size: AppSpacing.lg,
                      color: cs.secondary,
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.ms),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reserva.quadraNome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleSmall?.copyWith(color: cs.onSurface),
                      ),
                      Text(
                        data,
                        style: tt.bodySmall?.copyWith(color: cs.secondary),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        valor,
                        style: tt.labelMedium?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Pilula(
                        texto: status,
                        fundo: cs.surfaceContainerHigh,
                        frente: cs.onSurfaceVariant,
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

// ── Estados e cartão final ───────────────────────────────────────────────────

class _VazioAba extends StatelessWidget {
  const _VazioAba({
    required this.icone,
    required this.titulo,
    this.rotuloAcao,
    this.onAcao,
  });

  final IconData icone;
  final String titulo;
  final String? rotuloAcao;
  final VoidCallback? onAcao;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Icon(icone, size: AppSpacing.xl, color: cs.secondary),
            ),
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: context.textTheme.titleMedium?.copyWith(color: cs.onSurface),
          ),
          if (rotuloAcao != null && onAcao != null) ...[
            SizedBox(height: AppSpacing.md),
            BotaoReserva(
              rotulo: rotuloAcao!,
              icone: Icons.search,
              fundo: cs.primary,
              frente: cs.onPrimary,
              onPressed: onAcao,
            ),
          ],
        ],
      ),
    );
  }
}

class _CartaoNovaPartida extends StatelessWidget {
  const _CartaoNovaPartida({required this.onEncontrar});

  final VoidCallback onEncontrar;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppBorders.lg,
        boxShadow: AppShadows.subtle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withValues(alpha: 0.1),
            cs.surfaceContainerLow,
            cs.surfaceContainer,
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.subtle,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.sm),
                    child: Icon(Icons.sports,
                        size: AppSpacing.lg, color: cs.onPrimary),
                  ),
                ),
                SizedBox(width: AppSpacing.ms),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'reservas.minhas.nova_partida_titulo'.tr(),
                        style: tt.titleSmall?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: AppSpacing.xxs),
                      Text(
                        'reservas.minhas.nova_partida_texto'.tr(),
                        style: tt.bodySmall?.copyWith(color: cs.secondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.ms),
            BotaoReserva(
              rotulo: 'reservas.minhas.encontrar_novas_quadras'.tr(),
              icone: Icons.search,
              fundo: cs.primary,
              frente: cs.onPrimary,
              onPressed: onEncontrar,
            ),
          ],
        ),
      ),
    );
  }
}

class _Carregando extends StatelessWidget {
  const _Carregando();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'comum.carregando'.tr(),
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.all(AppSpacing.md),
        children: [
          const _Cabecalho(),
          SizedBox(height: AppSpacing.md),
          BlocoEsqueleto(altura: AppSpacing.xxl + AppSpacing.sm),
          SizedBox(height: AppSpacing.md),
          for (var i = 0; i < 2; i++) ...[
            BlocoEsqueleto(altura: AppSpacing.xxxl * 4, raio: AppBorders.lg),
            SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}
