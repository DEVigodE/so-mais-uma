import 'package:equatable/equatable.dart';

import '../enums.dart';

/// Cobrança Pix de uma reserva (`PagamentoResponse`).
class Pagamento extends Equatable {
  const Pagamento({
    required this.txid,
    required this.status,
    required this.provedor,
    required this.valor,
    this.pixCopiaECola,
    this.expiraEm,
    this.pagoEm,
  });

  final String txid;
  final StatusPagamento status;
  final ProvedorPagamento provedor;
  final double valor;

  /// Payload "copia e cola" (EMV), usado também para gerar o QR localmente.
  final String? pixCopiaECola;
  final DateTime? expiraEm;
  final DateTime? pagoEm;

  @override
  List<Object?> get props =>
      [txid, status, provedor, valor, pixCopiaECola, expiraEm, pagoEm];
}
