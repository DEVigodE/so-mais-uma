import 'package:equatable/equatable.dart';

import '../../../../shared/domain/brasilia.dart';
import '../../../../shared/domain/entities/horario_funcionamento.dart';
import '../../../../shared/domain/entities/reserva.dart';
import '../../../../shared/domain/enums.dart';

/// Fórmulas da ReservasQuadra (design D14). Funções puras: "agora" e as datas
/// de parede de Brasília entram por parâmetro.

/// Quantidade de dias da faixa de datas: hoje até hoje + 14.
const int diasDaFaixa = 15;

/// Resumo do dia exibido nos três blocos do topo.
class ResumoDia extends Equatable {
  const ResumoDia({
    required this.agendadas,
    required this.aguardando,
    required this.previsao,
    required this.hoje,
    this.ocupacaoPercentual,
    this.expiraEmMinutos,
  });

  static const vazio = ResumoDia(
    agendadas: 0,
    aguardando: 0,
    previsao: 0,
    hoje: true,
  );

  /// Reservas `CONFIRMADA` da lista.
  final int agendadas;

  /// `round(100 * ativas / slots do dia)`; `null` quando os slots não são
  /// conhecidos ou o dia não tem nenhum slot (o texto é omitido).
  final int? ocupacaoPercentual;

  /// Reservas `PENDENTE_PAGAMENTO` da lista.
  final int aguardando;

  /// `ceil(menor(expiraEm - agora) / 1 min)` entre as pendentes; `null` sem
  /// nenhuma pendente com prazo.
  final int? expiraEmMinutos;

  /// Soma do valor das reservas ativas.
  final double previsao;

  /// `true` quando a data é hoje ("Hoje total"); senão "Total do dia".
  final bool hoje;

  @override
  List<Object?> get props => [
        agendadas,
        ocupacaoPercentual,
        aguardando,
        expiraEmMinutos,
        previsao,
        hoje
      ];
}

/// Calcula o resumo do dia a partir da lista exibida (data e chip
/// selecionados).
ResumoDia calcularResumoDoDia({
  required List<Reserva> reservas,
  required int? slotsDoDia,
  required DateTime agora,
  required bool hoje,
}) {
  var agendadas = 0;
  var aguardando = 0;
  var ativas = 0;
  var previsao = 0.0;
  int? menorRestante;

  for (final r in reservas) {
    if (r.status == StatusReserva.confirmada) agendadas++;
    if (r.status == StatusReserva.pendentePagamento) {
      aguardando++;
      final expira = r.expiraEm;
      if (expira != null) {
        final restante = minutosRestantes(expira, agora);
        if (menorRestante == null || restante < menorRestante) {
          menorRestante = restante;
        }
      }
    }
    if (r.status.ativa) {
      ativas++;
      previsao += r.valor;
    }
  }

  final ocupacao = (slotsDoDia == null || slotsDoDia <= 0)
      ? null
      : (100 * ativas / slotsDoDia).round();

  return ResumoDia(
    agendadas: agendadas,
    ocupacaoPercentual: ocupacao,
    aguardando: aguardando,
    expiraEmMinutos: menorRestante,
    previsao: previsao,
    hoje: hoje,
  );
}

/// Minutos inteiros que faltam até [expiraEm], arredondados para cima e nunca
/// negativos.
int minutosRestantes(DateTime expiraEm, DateTime agora) {
  final segundos = expiraEm.difference(agora).inSeconds;
  if (segundos <= 0) return 0;
  return (segundos / 60).ceil();
}

/// Soma dos slots do dia da semana [diaSemana] (1 = segunda ... 7 = domingo)
/// das quadras [quadraIds]. Devolve `null` quando as faixas de alguma quadra
/// ainda não são conhecidas; dia sem faixa conta zero.
int? somarSlotsDoDia({
  required Iterable<int> quadraIds,
  required Map<int, List<HorarioFuncionamento>> horarios,
  required int diaSemana,
}) {
  var total = 0;
  for (final id in quadraIds) {
    final faixas = horarios[id];
    if (faixas == null) return null;
    for (final h in faixas) {
      if (h.diaSemana == diaSemana) total += h.quantidadeSlots;
    }
  }
  return total;
}

/// Datas de parede da faixa: de [hoje] até [hoje] + 14.
List<DateTime> faixaDeDatas(DateTime hoje) => List.generate(
      diasDaFaixa,
      (i) => DateTime.utc(hoje.year, hoje.month, hoje.day + i),
      growable: false,
    );

/// `true` quando a data de parede [data] está na faixa iniciada em [hoje].
bool dataNaFaixa(DateTime data, DateTime hoje) {
  final ultimo =
      DateTime.utc(hoje.year, hoje.month, hoje.day + diasDaFaixa - 1);
  return !data.isBefore(hoje) && !data.isAfter(ultimo);
}

/// Reservas de [reservas] que começam na data de parede [data] e, com
/// [quadraId], dessa quadra, em ordem crescente de início.
List<Reserva> reservasDoDia(
  Iterable<Reserva> reservas, {
  required DateTime data,
  int? quadraId,
}) {
  final lista = reservas
      .where((r) => Brasilia.dia(r.inicio) == data)
      .where((r) => quadraId == null || r.quadraId == quadraId)
      .toList()
    ..sort((a, b) {
      final porInicio = a.inicio.compareTo(b.inicio);
      return porInicio != 0 ? porInicio : a.id.compareTo(b.id);
    });
  return lista;
}

/// O dono pode cancelar reservas ativas até o início (RN03).
bool donoPodeCancelar(Reserva reserva, DateTime agora) =>
    reserva.status.ativa && agora.isBefore(reserva.inicio);

/// Iniciais de um nome (D14): primeira letra do primeiro e do último nome.
String iniciaisDoNome(String? nome) {
  final partes = (nome ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (partes.isEmpty) return '?';
  final primeira = partes.first.substring(0, 1);
  if (partes.length == 1) return primeira.toUpperCase();
  return '$primeira${partes.last.substring(0, 1)}'.toUpperCase();
}
