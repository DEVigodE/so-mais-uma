import 'package:equatable/equatable.dart';

/// Faixa de funcionamento de um dia da semana (`HorarioFuncionamentoResponse`).
///
/// `diaSemana` segue a ISO-8601: 1 = segunda ... 7 = domingo (igual a
/// `DateTime.weekday`). As horas vêm como "HH:mm" e são sempre cheias no app.
class HorarioFuncionamento extends Equatable {
  const HorarioFuncionamento({
    required this.diaSemana,
    required this.horaAbertura,
    required this.horaFechamento,
    this.id,
    this.quadraId,
  });

  final int? id;
  final int? quadraId;
  final int diaSemana;

  /// "HH:mm".
  final String horaAbertura;

  /// "HH:mm".
  final String horaFechamento;

  int get aberturaHora => int.tryParse(horaAbertura.split(':').first) ?? 0;
  int get fechamentoHora => int.tryParse(horaFechamento.split(':').first) ?? 0;

  /// Quantidade de slots de 60 min da faixa.
  int get quantidadeSlots =>
      (fechamentoHora - aberturaHora).clamp(0, 24).toInt();

  /// Formata uma hora inteira como "HH:mm".
  static String hora(int h) => '${h.toString().padLeft(2, '0')}:00';

  @override
  List<Object?> get props =>
      [id, quadraId, diaSemana, horaAbertura, horaFechamento];
}
