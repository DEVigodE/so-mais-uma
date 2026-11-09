import 'package:so_mais_uma/src/imports/imports.dart';

import 'form_quadra_campos.dart';
import 'form_quadra_formatadores.dart';
import 'form_quadra_store.dart';

/// View sem estado da FormQuadra (`nova_quadra/code.html`).
///
/// Omitidos: o botão de ajuda, a pílula "RF06 / RF09" (e "RF09" da seção de
/// endereço), o envio de arquivo ("Alterar") e "Formatos aceitos: JPG, PNG até
/// 5MB". O campo "Cidade / UF" virou dois campos, como no contrato.
class FormQuadraView extends StatelessWidget {
  const FormQuadraView({
    super.key,
    required this.edicao,
    required this.carga,
    required this.campos,
    required this.erros,
    required this.estadoCep,
    required this.coordenadasAuto,
    required this.urlPreview,
    required this.salvando,
    required this.podeBuscarCep,
    required this.controladores,
    required this.focos,
    required this.onAlterar,
    required this.onEsporte,
    required this.onBuscarCep,
    required this.onAtualizarPreview,
    required this.onVoltar,
    required this.onSalvar,
    required this.onTentarNovamente,
  });

  final bool edicao;
  final RequestState<void> carga;
  final FormQuadraCampos campos;
  final Map<CampoQuadra, String> erros;
  final EstadoCep estadoCep;
  final bool coordenadasAuto;
  final String urlPreview;
  final bool salvando;
  final bool podeBuscarCep;
  final Map<CampoQuadra, TextEditingController> controladores;
  final Map<CampoQuadra, FocusNode> focos;
  final void Function(CampoQuadra campo, String valor) onAlterar;
  final ValueChanged<TipoEsporte?> onEsporte;
  final VoidCallback onBuscarCep;
  final VoidCallback onAtualizarPreview;
  final VoidCallback onVoltar;
  final VoidCallback onSalvar;
  final VoidCallback onTentarNovamente;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: BarraSuperior(
        titulo: edicao
            ? 'quadras.form.titulo_editar'.tr()
            : 'quadras.form.titulo_nova'.tr(),
        tituloStyle:
            context.textTheme.titleLarge?.copyWith(color: cs.onSurface),
        mostrarVoltar: true,
        onVoltar: onVoltar,
      ),
      body: switch (carga) {
        RequestInitial() ||
        RequestLoading() =>
          const Center(child: CircularProgressIndicator()),
        RequestFailure(:final failure) => _Falha(
            naoEncontrada: failure is ApiFailure && failure.naoEncontrado,
            mensagem: failure.message,
            onVoltar: onVoltar,
            onTentarNovamente: onTentarNovamente,
          ),
        RequestSuccess() => _Formulario(view: this),
      },
    );
  }
}

class _Formulario extends StatelessWidget {
  const _Formulario({required this.view});

  final FormQuadraView view;

  @override
  Widget build(BuildContext context) {
    final v = view;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.lg + context.safeArea.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CartaoContexto(esporte: v.campos.esporte),
          SizedBox(height: AppSpacing.lg),
          _SecaoBasica(view: v),
          SizedBox(height: AppSpacing.lg),
          _SecaoEndereco(view: v),
          SizedBox(height: AppSpacing.lg),
          _SecaoFoto(view: v),
          SizedBox(height: AppSpacing.lg),
          _BarraAcoes(
            salvando: v.salvando,
            onCancelar: v.onVoltar,
            onSalvar: v.onSalvar,
          ),
        ],
      ),
    );
  }
}

/// "GESTÃO DO DONO" / "Configurar Arena".
class _CartaoContexto extends StatelessWidget {
  const _CartaoContexto({required this.esporte});

  final TipoEsporte? esporte;

  static const double _circulo = 40;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: AppBorders.md,
        boxShadow: AppShadows.subtle,
      ),
      child: Row(
        children: [
          Container(
            width: _circulo,
            height: _circulo,
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              esporte?.icone ?? Icons.sports_soccer,
              color: cs.primary,
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'quadras.form.gestao_dono'.tr().toUpperCase(),
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  'quadras.form.configurar_arena'.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleMedium?.copyWith(color: cs.onSurface),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Secao extends StatelessWidget {
  const _Secao({
    required this.icone,
    required this.titulo,
    required this.children,
  });

  final IconData icone;
  final String titulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
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
            Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(icone, size: 20, color: cs.primary),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        titulo,
                        style: context.textTheme.titleMedium
                            ?.copyWith(color: cs.onSurface),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (final (i, filho) in children.indexed) ...[
              if (i > 0) SizedBox(height: AppSpacing.md),
              filho,
            ],
          ],
        ),
      ),
    );
  }
}

class _SecaoBasica extends StatelessWidget {
  const _SecaoBasica({required this.view});

  final FormQuadraView view;

  @override
  Widget build(BuildContext context) {
    final v = view;
    final cs = context.colors;
    final tt = context.textTheme;
    return _Secao(
      icone: Icons.info_outlined,
      titulo: 'quadras.form.secao_basica'.tr(),
      children: [
        _CampoTexto(
          view: v,
          campo: CampoQuadra.nome,
          rotulo: 'quadras.form.nome'.tr(),
          obrigatorio: true,
          dica: 'quadras.form.nome_dica'.tr(),
          limite: LimitesQuadra.nome,
          capitalizacao: TextCapitalization.words,
        ),
        _SeletorEsporte(view: v),
        _CampoTexto(
          view: v,
          campo: CampoQuadra.preco,
          rotulo: 'quadras.form.preco'.tr(),
          obrigatorio: true,
          dica: 'quadras.form.preco_dica'.tr(),
          teclado: TextInputType.number,
          formatadores: const [MoedaInputFormatter()],
          prefixo: Padding(
            padding: EdgeInsetsDirectional.only(
              start: AppSpacing.md,
              end: AppSpacing.sm,
            ),
            child: Text(
              'quadras.form.moeda'.tr(),
              style: tt.titleSmall?.copyWith(color: cs.primary),
            ),
          ),
          ajuda: 'quadras.form.preco_ajuda'.tr(),
        ),
        _CampoTexto(
          view: v,
          campo: CampoQuadra.descricao,
          rotulo: 'quadras.form.descricao'.tr(),
          dica: 'quadras.form.descricao_dica'.tr(),
          limite: LimitesQuadra.descricao,
          linhas: 3,
          capitalizacao: TextCapitalization.sentences,
          acao: TextInputAction.newline,
        ),
      ],
    );
  }
}

class _SecaoEndereco extends StatelessWidget {
  const _SecaoEndereco({required this.view});

  final FormQuadraView view;

  @override
  Widget build(BuildContext context) {
    final v = view;
    return _Secao(
      icone: Icons.pin_drop_outlined,
      titulo: 'quadras.form.secao_endereco'.tr(),
      children: [
        _CampoCep(view: v),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 8,
              child: _CampoTexto(
                view: v,
                campo: CampoQuadra.logradouro,
                rotulo: 'quadras.form.logradouro'.tr(),
                obrigatorio: true,
                limite: LimitesQuadra.logradouro,
                mostrarContador: false,
                capitalizacao: TextCapitalization.words,
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              flex: 4,
              child: _CampoTexto(
                view: v,
                campo: CampoQuadra.numero,
                rotulo: 'quadras.form.numero'.tr(),
                obrigatorio: true,
                limite: LimitesQuadra.numero,
                mostrarContador: false,
                centralizado: true,
              ),
            ),
          ],
        ),
        _CampoTexto(
          view: v,
          campo: CampoQuadra.bairro,
          rotulo: 'quadras.form.bairro'.tr(),
          limite: LimitesQuadra.bairro,
          mostrarContador: false,
          capitalizacao: TextCapitalization.words,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 8,
              child: _CampoTexto(
                view: v,
                campo: CampoQuadra.cidade,
                rotulo: 'quadras.form.cidade'.tr(),
                obrigatorio: true,
                limite: LimitesQuadra.cidade,
                mostrarContador: false,
                capitalizacao: TextCapitalization.words,
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              flex: 4,
              child: _CampoTexto(
                view: v,
                campo: CampoQuadra.uf,
                rotulo: 'quadras.form.uf'.tr(),
                obrigatorio: true,
                centralizado: true,
                capitalizacao: TextCapitalization.characters,
                formatadores: [
                  FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
                  LengthLimitingTextInputFormatter(2),
                  const MaiusculasInputFormatter(),
                ],
              ),
            ),
          ],
        ),
        _BlocoGeolocalizacao(view: v),
      ],
    );
  }
}

class _SecaoFoto extends StatelessWidget {
  const _SecaoFoto({required this.view});

  final FormQuadraView view;

  @override
  Widget build(BuildContext context) {
    final v = view;
    final cs = context.colors;
    final tt = context.textTheme;
    return _Secao(
      icone: Icons.photo_camera_outlined,
      titulo: 'quadras.form.secao_foto'.tr(),
      children: [
        _CampoTexto(
          view: v,
          campo: CampoQuadra.fotoUrl,
          rotulo: 'quadras.form.foto_url'.tr(),
          dica: 'quadras.form.foto_url_dica'.tr(),
          limite: LimitesQuadra.fotoUrl,
          mostrarContador: false,
          teclado: TextInputType.url,
          acao: TextInputAction.done,
          aoEnviar: (_) => v.onAtualizarPreview(),
          sufixo: IconButton(
            tooltip: 'quadras.form.foto_recarregar'.tr(),
            onPressed: v.onAtualizarPreview,
            icon: Icon(Icons.link, size: 18, color: cs.onSurfaceVariant),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'quadras.form.preview'.tr(),
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            SizedBox(height: AppSpacing.sm),
            _PreVisualizacao(
              url: v.urlPreview,
              esporte: v.campos.esporte,
              nome: v.campos.nome,
            ),
          ],
        ),
        Text(
          'quadras.form.proporcao'.tr(),
          textAlign: TextAlign.center,
          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Rótulo acima do campo, com o asterisco dos obrigatórios e o contador.
class _Rotulo extends StatelessWidget {
  const _Rotulo({
    required this.texto,
    this.obrigatorio = false,
    this.contador,
  });

  final String texto;
  final bool obrigatorio;
  final String? contador;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final estilo =
        context.textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant);
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                text: texto,
                children: [
                  if (obrigatorio)
                    TextSpan(text: ' *', style: TextStyle(color: cs.error)),
                ],
              ),
              style: estilo,
            ),
          ),
          if (contador != null)
            ExcludeSemantics(
              child: Text(
                contador!,
                style: estilo?.copyWith(
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Mensagem de erro abaixo do campo, anunciada pelo leitor de tela.
class _ErroCampo extends StatelessWidget {
  const _ErroCampo(this.mensagem);

  final String mensagem;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Padding(
      padding: EdgeInsets.only(top: AppSpacing.xs, left: AppSpacing.xs),
      child: Semantics(
        liveRegion: true,
        child: Text(
          mensagem,
          style: context.textTheme.bodySmall?.copyWith(color: cs.error),
        ),
      ),
    );
  }
}

InputDecoration _decoracao(
  BuildContext context, {
  required bool comErro,
  String? dica,
  Widget? prefixo,
  Widget? sufixo,
}) {
  final cs = context.colors;
  OutlineInputBorder borda(Color cor, [double largura = 1]) =>
      OutlineInputBorder(
        borderRadius: AppBorders.sm,
        borderSide: BorderSide(color: cor, width: largura),
      );
  final normal = comErro ? cs.error : cs.outlineVariant.withValues(alpha: 0.6);
  return InputDecoration(
    hintText: dica,
    hintStyle: context.textTheme.bodyMedium?.copyWith(color: cs.outlineVariant),
    filled: true,
    fillColor: cs.surfaceContainerLowest,
    isDense: true,
    counterText: '',
    contentPadding: EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.s14,
    ),
    prefixIcon: prefixo,
    prefixIconConstraints: const BoxConstraints(),
    suffixIcon: sufixo,
    border: borda(normal),
    enabledBorder: borda(normal),
    disabledBorder: borda(cs.outlineVariant.withValues(alpha: 0.3)),
    focusedBorder: borda(comErro ? cs.error : cs.primary, 2),
  );
}

class _CampoTexto extends StatelessWidget {
  const _CampoTexto({
    required this.view,
    required this.campo,
    required this.rotulo,
    this.obrigatorio = false,
    this.dica,
    this.ajuda,
    this.limite,
    this.mostrarContador = true,
    this.linhas = 1,
    this.teclado,
    this.acao = TextInputAction.next,
    this.capitalizacao = TextCapitalization.none,
    this.formatadores = const [],
    this.prefixo,
    this.sufixo,
    this.centralizado = false,
    this.aoEnviar,
  });

  final FormQuadraView view;
  final CampoQuadra campo;
  final String rotulo;
  final bool obrigatorio;
  final String? dica;
  final String? ajuda;
  final int? limite;
  final bool mostrarContador;
  final int linhas;
  final TextInputType? teclado;
  final TextInputAction acao;
  final TextCapitalization capitalizacao;
  final List<TextInputFormatter> formatadores;
  final Widget? prefixo;
  final Widget? sufixo;
  final bool centralizado;
  final ValueChanged<String>? aoEnviar;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final erro = view.erros[campo];
    final limite = this.limite;
    final tamanho = view.campos.texto(campo).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Rotulo(
          texto: rotulo,
          obrigatorio: obrigatorio,
          contador: limite != null && mostrarContador
              ? 'quadras.form.contador'
                  .tr(namedArgs: {'atual': '$tamanho', 'max': '$limite'})
              : null,
        ),
        TextField(
          controller: view.controladores[campo],
          focusNode: view.focos[campo],
          onChanged: (valor) => view.onAlterar(campo, valor),
          onSubmitted: aoEnviar,
          enabled: !view.salvando,
          keyboardType: linhas > 1 ? TextInputType.multiline : teclado,
          textInputAction: acao,
          textCapitalization: capitalizacao,
          textAlign: centralizado ? TextAlign.center : TextAlign.start,
          minLines: linhas,
          maxLines: linhas,
          maxLength: limite,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          inputFormatters: formatadores,
          style: context.textTheme.bodyMedium?.copyWith(color: cs.onSurface),
          decoration: _decoracao(
            context,
            comErro: erro != null,
            dica: dica,
            prefixo: prefixo,
            sufixo: sufixo,
          ),
        ),
        if (erro != null)
          _ErroCampo(erro)
        else if (ajuda != null)
          Padding(
            padding: EdgeInsets.only(top: AppSpacing.xs, left: AppSpacing.xs),
            child: Text(
              ajuda!,
              style: context.textTheme.labelSmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

class _SeletorEsporte extends StatelessWidget {
  const _SeletorEsporte({required this.view});

  final FormQuadraView view;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final erro = view.erros[CampoQuadra.esporte];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Rotulo(texto: 'quadras.form.esporte'.tr(), obrigatorio: true),
        DropdownButtonFormField<TipoEsporte>(
          initialValue: view.campos.esporte,
          focusNode: view.focos[CampoQuadra.esporte],
          onChanged: view.salvando ? null : view.onEsporte,
          isExpanded: true,
          icon: Icon(Icons.expand_more, color: cs.onSurfaceVariant),
          borderRadius: AppBorders.sm,
          dropdownColor: cs.surfaceContainerLowest,
          hint: Text(
            'quadras.form.esporte_dica'.tr(),
            style: context.textTheme.bodyMedium
                ?.copyWith(color: cs.outlineVariant),
          ),
          style: context.textTheme.bodyMedium?.copyWith(color: cs.onSurface),
          decoration: _decoracao(context, comErro: erro != null),
          items: [
            for (final e in TipoEsporte.selecionaveis)
              DropdownMenuItem<TipoEsporte>(
                value: e,
                child: Text(e.rotuloKey.tr()),
              ),
          ],
        ),
        if (erro != null) _ErroCampo(erro),
      ],
    );
  }
}

class _CampoCep extends StatelessWidget {
  const _CampoCep({required this.view});

  final FormQuadraView view;

  static const double _alturaBotao = 48;
  static const double _spinner = 16;

  /// Largura máxima do "Buscar CEP" em relação à linha.
  static const double _fracaoBotao = 0.55;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final erro = view.erros[CampoQuadra.cep];
    final estado = view.estadoCep;
    final buscando = estado is CepBuscando;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Rotulo(texto: 'quadras.form.cep'.tr(), obrigatorio: true),
        LayoutBuilder(
          builder: (context, restricoes) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: view.controladores[CampoQuadra.cep],
                  focusNode: view.focos[CampoQuadra.cep],
                  onChanged: (valor) => view.onAlterar(CampoQuadra.cep, valor),
                  enabled: !view.salvando,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: const [CepInputFormatter()],
                  style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                  decoration: _decoracao(
                    context,
                    comErro: erro != null,
                    dica: 'quadras.form.cep_dica'.tr(),
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              // Largura natural até uma fração da linha; com fonte ampliada o
              // botão encolhe em vez de estourar a linha.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: restricoes.maxWidth * _fracaoBotao,
                  maxHeight: _alturaBotao,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    height: _alturaBotao,
                    child: Semantics(
                      button: true,
                      label: 'quadras.form.cep_buscar_a11y'.tr(),
                      excludeSemantics: true,
                      child: FilledButton.icon(
                        onPressed: view.podeBuscarCep && !view.salvando
                            ? view.onBuscarCep
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: cs.primaryContainer,
                          foregroundColor: cs.onPrimary,
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppBorders.sm,
                          ),
                          textStyle: tt.labelMedium,
                          padding:
                              EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        ),
                        icon: buscando
                            ? SizedBox(
                                width: _spinner,
                                height: _spinner,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: cs.onSurface.withValues(alpha: 0.38),
                                ),
                              )
                            : const Icon(Icons.search, size: 18),
                        label: Text(
                          buscando
                              ? 'quadras.form.cep_buscando'.tr()
                              : 'quadras.form.cep_buscar'.tr(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (erro != null)
          _ErroCampo(erro)
        else
          switch (estado) {
            CepEncontrado(:final fonte) => _FeedbackCep(
                icone: Icons.check_circle_outlined,
                cor: cs.primary,
                texto: fonte == FonteCep.viaCep
                    ? 'quadras.form.cep_via_viacep'.tr()
                    : 'quadras.form.cep_via_brasilapi'.tr(),
                anuncio: 'quadras.form.endereco_preenchido'.tr(),
              ),
            CepIndisponivel(:final mensagem) => _FeedbackCep(
                icone: Icons.warning_amber_outlined,
                cor: context.appColors.warning,
                texto: mensagem,
              ),
            CepOcioso() || CepBuscando() => const SizedBox.shrink(),
          },
      ],
    );
  }
}

class _FeedbackCep extends StatelessWidget {
  const _FeedbackCep({
    required this.icone,
    required this.cor,
    required this.texto,
    this.anuncio,
  });

  final IconData icone;
  final Color cor;
  final String texto;

  /// Texto extra anunciado antes do visível ("Endereço preenchido").
  final String? anuncio;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: AppSpacing.xs),
      child: Semantics(
        liveRegion: true,
        label: anuncio == null ? texto : '${anuncio!}. $texto',
        excludeSemantics: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, size: 16, color: cor),
            SizedBox(width: AppSpacing.s6),
            Expanded(
              child: Text(
                texto,
                style: context.textTheme.labelSmall?.copyWith(color: cor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlocoGeolocalizacao extends StatelessWidget {
  const _BlocoGeolocalizacao({required this.view});

  final FormQuadraView view;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final explicacao = 'quadras.form.geo_explicacao'.tr();
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: AppBorders.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.my_location, size: 16, color: cs.primary),
              SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'quadras.form.geo_titulo'.tr(),
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              if (view.coordenadasAuto)
                Text(
                  'quadras.form.geo_auto'.tr(),
                  style: tt.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _CampoCoordenada(
                  view: view,
                  campo: CampoQuadra.latitude,
                  rotulo: 'quadras.form.latitude'.tr(),
                  explicacao: explicacao,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _CampoCoordenada(
                  view: view,
                  campo: CampoQuadra.longitude,
                  rotulo: 'quadras.form.longitude'.tr(),
                  explicacao: explicacao,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          ExcludeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outlined, size: 14, color: cs.onSurfaceVariant),
                SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    explicacao,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Latitude ou longitude editável (bloco "Geolocalização Precisa").
class _CampoCoordenada extends StatelessWidget {
  const _CampoCoordenada({
    required this.view,
    required this.campo,
    required this.rotulo,
    required this.explicacao,
  });

  final FormQuadraView view;
  final CampoQuadra campo;
  final String rotulo;
  final String explicacao;

  static const int _maxCaracteres = 20;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final erro = view.erros[campo];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            borderRadius: AppBorders.sm,
            border: erro == null ? null : Border.all(color: cs.error),
          ),
          child: Semantics(
            hint: explicacao,
            child: TextField(
              controller: view.controladores[campo],
              focusNode: view.focos[campo],
              onChanged: (valor) => view.onAlterar(campo, valor),
              enabled: !view.salvando,
              keyboardType: const TextInputType.numberWithOptions(
                signed: true,
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
                LengthLimitingTextInputFormatter(_maxCaracteres),
              ],
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                labelText: rotulo,
                labelStyle: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.8)),
                floatingLabelBehavior: FloatingLabelBehavior.always,
                isDense: true,
                filled: false,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
              ),
            ),
          ),
        ),
        if (erro != null) _ErroCampo(erro),
      ],
    );
  }
}

/// "Pré-visualização do Anúncio" 16:9 com o esporte e o nome sobre a imagem.
class _PreVisualizacao extends StatelessWidget {
  const _PreVisualizacao({
    required this.url,
    required this.esporte,
    required this.nome,
  });

  final String url;
  final TipoEsporte? esporte;
  final String nome;

  static const double _icone = 48;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final vazio = ColoredBox(
      color: cs.surfaceContainer,
      child: Center(
        child: Icon(
          esporte?.icone ?? Icons.image_outlined,
          size: _icone,
          color: cs.outline.withValues(alpha: 0.6),
        ),
      ),
    );
    final nomeExibido =
        nome.trim().isEmpty ? 'quadras.form.preview_nome'.tr() : nome.trim();

    return Semantics(
      image: true,
      label: 'quadras.form.preview'.tr(),
      child: ClipRRect(
        borderRadius: AppBorders.md,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (url.isEmpty)
                vazio
              else
                CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (context, u) => vazio,
                  errorWidget: (context, u, e) => vazio,
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      cs.scrim.withValues(alpha: 0.7),
                      cs.scrim.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: AppSpacing.md,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (esporte != null)
                      Text(
                        esporte!.rotuloCurtoKey.tr(),
                        style: tt.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    Text(
                      nomeExibido,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
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

class _BarraAcoes extends StatelessWidget {
  const _BarraAcoes({
    required this.salvando,
    required this.onCancelar,
    required this.onSalvar,
  });

  final bool salvando;
  final VoidCallback onCancelar;
  final VoidCallback onSalvar;

  static const double _altura = 48;
  static const double _spinner = 20;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    const forma = RoundedRectangleBorder(borderRadius: AppBorders.md);
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: AppBorders.md,
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: _altura,
              child: TextButton(
                onPressed: salvando ? null : onCancelar,
                style: TextButton.styleFrom(
                  backgroundColor: cs.surfaceContainer,
                  foregroundColor: cs.secondary,
                  shape: forma,
                  textStyle: tt.labelLarge,
                ),
                child: Text('comum.cancelar'.tr()),
              ),
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: _altura,
              child: FilledButton(
                // Durante o envio, o botão mostra o progresso e não aceita
                // segundo toque.
                onPressed: salvando ? null : onSalvar,
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  shape: forma,
                  textStyle: tt.labelLarge,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (salvando)
                      SizedBox(
                        width: _spinner,
                        height: _spinner,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.onSurface.withValues(alpha: 0.38),
                        ),
                      )
                    else
                      const Icon(Icons.check, size: 20),
                    SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        salvando
                            ? 'quadras.form.salvando'.tr()
                            : 'quadras.form.salvar'.tr(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Falha extends StatelessWidget {
  const _Falha({
    required this.naoEncontrada,
    required this.mensagem,
    required this.onVoltar,
    required this.onTentarNovamente,
  });

  final bool naoEncontrada;
  final String mensagem;
  final VoidCallback onVoltar;
  final VoidCallback onTentarNovamente;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            borderRadius: AppBorders.md,
            boxShadow: AppShadows.subtle,
          ),
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  naoEncontrada
                      ? Icons.search_off_outlined
                      : Icons.cloud_off_outlined,
                  size: 40,
                  color: naoEncontrada ? cs.onSurfaceVariant : cs.error,
                ),
                SizedBox(height: AppSpacing.sm),
                Text(
                  naoEncontrada
                      ? 'quadras.form.nao_encontrada'.tr()
                      : 'quadras.form.erro_carga'.tr(),
                  textAlign: TextAlign.center,
                  style: tt.titleMedium?.copyWith(color: cs.onSurface),
                ),
                if (!naoEncontrada) ...[
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    mensagem,
                    textAlign: TextAlign.center,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
                SizedBox(height: AppSpacing.md),
                if (naoEncontrada)
                  FilledButton.tonalIcon(
                    onPressed: onVoltar,
                    icon: const Icon(Icons.arrow_back),
                    label: Text('comum.voltar'.tr()),
                  )
                else
                  FilledButton.tonalIcon(
                    onPressed: onTentarNovamente,
                    icon: const Icon(Icons.refresh),
                    label: Text('comum.tentar_novamente'.tr()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
