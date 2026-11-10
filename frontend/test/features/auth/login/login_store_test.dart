import 'dart:async';

// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:so_mais_uma/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:so_mais_uma/src/features/auth/presentation/login/login_store.dart';
import 'package:so_mais_uma/src/shared/domain/entities/app_user.dart';
import 'package:so_mais_uma/src/utils/failure.dart';
import 'package:so_mais_uma/src/utils/typedefs.dart';

class _AuthFalso implements AuthRepository {
  Either<Failure, AppUser> resposta =
      right(const AppUser(id: '1', email: 'cliente@demo.com'));
  Completer<void>? segurar;
  var chamadas = 0;

  @override
  FutureEither<AppUser> login({
    required String email,
    required String password,
  }) async {
    chamadas++;
    if (segurar != null) await segurar!.future;
    return resposta;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _AuthFalso auth;
  late LoginStore store;

  setUp(() {
    auth = _AuthFalso();
    store = LoginStore(repository: auth);
  });

  tearDown(() => store.dispose());

  group('validação local', () {
    test('e-mail precisa de @ e domínio', () {
      expect(LoginStore.validarEmail(''), 'login.email_obrigatorio');
      expect(LoginStore.validarEmail('cliente'), 'login.email_invalido');
      expect(LoginStore.validarEmail('cliente@demo'), 'login.email_invalido');
      expect(LoginStore.validarEmail('cliente@demo.com'), isNull);
    });

    test('senha só não pode ser vazia', () {
      expect(LoginStore.validarSenha(''), 'login.senha_obrigatoria');
      expect(LoginStore.validarSenha('a'), isNull);
    });

    test('emailValido acompanha o texto digitado', () {
      store.atualizarEmail('cliente@');
      expect(store.emailValido.value, isFalse);
      store.atualizarEmail(' cliente@demo.com ');
      expect(store.emailValido.value, isTrue);
    });
  });

  test('sucesso devolve LoginConcluido sem erro', () async {
    final r = await store.entrar(email: 'cliente@demo.com', senha: 'Senha123');
    expect(r, isA<LoginConcluido>());
    expect(store.erro.value, isNull);
    expect(store.enviando.value, isFalse);
  });

  test('401 CREDENCIAL_INVALIDA pede para limpar a senha', () async {
    auth.resposta = left(
      const ApiFailure(status: 401, codigo: 'CREDENCIAL_INVALIDA'),
    );
    final r = await store.entrar(email: 'cliente@demo.com', senha: 'errada');
    expect(r, isA<LoginCredencialInvalida>());
    expect(store.erro.value, 'login.credencial_invalida');
  });

  test('429 LOGIN_BLOQUEADO desabilita o botão por 30 s', () {
    fakeAsync((async) {
      auth.resposta = left(
        const ApiFailure(status: 429, codigo: 'LOGIN_BLOQUEADO'),
      );
      store.entrar(email: 'cliente@demo.com', senha: 'Senha123');
      async.flushMicrotasks();
      expect(store.erro.value, 'login.bloqueado');
      expect(store.bloqueado.value, isTrue);

      async.elapse(const Duration(seconds: 29));
      expect(store.bloqueado.value, isTrue);
      async.elapse(const Duration(seconds: 1));
      expect(store.bloqueado.value, isFalse);
    });
  });

  test('bloqueado não envia de novo', () {
    fakeAsync((async) {
      auth.resposta = left(
        const ApiFailure(status: 429, codigo: 'LOGIN_BLOQUEADO'),
      );
      store.entrar(email: 'cliente@demo.com', senha: 'Senha123');
      async.flushMicrotasks();
      store.entrar(email: 'cliente@demo.com', senha: 'Senha123');
      async.flushMicrotasks();
      expect(auth.chamadas, 1);
    });
  });

  test('sem rede mostra a mensagem de conexão', () async {
    auth.resposta = left(const NetworkFailure('offline'));
    final r = await store.entrar(email: 'cliente@demo.com', senha: 'Senha123');
    expect(r, isA<LoginFalhou>());
    expect(store.erro.value, 'login.sem_conexao');
  });

  test('não envia duas vezes enquanto a primeira está em andamento', () async {
    auth.segurar = Completer<void>();
    final primeira = store.entrar(email: 'cliente@demo.com', senha: 'Senha123');
    expect(store.enviando.value, isTrue);
    final segunda =
        await store.entrar(email: 'cliente@demo.com', senha: 'Senha123');
    expect(segunda, isNull);
    auth.segurar!.complete();
    expect(await primeira, isA<LoginConcluido>());
    expect(auth.chamadas, 1);
  });
}
