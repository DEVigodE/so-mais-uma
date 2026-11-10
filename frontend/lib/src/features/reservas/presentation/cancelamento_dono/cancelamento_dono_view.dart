import 'package:so_mais_uma/src/imports/imports.dart';

import 'cancelamento_dono_store.dart';

/// Sheet de cancelamento pelo dono, no desenho do modal de
/// `reservas_da_quadra_dono/code.html` (o campo livre segue
/// `cancelar_reserva_confirma_o/code.html`). Sem estado: recebe o estado e os
/// callbacks do contêiner.
class CancelamentoDonoView extends StatelessWidget {
  const CancelamentoDonoView({
    super.key,
    required this.reserva,
    required this.motivo,
    required this.mostrarAvisoEstorno,
    required this.motivoLivre,
    required this.textoLivreController,
    required this.comprimentoTextoLivre,
    required this.enviando,
    required this.podeConfirmar,
    required this.onMotivo,
    required this.onTextoLivre,
    required this.onVoltar,
    required this.onConfirmar,
    this.erroMotivo,
    this.erroGeral,
  });

  final Reserva reserva;
  final MotivoCancelamentoDono motivo;
  final bool mostrarAvisoEstorno;
  final bool motivoLivre;
  final TextEditingController textoLivreController;
  final int comprimentoTextoLivre;
  final bool enviando;
  final bool podeConfirmar;
  final String? erroMotivo;
  final String? erroGeral;
  final ValueChanged<MotivoCancelamentoDono> onMotivo;
  final ValueChanged<String> onTextoLivre;
  final VoidCallback onVoltar;
  final VoidCallback onConfirmar;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: AppSpacing.xxl,
                height: AppSpacing.s6,
                margin: EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: AppBorders.full,
                ),
              ),
            ),
            _Cabecalho(onFechar: enviando ? null : onVoltar),
            SizedBox(height: AppSpacing.md),
            _ResumoReserva(reserva: reserva),
            if (mostrarAvisoEstorno) ...[
              SizedBox(height: AppSpacing.md),
              const _AvisoEstorno(),
            ],
            SizedBox(height: AppSpacing.md),
            MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'reservas.cancelamento_dono.motivo_rotulo'.tr(),
                    style: tt.labelMedium?.copyWith(color: cs.onSurface),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  _SeletorMotivo(
                    motivo: motivo,
                    onMotivo: enviando ? null : onMotivo,
                  ),
                ],
              ),
            ),
            if (motivoLivre) ...[
              SizedBox(height: AppSpacing.sm),
              _CampoMotivoLivre(
                controller: textoLivreController,
                comprimento: comprimentoTextoLivre,
                enabled: !enviando,
                onChanged: onTextoLivre,
              ),
            ],
            if (erroMotivo != null) ...[
              SizedBox(height: AppSpacing.xs),
              _LinhaErro(mensagem: erroMotivo!),
            ],
            if (erroGeral != null) ...[
              SizedBox(height: AppSpacing.sm),
              _LinhaErro(mensagem: erroGeral!),
            ],
            SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'comum.voltar'.tr(),
                    color: cs.surfaceContainer,
                    textColor: cs.onSurface,
                    isFullWidth: true,
                    onPressed: enviando ? null : onVoltar,
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: 'comum.confirmar'.tr(),
                    variant: ButtonVariant.danger,
                    isFullWidth: true,
                    isLoading: enviando,
                    prefixIcon: Icon(
                      Icons.delete_outline,
                      size: AppSpacing.ml,
                      color: cs.onError,
                    ),
                    onPressed: podeConfirmar ? onConfirmar : null,
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

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.onFechar});

  final VoidCallback? onFechar;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    return Row(
      children: [
        Container(
          width: AppSpacing.xl + AppSpacing.xs,
          height: AppSpacing.xl + AppSpacing.xs,
          decoration: BoxDecoration(
            color: cs.errorContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.event_busy_outlined,
            size: AppSpacing.ml,
            color: cs.onErrorContainer,
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
                  'reservas.cancelamento_dono.titulo'.tr(),
                  style: tt.titleMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'reservas.cancelamento_dono.subtitulo'.tr(),
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'comum.fechar'.tr(),
          onPressed: onFechar,
          color: cs.onSurfaceVariant,
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}

class _ResumoReserva extends StatelessWidget {
  const _ResumoReserva({required this.reserva});

  final Reserva reserva;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final nome = (reserva.clienteNome?.trim().isNotEmpty ?? false)
        ? reserva.clienteNome!.trim()
        : 'reservas.dono.cliente_sem_nome'.tr();
    return Container(
      padding: EdgeInsets.all(AppSpacing.ms),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: AppBorders.md,
      ),
      child: Column(
        children: [
          _LinhaResumo(
            rotulo: 'reservas.cancelamento_dono.cliente'.tr(),
            valor: nome,
          ),
          _LinhaResumo(
            rotulo: 'reservas.cancelamento_dono.horario'.tr(),
            valor: Formatadores.faixaHorario(reserva.inicio, reserva.fim),
          ),
          _LinhaResumo(
            rotulo: 'reservas.cancelamento_dono.quadra'.tr(),
            valor: reserva.quadraNome,
          ),
          _LinhaResumo(
            rotulo: 'reservas.cancelamento_dono.valor'.tr(),
            valor: Formatadores.moeda(reserva.valor),
            destaque: true,
          ),
        ],
      ),
    );
  }
}

class _LinhaResumo extends StatelessWidget {
  const _LinhaResumo({
    required this.rotulo,
    required this.valor,
    this.destaque = false,
  });

  final String rotulo;
  final String valor;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rotulo,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              valor,
              textAlign: TextAlign.end,
              style: tt.bodySmall?.copyWith(
                color: destaque ? cs.primary : cs.onSurface,
                fontWeight: destaque ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvisoEstorno extends StatelessWidget {
  const _AvisoEstorno();

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final estilo = context.textTheme.bodySmall?.copyWith(
      color: cs.onSecondaryContainer,
    );
    return Container(
      padding: EdgeInsets.all(AppSpacing.ms),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: AppBorders.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_outlined,
            size: AppSpacing.ml - AppSpacing.xxs,
            color: cs.tertiaryContainer,
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'reservas.cancelamento_dono.atencao'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: ' '),
                  TextSpan(
                    text: 'reservas.cancelamento_dono.aviso_estorno'.tr(),
                  ),
                ],
              ),
              style: estilo,
            ),
          ),
        ],
      ),
    );
  }
}

class _SeletorMotivo extends StatelessWidget {
  const _SeletorMotivo({required this.motivo, required this.onMotivo});

  final MotivoCancelamentoDono motivo;
  final ValueChanged<MotivoCancelamentoDono>? onMotivo;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    return Container(
      height: AppSpacing.xxl,
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.ms),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: AppBorders.sm,
        boxShadow: AppShadows.card,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<MotivoCancelamentoDono>(
          value: motivo,
          isExpanded: true,
          dropdownColor: cs.surfaceContainerLowest,
          borderRadius: AppBorders.sm,
          style: tt.bodyMedium?.copyWith(color: cs.onSurface),
          onChanged: onMotivo == null
              ? null
              : (m) {
                  if (m != null) onMotivo!(m);
                },
          items: [
            for (final m in MotivoCancelamentoDono.values)
              DropdownMenuItem(
                value: m,
                child: Text(
                  m.rotuloKey.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CampoMotivoLivre extends StatelessWidget {
  const _CampoMotivoLivre({
    required this.controller,
    required this.comprimento,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final int comprimento;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                'reservas.cancelamento_dono.outro_dica'.tr(),
                style: tt.bodySmall?.copyWith(color: cs.secondary),
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Text(
              'reservas.cancelamento_dono.contador'.tr(
                args: ['$comprimento', '$motivoMaximo'],
              ),
              style: tt.labelSmall?.copyWith(color: cs.secondary),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.xs),
        DecoratedBox(
          decoration: const BoxDecoration(
            borderRadius: AppBorders.md,
            boxShadow: AppShadows.subtle,
          ),
          child: TextField(
            controller: controller,
            enabled: enabled,
            autofocus: true,
            minLines: 3,
            maxLines: 3,
            maxLength: motivoMaximo,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            textCapitalization: TextCapitalization.sentences,
            onChanged: onChanged,
            style: tt.bodyMedium?.copyWith(color: cs.onSurface),
            decoration: InputDecoration(
              hintText: 'reservas.cancelamento_dono.outro_placeholder'.tr(),
              counterText: '',
              filled: true,
              fillColor: cs.surfaceContainerLowest,
              contentPadding: EdgeInsets.all(AppSpacing.md),
              border: const OutlineInputBorder(
                borderRadius: AppBorders.md,
                borderSide: BorderSide.none,
              ),
              enabledBorder: const OutlineInputBorder(
                borderRadius: AppBorders.md,
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppBorders.md,
                borderSide: BorderSide(color: cs.primary),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LinhaErro extends StatelessWidget {
  const _LinhaErro({required this.mensagem});

  final String mensagem;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: AppSpacing.md, color: cs.error),
          SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              mensagem,
              style: context.textTheme.bodySmall?.copyWith(color: cs.error),
            ),
          ),
        ],
      ),
    );
  }
}
