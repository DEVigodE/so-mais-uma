/// Fuso de exibição fixo em UTC-3 (RNF12): o Brasil não tem horário de verão
/// desde 2019, então todo instante da API é mostrado e enviado neste deslocamento.
///
/// "Hora de parede" é um `DateTime` em UTC cujos campos (ano, mês, dia, hora...)
/// são os de Brasília. Use-o só para exibir, agrupar por dia e montar parâmetros;
/// para comparar instantes, use os `DateTime` originais das entidades.
abstract final class Brasilia {
  static const Duration deslocamento = Duration(hours: -3);

  /// Converte um instante real na hora de parede de Brasília.
  static DateTime parede(DateTime instante) =>
      instante.toUtc().add(deslocamento);

  /// Converte uma hora de parede de Brasília de volta no instante real.
  static DateTime instante(DateTime parede) => DateTime.utc(
        parede.year,
        parede.month,
        parede.day,
        parede.hour,
        parede.minute,
        parede.second,
      ).subtract(deslocamento);

  /// Data (meia-noite, hora de parede) do instante informado.
  static DateTime dia(DateTime instante) {
    final p = parede(instante);
    return DateTime.utc(p.year, p.month, p.day);
  }

  /// `true` quando os dois instantes caem no mesmo dia em Brasília.
  static bool mesmoDia(DateTime a, DateTime b) => dia(a) == dia(b);

  /// Parâmetro `data` da API (`yyyy-MM-dd`) a partir de uma data de parede.
  static String dataApi(DateTime dataParede) =>
      '${dataParede.year.toString().padLeft(4, '0')}-'
      '${_dois(dataParede.month)}-${_dois(dataParede.day)}';

  /// Campo `inicio` do `POST /reservas`: `<data>T<HH>:<mm>:00-03:00`.
  static String inicioApi(DateTime instanteInicio) {
    final p = parede(instanteInicio);
    return '${dataApi(p)}T${_dois(p.hour)}:${_dois(p.minute)}:00-03:00';
  }

  static String _dois(int v) => v.toString().padLeft(2, '0');
}

/// Fonte de "agora", injetável para os testes controlarem o tempo.
class Relogio {
  const Relogio();

  DateTime agora() => DateTime.now();
}
