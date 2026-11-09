import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:so_mais_uma/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:so_mais_uma/src/features/perfil/presentation/perfil/contadores_perfil.dart';
import 'package:so_mais_uma/src/features/perfil/presentation/perfil/perfil_store.dart';
import 'package:so_mais_uma/src/shared/domain/brasilia.dart';
import 'package:so_mais_uma/src/shared/domain/entities/app_user.dart';
import 'package:so_mais_uma/src/shared/domain/entities/quadra.dart';
import 'package:so_mais_uma/src/shared/domain/entities/reserva.dart';
import 'package:so_mais_uma/src/shared/domain/enums.dart';
import 'package:so_mais_uma/src/shared/domain/repositories/repositorios.dart';
import 'package:so_mais_uma/src/shared/session/session_store.dart';
import 'package:so_mais_uma/src/utils/failure.dart';
import 'package:so_mais_uma/src/utils/typedefs.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────

class RelogioFixo extends Relogio {
  const RelogioFixo(this.instante);
  final DateTime instante;
  @override
  DateTime agora() => instante;
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository(this.usuario);

  final AppUser usuario;
  final _eventos = StreamController<AppUser?>.broadcast();
  int logouts = 0;

  @override
  Stream<AppUser?> get onAuthStateChanged => _eventos.stream;

  @override
  FutureEither<AppUser?> checkAuthState() async => right(usuario);

  @override
  FutureEither<void> logout() async {
    logouts++;
    return right(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ChamadaAtualizar {
  ChamadaAtualizar(this.nome, this.telefone, this.senhaAtual, this.novaSenha);
  final String nome;
  final String? telefone;
  final String? senhaAtual;
  final String? novaSenha;
}

class FakeUsuarioRepository implements UsuarioRepository {
  FakeUsuarioRepository(this.remoto);

  AppUser remoto;
  Either<Failure, AppUser>? respostaObter;
  Either<Failure, AppUser>? respostaAtualizar;
  final List<ChamadaAtualizar> chamadas = [];

  @override
  FutureEither<AppUser> obter() async => respostaObter ?? right(remoto);

  @override
  FutureEither<AppUser> atualizar({
    required String nome,
    String? telefone,
    String? senhaAtual,
    String? novaSenha,
  }) async {
    chamadas.add(ChamadaAtualizar(nome, telefone, senhaAtual, novaSenha));
    final r = respostaAtualizar;
    if (r != null) return r;
    remoto = remoto.copyWith(name: nome, telefone: telefone);
    return right(remoto);
  }
}

class FakeReservaRepository implements ReservaRepository {
  Either<Failure, List<Reserva>> resposta = right(const []);

  @override
  FutureEither<List<Reserva>> listar({String? situacao}) async => resposta;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeQuadraRepository implements QuadraRepository {
  int chamadas = 0;
  List<Quadra> lista = const [];

  @override
  FutureEither<List<Quadra>> minhas() async {
    chamadas++;
    return right(lista);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final agora = Brasilia.instante(DateTime.utc(2026, 11, 9, 15));

Reserva reserva(int id, int quadraId, Duration desdeAgora) => Reserva(
      id: id,
      quadraId: quadraId,
      quadraNome: 'Quadra $quadraId',
      inicio: agora.add(desdeAgora),
      fim: agora.add(desdeAgora).add(const Duration(hours: 1)),
      status: StatusReserva.confirmada,
      valor: 90,
    );

Quadra quadra(int id) => Quadra(
      id: id,
      nome: 'Quadra $id',
      tipoEsporte: TipoEsporte.volei,
      precoHora: 70,
      cep: '01310100',
      logradouro: 'Rua B',
      numero: '2',
      cidade: 'Campinas',
      uf: 'SP',
    );

const cliente = AppUser(
  id: '7',
  email: 'lucas.silva@demo.com',
  name: 'Lucas Silva',
  telefone: '11987654321',
);

const dono = AppUser(
  id: '8',
  email: 'dono@demo.com',
  name: 'Dona Arena',
  perfil: PerfilUsuario.dono,
);

Future<void> esvaziarFila() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeAuthRepository auth;
  late SessionStore sessao;
  late FakeUsuarioRepository usuarios;
  late FakeReservaRepository reservas;
  late FakeQuadraRepository quadras;
  late PerfilStore store;

  Future<void> montar(AppUser usuario) async {
    auth = FakeAuthRepository(usuario);
    sessao = SessionStore(repository: auth);
    await esvaziarFila(); // checkAuthState
    usuarios = FakeUsuarioRepository(usuario);
    reservas = FakeReservaRepository()
      ..resposta = right([
        reserva(1, 1, const Duration(days: -7)),
        reserva(2, 2, const Duration(days: -2)),
        reserva(3, 2, const Duration(days: -1)),
        reserva(4, 3, const Duration(days: 1)),
      ]);
    quadras = FakeQuadraRepository()..lista = [quadra(1), quadra(2)];
    store = PerfilStore(
      usuarios,
      reservas,
      quadras,
      sessao,
      RelogioFixo(agora),
    );
  }

  tearDown(() {
    store.dispose();
    sessao.dispose();
  });

  group('carga', () {
    test('mostra a sessão na hora e atualiza com GET /usuarios/me', () async {
      await montar(cliente);
      expect(store.usuario.value?.name, 'Lucas Silva');

      usuarios.remoto = cliente.copyWith(name: 'Lucas S. Silva');
      await store.carregar();
      expect(store.usuario.value?.name, 'Lucas S. Silva');
    });

    test('falha do GET mantém os dados da sessão', () async {
      await montar(cliente);
      usuarios.respostaObter = left(const NetworkFailure('sem conexão'));
      await store.carregar();
      expect(store.usuario.value, cliente);
    });

    test('contadores do CLIENTE: Jogos e Arenas', () async {
      await montar(cliente);
      expect(store.contadores.value, isEmpty);
      final carga = store.carregar();
      expect(store.carregandoContadores.value, isTrue);
      await carga;

      expect(store.carregandoContadores.value, isFalse);
      expect(store.contadores.value, const [
        ContadorPerfil('perfil.contadores.jogos', 3),
        ContadorPerfil('perfil.contadores.arenas', 2),
      ]);
      expect(quadras.chamadas, 0, reason: 'o cliente não usa /quadras/minhas');
    });

    test('contadores do DONO: Quadras e Reservas', () async {
      await montar(dono);
      await store.carregar();
      expect(store.perfil.value, PerfilUsuario.dono);
      expect(quadras.chamadas, 1);
      expect(store.contadores.value, const [
        ContadorPerfil('perfil.contadores.quadras', 2),
        ContadorPerfil('perfil.contadores.reservas', 4),
      ]);
    });

    test('falha nas reservas omite os números que dependem delas', () async {
      await montar(dono);
      reservas.resposta = left(const NetworkFailure('sem conexão'));
      await store.carregar();
      expect(store.contadores.value, const [
        ContadorPerfil('perfil.contadores.quadras', 2),
      ]);
    });
  });

  group('dados pessoais', () {
    test('nome curto demais marca o campo e nada é enviado', () async {
      await montar(cliente);
      await store.salvarDados(nome: ' L ', telefone: '(11) 98765-4321');
      expect(store.erroNome.value, 'perfil.dados.erro_nome');
      expect(usuarios.chamadas, isEmpty);

      store.limparErro(CampoPerfil.nome);
      expect(store.erroNome.value, isNull);
    });

    test('telefone incompleto marca o campo', () async {
      await montar(cliente);
      await store.salvarDados(nome: 'Lucas Silva', telefone: '(11) 9123');
      expect(store.erroTelefone.value, 'perfil.dados.erro_telefone');
      expect(usuarios.chamadas, isEmpty);
    });

    test('envia o telefone só com dígitos e avisa o sucesso', () async {
      await montar(cliente);
      await store.salvarDados(
        nome: '  Lucas Silva ',
        telefone: '(11) 91234-5678',
      );

      final c = usuarios.chamadas.single;
      expect(c.nome, 'Lucas Silva');
      expect(c.telefone, '11912345678');
      expect(c.senhaAtual, isNull);
      expect(c.novaSenha, isNull);
      expect(store.evento.value, isA<DadosSalvos>());
      expect(store.usuario.value?.telefone, '11912345678');
      expect(store.salvandoDados.value, isFalse);

      store.consumirEvento();
      expect(store.evento.value, isNull);
    });

    test('telefone vazio é enviado como nulo', () async {
      await montar(cliente);
      await store.salvarDados(nome: 'Lucas Silva', telefone: '');
      expect(usuarios.chamadas.single.telefone, isNull);
    });

    test('telefone fixo de 10 dígitos é aceito', () async {
      await montar(cliente);
      await store.salvarDados(nome: 'Lucas Silva', telefone: '(11) 3456-7890');
      expect(usuarios.chamadas.single.telefone, '1134567890');
    });

    test('400 VALIDACAO marca os campos de campos[]', () async {
      await montar(cliente);
      usuarios.respostaAtualizar = left(
        const ApiFailure(
          status: 400,
          codigo: 'VALIDACAO',
          campos: {'nome': 'tamanho deve ser entre 0 e 100'},
          message: 'Confira os dados informados.',
        ),
      );
      await store.salvarDados(nome: 'Lucas Silva', telefone: '');
      expect(store.erroNome.value, 'tamanho deve ser entre 0 e 100');
      expect(store.evento.value, isNull);
    });

    test('outro erro vai para o snackbar e mantém os dados', () async {
      await montar(cliente);
      usuarios.respostaAtualizar = left(const NetworkFailure('sem conexão'));
      await store.salvarDados(nome: 'Lucas Novo', telefone: '');
      expect(store.evento.value, isA<ErroPerfil>());
      expect((store.evento.value! as ErroPerfil).mensagem, 'sem conexão');
      expect(store.usuario.value?.name, 'Lucas Silva');
    });
  });

  group('troca de senha', () {
    test('valida senha atual, política e confirmação antes de enviar',
        () async {
      await montar(cliente);
      await store.alterarSenha(
        senhaAtual: '',
        novaSenha: 'abcdefgh',
        confirmacao: 'abcdefgx',
      );
      expect(store.erroSenhaAtual.value, 'perfil.senha.erro_atual_obrigatoria');
      expect(store.erroNovaSenha.value, 'perfil.senha.erro_politica');
      expect(store.erroConfirmacao.value, 'perfil.senha.erro_confirmacao');
      expect(usuarios.chamadas, isEmpty);
    });

    test('política igual à do backend', () {
      expect(politicaSenha.hasMatch('NovaSenha9'), isTrue);
      expect(politicaSenha.hasMatch('12345678'), isFalse);
      expect(politicaSenha.hasMatch('abcdefgh'), isFalse);
      expect(politicaSenha.hasMatch('abc1234'), isFalse);
      expect(politicaSenha.hasMatch('a1${'x' * 70}'), isTrue);
      expect(politicaSenha.hasMatch('a1${'x' * 71}'), isFalse);
    });

    test('envia nome e telefone salvos com a senha atual e a nova', () async {
      await montar(cliente);
      await store.alterarSenha(
        senhaAtual: 'Senha123',
        novaSenha: 'NovaSenha9',
        confirmacao: 'NovaSenha9',
      );
      final c = usuarios.chamadas.single;
      expect(c.nome, 'Lucas Silva');
      expect(c.telefone, '11987654321');
      expect(c.senhaAtual, 'Senha123');
      expect(c.novaSenha, 'NovaSenha9');
      expect(store.evento.value, isA<SenhaAlterada>());
      expect(store.salvandoSenha.value, isFalse);
    });

    test('422 SENHA_ATUAL_INCORRETA aparece no campo da senha atual', () async {
      await montar(cliente);
      usuarios.respostaAtualizar = left(
        const ApiFailure(
          status: 422,
          codigo: 'REGRA_NEGOCIO',
          subcodigo: 'SENHA_ATUAL_INCORRETA',
          message: 'A senha atual está incorreta.',
        ),
      );
      await store.alterarSenha(
        senhaAtual: 'errada123',
        novaSenha: 'NovaSenha9',
        confirmacao: 'NovaSenha9',
      );
      expect(store.erroSenhaAtual.value, 'perfil.senha.atual_incorreta');
      expect(store.evento.value, isNull);

      store.limparErro(CampoPerfil.senhaAtual);
      expect(store.erroSenhaAtual.value, isNull);
    });

    test('item recolhível alterna', () async {
      await montar(cliente);
      expect(store.senhaExpandida.value, isFalse);
      store.alternarSenha();
      expect(store.senhaExpandida.value, isTrue);
      store.alternarSenha();
      expect(store.senhaExpandida.value, isFalse);
    });
  });

  test('sair encerra a sessão', () async {
    await montar(cliente);
    expect(sessao.isAuthenticated.value, isTrue);
    await store.sair();
    expect(auth.logouts, 1);
    expect(sessao.state.value, isA<SessionUnauthenticated>());
    expect(store.saindo.value, isFalse);
  });
}
