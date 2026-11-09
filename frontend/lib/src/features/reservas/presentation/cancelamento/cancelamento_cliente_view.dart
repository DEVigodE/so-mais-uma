import 'package:so_mais_uma/src/imports/imports.dart';

import '../minhas_reservas/componentes_reserva.dart';
import 'prazo_cancelamento.dart';
import 'texto_prazo.dart';

/// Motivos rápidos do protótipo (chips que preenchem o campo).
const motivosRapidosCancelamento = [
  'reservas.cancelamento_cliente.motivo_equipe',
  'reservas.cancelamento_cliente.motivo_saude',
  'reservas.cancelamento_cliente.motivo_clima',
  'reservas.cancelamento_cliente.motivo_outro',
];

/// Conteúdo do sheet `cancelar_reserva_confirma_o/code.html`, sem estado.
class CancelamentoClienteView extends StatelessWidget {
  const CancelamentoClienteView({
    super.key,
    required this.reserva,
    required this.prazo,
    required this.tamanho,
    required this.motivoCurto,
    required this.podeConfirmar,
    required this.enviando,
    required this.erro,
    required this.motivoController,
    required this.motivoFocus,
    required this.manterFocus,
    required this.onMotivo,
    required this.onChip,
    required this.onManter,
    required this.onConfirmar,
  });

  final Reserva reserva;
  final PrazoCancelamento? prazo;
  final int tamanho;
  final bool motivoCurto;
  final bool podeConfirmar;
  final bool enviando;
  final String? erro;
  final TextEditingController motivoController;
  final FocusNode motivoFocus;
  final FocusNode manterFocus;
  final ValueChanged<String> onMotivo;
  final ValueChanged<String> onChip;
  final VoidCallback onManter;
  final VoidCallback onConfirmar;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final confirmada = reserva.status == StatusReserva.confirmada;
    final prazoAtual = prazo;
    final descricao = tt.bodyMedium?.copyWith(color: cs.secondary);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: AppBorders.bottomSheet,
        boxShadow: AppShadows.modal,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: SizedBox(
                  width: AppSpacing.xxl,
                  height: AppSpacing.s6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: AppBorders.full,
                    ),
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox.square(
                    dimension: AppSpacing.xxl,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.warning,
                        size: AppSpacing.lg + AppSpacing.xs,
                        color: cs.onErrorContainer,
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            'reservas.cancelamento_cliente.titulo'.tr(),
                            style:
                                tt.headlineSmall?.copyWith(color: cs.onSurface),
                          ),
                        ),
                        SizedBox(height: AppSpacing.xxs),
                        TextoComNegrito(
                          'reservas.cancelamento_cliente.descricao'.tr(
                            namedArgs: {
                              'quadra': reserva.quadraNome,
                              'data': Formatadores.dataSemAno(reserva.inicio),
                              'hora': Formatadores.hora(reserva.inicio),
                            },
                          ),
                          style: descricao,
                          estiloNegrito:
                              tt.titleSmall?.copyWith(color: cs.onSurface),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.md),
              _QuadroRegra(prazo: prazoAtual, confirmada: confirmada),
              SizedBox(height: AppSpacing.md),
              _CampoMotivo(
                tamanho: tamanho,
                motivoCurto: motivoCurto,
                controller: motivoController,
                focusNode: motivoFocus,
                enviando: enviando,
                onMotivo: onMotivo,
                onChip: onChip,
              ),
              if (erro != null) ...[
                SizedBox(height: AppSpacing.sm),
                Semantics(
                  liveRegion: true,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: AppBorders.sm,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.sm),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: AppSpacing.ml,
                            color: cs.onErrorContainer,
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              erro!,
                              style: tt.bodySmall
                                  ?.copyWith(color: cs.onErrorContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              SizedBox(height: AppSpacing.md),
              BotaoReserva(
                rotulo: 'reservas.cancelamento_cliente.manter'.tr(),
                icone: Icons.sports_soccer,
                fundo: cs.primary,
                frente: cs.onPrimary,
                autofocus: true,
                focusNode: manterFocus,
                onPressed: enviando ? null : onManter,
              ),
              SizedBox(height: AppSpacing.sm),
              BotaoReserva(
                rotulo: enviando
                    ? 'reservas.cancelamento_cliente.cancelando'.tr()
                    : 'reservas.cancelamento_cliente.confirmar'.tr(),
                icone: Icons.event_busy_outlined,
                fundo: cs.error,
                frente: cs.onError,
                carregando: enviando,
                onPressed: podeConfirmar ? onConfirmar : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuadroRegra extends StatelessWidget {
  const _QuadroRegra({required this.prazo, required this.confirmada});

  final PrazoCancelamento? prazo;
  final bool confirmada;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final prazoAtual = prazo;
    final corpo = tt.bodySmall?.copyWith(color: cs.onSurfaceVariant);
    final atencao = confirmada
        ? 'reservas.cancelamento_cliente.atencao_confirmada'.tr()
        : 'reservas.cancelamento_cliente.atencao_pendente'.tr();
    final textoPrazo =
        prazoAtual == null || prazoAtual.situacao == SituacaoPrazo.naoAplica
            ? null
            : textoPilulaPrazo(prazoAtual);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: AppBorders.md,
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (textoPrazo != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.timer,
                    size: AppSpacing.ml,
                    color: prazoAtual!.situacao == SituacaoPrazo.encerrado
                        ? cs.error
                        : cs.primary,
                  ),
                  SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      textoPrazo,
                      style: tt.titleSmall?.copyWith(
                        color: prazoAtual.situacao == SituacaoPrazo.encerrado
                            ? cs.error
                            : cs.primary,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.xs),
            ],
            TextoComNegrito(
              atencao,
              style: corpo,
              estiloNegrito: tt.labelMedium?.copyWith(color: cs.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

class _CampoMotivo extends StatelessWidget {
  const _CampoMotivo({
    required this.tamanho,
    required this.motivoCurto,
    required this.controller,
    required this.focusNode,
    required this.enviando,
    required this.onMotivo,
    required this.onChip,
  });

  final int tamanho;
  final bool motivoCurto;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enviando;
  final ValueChanged<String> onMotivo;
  final ValueChanged<String> onChip;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final secundario = tt.bodySmall?.copyWith(color: cs.secondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: 'reservas.cancelamento_cliente.motivo_rotulo'.tr(),
                  style: tt.labelLarge?.copyWith(color: cs.onSurface),
                  children: [
                    TextSpan(
                      text: ' *',
                      style: tt.labelLarge?.copyWith(color: cs.error),
                      semanticsLabel: '',
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  'reservas.cancelamento_cliente.contador'.tr(
                    namedArgs: {
                      'n': '$tamanho',
                      'max': '${MotivoCancelamento.maximo}',
                    },
                  ),
                  textAlign: TextAlign.end,
                  style: tt.labelSmall?.copyWith(color: cs.secondary),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.xs),
        Text(
          'reservas.cancelamento_cliente.motivo_dica'.tr(),
          style: secundario,
        ),
        SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final chave in motivosRapidosCancelamento) ...[
                ActionChip(
                  label: Text(chave.tr()),
                  onPressed: enviando ? null : () => onChip(chave.tr()),
                  backgroundColor: cs.surfaceContainerHigh,
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                  labelStyle: tt.labelMedium?.copyWith(color: cs.onSurface),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                ),
                SizedBox(width: AppSpacing.xs),
              ],
            ],
          ),
        ),
        SizedBox(height: AppSpacing.xs),
        DecoratedBox(
          decoration: const BoxDecoration(
            borderRadius: AppBorders.md,
            boxShadow: AppShadows.subtle,
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: !enviando,
            onChanged: onMotivo,
            minLines: 3,
            maxLines: 5,
            maxLength: MotivoCancelamento.maximo,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            textCapitalization: TextCapitalization.sentences,
            style: tt.bodyMedium?.copyWith(color: cs.onSurface),
            decoration: InputDecoration(
              hintText: 'reservas.cancelamento_cliente.motivo_placeholder'.tr(),
              hintStyle: tt.bodyMedium?.copyWith(color: cs.outline),
              counterText: '',
              filled: true,
              fillColor: cs.surfaceContainerLowest,
              contentPadding: EdgeInsets.all(AppSpacing.md),
              border: const OutlineInputBorder(
                borderRadius: AppBorders.md,
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppBorders.md,
                borderSide: BorderSide(color: cs.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppBorders.md,
                borderSide: BorderSide(color: cs.primary, width: 2),
              ),
            ),
          ),
        ),
        if (motivoCurto) ...[
          SizedBox(height: AppSpacing.xs),
          Semantics(
            liveRegion: true,
            child: Row(
              children: [
                Icon(Icons.error, size: AppSpacing.md, color: cs.error),
                SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'reservas.cancelamento_cliente.motivo_curto'.tr(),
                    style: tt.bodySmall?.copyWith(color: cs.error),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
