import 'package:so_mais_uma/src/imports/imports.dart';

import 'confirmar_reserva_store.dart';

/// View sem estado da ConfirmarReserva (`confirmar_reserva/code.html`), no
/// estado anterior à criação da reserva.
class ConfirmarReservaView extends StatelessWidget {
  const ConfirmarReservaView({
    super.key,
    required this.quadra,
    required this.inicio,
    required this.naoEncontrada,
    required this.observacaoController,
    required this.tamanhoObservacao,
    required this.enviando,
    required this.podeConfirmar,
    required this.onObservacao,
    required this.onConfirmar,
    required this.onTentarNovamente,
    required this.onVoltar,
  });

  final RequestState<Quadra> quadra;
  final DateTime? inicio;
  final bool naoEncontrada;
  final TextEditingController observacaoController;
  final int tamanhoObservacao;
  final bool enviando;
  final bool podeConfirmar;
  final ValueChanged<String> onObservacao;
  final VoidCallback onConfirmar;
  final VoidCallback onTentarNovamente;
  final VoidCallback onVoltar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: BarraSuperior(titulo: 'reservas.confirmar.titulo'.tr()),
      body: switch (quadra) {
        RequestInitial() || RequestLoading() => const _ResumoEsqueleto(),
        RequestFailure(:final failure) => naoEncontrada
            ? _EstadoConfirmar(
                icone: Icons.location_off_outlined,
                titulo: 'reservas.confirmar.nao_encontrada'.tr(),
                rotuloAcao: 'comum.voltar'.tr(),
                onAcao: onVoltar,
              )
            : _EstadoConfirmar(
                icone: failure is NetworkFailure
                    ? Icons.wifi_off_outlined
                    : Icons.error_outline,
                titulo: 'reservas.confirmar.erro_titulo'.tr(),
                mensagem: failure.message,
                rotuloAcao: 'comum.tentar_novamente'.tr(),
                onAcao: onTentarNovamente,
              ),
        RequestSuccess(:final data) => _conteudo(context, data),
      },
    );
  }

  Widget _conteudo(BuildContext context, Quadra quadra) {
    final inicio = this.inicio;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        const _AvisoPrazoPix(),
        SizedBox(height: AppSpacing.lg),
        if (inicio != null) _Resumo(quadra: quadra, inicio: inicio),
        SizedBox(height: AppSpacing.lg),
        _Observacoes(
          controller: observacaoController,
          tamanho: tamanhoObservacao,
          habilitado: !enviando,
          onChanged: onObservacao,
        ),
        SizedBox(height: AppSpacing.lg),
        _BotaoConfirmar(
          enviando: enviando,
          onPressed: podeConfirmar ? onConfirmar : null,
        ),
      ],
    );
  }
}

/// Cartão do aviso de 15 minutos (sem a pílula e o contador, que são da tela
/// Pagamento).
class _AvisoPrazoPix extends StatelessWidget {
  const _AvisoPrazoPix();

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: AppBorders.md,
        boxShadow: AppShadows.subtle,
      ),
      child: ClipRRect(
        borderRadius: AppBorders.md,
        child: Stack(
          children: [
            Positioned(
              right: -24,
              bottom: -24,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: const SizedBox.square(dimension: 96),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: AppBorders.sm,
                ),
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.s10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: AppSpacing.xxs),
                        child: Icon(
                          Icons.info_outline,
                          size: 18,
                          color: cs.tertiary,
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'reservas.confirmar.aviso_pix'.tr(),
                          style: context.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
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

/// Resumo: imagem, esporte, nome, endereço curto, total e data/horário. Lido
/// em bloco pelo leitor de tela.
class _Resumo extends StatelessWidget {
  const _Resumo({required this.quadra, required this.inicio});

  final Quadra quadra;
  final DateTime inicio;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final fim = inicio.add(ConfirmarReservaStore.duracaoSlot);

    return MergeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: AppBorders.md,
          boxShadow: AppShadows.subtle,
        ),
        child: ClipRRect(
          borderRadius: AppBorders.md,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 144,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _FotoResumo(
                      fotoUrl: quadra.fotoUrl,
                      esporte: quadra.tipoEsporte,
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            cs.inverseSurface.withValues(alpha: 0.8),
                            cs.inverseSurface.withValues(alpha: 0),
                          ],
                          stops: const [0, 0.5],
                        ),
                      ),
                    ),
                    Positioned(
                      left: AppSpacing.md,
                      bottom: AppSpacing.md,
                      child:
                          _EtiquetaEsporteResumo(esporte: quadra.tipoEsporte),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.all(AppSpacing.md),
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
                              Text(
                                quadra.nome,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tt.titleLarge
                                    ?.copyWith(color: cs.onSurface),
                              ),
                              SizedBox(height: AppSpacing.xxs),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 16,
                                    color: cs.onSurfaceVariant,
                                  ),
                                  SizedBox(width: AppSpacing.xs),
                                  Flexible(
                                    child: Text(
                                      enderecoCurto(quadra),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: tt.bodySmall?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'reservas.confirmar.total'.tr(),
                              style: tt.labelSmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                            Text(
                              Formatadores.moeda(quadra.precoHora),
                              style: tt.titleLarge?.copyWith(color: cs.primary),
                            ),
                          ],
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
                        padding: EdgeInsets.all(AppSpacing.s10),
                        child: Row(
                          children: [
                            Icon(
                              Icons.event_available_outlined,
                              size: 20,
                              color: cs.primary,
                            ),
                            SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'reservas.confirmar.data_horario'.tr(),
                                    style: tt.labelMedium
                                        ?.copyWith(color: cs.onSurface),
                                  ),
                                  Text(
                                    'reservas.confirmar.data_faixa'.tr(
                                      namedArgs: {
                                        'data': Formatadores.dataLonga(inicio),
                                        'faixa': Formatadores.faixaHorario(
                                          inicio,
                                          fim,
                                        ),
                                      },
                                    ),
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Logradouro, número - Bairro" (spec reservas-cliente).
String enderecoCurto(Quadra quadra) {
  final bairro = quadra.bairro?.trim() ?? '';
  final base = '${quadra.logradouro}, ${quadra.numero}';
  return bairro.isEmpty ? base : '$base - $bairro';
}

class _FotoResumo extends StatelessWidget {
  const _FotoResumo({required this.fotoUrl, required this.esporte});

  final String? fotoUrl;
  final TipoEsporte esporte;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.surfaceContainerHigh,
            cs.primaryFixed.withValues(alpha: 0.45),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          esporte.icone,
          size: 48,
          color: cs.primary.withValues(alpha: 0.55),
        ),
      ),
    );
    final url = fotoUrl?.trim() ?? '';
    if (url.isEmpty) return placeholder;
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      fadeInDuration: AppDurations.normal,
      placeholder: (context, url) => ColoredBox(color: cs.surfaceContainer),
      errorWidget: (context, url, erro) => placeholder,
    );
  }
}

class _EtiquetaEsporteResumo extends StatelessWidget {
  const _EtiquetaEsporteResumo({required this.esporte});

  final TipoEsporte esporte;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest.withValues(alpha: 0.9),
        borderRadius: AppBorders.full,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.s10,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(esporte.icone, size: 14, color: cs.primary),
            SizedBox(width: AppSpacing.xs),
            Text(
              esporte.rotuloCurtoKey.tr(),
              style: context.textTheme.labelMedium?.copyWith(color: cs.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _Observacoes extends StatelessWidget {
  const _Observacoes({
    required this.controller,
    required this.tamanho,
    required this.habilitado,
    required this.onChanged,
  });

  final TextEditingController controller;
  final int tamanho;
  final bool habilitado;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    const limite = ConfirmarReservaStore.limiteObservacao;
    final rotulo = 'reservas.confirmar.observacoes_rotulo'.tr();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: AppBorders.md,
        boxShadow: AppShadows.subtle,
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: ExcludeSemantics(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: rotulo,
                            style:
                                tt.labelMedium?.copyWith(color: cs.onSurface),
                          ),
                          const TextSpan(text: ' '),
                          TextSpan(
                            text: 'reservas.confirmar.opcional'.tr(),
                            style: tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Semantics(
                  liveRegion: true,
                  label: 'reservas.confirmar.contador_semantica'.tr(
                    namedArgs: {'atual': '$tamanho', 'max': '$limite'},
                  ),
                  excludeSemantics: true,
                  child: Text(
                    'reservas.confirmar.contador'.tr(
                      namedArgs: {'atual': '$tamanho', 'max': '$limite'},
                    ),
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.xs),
            MergeSemantics(
              child: Semantics(
                label: rotulo,
                child: TextField(
                  controller: controller,
                  enabled: habilitado,
                  onChanged: onChanged,
                  minLines: 3,
                  maxLines: 3,
                  maxLength: limite,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  textCapitalization: TextCapitalization.sentences,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'reservas.confirmar.observacoes_placeholder'.tr(),
                    hintStyle: tt.bodyMedium?.copyWith(color: cs.outline),
                    filled: true,
                    fillColor: cs.surfaceContainer,
                    contentPadding: EdgeInsets.all(AppSpacing.ms),
                    border: const OutlineInputBorder(
                      borderRadius: AppBorders.sm,
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderRadius: AppBorders.sm,
                      borderSide: BorderSide.none,
                    ),
                    disabledBorder: const OutlineInputBorder(
                      borderRadius: AppBorders.sm,
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppBorders.sm,
                      borderSide: BorderSide(color: cs.primary),
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

/// Diálogo do 502 `PAGAMENTO_INDISPONIVEL` (sem desenho no protótipo): o
/// texto da spec e "Fechar". Ao fechar, a tela volta à grade.
class DialogoPagamentoIndisponivel extends StatelessWidget {
  const DialogoPagamentoIndisponivel({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return AlertDialog(
      backgroundColor: cs.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(borderRadius: AppBorders.dialog),
      icon: Icon(Icons.qr_code_2_outlined, size: 32, color: cs.error),
      title: Text(
        'reservas.confirmar.pagamento_indisponivel_titulo'.tr(),
        textAlign: TextAlign.center,
        style: context.textTheme.titleMedium?.copyWith(color: cs.onSurface),
      ),
      content: Text(
        'reservas.confirmar.pagamento_indisponivel'.tr(),
        textAlign: TextAlign.center,
        style:
            context.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            minimumSize: const Size(120, 44),
            shape: const RoundedRectangleBorder(borderRadius: AppBorders.md),
          ),
          child: Text('comum.fechar'.tr()),
        ),
      ],
    );
  }
}

class _BotaoConfirmar extends StatelessWidget {
  const _BotaoConfirmar({required this.enviando, required this.onPressed});

  final bool enviando;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: enviando ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          disabledBackgroundColor: cs.primary.withValues(alpha: 0.6),
          disabledForegroundColor: cs.onPrimary,
          shape: const RoundedRectangleBorder(borderRadius: AppBorders.md),
          textStyle: context.textTheme.labelLarge,
        ),
        child: enviando
            ? Semantics(
                label: 'comum.carregando'.tr(),
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.onPrimary,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, size: 20),
                  SizedBox(width: AppSpacing.sm),
                  Flexible(child: Text('reservas.confirmar.confirmar'.tr())),
                ],
              ),
      ),
    );
  }
}

class _EstadoConfirmar extends StatelessWidget {
  const _EstadoConfirmar({
    required this.icone,
    required this.titulo,
    required this.rotuloAcao,
    required this.onAcao,
    this.mensagem,
  });

  final IconData icone;
  final String titulo;
  final String? mensagem;
  final String rotuloAcao;
  final VoidCallback onAcao;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            SizedBox(height: AppSpacing.lg),
            AppButton(label: rotuloAcao, onPressed: onAcao),
          ],
        ),
      ),
    );
  }
}

class _ResumoEsqueleto extends StatelessWidget {
  const _ResumoEsqueleto();

  @override
  Widget build(BuildContext context) {
    return Skeletonizer.zone(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.all(AppSpacing.md),
        children: [
          const Bone(
              height: 72, width: double.infinity, borderRadius: AppBorders.md),
          SizedBox(height: AppSpacing.lg),
          const Bone(
              height: 144, width: double.infinity, borderRadius: AppBorders.md),
          SizedBox(height: AppSpacing.md),
          const Bone.text(words: 3, fontSize: 18),
          SizedBox(height: AppSpacing.xs),
          const Bone.text(words: 4, fontSize: 12),
          SizedBox(height: AppSpacing.lg),
          const Bone(
              height: 120, width: double.infinity, borderRadius: AppBorders.md),
        ],
      ),
    );
  }
}
