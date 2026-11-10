import 'package:so_mais_uma/src/shared/domain/domain.dart';

/// Antecedência mínima para o cliente cancelar uma reserva confirmada (RN13).
const Duration antecedenciaCancelamentoCliente = Duration(hours: 2);

/// Situação do prazo de cancelamento do cliente.
enum SituacaoPrazo {
  /// `CONFIRMADA` com `agora <= inicio - 2 h`.
  dentro,

  /// `CONFIRMADA` com menos de 2 h para o início (ainda não terminou).
  encerrado,

  /// `PENDENTE_PAGAMENTO`: pode cancelar a qualquer momento até o Pix expirar.
  pendente,

  /// Concluída, cancelada ou expirada: o cartão da política não aparece.
  naoAplica,
}

/// Prazo de cancelamento calculado (D14). A decisão final é do servidor.
class PrazoCancelamento {
  const PrazoCancelamento(this.situacao, {this.limite, this.restante});

  final SituacaoPrazo situacao;

  /// `inicio - 2 h` (confirmada) ou `expiraEm` (pendente).
  final DateTime? limite;

  /// `limite - agora`, nunca negativo; nulo quando não há limite.
  final Duration? restante;

  /// O botão "Cancelar Reserva" aparece (habilitado ou não).
  bool get mostrarBotao =>
      situacao == SituacaoPrazo.dentro ||
      situacao == SituacaoPrazo.encerrado ||
      situacao == SituacaoPrazo.pendente;

  /// O cliente ainda pode pedir o cancelamento.
  bool get podeCancelar =>
      situacao == SituacaoPrazo.dentro || situacao == SituacaoPrazo.pendente;
}

/// Calcula o prazo de cancelamento do cliente para [reserva] em [agora].
///
/// - `CONFIRMADA` futura: limite = `inicio - 2 h`; dentro quando `agora <= limite`.
/// - `PENDENTE_PAGAMENTO`: sempre dentro, até `expiraEm`.
/// - concluída, cancelada ou expirada: não se aplica.
PrazoCancelamento calcularPrazoCancelamento(Reserva reserva, DateTime agora) {
  switch (reserva.status) {
    case StatusReserva.confirmada:
      if (reserva.concluida(agora)) {
        return const PrazoCancelamento(SituacaoPrazo.naoAplica);
      }
      final limite = reserva.inicio.subtract(antecedenciaCancelamentoCliente);
      if (agora.isAfter(limite)) {
        return PrazoCancelamento(
          SituacaoPrazo.encerrado,
          limite: limite,
          restante: Duration.zero,
        );
      }
      return PrazoCancelamento(
        SituacaoPrazo.dentro,
        limite: limite,
        restante: limite.difference(agora),
      );
    case StatusReserva.pendentePagamento:
      final expira = reserva.pagamento?.expiraEm ?? reserva.expiraEm;
      if (expira == null) {
        return const PrazoCancelamento(SituacaoPrazo.pendente);
      }
      final restante = expira.difference(agora);
      return PrazoCancelamento(
        SituacaoPrazo.pendente,
        limite: expira,
        restante: restante.isNegative ? Duration.zero : restante,
      );
    case StatusReserva.cancelada:
    case StatusReserva.expirada:
      return const PrazoCancelamento(SituacaoPrazo.naoAplica);
  }
}

/// Unidade do tempo restante exibido.
enum UnidadeRestante { horas, minutos }

/// "Faltam N horas" (horas inteiras, a partir de 1 h) ou "Faltam N min"
/// (minutos inteiros, no mínimo 1 enquanto houver tempo).
({UnidadeRestante unidade, int valor}) tempoRestante(Duration restante) {
  if (restante >= const Duration(hours: 1)) {
    return (unidade: UnidadeRestante.horas, valor: restante.inHours);
  }
  final minutos = restante.inMinutes;
  final valor = minutos == 0 && restante > Duration.zero ? 1 : minutos;
  return (unidade: UnidadeRestante.minutos, valor: valor);
}

/// Motivo do cancelamento do cliente: 5 a 200 caracteres depois do `trim`.
abstract final class MotivoCancelamento {
  static const int minimo = 5;
  static const int maximo = 200;

  static bool valido(String motivo) {
    final n = motivo.trim().length;
    return n >= minimo && n <= maximo;
  }

  /// Aviso "insira pelo menos 5 caracteres": de 1 a 4 caracteres úteis.
  static bool curto(String motivo) {
    final n = motivo.trim().length;
    return n > 0 && n < minimo;
  }
}
