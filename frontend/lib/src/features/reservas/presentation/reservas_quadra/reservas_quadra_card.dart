import 'package:so_mais_uma/src/imports/imports.dart';

import 'resumo_do_dia.dart';

/// Card de reserva da ReservasQuadra (`reservas_da_quadra_dono/code.html`).
///
/// Nunca mostra dados de quem pagou o Pix (RN05): só o contato cadastral do
/// cliente. [onCancelar] nulo esconde o botão de cancelar.
class CardReservaDono extends StatelessWidget {
  const CardReservaDono({
    super.key,
    required this.reserva,
    required this.agora,
    this.onLigar,
    this.onWhatsapp,
    this.onCancelar,
  });

  final Reserva reserva;
  final DateTime agora;
  final VoidCallback? onLigar;
  final VoidCallback? onWhatsapp;
  final VoidCallback? onCancelar;

  bool get _encerrada =>
      reserva.status == StatusReserva.cancelada ||
      reserva.status == StatusReserva.expirada;

  String get _nomeCliente {
    final nome = reserva.clienteNome?.trim();
    return (nome == null || nome.isEmpty)
        ? 'reservas.dono.cliente_sem_nome'.tr()
        : nome;
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final barra = switch (reserva.status) {
      StatusReserva.confirmada => cs.primary,
      StatusReserva.pendentePagamento => cs.tertiaryContainer,
      StatusReserva.cancelada => cs.error,
      StatusReserva.expirada => cs.outline,
    };

    final card = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _encerrada
            ? cs.surfaceContainerLow.withValues(alpha: 0.7)
            : cs.surfaceContainerLowest,
        borderRadius: AppBorders.md,
        boxShadow: AppShadows.subtle,
      ),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md + AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Topo(reserva: reserva, agora: agora, encerrada: _encerrada),
                SizedBox(height: _encerrada ? AppSpacing.sm : AppSpacing.ms),
                if (_encerrada)
                  _CorpoEncerrada(reserva: reserva, nomeCliente: _nomeCliente)
                else
                  _CorpoAtiva(
                    reserva: reserva,
                    agora: agora,
                    nomeCliente: _nomeCliente,
                    onLigar: onLigar,
                    onWhatsapp: onWhatsapp,
                    onCancelar: onCancelar,
                  ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: AppSpacing.s6,
            child: ColoredBox(color: barra),
          ),
        ],
      ),
    );

    return Semantics(
      container: true,
      child: _encerrada ? Opacity(opacity: 0.9, child: card) : card,
    );
  }
}

/// Faixa "19:00 – 20:00" + "60 min" (ou "Horário Liberado") + etiqueta.
class _Topo extends StatelessWidget {
  const _Topo({
    required this.reserva,
    required this.agora,
    required this.encerrada,
  });

  final Reserva reserva;
  final DateTime agora;
  final bool encerrada;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final corIcone = switch (reserva.status) {
      StatusReserva.confirmada => cs.primary,
      StatusReserva.pendentePagamento => cs.tertiary,
      StatusReserva.cancelada || StatusReserva.expirada => cs.secondary,
    };
    final minutos = reserva.fim.difference(reserva.inicio).inMinutes;

    // A etiqueta de status ocupa no máximo 45% da linha e quebra o texto;
    // o resto fica para o horário, que encolhe em telas estreitas.
    return LayoutBuilder(
      builder: (context, restricoes) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.s10,
                    vertical: AppSpacing.s6,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainer,
                    borderRadius: AppBorders.sm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule_outlined,
                        size: AppSpacing.ml - AppSpacing.xxs,
                        color: corIcone,
                      ),
                      SizedBox(width: AppSpacing.s6),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            Formatadores.faixaHorario(
                                reserva.inicio, reserva.fim),
                            maxLines: 1,
                            style: tt.titleMedium?.copyWith(
                              color: cs.onSurface,
                              fontWeight:
                                  encerrada ? FontWeight.w600 : FontWeight.w700,
                              decoration:
                                  encerrada ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (encerrada)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: AppBorders.xs,
                    ),
                    child: Text(
                      'reservas.dono.horario_liberado'.tr(),
                      style: tt.labelSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  Text(
                    'reservas.dono.minutos'.tr(args: ['$minutos']),
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: restricoes.maxWidth * 0.45),
            child: _EtiquetaStatus(reserva: reserva, agora: agora),
          ),
        ],
      ),
    );
  }
}

class _EtiquetaStatus extends StatelessWidget {
  const _EtiquetaStatus({required this.reserva, required this.agora});

  final Reserva reserva;
  final DateTime agora;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final (fundo, frente, icone, texto) = switch (reserva.status) {
      StatusReserva.confirmada => (
          cs.primary.withValues(alpha: 0.1),
          cs.primary,
          Icons.check_circle,
          StatusReserva.confirmada.rotuloKey.tr(),
        ),
      StatusReserva.pendentePagamento => (
          cs.tertiaryFixed,
          cs.onTertiaryFixedVariant,
          Icons.timer_outlined,
          reserva.expiraEm == null
              ? 'reservas.dono.status.aguardando_pix_sem_prazo'.tr()
              : 'reservas.dono.status.aguardando_pix'.tr(
                  args: ['${minutosRestantes(reserva.expiraEm!, agora)}'],
                ),
        ),
      StatusReserva.cancelada => (
          cs.errorContainer,
          cs.onErrorContainer,
          Icons.block,
          switch (reserva.canceladoPor) {
            final CanceladoPor por =>
              'reservas.dono.status.cancelada_${por.api}'.tr(),
            null => StatusReserva.cancelada.rotuloKey.tr(),
          },
        ),
      StatusReserva.expirada => (
          cs.surfaceContainerHighest,
          cs.onSurfaceVariant,
          Icons.timer_off_outlined,
          StatusReserva.expirada.rotuloKey.tr(),
        ),
    };

    final etiqueta = Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.s10,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(color: fundo, borderRadius: AppBorders.full),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: AppSpacing.s14, color: frente),
          SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              texto,
              style: context.textTheme.labelSmall?.copyWith(
                color: frente,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    final pulsar = reserva.status == StatusReserva.pendentePagamento &&
        !MediaQuery.of(context).disableAnimations;
    if (!pulsar) return etiqueta;
    return etiqueta
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fade(begin: 1, end: 0.55, duration: AppDurations.shimmer);
  }
}

class _CorpoAtiva extends StatelessWidget {
  const _CorpoAtiva({
    required this.reserva,
    required this.agora,
    required this.nomeCliente,
    this.onLigar,
    this.onWhatsapp,
    this.onCancelar,
  });

  final Reserva reserva;
  final DateTime agora;
  final String nomeCliente;
  final VoidCallback? onLigar;
  final VoidCallback? onWhatsapp;
  final VoidCallback? onCancelar;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final confirmada = reserva.status == StatusReserva.confirmada;
    final (corValor, fundoValor) = confirmada
        ? (cs.primary, cs.primary.withValues(alpha: 0.1))
        : (cs.tertiary, cs.tertiaryFixed.withValues(alpha: 0.6));
    final (iconePagamento, corPagamento, textoPagamento) = confirmada
        ? (
            Icons.credit_score_outlined,
            cs.primary,
            reserva.concluida(agora)
                ? 'reservas.dono.pagamento.concluido'.tr()
                : 'reservas.dono.pagamento.conciliado'.tr(),
          )
        : (
            Icons.qr_code_2,
            cs.tertiaryContainer,
            'reservas.dono.pagamento.pix_gerado'.tr(),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                reserva.quadraNome,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.titleSmall?.copyWith(color: cs.onSurface),
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: fundoValor,
                borderRadius: AppBorders.xs,
              ),
              child: Text(
                Formatadores.moeda(reserva.valor),
                style: tt.labelSmall?.copyWith(
                  color: corValor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.xxs),
        Row(
          children: [
            Icon(
              iconePagamento,
              size: AppSpacing.md - AppSpacing.xxs / 2,
              color: corPagamento,
            ),
            SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                textoPagamento,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.ms),
        _BlocoCliente(
          reserva: reserva,
          nomeCliente: nomeCliente,
          onLigar: onLigar,
          onWhatsapp: onWhatsapp,
        ),
        SizedBox(height: AppSpacing.ms),
        Row(
          children: [
            Expanded(
              child: Text(
                'reservas.dono.codigo'.tr(args: ['${reserva.id}']),
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            if (onCancelar != null)
              AppButton(
                label: confirmada
                    ? 'reservas.dono.cancelar_reserva'.tr()
                    : 'reservas.dono.desistir_cancelar'.tr(),
                height: ButtonSize.small,
                color: cs.surfaceContainer,
                textColor: cs.error,
                prefixIcon: Icon(
                  Icons.cancel_outlined,
                  size: AppSpacing.md,
                  color: cs.error,
                ),
                onPressed: onCancelar,
              ),
          ],
        ),
      ],
    );
  }
}

class _BlocoCliente extends StatelessWidget {
  const _BlocoCliente({
    required this.reserva,
    required this.nomeCliente,
    this.onLigar,
    this.onWhatsapp,
  });

  final Reserva reserva;
  final String nomeCliente;
  final VoidCallback? onLigar;
  final VoidCallback? onWhatsapp;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final telefone = reserva.clienteTelefone;
    final temTelefone = telefone != null && telefone.trim().isNotEmpty;
    final observacao = reserva.observacao?.trim();

    return Container(
      padding: EdgeInsets.all(AppSpacing.ms),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: AppBorders.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AvatarIniciais(iniciais: iniciaisDoNome(reserva.clienteNome)),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            nomeCliente,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.labelLarge?.copyWith(color: cs.onSurface),
                          ),
                        ),
                        SizedBox(width: AppSpacing.s6),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.s6,
                            vertical: AppSpacing.xxs / 2,
                          ),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: AppBorders.xs,
                          ),
                          child: Text(
                            'reservas.dono.titular'.tr(),
                            style: tt.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (temTelefone)
                      Text(
                        Formatadores.telefone(telefone),
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (temTelefone) ...[
                SizedBox(width: AppSpacing.sm),
                _BotaoContato(
                  icone: Icons.call_outlined,
                  rotulo: 'reservas.dono.ligar_para'.tr(args: [nomeCliente]),
                  onTap: onLigar,
                ),
                SizedBox(width: AppSpacing.s6),
                _BotaoContato(
                  icone: Icons.chat_outlined,
                  rotulo: 'reservas.dono.whatsapp_com'.tr(args: [nomeCliente]),
                  onTap: onWhatsapp,
                ),
              ],
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          if (observacao != null && observacao.isNotEmpty)
            Container(
              padding: EdgeInsets.all(AppSpacing.s10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLowest.withValues(alpha: 0.6),
                borderRadius: AppBorders.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.notes,
                        size: AppSpacing.s14,
                        color: cs.onSurfaceVariant,
                      ),
                      SizedBox(width: AppSpacing.xs),
                      Text(
                        'reservas.dono.observacao_rotulo'.tr(),
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.xxs),
                  Text(
                    '“$observacao”',
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurface,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              'reservas.dono.sem_observacao'.tr(),
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }
}

class _BotaoContato extends StatelessWidget {
  const _BotaoContato({
    required this.icone,
    required this.rotulo,
    required this.onTap,
  });

  final IconData icone;
  final String rotulo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tamanho = AppSpacing.xl + AppSpacing.sm;
    return Semantics(
      button: true,
      label: rotulo,
      excludeSemantics: true,
      child: Tooltip(
        message: rotulo,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: AppShadows.subtle,
          ),
          child: Material(
            color: cs.surfaceContainerLowest,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: tamanho,
                height: tamanho,
                child: Icon(icone, size: AppSpacing.ml, color: cs.primary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CorpoEncerrada extends StatelessWidget {
  const _CorpoEncerrada({required this.reserva, required this.nomeCliente});

  final Reserva reserva;
  final String nomeCliente;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final motivo = reserva.motivoCancelamento?.trim();
    final estilo = tt.bodySmall?.copyWith(color: cs.onSurfaceVariant);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                reserva.quadraNome,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.titleSmall?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Text(
              Formatadores.moeda(reserva.valor),
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.xs),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'reservas.dono.cliente_rotulo'.tr()),
              TextSpan(
                text: nomeCliente,
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (motivo != null && motivo.isNotEmpty) ...[
                TextSpan(text: 'reservas.dono.motivo_rotulo'.tr()),
                TextSpan(
                  text: '“$motivo”',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
          style: estilo,
        ),
        SizedBox(height: AppSpacing.sm),
        Text(
          'reservas.dono.codigo'.tr(args: ['${reserva.id}']),
          textAlign: TextAlign.end,
          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
