import 'package:so_mais_uma/src/imports/imports.dart';

import 'faixa_datas.dart';
import 'grade_slots_store.dart';

/// Parte inferior de `detalhe_da_quadra/code.html`: "Escolha a Data", faixa
/// de datas, "Horários Disponíveis", legenda e grade de slots em 2 colunas.
class GradeSlotsView extends StatelessWidget {
  const GradeSlotsView({
    super.key,
    required this.datas,
    required this.dataSelecionada,
    required this.grade,
    required this.visiveis,
    required this.selecionado,
    required this.semLivre,
    required this.proxima,
    required this.onData,
    required this.onSlot,
    required this.onTentarNovamente,
  });

  final List<DataFaixa> datas;
  final DataFaixa? dataSelecionada;
  final RequestState<List<Slot>> grade;

  /// Slots não `FECHADO`.
  final List<Slot> visiveis;
  final Slot? selecionado;
  final bool semLivre;
  final ProximaDataLivre proxima;
  final ValueChanged<DataFaixa> onData;
  final ValueChanged<Slot> onSlot;
  final VoidCallback onTentarNovamente;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final gutter = AppSpacing.md;
    final selecionada = dataSelecionada;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'reservas.grade.escolha_data'.tr(),
                    style: tt.titleMedium?.copyWith(color: cs.onSurface),
                  ),
                ),
              ),
              if (selecionada != null) ...[
                Icon(
                  Icons.calendar_month_outlined,
                  size: 16,
                  color: cs.primary,
                ),
                SizedBox(width: AppSpacing.xs),
                Text(
                  Formatadores.nomeMes(selecionada.data),
                  style: tt.labelMedium?.copyWith(color: cs.primary),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 78 + AppSpacing.xs * 2,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: gutter,
              vertical: AppSpacing.xs,
            ),
            itemCount: datas.length,
            separatorBuilder: (context, _) => SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, i) => _BotaoData(
              data: datas[i],
              selecionada: datas[i] == selecionada,
              onTap: () => onData(datas[i]),
            ),
          ),
        ),
        SizedBox(height: AppSpacing.lg),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'reservas.grade.horarios_disponiveis'.tr(),
                        style: tt.titleMedium?.copyWith(color: cs.onSurface),
                      ),
                    ),
                  ),
                  Text(
                    'reservas.grade.partidas_60'.tr(),
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.sm),
              const _Legenda(),
              SizedBox(height: AppSpacing.ms),
              _area(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _area(BuildContext context) {
    return switch (grade) {
      RequestInitial() || RequestLoading() => const _GradeEsqueleto(),
      RequestFailure(:final failure) => failure is NetworkFailure
          ? _AvisoGrade(
              icone: Icons.wifi_off_outlined,
              texto: 'reservas.grade.sem_conexao'.tr(),
              rotuloAcao: 'comum.tentar_novamente'.tr(),
              onAcao: onTentarNovamente,
            )
          : _AvisoGrade(
              icone: Icons.error_outline,
              texto: 'reservas.grade.erro'.tr(),
              detalhe: failure.message,
              rotuloAcao: 'comum.tentar_novamente'.tr(),
              onAcao: onTentarNovamente,
            ),
      RequestSuccess() => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (semLivre) ...[
              _SemHorarioLivre(
                diaFechado: visiveis.isEmpty,
                proxima: proxima,
                onVerData: onData,
              ),
              if (visiveis.isNotEmpty) SizedBox(height: AppSpacing.ms),
            ],
            if (visiveis.isNotEmpty)
              _Grade(
                slots: visiveis,
                selecionado: selecionado,
                onSlot: onSlot,
              ),
          ],
        ),
    };
  }
}

class _BotaoData extends StatelessWidget {
  const _BotaoData({
    required this.data,
    required this.selecionada,
    required this.onTap,
  });

  final DataFaixa data;
  final bool selecionada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final superior = switch (data.tipo) {
      TipoDia.hoje => 'comum.hoje'.tr(),
      TipoDia.amanha => 'comum.amanha'.tr(),
      TipoDia.outro => diaSemanaAbreviado(data.data),
    };
    final inferior = data.tipo == TipoDia.outro
        ? mesAbreviado(data.data)
        : diaSemanaAbreviado(data.data);

    final corSuperior = selecionada ? cs.primaryFixed : cs.onSurfaceVariant;
    final corDia = selecionada ? cs.onPrimary : cs.onSurface;
    final corInferior =
        selecionada ? cs.onPrimary.withValues(alpha: 0.8) : cs.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selecionada,
      excludeSemantics: true,
      label: Formatadores.dataSemAno(Brasilia.instante(data.data)),
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppBorders.lg,
          boxShadow: AppShadows.subtle,
          color: selecionada ? cs.primary : cs.surfaceContainerLowest,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppBorders.lg,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 70),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      superior.toUpperCase(),
                      style: tt.labelSmall?.copyWith(
                        color: corSuperior,
                        letterSpacing: 0.8,
                        fontWeight:
                            selecionada ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${data.dia}',
                      style: tt.headlineSmall?.copyWith(
                        color: corDia,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      inferior,
                      style: tt.labelSmall?.copyWith(color: corInferior),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Legenda extends StatelessWidget {
  const _Legenda();

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    Widget item(Color cor, String chave) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
              child: const SizedBox.square(dimension: 14),
            ),
            SizedBox(width: AppSpacing.s6),
            Text(
              chave.tr(),
              style: context.textTheme.labelSmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        );

    return Wrap(
      spacing: AppSpacing.ms,
      runSpacing: AppSpacing.xs,
      children: [
        item(cs.primaryFixedDim, 'reservas.grade.legenda_livre'),
        item(cs.surfaceContainerHighest, 'reservas.grade.legenda_ocupado'),
        item(cs.surfaceDim.withValues(alpha: 0.7),
            'reservas.grade.legenda_passado'),
      ],
    );
  }
}

/// Grade em duas colunas; cada linha tem a altura do slot mais alto.
class _Grade extends StatelessWidget {
  const _Grade({
    required this.slots,
    required this.selecionado,
    required this.onSlot,
  });

  final List<Slot> slots;
  final Slot? selecionado;
  final ValueChanged<Slot> onSlot;

  @override
  Widget build(BuildContext context) {
    final espaco = AppSpacing.s10;
    final linhas = <Widget>[];
    for (var i = 0; i < slots.length; i += 2) {
      final a = slots[i];
      final b = i + 1 < slots.length ? slots[i + 1] : null;
      if (i > 0) linhas.add(SizedBox(height: espaco));
      linhas.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _celula(a)),
              SizedBox(width: espaco),
              Expanded(child: b == null ? const SizedBox.shrink() : _celula(b)),
            ],
          ),
        ),
      );
    }
    return Column(children: linhas);
  }

  Widget _celula(Slot slot) => SlotTile(
        slot: slot,
        selecionado: slot == selecionado,
        onTap: () => onSlot(slot),
      );
}

/// Um slot da grade, nos estados LIVRE, LIVRE selecionado, OCUPADO e PASSADO.
class SlotTile extends StatelessWidget {
  const SlotTile({
    super.key,
    required this.slot,
    required this.selecionado,
    required this.onTap,
  });

  final Slot slot;
  final bool selecionado;
  final VoidCallback onTap;

  String _semantica() {
    final args = {
      'inicio': '${Brasilia.parede(slot.inicio).hour}',
      'fim': '${Brasilia.parede(slot.fim).hour}',
      'preco': Formatadores.moeda(slot.valor),
    };
    return switch (slot.status) {
      StatusSlot.livre =>
        'reservas.grade.slot_semantica_livre'.tr(namedArgs: args),
      StatusSlot.ocupado =>
        'reservas.grade.slot_semantica_ocupado'.tr(namedArgs: args),
      _ => 'reservas.grade.slot_semantica_passado'.tr(namedArgs: args),
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final faixa = faixaSlot(slot.inicio, slot.fim);
    final padding = EdgeInsets.all(AppSpacing.ms);

    final Widget conteudo = switch (slot.status) {
      StatusSlot.livre when selecionado => DecoratedBox(
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: AppBorders.md,
            border: Border.all(color: cs.primaryFixed, width: 2),
            boxShadow: AppShadows.subtle,
          ),
          child: Padding(
            padding: padding,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        faixa,
                        style: tt.labelLarge?.copyWith(
                          color: cs.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(Icons.check_circle, size: 20, color: cs.primaryFixed),
                  ],
                ),
                SizedBox(height: AppSpacing.xxs),
                Text(
                  Formatadores.moeda(slot.valor),
                  textAlign: TextAlign.end,
                  style: tt.labelSmall?.copyWith(
                    color: cs.primaryFixed,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      StatusSlot.livre => DecoratedBox(
          decoration: BoxDecoration(
            color: cs.primaryFixed.withValues(alpha: 0.2),
            borderRadius: AppBorders.md,
          ),
          child: Padding(
            padding: padding,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        faixa,
                        style: tt.labelLarge?.copyWith(color: cs.primary),
                      ),
                      Text(
                        'reservas.grade.disponivel'.tr(),
                        style:
                            tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Text(
                  Formatadores.moedaCompacta(slot.valor),
                  style: tt.labelMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      StatusSlot.ocupado => DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: AppBorders.md,
          ),
          child: Padding(
            padding: padding,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        faixa,
                        style: tt.labelLarge?.copyWith(color: cs.secondary),
                      ),
                      Text(
                        'reservas.grade.reservado'.tr(),
                        style: tt.labelSmall?.copyWith(color: cs.secondary),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.lock_outline, size: 18, color: cs.secondary),
              ],
            ),
          ),
        ),
      _ => Opacity(
          opacity: 0.6,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: AppBorders.md,
            ),
            child: Padding(
              padding: padding,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      faixa,
                      style: tt.labelLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                  Icon(Icons.history, size: 18, color: cs.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
    };

    return Semantics(
      button: true,
      enabled: slot.livre,
      selected: selecionado,
      excludeSemantics: true,
      label: _semantica(),
      onTap: slot.livre ? onTap : null,
      child: slot.livre
          ? Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                borderRadius: AppBorders.md,
                child: conteudo,
              ),
            )
          : conteudo,
    );
  }
}

/// Data sem slot livre: aviso e, quando achada, a próxima data com horário.
class _SemHorarioLivre extends StatelessWidget {
  const _SemHorarioLivre({
    required this.diaFechado,
    required this.proxima,
    required this.onVerData,
  });

  final bool diaFechado;
  final ProximaDataLivre proxima;
  final ValueChanged<DataFaixa> onVerData;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final Widget? rodape = switch (proxima) {
      ProximaBuscando() => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.primary,
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                'reservas.grade.buscando_proxima'.tr(),
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ProximaEncontrada(:final data) => AppButton(
          label: 'reservas.grade.ver_data'.tr(namedArgs: {
            'data': 'reservas.grade.dia_curto'.tr(namedArgs: {
              'semana': diaSemanaAbreviado(data.data),
              'data': diaMesParede(data.data),
            }),
          }),
          height: ButtonSize.small,
          suffixIcon: Icon(Icons.arrow_forward, size: 18, color: cs.onPrimary),
          onPressed: () => onVerData(data),
        ),
      ProximaNenhuma() => Text(
          'reservas.grade.sem_livre_janela'.tr(),
          textAlign: TextAlign.center,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ProximaNaoAplicavel() => null,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: AppBorders.lg,
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Icon(
              diaFechado
                  ? Icons.event_busy_outlined
                  : Icons.event_note_outlined,
              size: 28,
              color: cs.onSurfaceVariant,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              diaFechado
                  ? 'reservas.grade.dia_fechado'.tr()
                  : 'reservas.grade.sem_livre'.tr(),
              textAlign: TextAlign.center,
              style: tt.titleSmall?.copyWith(color: cs.onSurface),
            ),
            if (rodape != null) ...[
              SizedBox(height: AppSpacing.ms),
              rodape,
            ],
          ],
        ),
      ),
    );
  }
}

/// Falha ou falta de conexão, só na área da grade.
class _AvisoGrade extends StatelessWidget {
  const _AvisoGrade({
    required this.icone,
    required this.texto,
    required this.rotuloAcao,
    required this.onAcao,
    this.detalhe,
  });

  final IconData icone;
  final String texto;
  final String? detalhe;
  final String rotuloAcao;
  final VoidCallback onAcao;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: AppBorders.lg,
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Icon(icone, size: 28, color: cs.onSurfaceVariant),
            SizedBox(height: AppSpacing.sm),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: tt.titleSmall?.copyWith(color: cs.onSurface),
            ),
            if (detalhe != null && detalhe!.isNotEmpty) ...[
              SizedBox(height: AppSpacing.xs),
              Text(
                detalhe!,
                textAlign: TextAlign.center,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
            SizedBox(height: AppSpacing.ms),
            AppButton(
              label: rotuloAcao,
              height: ButtonSize.small,
              variant: ButtonVariant.outline,
              onPressed: onAcao,
            ),
          ],
        ),
      ),
    );
  }
}

/// Carregando: esqueleto de uma linha de slots.
class _GradeEsqueleto extends StatelessWidget {
  const _GradeEsqueleto();

  @override
  Widget build(BuildContext context) {
    final espaco = AppSpacing.s10;
    return Skeletonizer.zone(
      child: Row(
        children: [
          const Expanded(child: Bone(height: 56, borderRadius: AppBorders.md)),
          SizedBox(width: espaco),
          const Expanded(child: Bone(height: 56, borderRadius: AppBorders.md)),
        ],
      ),
    );
  }
}

/// Barra fixa "Horário selecionado" com o dia, a faixa, o total e
/// "Continuar". Sem slot selecionado, não ocupa espaço.
class BarraHorarioSelecionado extends StatelessWidget {
  const BarraHorarioSelecionado({
    super.key,
    required this.slot,
    required this.data,
    required this.onContinuar,
  });

  final Slot? slot;

  /// Data selecionada na faixa (a do slot).
  final DataFaixa? data;
  final VoidCallback onContinuar;

  String _dia(DataFaixa data) => switch (data.tipo) {
        TipoDia.hoje => 'comum.hoje'.tr(),
        TipoDia.amanha => 'comum.amanha'.tr(),
        TipoDia.outro => 'reservas.grade.dia_curto'.tr(namedArgs: {
            'semana': diaSemanaAbreviado(data.data),
            'data': diaMesParede(data.data),
          }),
      };

  @override
  Widget build(BuildContext context) {
    final selecionado = slot;
    final dia = data;
    return AnimatedSize(
      duration: AppDurations.normal,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: selecionado == null || dia == null
          ? const SizedBox(width: double.infinity)
          : _conteudo(context, selecionado, dia),
    );
  }

  Widget _conteudo(BuildContext context, Slot slot, DataFaixa dia) {
    final cs = context.colors;
    final tt = context.textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest.withValues(alpha: 0.95),
        boxShadow: AppShadows.bottomBar,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.ms,
          ),
          child: Row(
            children: [
              Expanded(
                child: MergeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'reservas.grade.horario_selecionado'.tr().toUpperCase(),
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'reservas.grade.barra_dia'.tr(namedArgs: {
                          'dia': _dia(dia),
                          'faixa': faixaSlot(slot.inicio, slot.fim),
                        }),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleSmall?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'reservas.grade.total'.tr(namedArgs: {
                          'valor': Formatadores.moeda(slot.valor),
                        }),
                        style: tt.labelSmall?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.ms),
              FilledButton(
                onPressed: onContinuar,
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  minimumSize: const Size(0, 48),
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.ml),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppBorders.md,
                  ),
                  textStyle: tt.labelLarge,
                  elevation: 2,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('comum.continuar'.tr()),
                    SizedBox(width: AppSpacing.sm),
                    const Icon(Icons.arrow_forward, size: 20),
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
