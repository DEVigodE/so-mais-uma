import 'package:so_mais_uma/src/imports/imports.dart';

import '../quadras/quadra_card.dart';
import '../quadras/quadras_view.dart';
import 'horarios_agrupados.dart';

/// Monta o corpo da DetalheQuadra com a seção de reserva: `secao` entra no fim
/// da rolagem e `barra` fica fixa no rodapé da tela.
typedef LayoutSecaoReserva = Widget Function(Widget secao, Widget barra);

/// Seção de reserva composta pelo router (feature `reservas`), que chama
/// `layout` com a grade e a barra "Horário selecionado".
typedef ConstrutorSecaoReserva = Widget Function(
  Quadra quadra,
  LayoutSecaoReserva layout,
);

/// View sem estado da DetalheQuadra (parte estática de
/// `detalhe_da_quadra/code.html`).
class DetalheQuadraView extends StatelessWidget {
  const DetalheQuadraView({
    super.key,
    required this.estado,
    required this.grupos,
    required this.naoEncontrada,
    required this.onTentarNovamente,
    required this.onVoltar,
    required this.onAbrirMapa,
    this.secaoReserva,
  });

  final RequestState<Quadra> estado;
  final List<GrupoFuncionamento> grupos;
  final bool naoEncontrada;
  final VoidCallback onTentarNovamente;
  final VoidCallback onVoltar;
  final ValueChanged<Quadra> onAbrirMapa;

  /// `null` na variante do DONO: sem faixa de datas, grade nem barra.
  final ConstrutorSecaoReserva? secaoReserva;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: BarraSuperior(titulo: 'quadras.detalhe.titulo'.tr()),
      body: switch (estado) {
        RequestInitial() || RequestLoading() => const _DetalheEsqueleto(),
        RequestFailure(:final failure) => naoEncontrada
            ? EstadoQuadras(
                icone: Icons.location_off_outlined,
                titulo: 'quadras.detalhe.nao_encontrada_titulo'.tr(),
                mensagem: 'quadras.detalhe.nao_encontrada_mensagem'.tr(),
                rotuloAcao: 'comum.voltar'.tr(),
                onAcao: onVoltar,
              )
            : EstadoQuadras(
                icone: failure is NetworkFailure
                    ? Icons.wifi_off_outlined
                    : Icons.error_outline,
                titulo: 'quadras.detalhe.erro_titulo'.tr(),
                mensagem: failure.message,
                rotuloAcao: 'comum.tentar_novamente'.tr(),
                onAcao: onTentarNovamente,
              ),
        RequestSuccess(:final data) => _conteudo(context, data),
      },
    );
  }

  Widget _conteudo(BuildContext context, Quadra quadra) {
    final estatico = <Widget>[
      _Destaque(quadra: quadra),
      Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Cabecalho(quadra: quadra, onAbrirMapa: () => onAbrirMapa(quadra)),
            if ((quadra.descricao ?? '').trim().isNotEmpty) ...[
              SizedBox(height: AppSpacing.lg),
              _CartaoSobre(descricao: quadra.descricao!.trim()),
            ],
            SizedBox(height: AppSpacing.lg),
            _CartaoFuncionamento(grupos: grupos),
          ],
        ),
      ),
    ];

    final secao = secaoReserva;
    if (secao == null) {
      return ListView(
        padding: EdgeInsets.only(bottom: AppSpacing.xl),
        children: estatico,
      );
    }
    return secao(
      quadra,
      (grade, barra) => Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(bottom: AppSpacing.xl),
              children: [
                ...estatico,
                SizedBox(height: AppSpacing.lg),
                grade,
              ],
            ),
          ),
          barra,
        ],
      ),
    );
  }
}

/// Imagem de destaque com degradê, etiqueta de esporte e preço por hora.
class _Destaque extends StatelessWidget {
  const _Destaque({required this.quadra});

  final Quadra quadra;

  static const _cantos = BorderRadius.vertical(bottom: Radius.circular(24));

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: _cantos,
        boxShadow: AppShadows.card,
      ),
      child: ClipRRect(
        borderRadius: _cantos,
        child: SizedBox(
          height: 256,
          child: Stack(
            fit: StackFit.expand,
            children: [
              FotoQuadra(
                fotoUrl: quadra.fotoUrl,
                esporte: quadra.tipoEsporte,
                tamanhoIcone: 72,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      cs.inverseSurface.withValues(alpha: 0.9),
                      cs.inverseSurface.withValues(alpha: 0.3),
                      cs.inverseSurface.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: AppSpacing.md,
                left: AppSpacing.md,
                child: EtiquetaEsporte(
                  esporte: quadra.tipoEsporte,
                  tamanhoIcone: 18,
                  estiloTexto: tt.labelMedium?.copyWith(color: cs.onSurface),
                ),
              ),
              Positioned(
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: AppSpacing.md,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'quadras.detalhe.a_partir_de'.tr().toUpperCase(),
                      style: tt.labelSmall?.copyWith(
                        color: cs.surfaceContainerHigh,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: Formatadores.moeda(quadra.precoHora),
                            style: tt.headlineLarge?.copyWith(
                              color: cs.primaryFixed,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const TextSpan(text: ' '),
                          TextSpan(
                            text: 'quadras.detalhe.por_hora'.tr(),
                            style: tt.bodySmall?.copyWith(
                              color: cs.onInverseSurface.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
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

/// Nome, endereço e "Abrir no Maps".
class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.quadra, required this.onAbrirMapa});

  final Quadra quadra;
  final VoidCallback onAbrirMapa;

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
            quadra.nome,
            style: tt.headlineMedium?.copyWith(
              color: cs.onSurface,
              letterSpacing: -0.3,
            ),
          ),
        ),
        SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: AppSpacing.xxs),
              child: Icon(
                Icons.location_on_outlined,
                size: 20,
                color: cs.primary,
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    enderecoDetalhe(quadra),
                    style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                  ),
                  if (quadra.temCoordenadas) ...[
                    SizedBox(height: AppSpacing.xs),
                    Semantics(
                      button: true,
                      excludeSemantics: true,
                      label: 'quadras.detalhe.abrir_maps_semantica'.tr(),
                      onTap: onAbrirMapa,
                      child: TextButton.icon(
                        onPressed: onAbrirMapa,
                        icon: const Icon(Icons.map_outlined, size: 16),
                        label: Text('quadras.detalhe.abrir_maps'.tr()),
                        style: TextButton.styleFrom(
                          backgroundColor: cs.surfaceContainerHigh,
                          foregroundColor: cs.primary,
                          textStyle: tt.labelMedium,
                          shape: const StadiumBorder(),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.ms,
                          ),
                          minimumSize: const Size(0, 32),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// "Logradouro, número - Bairro, Cidade" (spec quadras-cliente).
String enderecoDetalhe(Quadra quadra) {
  final bairro = quadra.bairro?.trim() ?? '';
  final local = bairro.isEmpty ? quadra.cidade : '$bairro, ${quadra.cidade}';
  return '${quadra.logradouro}, ${quadra.numero} - $local';
}

class _CartaoSobre extends StatelessWidget {
  const _CartaoSobre({required this.descricao});

  final String descricao;

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sports, size: 18, color: cs.primary),
                SizedBox(width: AppSpacing.s6),
                Text(
                  'quadras.detalhe.sobre'.tr(),
                  style: tt.titleSmall?.copyWith(color: cs.onSurface),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              descricao,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartaoFuncionamento extends StatelessWidget {
  const _CartaoFuncionamento({required this.grupos});

  final List<GrupoFuncionamento> grupos;

  static const _chavesDias = {
    1: 'segunda',
    2: 'terca',
    3: 'quarta',
    4: 'quinta',
    5: 'sexta',
    6: 'sabado',
    7: 'domingo',
  };

  String _rotulo(GrupoFuncionamento grupo) => rotuloDiasDoGrupo(
        grupo,
        nomeDia: (dia) => 'quadras.detalhe.dias.${_chavesDias[dia]}'.tr(),
        doisDias: (a, b) => 'quadras.detalhe.dois_dias'
            .tr(namedArgs: {'primeiro': a, 'segundo': b}),
        intervalo: (a, b) => 'quadras.detalhe.intervalo_dias'
            .tr(namedArgs: {'primeiro': a, 'ultimo': b}),
      );

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final valorStyle = tt.bodySmall?.copyWith(color: cs.onSurfaceVariant);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: AppBorders.lg,
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(
                dimension: 40,
                child: Icon(
                  Icons.schedule_outlined,
                  size: 20,
                  color: cs.primary,
                ),
              ),
            ),
            SizedBox(width: AppSpacing.ms),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'quadras.detalhe.horarios_titulo'.tr(),
                    style: tt.titleSmall?.copyWith(color: cs.onSurface),
                  ),
                  SizedBox(height: AppSpacing.xxs),
                  if (grupos.isEmpty)
                    Text('quadras.detalhe.sem_horarios'.tr(), style: valorStyle)
                  else
                    for (final grupo in grupos)
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'quadras.detalhe.rotulo_dias'
                                  .tr(namedArgs: {'dias': _rotulo(grupo)}),
                              style:
                                  tt.labelMedium?.copyWith(color: cs.onSurface),
                            ),
                            const TextSpan(text: ' '),
                            TextSpan(
                              text: grupo.fechado
                                  ? 'quadras.detalhe.fechado'.tr()
                                  : '${grupo.abertura} – ${grupo.fechamento}',
                            ),
                          ],
                        ),
                        style: valorStyle,
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

class _DetalheEsqueleto extends StatelessWidget {
  const _DetalheEsqueleto();

  @override
  Widget build(BuildContext context) {
    return Skeletonizer.zone(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: [
          const SizedBox(
            height: 256,
            child: Bone(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Bone.text(words: 3, fontSize: 24),
                SizedBox(height: AppSpacing.sm),
                const Bone.text(words: 5),
                SizedBox(height: AppSpacing.lg),
                const Bone(
                  height: 96,
                  width: double.infinity,
                  borderRadius: AppBorders.lg,
                ),
                SizedBox(height: AppSpacing.lg),
                const Bone(
                  height: 88,
                  width: double.infinity,
                  borderRadius: AppBorders.lg,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
