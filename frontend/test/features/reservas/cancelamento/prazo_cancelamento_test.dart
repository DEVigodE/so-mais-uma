import 'package:flutter_test/flutter_test.dart';
import 'package:so_mais_uma/src/features/reservas/presentation/cancelamento/prazo_cancelamento.dart';
import 'package:so_mais_uma/src/shared/domain/domain.dart';

import '../minhas_reservas/fakes.dart';

void main() {
  final agora = agoraBase;

  group('calcularPrazoCancelamento (D14)', () {
    test('confirmada daqui a 48 h às 19:00: faltam 46 horas, limite às 17:00',
        () {
      // 19:00 em Brasília = 22:00 UTC; agora 15:00 em Brasília (18:00 UTC).
      final inicio = DateTime.utc(2026, 11, 11, 22);
      final reserva = reservaFake(
        inicio: inicio,
        status: StatusReserva.confirmada,
      );
      // 48 h antes do início.
      final agora48 = inicio.subtract(const Duration(hours: 48));

      final prazo = calcularPrazoCancelamento(reserva, agora48);

      expect(prazo.situacao, SituacaoPrazo.dentro);
      expect(prazo.limite, inicio.subtract(const Duration(hours: 2)));
      expect(Brasilia.parede(prazo.limite!).hour, 17);
      final t = tempoRestante(prazo.restante!);
      expect(t.unidade, UnidadeRestante.horas);
      expect(t.valor, 46);
      expect(prazo.podeCancelar, isTrue);
      expect(prazo.mostrarBotao, isTrue);
    });

    test('confirmada daqui a 1 h: prazo encerrado e botão desabilitado', () {
      final reserva = reservaFake(
        inicio: agora.add(const Duration(hours: 1)),
      );
      final prazo = calcularPrazoCancelamento(reserva, agora);
      expect(prazo.situacao, SituacaoPrazo.encerrado);
      expect(prazo.mostrarBotao, isTrue);
      expect(prazo.podeCancelar, isFalse);
    });

    test('exatamente 2 h antes ainda está dentro do prazo', () {
      final reserva = reservaFake(
        inicio: agora.add(const Duration(hours: 2)),
      );
      final prazo = calcularPrazoCancelamento(reserva, agora);
      expect(prazo.situacao, SituacaoPrazo.dentro);
      expect(prazo.restante, Duration.zero);
    });

    test('pendente: sempre dentro, até o expiraEm da cobrança', () {
      final reserva = reservaFake(
        inicio: agora.add(const Duration(hours: 1)),
        status: StatusReserva.pendentePagamento,
        expiraEm: agora.add(const Duration(minutes: 20)),
        pagamento: pagamentoFake(
          expiraEm: agora.add(const Duration(minutes: 12)),
        ),
      );
      final prazo = calcularPrazoCancelamento(reserva, agora);
      expect(prazo.situacao, SituacaoPrazo.pendente);
      expect(prazo.podeCancelar, isTrue);
      expect(prazo.restante, const Duration(minutes: 12));
      final t = tempoRestante(prazo.restante!);
      expect(t.unidade, UnidadeRestante.minutos);
      expect(t.valor, 12);
    });

    test('pendente com o Pix vencido não fica negativo', () {
      final reserva = reservaFake(
        inicio: agora.add(const Duration(hours: 1)),
        status: StatusReserva.pendentePagamento,
        expiraEm: agora.subtract(const Duration(minutes: 1)),
      );
      final prazo = calcularPrazoCancelamento(reserva, agora);
      expect(prazo.restante, Duration.zero);
    });

    test('concluída, cancelada e expirada: o cartão não aparece', () {
      final concluida = reservaFake(
        inicio: agora.subtract(const Duration(hours: 3)),
      );
      final cancelada = reservaFake(
        inicio: agora.add(const Duration(days: 1)),
        status: StatusReserva.cancelada,
      );
      final expirada = reservaFake(
        inicio: agora.add(const Duration(days: 1)),
        status: StatusReserva.expirada,
      );
      for (final r in [concluida, cancelada, expirada]) {
        final prazo = calcularPrazoCancelamento(r, agora);
        expect(prazo.situacao, SituacaoPrazo.naoAplica);
        expect(prazo.mostrarBotao, isFalse);
      }
    });
  });

  group('tempoRestante', () {
    test('horas inteiras a partir de 1 h', () {
      final t = tempoRestante(const Duration(hours: 1, minutes: 59));
      expect((t.unidade, t.valor), (UnidadeRestante.horas, 1));
    });

    test('minutos abaixo de 1 h', () {
      final t = tempoRestante(const Duration(minutes: 59, seconds: 59));
      expect((t.unidade, t.valor), (UnidadeRestante.minutos, 59));
    });

    test('menos de 1 minuto mostra 1 min; zero mostra 0 min', () {
      expect(tempoRestante(const Duration(seconds: 30)).valor, 1);
      expect(tempoRestante(Duration.zero).valor, 0);
    });
  });

  group('MotivoCancelamento', () {
    test('5 a 200 caracteres depois do trim', () {
      expect(MotivoCancelamento.valido('Ops'), isFalse);
      expect(MotivoCancelamento.valido('  abcd  '), isFalse);
      expect(MotivoCancelamento.valido('Chuva'), isTrue);
      expect(MotivoCancelamento.valido('  Chuva  '), isTrue);
      expect(MotivoCancelamento.valido('a' * 200), isTrue);
      expect(MotivoCancelamento.valido('a' * 201), isFalse);
    });

    test('aviso de curto só entre 1 e 4 caracteres úteis', () {
      expect(MotivoCancelamento.curto(''), isFalse);
      expect(MotivoCancelamento.curto('     '), isFalse);
      expect(MotivoCancelamento.curto('Ops'), isTrue);
      expect(MotivoCancelamento.curto('Chuva'), isFalse);
    });
  });
}
