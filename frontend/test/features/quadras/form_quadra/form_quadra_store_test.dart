import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:so_mais_uma/src/features/quadras/presentation/form_quadra/form_quadra_campos.dart';
import 'package:so_mais_uma/src/features/quadras/presentation/form_quadra/form_quadra_formatadores.dart';
import 'package:so_mais_uma/src/features/quadras/presentation/form_quadra/form_quadra_store.dart';
import 'package:so_mais_uma/src/shared/data/json/mapeadores.dart';
import 'package:so_mais_uma/src/shared/domain/entities/endereco_cep.dart';
import 'package:so_mais_uma/src/shared/domain/entities/quadra.dart';
import 'package:so_mais_uma/src/shared/domain/enums.dart';
import 'package:so_mais_uma/src/shared/domain/repositories/repositorios.dart';
import 'package:so_mais_uma/src/utils/async_state.dart';
import 'package:so_mais_uma/src/utils/failure.dart';
import 'package:so_mais_uma/src/utils/typedefs.dart';

const arena = Quadra(
  id: 7,
  nome: 'Arena Prime Society',
  tipoEsporte: TipoEsporte.futebolSociety,
  precoHora: 80,
  cep: '05425070',
  logradouro: 'Av. das Nações Unidas',
  numero: '1420',
  bairro: 'Pinheiros',
  cidade: 'São Paulo',
  uf: 'SP',
  latitude: -23.5682,
  longitude: -46.6991,
);

class QuadraRepositoryFalso implements QuadraRepository {
  final criadas = <QuadraDados>[];
  final atualizadas = <(int, QuadraDados)>[];
  Failure? falhaSalvar;
  Failure? falhaDetalhar;

  Quadra _de(int id, QuadraDados d) => Quadra(
        id: id,
        nome: d.nome,
        tipoEsporte: d.tipoEsporte,
        precoHora: d.precoHora,
        cep: d.cep,
        logradouro: d.logradouro,
        numero: d.numero,
        bairro: d.bairro,
        cidade: d.cidade,
        uf: d.uf,
      );

  @override
  FutureEither<Quadra> detalhar(int id) async {
    final f = falhaDetalhar;
    return f == null ? const Right(arena) : Left(f);
  }

  @override
  FutureEither<Quadra> criar(QuadraDados dados) async {
    criadas.add(dados);
    final f = falhaSalvar;
    return f == null ? Right(_de(99, dados)) : Left(f);
  }

  @override
  FutureEither<Quadra> atualizar(int id, QuadraDados dados) async {
    atualizadas.add((id, dados));
    final f = falhaSalvar;
    return f == null ? Right(_de(id, dados)) : Left(f);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class CepRepositoryFalso implements CepRepository {
  final buscados = <String>[];
  Either<Failure, EnderecoCep> resposta = const Right(EnderecoCep(
    cep: '01001000',
    logradouro: 'Praça da Sé',
    bairro: 'Sé',
    cidade: 'São Paulo',
    uf: 'SP',
    latitude: -23.5503,
    longitude: -46.6339,
    fonte: FonteCep.brasilApi,
  ));

  @override
  FutureEither<EnderecoCep> buscar(String cep) async {
    buscados.add(cep);
    return resposta;
  }
}

/// Campos válidos de uma quadra nova (sem bairro nem coordenadas).
const validos = FormQuadraCampos(
  nome: 'Arena Prime Society',
  esporte: TipoEsporte.futebolSociety,
  preco: '95,00',
  cep: '05425-070',
  logradouro: 'Av. das Nações Unidas',
  numero: '1420',
  cidade: 'São Paulo',
  uf: 'SP',
);

void main() {
  setUpAll(() => EasyLocalization.logger.enableBuildModes = []);

  late QuadraRepositoryFalso quadras;
  late CepRepositoryFalso cep;
  late FormQuadraStore store;

  setUp(() {
    quadras = QuadraRepositoryFalso();
    cep = CepRepositoryFalso();
    store = FormQuadraStore(quadras, cep);
  });

  tearDown(() => store.dispose());

  /// Preenche a nova quadra campo a campo, como a digitação faria. O CEP vem
  /// primeiro (dispara a busca) e os demais campos sobrescrevem o endereço.
  Future<void> preencher(FormQuadraCampos c) async {
    await store.carregar(null);
    store.alterar(CampoQuadra.cep, c.cep);
    await pumpEventQueue();
    store.selecionarEsporte(c.esporte);
    for (final campo in CampoQuadra.values) {
      if (campo == CampoQuadra.esporte || campo == CampoQuadra.cep) continue;
      store.alterar(campo, c.texto(campo));
    }
  }

  group('validarQuadra', () {
    test('formulário vazio marca os obrigatórios, sem Bairro', () {
      final erros = validarQuadra(const FormQuadraCampos());
      expect(erros.keys, [
        CampoQuadra.nome,
        CampoQuadra.esporte,
        CampoQuadra.preco,
        CampoQuadra.cep,
        CampoQuadra.logradouro,
        CampoQuadra.numero,
        CampoQuadra.cidade,
        CampoQuadra.uf,
      ]);
      expect(erros[CampoQuadra.nome], 'comum.campo_obrigatorio');
    });

    test('campos válidos passam', () {
      expect(validarQuadra(validos), isEmpty);
    });

    test('preço 0,00 é recusado', () {
      final erros = validarQuadra(validos.comTexto(CampoQuadra.preco, '0,00'));
      expect(erros[CampoQuadra.preco], 'quadras.form.erro_preco_zero');
    });

    test('preço com mais de 8 inteiros é recusado', () {
      final erros = validarQuadra(
        validos.comTexto(CampoQuadra.preco, '123.456.789,00'),
      );
      expect(erros[CampoQuadra.preco], 'quadras.form.erro_preco_maximo');
    });

    test('limites de tamanho do QuadraRequest', () {
      final erros = validarQuadra(validos
          .comTexto(CampoQuadra.nome, 'a' * 101)
          .comTexto(CampoQuadra.descricao, 'a' * 501)
          .comTexto(CampoQuadra.numero, '1' * 11)
          .comTexto(CampoQuadra.bairro, 'b' * 81)
          .comTexto(CampoQuadra.fotoUrl, 'h' * 301));
      expect(erros.keys, [
        CampoQuadra.nome,
        CampoQuadra.descricao,
        CampoQuadra.numero,
        CampoQuadra.bairro,
        CampoQuadra.fotoUrl,
      ]);
      expect(erros[CampoQuadra.nome], 'quadras.form.erro_maximo');
    });

    test('CEP incompleto e UF inválida', () {
      final erros = validarQuadra(validos
          .comTexto(CampoQuadra.cep, '05425')
          .comTexto(CampoQuadra.uf, 'S1'));
      expect(erros[CampoQuadra.cep], 'quadras.form.erro_cep');
      expect(erros[CampoQuadra.uf], 'quadras.form.erro_uf');
    });

    test('coordenadas só valem juntas e dentro dos limites', () {
      expect(
        validarQuadra(validos.comTexto(CampoQuadra.latitude, '-23.5'))[
            CampoQuadra.longitude],
        'quadras.form.erro_coordenadas',
      );
      final fora = validarQuadra(validos
          .comTexto(CampoQuadra.latitude, '-91')
          .comTexto(CampoQuadra.longitude, '181'));
      expect(fora[CampoQuadra.latitude], 'quadras.form.erro_latitude');
      expect(fora[CampoQuadra.longitude], 'quadras.form.erro_longitude');
      expect(
        validarQuadra(validos
            .comTexto(CampoQuadra.latitude, '-23,55')
            .comTexto(CampoQuadra.longitude, '-46,63')),
        isEmpty,
      );
    });
  });

  test('montarQuadraDados converte preço, CEP e UF para a API', () {
    final dados = montarQuadraDados(validos
        .comTexto(CampoQuadra.uf, 'sp')
        .comTexto(CampoQuadra.preco, '1.234,50'));
    expect(dados.precoHora, 1234.5);
    expect(dados.cep, '05425070');
    expect(dados.uf, 'SP');
    expect(dados.bairro, isNull);
    expect(Mapeadores.quadraDados(dados)['precoHora'], '1234.50');
  });

  group('formatadores', () {
    TextEditingValue digitar(TextInputFormatter f, String texto) =>
        f.formatEditUpdate(
            TextEditingValue.empty, TextEditingValue(text: texto));

    test('máscara de dinheiro por centavos', () {
      const f = MoedaInputFormatter();
      expect(digitar(f, '9500').text, '95,00');
      expect(digitar(f, '0').text, '0,00');
      expect(digitar(f, '123456').text, '1.234,56');
      expect(digitar(f, '').text, '');
    });

    test('máscara de CEP', () {
      const f = CepInputFormatter();
      expect(digitar(f, '01001000').text, '01001-000');
      expect(digitar(f, '0100').text, '0100');
      expect(digitar(f, '010010001').text, '01001-000');
    });
  });

  group('salvar', () {
    test('preço 0,00 mostra o erro, foca o campo e não envia', () async {
      await preencher(validos.comTexto(CampoQuadra.preco, '0,00'));

      await store.salvar();

      expect(
          store.erros.value[CampoQuadra.preco], 'quadras.form.erro_preco_zero');
      expect(store.evento.value, isA<FocarCampo>());
      expect((store.evento.value! as FocarCampo).campo, CampoQuadra.preco);
      expect(quadras.criadas, isEmpty);
    });

    test('nova quadra sem bairro é criada', () async {
      await preencher(validos);

      await store.salvar();

      expect(quadras.criadas, hasLength(1));
      expect(quadras.criadas.single.bairro, isNull);
      expect(quadras.criadas.single.precoHora, 95);
      expect(store.erros.value, isEmpty);
      expect(store.evento.value, isA<QuadraSalva>());
      expect(store.podeSair.value, isTrue);
    });

    test('400 do servidor marca os campos de campos[]', () async {
      await preencher(validos);
      quadras.falhaSalvar = const ApiFailure(
        status: 400,
        codigo: 'VALIDACAO',
        campos: {
          'precoHora': 'deve ser maior que zero',
          'coordenadas': 'latitude e longitude devem ser informadas juntas',
        },
        message: 'Confira os dados informados.',
      );

      await store.salvar();

      expect(store.erros.value[CampoQuadra.preco], 'deve ser maior que zero');
      expect(store.erros.value[CampoQuadra.latitude],
          'latitude e longitude devem ser informadas juntas');
      expect((store.evento.value! as FocarCampo).campo, CampoQuadra.preco);
      expect(store.salvando.value, isFalse);
    });

    test('403 avisa e volta', () async {
      await preencher(validos);
      quadras.falhaSalvar = const ApiFailure(status: 403, message: 'negado');

      await store.salvar();

      expect(store.evento.value, isA<SemPermissaoFormQuadra>());
    });
  });

  group('CEP', () {
    test('completar 8 dígitos busca e preenche o endereço e as coordenadas',
        () async {
      await store.carregar(null);
      final versao = store.versaoExterna.value;

      store.alterar(CampoQuadra.cep, '01001-000');
      await pumpEventQueue();

      expect(cep.buscados, ['01001000']);
      final c = store.campos.value;
      expect(c.logradouro, 'Praça da Sé');
      expect(c.bairro, 'Sé');
      expect(c.cidade, 'São Paulo');
      expect(c.uf, 'SP');
      expect(c.latitude, '-23.5503');
      expect(c.longitude, '-46.6339');
      expect(store.coordenadasAuto.value, isTrue);
      expect(store.estadoCep.value, isA<CepEncontrado>());
      expect(
          (store.estadoCep.value as CepEncontrado).fonte, FonteCep.brasilApi);
      expect(store.versaoExterna.value, greaterThan(versao));
    });

    test('ViaCEP sem coordenadas deixa latitude e longitude vazias', () async {
      cep.resposta = const Right(EnderecoCep(
        cep: '01001000',
        logradouro: 'Praça da Sé',
        bairro: 'Sé',
        cidade: 'São Paulo',
        uf: 'SP',
        fonte: FonteCep.viaCep,
      ));
      await store.carregar(null);
      store
        ..alterar(CampoQuadra.latitude, '-1')
        ..alterar(CampoQuadra.longitude, '-2')
        ..alterar(CampoQuadra.cep, '01001-000');
      await pumpEventQueue();

      expect(store.campos.value.latitude, isEmpty);
      expect(store.campos.value.longitude, isEmpty);
      expect(store.coordenadasAuto.value, isFalse);
      expect((store.estadoCep.value as CepEncontrado).fonte, FonteCep.viaCep);
    });

    test('404 mostra "CEP não encontrado" no campo', () async {
      cep.resposta = const Left(ApiFailure(status: 404, message: 'x'));
      await store.carregar(null);
      store.alterar(CampoQuadra.cep, '99999-999');
      await pumpEventQueue();

      expect(store.erros.value[CampoQuadra.cep],
          'quadras.form.cep_nao_encontrado');
      expect(store.estadoCep.value, isA<CepOcioso>());
    });

    test('400 mostra "CEP inválido"', () async {
      cep.resposta = const Left(ApiFailure(status: 400, message: 'x'));
      await store.carregar(null);
      store.alterar(CampoQuadra.cep, '00000-000');
      await pumpEventQueue();

      expect(store.erros.value[CampoQuadra.cep], 'quadras.form.cep_invalido');
    });

    test('503 CEP_INDISPONIVEL avisa e o endereço manual salva', () async {
      cep.resposta = const Left(ApiFailure(
        status: 503,
        codigo: 'CEP_INDISPONIVEL',
        message: 'indisponível',
      ));
      await store.carregar(null);
      store.alterar(CampoQuadra.cep, '05425-070');
      await pumpEventQueue();

      expect(store.estadoCep.value, isA<CepIndisponivel>());
      expect((store.estadoCep.value as CepIndisponivel).mensagem,
          'quadras.form.cep_indisponivel');
      expect(store.erros.value[CampoQuadra.cep], isNull);

      await preencher(validos);
      await store.salvar();
      expect(quadras.criadas, hasLength(1));
    });

    test('o mesmo CEP não é buscado de novo automaticamente', () async {
      await store.carregar(null);
      store.alterar(CampoQuadra.cep, '01001-000');
      await pumpEventQueue();
      store
        ..alterar(CampoQuadra.cep, '01001-00')
        ..alterar(CampoQuadra.cep, '01001-000');
      await pumpEventQueue();
      expect(cep.buscados, ['01001000']);

      await store.buscarCep();
      expect(cep.buscados, ['01001000', '01001000']);
    });
  });

  group('edição', () {
    test('carrega os campos da quadra sem marcar alteração', () async {
      await store.carregar(7);

      expect(store.edicao, isTrue);
      expect(store.carga.value, isA<RequestSuccess<void>>());
      final c = store.campos.value;
      expect(c.nome, 'Arena Prime Society');
      expect(c.preco, '80,00');
      expect(c.cep, '05425-070');
      expect(c.latitude, '-23.5682');
      expect(store.alterado.value, isFalse);
      expect(store.podeSair.value, isTrue);
      expect(store.versaoExterna.value, 1);
    });

    test('mudar o preço para 95,00 envia PUT com "95.00"', () async {
      await store.carregar(7);

      store.alterar(CampoQuadra.preco, '95,00');
      expect(store.alterado.value, isTrue);
      expect(store.podeSair.value, isFalse);

      await store.salvar();

      final (id, dados) = quadras.atualizadas.single;
      expect(id, 7);
      expect(Mapeadores.quadraDados(dados)['precoHora'], '95.00');
      expect(quadras.criadas, isEmpty);
      expect(store.evento.value, isA<QuadraSalva>());
      expect(store.podeSair.value, isTrue);
    });

    test('quadra inexistente: falha com naoEncontrado', () async {
      quadras.falhaDetalhar = const ApiFailure(status: 404, message: 'x');
      await store.carregar(7);

      final carga = store.carga.value;
      expect(carga, isA<RequestFailure<void>>());
      expect(
        ((carga as RequestFailure<void>).failure as ApiFailure).naoEncontrado,
        isTrue,
      );
    });
  });
}
