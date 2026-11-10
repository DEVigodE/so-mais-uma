import 'package:flutter_test/flutter_test.dart';
import 'package:so_mais_uma/src/features/reservas/presentation/grade/faixa_datas.dart';

void main() {
  group('gerarFaixaDatas', () {
    test('vai de hoje a hoje + 14 (15 datas)', () {
      // 10/10/2026 15:00 em Brasília.
      final agora = DateTime.utc(2026, 10, 10, 18);
      final datas = gerarFaixaDatas(agora);

      expect(datas, hasLength(15));
      expect(datas.first.data, DateTime.utc(2026, 10, 10));
      expect(datas.last.data, DateTime.utc(2026, 10, 24));
      expect(datas.first.tipo, TipoDia.hoje);
      expect(datas[1].tipo, TipoDia.amanha);
      expect(datas.skip(2).every((d) => d.tipo == TipoDia.outro), isTrue);
    });

    test('"hoje" é o dia em Brasília, não em UTC', () {
      // 11/10/2026 01:30 UTC = 10/10/2026 22:30 em Brasília.
      final datas = gerarFaixaDatas(DateTime.utc(2026, 10, 11, 1, 30));
      expect(datas.first.data, DateTime.utc(2026, 10, 10));
      expect(datas.first.dia, 10);
      // 10/10/2026 foi um sábado.
      expect(datas.first.diaSemana, DateTime.saturday);
    });

    test('atravessa a virada do mês e do ano', () {
      final datas = gerarFaixaDatas(DateTime.utc(2026, 12, 25, 15));
      expect(datas.first.data, DateTime.utc(2026, 12, 25));
      expect(datas[7].data, DateTime.utc(2027, 1, 1));
      expect(datas.last.data, DateTime.utc(2027, 1, 8));
      final dias = datas.map((d) => d.data).toList();
      expect(dias.toSet(), hasLength(15));
    });

    test('datas consecutivas, sem pular nem repetir', () {
      final datas = gerarFaixaDatas(DateTime.utc(2026, 2, 20, 12));
      for (var i = 1; i < datas.length; i++) {
        expect(
          datas[i].data.difference(datas[i - 1].data),
          const Duration(days: 1),
        );
      }
    });
  });

  group('tipoDoDia', () {
    final hoje = DateTime.utc(2026, 10, 10);
    test('hoje, amanhã e outro', () {
      expect(tipoDoDia(DateTime.utc(2026, 10, 10), hoje), TipoDia.hoje);
      expect(tipoDoDia(DateTime.utc(2026, 10, 11), hoje), TipoDia.amanha);
      expect(tipoDoDia(DateTime.utc(2026, 10, 12), hoje), TipoDia.outro);
      expect(tipoDoDia(DateTime.utc(2026, 10, 9), hoje), TipoDia.outro);
    });
  });

  group('formatos', () {
    test('faixaSlot usa hora de Brasília e hífen', () {
      final inicio = DateTime.utc(2026, 10, 10, 22); // 19:00 em Brasília
      final fim = DateTime.utc(2026, 10, 10, 23);
      expect(faixaSlot(inicio, fim), '19:00 - 20:00');
    });

    test('diaMesParede', () {
      expect(diaMesParede(DateTime.utc(2026, 10, 3)), '03/10');
    });
  });
}
