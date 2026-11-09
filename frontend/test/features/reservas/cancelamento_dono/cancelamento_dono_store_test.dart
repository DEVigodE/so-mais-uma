import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:so_mais_uma/src/features/reservas/presentation/cancelamento_dono/cancelamento_dono_store.dart';
import 'package:so_mais_uma/src/shared/domain/entities/reserva.dart';
import 'package:so_mais_uma/src/shared/domain/enums.dart';
import 'package:so_mais_uma/src/shared/domain/repositories/repositorios.dart';
import 'package:so_mais_uma/src/utils/async_state.dart';
import 'package:so_mais_uma/src/utils/failure.dart';
import 'package:so_mais_uma/src/utils/typedefs.dart';

class FakeReservaRepository implements ReservaRepository {
  final List<(int, String)> chamadas = [];
  Either<Failure, Reserva>? resposta;
  Completer<Either<Failure, Reserva>>? pendente;

  @override
  FutureEither<Reserva> cancelar(int id, String motivo) {
    chamadas.add((id, motivo));
    if (pendente != null) return pendente!.future;
    return Future.value(resposta ?? right(cancelada(id, motivo)));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final inicio = DateTime.utc(2026, 11, 10, 22);

Reserva reservaCom(StatusReserva status) => Reserva(
      id: 42,
      quadraId: 1,
      quadraNome: 'Quadra Teste Usabilidade',
      inicio: inicio,
      fim: inicio.add(const Duration(hours: 1)),
      status: status,
      valor: 90,
      clienteNome: 'Maria Souza',
      clienteTelefone: '11987654321',
    );

Reserva cancelada(int id, String motivo) => Reserva(
      id: id,
      quadraId: 1,
      quadraNome: 'Quadra Teste Usabilidade',
      inicio: inicio,
      fim: inicio.add(const Duration(hours: 1)),
      status: StatusReserva.cancelada,
      valor: 90,
      canceladoPor: CanceladoPor.dono,
      motivoCancelamento: motivo,
    );

ApiFailure regra(String subcodigo) => ApiFailure(
      status: 422,
      codigo: 'REGRA_NEGOCIO',
      subcodigo: subcodigo,
      message: 'erro $subcodigo',
    );

void main() {
  late FakeReservaRepository repo;
  late CancelamentoDonoStore store;

  setUp(() {
    repo = FakeReservaRepository();
    store = CancelamentoDonoStore(repo)
      ..iniciar(reservaCom(StatusReserva.confirmada));
  });

  tearDown(() => store.dispose());

  group('motivo', () {
    test('começa na primeira opção da lista e pode confirmar', () {
      expect(store.motivo.value, MotivoCancelamentoDono.manutencao);
      expect(store.motivoLivre.value, isFalse);
      expect(store.podeConfirmar.value, isTrue);
      expect(store.erroMotivo.value, isNull);
    });

    test('"Outro motivo" exige de 5 a 200 caracteres', () {
      store.selecionarMotivo(MotivoCancelamentoDono.outro);
      expect(store.motivoLivre.value, isTrue);
      expect(store.podeConfirmar.value, isFalse, reason: 'texto vazio');
      expect(store.erroMotivo.value, isNull,
          reason: 'sem erro antes de digitar');

      store.alterarTextoLivre('ok');
      expect(store.podeConfirmar.value, isFalse);
      expect(
        store.erroMotivo.value,
        'reservas.cancelamento_dono.erro_minimo',
      );

      store.alterarTextoLivre('chuva');
      expect(store.podeConfirmar.value, isTrue);
      expect(store.erroMotivo.value, isNull);

      store.alterarTextoLivre('   ok   ');
      expect(store.podeConfirmar.value, isFalse, reason: 'conta sem espaços');

      store.alterarTextoLivre('a' * 200);
      expect(store.podeConfirmar.value, isTrue);
      store.alterarTextoLivre('a' * 201);
      expect(store.podeConfirmar.value, isFalse);
    });

    test('motivoLivreValido', () {
      expect(motivoLivreValido('chuva'), isTrue);
      expect(motivoLivreValido('ok'), isFalse);
      expect(motivoLivreValido(' abcd '), isFalse);
      expect(motivoLivreValido('x' * 200), isTrue);
      expect(motivoLivreValido('x' * 201), isFalse);
    });
  });

  group('aviso de estorno', () {
    test('aparece só para CONFIRMADA', () {
      expect(store.mostrarAvisoEstorno.value, isTrue);
      store.iniciar(reservaCom(StatusReserva.pendentePagamento));
      expect(store.mostrarAvisoEstorno.value, isFalse);
    });
  });

  group('confirmar', () {
    test('opção da lista envia o próprio texto e devolve a reserva cancelada',
        () async {
      await store.confirmar();

      expect(repo.chamadas, [
        (42, 'reservas.cancelamento_dono.motivos.manutencao'),
      ]);
      final resultado = store.resultado.value;
      expect(resultado, isA<CancelamentoConcluido>());
      final reserva = (resultado! as CancelamentoConcluido).reserva;
      expect(reserva.status, StatusReserva.cancelada);
      expect(reserva.canceladoPor, CanceladoPor.dono);

      store.consumirResultado();
      expect(store.resultado.value, isNull);
    });

    test('"Outro motivo" envia o texto digitado sem espaços nas pontas',
        () async {
      store
        ..selecionarMotivo(MotivoCancelamentoDono.outro)
        ..alterarTextoLivre('  Vazamento no vestiário  ');
      await store.confirmar();
      expect(repo.chamadas.single.$2, 'Vazamento no vestiário');
    });

    test('não envia com o motivo inválido', () async {
      store
        ..selecionarMotivo(MotivoCancelamentoDono.outro)
        ..alterarTextoLivre('ok');
      await store.confirmar();
      expect(repo.chamadas, isEmpty);
    });

    test('bloqueia novo envio enquanto envia', () async {
      repo.pendente = Completer();
      final envio = store.confirmar();
      expect(store.enviando.value, isTrue);
      expect(store.podeConfirmar.value, isFalse);
      await store.confirmar();
      expect(repo.chamadas, hasLength(1));
      repo.pendente!.complete(right(cancelada(42, 'x')));
      await envio;
      expect(store.enviando.value, isFalse);
    });

    test('422 CANCELAMENTO_FORA_DO_PRAZO recusa com a mensagem da spec',
        () async {
      repo.resposta = left(regra('CANCELAMENTO_FORA_DO_PRAZO'));
      await store.confirmar();
      final r = store.resultado.value;
      expect(r, isA<CancelamentoRecusado>());
      expect(
        (r! as CancelamentoRecusado).mensagem,
        'reservas.cancelamento_dono.fora_do_prazo',
      );
    });

    test('422 TRANSICAO_INVALIDA recusa e pede recarga', () async {
      repo.resposta = left(regra('TRANSICAO_INVALIDA'));
      await store.confirmar();
      expect(
        (store.resultado.value! as CancelamentoRecusado).mensagem,
        'reservas.cancelamento_dono.mudou_situacao',
      );
    });

    test('400 VALIDACAO marca o campo do motivo e mantém o sheet', () async {
      repo.resposta = left(
        const ApiFailure(
          status: 400,
          codigo: 'VALIDACAO',
          campos: {'motivo': 'é obrigatório quando o dono cancela'},
          message: 'Confira os dados informados.',
        ),
      );
      await store.confirmar();
      expect(store.resultado.value, isNull);
      expect(store.erroMotivo.value, 'é obrigatório quando o dono cancela');

      store.selecionarMotivo(MotivoCancelamentoDono.clima);
      expect(store.erroMotivo.value, isNull, reason: 'editar limpa o erro');
    });

    test('falha de rede mostra o erro no sheet', () async {
      repo.resposta = left(const NetworkFailure('Sem conexão.'));
      await store.confirmar();
      expect(store.resultado.value, isNull);
      expect(store.erroGeral.value, 'Sem conexão.');
      expect(store.envio.value, isA<RequestFailure<Reserva>>());
      expect(store.podeConfirmar.value, isTrue, reason: 'pode tentar de novo');
    });

    test('resposta depois do dispose é ignorada', () async {
      repo.pendente = Completer();
      final envio = store.confirmar();
      store.dispose();
      repo.pendente!.complete(right(cancelada(42, 'x')));
      await envio;
      store = CancelamentoDonoStore(repo);
    });
  });
}
