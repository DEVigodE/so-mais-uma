import 'package:equatable/equatable.dart';

import '../enums.dart';
import 'horario_funcionamento.dart';

/// Quadra esportiva (`QuadraResponse`).
class Quadra extends Equatable {
  const Quadra({
    required this.id,
    required this.nome,
    required this.tipoEsporte,
    required this.precoHora,
    required this.cep,
    required this.logradouro,
    required this.numero,
    required this.cidade,
    required this.uf,
    this.donoId,
    this.descricao,
    this.bairro,
    this.latitude,
    this.longitude,
    this.fotoUrl,
    this.ativa = true,
    this.atualizadoEm,
    this.horarios = const [],
  });

  final int id;
  final int? donoId;
  final String nome;
  final String? descricao;
  final TipoEsporte tipoEsporte;

  /// Preço por hora em reais.
  final double precoHora;

  /// Só dígitos (8).
  final String cep;
  final String logradouro;
  final String numero;
  final String? bairro;
  final String cidade;
  final String uf;
  final double? latitude;
  final double? longitude;
  final String? fotoUrl;
  final bool ativa;
  final DateTime? atualizadoEm;

  /// Faixas de funcionamento (0 a 7; dia ausente = fechado). Só vem no detalhe.
  final List<HorarioFuncionamento> horarios;

  bool get temCoordenadas => latitude != null && longitude != null;

  /// "Bairro, Cidade" (ou só a cidade, sem bairro).
  String get localCurto => [
        if (bairro != null && bairro!.trim().isNotEmpty) bairro!.trim(),
        cidade,
      ].join(', ');

  /// "Logradouro, número - Bairro, Cidade - UF".
  String get enderecoCompleto {
    final bairroParte = (bairro != null && bairro!.trim().isNotEmpty)
        ? ' - ${bairro!.trim()}'
        : '';
    return '$logradouro, $numero$bairroParte, $cidade - $uf';
  }

  /// Faixa de funcionamento do dia da semana (1 = segunda ... 7 = domingo).
  HorarioFuncionamento? horarioDoDia(int diaSemana) {
    for (final h in horarios) {
      if (h.diaSemana == diaSemana) return h;
    }
    return null;
  }

  Quadra copyWith({List<HorarioFuncionamento>? horarios, bool? ativa}) => Quadra(
        id: id,
        donoId: donoId,
        nome: nome,
        descricao: descricao,
        tipoEsporte: tipoEsporte,
        precoHora: precoHora,
        cep: cep,
        logradouro: logradouro,
        numero: numero,
        bairro: bairro,
        cidade: cidade,
        uf: uf,
        latitude: latitude,
        longitude: longitude,
        fotoUrl: fotoUrl,
        ativa: ativa ?? this.ativa,
        atualizadoEm: atualizadoEm,
        horarios: horarios ?? this.horarios,
      );

  @override
  List<Object?> get props => [
        id,
        donoId,
        nome,
        descricao,
        tipoEsporte,
        precoHora,
        cep,
        logradouro,
        numero,
        bairro,
        cidade,
        uf,
        latitude,
        longitude,
        fotoUrl,
        ativa,
        atualizadoEm,
        horarios,
      ];
}

/// Dados enviados em `POST /quadras` e `PUT /quadras/{id}` (`QuadraRequest`).
class QuadraDados extends Equatable {
  const QuadraDados({
    required this.nome,
    required this.tipoEsporte,
    required this.precoHora,
    required this.cep,
    required this.logradouro,
    required this.numero,
    required this.cidade,
    required this.uf,
    this.descricao,
    this.bairro,
    this.latitude,
    this.longitude,
    this.fotoUrl,
  });

  final String nome;
  final String? descricao;
  final TipoEsporte tipoEsporte;
  final double precoHora;

  /// Só dígitos (8).
  final String cep;
  final String logradouro;
  final String numero;
  final String? bairro;
  final String cidade;
  final String uf;
  final double? latitude;
  final double? longitude;
  final String? fotoUrl;

  @override
  List<Object?> get props => [
        nome,
        descricao,
        tipoEsporte,
        precoHora,
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
