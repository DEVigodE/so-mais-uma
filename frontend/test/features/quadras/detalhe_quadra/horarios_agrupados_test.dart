import 'package:flutter_test/flutter_test.dart';
import 'package:so_mais_uma/src/features/quadras/presentation/detalhe_quadra/horarios_agrupados.dart';
import 'package:so_mais_uma/src/shared/domain/entities/horario_funcionamento.dart';

HorarioFuncionamento _h(int dia, String abre, String fecha) =>
    HorarioFuncionamento(
        diaSemana: dia, horaAbertura: abre, horaFechamento: fecha);

const _nomes = {
  1: 'Segunda',
  2: 'Terça',
  3: 'Quarta',
  4: 'Quinta',
  5: 'Sexta',
  6: 'Sábado',
  7: 'Domingo',
};

String _rotulo(GrupoFuncionamento g) => rotuloDiasDoGrupo(
      g,
      nomeDia: (d) => _nomes[d]!,
      doisDias: (a, b) => '$a e $b',
      intervalo: (a, b) => '$a a $b',
    );

String _linha(GrupoFuncionamento g) =>
    '${_rotulo(g)}: ${g.fechado ? 'Fechado' : '${g.abertura} – ${g.fechamento}'}';

void main() {
  group('agruparHorarios', () {
    test('sem faixas devolve lista vazia', () {
      expect(agruparHorarios(const []), isEmpty);
    });

    test('semana com fim de semana diferente (cenário da spec)', () {
      final grupos = agruparHorarios([
        for (var d = 1; d <= 5; d++) _h(d, '07:00', '23:00'),
        _h(6, '08:00', '22:00'),
      ]);
      expect(grupos.map(_linha), [
        'Segunda a Sexta: 07:00 – 23:00',
        'Sábado: 08:00 – 22:00',
        'Domingo: Fechado',
      ]);
    });

    test('dois dias iguais viram "<a> e <b>"', () {
      final grupos = agruparHorarios([
        for (var d = 1; d <= 5; d++) _h(d, '07:00', '23:00'),
        _h(6, '08:00', '22:00'),
        _h(7, '08:00', '22:00'),
      ]);
      expect(grupos.map(_linha), [
        'Segunda a Sexta: 07:00 – 23:00',
        'Sábado e Domingo: 08:00 – 22:00',
      ]);
      expect(grupos.last.quantidadeDias, 2);
    });

    test('um dia isolado usa só o nome', () {
      final grupos = agruparHorarios([_h(3, '10:00', '12:00')]);
      expect(grupos.map(_linha), [
        'Segunda e Terça: Fechado',
        'Quarta: 10:00 – 12:00',
        'Quinta a Domingo: Fechado',
      ]);
    });

    test('dias fechados no meio quebram o grupo', () {
      final grupos = agruparHorarios([
        _h(1, '08:00', '20:00'),
        _h(2, '08:00', '20:00'),
        _h(4, '08:00', '20:00'),
        _h(5, '08:00', '20:00'),
        _h(6, '08:00', '20:00'),
      ]);
      expect(grupos.map(_linha), [
        'Segunda e Terça: 08:00 – 20:00',
        'Quarta: Fechado',
        'Quinta a Sábado: 08:00 – 20:00',
        'Domingo: Fechado',
      ]);
    });

    test('a semana toda igual vira um grupo de 7 dias', () {
      final grupos = agruparHorarios([
        for (var d = 1; d <= 7; d++) _h(d, '06:00', '23:00'),
      ]);
      expect(grupos, hasLength(1));
      expect(_linha(grupos.single), 'Segunda a Domingo: 06:00 – 23:00');
    });

    test('domingo não se junta à segunda', () {
      final grupos = agruparHorarios([
        _h(1, '08:00', '22:00'),
        for (var d = 2; d <= 6; d++) _h(d, '07:00', '23:00'),
        _h(7, '08:00', '22:00'),
      ]);
      expect(
          grupos.first,
          const GrupoFuncionamento(
            primeiroDia: 1,
            ultimoDia: 1,
            abertura: '08:00',
            fechamento: '22:00',
          ));
      expect(
          grupos.last,
          const GrupoFuncionamento(
            primeiroDia: 7,
            ultimoDia: 7,
            abertura: '08:00',
            fechamento: '22:00',
          ));
      expect(grupos, hasLength(3));
    });

    test('faixas diferentes em dias vizinhos não se juntam', () {
      final grupos = agruparHorarios([
        _h(1, '08:00', '22:00'),
        _h(2, '08:00', '21:00'),
      ]);
      expect(grupos.map(_linha), [
        'Segunda: 08:00 – 22:00',
        'Terça: 08:00 – 21:00',
        'Quarta a Domingo: Fechado',
      ]);
    });

    test('a ordem da lista recebida não importa', () {
      final a =
          agruparHorarios([_h(2, '08:00', '22:00'), _h(1, '08:00', '22:00')]);
      final b =
          agruparHorarios([_h(1, '08:00', '22:00'), _h(2, '08:00', '22:00')]);
      expect(a, b);
    });
  });
}
