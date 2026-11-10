import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:so_mais_uma/src/features/reservas/presentation/grade/faixa_datas.dart';
import 'package:so_mais_uma/src/features/reservas/presentation/grade/grade_slots_store.dart';
import 'package:so_mais_uma/src/shared/domain/brasilia.dart';
import 'package:so_mais_uma/src/shared/domain/entities/slot.dart';
import 'package:so_mais_uma/src/shared/domain/enums.dart';
import 'package:so_mais_uma/src/shared/domain/repositories/repositorios.dart';
import 'package:so_mais_uma/src/utils/async_state.dart';
import 'package:so_mais_uma/src/utils/failure.dart';
import 'package:so_mais_uma/src/utils/typedefs.dart';

typedef _Resposta = Either<Failure, List<Slot>>;

class _RelogioFixo extends Relogio {
  _RelogioFixo(this.instante);
  DateTime instante;
  @override
  DateTime agora() => instante;
}

class _SlotsFalsos implements SlotRepository {
  final chamadas = <DateTime>[];
  final pendentes = <Completer<_Resposta>>[];

  /// Quando definido, responde na hora; senão, a resposta fica pendente.
  _Resposta Function(DateTime data)? automatico;

  @override
  FutureEither<List<Slot>> slots(int quadraId, DateTime data) {
    chamadas.add(data);
    final responder = automatico;
    if (responder != null) return Future.value(responder(data));
    final c = Completer<_Resposta>();
    pendentes.add(c);
    return c.future;
  }
}

/// Slot de [hora] (hora de Brasília) da data de parede [dia].
Slot _slot(DateTime dia, int hora, StatusSlot status, {double valor = 90}) {
  final inicio =
      Brasilia.instante(DateTime.utc(dia.year, dia.month, dia.day, hora));
  return Slot(
    inicio: inicio,
    fim: inicio.add(const Duration(hours: 1)),
    status: status,
    valor: valor,
  );
}

Future<void> _drenar() async {
  for (var i = 0; i < 50; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  // Sábado, 10/10/2026, 17:30 em Brasília.
  final agora = DateTime.utc(2026, 10, 10, 20, 30);
  final hoje = DateTime.utc(2026, 10, 10);
  final amanha = DateTime.utc(2026, 10, 11);
  final depois = DateTime.utc(2026, 10, 12);

  List<Slot> gradeDeHoje() => [
        _slot(hoje, 15, StatusSlot.fechado),
        _slot(hoje, 16, StatusSlot.passado),
        _slot(hoje, 17, StatusSlot.passado),
        _slot(hoje, 18, StatusSlot.ocupado),
        _slot(hoje, 19, StatusSlot.livre),
        _slot(hoje, 20, StatusSlot.livre),
      ];

  late _SlotsFalsos repo;
  late GradeSlotsStore store;

  setUp(() {
    repo = _SlotsFalsos();
    store = GradeSlotsStore(repo, _RelogioFixo(agora));
  });

  tearDown(() => store.dispose());

  test('iniciar monta a faixa e carrega hoje, sem os slots FECHADO', () async {
    repo.automatico = (_) => Right(gradeDeHoje());
    final futuro = store.iniciar(1);
    expect(store.grade.value, isA<RequestLoading<List<Slot>>>());
    await futuro;

    expect(store.datas.value, hasLength(15));
    expect(store.dataSelecionada.value?.data, hoje);
    expect(store.dataSelecionada.value?.tipo, TipoDia.hoje);
    expect(repo.chamadas, [hoje]);
    expect(store.visiveis.value, hasLength(5));
    expect(
      store.visiveis.value.any((s) => s.status == StatusSlot.fechado),
      isFalse,
    );
    expect(store.semLivre.value, isFalse);
    expect(store.proxima.value, isA<ProximaNaoAplicavel>());
  });

  test('tocar slot LIVRE seleciona; de novo desfaz; outros estados não',
      () async {
    repo.automatico = (_) => Right(gradeDeHoje());
    await store.iniciar(1);
    final slots = store.visiveis.value;
    final passado = slots.firstWhere((s) => s.status == StatusSlot.passado);
    final ocupado = slots.firstWhere((s) => s.status == StatusSlot.ocupado);
    final livres = slots.where((s) => s.livre).toList();

    store.tocarSlot(ocupado);
    expect(store.selecionado.value, isNull);
    store.tocarSlot(passado);
    expect(store.selecionado.value, isNull);

    store.tocarSlot(livres[0]);
    expect(store.selecionado.value, livres[0]);
    store.tocarSlot(livres[1]);
    expect(store.selecionado.value, livres[1], reason: 'apenas um por vez');
    store.tocarSlot(livres[1]);
    expect(store.selecionado.value, isNull);
  });

  test('trocar de data desfaz a seleção e descarta a resposta anterior',
      () async {
    final futuroHoje = store.iniciar(1);
    final datas = store.datas.value;

    final futuroAmanha = store.selecionarData(datas[1]);
    expect(repo.chamadas, [hoje, amanha]);

    // A resposta de amanhã chega antes; a de hoje, atrasada, é ignorada.
    repo.pendentes[1].complete(Right([_slot(amanha, 19, StatusSlot.livre)]));
    await futuroAmanha;
    repo.pendentes[0].complete(Right(gradeDeHoje()));
    await futuroHoje;

    expect(store.dataSelecionada.value, datas[1]);
    expect(store.visiveis.value.single.inicio,
        _slot(amanha, 19, StatusSlot.livre).inicio);

    store.tocarSlot(store.visiveis.value.single);
    expect(store.selecionado.value, isNotNull);
    repo.automatico = (_) => Right(gradeDeHoje());
    await store.selecionarData(datas[0]);
    expect(store.selecionado.value, isNull);
  });

  test('recarregar depois da ConfirmarReserva limpa a seleção e busca de novo',
      () async {
    repo.automatico = (_) => Right(gradeDeHoje());
    await store.iniciar(1);
    store.tocarSlot(store.visiveis.value.firstWhere((s) => s.livre));
    expect(store.selecionado.value, isNotNull);

    final slot19Ocupado = gradeDeHoje()
        .map((s) => Brasilia.parede(s.inicio).hour == 19
            ? _slot(hoje, 19, StatusSlot.ocupado)
            : s)
        .toList();
    repo.automatico = (_) => Right(slot19Ocupado);
    await store.recarregar();

    expect(repo.chamadas, [hoje, hoje]);
    expect(store.selecionado.value, isNull);
    expect(
      store.visiveis.value
          .firstWhere((s) => Brasilia.parede(s.inicio).hour == 19)
          .status,
      StatusSlot.ocupado,
    );
  });

  test('recarregar mantendo a seleção só se o slot seguir livre', () async {
    repo.automatico = (_) => Right(gradeDeHoje());
    await store.iniciar(1);
    final as20 = store.visiveis.value
        .firstWhere((s) => Brasilia.parede(s.inicio).hour == 20);
    store.tocarSlot(as20);

    await store.recarregar(limparSelecao: false);
    expect(store.selecionado.value, as20);

    repo.automatico = (_) => Right([
          _slot(hoje, 19, StatusSlot.livre),
          _slot(hoje, 20, StatusSlot.ocupado),
        ]);
    await store.recarregar(limparSelecao: false);
    expect(store.selecionado.value, isNull);
  });

  test('data sem slot livre procura a próxima data com horário', () async {
    repo.automatico = (data) {
      if (data == depois) return Right([_slot(depois, 9, StatusSlot.livre)]);
      return Right([_slot(data, 9, StatusSlot.ocupado)]);
    };
    await store.iniciar(1);
    expect(store.semLivre.value, isTrue);
    await _drenar();

    final proxima = store.proxima.value;
    expect(proxima, isA<ProximaEncontrada>());
    expect((proxima as ProximaEncontrada).data.data, depois);
    expect(repo.chamadas, [hoje, amanha, depois]);

    await store.selecionarData(proxima.data);
    expect(store.semLivre.value, isFalse);
    expect(store.proxima.value, isA<ProximaNaoAplicavel>());
  });

  test('sem nenhuma data livre na janela: ProximaNenhuma', () async {
    repo.automatico = (data) => Right([_slot(data, 9, StatusSlot.ocupado)]);
    await store.iniciar(1);
    await _drenar();
    expect(store.proxima.value, isA<ProximaNenhuma>());
    expect(repo.chamadas, hasLength(15));
    expect(repo.chamadas.last, DateTime.utc(2026, 10, 24));
  });

  test('dia fechado (todos FECHADO) também busca a próxima', () async {
    repo.automatico = (data) => data == hoje
        ? Right([_slot(hoje, 9, StatusSlot.fechado)])
        : Right([_slot(data, 9, StatusSlot.livre)]);
    await store.iniciar(1);
    expect(store.visiveis.value, isEmpty);
    expect(store.semLivre.value, isTrue);
    await _drenar();
    expect((store.proxima.value as ProximaEncontrada).data.data, amanha);
  });

  test('sem conexão: falha na área da grade e tentar de novo', () async {
    repo.automatico = (_) => const Left(NetworkFailure('sem rede'));
    await store.iniciar(1);
    final grade = store.grade.value;
    expect(grade, isA<RequestFailure<List<Slot>>>());
    expect(
        (grade as RequestFailure<List<Slot>>).failure, isA<NetworkFailure>());
    expect(store.aviso.value, isNull);

    repo.automatico = (_) => Right(gradeDeHoje());
    await store.tentarNovamente();
    expect(store.grade.value, isA<RequestSuccess<List<Slot>>>());
  });

  test('422 DATA_FORA_DA_JANELA vira aviso', () async {
    repo.automatico = (_) => const Left(ApiFailure(
          status: 422,
          codigo: 'REGRA_NEGOCIO',
          subcodigo: 'DATA_FORA_DA_JANELA',
          message: 'Só é possível reservar de hoje até 14 dias à frente.',
        ));
    await store.iniciar(1);
    expect(store.aviso.value?.mensagem, contains('14 dias'));
    store.consumirAviso();
    expect(store.aviso.value, isNull);
  });

  test('resposta depois do dispose é descartada', () async {
    final outroRepo = _SlotsFalsos();
    final outro = GradeSlotsStore(outroRepo, _RelogioFixo(agora));
    final futuro = outro.iniciar(1);
    outro.dispose();
    outroRepo.pendentes.single.complete(Right(gradeDeHoje()));
    await expectLater(futuro, completes);
  });
}
