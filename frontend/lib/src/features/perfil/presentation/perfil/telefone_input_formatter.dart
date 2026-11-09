import 'package:flutter/services.dart';

/// Máscara de telefone brasileiro enquanto o usuário digita:
/// "(11) 3456-7890" (10 dígitos) ou "(11) 91234-5678" (11 dígitos).
/// Aceita só dígitos e no máximo 11.
class TelefoneInputFormatter extends TextInputFormatter {
  const TelefoneInputFormatter();

  static const int maximoDigitos = 11;

  /// Formata os dígitos já digitados (parciais ou completos).
  static String formatar(String texto) {
    var d = texto.replaceAll(RegExp(r'\D'), '');
    if (d.length > maximoDigitos) d = d.substring(0, maximoDigitos);
    if (d.isEmpty) return '';
    if (d.length <= 2) return '($d';

    final ddd = d.substring(0, 2);
    final resto = d.substring(2);
    if (resto.length <= 4) return '($ddd) $resto';

    // Com 11 dígitos o prefixo tem 5 dígitos; até 10, tem 4.
    final corte = d.length == maximoDigitos ? 5 : 4;
    return '($ddd) ${resto.substring(0, corte)}-${resto.substring(corte)}';
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitosNovos = newValue.text.replaceAll(RegExp(r'\D'), '');
    final digitosAntigos = oldValue.text.replaceAll(RegExp(r'\D'), '');

    // Apagar só um caractere de máscara apaga também o dígito anterior.
    var digitos = digitosNovos;
    if (digitosNovos == digitosAntigos &&
        newValue.text.length < oldValue.text.length &&
        digitos.isNotEmpty) {
      digitos = digitos.substring(0, digitos.length - 1);
    }

    final texto = formatar(digitos);
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}
