import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

import '../../../../shared/domain/brasilia.dart';
import '../../../../shared/formatters/formatadores.dart';

/// Quantos dias depois de hoje a faixa oferece (hoje + 14, RN09).
const int diasDaJanela = 14;

/// Posição de uma data em relação a hoje, em Brasília.
enum TipoDia { hoje, amanha, outro }

/// Uma data da faixa horizontal da DetalheQuadra.
class DataFaixa extends Equatable {
  const DataFaixa({required this.data, required this.tipo});

  /// Meia-noite da data, em hora de parede de Brasília (ver [Brasilia]).
  final DateTime data;
  final TipoDia tipo;

  int get dia => data.day;
  int get diaSemana => data.weekday;

  @override
  List<Object?> get props => [data, tipo];
}

/// Datas de hoje a hoje + [diasDaJanela] (design D14), em Brasília.
List<DataFaixa> gerarFaixaDatas(DateTime agora, {int dias = diasDaJanela}) {
  final hoje = Brasilia.dia(agora);
  return List.generate(dias + 1, (i) {
    final data = DateTime.utc(hoje.year, hoje.month, hoje.day + i);
    return DataFaixa(data: data, tipo: tipoDoDia(data, hoje));
  }, growable: false);
}

/// Classifica a data de parede [data] em relação à data de parede [hoje].
TipoDia tipoDoDia(DateTime data, DateTime hoje) {
  final d = DateTime.utc(data.year, data.month, data.day);
  final h = DateTime.utc(hoje.year, hoje.month, hoje.day);
  final diferenca = d.difference(h).inHours ~/ 24;
  return switch (diferenca) {
    0 => TipoDia.hoje,
    1 => TipoDia.amanha,
    _ => TipoDia.outro,
  };
}

/// "Sáb" (dia da semana abreviado, no idioma ativo) de uma data de parede.
String diaSemanaAbreviado(DateTime dataParede) =>
    Formatadores.nomeDiaSemana(dataParede.weekday, abreviado: true);

/// "Out" (mês abreviado, no idioma ativo) de uma data de parede.
String mesAbreviado(DateTime dataParede) {
  final texto = DateFormat.MMM().format(dataParede).replaceAll('.', '');
  return texto.isEmpty
      ? texto
      : '${texto[0].toUpperCase()}${texto.substring(1)}';
}

/// "11/10" de uma data de parede.
String diaMesParede(DateTime dataParede) =>
    DateFormat('dd/MM').format(dataParede);

/// Faixa do slot no formato da grade: "19:00 - 20:00".
String faixaSlot(DateTime inicio, DateTime fim) =>
    '${Formatadores.hora(inicio)} - ${Formatadores.hora(fim)}';
