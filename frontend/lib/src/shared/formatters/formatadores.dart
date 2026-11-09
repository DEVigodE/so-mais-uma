import 'package:intl/intl.dart';

import '../domain/brasilia.dart';

/// Formatação de valores para exibição.
///
/// Datas e horas recebem o instante real da API e são mostradas em UTC-3
/// ([Brasilia]). O idioma vem de `Intl.defaultLocale`, que o `App` mantém igual
/// ao locale do easy_localization (pt_BR, en ou es).
abstract final class Formatadores {
  static final NumberFormat _moeda =
      NumberFormat.currency(locale: 'pt_BR', symbol: r'R$', decimalDigits: 2);

  /// "R$ 90,00" (o real é sempre formatado no padrão brasileiro).
  static String moeda(double valor) =>
      _moeda.format(valor).replaceAll(' ', ' ');

  /// "R$ 90" quando os centavos são zero; senão, o formato completo.
  static String moedaCompacta(double valor) {
    if ((valor * 100).round() % 100 == 0) {
      return 'R\$ ${NumberFormat.decimalPattern('pt_BR').format(valor.round())}';
    }
    return moeda(valor);
  }

  /// "80.00": formato aceito pela API para dinheiro.
  static String dinheiroApi(double valor) => valor.toStringAsFixed(2);

  /// Lê "80,00", "80.00", "1.234,56" ou "R$ 80,00" como número.
  static double? lerDinheiro(String texto) {
    var t = texto.replaceAll(RegExp(r'[^0-9,\.]'), '');
    if (t.isEmpty) return null;
    if (t.contains(',')) t = t.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(t);
  }

  /// "19:00".
  static String hora(DateTime instante) =>
      DateFormat('HH:mm').format(Brasilia.parede(instante));

  /// "19:00 – 20:00".
  static String faixaHorario(DateTime inicio, DateTime fim) =>
      '${hora(inicio)} – ${hora(fim)}';

  /// "Sábado, 10 de outubro de 2026".
  static String dataLonga(DateTime instante) =>
      _capitalizar(DateFormat.yMMMMEEEEd().format(Brasilia.parede(instante)));

  /// "Sábado, 10 de outubro".
  static String dataSemAno(DateTime instante) =>
      _capitalizar(DateFormat.MMMMEEEEd().format(Brasilia.parede(instante)));

  /// "Sáb., 10 de out." (curta, com dia da semana).
  static String dataCurta(DateTime instante) =>
      _capitalizar(DateFormat.MMMEd().format(Brasilia.parede(instante)));

  /// "10/10/2026".
  static String dataNumerica(DateTime instante) =>
      DateFormat('dd/MM/yyyy').format(Brasilia.parede(instante));

  /// "10/10".
  static String diaMes(DateTime instante) =>
      DateFormat('dd/MM').format(Brasilia.parede(instante));

  /// "10/10/2026 às 19:00" (padrão pt; usa o separador do idioma ativo).
  static String dataHora(DateTime instante) =>
      '${dataNumerica(instante)} ${hora(instante)}';

  /// Nome do dia da semana ISO (1 = segunda ... 7 = domingo), capitalizado.
  static String nomeDiaSemana(int diaSemana, {bool abreviado = false}) {
    // 2024-01-01 foi uma segunda-feira.
    final data = DateTime.utc(2024, 1, diaSemana);
    final f = abreviado ? DateFormat.E() : DateFormat.EEEE();
    return _capitalizar(f.format(data).replaceAll('.', ''));
  }

  /// Nome do mês de uma data de parede, capitalizado ("Outubro").
  static String nomeMes(DateTime dataParede) =>
      _capitalizar(DateFormat.MMMM().format(dataParede));

  /// "(11) 98765-4321" ou "(11) 3456-7890".
  static String telefone(String? digitos) {
    final d = (digitos ?? '').replaceAll(RegExp(r'\D'), '');
    if (d.length == 11) {
      return '(${d.substring(0, 2)}) ${d.substring(2, 7)}-${d.substring(7)}';
    }
    if (d.length == 10) {
      return '(${d.substring(0, 2)}) ${d.substring(2, 6)}-${d.substring(6)}';
    }
    return d;
  }

  /// "01310-100".
  static String cep(String? digitos) {
    final d = (digitos ?? '').replaceAll(RegExp(r'\D'), '');
    if (d.length != 8) return d;
    return '${d.substring(0, 5)}-${d.substring(5)}';
  }

  /// Só os dígitos.
  static String digitos(String? texto) =>
      (texto ?? '').replaceAll(RegExp(r'\D'), '');

  static String _capitalizar(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
