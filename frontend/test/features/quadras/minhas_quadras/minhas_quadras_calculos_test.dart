import 'package:flutter_test/flutter_test.dart';
import 'package:so_mais_uma/src/features/quadras/presentation/minhas_quadras/minhas_quadras_calculos.dart';
import 'package:so_mais_uma/src/shared/domain/entities/horario_funcionamento.dart';
import 'package:so_mais_uma/src/shared/domain/entities/quadra.dart';
import 'package:so_mais_uma/src/shared/domain/entities/reserva.dart';
import 'package:so_mais_uma/src/shared/domain/enums.dart';

/// Instante de uma hora de parede em Brasília (UTC-3) em novembro de 2026.
/// 09/11/2026 é uma segunda-feira.
DateTime br(int hora, {int dia = 9, int minuto = 0}) =>
    DateTime.utc(2026, 11, dia, hora + 3, minuto);

var _id = 0;

Reserva reserva({
  int quadraId = 1,
  required DateTime inicio,
  StatusReserva status = StatusReserva.confirmada,
}) =>
    Reserva(
      id: ++_id,
      quadraId: quadraId,
      quadraNome: 'Quadra $quadraId',
      inicio: inicio,
      fim: inicio.add(const Duration(hours: 1)),
      status: status,
      valor: 90,
    );

Quadra quadra(int id, String nome, {bool ativa = true}) => Quadra(
      id: id,
      nome: nome,
      tipoEsporte: TipoEsporte.futebolSociety,
      precoHora: 90,
      cep: '01001000',
      logradouro: 'Rua A',
      numero: '1',
      cidade: 'São Paulo',
      uf: 'SP',
      ativa: ativa,
    );

const segunda8a22 = [
  HorarioFuncionamento(
    id: 1,
    diaSemana: 1,
    horaAbertura: '08:00',
    horaFechamento: '22:00',
  ),
];

void main() {
  final agora = br(15, minuto: 10);

  group('calcularAtividade', () {
    test('ocupação do dia: 6 reservas das 08:00 às 22:00 às 15:10', () {
      final reservas = [
        reserva(inicio: br(8)),
        reserva(inicio: br(10)),
        reserva(inicio: br(14), status: StatusReserva.pendentePagamento),
        reserva(inicio: br(18)),
        reserva(inicio: br(20)),
        reserva(inicio: br(21)),
      ];

      final a = calcularAtividade(
        quadraId: 1,
        reservas: reservas,
        horarios: segunda8a22,
        agora: agora,
      );

      expect(a.reservasHoje, 6);
      expect(a.proxima, br(18));
      expect(a.ocupacao, 43);
      expect(a.fechadaHoje, isFalse);
    });

    test('conta só pendentes e confirmadas da quadra com início hoje', () {
      final reservas = [
        reserva(inicio: br(9)),
        reserva(inicio: br(11), status: StatusReserva.cancelada),
        reserva(inicio: br(12), status: StatusReserva.expirada),
        reserva(inicio: br(13), quadraId: 2),
        reserva(inicio: br(9, dia: 10)),
        reserva(inicio: br(9, dia: 8)),
        // 23:00 de Brasília ainda é hoje (02:00 UTC do dia seguinte).
        reserva(inicio: br(23)),
      ];

      final a = calcularAtividade(
        quadraId: 1,
        reservas: reservas,
        horarios: segunda8a22,
        agora: agora,
      );

      expect(a.reservasHoje, 2);
      expect(a.proxima, br(23));
    });

    test('sem reserva futura hoje: "Sem próximas hoje" (proxima nula)', () {
      final a = calcularAtividade(
        quadraId: 1,
        reservas: [reserva(inicio: br(9)), reserva(inicio: br(15))],
        horarios: segunda8a22,
        agora: agora,
      );
      expect(a.reservasHoje, 2);
      expect(a.proxima, isNull);
    });

    test('quadra sem faixa no dia de hoje: "Fechada hoje"', () {
      final a = calcularAtividade(
        quadraId: 1,
        reservas: const [],
        horarios: const [
          HorarioFuncionamento(
            diaSemana: 2,
            horaAbertura: '08:00',
            horaFechamento: '22:00',
          ),
        ],
        agora: agora,
      );
      expect(a.fechadaHoje, isTrue);
      expect(a.ocupacao, isNull);
    });

    test('dia da semana usa o fuso de Brasília', () {
      // Domingo 08/11 às 22:00 em Brasília = segunda 01:00 UTC.
      final a = calcularAtividade(
        quadraId: 1,
        reservas: const [],
        horarios: segunda8a22,
        agora: br(22, dia: 8),
      );
      expect(a.fechadaHoje, isTrue);
    });

    test('faixas desconhecidas: sem ocupação e sem "Fechada hoje"', () {
      final a = calcularAtividade(
        quadraId: 1,
        reservas: [reserva(inicio: br(18))],
        horarios: null,
        agora: agora,
      );
      expect(a.reservasHoje, 1);
      expect(a.ocupacao, isNull);
      expect(a.fechadaHoje, isFalse);
    });

    test('reservas não carregadas: n nulo', () {
      final a = calcularAtividade(
        quadraId: 1,
        reservas: null,
        horarios: segunda8a22,
        agora: agora,
      );
      expect(a.reservasHoje, isNull);
      expect(a.ocupacao, isNull);
    });
  });

  test('ocupacaoDoDia arredonda e limita a 100', () {
    expect(ocupacaoDoDia(6, 14), 43);
    expect(ocupacaoDoDia(1, 3), 33);
    expect(ocupacaoDoDia(0, 14), 0);
    expect(ocupacaoDoDia(20, 14), 100);
  });

  test('painel conta só as confirmadas de hoje', () {
    final reservas = [
      reserva(inicio: br(8)),
      reserva(inicio: br(10), quadraId: 2),
      reserva(inicio: br(19)),
      reserva(inicio: br(20), status: StatusReserva.pendentePagamento),
      reserva(inicio: br(9, dia: 10)),
    ];
    expect(reservasConfirmadasHoje(reservas, agora), 3);
  });

  test('total de quadras conta ativas e inativas', () {
    expect(
      totalDeQuadras([quadra(1, 'A'), quadra(2, 'B', ativa: false)]),
      2,
    );
  });

  test('ordem "Mais ativas": ativas, n decrescente e nome', () {
    QuadraComAtividade item(Quadra q, int n) =>
        QuadraComAtividade(q, AtividadeQuadra(reservasHoje: n));

    final ordenados = ordenarMaisAtivas([
      item(quadra(1, 'Zeta', ativa: false), 9),
      item(quadra(2, 'beta'), 2),
      item(quadra(3, 'Alfa'), 2),
      item(quadra(4, 'Gama'), 5),
    ]);

    expect(
        ordenados.map((i) => i.quadra.nome), ['Gama', 'Alfa', 'beta', 'Zeta']);
  });
}
