import 'package:equatable/equatable.dart';

import '../../../../shared/domain/brasilia.dart';
import '../../../../shared/domain/entities/horario_funcionamento.dart';
import '../../../../shared/domain/entities/quadra.dart';
import '../../../../shared/domain/entities/reserva.dart';
import '../../../../shared/domain/enums.dart';

/// Fórmulas de MinhasQuadras (design D14), todas no fuso de Brasília.

/// Atividade de hoje de uma quadra, mostrada no card.
class AtividadeQuadra extends Equatable {
  const AtividadeQuadra({
    required this.reservasHoje,
    this.proxima,
    this.ocupacao,
    this.fechadaHoje = false,
  });

  /// `n`: reservas `PENDENTE_PAGAMENTO` ou `CONFIRMADA` da quadra com início
  /// hoje. Nulo quando as reservas não puderam ser carregadas.
  final int? reservasHoje;

  /// Menor início futuro entre essas reservas ("Próxima às"); nulo = "Sem
  /// próximas hoje".
  final DateTime? proxima;

  /// `round(100 * n / slotsHoje)`, de 0 a 100. Nulo quando a faixa de hoje é
  /// desconhecida (horários ainda não carregados) ou a quadra está fechada.
  final int? ocupacao;

  /// Sem faixa de funcionamento no dia da semana de hoje.
  final bool fechadaHoje;

  @override
  List<Object?> get props => [reservasHoje, proxima, ocupacao, fechadaHoje];
}

/// Quadra com a atividade calculada, pronta para o card.
class QuadraComAtividade extends Equatable {
  const QuadraComAtividade(this.quadra, this.atividade);

  final Quadra quadra;
  final AtividadeQuadra atividade;

  @override
  List<Object?> get props => [quadra, atividade];
}

/// "Total de Quadras": todas as do dono, ativas e inativas.
int totalDeQuadras(List<Quadra> quadras) => quadras.length;

/// "Reservas Hoje" do painel: `CONFIRMADA` com início hoje em todas as quadras.
int reservasConfirmadasHoje(List<Reserva> reservas, DateTime agora) => reservas
    .where((r) =>
        r.status == StatusReserva.confirmada &&
        Brasilia.mesmoDia(r.inicio, agora))
    .length;

/// Atividade do card. [reservas] nulo = não carregadas; [horarios] nulo =
/// faixas ainda desconhecidas.
AtividadeQuadra calcularAtividade({
  required int quadraId,
  required List<Reserva>? reservas,
  required List<HorarioFuncionamento>? horarios,
  required DateTime agora,
}) {
  final deHoje = reservas
      ?.where((r) =>
          r.quadraId == quadraId &&
          r.status.ativa &&
          Brasilia.mesmoDia(r.inicio, agora))
      .toList(growable: false);
  final n = deHoje?.length;

  DateTime? proxima;
  for (final r in deHoje ?? const <Reserva>[]) {
    if (!r.inicio.isAfter(agora)) continue;
    if (proxima == null || r.inicio.isBefore(proxima)) proxima = r.inicio;
  }

  if (horarios == null) {
    return AtividadeQuadra(reservasHoje: n, proxima: proxima);
  }

  final diaSemana = Brasilia.parede(agora).weekday;
  HorarioFuncionamento? faixa;
  for (final h in horarios) {
    if (h.diaSemana == diaSemana) faixa = h;
  }
  final slots = faixa?.quantidadeSlots ?? 0;
  if (slots <= 0) {
    return AtividadeQuadra(
      reservasHoje: n,
      proxima: proxima,
      fechadaHoje: true,
    );
  }
  return AtividadeQuadra(
    reservasHoje: n,
    proxima: proxima,
    ocupacao: n == null ? null : ocupacaoDoDia(n, slots),
  );
}

/// `round(100 * n / slots)`, limitado a 0..100.
int ocupacaoDoDia(int reservas, int slots) {
  if (slots <= 0) return 0;
  return (100 * reservas / slots).round().clamp(0, 100);
}

/// Ordem "Mais ativas": ativas antes das inativas, depois `n` decrescente e,
/// no empate, o nome em ordem alfabética.
List<QuadraComAtividade> ordenarMaisAtivas(Iterable<QuadraComAtividade> itens) {
  final lista = itens.toList();
  lista.sort((a, b) {
    if (a.quadra.ativa != b.quadra.ativa) return a.quadra.ativa ? -1 : 1;
    final n = (b.atividade.reservasHoje ?? 0)
        .compareTo(a.atividade.reservasHoje ?? 0);
    if (n != 0) return n;
    return a.quadra.nome.toLowerCase().compareTo(b.quadra.nome.toLowerCase());
  });
  return List.unmodifiable(lista);
}
