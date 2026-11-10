import 'package:so_mais_uma/src/imports/imports.dart';

import 'reservas_quadra_card.dart';
import 'resumo_do_dia.dart';

/// Medidas do protótipo (`min-w-[76px] h-[68px]` das datas, `h-9` dos chips).
const double _larguraMinimaData = 76;
const double _alturaData = 68;
const double _alturaChip = 36;

/// View da ReservasQuadra (`reservas_da_quadra_dono/code.html`). Sem estado:
/// recebe o estado do store e os callbacks do contêiner.
class ReservasQuadraView extends StatelessWidget {
  const ReservasQuadraView({
    super.key,
    required this.carga,
    required this.cargaLista,
    required this.quadras,
    required this.quadraFiltro,
    required this.faixa,
    required this.hoje,
    required this.dataSelecionada,
    required this.naFaixa,
    required this.reservas,
    required this.resumo,
    required this.agora,
    required this.atualizando,
    required this.podeCancelar,
    required this.onAtualizar,
    required this.onTentarNovamente,
    required this.onSelecionarData,
    required this.onOutroDia,
    required this.onSelecionarQuadra,
    required this.onLigar,
    required this.onWhatsapp,
    required this.onCancelar,
  });

  final RequestState<void> carga;
  final RequestState<void> cargaLista;
  final List<Quadra> quadras;
  final int? quadraFiltro;
  final List<DateTime> faixa;
  final DateTime hoje;
  final DateTime dataSelecionada;
  final bool naFaixa;
  final List<Reserva> reservas;
  final ResumoDia resumo;
  final DateTime agora;
  final bool atualizando;
  final bool Function(Reserva reserva) podeCancelar;
  final Future<void> Function() onAtualizar;
  final VoidCallback onTentarNovamente;
  final ValueChanged<DateTime> onSelecionarData;
  final VoidCallback onOutroDia;
  final ValueChanged<int?> onSelecionarQuadra;
  final ValueChanged<Reserva> onLigar;
  final ValueChanged<Reserva> onWhatsapp;
  final ValueChanged<Reserva> onCancelar;

  @override
  Widget build(BuildContext context) {
    final gutter = EdgeInsets.symmetric(horizontal: AppSpacing.md);

    return AppRefreshIndicator(
      onRefresh: onAtualizar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xl),
        children: [
          Padding(
            padding: gutter,
            child: _SubCabecalho(
              atualizando: atualizando,
              onAtualizar: onAtualizar,
            ),
          ),
          SizedBox(height: AppSpacing.md),
          ...switch (carga) {
            RequestInitial() || RequestLoading() => [const _Carregando()],
            RequestFailure(:final failure) => [
                Padding(
                  padding: gutter,
                  child: _CaixaErro(
                    mensagem: failure.message,
                    onTentarNovamente: onTentarNovamente,
                  ),
                ),
              ],
            RequestSuccess() => _conteudo(gutter),
          },
        ],
      ),
    );
  }

  List<Widget> _conteudo(EdgeInsets gutter) {
    return [
      Padding(padding: gutter, child: _Resumo(resumo: resumo)),
      SizedBox(height: AppSpacing.md),
      _SeletorDatas(
        faixa: faixa,
        hoje: hoje,
        dataSelecionada: dataSelecionada,
        naFaixa: naFaixa,
        onSelecionar: onSelecionarData,
        onOutroDia: onOutroDia,
      ),
      SizedBox(height: AppSpacing.md),
      _FaixaQuadras(
        quadras: quadras,
        selecionada: quadraFiltro,
        onSelecionar: onSelecionarQuadra,
      ),
      SizedBox(height: AppSpacing.md),
      ...switch (cargaLista) {
        RequestInitial() || RequestLoading() => [const _Carregando()],
        RequestFailure(:final failure) => [
            Padding(
              padding: gutter,
              child: _CaixaErro(
                mensagem: failure.message,
                onTentarNovamente: onTentarNovamente,
              ),
            ),
          ],
        RequestSuccess() => [
            Padding(
              padding: gutter,
              child: _CabecalhoLista(
                quantidade: reservas.length,
                data: dataSelecionada,
                ehHoje: dataSelecionada == hoje,
              ),
            ),
            SizedBox(height: AppSpacing.md),
            if (reservas.isEmpty)
              Padding(padding: gutter, child: const _ListaVazia())
            else
              for (final r in reservas)
                Padding(
                  padding: gutter.copyWith(bottom: AppSpacing.md),
                  child: CardReservaDono(
                    key: ValueKey(r.id),
                    reserva: r,
                    agora: agora,
                    onLigar: () => onLigar(r),
                    onWhatsapp: () => onWhatsapp(r),
                    onCancelar: podeCancelar(r) ? () => onCancelar(r) : null,
                  ),
                ),
          ],
      },
      SizedBox(height: AppSpacing.sm),
      Padding(padding: gutter, child: const _RegrasCancelamento()),
    ];
  }
}

class _SubCabecalho extends StatelessWidget {
  const _SubCabecalho({required this.atualizando, required this.onAtualizar});

  final bool atualizando;
  final Future<void> Function() onAtualizar;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final tamanho = AppSpacing.xl + AppSpacing.sm;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'reservas.dono.titulo'.tr(),
                  style: tt.titleLarge?.copyWith(color: cs.onSurface),
                ),
              ),
              Text(
                'reservas.dono.descricao'.tr(),
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        SizedBox(width: AppSpacing.sm),
        Tooltip(
          message: 'reservas.dono.atualizar'.tr(),
          child: Material(
            color: cs.surfaceContainer,
            borderRadius: AppBorders.md,
            child: InkWell(
              borderRadius: AppBorders.md,
              onTap: atualizando ? null : onAtualizar,
              child: SizedBox(
                width: tamanho,
                height: tamanho,
                child: Center(
                  child: atualizando
                      ? SizedBox.square(
                          dimension: AppSpacing.ml - AppSpacing.xxs,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.primary,
                          ),
                        )
                      : Icon(
                          Icons.sync,
                          size: AppSpacing.ml,
                          color: cs.primary,
                          semanticLabel: 'reservas.dono.atualizar'.tr(),
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Resumo extends StatelessWidget {
  const _Resumo({required this.resumo});

  final ResumoDia resumo;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final numero = tt.headlineSmall?.copyWith(
      color: cs.onSurface,
      fontWeight: FontWeight.w700,
    );
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _BlocoResumo(
              rotulo: 'reservas.dono.resumo.agendadas'.tr(),
              icone: Icons.event_available,
              corIcone: cs.primary,
              valor: '${resumo.agendadas}',
              estiloValor: numero,
              detalhe: resumo.ocupacaoPercentual == null
                  ? null
                  : 'reservas.dono.resumo.ocupado'.tr(
                      args: ['${resumo.ocupacaoPercentual}'],
                    ),
              corDetalhe: cs.primary,
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _BlocoResumo(
              rotulo: 'reservas.dono.resumo.aguardando'.tr(),
              icone: Icons.schedule_outlined,
              corIcone: cs.tertiaryContainer,
              valor: '${resumo.aguardando}',
              estiloValor: numero,
              detalhe: resumo.expiraEmMinutos == null
                  ? null
                  : 'reservas.dono.resumo.expira_em'.tr(
                      args: ['${resumo.expiraEmMinutos}'],
                    ),
              corDetalhe: cs.tertiaryContainer,
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _BlocoResumo(
              rotulo: 'reservas.dono.resumo.previsao'.tr(),
              icone: Icons.payments_outlined,
              corIcone: cs.primary,
              valor: Formatadores.moedaCompacta(resumo.previsao),
              estiloValor: tt.titleMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
              ),
              detalhe: resumo.hoje
                  ? 'reservas.dono.resumo.hoje_total'.tr()
                  : 'reservas.dono.resumo.total_dia'.tr(),
              corDetalhe: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlocoResumo extends StatelessWidget {
  const _BlocoResumo({
    required this.rotulo,
    required this.icone,
    required this.corIcone,
    required this.valor,
    required this.estiloValor,
    required this.corDetalhe,
    this.detalhe,
  });

  final String rotulo;
  final IconData icone;
  final Color corIcone;
  final String valor;
  final TextStyle? estiloValor;
  final String? detalhe;
  final Color corDetalhe;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    return Semantics(
      container: true,
      child: Container(
        padding: EdgeInsets.all(AppSpacing.ms),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: AppBorders.md,
          boxShadow: AppShadows.subtle,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    rotulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                Icon(
                  icone,
                  size: AppSpacing.ml - AppSpacing.xxs,
                  color: corIcone,
                ),
              ],
            ),
            SizedBox(height: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(valor, maxLines: 1, style: estiloValor),
                ),
                if (detalhe != null)
                  Padding(
                    padding: EdgeInsets.only(top: AppSpacing.xxs),
                    child: Text(
                      detalhe!,
                      style: tt.labelSmall?.copyWith(
                        color: corDetalhe,
                        height: 1,
                      ),
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

class _SeletorDatas extends StatelessWidget {
  const _SeletorDatas({
    required this.faixa,
    required this.hoje,
    required this.dataSelecionada,
    required this.naFaixa,
    required this.onSelecionar,
    required this.onOutroDia,
  });

  final List<DateTime> faixa;
  final DateTime hoje;
  final DateTime dataSelecionada;
  final bool naFaixa;
  final ValueChanged<DateTime> onSelecionar;
  final VoidCallback onOutroDia;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    // Data escolhida em "Outro dia" aparece selecionada antes da faixa.
    final datas = [if (!naFaixa) dataSelecionada, ...faixa];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'reservas.dono.data_selecionada'.tr(),
                  style: tt.titleSmall?.copyWith(color: cs.onSurface),
                ),
              ),
              TextButton.icon(
                onPressed: onOutroDia,
                style: TextButton.styleFrom(
                  foregroundColor: cs.primary,
                  textStyle: tt.labelMedium,
                  minimumSize: Size(0, AppSpacing.xxl),
                ),
                icon: Icon(
                  Icons.calendar_month_outlined,
                  size: AppSpacing.ml - AppSpacing.xxs,
                ),
                label: Text('reservas.dono.outro_dia'.tr()),
              ),
            ],
          ),
        ),
        SizedBox(
          height: _alturaData + AppSpacing.sm * 2,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            itemCount: datas.length,
            separatorBuilder: (context, i) => SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, i) {
              final data = datas[i];
              return _ItemData(
                data: data,
                ehHoje: data == hoje,
                selecionada: data == dataSelecionada,
                onTap: () => onSelecionar(data),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ItemData extends StatelessWidget {
  const _ItemData({
    required this.data,
    required this.ehHoje,
    required this.selecionada,
    required this.onTap,
  });

  /// Data de parede (meia-noite UTC com os campos de Brasília).
  final DateTime data;
  final bool ehHoje;
  final bool selecionada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final topo = ehHoje
        ? 'comum.hoje'.tr()
        : Formatadores.nomeDiaSemana(data.weekday, abreviado: true);
    final baixo = _diaMesAbreviado(data);

    return Semantics(
      button: true,
      selected: selecionada,
      label: '$topo, ${Formatadores.dataSemAno(Brasilia.instante(data))}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppBorders.md,
          boxShadow: selecionada ? AppShadows.card : AppShadows.subtle,
        ),
        child: Material(
          color: selecionada ? cs.primary : cs.surfaceContainerLowest,
          borderRadius: AppBorders.md,
          child: InkWell(
            borderRadius: AppBorders.md,
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minWidth: _larguraMinimaData),
              height: _alturaData,
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.ms,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    selecionada ? topo.toUpperCase() : topo,
                    style: tt.labelSmall?.copyWith(
                      color: selecionada
                          ? cs.onPrimaryContainer
                          : cs.onSurfaceVariant,
                      fontWeight:
                          selecionada ? FontWeight.w600 : FontWeight.w500,
                      letterSpacing: selecionada ? 0.8 : null,
                    ),
                  ),
                  Text(
                    baixo,
                    style: (selecionada ? tt.titleLarge : tt.titleMedium)
                        ?.copyWith(
                      color: selecionada ? cs.onPrimary : cs.onSurface,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
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

  /// "24 Out" no idioma ativo.
  static String _diaMesAbreviado(DateTime dataParede) {
    final mes = DateFormat.MMM().format(dataParede).replaceAll('.', '');
    final mesCapitalizado =
        mes.isEmpty ? mes : '${mes[0].toUpperCase()}${mes.substring(1)}';
    return '${dataParede.day} $mesCapitalizado';
  }
}

class _FaixaQuadras extends StatelessWidget {
  const _FaixaQuadras({
    required this.quadras,
    required this.selecionada,
    required this.onSelecionar,
  });

  final List<Quadra> quadras;
  final int? selecionada;
  final ValueChanged<int?> onSelecionar;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _alturaChip + AppSpacing.xs * 2,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xxs,
        ),
        children: [
          _ChipQuadra(
            icone: Icons.apps,
            rotulo: 'reservas.dono.todas_quadras'.tr(
              args: ['${quadras.length}'],
            ),
            selecionado: selecionada == null,
            onTap: () => onSelecionar(null),
          ),
          for (final q in quadras) ...[
            SizedBox(width: AppSpacing.sm),
            _ChipQuadra(
              icone: q.tipoEsporte.icone,
              rotulo: q.nome,
              selecionado: selecionada == q.id,
              onTap: () => onSelecionar(q.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChipQuadra extends StatelessWidget {
  const _ChipQuadra({
    required this.icone,
    required this.rotulo,
    required this.selecionado,
    required this.onTap,
  });

  final IconData icone;
  final String rotulo;
  final bool selecionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final frente = selecionado ? cs.onPrimary : cs.onSurface;
    return Semantics(
      button: true,
      selected: selecionado,
      label: rotulo,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: const ShapeDecoration(
          shape: StadiumBorder(),
          shadows: AppShadows.subtle,
        ),
        child: Material(
          color: selecionado ? cs.primary : cs.surfaceContainerLowest,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Container(
              height: _alturaChip,
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icone,
                    size: AppSpacing.ml - AppSpacing.xxs,
                    color: selecionado ? cs.onPrimary : cs.secondary,
                  ),
                  SizedBox(width: AppSpacing.s6),
                  Text(
                    rotulo,
                    style: context.textTheme.labelMedium?.copyWith(
                      color: frente,
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

class _CabecalhoLista extends StatelessWidget {
  const _CabecalhoLista({
    required this.quantidade,
    required this.data,
    required this.ehHoje,
  });

  final int quantidade;
  final DateTime data;
  final bool ehHoje;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final registros = 'reservas.dono.registros'.plural(quantidade);
    final titulo = ehHoje
        ? 'reservas.dono.horarios_hoje'.tr(namedArgs: {'registros': registros})
        : 'reservas.dono.horarios_data'.tr(
            namedArgs: {
              'data': Formatadores.diaMes(Brasilia.instante(data)),
              'registros': registros,
            },
          );
    return Row(
      children: [
        Expanded(
          child: Text(
            titulo,
            style: tt.titleSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        SizedBox(width: AppSpacing.sm),
        Text(
          'reservas.dono.ordem_cronologica'.tr(),
          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _RegrasCancelamento extends StatelessWidget {
  const _RegrasCancelamento();

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final circulo = AppSpacing.xl;
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: AppBorders.md,
        boxShadow: AppShadows.subtle,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: circulo,
            height: circulo,
            margin: EdgeInsets.only(top: AppSpacing.xxs),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.policy_outlined,
              size: AppSpacing.ml,
              color: cs.primary,
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'reservas.dono.regras_titulo'.tr(),
                  style: tt.titleSmall?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  'reservas.dono.regras_texto'.tr(),
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Carregando extends StatelessWidget {
  const _Carregando();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: AppLoading(message: 'comum.carregando'.tr()),
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
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: AppBorders.md,
          boxShadow: AppShadows.subtle,
        ),
        child: Column(
          children: [
            Icon(Icons.error_outline,
                size: AppSpacing.xl + AppSpacing.sm, color: cs.error),
            SizedBox(height: AppSpacing.sm),
            Text(
              'reservas.dono.erro_titulo'.tr(),
              textAlign: TextAlign.center,
              style: tt.titleSmall?.copyWith(color: cs.onSurface),
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'comum.tentar_novamente'.tr(),
              variant: ButtonVariant.outline,
              onPressed: onTentarNovamente,
            ),
          ],
        ),
      ),
    );
  }
}

class _ListaVazia extends StatelessWidget {
  const _ListaVazia();

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: AppBorders.md,
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_busy_outlined,
            size: AppSpacing.xl + AppSpacing.sm,
            color: cs.onSurfaceVariant,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'reservas.dono.vazio'.tr(),
            textAlign: TextAlign.center,
            style: context.textTheme.titleSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
