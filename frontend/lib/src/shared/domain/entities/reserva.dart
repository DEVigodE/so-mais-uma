import 'package:equatable/equatable.dart';

import '../enums.dart';
import 'pagamento.dart';

/// Reserva de um slot (`ReservaResponse`).
///
/// `pagamento` só vem no `POST /reservas`, no detalhe, no `PATCH` e no
/// cancelamento; nas listagens (`GET /reservas`, agenda do dono) vem nulo.
class Reserva extends Equatable {
  const Reserva({
    required this.id,
    required this.quadraId,
    required this.quadraNome,
    required this.inicio,
    required this.fim,
    required this.status,
    required this.valor,
    this.quadraEndereco,
    this.clienteId,
    this.clienteNome,
    this.clienteTelefone,
    this.observacao,
    this.expiraEm,
    this.criadoEm,
    this.canceladoEm,
    this.canceladoPor,
    this.motivoCancelamento,
    this.pagamento,
  });

  final int id;
  final int quadraId;
  final String quadraNome;
  final String? quadraEndereco;
  final int? clienteId;
  final String? clienteNome;

  /// Só dígitos, quando informado no cadastro do cliente.
  final String? clienteTelefone;
  final DateTime inicio;
  final DateTime fim;
  final StatusReserva status;
  final double valor;
  final String? observacao;

  /// Fim do prazo do Pix de uma reserva `PENDENTE_PAGAMENTO`.
  final DateTime? expiraEm;
  final DateTime? criadoEm;
  final DateTime? canceladoEm;
  final CanceladoPor? canceladoPor;
  final String? motivoCancelamento;
  final Pagamento? pagamento;

  /// "Concluída": confirmada e já terminou.
  bool concluida(DateTime agora) =>
      status == StatusReserva.confirmada && !fim.isAfter(agora);

  /// Aba "Próximas": pendente ou confirmada e ainda não terminou.
  bool proxima(DateTime agora) => status.ativa && fim.isAfter(agora);

  /// "Estorno pendente": cancelada depois de paga.
  bool get estornoPendente =>
      status == StatusReserva.cancelada &&
      pagamento?.status == StatusPagamento.pago;

  @override
  List<Object?> get props => [
        id,
        quadraId,
        quadraNome,
        quadraEndereco,
        clienteId,
        clienteNome,
        clienteTelefone,
        inicio,
        fim,
        status,
        valor,
        observacao,
        expiraEm,
        criadoEm,
        canceladoEm,
        canceladoPor,
        motivoCancelamento,
        pagamento,
      ];
}
