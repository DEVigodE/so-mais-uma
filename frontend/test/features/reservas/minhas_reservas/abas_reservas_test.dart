import 'package:flutter_test/flutter_test.dart';
import 'package:so_mais_uma/src/features/reservas/presentation/minhas_reservas/abas_reservas.dart';
import 'package:so_mais_uma/src/shared/domain/domain.dart';

import 'fakes.dart';

void main() {
  final agora = agoraBase;

  group('separarAbas (D14)', () {
    test('cenário da spec: amanhã, ontem e expirada', () {
      final amanha = reservaFake(
        id: 1,
        inicio: agora.add(const Duration(days: 1)),
      );
      final ontem = reservaFake(
        id: 2,
        inicio: agora.subtract(const Duration(days: 1)),
      );
      final expirada = reservaFake(
        id: 3,
        inicio: agora.add(const Duration(days: 2)),
        status: StatusReserva.expirada,
      );

      final abas = separarAbas([ontem, expirada, amanha], agora);

      expect(abas.proximas.map((r) => r.id), [1]);
      expect(abas.historico.length, 2);
      expect(SituacaoReserva.de(ontem, agora), SituacaoReserva.concluida);
      expect(SituacaoReserva.de(amanha, agora), SituacaoReserva.confirmada);
      expect(SituacaoReserva.de(expirada, agora), SituacaoReserva.expirada);
    });

    test('próximas em ordem crescente e histórico em ordem decrescente', () {
      final reservas = [
        reservaFake(id: 1, inicio: agora.add(const Duration(days: 3))),
        reservaFake(
          id: 2,
          inicio: agora.add(const Duration(hours: 2)),
          status: StatusReserva.pendentePagamento,
        ),
        reservaFake(id: 3, inicio: agora.add(const Duration(days: 1))),
        reservaFake(id: 4, inicio: agora.subtract(const Duration(days: 5))),
        reservaFake(
          id: 5,
          inicio: agora.subtract(const Duration(days: 1)),
          status: StatusReserva.cancelada,
        ),
        reservaFake(id: 6, inicio: agora.subtract(const Duration(days: 3))),
      ];

      final abas = separarAbas(reservas, agora);

      expect(abas.proximas.map((r) => r.id), [2, 3, 1]);
      expect(abas.historico.map((r) => r.id), [5, 6, 4]);
    });

    test('cancelada futura vai para o histórico', () {
      final cancelada = reservaFake(
        inicio: agora.add(const Duration(days: 1)),
        status: StatusReserva.cancelada,
      );
      final abas = separarAbas([cancelada], agora);
      expect(abas.proximas, isEmpty);
      expect(abas.historico, [cancelada]);
    });

    test('confirmada em andamento continua em Próximas e não é "Concluída"',
        () {
      final emJogo = reservaFake(
        inicio: agora.subtract(const Duration(minutes: 30)),
      );
      final abas = separarAbas([emJogo], agora);
      expect(abas.proximas, [emJogo]);
      expect(SituacaoReserva.de(emJogo, agora), SituacaoReserva.confirmada);
    });

    test('fim igual a agora já é "Concluída" e vai para o histórico', () {
      final terminou = reservaFake(
        inicio: agora.subtract(const Duration(hours: 1)),
      );
      final abas = separarAbas([terminou], agora);
      expect(abas.historico, [terminou]);
      expect(SituacaoReserva.de(terminou, agora), SituacaoReserva.concluida);
      expect(SituacaoReserva.concluida.rotuloKey, 'status_reserva.CONCLUIDA');
    });

    test('contadores das abas são o tamanho de cada lista', () {
      final abas = separarAbas([
        reservaFake(id: 1, inicio: agora.add(const Duration(days: 1))),
        reservaFake(id: 2, inicio: agora.add(const Duration(days: 2))),
        reservaFake(id: 3, inicio: agora.subtract(const Duration(days: 2))),
      ], agora);
      expect(abas.proximas.length, 2);
      expect(abas.historico.length, 1);
    });
  });

  group('contador do card pendente', () {
    test('restante a partir de expiraEm, no formato mm:ss', () {
      final pendente = reservaFake(
        inicio: agora.add(const Duration(days: 1)),
        status: StatusReserva.pendentePagamento,
        expiraEm: agora.add(const Duration(minutes: 10, seconds: 29)),
      );
      final restante = restantePagamento(pendente, agora)!;
      expect(formatarMmSs(restante), '10:29');
    });

    test('prefere o expiraEm da cobrança e nunca fica negativo', () {
      final pendente = reservaFake(
        inicio: agora.add(const Duration(days: 1)),
        status: StatusReserva.pendentePagamento,
        expiraEm: agora.add(const Duration(minutes: 10)),
        pagamento: pagamentoFake(
          expiraEm: agora.subtract(const Duration(seconds: 1)),
        ),
      );
      expect(restantePagamento(pendente, agora), Duration.zero);
      expect(formatarMmSs(Duration.zero), '00:00');
    });

    test('sem expiraEm não há contador', () {
      final pendente = reservaFake(
        inicio: agora.add(const Duration(days: 1)),
        status: StatusReserva.pendentePagamento,
      );
      expect(restantePagamento(pendente, agora), isNull);
    });
  });
}
