import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:so_mais_uma/src/features/horarios/domain/salvar_horarios_use_case.dart';
import 'package:so_mais_uma/src/features/horarios/presentation/horarios_quadra/horarios_quadra_store.dart';
import 'package:so_mais_uma/src/shared/domain/entities/horario_funcionamento.dart';
import 'package:so_mais_uma/src/shared/domain/entities/quadra.dart';
import 'package:so_mais_uma/src/shared/domain/enums.dart';
import 'package:so_mais_uma/src/shared/domain/repositories/repositorios.dart';
import 'package:so_mais_uma/src/utils/async_state.dart';
import 'package:so_mais_uma/src/utils/failure.dart';
import 'package:so_mais_uma/src/utils/typedefs.dart';

class HorarioRepositoryFalso implements HorarioRepository {
  HorarioRepositoryFalso(this.faixas);

  /// Estado do "servidor".
  List<HorarioFuncionamento> faixas;
  final chamadas = <String>[];
  final falhas = <int, Failure>{};
  Failure? falhaListar;
  var _proximoId = 100;

  int _dia(int id) => faixas.firstWhere((h) => h.id == id).diaSemana;

  @override
  FutureEither<List<HorarioFuncionamento>> listar(int quadraId) async {
    final f = falhaListar;
    return f == null ? Right(List.of(faixas)) : Left(f);
  }

  @override
  FutureEither<HorarioFuncionamento> criar(
    int quadraId, {
    required int diaSemana,
    required String horaAbertura,
    required String horaFechamento,
  }) async {
    chamadas.add('POST $diaSemana');
    final falha = falhas[diaSemana];
    if (falha != null) return Left(falha);
    final h = HorarioFuncionamento(
      id: _proximoId++,
      quadraId: quadraId,
      diaSemana: diaSemana,
      horaAbertura: horaAbertura,
      horaFechamento: horaFechamento,
    );
    faixas = [...faixas, h];
    return Right(h);
  }

  @override
  FutureEither<HorarioFuncionamento> atualizar(
    int quadraId,
    int horarioId, {
    required String horaAbertura,
    required String horaFechamento,
  }) async {
    final dia = _dia(horarioId);
    chamadas.add('PUT $dia');
    final falha = falhas[dia];
    if (falha != null) return Left(falha);
    final h = HorarioFuncionamento(
      id: horarioId,
      quadraId: quadraId,
      diaSemana: dia,
      horaAbertura: horaAbertura,
      horaFechamento: horaFechamento,
    );
    faixas = faixas.map((f) => f.id == horarioId ? h : f).toList();
    return Right(h);
  }

  @override
  FutureEither<void> remover(int quadraId, int horarioId) async {
    final dia = _dia(horarioId);
    chamadas.add('DELETE $dia');
    final falha = falhas[dia];
    if (falha != null) return Left(falha);
    faixas = faixas.where((f) => f.id != horarioId).toList();
    return const Right(null);
  }
}

class QuadraRepositoryFalso implements QuadraRepository {
  @override
  FutureEither<Quadra> detalhar(int id) async => Right(Quadra(
        id: id,
        nome: 'Arena Champions Society',
        tipoEsporte: TipoEsporte.futebolSociety,
        precoHora: 90,
        cep: '01001000',
        logradouro: 'Praça da Sé',
        numero: '1',
        cidade: 'São Paulo',
        uf: 'SP',
      ));

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

HorarioFuncionamento faixa(int id, int dia, int abre, int fecha) =>
    HorarioFuncionamento(
      id: id,
      quadraId: 1,
      diaSemana: dia,
      horaAbertura: HorarioFuncionamento.hora(abre),
      horaFechamento: HorarioFuncionamento.hora(fecha),
    );

void main() {
  setUpAll(() => EasyLocalization.logger.enableBuildModes = []);

  late HorarioRepositoryFalso horarios;
  late HorariosQuadraStore store;

  Future<HorariosQuadraStore> criar(List<HorarioFuncionamento> faixas) async {
    horarios = HorarioRepositoryFalso(faixas);
    store = HorariosQuadraStore(
      horarios,
      QuadraRepositoryFalso(),
      SalvarHorariosUseCase(horarios),
    );
    await store.carregar(1);
    return store;
  }

  tearDown(() => store.dispose());

  FaixaDia dia(int d) => store.dias.value[d - 1];

  group('carga', () {
    test('mostra as faixas do servidor e fecha os dias sem registro', () async {
      await criar([faixa(12, 2, 8, 22), faixa(17, 7, 8, 18)]);

      expect(store.carga.value, isA<RequestSuccess<void>>());
      expect(store.quadra.value?.nome, 'Arena Champions Society');
      expect(store.dias.value.map((d) => d.aberto),
          [false, true, false, false, false, false, true]);
      expect(dia(7).fechamento, 18);
      expect(store.semFaixas.value, isFalse);
      expect(store.alterado.value, isFalse);
      expect(store.podeSalvar.value, isFalse);
    });

    test('quadra sem faixas: 7 dias fechados e a dica', () async {
      await criar([]);
      expect(store.dias.value.every((d) => !d.aberto), isTrue);
      expect(store.semFaixas.value, isTrue);
    });

    test('falha de carga vira RequestFailure', () async {
      horarios = HorarioRepositoryFalso([])
        ..falhaListar = const NetworkFailure('sem conexão');
      store = HorariosQuadraStore(
        horarios,
        QuadraRepositoryFalso(),
        SalvarHorariosUseCase(horarios),
      );
      await store.carregar(1);
      expect(store.carga.value, isA<RequestFailure<void>>());
    });
  });

  group('edição local', () {
    test('ligar um dia novo preenche 08:00 às 22:00', () async {
      await criar([]);
      store.alternarDia(6, aberto: true);
      expect(
          dia(6),
          const FaixaDia(
              diaSemana: 6, aberto: true, abertura: 8, fechamento: 22));
      expect(store.alterado.value, isTrue);
      expect(horarios.chamadas, isEmpty);
    });

    test('fechar e reabrir um dia volta à faixa anterior da edição', () async {
      await criar([faixa(12, 2, 10, 20)]);
      store
        ..definirFechamento(2, 21)
        ..alternarDia(2, aberto: false)
        ..alternarDia(2, aberto: true);
      expect(dia(2).abertura, 10);
      expect(dia(2).fechamento, 21);
    });

    test('fechar um dia com faixa entra em diasParaFechar', () async {
      await criar([faixa(12, 2, 8, 22), faixa(17, 7, 8, 18)]);
      store
        ..alternarDia(1, aberto: false)
        ..alternarDia(7, aberto: false);
      expect(store.diasParaFechar.value, [7]);
      store.alternarDia(7, aberto: true);
      expect(store.diasParaFechar.value, isEmpty);
      expect(store.alterado.value, isFalse);
    });

    test('desfazer a alteração deixa o diff vazio', () async {
      await criar([faixa(12, 2, 8, 22)]);
      store.definirAbertura(2, 9);
      expect(store.operacoes.value, hasLength(1));
      store.definirAbertura(2, 8);
      expect(store.operacoes.value, isEmpty);
      expect(store.podeSalvar.value, isFalse);
    });
  });

  group('copiar a segunda', () {
    test('aplica a faixa da segunda a todos os dias e abre os fechados',
        () async {
      await criar([faixa(11, 1, 7, 23)]);
      store.copiarSegunda();

      for (final d in store.dias.value) {
        expect(d.aberto, isTrue, reason: 'dia ${d.diaSemana}');
        expect(d.abertura, 7);
        expect(d.fechamento, 23);
      }
      expect(store.evento.value, isA<HorarioCopiado>());
      expect(horarios.chamadas, isEmpty, reason: 'nada é salvo ao copiar');
    });

    test('fica desabilitado com a segunda fechada', () async {
      await criar([faixa(12, 2, 8, 22)]);
      expect(store.podeCopiar.value, isFalse);
      store.copiarSegunda();
      expect(store.dias.value.where((d) => d.aberto), hasLength(1));
    });
  });

  group('salvar', () {
    test('fechamento antes da abertura marca o dia e não envia nada', () async {
      await criar([]);
      store
        ..alternarDia(1, aberto: true)
        ..definirAbertura(1, 22)
        ..definirFechamento(1, 8);

      await store.salvar();

      expect(store.errosDia.value[1], 'horarios.erro_fechamento');
      expect(horarios.chamadas, isEmpty);
    });

    test('três operações em um salvamento, na ordem', () async {
      await criar([faixa(12, 2, 8, 22), faixa(17, 7, 8, 18)]);
      store
        ..alternarDia(1, aberto: true)
        ..definirAbertura(2, 9)
        ..alternarDia(7, aberto: false);
      expect(store.diasParaFechar.value, [7]);

      await store.salvar();

      expect(horarios.chamadas, ['POST 1', 'PUT 2', 'DELETE 7']);
      expect(store.evento.value, isA<HorariosSalvos>());
      expect(store.alterado.value, isFalse);
      expect(store.salvando.value, isFalse);
      expect(store.salvouAlgo, isTrue);
    });

    test('409 HORARIO_COM_RESERVAS volta só aquele dia e pede o diálogo',
        () async {
      await criar([faixa(12, 2, 8, 22), faixa(13, 3, 8, 22)]);
      horarios.falhas[2] = const ApiFailure(
        status: 409,
        codigo: 'HORARIO_COM_RESERVAS',
        message: 'há reservas',
      );
      store
        ..definirFechamento(2, 18)
        ..definirAbertura(3, 9);

      await store.salvar();

      expect(horarios.chamadas, ['PUT 2', 'PUT 3']);
      expect(dia(2).fechamento, 22, reason: 'terça volta ao servidor');
      expect(dia(3).abertura, 9, reason: 'quarta fica salva');
      expect(store.alterado.value, isFalse);
      expect(store.errosDia.value[2], 'há reservas');
      final evento = store.evento.value;
      expect(evento, isA<SalvamentoIncompleto>());
      evento as SalvamentoIncompleto;
      expect(evento.conflitoComReservas, isTrue);
      expect(evento.pendencias, isFalse);
    });

    test('409 DIA_JA_CADASTRADO recarrega o servidor e marca o dia', () async {
      await criar([]);
      // Outro aparelho cadastrou a segunda depois da carga.
      horarios
        ..faixas = [faixa(50, 1, 6, 12)]
        ..falhas[1] = const ApiFailure(
          status: 409,
          codigo: 'DIA_JA_CADASTRADO',
          message: 'dia já cadastrado',
        );
      store.alternarDia(1, aberto: true);

      await store.salvar();

      expect(
          dia(1),
          const FaixaDia(
              diaSemana: 1, aberto: true, abertura: 6, fechamento: 12));
      expect(store.errosDia.value[1], 'dia já cadastrado');
      expect(store.alterado.value, isFalse);
      expect((store.evento.value! as SalvamentoIncompleto).pendencias, isTrue);
    });

    test('falha de rede mantém os dias não enviados como pendentes', () async {
      await criar([faixa(12, 2, 8, 22), faixa(17, 7, 8, 18)]);
      horarios.falhas[2] = const NetworkFailure('sem conexão');
      store
        ..alternarDia(1, aberto: true)
        ..definirAbertura(2, 9)
        ..alternarDia(7, aberto: false);

      await store.salvar();

      expect(horarios.chamadas, ['POST 1', 'PUT 2']);
      expect(store.operacoes.value.map((o) => o.diaSemana), [2, 7]);
      expect(store.alterado.value, isTrue);
      final evento = store.evento.value! as SalvamentoIncompleto;
      expect(evento.pendencias, isTrue);
      expect(evento.conflitoComReservas, isFalse);
      expect(store.salvouAlgo, isTrue);
    });
  });
}
