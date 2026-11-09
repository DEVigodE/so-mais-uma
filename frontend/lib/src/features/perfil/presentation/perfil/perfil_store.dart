import 'package:so_mais_uma/src/imports/imports.dart';

import 'contadores_perfil.dart';

/// Política de senha do backend (`Senhas.POLITICA`): 8 a 72 caracteres com
/// ao menos uma letra e um número.
final RegExp politicaSenha = RegExp(r'^(?=.*[A-Za-z])(?=.*\d).{8,72}$');

/// Nome com 2 a 100 caracteres (sem os espaços das pontas).
String? validarNome(String nome) {
  final n = nome.trim().length;
  return (n < 2 || n > 100) ? 'perfil.dados.erro_nome'.tr() : null;
}

/// Telefone vazio ou com 10 ou 11 dígitos (DDD + número).
String? validarTelefone(String digitos) =>
    (digitos.isEmpty || digitos.length == 10 || digitos.length == 11)
        ? null
        : 'perfil.dados.erro_telefone'.tr();

/// Campos com erro editáveis do Perfil.
enum CampoPerfil { nome, telefone, senhaAtual, novaSenha, confirmacao }

/// Eventos de uma leitura do Perfil (snackbar e limpeza de campos).
sealed class EventoPerfil {
  const EventoPerfil();
}

final class DadosSalvos extends EventoPerfil {
  const DadosSalvos();
}

final class SenhaAlterada extends EventoPerfil {
  const SenhaAlterada();
}

final class ErroPerfil extends EventoPerfil {
  const ErroPerfil(this.mensagem);
  final String mensagem;
}

/// Estado e ações do Perfil, variantes CLIENTE e DONO (design D4).
///
/// Mostra na hora o usuário da sessão e o atualiza com `GET /usuarios/me`. Os
/// contadores (D14) vêm de `GET /reservas` e, para o DONO, de
/// `GET /quadras/minhas`. `PUT /usuarios/me` também atualiza a sessão (feito
/// pelo repositório).
class PerfilStore {
  PerfilStore(
    this._usuarios,
    this._reservas,
    this._quadras,
    this._sessao,
    this._relogio,
  );

  final UsuarioRepository _usuarios;
  final ReservaRepository _reservas;
  final QuadraRepository _quadras;
  final SessionStore _sessao;
  final Relogio _relogio;

  final _usuarioAtualizado = signal<AppUser?>(null);
  final _reservasCarregadas = signal<List<Reserva>?>(null);
  final _quadrasCarregadas = signal<List<Quadra>?>(null);
  final _carregandoContadores = signal<bool>(false);
  late final _agora = signal<DateTime>(_relogio.agora());

  final _salvandoDados = signal<bool>(false);
  final _erroNome = signal<String?>(null);
  final _erroTelefone = signal<String?>(null);

  final _senhaExpandida = signal<bool>(false);
  final _salvandoSenha = signal<bool>(false);
  final _erroSenhaAtual = signal<String?>(null);
  final _erroNovaSenha = signal<String?>(null);
  final _erroConfirmacao = signal<String?>(null);

  final _saindo = signal<bool>(false);
  final _evento = signal<EventoPerfil?>(null);
  bool _descartado = false;

  /// Usuário exibido: o devolvido pela API ou, antes dela, o da sessão.
  late final ReadonlySignal<AppUser?> usuario =
      computed(() => _usuarioAtualizado.value ?? _sessao.user.value);

  late final ReadonlySignal<PerfilUsuario> perfil =
      computed(() => usuario.value?.perfil ?? PerfilUsuario.cliente);

  /// Contadores calculados (D14); só os que têm dado.
  late final ReadonlySignal<List<ContadorPerfil>> contadores = computed(
    () => calcularContadoresPerfil(
      perfil: perfil.value,
      agora: _agora.value,
      reservas: _reservasCarregadas.value,
      quadras: _quadrasCarregadas.value,
    ),
  );

  ReadonlySignal<bool> get carregandoContadores => _carregandoContadores;
  ReadonlySignal<bool> get salvandoDados => _salvandoDados;
  ReadonlySignal<String?> get erroNome => _erroNome;
  ReadonlySignal<String?> get erroTelefone => _erroTelefone;
  ReadonlySignal<bool> get senhaExpandida => _senhaExpandida;
  ReadonlySignal<bool> get salvandoSenha => _salvandoSenha;
  ReadonlySignal<String?> get erroSenhaAtual => _erroSenhaAtual;
  ReadonlySignal<String?> get erroNovaSenha => _erroNovaSenha;
  ReadonlySignal<String?> get erroConfirmacao => _erroConfirmacao;
  ReadonlySignal<bool> get saindo => _saindo;

  /// Evento de uma leitura: o contêiner trata e chama [consumirEvento].
  ReadonlySignal<EventoPerfil?> get evento => _evento;

  // ── Carga ─────────────────────────────────────────────────────────────────

  /// `GET /usuarios/me` e as fontes dos contadores, em paralelo.
  Future<void> carregar() async {
    final dono = perfil.value == PerfilUsuario.dono;
    _carregandoContadores.value = true;
    await Future.wait([
      _carregarUsuario(),
      _carregarReservas(),
      if (dono) _carregarQuadras(),
    ]);
    if (_descartado) return;
    _carregandoContadores.value = false;
  }

  Future<void> _carregarUsuario() async {
    final r = await _usuarios.obter();
    if (_descartado) return;
    // Falha mantém os dados da sessão (o Perfil continua utilizável).
    r.fold((_) {}, (u) => _usuarioAtualizado.value = u);
  }

  Future<void> _carregarReservas() async {
    final r = await _reservas.listar();
    if (_descartado) return;
    r.fold((_) {}, (lista) {
      batch(() {
        _agora.value = _relogio.agora();
        _reservasCarregadas.value = lista;
      });
    });
  }

  Future<void> _carregarQuadras() async {
    final r = await _quadras.minhas();
    if (_descartado) return;
    r.fold((_) {}, (lista) => _quadrasCarregadas.value = lista);
  }

  // ── Dados pessoais ────────────────────────────────────────────────────────

  /// Valida e envia `PUT /usuarios/me` com `{nome, telefone}` (telefone só com
  /// dígitos; vazio vira `null`).
  Future<void> salvarDados({
    required String nome,
    required String telefone,
  }) async {
    if (_salvandoDados.value) return;
    final nomeLimpo = nome.trim();
    final digitos = Formatadores.digitos(telefone);
    final erroNome = validarNome(nomeLimpo);
    final erroTelefone = validarTelefone(digitos);
    batch(() {
      _erroNome.value = erroNome;
      _erroTelefone.value = erroTelefone;
    });
    if (erroNome != null || erroTelefone != null) return;

    _salvandoDados.value = true;
    final r = await _usuarios.atualizar(
      nome: nomeLimpo,
      telefone: digitos.isEmpty ? null : digitos,
    );
    if (_descartado) return;
    batch(() {
      _salvandoDados.value = false;
      r.fold(_tratarFalhaDados, (u) {
        _usuarioAtualizado.value = u;
        _evento.value = const DadosSalvos();
      });
    });
  }

  void _tratarFalhaDados(Failure falha) {
    if (falha is ApiFailure && _ehValidacao(falha)) {
      final nome = falha.campos['nome'];
      final telefone = falha.campos['telefone'];
      if (nome != null || telefone != null) {
        _erroNome.value = nome;
        _erroTelefone.value = telefone;
        return;
      }
    }
    _evento.value = ErroPerfil(falha.message);
  }

  // ── Senha ─────────────────────────────────────────────────────────────────

  void alternarSenha() => _senhaExpandida.value = !_senhaExpandida.value;

  /// Troca de senha: `PUT /usuarios/me` com o nome e o telefone já salvos,
  /// mais `senhaAtual` e `novaSenha`.
  Future<void> alterarSenha({
    required String senhaAtual,
    required String novaSenha,
    required String confirmacao,
  }) async {
    if (_salvandoSenha.value) return;
    final erroAtual =
        senhaAtual.isEmpty ? 'perfil.senha.erro_atual_obrigatoria'.tr() : null;
    final erroNova = politicaSenha.hasMatch(novaSenha)
        ? null
        : 'perfil.senha.erro_politica'.tr();
    final erroConfirmacao =
        confirmacao == novaSenha ? null : 'perfil.senha.erro_confirmacao'.tr();
    batch(() {
      _erroSenhaAtual.value = erroAtual;
      _erroNovaSenha.value = erroNova;
      _erroConfirmacao.value = erroConfirmacao;
    });
    if (erroAtual != null || erroNova != null || erroConfirmacao != null) {
      return;
    }

    final atual = usuario.value;
    if (atual == null) return;
    _salvandoSenha.value = true;
    final r = await _usuarios.atualizar(
      nome: atual.name ?? '',
      telefone: atual.telefone,
      senhaAtual: senhaAtual,
      novaSenha: novaSenha,
    );
    if (_descartado) return;
    batch(() {
      _salvandoSenha.value = false;
      r.fold(_tratarFalhaSenha, (u) {
        _usuarioAtualizado.value = u;
        _evento.value = const SenhaAlterada();
      });
    });
  }

  void _tratarFalhaSenha(Failure falha) {
    if (falha is ApiFailure) {
      if ((falha.subcodigo ?? falha.codigo) == 'SENHA_ATUAL_INCORRETA') {
        _erroSenhaAtual.value = 'perfil.senha.atual_incorreta'.tr();
        return;
      }
      if (_ehValidacao(falha)) {
        final atual = falha.campos['senhaAtual'];
        final nova = falha.campos['novaSenha'];
        if (atual != null || nova != null) {
          _erroSenhaAtual.value = atual;
          _erroNovaSenha.value = nova;
          return;
        }
      }
    }
    _evento.value = ErroPerfil(falha.message);
  }

  // ── Outros ────────────────────────────────────────────────────────────────

  /// Limpa o erro de um campo assim que ele é editado.
  void limparErro(CampoPerfil campo) {
    final alvo = switch (campo) {
      CampoPerfil.nome => _erroNome,
      CampoPerfil.telefone => _erroTelefone,
      CampoPerfil.senhaAtual => _erroSenhaAtual,
      CampoPerfil.novaSenha => _erroNovaSenha,
      CampoPerfil.confirmacao => _erroConfirmacao,
    };
    if (alvo.value != null) alvo.value = null;
  }

  /// Encerra a sessão (funciona sem rede); o redirect leva ao Login.
  Future<void> sair() async {
    if (_saindo.value) return;
    _saindo.value = true;
    await _sessao.logout();
    if (_descartado) return;
    _saindo.value = false;
  }

  void consumirEvento() => _evento.value = null;

  static bool _ehValidacao(ApiFailure f) =>
      f.codigo == 'VALIDACAO' || f.status == 400;

  void dispose() {
    _descartado = true;
    contadores.dispose();
    perfil.dispose();
    usuario.dispose();
    _usuarioAtualizado.dispose();
    _reservasCarregadas.dispose();
    _quadrasCarregadas.dispose();
    _carregandoContadores.dispose();
    _agora.dispose();
    _salvandoDados.dispose();
    _erroNome.dispose();
    _erroTelefone.dispose();
    _senhaExpandida.dispose();
    _salvandoSenha.dispose();
    _erroSenhaAtual.dispose();
    _erroNovaSenha.dispose();
    _erroConfirmacao.dispose();
    _saindo.dispose();
    _evento.dispose();
  }
}
