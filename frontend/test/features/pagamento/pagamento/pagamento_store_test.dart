// `fake_async` vem com o flutter_test (dependência transitiva).
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' show left, right;
import 'package:so_mais_uma/src/features/pagamento/presentation/pagamento/contador_pix.dart';
import 'package:so_mais_uma/src/features/pagamento/presentation/pagamento/pagamento_store.dart';
import 'package:so_mais_uma/src/shared/domain/domain.dart';
import 'package:so_mais_uma/src/utils/failure.dart';

import 'fakes_pagamento.dart';

/// Monta o store dentro do `FakeAsync`, carrega a reserva 7 e devolve os
/// fakes para o teste.
({PagamentoStore store, FakePagamentos pagamentos, FakeReservas reservas})
    abrir(FakeAsync fake, {Reserva? reserva}) {
  final pagamentos = FakePagamentos(fake);
  final reservas = FakeReservas((_) => ok(reserva ?? reservaPendente()));
  final store = PagamentoStore(
    reservas,
    pagamentos,
    FakeQuadras(),
    RelogioFake(fake),
  );
  store.carregar(7);
  fake.flushMicrotasks();
  return (store: store, pagamentos: pagamentos, reservas: reservas);
}

void semTimers(FakeAsync fake) {
  expect(fake.periodicTimerCount, 0, reason: 'contador');
  expect(fake.nonPeriodicTimerCount, 0, reason: 'consulta');
}

void main() {
  group('carga', () {
    test('cobrança pendente: aguardando, com contador a partir de expiraEm',
        () {
      fakeAsync((fake) {
        // Reserva criada há 4 min: faltam 11 min.
        final t = abrir(
          fake,
          reserva: reservaPendente(expiraEm: const Duration(minutes: 11)),
        );
        expect(t.store.fase.value, FasePagamento.aguardando);
        expect(formatarContadorPix(t.store.restante.value), '11:00');
        expect(t.store.progresso.value, closeTo(11 / 15, 0.0001));
        expect(t.pagamentos.consultas, isEmpty);
        t.store.dispose();
        semTimers(fake);
      });
    });

    test('reserva que já não está pendente leva ao detalhe sem consultar', () {
      fakeAsync((fake) {
        final t = abrir(
          fake,
          reserva: reservaPendente(
            status: StatusReserva.confirmada,
            statusPagamento: StatusPagamento.pago,
          ),
        );
        expect(t.store.navegacao.value, DestinoPagamento.detalhe);
        expect(t.store.fase.value, FasePagamento.saindo);
        fake.elapse(const Duration(minutes: 1));
        expect(t.pagamentos.consultas, isEmpty);
        semTimers(fake);
        t.store.dispose();
      });
    });

    test('404 leva ao detalhe', () {
      fakeAsync((fake) {
        final pagamentos = FakePagamentos(fake);
        final store = PagamentoStore(
          FakeReservas(
            (_) =>
                erro(const ApiFailure(status: 404, codigo: 'NAO_ENCONTRADO')),
          ),
          pagamentos,
          FakeQuadras(),
          RelogioFake(fake),
        );
        store.carregar(7);
        fake.flushMicrotasks();
        expect(store.navegacao.value, DestinoPagamento.detalhe);
        store.dispose();
      });
    });

    test('sem rede na carga: estado de erro e "Tentar novamente"', () {
      fakeAsync((fake) {
        var falhar = true;
        final pagamentos = FakePagamentos(fake);
        final reservas = FakeReservas(
          (_) => falhar
              ? erro(const NetworkFailure('sem rede'))
              : ok(reservaPendente()),
        );
        final store = PagamentoStore(
          reservas,
          pagamentos,
          FakeQuadras(),
          RelogioFake(fake),
        );
        store.carregar(7);
        fake.flushMicrotasks();
        expect(store.fase.value, FasePagamento.erro);
        expect(store.falhaCarga.value, isA<NetworkFailure>());

        falhar = false;
        store.tentarNovamente();
        fake.flushMicrotasks();
        expect(store.fase.value, FasePagamento.aguardando);
        store.dispose();
        semTimers(fake);
      });
    });
  });

  group('consulta (D15)', () {
    test('5 s nos 2 primeiros minutos visíveis e depois 10 s', () {
      fakeAsync((fake) {
        final t = abrir(fake);
        fake.elapse(const Duration(minutes: 3));
        expect(segundos(t.pagamentos.consultas), [
          for (var s = 5; s <= 120; s += 5) s,
          for (var s = 130; s <= 180; s += 10) s,
        ]);
        t.store.dispose();
      });
    });

    test('PAGO para a consulta e emite a ida ao detalhe', () {
      fakeAsync((fake) {
        final t = abrir(fake);
        t.pagamentos.resposta = (n) => right(
              cobranca(
                status: n < 2 ? StatusPagamento.pendente : StatusPagamento.pago,
              ),
            );
        fake.elapse(const Duration(seconds: 15));
        expect(segundos(t.pagamentos.consultas), [5, 10, 15]);
        expect(t.store.navegacao.value, DestinoPagamento.detalhe);
        expect(t.store.fase.value, FasePagamento.saindo);
        semTimers(fake);

        fake.elapse(const Duration(minutes: 1));
        expect(t.pagamentos.consultas.length, 3);
        t.store.consumirNavegacao();
        expect(t.store.navegacao.value, isNull);
        t.store.dispose();
      });
    });

    test('CANCELADO vai ao detalhe com o aviso de cancelamento', () {
      fakeAsync((fake) {
        final t = abrir(fake);
        t.pagamentos.resposta =
            (_) => right(cobranca(status: StatusPagamento.cancelado));
        fake.elapse(const Duration(seconds: 5));
        expect(t.store.navegacao.value, DestinoPagamento.detalheCancelada);
        semTimers(fake);
        t.store.dispose();
      });
    });

    test('EXPIRADO no servidor para a consulta e mostra o expirado', () {
      fakeAsync((fake) {
        final t = abrir(fake);
        t.pagamentos.resposta =
            (_) => right(cobranca(status: StatusPagamento.expirado));
        fake.elapse(const Duration(seconds: 5));
        expect(t.store.fase.value, FasePagamento.expirada);
        expect(t.store.navegacao.value, isNull);
        semTimers(fake);
        fake.elapse(const Duration(minutes: 1));
        expect(t.pagamentos.consultas.length, 1);
        t.store.dispose();
      });
    });

    test('contador em 00:00 faz o último ciclo; pendente vira expirado', () {
      fakeAsync((fake) {
        final t = abrir(
          fake,
          reserva: reservaPendente(expiraEm: const Duration(seconds: 12)),
        );
        t.pagamentos.resposta =
            (_) => right(cobranca(expiraEm: const Duration(seconds: 12)));
        fake.elapse(const Duration(seconds: 13));
        expect(segundos(t.pagamentos.consultas), [5, 10, 12]);
        expect(t.store.fase.value, FasePagamento.expirada);
        expect(formatarContadorPix(t.store.restante.value), '00:00');
        semTimers(fake);
        t.store.dispose();
      });
    });

    test('último ciclo que encontra PAGO confirma', () {
      fakeAsync((fake) {
        final t = abrir(
          fake,
          reserva: reservaPendente(expiraEm: const Duration(seconds: 3)),
        );
        t.pagamentos.resposta = (_) => right(
              cobranca(
                status: StatusPagamento.pago,
                expiraEm: const Duration(seconds: 3),
              ),
            );
        fake.elapse(const Duration(seconds: 4));
        expect(segundos(t.pagamentos.consultas), [3]);
        expect(t.store.navegacao.value, DestinoPagamento.detalhe);
        t.store.dispose();
      });
    });

    test('último ciclo com falha também expira', () {
      fakeAsync((fake) {
        final t = abrir(
          fake,
          reserva: reservaPendente(expiraEm: const Duration(seconds: 3)),
        );
        t.pagamentos.resposta = (_) => left(const NetworkFailure('sem rede'));
        fake.elapse(const Duration(seconds: 4));
        expect(t.store.fase.value, FasePagamento.expirada);
        t.store.dispose();
      });
    });

    test('falha de rede mantém aguardando e a consulta continua', () {
      fakeAsync((fake) {
        final t = abrir(fake);
        t.pagamentos.resposta = (n) =>
            n < 3 ? left(const NetworkFailure('sem rede')) : right(cobranca());
        fake.elapse(const Duration(seconds: 15));
        expect(t.store.fase.value, FasePagamento.aguardando);
        expect(t.store.statusVerificacao.value, StatusVerificacao.semConexao);
        expect(t.store.pagamento.value?.pixCopiaECola, codigoPix);

        fake.elapse(const Duration(seconds: 5));
        expect(segundos(t.pagamentos.consultas), [5, 10, 15, 20]);
        expect(t.store.statusVerificacao.value, StatusVerificacao.ok);
        t.store.dispose();
      });
    });

    test('outra falha mostra "Não foi possível verificar agora"', () {
      fakeAsync((fake) {
        final t = abrir(fake);
        t.pagamentos.resposta = (_) => left(
              const ApiFailure(status: 500, codigo: 'ERRO_INTERNO'),
            );
        fake.elapse(const Duration(seconds: 10));
        expect(t.store.statusVerificacao.value, StatusVerificacao.falha);
        expect(t.store.fase.value, FasePagamento.aguardando);
        expect(t.pagamentos.consultas.length, 2);
        t.store.dispose();
      });
    });

    test('segundo plano pausa; a volta faz um ciclo imediato', () {
      fakeAsync((fake) {
        final t = abrir(fake);
        fake.elapse(const Duration(seconds: 7));
        t.store.aoOcultarApp();
        semTimers(fake);
        fake.elapse(const Duration(minutes: 5));
        expect(segundos(t.pagamentos.consultas), [5]);

        t.store.aoMostrarApp();
        fake.flushMicrotasks();
        fake.elapse(const Duration(seconds: 10));
        // 5 min invisíveis não contam: a cadência continua em 5 s.
        expect(segundos(t.pagamentos.consultas), [5, 307, 312, 317]);
        expect(t.store.tempoVisivel, const Duration(seconds: 17));
        t.store.dispose();
      });
    });

    test('sheet de cancelamento aberto suspende a consulta', () {
      fakeAsync((fake) {
        final t = abrir(fake);
        t.store.suspenderConsulta();
        fake.elapse(const Duration(seconds: 30));
        expect(t.pagamentos.consultas, isEmpty);
        t.store.retomarConsulta();
        fake.flushMicrotasks();
        expect(segundos(t.pagamentos.consultas), [30]);
        t.store.dispose();
      });
    });

    test('dispose cancela os temporizadores e ignora respostas tardias', () {
      fakeAsync((fake) {
        final t = abrir(fake);
        fake.elapse(const Duration(seconds: 6));
        t.store.dispose();
        semTimers(fake);
        fake.elapse(const Duration(minutes: 1));
        expect(segundos(t.pagamentos.consultas), [5]);
      });
    });
  });

  group('ações', () {
    test('"Já realizei" faz um ciclo extra sem mudar a cadência', () {
      fakeAsync((fake) {
        final t = abrir(fake);
        fake.elapse(const Duration(seconds: 2));
        t.store.jaRealizeiPagamento();
        expect(t.store.verificacaoManual.value, VerificacaoManual.verificando);
        fake.flushMicrotasks();
        expect(
          t.store.verificacaoManual.value,
          VerificacaoManual.aguardandoCompensacao,
        );
        fake.elapse(const Duration(seconds: 2));
        expect(t.store.verificacaoManual.value, VerificacaoManual.ociosa);
        fake.elapse(const Duration(seconds: 6));
        expect(segundos(t.pagamentos.consultas), [2, 5, 10]);
        t.store.dispose();
      });
    });

    test('"Já realizei" com PAGO vai ao detalhe', () {
      fakeAsync((fake) {
        final t = abrir(fake);
        t.pagamentos.resposta =
            (_) => right(cobranca(status: StatusPagamento.pago));
        t.store.jaRealizeiPagamento();
        fake.flushMicrotasks();
        expect(t.store.navegacao.value, DestinoPagamento.detalhe);
        expect(t.store.verificacaoManual.value, VerificacaoManual.ociosa);
        t.store.dispose();
      });
    });

    test('simulação confirma e dispara um ciclo imediato', () {
      fakeAsync((fake) {
        final t = abrir(fake);
        t.pagamentos.resposta =
            (_) => right(cobranca(status: StatusPagamento.pago));
        fake.elapse(const Duration(seconds: 1));
        t.store.simular();
        expect(t.store.simulando.value, isTrue);
        fake.flushMicrotasks();
        expect(t.pagamentos.simulacoes, ['TX7']);
        expect(segundos(t.pagamentos.consultas), [1]);
        expect(t.store.navegacao.value, DestinoPagamento.detalhe);
        expect(t.store.simulando.value, isFalse);
        t.store.dispose();
      });
    });

    test('simulação com 403 avisa "Chave de desenvolvimento inválida"', () {
      fakeAsync((fake) {
        final t = abrir(fake);
        t.pagamentos.onSimular =
            (_) => erro(const ApiFailure(status: 403, codigo: 'ACESSO_NEGADO'));
        t.store.simular();
        fake.flushMicrotasks();
        expect(t.store.aviso.value?.chave, 'pagamento.dev_chave_invalida');
        expect(t.pagamentos.consultas, isEmpty);
        t.store.dispose();
      });
    });

    test('"Código copiado!" por 3,5 s', () {
      fakeAsync((fake) {
        final t = abrir(fake);
        t.store.marcarCopiado();
        expect(t.store.copiado.value, isTrue);
        fake.elapse(const Duration(milliseconds: 3400));
        expect(t.store.copiado.value, isTrue);
        fake.elapse(const Duration(milliseconds: 100));
        expect(t.store.copiado.value, isFalse);
        t.store.dispose();
      });
    });

    test('anuncia o contador aos 5 min, a 1 min e em zero', () {
      fakeAsync((fake) {
        final t = abrir(
          fake,
          reserva: reservaPendente(
            expiraEm: const Duration(minutes: 5, seconds: 2),
          ),
        );
        t.pagamentos.resposta = (_) => right(
              cobranca(expiraEm: const Duration(minutes: 5, seconds: 2)),
            );
        final marcos = <int>[];
        void coletar() {
          final m = t.store.marcoContador.value;
          if (m != null) {
            marcos.add(m);
            t.store.consumirMarco();
          }
        }

        for (var s = 0; s < 305; s++) {
          fake.elapse(const Duration(seconds: 1));
          coletar();
        }
        expect(marcos, [300, 60, 0]);
        t.store.dispose();
      });
    });
  });

  group('contador_pix (D14)', () {
    test('restante nunca negativo e mm:ss', () {
      final agora = DateTime.utc(2026);
      expect(
        restantePix(agora.add(const Duration(minutes: 11, seconds: 10)), agora),
        const Duration(minutes: 11, seconds: 10),
      );
      expect(
        restantePix(agora.subtract(const Duration(seconds: 1)), agora),
        Duration.zero,
      );
      expect(restantePix(null, agora), Duration.zero);
      expect(formatarContadorPix(const Duration(minutes: 11, seconds: 10)),
          '11:10');
      expect(formatarContadorPix(Duration.zero), '00:00');
    });

    test('progresso = restante / 900 s, entre 0 e 1', () {
      expect(progressoPix(const Duration(seconds: 450)), 0.5);
      expect(progressoPix(const Duration(minutes: 20)), 1);
      expect(progressoPix(Duration.zero), 0);
    });

    test('marcos cruzados', () {
      expect(marcoCruzado(null, 299), isNull);
      expect(marcoCruzado(301, 300), 300);
      expect(marcoCruzado(61, 59), 60);
      expect(marcoCruzado(1, 0), 0);
      expect(marcoCruzado(200, 199), isNull);
    });
  });
}
