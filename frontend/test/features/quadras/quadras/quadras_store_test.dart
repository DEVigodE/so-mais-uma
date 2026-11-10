import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:so_mais_uma/src/features/quadras/presentation/quadras/filtro_quadras.dart';
import 'package:so_mais_uma/src/features/quadras/presentation/quadras/quadras_store.dart';
import 'package:so_mais_uma/src/shared/domain/entities/quadra.dart';
import 'package:so_mais_uma/src/shared/domain/enums.dart';
import 'package:so_mais_uma/src/shared/domain/repositories/repositorios.dart';
import 'package:so_mais_uma/src/utils/async_state.dart';
import 'package:so_mais_uma/src/utils/failure.dart';
import 'package:so_mais_uma/src/utils/typedefs.dart';

Quadra _quadra(
  int id,
  String nome, {
  TipoEsporte esporte = TipoEsporte.futebolSociety,
  String cidade = 'São Paulo',
  String? bairro,
}) =>
    Quadra(
      id: id,
      nome: nome,
      tipoEsporte: esporte,
      precoHora: 90,
      cep: '01310100',
      logradouro: 'Rua A',
      numero: '1',
      cidade: cidade,
      uf: 'SP',
      bairro: bairro,
    );

final _catalogo = [
  _quadra(1, 'Arena Sul', bairro: 'Jardim São Paulo'),
  _quadra(2, 'Quadra Central',
      esporte: TipoEsporte.futsal, bairro: 'Pinheiros'),
  _quadra(3, 'Beach Club', esporte: TipoEsporte.beachTennis, cidade: 'Santos'),
  _quadra(4, 'Ágora Futsal', esporte: TipoEsporte.futsal, cidade: 'Campinas'),
];

class _QuadrasFalsas implements QuadraRepository {
  final respostas = <Completer<Either<Failure, List<Quadra>>>>[];
  int chamadas = 0;

  Completer<Either<Failure, List<Quadra>>> get ultima => respostas.last;

  @override
  FutureEither<List<Quadra>> listar({TipoEsporte? esporte, String? cidade}) {
    chamadas++;
    final c = Completer<Either<Failure, List<Quadra>>>();
    respostas.add(c);
    return c.future;
  }

  @override
  FutureEither<Quadra> detalhar(int id) => throw UnimplementedError();
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

List<int> _ids(SituacaoQuadras s) =>
    s is QuadrasLista ? s.quadras.map((q) => q.id).toList() : const [];

void main() {
  group('filtrarQuadras', () {
    test('busca por bairro ignora acento e caixa', () {
      final r = filtrarQuadras(_catalogo, busca: 'jardim sao');
      expect(r.map((q) => q.id), [1]);
    });

    test('busca por cidade', () {
      final r = filtrarQuadras(_catalogo, busca: '  SANTOS ');
      expect(r.map((q) => q.id), [3]);
    });

    test('esporte filtra e "Todos" (null) não filtra', () {
      expect(
        filtrarQuadras(_catalogo, esporte: TipoEsporte.futsal).map((q) => q.id),
        unorderedEquals([2, 4]),
      );
      expect(filtrarQuadras(_catalogo), hasLength(4));
    });

    test('busca e esporte combinam com "e"', () {
      final r = filtrarQuadras(
        _catalogo,
        busca: 'pinheiros',
        esporte: TipoEsporte.futsal,
      );
      expect(r.map((q) => q.id), [2]);
      expect(
        filtrarQuadras(
          _catalogo,
          busca: 'pinheiros',
          esporte: TipoEsporte.beachTennis,
        ),
        isEmpty,
      );
    });

    test('resultado em ordem alfabética, sem acento', () {
      final r = filtrarQuadras(_catalogo);
      expect(r.map((q) => q.nome), [
        'Ágora Futsal',
        'Arena Sul',
        'Beach Club',
        'Quadra Central',
      ]);
    });

    test('normalizarBusca', () {
      expect(normalizarBusca('  São   Paulo '), 'sao paulo');
      expect(normalizarBusca('Ação Çé'), 'acao ce');
    });
  });

  group('QuadrasStore', () {
    late _QuadrasFalsas repo;
    late QuadrasStore store;

    setUp(() {
      repo = _QuadrasFalsas();
      store = QuadrasStore(repo);
    });

    tearDown(() => store.dispose());

    test('primeira carga: carregando e depois a lista', () async {
      final futuro = store.carregar();
      expect(store.situacao.value, isA<QuadrasCarregando>());
      repo.ultima.complete(Right(_catalogo));
      await futuro;
      expect(_ids(store.situacao.value), [4, 1, 3, 2]);
    });

    test('catálogo vazio', () async {
      final futuro = store.carregar();
      repo.ultima.complete(const Right([]));
      await futuro;
      expect(store.situacao.value, isA<QuadrasCatalogoVazio>());
    });

    test('falha sem lista vira erro; tentar de novo recarrega', () async {
      var futuro = store.carregar();
      repo.ultima.complete(const Left(NetworkFailure('sem rede')));
      await futuro;
      final s = store.situacao.value;
      expect(s, isA<QuadrasErro>());
      expect((s as QuadrasErro).failure, isA<NetworkFailure>());

      futuro = store.carregar();
      expect(store.situacao.value, isA<QuadrasCarregando>());
      repo.ultima.complete(Right(_catalogo));
      await futuro;
      expect(store.situacao.value, isA<QuadrasLista>());
    });

    test('falha com lista mantém a lista e emite aviso', () async {
      var futuro = store.carregar();
      repo.ultima.complete(Right(_catalogo));
      await futuro;

      futuro = store.atualizar();
      expect(store.atualizando.value, isTrue);
      expect(store.situacao.value, isA<QuadrasLista>());
      repo.ultima.complete(const Left(NetworkFailure('sem rede')));
      await futuro;

      expect(store.atualizando.value, isFalse);
      expect(store.situacao.value, isA<QuadrasLista>());
      expect(store.aviso.value?.mensagem, 'sem rede');
      store.consumirAviso();
      expect(store.aviso.value, isNull);
    });

    test('atualizar remove a quadra desativada', () async {
      var futuro = store.carregar();
      repo.ultima.complete(Right(_catalogo));
      await futuro;
      futuro = store.atualizar();
      repo.ultima.complete(Right(_catalogo.where((q) => q.id != 1).toList()));
      await futuro;
      expect(_ids(store.situacao.value), isNot(contains(1)));
    });

    test('filtro por esporte e por texto, e limpar filtros', () async {
      final futuro = store.carregar();
      repo.ultima.complete(Right(_catalogo));
      await futuro;

      store.selecionarEsporte(TipoEsporte.futsal);
      expect(store.esporte.value, TipoEsporte.futsal);
      expect(_ids(store.situacao.value), [4, 2]);
      expect(store.temFiltro.value, isTrue);

      store.buscar('pinheiros');
      expect(_ids(store.situacao.value), [2]);

      store.buscar('cidade inexistente');
      expect(store.situacao.value, isA<QuadrasSemResultado>());

      store.limparFiltros();
      expect(store.temFiltro.value, isFalse);
      expect(store.esporte.value, isNull);
      expect(_ids(store.situacao.value), [4, 1, 3, 2]);
    });

    test('resposta antiga é ignorada quando outra carga começou', () async {
      final primeira = store.carregar();
      final segunda = store.carregar();
      repo.respostas[1].complete(Right([_catalogo.first]));
      await segunda;
      repo.respostas[0].complete(Right(_catalogo));
      await primeira;
      expect(_ids(store.situacao.value), [1]);
    });

    test('resposta depois do dispose é descartada', () async {
      final outroRepo = _QuadrasFalsas();
      final outro = QuadrasStore(outroRepo);
      final futuro = outro.carregar();
      outro.dispose();
      outroRepo.ultima.complete(Right(_catalogo));
      await expectLater(futuro, completes);
    });

    test('estado inicial é carregando', () {
      expect(store.catalogo.value, isA<RequestInitial<List<Quadra>>>());
      expect(store.situacao.value, isA<QuadrasCarregando>());
    });
  });
}
