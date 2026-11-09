import 'package:so_mais_uma/src/imports/imports.dart';

import '../minhas_reservas/componentes_reserva.dart';
import 'detalhe_reserva_store.dart';
import 'detalhe_reserva_view.dart';

/// Variante cancelada da DetalheReserva
/// (`detalhe_da_reserva_cancelada/code.html`), sem estado.
class DetalheReservaCanceladaConteudo extends StatelessWidget {
  const DetalheReservaCanceladaConteudo({
    super.key,
    required this.reserva,
    required this.quadra,
    required this.usuario,
    required this.copiado,
    required this.onCopiarCodigo,
    required this.onCopiarTxid,
    required this.onComoChegar,
    required this.onBuscarQuadras,
    required this.onVoltarMinhasReservas,
  });

  final Reserva reserva;
  final Quadra? quadra;
  final AppUser? usuario;
  final ItemCopiado? copiado;
  final VoidCallback onCopiarCodigo;
  final VoidCallback onCopiarTxid;
  final VoidCallback onComoChegar;
  final VoidCallback onBuscarQuadras;
  final VoidCallback onVoltarMinhasReservas;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final espaco = SizedBox(height: AppSpacing.md);
    final pagamento = reserva.pagamento;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        _CartaoStatus(
          reserva: reserva,
          copiado: copiado == ItemCopiado.codigo,
          onCopiar: onCopiarCodigo,
        ),
        espaco,
        _CartaoCancelamento(reserva: reserva),
        if (reserva.estornoPendente) ...[
          espaco,
          _CartaoEstorno(quadraNome: reserva.quadraNome),
        ],
        espaco,
        _CartaoQuadraCancelada(
          reserva: reserva,
          quadra: quadra,
          onComoChegar: onComoChegar,
        ),
        if (pagamento != null) ...[
          espaco,
          _CartaoHistoricoFinanceiro(
            pagamento: pagamento,
            txidCopiado: copiado == ItemCopiado.txid,
            onCopiarTxid: onCopiarTxid,
          ),
        ],
        espaco,
        _CartaoObservacoesLeitura(observacao: reserva.observacao),
        if (usuario != null) ...[
          espaco,
          _FaixaTitular(usuario: usuario!),
        ],
        SizedBox(height: AppSpacing.lg),
        BotaoReserva(
          rotulo: 'reservas.detalhe.buscar_outra_quadra'.tr(),
          icone: Icons.sports_soccer,
          fundo: cs.primary,
          frente: cs.onPrimary,
          onPressed: onBuscarQuadras,
        ),
        SizedBox(height: AppSpacing.sm),
        BotaoReserva(
          rotulo: 'reservas.detalhe.voltar_minhas_reservas'.tr(),
          icone: Icons.arrow_back,
          fundo: cs.surface,
          frente: cs.onSurfaceVariant,
          estilo: context.textTheme.labelMedium,
          onPressed: onVoltarMinhasReservas,
        ),
      ],
    );
  }
}

class _CartaoStatus extends StatelessWidget {
  const _CartaoStatus({
    required this.reserva,
    required this.copiado,
    required this.onCopiar,
  });

  final Reserva reserva;
  final bool copiado;
  final VoidCallback onCopiar;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final canceladoEm = reserva.canceladoEm;
    return CartaoReserva(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              Pilula(
                texto: StatusReserva.cancelada.rotuloKey.tr(),
                icone: Icons.cancel,
                fundo: cs.errorContainer,
                frente: cs.onErrorContainer,
                estilo: context.textTheme.labelMedium,
                maiusculas: true,
              ),
              if (canceladoEm != null)
                Pilula(
                  texto: dataAsHora(canceladoEm),
                  icone: Icons.event_busy_outlined,
                  fundo: cs.surfaceContainer,
                  frente: cs.onSurfaceVariant,
                ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          CaixaCodigoReserva(
            reservaId: reserva.id,
            copiado: copiado,
            onCopiar: onCopiar,
            maiusculas: true,
            fundo: cs.surfaceContainerLowest,
          ),
        ],
      ),
    );
  }
}

class _CartaoCancelamento extends StatelessWidget {
  const _CartaoCancelamento({required this.reserva});

  final Reserva reserva;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final quem = switch (reserva.canceladoPor) {
      CanceladoPor.cliente => 'reservas.detalhe.cancelada_por_cliente'.tr(),
      CanceladoPor.dono => 'reservas.detalhe.cancelada_por_dono'.tr(),
      CanceladoPor.sistema => 'reservas.detalhe.cancelada_por_sistema'.tr(),
      null => null,
    };
    final motivoApi = reserva.motivoCancelamento?.trim();
    final motivo = reserva.canceladoPor == CanceladoPor.sistema
        ? 'reservas.detalhe.motivo_sistema'.tr()
        : (motivoApi == null || motivoApi.isEmpty ? null : motivoApi);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.4),
        borderRadius: AppBorders.md,
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
                    color: cs.error,
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.subtle,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.sm),
                    child: Icon(Icons.info_outline,
                        size: AppSpacing.lg, color: cs.onError),
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          'reservas.detalhe.cancelada_titulo'.tr(),
                          style: tt.titleMedium?.copyWith(color: cs.onSurface),
                        ),
                      ),
                      Text(
                        'reservas.detalhe.cancelada_subtitulo'.tr(),
                        style:
                            tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (quem != null || motivo != null) ...[
              SizedBox(height: AppSpacing.sm),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLowest.withValues(alpha: 0.8),
                  borderRadius: AppBorders.sm,
                ),
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (quem != null)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'reservas.detalhe.cancelada_por'.tr(),
                                style: tt.labelSmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ),
                            SizedBox(width: AppSpacing.sm),
                            Flexible(
                              child: Text(
                                quem,
                                textAlign: TextAlign.end,
                                style: tt.labelMedium
                                    ?.copyWith(color: cs.onSurface),
                              ),
                            ),
                          ],
                        ),
                      if (motivo != null) ...[
                        SizedBox(height: AppSpacing.s6),
                        Text(
                          'reservas.detalhe.motivo_registrado'.tr(),
                          style: tt.labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        SizedBox(height: AppSpacing.xxs),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerLow,
                            borderRadius: AppBorders.xs,
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.sm),
                            child: Text(
                              'reservas.detalhe.observacao_entre_aspas'
                                  .tr(namedArgs: {'texto': motivo}),
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurface,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CartaoEstorno extends StatelessWidget {
  const _CartaoEstorno({required this.quadraNome});

  final String quadraNome;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final corpo = tt.bodySmall?.copyWith(color: cs.onSurfaceVariant);
    return CartaoReserva(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.currency_exchange,
                  size: AppSpacing.ml, color: cs.primary),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'reservas.detalhe.estorno_titulo'.tr(),
                  style: tt.titleSmall?.copyWith(color: cs.onSurface),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          TextoComNegrito(
            'reservas.detalhe.estorno_texto'
                .tr(namedArgs: {'quadra': quadraNome}),
            style: corpo,
            estiloNegrito: corpo?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CartaoQuadraCancelada extends StatelessWidget {
  const _CartaoQuadraCancelada({
    required this.reserva,
    required this.quadra,
    required this.onComoChegar,
  });

  final Reserva reserva;
  final Quadra? quadra;
  final VoidCallback onComoChegar;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final esporte = quadra?.tipoEsporte;
    final (:faixa, :minutos) = faixaEDuracao(reserva);
    final endereco = reserva.quadraEndereco ?? quadra?.enderecoCompleto;
    final claro = cs.surfaceContainerLowest;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: claro,
        borderRadius: AppBorders.md,
        boxShadow: AppShadows.subtle,
      ),
      child: ClipRRect(
        borderRadius: AppBorders.md,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: AppSpacing.xxxl * 2 + AppSpacing.xxl,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: 0.85,
                    child: ImagemQuadra(
                      url: quadra?.fotoUrl,
                      icone: esporte?.icone ?? TipoEsporte.outro.icone,
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          cs.onSurface.withValues(alpha: 0.8),
                          cs.onSurface.withValues(alpha: 0),
                          cs.scrim.withValues(alpha: 0.3),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: AppSpacing.ms,
                    left: AppSpacing.ms,
                    child: Pilula(
                      texto: 'reservas.detalhe.horario_desmarcado'.tr(),
                      icone: Icons.block,
                      fundo: cs.error,
                      frente: cs.onError,
                    ),
                  ),
                  Positioned(
                    left: AppSpacing.ms,
                    right: AppSpacing.ms,
                    bottom: AppSpacing.ms,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (esporte != null)
                          Text(
                            esporte.rotuloKey.tr().toUpperCase(),
                            style: tt.labelSmall?.copyWith(
                              color: cs.surfaceContainerHighest,
                              letterSpacing: 0.8,
                            ),
                          ),
                        Text(
                          reserva.quadraNome,
                          style: tt.headlineSmall?.copyWith(
                            color: claro,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: AppBorders.sm,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.sm),
                      child: Row(
                        children: [
                          SizedBox.square(
                            dimension: AppSpacing.xl + AppSpacing.sm,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest,
                                borderRadius: AppBorders.sm,
                              ),
                              child: Icon(
                                Icons.calendar_today_outlined,
                                size: AppSpacing.lg,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  Formatadores.dataLonga(reserva.inicio),
                                  style: tt.titleSmall?.copyWith(
                                    color: cs.onSurface,
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: cs.error,
                                    decorationThickness: 2,
                                  ),
                                ),
                                Text(
                                  'reservas.detalhe.faixa_duracao_original'.tr(
                                    namedArgs: {'faixa': faixa, 'min': minutos},
                                  ),
                                  style: tt.bodySmall
                                      ?.copyWith(color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (endereco != null) ...[
                    SizedBox(height: AppSpacing.md),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: AppSpacing.ml + AppSpacing.xxs,
                          color: cs.onSurfaceVariant,
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'reservas.detalhe.endereco_quadra'.tr(),
                                style: tt.labelMedium
                                    ?.copyWith(color: cs.onSurface),
                              ),
                              Text(
                                endereco,
                                style: tt.bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  SizedBox(height: AppSpacing.ms),
                  BotaoReserva(
                    rotulo: 'reservas.detalhe.como_chegar'.tr(),
                    icone: Icons.directions_outlined,
                    fundo: cs.surfaceContainer,
                    frente: cs.onSurface,
                    estilo: tt.labelMedium,
                    onPressed: onComoChegar,
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

class _CartaoHistoricoFinanceiro extends StatelessWidget {
  const _CartaoHistoricoFinanceiro({
    required this.pagamento,
    required this.txidCopiado,
    required this.onCopiarTxid,
  });

  final Pagamento pagamento;
  final bool txidCopiado;
  final VoidCallback onCopiarTxid;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final pago = pagamento.status == StatusPagamento.pago;
    return CartaoReserva(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'reservas.detalhe.historico_financeiro'.tr(),
                  style: tt.titleSmall?.copyWith(color: cs.onSurface),
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Flexible(
                child: pago
                    ? Pilula(
                        texto: 'reservas.detalhe.estorno_pendente'.tr(),
                        icone: Icons.pending_outlined,
                        fundo: cs.tertiaryFixed,
                        frente: cs.onTertiaryFixed,
                      )
                    : PilulaStatusPagamento(status: pagamento.status),
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
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: AppSpacing.xl,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.qr_code_2,
                        size: AppSpacing.md + AppSpacing.xxs,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.s10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'reservas.detalhe.pagamento_via_pix'.tr(),
                          style: tt.labelMedium?.copyWith(color: cs.onSurface),
                        ),
                        if (pagamento.pagoEm != null)
                          Text(
                            'reservas.detalhe.quitado_em'.tr(
                              namedArgs: {
                                'data': dataAsHora(pagamento.pagoEm!)
                              },
                            ),
                            style: tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    Formatadores.moeda(pagamento.valor),
                    style: tt.titleMedium?.copyWith(color: cs.onSurface),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'reservas.detalhe.txid_completo'.tr(),
                      style:
                          tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    Text(
                      pagamento.txid,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurface,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Flexible(
                child: BotaoCopiar(
                  copiado: txidCopiado,
                  onCopiar: onCopiarTxid,
                  fundo: cs.surfaceContainer,
                  semanticsLabel: 'reservas.detalhe.copiar_txid_semantica'.tr(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CartaoObservacoesLeitura extends StatelessWidget {
  const _CartaoObservacoesLeitura({required this.observacao});

  final String? observacao;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    return CartaoReserva(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.notes,
                  size: AppSpacing.md + AppSpacing.xxs,
                  color: cs.onSurfaceVariant),
              SizedBox(width: AppSpacing.s6),
              Expanded(
                child: Text(
                  'reservas.detalhe.observacoes_reserva'.tr(),
                  style: tt.titleSmall?.copyWith(color: cs.onSurface),
                ),
              ),
              const Flexible(child: SomenteLeitura()),
            ],
          ),
          SizedBox(height: AppSpacing.s6),
          TextoObservacao(observacao: observacao, estilo: tt.bodySmall),
        ],
      ),
    );
  }
}

class _FaixaTitular extends StatelessWidget {
  const _FaixaTitular({required this.usuario});

  final AppUser usuario;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final nome = (usuario.name?.trim().isNotEmpty ?? false)
        ? usuario.name!.trim()
        : usuario.email;
    return CartaoReserva(
      padding: EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          AvatarIniciais(
              iniciais: usuario.iniciais,
              tamanho: AppSpacing.xl + AppSpacing.sm),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleSmall?.copyWith(color: cs.onSurface),
                ),
                Text(
                  'reservas.detalhe.titular_cancelada'.tr(),
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Pilula(
            texto: 'reservas.detalhe.cliente'.tr(),
            fundo: cs.surfaceContainer,
            frente: cs.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
