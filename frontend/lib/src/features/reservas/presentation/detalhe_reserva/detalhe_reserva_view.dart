import 'package:so_mais_uma/src/imports/imports.dart';

import '../cancelamento/prazo_cancelamento.dart';
import '../cancelamento/texto_prazo.dart';
import '../minhas_reservas/abas_reservas.dart';
import '../minhas_reservas/componentes_reserva.dart';
import 'detalhe_reserva_cancelada_view.dart';
import 'detalhe_reserva_store.dart';

/// DetalheReserva (`detalhe_da_reserva/code.html` e, para a cancelada,
/// `detalhe_da_reserva_cancelada/code.html`), sem estado.
class DetalheReservaView extends StatelessWidget {
  const DetalheReservaView({
    super.key,
    required this.estado,
    required this.quadra,
    required this.agora,
    required this.prazo,
    required this.podeEditar,
    required this.editando,
    required this.salvando,
    required this.observacaoSalva,
    required this.copiado,
    required this.usuario,
    required this.observacaoController,
    required this.onVoltarErro,
    required this.onTentarNovamente,
    required this.onCopiarCodigo,
    required this.onCopiarTxid,
    required this.onComoChegar,
    required this.onEditar,
    required this.onCancelarEdicao,
    required this.onSalvar,
    required this.onCancelarReserva,
    required this.onPagar,
    required this.onVoltarMinhasReservas,
    required this.onBuscarQuadras,
  });

  final RequestState<Reserva> estado;
  final Quadra? quadra;
  final DateTime agora;
  final PrazoCancelamento? prazo;
  final bool podeEditar;
  final bool editando;
  final bool salvando;
  final bool observacaoSalva;
  final ItemCopiado? copiado;
  final AppUser? usuario;
  final TextEditingController observacaoController;
  final VoidCallback onVoltarErro;
  final VoidCallback onTentarNovamente;
  final VoidCallback onCopiarCodigo;
  final VoidCallback onCopiarTxid;
  final VoidCallback onComoChegar;
  final VoidCallback onEditar;
  final VoidCallback onCancelarEdicao;
  final VoidCallback onSalvar;
  final VoidCallback onCancelarReserva;
  final VoidCallback onPagar;
  final VoidCallback onVoltarMinhasReservas;
  final VoidCallback onBuscarQuadras;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BarraSuperior(titulo: 'reservas.detalhe.titulo'.tr()),
      body: switch (estado) {
        RequestInitial() || RequestLoading() => const _Carregando(),
        RequestFailure(:final failure) => _erro(failure),
        RequestSuccess(:final data) => data.status == StatusReserva.cancelada
            ? DetalheReservaCanceladaConteudo(
                reserva: data,
                quadra: quadra,
                usuario: usuario,
                copiado: copiado,
                onCopiarCodigo: onCopiarCodigo,
                onCopiarTxid: onCopiarTxid,
                onComoChegar: onComoChegar,
                onBuscarQuadras: onBuscarQuadras,
                onVoltarMinhasReservas: onVoltarMinhasReservas,
              )
            : _conteudoAtivo(context, data),
      },
    );
  }

  Widget _erro(Failure failure) {
    final status = failure is ApiFailure ? failure.status : null;
    if (status == 403 || status == 404) {
      return EstadoErroReservas(
        icone: status == 403 ? Icons.lock_outline : Icons.search_off,
        titulo: status == 403
            ? 'reservas.detalhe.erro_sem_permissao'.tr()
            : 'reservas.detalhe.erro_nao_encontrada'.tr(),
        rotuloAcao: 'comum.voltar'.tr(),
        onAcao: onVoltarErro,
      );
    }
    return EstadoErroReservas(
      icone: failure is NetworkFailure
          ? Icons.cloud_off_outlined
          : Icons.error_outline,
      titulo: 'reservas.detalhe.erro_titulo'.tr(),
      mensagem: failure.message,
      rotuloAcao: 'comum.tentar_novamente'.tr(),
      onAcao: onTentarNovamente,
    );
  }

  Widget _conteudoAtivo(BuildContext context, Reserva reserva) {
    final situacao = SituacaoReserva.de(reserva, agora);
    final prazoAtual = prazo;
    final secao = SizedBox(height: AppSpacing.lg);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: PilulaSituacao(situacao: situacao),
        ),
        SizedBox(height: AppSpacing.sm),
        CaixaCodigoReserva(
          reservaId: reserva.id,
          copiado: copiado == ItemCopiado.codigo,
          onCopiar: onCopiarCodigo,
        ),
        secao,
        _CartaoQuadra(
          reserva: reserva,
          quadra: quadra,
          onComoChegar: onComoChegar,
        ),
        if (reserva.pagamento != null) ...[
          secao,
          _CartaoPagamento(
            pagamento: reserva.pagamento!,
            txidCopiado: copiado == ItemCopiado.txid,
            onCopiarTxid: onCopiarTxid,
          ),
        ],
        secao,
        _CartaoObservacoes(
          observacao: reserva.observacao,
          podeEditar: podeEditar,
          editando: editando,
          salvando: salvando,
          salva: observacaoSalva,
          controller: observacaoController,
          onEditar: onEditar,
          onCancelar: onCancelarEdicao,
          onSalvar: onSalvar,
        ),
        if (prazoAtual != null &&
            prazoAtual.situacao != SituacaoPrazo.naoAplica) ...[
          secao,
          _CartaoPolitica(prazo: prazoAtual),
        ],
        secao,
        _Rodape(
          pendente: reserva.status == StatusReserva.pendentePagamento,
          prazo: prazoAtual,
          onPagar: onPagar,
          onCancelar: onCancelarReserva,
          onVoltar: onVoltarMinhasReservas,
        ),
      ],
    );
  }
}

// ── Peças compartilhadas com a variante cancelada ────────────────────────────

/// "19:00 – 20:00" e a duração em minutos.
({String faixa, String minutos}) faixaEDuracao(Reserva reserva) => (
      faixa: Formatadores.faixaHorario(reserva.inicio, reserva.fim),
      minutos: '${reserva.fim.difference(reserva.inicio).inMinutes}',
    );

/// "24/10/2026 às 19:34".
String dataAsHora(DateTime instante) => 'reservas.detalhe.data_as_hora'.tr(
      namedArgs: {
        'data': Formatadores.dataNumerica(instante),
        'hora': Formatadores.hora(instante),
      },
    );

/// Pílula de status da reserva (topo do detalhe).
class PilulaSituacao extends StatelessWidget {
  const PilulaSituacao({super.key, required this.situacao});

  final SituacaoReserva situacao;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final (fundo, frente, icone) = switch (situacao) {
      SituacaoReserva.pendente => (
          cs.tertiaryFixed,
          cs.onTertiaryFixed,
          Icons.hourglass_top,
        ),
      SituacaoReserva.confirmada => (
          cs.primaryContainer,
          cs.onPrimaryContainer,
          Icons.check_circle,
        ),
      SituacaoReserva.concluida => (
          cs.surfaceContainerHigh,
          cs.onSurfaceVariant,
          Icons.task_alt,
        ),
      SituacaoReserva.cancelada => (
          cs.errorContainer,
          cs.onErrorContainer,
          Icons.cancel,
        ),
      SituacaoReserva.expirada => (
          cs.errorContainer,
          cs.onErrorContainer,
          Icons.timer_off,
        ),
    };
    return Pilula(
      texto: situacao.rotuloKey.tr(),
      icone: icone,
      fundo: fundo,
      frente: frente,
      estilo: context.textTheme.labelMedium,
    );
  }
}

/// Caixa "Código da Reserva" com `#RES-<id>` e "Copiar".
class CaixaCodigoReserva extends StatelessWidget {
  const CaixaCodigoReserva({
    super.key,
    required this.reservaId,
    required this.copiado,
    required this.onCopiar,
    this.maiusculas = false,
    this.fundo,
  });

  final int reservaId;
  final bool copiado;
  final VoidCallback onCopiar;
  final bool maiusculas;
  final Color? fundo;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final rotulo = 'reservas.detalhe.codigo_reserva'.tr();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fundo ?? cs.surfaceContainerLow,
        borderRadius: AppBorders.sm,
        boxShadow: fundo == null ? AppShadows.subtle : AppShadows.none,
      ),
      child: Padding(
        padding: EdgeInsets.all(fundo == null ? AppSpacing.sm : 0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    maiusculas ? rotulo.toUpperCase() : rotulo,
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      letterSpacing: maiusculas ? 0.8 : null,
                    ),
                  ),
                  Text(
                    codigoReserva(reservaId),
                    style: tt.titleMedium?.copyWith(
                      color: cs.onSurface,
                      fontFamily: 'monospace',
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: BotaoCopiar(
                copiado: copiado,
                onCopiar: onCopiar,
                semanticsLabel: 'reservas.detalhe.copiar_codigo_semantica'.tr(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `#RES-<id>`.
String codigoReserva(int id) => '#RES-$id';

/// Botão "Copiar" que vira "Copiado!" com marca de confirmação.
class BotaoCopiar extends StatelessWidget {
  const BotaoCopiar({
    super.key,
    required this.copiado,
    required this.onCopiar,
    this.semanticsLabel,
    this.fundo,
  });

  final bool copiado;
  final VoidCallback onCopiar;
  final String? semanticsLabel;
  final Color? fundo;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final texto =
        copiado ? 'comum.copiado'.tr() : 'reservas.detalhe.copiar'.tr();
    return Semantics(
      button: true,
      liveRegion: copiado,
      label: copiado ? texto : (semanticsLabel ?? texto),
      onTap: onCopiar,
      excludeSemantics: true,
      child: TextButton.icon(
        onPressed: onCopiar,
        icon: Icon(
          copiado ? Icons.check : Icons.content_copy_outlined,
          size: AppSpacing.md + AppSpacing.xxs,
        ),
        label: Text(texto),
        style: TextButton.styleFrom(
          backgroundColor: fundo ?? cs.surfaceContainerHighest,
          foregroundColor: cs.onSurface,
          minimumSize: const Size.square(kMinInteractiveDimension),
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.ms),
          shape: const RoundedRectangleBorder(borderRadius: AppBorders.sm),
          textStyle: context.textTheme.labelMedium,
        ),
      ),
    );
  }
}

/// Linha com rótulo e valor do bloco de agenda.
class LinhaAgenda extends StatelessWidget {
  const LinhaAgenda({
    super.key,
    required this.icone,
    required this.rotulo,
    required this.valor,
    this.estiloValor,
  });

  final IconData icone;
  final String rotulo;
  final String valor;
  final TextStyle? estiloValor;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    return Row(
      children: [
        SizedBox.square(
          dimension: AppSpacing.xl + AppSpacing.sm,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: AppBorders.sm,
            ),
            child: Icon(icone,
                size: AppSpacing.ml + AppSpacing.xxs, color: cs.primary),
          ),
        ),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rotulo,
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              Text(
                valor,
                style:
                    estiloValor ?? tt.titleSmall?.copyWith(color: cs.onSurface),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Variante ativa (confirmada, pendente, concluída, expirada) ───────────────

class _CartaoQuadra extends StatelessWidget {
  const _CartaoQuadra({
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

    return CartaoReserva(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (esporte != null) ...[
                      Row(
                        children: [
                          Icon(esporte.icone,
                              size: AppSpacing.md, color: cs.primary),
                          SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              esporte.rotuloKey.tr(),
                              style:
                                  tt.labelMedium?.copyWith(color: cs.primary),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.xs),
                    ],
                    Text(
                      reserva.quadraNome,
                      style: tt.headlineSmall?.copyWith(color: cs.onSurface),
                    ),
                  ],
                ),
              ),
              if (esporte != null) ...[
                SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Pilula(
                    texto: esporte.rotuloCurtoKey.tr(),
                    fundo: cs.secondaryContainer,
                    frente: cs.onSecondaryContainer,
                    raio: AppBorders.xs,
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: AppBorders.sm,
            child: SizedBox(
              height: AppSpacing.xxxl * 2 + AppSpacing.xl,
              child: ImagemQuadra(
                url: quadra?.fotoUrl,
                icone: esporte?.icone ?? TipoEsporte.outro.icone,
              ),
            ),
          ),
          SizedBox(height: AppSpacing.md),
          DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: AppBorders.sm,
            ),
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.sm),
              child: Column(
                children: [
                  LinhaAgenda(
                    icone: Icons.event_outlined,
                    rotulo: 'reservas.detalhe.data_do_jogo'.tr(),
                    valor: Formatadores.dataLonga(reserva.inicio),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  LinhaAgenda(
                    icone: Icons.schedule_outlined,
                    rotulo: 'reservas.detalhe.horario_reservado'.tr(),
                    valor: 'reservas.detalhe.faixa_duracao'
                        .tr(namedArgs: {'faixa': faixa, 'min': minutos}),
                    estiloValor: tt.titleMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
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
                  size: AppSpacing.ml,
                  color: cs.onSurfaceVariant,
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    endereco,
                    style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: AppSpacing.ms),
          BotaoReserva(
            rotulo: 'reservas.detalhe.como_chegar'.tr(),
            icone: Icons.directions_outlined,
            fundo: cs.surfaceContainerHigh,
            frente: cs.onSurface,
            onPressed: onComoChegar,
          ),
        ],
      ),
    );
  }
}

class _CartaoPagamento extends StatelessWidget {
  const _CartaoPagamento({
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
                  'reservas.detalhe.info_pagamento'.tr(),
                  style: tt.titleMedium?.copyWith(color: cs.onSurface),
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Flexible(child: PilulaStatusPagamento(status: pagamento.status)),
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
                  Icon(Icons.qr_code_2, size: AppSpacing.lg, color: cs.primary),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'reservas.detalhe.pix'.tr(),
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (pagamento.pagoEm != null)
                          Text(
                            dataAsHora(pagamento.pagoEm!),
                            style: tt.labelSmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    Formatadores.moeda(pagamento.valor),
                    style: tt.headlineSmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: AppSpacing.ms),
          Row(
            children: [
              Expanded(
                child: Text(
                  'reservas.detalhe.txid'.tr(),
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              Semantics(
                button: true,
                liveRegion: txidCopiado,
                label: txidCopiado
                    ? 'comum.copiado'.tr()
                    : 'reservas.detalhe.copiar_txid_semantica'.tr(),
                onTap: onCopiarTxid,
                excludeSemantics: true,
                child: TextButton.icon(
                  onPressed: onCopiarTxid,
                  iconAlignment: IconAlignment.end,
                  icon: Icon(
                    txidCopiado ? Icons.check : Icons.content_copy_outlined,
                    size: AppSpacing.s14,
                  ),
                  label: Text(
                    txidCopiado
                        ? 'comum.copiado'.tr()
                        : 'reservas.detalhe.copiar'.tr(),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: cs.primary,
                    minimumSize: const Size.square(kMinInteractiveDimension),
                    textStyle: tt.labelSmall,
                  ),
                ),
              ),
            ],
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: AppBorders.xs,
            ),
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.sm),
              child: Text(
                pagamento.txid,
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurface,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          if (pago) ...[
            SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: AppSpacing.md + AppSpacing.xxs,
                  color: cs.primary,
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    pagamento.provedor.rotuloKey.tr(),
                    style: tt.labelSmall?.copyWith(color: cs.primary),
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

/// Etiqueta "Aguardando", "Liquidado", "Expirado" ou "Cancelado".
class PilulaStatusPagamento extends StatelessWidget {
  const PilulaStatusPagamento({super.key, required this.status});

  final StatusPagamento status;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final (chave, fundo, frente) = switch (status) {
      StatusPagamento.pendente => (
          'reservas.detalhe.pagamento_aguardando',
          cs.tertiaryFixed,
          cs.onTertiaryFixed,
        ),
      StatusPagamento.pago => (
          'reservas.detalhe.pagamento_liquidado',
          cs.primaryContainer,
          cs.onPrimaryContainer,
        ),
      StatusPagamento.expirado => (
          'reservas.detalhe.pagamento_expirado',
          cs.errorContainer,
          cs.onErrorContainer,
        ),
      StatusPagamento.cancelado => (
          'reservas.detalhe.pagamento_cancelado',
          cs.errorContainer,
          cs.onErrorContainer,
        ),
    };
    return Pilula(texto: chave.tr(), fundo: fundo, frente: frente);
  }
}

class _CartaoObservacoes extends StatelessWidget {
  const _CartaoObservacoes({
    required this.observacao,
    required this.podeEditar,
    required this.editando,
    required this.salvando,
    required this.salva,
    required this.controller,
    required this.onEditar,
    required this.onCancelar,
    required this.onSalvar,
  });

  final String? observacao;
  final bool podeEditar;
  final bool editando;
  final bool salvando;
  final bool salva;
  final TextEditingController controller;
  final VoidCallback onEditar;
  final VoidCallback onCancelar;
  final VoidCallback onSalvar;

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
              Expanded(
                child: Text(
                  'reservas.detalhe.observacoes_titulo'.tr(),
                  style: tt.titleMedium?.copyWith(color: cs.onSurface),
                ),
              ),
              if (podeEditar && !editando)
                Flexible(
                  child: TextButton.icon(
                    onPressed: onEditar,
                    icon: Icon(
                      Icons.edit_outlined,
                      size: AppSpacing.md + AppSpacing.xxs,
                    ),
                    label: Text('reservas.detalhe.editar'.tr()),
                    style: TextButton.styleFrom(
                      foregroundColor: cs.primary,
                      minimumSize: const Size.square(kMinInteractiveDimension),
                      textStyle: tt.labelMedium,
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppBorders.sm,
                      ),
                    ),
                  ),
                )
              else if (!podeEditar)
                const Flexible(child: SomenteLeitura()),
            ],
          ),
          Text(
            'reservas.detalhe.observacoes_dica'.tr(),
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          SizedBox(height: AppSpacing.sm),
          if (editando)
            _EdicaoObservacao(
              controller: controller,
              salvando: salvando,
              onCancelar: onCancelar,
              onSalvar: onSalvar,
            )
          else
            TextoObservacao(observacao: observacao),
          if (salva) ...[
            SizedBox(height: AppSpacing.sm),
            Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  Icon(Icons.check, size: AppSpacing.md, color: cs.primary),
                  SizedBox(width: AppSpacing.s6),
                  Expanded(
                    child: Text(
                      'reservas.detalhe.observacao_salva'.tr(),
                      style: tt.labelSmall?.copyWith(color: cs.primary),
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

/// Selo "Somente leitura" com cadeado.
class SomenteLeitura extends StatelessWidget {
  const SomenteLeitura({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock_outline,
            size: AppSpacing.s14, color: cs.onSurfaceVariant),
        SizedBox(width: AppSpacing.xxs),
        Flexible(
          child: Text(
            'reservas.detalhe.somente_leitura'.tr(),
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.labelSmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// Observação entre aspas, ou "Nenhuma observação.".
class TextoObservacao extends StatelessWidget {
  const TextoObservacao({super.key, required this.observacao, this.estilo});

  final String? observacao;
  final TextStyle? estilo;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final texto = observacao?.trim();
    final vazio = texto == null || texto.isEmpty;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: AppBorders.sm,
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.sm),
        child: Text(
          vazio
              ? 'reservas.detalhe.sem_observacao'.tr()
              : 'reservas.detalhe.observacao_entre_aspas'
                  .tr(namedArgs: {'texto': texto}),
          style: (estilo ?? context.textTheme.bodyMedium)?.copyWith(
            color: vazio ? cs.onSurfaceVariant : cs.onSurface,
          ),
        ),
      ),
    );
  }
}

class _EdicaoObservacao extends StatelessWidget {
  const _EdicaoObservacao({
    required this.controller,
    required this.salvando,
    required this.onCancelar,
    required this.onSalvar,
  });

  final TextEditingController controller;
  final bool salvando;
  final VoidCallback onCancelar;
  final VoidCallback onSalvar;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          autofocus: true,
          enabled: !salvando,
          minLines: 3,
          maxLines: 5,
          maxLength: 200,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          textCapitalization: TextCapitalization.sentences,
          style: tt.bodyMedium?.copyWith(color: cs.onSurface),
          decoration: InputDecoration(
            labelText: 'reservas.detalhe.observacoes_rotulo_campo'.tr(),
            floatingLabelBehavior: FloatingLabelBehavior.never,
            counterText: '',
            filled: true,
            fillColor: cs.surfaceContainerHighest,
            contentPadding: EdgeInsets.all(AppSpacing.sm),
            border: const OutlineInputBorder(
              borderRadius: AppBorders.sm,
              borderSide: BorderSide.none,
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: AppBorders.sm,
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppBorders.sm,
              borderSide: BorderSide(color: cs.primary),
            ),
          ),
        ),
        SizedBox(height: AppSpacing.sm),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, valor, _) => Text(
                'reservas.detalhe.contador'
                    .tr(namedArgs: {'n': '${valor.text.length}'}),
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                TextButton(
                  onPressed: salvando ? null : onCancelar,
                  style: TextButton.styleFrom(
                    backgroundColor: cs.surfaceContainerHigh,
                    foregroundColor: cs.onSurface,
                    minimumSize: const Size.square(kMinInteractiveDimension),
                    textStyle: tt.labelMedium,
                    shape: const RoundedRectangleBorder(
                        borderRadius: AppBorders.sm),
                  ),
                  child: Text('comum.cancelar'.tr()),
                ),
                FilledButton(
                  onPressed: salvando ? null : onSalvar,
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    minimumSize: const Size.square(kMinInteractiveDimension),
                    textStyle: tt.labelMedium,
                    shape: const RoundedRectangleBorder(
                        borderRadius: AppBorders.sm),
                  ),
                  child: salvando
                      ? SizedBox.square(
                          dimension: AppSpacing.md,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onPrimary,
                          ),
                        )
                      : Text('reservas.detalhe.salvar_alteracao'.tr()),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _CartaoPolitica extends StatelessWidget {
  const _CartaoPolitica({required this.prazo});

  final PrazoCancelamento prazo;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final (fundo, frente, icone) = switch (prazo.situacao) {
      SituacaoPrazo.dentro => (
          cs.primaryContainer,
          cs.onPrimaryContainer,
          Icons.alarm_on,
        ),
      SituacaoPrazo.encerrado => (
          cs.errorContainer,
          cs.onErrorContainer,
          Icons.alarm_off,
        ),
      _ => (cs.tertiaryFixed, cs.onTertiaryFixed, Icons.hourglass_top),
    };
    final limite = prazo.limite;
    final pendente = prazo.situacao == SituacaoPrazo.pendente;

    return CartaoReserva(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.policy_outlined,
                  size: AppSpacing.ml + AppSpacing.xxs, color: cs.primary),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'reservas.detalhe.politica_titulo'.tr(),
                    style: tt.titleMedium?.copyWith(color: cs.onSurface),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: Pilula(
              texto: textoPilulaPrazo(prazo),
              icone: icone,
              fundo: fundo,
              frente: frente,
              raio: AppBorders.sm,
              estilo: tt.labelMedium,
              maxLinhas: 3,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: AppBorders.sm,
            ),
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (pendente)
                    TextoComNegrito(
                      limite == null
                          ? 'reservas.detalhe.politica_pendente_sem_hora'.tr()
                          : 'reservas.detalhe.politica_pendente'.tr(
                              namedArgs: {'hora': Formatadores.hora(limite)},
                            ),
                      style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                    )
                  else ...[
                    TextoComNegrito(
                      'reservas.detalhe.politica_texto'.tr(
                        namedArgs: {
                          'data': Formatadores.diaMes(limite!),
                          'hora': Formatadores.hora(limite),
                        },
                      ),
                      style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: AppSpacing.md,
                          color: cs.secondary,
                        ),
                        SizedBox(width: AppSpacing.s6),
                        Expanded(
                          child: Text(
                            'reservas.detalhe.politica_nota'.tr(),
                            style: tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Rodape extends StatelessWidget {
  const _Rodape({
    required this.pendente,
    required this.prazo,
    required this.onPagar,
    required this.onCancelar,
    required this.onVoltar,
  });

  final bool pendente;
  final PrazoCancelamento? prazo;
  final VoidCallback onPagar;
  final VoidCallback onCancelar;
  final VoidCallback onVoltar;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final prazoAtual = prazo;
    final espaco = SizedBox(height: AppSpacing.sm);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pendente) ...[
          BotaoReserva(
            rotulo: 'reservas.detalhe.pagar_agora'.tr(),
            icone: Icons.qr_code_2,
            fundo: cs.primary,
            frente: cs.onPrimary,
            onPressed: onPagar,
          ),
          espaco,
        ],
        if (prazoAtual != null && prazoAtual.mostrarBotao) ...[
          BotaoReserva(
            rotulo: 'reservas.detalhe.cancelar_reserva'.tr(),
            icone: Icons.cancel_outlined,
            fundo: cs.errorContainer,
            frente: cs.onErrorContainer,
            onPressed: prazoAtual.podeCancelar ? onCancelar : null,
          ),
          espaco,
        ],
        BotaoReserva(
          rotulo: 'reservas.detalhe.voltar_minhas_reservas'.tr(),
          icone: Icons.arrow_back,
          fundo: cs.surfaceContainerHigh,
          frente: cs.onSurface,
          onPressed: onVoltar,
        ),
      ],
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
          BlocoEsqueleto(altura: AppSpacing.xl, raio: AppBorders.full),
          SizedBox(height: AppSpacing.sm),
          BlocoEsqueleto(altura: AppSpacing.xxxl, raio: AppBorders.sm),
          SizedBox(height: AppSpacing.lg),
          BlocoEsqueleto(altura: AppSpacing.xxxl * 5),
          SizedBox(height: AppSpacing.lg),
          BlocoEsqueleto(altura: AppSpacing.xxxl * 2),
        ],
      ),
    );
  }
}
