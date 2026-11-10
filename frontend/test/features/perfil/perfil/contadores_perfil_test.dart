import 'package:flutter_test/flutter_test.dart';
import 'package:so_mais_uma/src/features/perfil/presentation/perfil/contadores_perfil.dart';
import 'package:so_mais_uma/src/features/perfil/presentation/perfil/telefone_input_formatter.dart';
import 'package:so_mais_uma/src/shared/domain/entities/quadra.dart';
import 'package:so_mais_uma/src/shared/domain/entities/reserva.dart';
import 'package:so_mais_uma/src/shared/domain/enums.dart';

final agora = DateTime.utc(2026, 11, 9, 18);

Reserva reserva(
  int id, {
  required int quadraId,
  required Duration desdeAgora,
  StatusReserva status = StatusReserva.confirmada,
}) {
  final inicio = agora.add(desdeAgora);
  return Reserva(
    id: id,
    quadraId: quadraId,
    quadraNome: 'Quadra $quadraId',
    inicio: inicio,
    fim: inicio.add(const Duration(hours: 1)),
    status: status,
    valor: 90,
  );
}

Quadra quadra(int id) => Quadra(
      id: id,
      nome: 'Quadra $id',
      tipoEsporte: TipoEsporte.futsal,
      precoHora: 80,
      cep: '01310100',
      logradouro: 'Rua A',
      numero: '1',
      cidade: 'São Paulo',
      uf: 'SP',
    );

void main() {
  // Cenário da spec: 3 confirmadas encerradas em 2 quadras, 1 confirmada
  // futura e 1 cancelada.
  final reservas = [
    reserva(1, quadraId: 1, desdeAgora: const Duration(days: -10)),
    reserva(2, quadraId: 1, desdeAgora: const Duration(days: -3)),
    reserva(3,
        quadraId: 2, desdeAgora: const Duration(hours: -1)), // fim == agora
    reserva(4, quadraId: 3, desdeAgora: const Duration(days: 2)),
    reserva(
      5,
      quadraId: 4,
      desdeAgora: const Duration(days: -1),
      status: StatusReserva.cancelada,
    ),
    reserva(
      6,
      quadraId: 5,
      desdeAgora: const Duration(minutes: -30), // em andamento
    ),
  ];

  group('CLIENTE', () {
    test('Jogos = confirmadas encerradas; Arenas = quadras distintas', () {
      expect(contarJogos(reservas, agora), 3);
      expect(contarArenas(reservas, agora), 2);
      expect(
        calcularContadoresPerfil(
          perfil: PerfilUsuario.cliente,
          agora: agora,
          reservas: reservas,
        ),
        const [
          ContadorPerfil('perfil.contadores.jogos', 3),
          ContadorPerfil('perfil.contadores.arenas', 2),
        ],
      );
    });

    test('sem reservas carregadas os números são omitidos', () {
      expect(
        calcularContadoresPerfil(perfil: PerfilUsuario.cliente, agora: agora),
        isEmpty,
      );
    });

    test('ignora quadras mesmo quando informadas', () {
      final c = calcularContadoresPerfil(
        perfil: PerfilUsuario.cliente,
        agora: agora,
        reservas: const [],
        quadras: [quadra(1)],
      );
      expect(c.map((e) => e.rotuloKey), [
        'perfil.contadores.jogos',
        'perfil.contadores.arenas',
      ]);
      expect(c.map((e) => e.valor), [0, 0]);
    });
  });

  group('DONO', () {
    test('Quadras = escopo MINHAS; Reservas = confirmadas', () {
      expect(contarReservasConfirmadas(reservas), 5);
      expect(
        calcularContadoresPerfil(
          perfil: PerfilUsuario.dono,
          agora: agora,
          reservas: reservas,
          quadras: [quadra(1), quadra(2), quadra(3)],
        ),
        const [
          ContadorPerfil('perfil.contadores.quadras', 3),
          ContadorPerfil('perfil.contadores.reservas', 5),
        ],
      );
    });

    test('cada contador só aparece com a sua fonte', () {
      expect(
        calcularContadoresPerfil(
          perfil: PerfilUsuario.dono,
          agora: agora,
          quadras: [quadra(1)],
        ),
        const [ContadorPerfil('perfil.contadores.quadras', 1)],
      );
      expect(
        calcularContadoresPerfil(
          perfil: PerfilUsuario.dono,
          agora: agora,
          reservas: reservas,
        ),
        const [ContadorPerfil('perfil.contadores.reservas', 5)],
      );
    });
  });

  group('TelefoneInputFormatter', () {
    test('formata enquanto digita', () {
      expect(TelefoneInputFormatter.formatar(''), '');
      expect(TelefoneInputFormatter.formatar('1'), '(1');
      expect(TelefoneInputFormatter.formatar('11'), '(11');
      expect(TelefoneInputFormatter.formatar('119'), '(11) 9');
      expect(TelefoneInputFormatter.formatar('119123'), '(11) 9123');
      expect(TelefoneInputFormatter.formatar('1191234'), '(11) 9123-4');
      expect(TelefoneInputFormatter.formatar('1134567890'), '(11) 3456-7890');
      expect(TelefoneInputFormatter.formatar('11912345678'), '(11) 91234-5678');
    });

    test('aceita só dígitos e no máximo 11', () {
      expect(
        TelefoneInputFormatter.formatar('(11) 91234-5678 99'),
        '(11) 91234-5678',
      );
      expect(TelefoneInputFormatter.formatar('ab'), '');
    });

    test('apagar dígitos e máscara', () {
      const f = TelefoneInputFormatter();
      final apagouDigito = f.formatEditUpdate(
        const TextEditingValue(text: '(11) 9123-4'),
        const TextEditingValue(text: '(11) 9123-'),
      );
      expect(apagouDigito.text, '(11) 9123');
      expect(apagouDigito.selection.baseOffset, '(11) 9123'.length);

      // Apagar só o hífen (mesmos dígitos) também remove um dígito, senão a
      // máscara voltaria e o apagar não teria efeito.
      final apagouHifen = f.formatEditUpdate(
        const TextEditingValue(text: '(11) 9123-4'),
        const TextEditingValue(text: '(11) 91234'),
      );
      expect(apagouHifen.text, '(11) 9123');
    });
  });
}
