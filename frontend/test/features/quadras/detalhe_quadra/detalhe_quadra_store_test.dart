import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:so_mais_uma/src/features/quadras/presentation/detalhe_quadra/detalhe_quadra_store.dart';
import 'package:so_mais_uma/src/shared/domain/entities/horario_funcionamento.dart';
import 'package:so_mais_uma/src/shared/domain/entities/quadra.dart';
import 'package:so_mais_uma/src/shared/domain/enums.dart';
import 'package:so_mais_uma/src/shared/domain/repositories/repositorios.dart';
import 'package:so_mais_uma/src/utils/async_state.dart';
import 'package:so_mais_uma/src/utils/failure.dart';
import 'package:so_mais_uma/src/utils/typedefs.dart';

const _quadra = Quadra(
  id: 7,
  nome: 'Arena Sul',
  tipoEsporte: TipoEsporte.futsal,
  precoHora: 80,
  cep: '01310100',
  logradouro: 'Rua A',
  numero: '10',
  cidade: 'São Paulo',
  uf: 'SP',
  horarios: [
    HorarioFuncionamento(
        diaSemana: 6, horaAbertura: '08:00', horaFechamento: '22:00'),
    HorarioFuncionamento(
        diaSemana: 7, horaAbertura: '08:00', horaFechamento: '22:00'),
  ],
);

class _QuadrasFalsas implements QuadraRepository {
  Completer<Either<Failure, Quadra>> resposta = Completer();
  final ids = <int>[];

  @override
  FutureEither<Quadra> detalhar(int id) {
    ids.add(id);
    resposta = Completer();
    return resposta.future;
  }

  @override
  FutureEither<List<Quadra>> listar({TipoEsporte? esporte, String? cidade}) =>
      throw UnimplementedError();
  @override
  FutureEither<List<Quadra>> minhas() => throw UnimplementedError();
  @override
  FutureEither<Quadra> criar(QuadraDados dados) => throw UnimplementedError();
  @override
  FutureEither<Quadra> atualizar(int id, QuadraDados dados) =>
      throw UnimplementedError();
  @override
  FutureEither<void> desativar(int id) => throw UnimplementedError();
}

void main() {
  late _QuadrasFalsas repo;
  late DetalheQuadraStore store;

  setUp(() {
    repo = _QuadrasFalsas();
    store = DetalheQuadraStore(repo);
  });

  tearDown(() => store.dispose());

  test('carrega a quadra e agrupa os horários', () async {
    final futuro = store.carregar(7);
    expect(store.estado.value, isA<RequestLoading<Quadra>>());
    repo.resposta.complete(const Right(_quadra));
    await futuro;

    expect(repo.ids, [7]);
    expect((store.estado.value as RequestSuccess<Quadra>).data, _quadra);
    expect(store.gruposFuncionamento.value, hasLength(2));
    expect(store.gruposFuncionamento.value.last.primeiroDia, 6);
    expect(store.naoEncontrada.value, isFalse);
  });

  test('404 vira "quadra não encontrada"', () async {
    final futuro = store.carregar(7);
    repo.resposta.complete(
      const Left(ApiFailure(status: 404, codigo: 'NAO_ENCONTRADO')),
    );
    await futuro;
    expect(store.estado.value, isA<RequestFailure<Quadra>>());
    expect(store.naoEncontrada.value, isTrue);
    expect(store.gruposFuncionamento.value, isEmpty);
  });

  test('falha de rede não é "não encontrada" e permite tentar de novo',
      () async {
    var futuro = store.carregar(7);
    repo.resposta.complete(const Left(NetworkFailure('sem rede')));
    await futuro;
    expect(store.naoEncontrada.value, isFalse);

    futuro = store.tentarNovamente();
    repo.resposta.complete(const Right(_quadra));
    await futuro;
    expect(repo.ids, [7, 7]);
    expect(store.estado.value, isA<RequestSuccess<Quadra>>());
  });
}
