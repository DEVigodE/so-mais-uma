import 'package:flutter_test/flutter_test.dart';
import 'package:so_mais_uma/src/features/reservas/presentation/reservas_quadra/resumo_do_dia.dart';
import 'package:so_mais_uma/src/shared/domain/brasilia.dart';
import 'package:so_mais_uma/src/shared/domain/entities/horario_funcionamento.dart';
import 'package:so_mais_uma/src/shared/domain/entities/reserva.dart';
import 'package:so_mais_uma/src/shared/domain/enums.dart';

/// Instante real a partir da hora de parede de Brasília.
DateTime br(int ano, int mes, int dia, int hora, [int minuto = 0]) =>
    Brasilia.instante(DateTime.utc(ano, mes, dia, hora, minuto));

Reserva reserva(
  int id, {
  required DateTime inicio,
  int quadraId = 1,
  StatusReserva status = StatusReserva.confirmada,
  double valor = 90,
  DateTime? expiraEm,
}) =>
    Reserva(
      id: id,
      quadraId: quadraId,
      quadraNome: 'Quadra $quadraId',
      inicio: inicio,
      fim: inicio.add(const Duration(hours: 1)),
      status: status,
      valor: valor,
      expiraEm: expiraEm,
    );

void main() {
  final agora = br(2026, 11, 9, 18, 0);

  group('calcularResumoDoDia (D14)', () {
    test(
        'cenário da spec: 4 confirmadas, 1 pendente que expira em 11 min, '
        '1 cancelada e 25 slots', () {
      final lista = [
        for (var i = 0; i < 4; i++)
          reserva(i + 1, inicio: br(2026, 11, 9, 19 + i % 2)),
        reserva(
          10,
          inicio: br(2026, 11, 9, 21),
          status: StatusReserva.pendentePagamento,
          expiraEm: agora.add(const Duration(minutes: 11)),
        ),
        reserva(11,
            inicio: br(2026, 11, 9, 15), status: StatusReserva.cancelada),
      ];

      final resumo = calcularResumoDoDia(
        reservas: lista,
        slotsDoDia: 25,
        agora: agora,
        hoje: true,
      );

      expect(resumo.agendadas, 4);
      expect(resumo.ocupacaoPercentual, 20);
      expect(resumo.aguardando, 1);
      expect(resumo.expiraEmMinutos, 11);
      expect(resumo.previsao, 450);
      expect(resumo.hoje, isTrue);
    });

    test('ocupação omitida sem slots conhecidos ou com dia fechado', () {
      final lista = [reserva(1, inicio: br(2026, 11, 9, 19))];
      expect(
        calcularResumoDoDia(
                reservas: lista, slotsDoDia: null, agora: agora, hoje: true)
            .ocupacaoPercentual,
        isNull,
      );
      expect(
        calcularResumoDoDia(
                reservas: lista, slotsDoDia: 0, agora: agora, hoje: true)
            .ocupacaoPercentual,
        isNull,
      );
    });

    test('ocupação arredonda e conta pendentes como ativas', () {
      final lista = [
        reserva(1, inicio: br(2026, 11, 9, 19)),
        reserva(2,
            inicio: br(2026, 11, 9, 20),
            status: StatusReserva.pendentePagamento),
        reserva(3, inicio: br(2026, 11, 9, 21), status: StatusReserva.expirada),
      ];
      final r = calcularResumoDoDia(
        reservas: lista,
        slotsDoDia: 3,
        agora: agora,
        hoje: false,
      );
      expect(r.ocupacaoPercentual, 67); // round(200 / 3)
      expect(r.previsao, 180);
      expect(r.hoje, isFalse);
      expect(r.expiraEmMinutos, isNull, reason: 'pendente sem expiraEm');
    });

    test('"Expira em" usa o menor prazo entre as pendentes', () {
      final lista = [
        reserva(
          1,
          inicio: br(2026, 11, 9, 19),
          status: StatusReserva.pendentePagamento,
          expiraEm: agora.add(const Duration(minutes: 9, seconds: 1)),
        ),
        reserva(
          2,
          inicio: br(2026, 11, 9, 20),
          status: StatusReserva.pendentePagamento,
          expiraEm: agora.add(const Duration(minutes: 4)),
        ),
      ];
      final r = calcularResumoDoDia(
        reservas: lista,
        slotsDoDia: 10,
        agora: agora,
        hoje: true,
      );
      expect(r.aguardando, 2);
      expect(r.expiraEmMinutos, 4);
    });

    test('lista vazia', () {
      final r = calcularResumoDoDia(
        reservas: const [],
        slotsDoDia: 12,
        agora: agora,
        hoje: true,
      );
      expect(r.agendadas, 0);
      expect(r.aguardando, 0);
      expect(r.ocupacaoPercentual, 0);
      expect(r.previsao, 0);
    });
  });

  group('minutosRestantes', () {
    test('arredonda para cima', () {
      expect(
          minutosRestantes(
              agora.add(const Duration(minutes: 10, seconds: 30)), agora),
          11);
      expect(
          minutosRestantes(agora.add(const Duration(minutes: 11)), agora), 11);
      expect(minutosRestantes(agora.add(const Duration(seconds: 1)), agora), 1);
    });

    test('nunca é negativo', () {
      expect(minutosRestantes(agora, agora), 0);
      expect(
          minutosRestantes(agora.subtract(const Duration(minutes: 3)), agora),
          0);
    });
  });

  group('somarSlotsDoDia', () {
    const segunda = 1;
    final horarios = {
      1: const [
        HorarioFuncionamento(
            diaSemana: segunda, horaAbertura: '08:00', horaFechamento: '22:00'),
        HorarioFuncionamento(
            diaSemana: 2, horaAbertura: '10:00', horaFechamento: '12:00'),
      ],
      2: const [
        HorarioFuncionamento(
            diaSemana: segunda, horaAbertura: '18:00', horaFechamento: '23:00'),
      ],
      3: const <HorarioFuncionamento>[],
    };

    test('soma as faixas do dia das quadras filtradas', () {
      expect(
        somarSlotsDoDia(
            quadraIds: [1, 2], horarios: horarios, diaSemana: segunda),
        19,
      );
      expect(
          somarSlotsDoDia(quadraIds: [2], horarios: horarios, diaSemana: 2), 0);
      expect(
          somarSlotsDoDia(
              quadraIds: [3], horarios: horarios, diaSemana: segunda),
          0);
    });

    test('desconhecido enquanto faltar a faixa de alguma quadra', () {
      expect(
        somarSlotsDoDia(
            quadraIds: [1, 4], horarios: horarios, diaSemana: segunda),
        isNull,
      );
    });
  });

  group('faixa de datas', () {
    test('hoje até hoje + 14, atravessando o mês', () {
      final hoje = DateTime.utc(2026, 11, 25);
      final faixa = faixaDeDatas(hoje);
      expect(faixa, hasLength(15));
      expect(faixa.first, hoje);
      expect(faixa.last, DateTime.utc(2026, 12, 9));
    });

    test('dataNaFaixa nas bordas', () {
      final hoje = DateTime.utc(2026, 11, 9);
      expect(dataNaFaixa(hoje, hoje), isTrue);
      expect(dataNaFaixa(DateTime.utc(2026, 11, 23), hoje), isTrue);
      expect(dataNaFaixa(DateTime.utc(2026, 11, 24), hoje), isFalse);
      expect(dataNaFaixa(DateTime.utc(2026, 11, 8), hoje), isFalse);
    });
  });

  group('reservasDoDia', () {
    test('agrupa pelo dia de Brasília, filtra a quadra e ordena por início',
        () {
      final lista = [
        reserva(3, inicio: br(2026, 11, 9, 20), quadraId: 2),
        reserva(1, inicio: br(2026, 11, 9, 8)),
        // 23:00 de Brasília é 02:00 UTC do dia seguinte: continua no dia 9.
        reserva(2, inicio: br(2026, 11, 9, 23)),
        reserva(4, inicio: br(2026, 11, 10, 0)),
      ];
      final dia = DateTime.utc(2026, 11, 9);

      expect(reservasDoDia(lista, data: dia).map((r) => r.id), [1, 3, 2]);
      expect(reservasDoDia(lista, data: dia, quadraId: 1).map((r) => r.id),
          [1, 2]);
      expect(
        reservasDoDia(lista, data: DateTime.utc(2026, 11, 10)).map((r) => r.id),
        [4],
      );
    });
  });

  test('o dono cancela reservas ativas até o início', () {
    final futura = reserva(1, inicio: agora.add(const Duration(minutes: 1)));
    expect(donoPodeCancelar(futura, agora), isTrue);
    expect(donoPodeCancelar(reserva(2, inicio: agora), agora), isFalse);
    expect(
      donoPodeCancelar(
        reserva(3,
            inicio: agora.add(const Duration(hours: 2)),
            status: StatusReserva.cancelada),
        agora,
      ),
      isFalse,
    );
    expect(
      donoPodeCancelar(
        reserva(
          4,
          inicio: agora.add(const Duration(hours: 2)),
          status: StatusReserva.pendentePagamento,
        ),
        agora,
      ),
      isTrue,
    );
  });

  test('iniciaisDoNome', () {
    expect(iniciaisDoNome('Maria Souza'), 'MS');
    expect(iniciaisDoNome('  lucas  da   silva '), 'LS');
    expect(iniciaisDoNome('Rodrigo'), 'R');
    expect(iniciaisDoNome(null), '?');
    expect(iniciaisDoNome('   '), '?');
  });
}
