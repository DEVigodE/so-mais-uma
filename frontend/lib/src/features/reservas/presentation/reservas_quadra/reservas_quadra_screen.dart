import 'dart:async';

import 'package:so_mais_uma/src/imports/imports.dart';

import '../cancelamento_dono/cancelamento_dono_sheet.dart';
import 'reservas_quadra_store.dart';
import 'reservas_quadra_view.dart';
import 'resumo_do_dia.dart';

/// ReservasQuadra do DONO: aba 1 do shell (todas as quadras) e
/// `/dono/quadras/:id/reservas` (com o chip da quadra e o botão voltar).
class ReservasQuadraScreen extends StatefulWidget {
  const ReservasQuadraScreen({
    super.key,
    this.quadraId,
  });

  /// `null` na aba do dono (todas as quadras); id em `/dono/quadras/:id/reservas`.
  final int? quadraId;

  @override
  State<ReservasQuadraScreen> createState() => _ReservasQuadraScreenState();
}

class _ReservasQuadraScreenState extends State<ReservasQuadraScreen> {
  late final ReservasQuadraStore _store;
  EffectCleanup? _efeitoMensagem;

  @override
  void initState() {
    super.initState();
    _store = injector.get<ReservasQuadraStore>();
    unawaited(_store.carregar(quadraId: widget.quadraId));
    _efeitoMensagem = effect(() {
      final mensagem = _store.mensagem.value;
      if (mensagem == null) return;
      Future.microtask(() {
        if (!mounted) return;
        _store.consumirMensagem();
        showAppSnack(context, mensagem, type: SnackBarType.error);
      });
    });
  }

  @override
  void dispose() {
    _efeitoMensagem?.call();
    _store.dispose();
    super.dispose();
  }

  Future<void> _escolherOutroDia() async {
    final hoje = _store.hoje.value;
    final atual = _store.dataSelecionada.value;
    final escolhida = await showDatePicker(
      context: context,
      initialDate: DateTime(atual.year, atual.month, atual.day),
      firstDate: DateTime(hoje.year - 1, hoje.month, hoje.day),
      lastDate: DateTime(hoje.year + 1, hoje.month, hoje.day),
      helpText: 'reservas.dono.outro_dia'.tr(),
    );
    if (escolhida == null || !mounted) return;
    await _store.selecionarData(
      DateTime.utc(escolhida.year, escolhida.month, escolhida.day),
    );
  }

  Future<void> _ligar(Reserva reserva) async {
    final telefone = reserva.clienteTelefone;
    if (telefone == null) return;
    final r = await UrlLauncherService.instance.ligar(telefone);
    _avisarFalhaDeLink(r);
  }

  Future<void> _whatsapp(Reserva reserva) async {
    final telefone = reserva.clienteTelefone;
    if (telefone == null) return;
    final r = await UrlLauncherService.instance.whatsapp(telefone);
    _avisarFalhaDeLink(r);
  }

  void _avisarFalhaDeLink(Either<Failure, void> resultado) {
    if (!mounted || resultado.isRight()) return;
    showAppSnack(context, 'comum.erro_abrir_link'.tr(),
        type: SnackBarType.error);
  }

  Future<void> _cancelar(Reserva alvo) async {
    final resultado = await abrirCancelamentoDono(context, alvo);
    if (!mounted || resultado == null) return;
    switch (resultado) {
      case CancelamentoConcluido(:final reserva):
        _store.aplicarCancelamento(reserva);
        showAppSnack(
          context,
          'reservas.cancelamento_dono.sucesso'.tr(),
          type: SnackBarType.success,
        );
      case CancelamentoRecusado(:final mensagem):
        showAppSnack(context, mensagem, type: SnackBarType.error);
        unawaited(_store.atualizar());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;

    return Scaffold(
      appBar: BarraSuperior(
        titulo: 'comum.app_nome'.tr(),
        tituloStyle: tt.titleSmall?.copyWith(color: cs.onSurface),
        subtitulo: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.s6,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                borderRadius: AppBorders.full,
              ),
              child: Text(
                'reservas.dono.etiqueta_dono'.tr().toUpperCase(),
                style: tt.labelSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  height: 1,
                ),
              ),
            ),
            SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                'reservas.dono.subtitulo_barra'.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
        onAvatar: () => context.go(AppRoutes.donoPerfil),
      ),
      body: SignalBuilder(
        builder: (context) {
          final agora = _store.agora.value;
          return ReservasQuadraView(
            carga: _store.carga.value,
            cargaLista: _store.cargaLista.value,
            quadras: _store.quadras.value,
            quadraFiltro: _store.quadraFiltro.value,
            faixa: _store.faixa.value,
            hoje: _store.hoje.value,
            dataSelecionada: _store.dataSelecionada.value,
            naFaixa: _store.naFaixa.value,
            reservas: _store.reservas.value,
            resumo: _store.resumo.value,
            agora: agora,
            atualizando: _store.atualizando.value,
            podeCancelar: (r) => donoPodeCancelar(r, agora),
            onAtualizar: _store.atualizar,
            onTentarNovamente: _store.tentarNovamente,
            onSelecionarData: _store.selecionarData,
            onOutroDia: _escolherOutroDia,
            onSelecionarQuadra: _store.selecionarQuadra,
            onLigar: _ligar,
            onWhatsapp: _whatsapp,
            onCancelar: _cancelar,
          );
        },
      ),
    );
  }
}
