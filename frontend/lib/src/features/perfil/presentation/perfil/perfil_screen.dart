import 'dart:async';

import 'package:so_mais_uma/src/imports/imports.dart';

import 'perfil_store.dart';
import 'perfil_view.dart';
import 'telefone_input_formatter.dart';

/// Perfil: aba 2 dos shells CLIENTE (`/perfil`) e DONO (`/dono/perfil`).
class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  late final PerfilStore _store;
  final _nome = TextEditingController();
  final _telefone = TextEditingController();
  final _senhaAtual = TextEditingController();
  final _novaSenha = TextEditingController();
  final _confirmacao = TextEditingController();

  /// Depois que o usuário edita, a resposta do `GET /usuarios/me` não
  /// sobrescreve os campos.
  bool _dadosEditados = false;
  EffectCleanup? _efeitoUsuario;
  EffectCleanup? _efeitoEvento;

  @override
  void initState() {
    super.initState();
    _store = injector.get<PerfilStore>();
    _efeitoUsuario = effect(() {
      final usuario = _store.usuario.value;
      if (usuario == null || _dadosEditados) return;
      _nome.text = usuario.name ?? '';
      _telefone.text = TelefoneInputFormatter.formatar(usuario.telefone ?? '');
    });
    _efeitoEvento = effect(() {
      final evento = _store.evento.value;
      if (evento == null) return;
      Future.microtask(() {
        if (!mounted) return;
        _store.consumirEvento();
        _tratarEvento(evento);
      });
    });
    unawaited(_store.carregar());
  }

  @override
  void dispose() {
    _efeitoUsuario?.call();
    _efeitoEvento?.call();
    _nome.dispose();
    _telefone.dispose();
    _senhaAtual.dispose();
    _novaSenha.dispose();
    _confirmacao.dispose();
    _store.dispose();
    super.dispose();
  }

  void _tratarEvento(EventoPerfil evento) {
    switch (evento) {
      case DadosSalvos():
        _dadosEditados = false;
        showAppSnack(
          context,
          'perfil.dados.sucesso'.tr(),
          type: SnackBarType.success,
        );
      case SenhaAlterada():
        _senhaAtual.clear();
        _novaSenha.clear();
        _confirmacao.clear();
        showAppSnack(
          context,
          'perfil.senha.sucesso'.tr(),
          type: SnackBarType.success,
        );
      case ErroPerfil(:final mensagem):
        showAppSnack(context, mensagem, type: SnackBarType.error);
    }
  }

  void _editarCampo(CampoPerfil campo) {
    if (campo == CampoPerfil.nome || campo == CampoPerfil.telefone) {
      _dadosEditados = true;
    }
    _store.limparErro(campo);
  }

  void _salvarDados() {
    FocusScope.of(context).unfocus();
    unawaited(
      _store.salvarDados(nome: _nome.text, telefone: _telefone.text),
    );
  }

  void _atualizarSenha() {
    FocusScope.of(context).unfocus();
    unawaited(
      _store.alterarSenha(
        senhaAtual: _senhaAtual.text,
        novaSenha: _novaSenha.text,
        confirmacao: _confirmacao.text,
      ),
    );
  }

  Future<void> _sair() async {
    final confirmou = await showAppAlertDialog(
      context,
      title: 'perfil.sair.titulo'.tr(),
      message: 'perfil.sair.mensagem'.tr(),
      confirmLabel: 'perfil.sair.confirmar'.tr(),
      cancelLabel: 'comum.cancelar'.tr(),
      isDestructive: true,
    );
    if (confirmou != true || !mounted) return;
    await _store.sair();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Scaffold(
      appBar: BarraSuperior(
        titulo: 'perfil.titulo'.tr(),
        tituloStyle: context.textTheme.titleLarge?.copyWith(
          color: cs.onSurface,
        ),
      ),
      body: SignalBuilder(
        builder: (context) => PerfilView(
          usuario: _store.usuario.value,
          contadores: _store.contadores.value,
          carregandoContadores: _store.carregandoContadores.value,
          nomeController: _nome,
          telefoneController: _telefone,
          senhaAtualController: _senhaAtual,
          novaSenhaController: _novaSenha,
          confirmacaoController: _confirmacao,
          salvandoDados: _store.salvandoDados.value,
          senhaExpandida: _store.senhaExpandida.value,
          salvandoSenha: _store.salvandoSenha.value,
          saindo: _store.saindo.value,
          erroNome: _store.erroNome.value,
          erroTelefone: _store.erroTelefone.value,
          erroSenhaAtual: _store.erroSenhaAtual.value,
          erroNovaSenha: _store.erroNovaSenha.value,
          erroConfirmacao: _store.erroConfirmacao.value,
          onEditarCampo: _editarCampo,
          onSalvarDados: _salvarDados,
          onAlternarSenha: _store.alternarSenha,
          onAtualizarSenha: _atualizarSenha,
          onSair: _sair,
        ),
      ),
    );
  }
}
