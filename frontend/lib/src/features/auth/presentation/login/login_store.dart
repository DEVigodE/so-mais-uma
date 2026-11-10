import 'dart:async';

import 'package:so_mais_uma/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:so_mais_uma/src/imports/imports.dart';

/// Resultado de uma tentativa de login, consumido pelo contêiner.
sealed class ResultadoLogin {
  const ResultadoLogin();
}

/// Sessão gravada; o contêiner navega para a home do perfil.
final class LoginConcluido extends ResultadoLogin {
  const LoginConcluido();
}

/// 401 `CREDENCIAL_INVALIDA`: o contêiner limpa o campo senha.
final class LoginCredencialInvalida extends ResultadoLogin {
  const LoginCredencialInvalida();
}

/// Qualquer outra falha (mensagem já em [LoginStore.erro]).
final class LoginFalhou extends ResultadoLogin {
  const LoginFalhou();
}

/// Estado e ações do Login (spec `sessao-e-navegacao`, "Login por e-mail e senha").
class LoginStore {
  LoginStore({required AuthRepository repository}) : _repository = repository;

  final AuthRepository _repository;

  /// Tempo do botão desabilitado depois do 429 `LOGIN_BLOQUEADO`.
  static const Duration bloqueio = Duration(seconds: 30);

  static final RegExp _formatoEmail = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  final _email = signal('');
  final _enviando = signal(false);
  final _bloqueado = signal(false);
  final _erro = signal<String?>(null);
  late final Computed<bool> _emailValido =
      computed(() => validarEmail(_email.value) == null);

  Timer? _timerBloqueio;
  var _descartado = false;

  /// E-mail com formato válido (dica "Formato válido" e marca de confirmação).
  ReadonlySignal<bool> get emailValido => _emailValido;

  /// Requisição em andamento: botão com progresso e campos desabilitados.
  ReadonlySignal<bool> get enviando => _enviando;

  /// Botão desabilitado por 30 s depois do 429.
  ReadonlySignal<bool> get bloqueado => _bloqueado;

  /// Mensagem exibida abaixo do botão Entrar.
  ReadonlySignal<String?> get erro => _erro;

  void atualizarEmail(String valor) => _email.value = valor.trim();

  /// `null` quando válido; senão, a chave de tradução do erro.
  static String? validarEmail(String? valor) {
    final v = (valor ?? '').trim();
    if (v.isEmpty) return 'login.email_obrigatorio';
    if (!_formatoEmail.hasMatch(v)) return 'login.email_invalido';
    return null;
  }

  /// `null` quando válida; a composição da senha não é validada no Login.
  static String? validarSenha(String? valor) =>
      (valor ?? '').isEmpty ? 'login.senha_obrigatoria' : null;

  Future<ResultadoLogin?> entrar({
    required String email,
    required String senha,
  }) async {
    if (_enviando.value || _bloqueado.value) return null;
    batch(() {
      _enviando.value = true;
      _erro.value = null;
    });

    final resultado =
        await _repository.login(email: email.trim(), password: senha);
    if (_descartado) return null;

    return resultado.fold(
      (failure) {
        _enviando.value = false;
        return _tratarFalha(failure);
      },
      (_) {
        _enviando.value = false;
        return const LoginConcluido();
      },
    );
  }

  ResultadoLogin _tratarFalha(Failure failure) {
    switch (failure) {
      case NetworkFailure():
        _erro.value = 'login.sem_conexao'.tr();
        return const LoginFalhou();
      case ApiFailure(codigo: 'CREDENCIAL_INVALIDA'):
        _erro.value = 'login.credencial_invalida'.tr();
        return const LoginCredencialInvalida();
      case ApiFailure(codigo: 'LOGIN_BLOQUEADO'):
        _erro.value = 'login.bloqueado'.tr();
        _bloquear();
        return const LoginFalhou();
      default:
        _erro.value = failure.message;
        return const LoginFalhou();
    }
  }

  void _bloquear() {
    _bloqueado.value = true;
    _timerBloqueio?.cancel();
    _timerBloqueio = Timer(bloqueio, () {
      if (!_descartado) _bloqueado.value = false;
    });
  }

  void dispose() {
    _descartado = true;
    _timerBloqueio?.cancel();
    _emailValido.dispose();
    _email.dispose();
    _enviando.dispose();
    _bloqueado.dispose();
    _erro.dispose();
  }
}
