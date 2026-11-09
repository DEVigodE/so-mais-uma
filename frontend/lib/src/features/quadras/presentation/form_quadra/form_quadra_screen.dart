import 'package:so_mais_uma/src/imports/imports.dart';

import 'form_quadra_campos.dart';
import 'form_quadra_store.dart';
import 'form_quadra_view.dart';

/// FormQuadra: nova (`/dono/quadras/nova`) ou edição
/// (`/dono/quadras/:id/editar`). Devolve `true` no `pop` depois de salvar.
class FormQuadraScreen extends StatefulWidget {
  const FormQuadraScreen({
    super.key,
    this.quadraId,
  });

  /// `null` para nova quadra; id para edição.
  final int? quadraId;

  @override
  State<FormQuadraScreen> createState() => _FormQuadraScreenState();
}

class _FormQuadraScreenState extends State<FormQuadraScreen> {
  late final FormQuadraStore _store;
  late final List<void Function()> _efeitos;

  /// Campos de texto (o esporte é um seletor e só tem foco).
  static final _camposTexto =
      CampoQuadra.values.where((c) => c != CampoQuadra.esporte);

  final _controladores = <CampoQuadra, TextEditingController>{
    for (final c in _camposTexto) c: TextEditingController(),
  };
  final _focos = <CampoQuadra, FocusNode>{
    for (final c in CampoQuadra.values) c: FocusNode(),
  };

  @override
  void initState() {
    super.initState();
    _store = injector.get<FormQuadraStore>();
    _efeitos = [
      effect(() {
        _store.versaoExterna.value;
        untracked(_copiarParaControladores);
      }),
      effect(() {
        final evento = _store.evento.value;
        if (evento == null) return;
        Future.microtask(() {
          if (!mounted) return;
          _store.consumirEvento();
          _tratarEvento(evento);
        });
      }),
    ];
    _store.carregar(widget.quadraId);
  }

  @override
  void dispose() {
    for (final limpar in _efeitos) {
      limpar();
    }
    for (final c in _controladores.values) {
      c.dispose();
    }
    for (final f in _focos.values) {
      f.dispose();
    }
    _store.dispose();
    super.dispose();
  }

  /// Leva para os controladores o que o store preencheu (edição, CEP).
  void _copiarParaControladores() {
    final campos = _store.campos.value;
    for (final MapEntry(key: campo, value: controlador)
        in _controladores.entries) {
      final texto = campos.texto(campo);
      if (controlador.text != texto) controlador.text = texto;
    }
  }

  void _tratarEvento(EventoFormQuadra evento) {
    switch (evento) {
      case QuadraSalva(:final nome):
        showAppSnack(
          context,
          'quadras.form.salva'.tr(namedArgs: {'nome': nome}),
          type: SnackBarType.success,
        );
        context.pop(true);
      case FocarCampo(:final campo):
        _focar(campo);
      case SemPermissaoFormQuadra():
        showAppSnack(
          context,
          'quadras.form.sem_permissao'.tr(),
          type: SnackBarType.error,
        );
        context.pop();
      case FalhaFormQuadra(:final mensagem):
        showAppSnack(context, mensagem, type: SnackBarType.error);
    }
  }

  void _focar(CampoQuadra campo) {
    final foco = _focos[campo];
    if (foco == null) return;
    foco.requestFocus();
    final contexto = foco.context;
    if (contexto != null) {
      Scrollable.ensureVisible(
        contexto,
        alignment: 0.3,
        duration: AppDurations.normal,
      );
    }
  }

  /// Volta pelo `maybePop` para o `PopScope` interceptar alterações pendentes.
  void _voltar() => Navigator.of(context).maybePop();

  Future<void> _confirmarDescarte() async {
    final descartar = await showAppAlertDialog(
      context,
      title: 'comum.descartar_alteracoes_titulo'.tr(),
      message: 'quadras.form.descartar_mensagem'.tr(),
      confirmLabel: 'comum.descartar'.tr(),
      cancelLabel: 'quadras.form.continuar_editando'.tr(),
      isDestructive: true,
    );
    if ((descartar ?? false) && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final salvando = _store.salvando.value;
        return PopScope<Object?>(
          canPop: _store.podeSair.value && !salvando,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop || _store.salvando.value) return;
            _confirmarDescarte();
          },
          child: FormQuadraView(
            edicao: widget.quadraId != null,
            carga: _store.carga.value,
            campos: _store.campos.value,
            erros: _store.erros.value,
            estadoCep: _store.estadoCep.value,
            coordenadasAuto: _store.coordenadasAuto.value,
            urlPreview: _store.urlPreview.value,
            salvando: salvando,
            podeBuscarCep: _store.podeBuscarCep.value,
            controladores: _controladores,
            focos: _focos,
            onAlterar: _store.alterar,
            onEsporte: _store.selecionarEsporte,
            onBuscarCep: _store.buscarCep,
            onAtualizarPreview: _store.atualizarPreview,
            onVoltar: _voltar,
            onSalvar: _store.salvar,
            onTentarNovamente: () => _store.carregar(widget.quadraId),
          ),
        );
      },
    );
  }
}
