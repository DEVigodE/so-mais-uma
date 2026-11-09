import 'package:easy_localization/easy_localization.dart';
import 'package:equatable/equatable.dart';

import '../../../../shared/domain/entities/endereco_cep.dart';
import '../../../../shared/domain/entities/quadra.dart';
import '../../../../shared/domain/enums.dart';
import '../../../../shared/formatters/formatadores.dart';

/// Campos da FormQuadra, na ordem da tela (usada para focar o primeiro
/// inválido).
enum CampoQuadra {
  nome,
  esporte,
  preco,
  descricao,
  cep,
  logradouro,
  numero,
  bairro,
  cidade,
  uf,
  latitude,
  longitude,
  fotoUrl;

  /// Campo da tela a partir do nome no `QuadraRequest` (`campos[]` do 400).
  /// `coordenadas` vem do `@AssertTrue isCoordenadas` do backend.
  static CampoQuadra? daApi(String campo) => switch (campo) {
        'nome' => nome,
        'tipoEsporte' => esporte,
        'precoHora' => preco,
        'descricao' => descricao,
        'cep' => cep,
        'logradouro' => logradouro,
        'numero' => numero,
        'bairro' => bairro,
        'cidade' => cidade,
        'uf' => uf,
        'latitude' || 'coordenadas' => latitude,
        'longitude' => longitude,
        'fotoUrl' => fotoUrl,
        _ => null,
      };
}

/// Limites do `QuadraRequest` (espelham as colunas do banco).
abstract final class LimitesQuadra {
  static const int nome = 100;
  static const int descricao = 500;
  static const int logradouro = 150;
  static const int numero = 10;
  static const int bairro = 80;
  static const int cidade = 80;
  static const int fotoUrl = 300;

  /// `@Digits(integer = 8, fraction = 2)`.
  static const int precoDigitosInteiros = 8;
  static const int precoDigitosDecimais = 2;
}

/// Valores digitados na FormQuadra (texto como aparece nos campos).
class FormQuadraCampos extends Equatable {
  const FormQuadraCampos({
    this.nome = '',
    this.esporte,
    this.preco = '',
    this.descricao = '',
    this.cep = '',
    this.logradouro = '',
    this.numero = '',
    this.bairro = '',
    this.cidade = '',
    this.uf = '',
    this.latitude = '',
    this.longitude = '',
    this.fotoUrl = '',
  });

  /// Campos preenchidos com uma quadra existente (edição).
  factory FormQuadraCampos.daQuadra(Quadra q) => FormQuadraCampos(
        nome: q.nome,
        esporte: TipoEsporte.selecionaveis.contains(q.tipoEsporte)
            ? q.tipoEsporte
            : null,
        preco: formatarPrecoCampo(q.precoHora),
        descricao: q.descricao ?? '',
        cep: Formatadores.cep(q.cep),
        logradouro: q.logradouro,
        numero: q.numero,
        bairro: q.bairro ?? '',
        cidade: q.cidade,
        uf: q.uf,
        latitude: q.latitude?.toString() ?? '',
        longitude: q.longitude?.toString() ?? '',
        fotoUrl: q.fotoUrl ?? '',
      );

  final String nome;
  final TipoEsporte? esporte;

  /// "95,00" (máscara de centavos).
  final String preco;
  final String descricao;

  /// "01001-000".
  final String cep;
  final String logradouro;
  final String numero;
  final String bairro;
  final String cidade;
  final String uf;
  final String latitude;
  final String longitude;
  final String fotoUrl;

  /// Texto de um campo de texto (o esporte não é texto e devolve vazio).
  String texto(CampoQuadra campo) => switch (campo) {
        CampoQuadra.nome => nome,
        CampoQuadra.esporte => '',
        CampoQuadra.preco => preco,
        CampoQuadra.descricao => descricao,
        CampoQuadra.cep => cep,
        CampoQuadra.logradouro => logradouro,
        CampoQuadra.numero => numero,
        CampoQuadra.bairro => bairro,
        CampoQuadra.cidade => cidade,
        CampoQuadra.uf => uf,
        CampoQuadra.latitude => latitude,
        CampoQuadra.longitude => longitude,
        CampoQuadra.fotoUrl => fotoUrl,
      };

  FormQuadraCampos comTexto(CampoQuadra campo, String valor) =>
      FormQuadraCampos(
        nome: campo == CampoQuadra.nome ? valor : nome,
        esporte: esporte,
        preco: campo == CampoQuadra.preco ? valor : preco,
        descricao: campo == CampoQuadra.descricao ? valor : descricao,
        cep: campo == CampoQuadra.cep ? valor : cep,
        logradouro: campo == CampoQuadra.logradouro ? valor : logradouro,
        numero: campo == CampoQuadra.numero ? valor : numero,
        bairro: campo == CampoQuadra.bairro ? valor : bairro,
        cidade: campo == CampoQuadra.cidade ? valor : cidade,
        uf: campo == CampoQuadra.uf ? valor : uf,
        latitude: campo == CampoQuadra.latitude ? valor : latitude,
        longitude: campo == CampoQuadra.longitude ? valor : longitude,
        fotoUrl: campo == CampoQuadra.fotoUrl ? valor : fotoUrl,
      );

  FormQuadraCampos comEsporte(TipoEsporte? valor) => FormQuadraCampos(
        nome: nome,
        esporte: valor,
        preco: preco,
        descricao: descricao,
        cep: cep,
        logradouro: logradouro,
        numero: numero,
        bairro: bairro,
        cidade: cidade,
        uf: uf,
        latitude: latitude,
        longitude: longitude,
        fotoUrl: fotoUrl,
      );

  /// Aplica o endereço do `GET /cep/{cep}`: logradouro, bairro, cidade e UF; as
  /// coordenadas quando vierem, senão ficam vazias.
  FormQuadraCampos comEndereco(EnderecoCep e) {
    final temCoordenadas = e.latitude != null && e.longitude != null;
    return FormQuadraCampos(
      nome: nome,
      esporte: esporte,
      preco: preco,
      descricao: descricao,
      cep: cep,
      logradouro: e.logradouro ?? '',
      numero: numero,
      bairro: e.bairro ?? '',
      cidade: e.cidade ?? '',
      uf: (e.uf ?? '').toUpperCase(),
      latitude: temCoordenadas ? e.latitude.toString() : '',
      longitude: temCoordenadas ? e.longitude.toString() : '',
      fotoUrl: fotoUrl,
    );
  }

  @override
  List<Object?> get props => [
        nome,
        esporte,
        preco,
        descricao,
        cep,
        logradouro,
        numero,
        bairro,
        cidade,
        uf,
        latitude,
        longitude,
        fotoUrl,
      ];
}

/// "1.234,56" a partir do preço em reais (mesmo formato da máscara).
String formatarPrecoCampo(double valor) {
  final centavos = (valor * 100).round();
  return formatarCentavos(centavos);
}

/// "1.234,56" a partir dos centavos.
String formatarCentavos(int centavos) {
  final inteiro = NumberFormat('#,##0', 'pt_BR').format(centavos ~/ 100);
  final resto = (centavos % 100).toString().padLeft(2, '0');
  return '$inteiro,$resto';
}

/// Lê latitude ou longitude ("-23,55" ou "-23.55"); vazio ou inválido = nulo.
double? lerCoordenada(String texto) {
  final t = texto.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

/// Valida por campo com as regras do `QuadraRequest`. Devolve a mensagem
/// (já traduzida) de cada campo inválido; vazio = válido.
Map<CampoQuadra, String> validarQuadra(FormQuadraCampos c) {
  final erros = <CampoQuadra, String>{};
  String obrigatorio() => 'comum.campo_obrigatorio'.tr();
  String maximo(int n) =>
      'quadras.form.erro_maximo'.tr(namedArgs: {'max': '$n'});

  void texto(
    CampoQuadra campo,
    String valor,
    int limite, {
    bool exigido = true,
  }) {
    final t = valor.trim();
    if (exigido && t.isEmpty) {
      erros[campo] = obrigatorio();
    } else if (t.length > limite) {
      erros[campo] = maximo(limite);
    }
  }

  texto(CampoQuadra.nome, c.nome, LimitesQuadra.nome);
  if (c.esporte == null) {
    erros[CampoQuadra.esporte] = 'quadras.form.erro_esporte'.tr();
  }

  final erroPreco = _validarPreco(c.preco);
  if (erroPreco != null) erros[CampoQuadra.preco] = erroPreco;

  texto(CampoQuadra.descricao, c.descricao, LimitesQuadra.descricao,
      exigido: false);

  final cep = Formatadores.digitos(c.cep);
  if (cep.isEmpty) {
    erros[CampoQuadra.cep] = obrigatorio();
  } else if (cep.length != 8) {
    erros[CampoQuadra.cep] = 'quadras.form.erro_cep'.tr();
  }

  texto(CampoQuadra.logradouro, c.logradouro, LimitesQuadra.logradouro);
  texto(CampoQuadra.numero, c.numero, LimitesQuadra.numero);
  texto(CampoQuadra.bairro, c.bairro, LimitesQuadra.bairro, exigido: false);
  texto(CampoQuadra.cidade, c.cidade, LimitesQuadra.cidade);

  final uf = c.uf.trim().toUpperCase();
  if (uf.isEmpty) {
    erros[CampoQuadra.uf] = obrigatorio();
  } else if (!RegExp(r'^[A-Z]{2}$').hasMatch(uf)) {
    erros[CampoQuadra.uf] = 'quadras.form.erro_uf'.tr();
  }

  _validarCoordenadas(c, erros);

  texto(CampoQuadra.fotoUrl, c.fotoUrl, LimitesQuadra.fotoUrl, exigido: false);
  return erros;
}

String? _validarPreco(String texto) {
  if (texto.trim().isEmpty) return 'comum.campo_obrigatorio'.tr();
  final valor = Formatadores.lerDinheiro(texto);
  if (valor == null) return 'quadras.form.erro_preco_invalido'.tr();
  if (valor <= 0) return 'quadras.form.erro_preco_zero'.tr();
  final centavos = valor * 100;
  if ((centavos - centavos.round()).abs() > 1e-6) {
    return 'quadras.form.erro_preco_invalido'.tr();
  }
  if (valor.truncate().toString().length > LimitesQuadra.precoDigitosInteiros) {
    return 'quadras.form.erro_preco_maximo'.tr();
  }
  return null;
}

void _validarCoordenadas(FormQuadraCampos c, Map<CampoQuadra, String> erros) {
  final temLat = c.latitude.trim().isNotEmpty;
  final temLng = c.longitude.trim().isNotEmpty;
  final lat = lerCoordenada(c.latitude);
  final lng = lerCoordenada(c.longitude);

  if (temLat && lat == null) {
    erros[CampoQuadra.latitude] = 'quadras.form.erro_numero'.tr();
  } else if (lat != null && (lat < -90 || lat > 90)) {
    erros[CampoQuadra.latitude] = 'quadras.form.erro_latitude'.tr();
  }
  if (temLng && lng == null) {
    erros[CampoQuadra.longitude] = 'quadras.form.erro_numero'.tr();
  } else if (lng != null && (lng < -180 || lng > 180)) {
    erros[CampoQuadra.longitude] = 'quadras.form.erro_longitude'.tr();
  }

  if (temLat && !temLng) {
    erros[CampoQuadra.longitude] = 'quadras.form.erro_coordenadas'.tr();
  } else if (temLng && !temLat) {
    erros[CampoQuadra.latitude] = 'quadras.form.erro_coordenadas'.tr();
  }
}

/// Dados do `POST`/`PUT` a partir de campos já validados: preço em reais (a
/// API recebe "80.00"), CEP só com dígitos e UF em maiúsculas.
QuadraDados montarQuadraDados(FormQuadraCampos c) {
  String? opcional(String v) => v.trim().isEmpty ? null : v.trim();
  return QuadraDados(
    nome: c.nome.trim(),
    descricao: opcional(c.descricao),
    tipoEsporte: c.esporte ?? TipoEsporte.outro,
    precoHora: Formatadores.lerDinheiro(c.preco) ?? 0,
    cep: Formatadores.digitos(c.cep),
    logradouro: c.logradouro.trim(),
    numero: c.numero.trim(),
    bairro: opcional(c.bairro),
    cidade: c.cidade.trim(),
    uf: c.uf.trim().toUpperCase(),
    latitude: lerCoordenada(c.latitude),
    longitude: lerCoordenada(c.longitude),
    fotoUrl: opcional(c.fotoUrl),
  );
}
