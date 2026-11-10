import 'package:so_mais_uma/src/shared/domain/domain.dart';

/// Abas de MinhasReservas.
enum AbaReservas { proximas, historico }

/// Situação exibida de uma reserva: o status da API mais "Concluída", que é
/// calculada (D14: `CONFIRMADA` com `fim <= agora`).
enum SituacaoReserva {
  pendente,
  confirmada,
  concluida,
  cancelada,
  expirada;

  static SituacaoReserva de(Reserva reserva, DateTime agora) =>
      switch (reserva.status) {
        StatusReserva.pendentePagamento => SituacaoReserva.pendente,
        StatusReserva.confirmada => reserva.concluida(agora)
            ? SituacaoReserva.concluida
            : SituacaoReserva.confirmada,
        StatusReserva.cancelada => SituacaoReserva.cancelada,
        StatusReserva.expirada => SituacaoReserva.expirada,
      };

  /// Chave de tradução do rótulo (`status_reserva.*`).
  String get rotuloKey => switch (this) {
        SituacaoReserva.pendente => StatusReserva.pendentePagamento.rotuloKey,
        SituacaoReserva.confirmada => StatusReserva.confirmada.rotuloKey,
        SituacaoReserva.concluida => 'status_reserva.CONCLUIDA',
        SituacaoReserva.cancelada => StatusReserva.cancelada.rotuloKey,
        SituacaoReserva.expirada => StatusReserva.expirada.rotuloKey,
      };
}

/// Resultado da divisão das reservas entre as abas.
class AbasReservas {
  const AbasReservas({this.proximas = const [], this.historico = const []});

  /// Pendentes ou confirmadas que ainda não terminaram, por início crescente.
  final List<Reserva> proximas;

  /// As demais, por início decrescente.
  final List<Reserva> historico;

  static const vazias = AbasReservas();
}

/// Divide as reservas entre "Próximas" e "Histórico" (D14).
///
/// Próximas: `PENDENTE_PAGAMENTO` ou `CONFIRMADA` com `fim > agora`, em ordem
/// crescente de início. Histórico: o resto, em ordem decrescente de início.
/// O id desempata, para a ordem ser estável.
AbasReservas separarAbas(Iterable<Reserva> reservas, DateTime agora) {
  final proximas = <Reserva>[];
  final historico = <Reserva>[];
  for (final r in reservas) {
    (r.proxima(agora) ? proximas : historico).add(r);
  }
  proximas.sort((a, b) {
    final c = a.inicio.compareTo(b.inicio);
    return c != 0 ? c : a.id.compareTo(b.id);
  });
  historico.sort((a, b) {
    final c = b.inicio.compareTo(a.inicio);
    return c != 0 ? c : b.id.compareTo(a.id);
  });
  return AbasReservas(
    proximas: List.unmodifiable(proximas),
    historico: List.unmodifiable(historico),
  );
}

/// Tempo restante do Pix de uma reserva pendente: `max(0, expiraEm - agora)`.
/// Sem `expiraEm`, devolve `null` (o card não mostra contador).
Duration? restantePagamento(Reserva reserva, DateTime agora) {
  final expira = reserva.pagamento?.expiraEm ?? reserva.expiraEm;
  if (expira == null) return null;
  final restante = expira.difference(agora);
  return restante.isNegative ? Duration.zero : restante;
}

/// Contador `mm:ss`.
String formatarMmSs(Duration d) {
  final total = d.isNegative ? 0 : d.inSeconds;
  final m = (total ~/ 60).toString().padLeft(2, '0');
  final s = (total % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
