import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:so_mais_uma/src/features/horarios/domain/salvar_horarios_use_case.dart';
import 'package:so_mais_uma/src/shared/domain/entities/horario_funcionamento.dart';
import 'package:so_mais_uma/src/shared/domain/repositories/repositorios.dart';
import 'package:so_mais_uma/src/utils/failure.dart';
import 'package:so_mais_uma/src/utils/typedefs.dart';

/// Repositório falso que registra as chamadas na ordem e falha por dia.
class HorarioRepositoryFalso implements HorarioRepository {
  final chamadas = <String>[];

  /// Falha a devolver na operação do dia (1..7).
  final falhas = <int, Failure>{};
  var _proximoId = 100;

  /// Dia de cada faixa conhecida (para PUT/DELETE, que recebem só o id).
  final diaDoId = <int, int>{};

  @override
  FutureEither<List<HorarioFuncionamento>> listar(int quadraId) async =>
      const Right([]);

  @override
  FutureEither<HorarioFuncionamento> criar(
    int quadraId, {
    required int diaSemana,
    required String horaAbertura,
    required String horaFechamento,
  }) async {
    chamadas.add('POST $diaSemana $horaAbertura-$horaFechamento');
    final falha = falhas[diaSemana];
    if (falha != null) return Left(falha);
    final id = _proximoId++;
    diaDoId[id] = diaSemana;
    return Right(HorarioFuncionamento(
      id: id,
      quadraId: quadraId,
      diaSemana: diaSemana,
      horaAbertura: horaAbertura,
      horaFechamento: horaFechamento,
    ));
  }

  @override
  FutureEither<HorarioFuncionamento> atualizar(
    int quadraId,
    int horarioId, {
    required String horaAbertura,
    required String horaFechamento,
  }) async {
    final dia = diaDoId[horarioId]!;
    chamadas.add('PUT $dia $horaAbertura-$horaFechamento');
    final falha = falhas[dia];
    if (falha != null) return Left(falha);
    return Right(HorarioFuncionamento(
      id: horarioId,
      quadraId: quadraId,
      diaSemana: dia,
      horaAbertura: horaAbertura,
      horaFechamento: horaFechamento,
    ));
  }

  @override
  FutureEither<void> remover(int quadraId, int horarioId) async {
    final dia = diaDoId[horarioId]!;
    chamadas.add('DELETE $dia');
    final falha = falhas[dia];
    if (falha != null) return Left(falha);
    return const Right(null);
  }
}

HorarioFuncionamento faixa(int id, int dia, int abre, int fecha) =>
    HorarioFuncionamento(
      id: id,
      quadraId: 1,
      diaSemana: dia,
      horaAbertura: HorarioFuncionamento.hora(abre),
      horaFechamento: HorarioFuncionamento.hora(fecha),
    );

const conflitoReservas = ApiFailure(
  status: 409,
  codigo: 'HORARIO_COM_RESERVAS',
  message: 'conflito',
);

void main() {
  late HorarioRepositoryFalso repo;
  late SalvarHorariosUseCase salvar;

  /// Servidor: terça 08-22 (id 12), quarta 08-22 (id 13), domingo 08-18 (id 17).
  final servidor = [
    faixa(12, 2, 8, 22),
    faixa(13, 3, 8, 22),
    faixa(17, 7, 8, 18),
  ];

  setUp(() {
    repo = HorarioRepositoryFalso();
    for (final h in servidor) {
      repo.diaDoId[h.id!] = h.diaSemana;
    }
    salvar = SalvarHorariosUseCase(repo);
  });

  List<FaixaDia> editar(Map<int, FaixaDia Function(FaixaDia)> mudancas) => [
        for (final d in semanaDoServidor(servidor))
          mudancas[d.diaSemana]?.call(d) ?? d,
      ];

  group('calcularOperacoesHorario', () {
    test('sem alteração não gera operações', () {
      expect(
        calcularOperacoesHorario(
          servidor: servidor,
          editado: semanaDoServidor(servidor),
        ),
        isEmpty,
      );
    });

    test('mudar as horas guardadas de um dia fechado não gera operação', () {
      final editado = editar({
        1: (d) => d.copyWith(abertura: 6, fechamento: 9),
      });
      expect(
        calcularOperacoesHorario(servidor: servidor, editado: editado),
        isEmpty,
      );
    });

    test(
        'POST para dia novo, PUT para faixa alterada e DELETE para dia fechado',
        () {
      final editado = editar({
        1: (d) => d.copyWith(aberto: true, abertura: 8, fechamento: 22),
        2: (d) => d.copyWith(abertura: 9),
        7: (d) => d.copyWith(aberto: false),
      });
      expect(
        calcularOperacoesHorario(servidor: servidor, editado: editado),
        const [
          CriarHorario(1, horaAbertura: '08:00', horaFechamento: '22:00'),
          AtualizarHorario(
            2,
            horarioId: 12,
            horaAbertura: '09:00',
            horaFechamento: '22:00',
          ),
          RemoverHorario(7, horarioId: 17),
        ],
      );
    });
  });

  group('SalvarHorariosUseCase', () {
    test('envia POST, PUT e DELETE nessa ordem, de segunda a domingo',
        () async {
      final editado = editar({
        7: (d) => d.copyWith(aberto: false),
        2: (d) => d.copyWith(abertura: 9),
        1: (d) => d.copyWith(aberto: true),
      });

      final r = await salvar(quadraId: 1, servidor: servidor, editado: editado);

      expect(repo.chamadas, [
        'POST 1 08:00-22:00',
        'PUT 2 09:00-22:00',
        'DELETE 7',
      ]);
      expect(r.concluido, isTrue);
      expect(r.dias.map((d) => d.status), everyElement(StatusOperacao.sucesso));
      expect(r.servidor.map((h) => h.diaSemana), [1, 2, 3]);
      expect(r.servidor[1].horaAbertura, '09:00');
      expect(r.editado, editado);
      expect(
        calcularOperacoesHorario(servidor: r.servidor, editado: r.editado),
        isEmpty,
      );
    });

    test('409 reverte só a linha em conflito e as outras ficam salvas',
        () async {
      repo.falhas[2] = conflitoReservas;
      final editado = editar({
        2: (d) => d.copyWith(fechamento: 18),
        3: (d) => d.copyWith(abertura: 9),
      });

      final r = await salvar(quadraId: 1, servidor: servidor, editado: editado);

      expect(repo.chamadas, ['PUT 2 08:00-18:00', 'PUT 3 09:00-22:00']);
      expect(r.concluido, isFalse);
      expect(r.interrompido, isFalse);
      expect(r.dias.map((d) => d.status), [
        StatusOperacao.conflito,
        StatusOperacao.sucesso,
      ]);
      expect(r.dias.first.codigo, 'HORARIO_COM_RESERVAS');
      // Terça volta ao servidor; quarta mantém a edição salva.
      expect(
        r.editado[1],
        const FaixaDia(diaSemana: 2, aberto: true, abertura: 8, fechamento: 22),
      );
      expect(r.editado[2].abertura, 9);
      expect(
          r.servidor.firstWhere((h) => h.diaSemana == 3).horaAbertura, '09:00');
      expect(r.servidor.firstWhere((h) => h.diaSemana == 2).horaFechamento,
          '22:00');
    });

    test('409 num dia novo fecha o dia e guarda as horas digitadas', () async {
      repo.falhas[1] = const ApiFailure(
        status: 409,
        codigo: 'DIA_JA_CADASTRADO',
        message: 'dia já cadastrado',
      );
      final editado = editar({
        1: (d) => d.copyWith(aberto: true, abertura: 7, fechamento: 21),
      });

      final r = await salvar(quadraId: 1, servidor: servidor, editado: editado);

      expect(r.dias.single.status, StatusOperacao.conflito);
      expect(
        r.editado.first,
        const FaixaDia(
            diaSemana: 1, aberto: false, abertura: 7, fechamento: 21),
      );
    });

    test('falha de rede interrompe a sequência e o resto fica não enviado',
        () async {
      repo.falhas[2] = const NetworkFailure('sem conexão');
      final editado = editar({
        1: (d) => d.copyWith(aberto: true),
        2: (d) => d.copyWith(abertura: 9),
        7: (d) => d.copyWith(aberto: false),
      });

      final r = await salvar(quadraId: 1, servidor: servidor, editado: editado);

      expect(repo.chamadas, ['POST 1 08:00-22:00', 'PUT 2 09:00-22:00']);
      expect(r.interrompido, isTrue);
      expect(r.dias.map((d) => d.status), [
        StatusOperacao.sucesso,
        StatusOperacao.falhaRede,
        StatusOperacao.naoEnviada,
      ]);
      // A segunda ficou salva; terça e domingo continuam pendentes.
      expect(r.servidor.map((h) => h.diaSemana), [1, 2, 3, 7]);
      expect(r.editado, editado);
      expect(
        calcularOperacoesHorario(servidor: r.servidor, editado: r.editado)
            .map((o) => o.diaSemana),
        [2, 7],
      );
    });

    test('erro 400 deixa o dia pendente e a sequência continua', () async {
      repo.falhas[2] = const ApiFailure(
        status: 400,
        codigo: 'VALIDACAO',
        campos: {'faixaValida': 'inválida'},
        message: 'validação',
      );
      final editado = editar({
        2: (d) => d.copyWith(abertura: 9),
        7: (d) => d.copyWith(aberto: false),
      });

      final r = await salvar(quadraId: 1, servidor: servidor, editado: editado);

      expect(repo.chamadas, ['PUT 2 09:00-22:00', 'DELETE 7']);
      expect(r.dias.map((d) => d.status), [
        StatusOperacao.erro,
        StatusOperacao.sucesso,
      ]);
      expect(r.editado[1].abertura, 9);
      expect(r.servidor.map((h) => h.diaSemana), [2, 3]);
    });
  });
}
