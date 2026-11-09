import 'package:flutter/material.dart';

/// Enums do contrato da API (`docs/api/openapi-n1.json`).
///
/// Cada enum lê o valor da API com `fromApi`, que nunca lança: um valor
/// desconhecido vira a variante de fallback para o app não quebrar quando o
/// backend acrescentar um valor novo.

enum PerfilUsuario {
  cliente('CLIENTE'),
  dono('DONO');

  const PerfilUsuario(this.api);
  final String api;

  static PerfilUsuario fromApi(Object? valor) =>
      valor == 'DONO' ? PerfilUsuario.dono : PerfilUsuario.cliente;
}

enum TipoEsporte {
  futebolSociety('FUTEBOL_SOCIETY', Icons.sports_soccer),
  futsal('FUTSAL', Icons.sports_soccer),
  volei('VOLEI', Icons.sports_volleyball),
  basquete('BASQUETE', Icons.sports_basketball),
  tenis('TENIS', Icons.sports_tennis),
  beachTennis('BEACH_TENNIS', Icons.sports_tennis),
  padel('PADEL', Icons.sports_tennis),
  outro('OUTRO', Icons.sports);

  const TipoEsporte(this.api, this.icone);

  /// Valor enviado e recebido pela API.
  final String api;

  /// Ícone do esporte (Futsal usa `sports_soccer`; Tênis e Padel, `sports_tennis`).
  final IconData icone;

  /// Chave de tradução do nome completo, por exemplo "Futebol Society".
  String get rotuloKey => 'esportes.$api';

  /// Chave do rótulo curto das etiquetas sobre imagem ("Society").
  String get rotuloCurtoKey => 'esportes_curto.$api';

  /// Esportes que o dono pode escolher (sem o fallback [outro]).
  static List<TipoEsporte> get selecionaveis =>
      values.where((e) => e != TipoEsporte.outro).toList(growable: false);

  static TipoEsporte fromApi(Object? valor) => values.firstWhere(
        (e) => e.api == valor,
        orElse: () => TipoEsporte.outro,
      );
}

enum StatusReserva {
  pendentePagamento('PENDENTE_PAGAMENTO'),
  confirmada('CONFIRMADA'),
  cancelada('CANCELADA'),
  expirada('EXPIRADA');

  const StatusReserva(this.api);
  final String api;

  String get rotuloKey => 'status_reserva.$api';

  /// Reserva que ainda ocupa o horário (pendente ou confirmada).
  bool get ativa =>
      this == StatusReserva.pendentePagamento || this == StatusReserva.confirmada;

  static StatusReserva fromApi(Object? valor) => values.firstWhere(
        (e) => e.api == valor,
        orElse: () => StatusReserva.expirada,
      );
}

enum StatusPagamento {
  pendente('PENDENTE'),
  pago('PAGO'),
  expirado('EXPIRADO'),
  cancelado('CANCELADO');

  const StatusPagamento(this.api);
  final String api;

  static StatusPagamento fromApi(Object? valor) => values.firstWhere(
        (e) => e.api == valor,
        orElse: () => StatusPagamento.pendente,
      );
}

enum ProvedorPagamento {
  inter('INTER'),
  simulado('SIMULADO');

  const ProvedorPagamento(this.api);
  final String api;

  /// Chave do rótulo exibido ("Banco Inter (sandbox)" ou "Pix simulado").
  String get rotuloKey => 'provedor_pagamento.$api';

  static ProvedorPagamento fromApi(Object? valor) =>
      valor == 'INTER' ? ProvedorPagamento.inter : ProvedorPagamento.simulado;
}

enum StatusSlot {
  livre('LIVRE'),
  ocupado('OCUPADO'),
  passado('PASSADO'),
  fechado('FECHADO');

  const StatusSlot(this.api);
  final String api;

  static StatusSlot fromApi(Object? valor) => values.firstWhere(
        (e) => e.api == valor,
        orElse: () => StatusSlot.fechado,
      );
}

enum CanceladoPor {
  cliente('CLIENTE'),
  dono('DONO'),
  sistema('SISTEMA');

  const CanceladoPor(this.api);
  final String api;

  static CanceladoPor? fromApi(Object? valor) {
    for (final e in values) {
      if (e.api == valor) return e;
    }
    return null;
  }
}

enum FonteCep {
  brasilApi('BRASILAPI'),
  viaCep('VIACEP');

  const FonteCep(this.api);
  final String api;

  static FonteCep? fromApi(Object? valor) {
    for (final e in values) {
      if (e.api == valor) return e;
    }
    return null;
  }
}
