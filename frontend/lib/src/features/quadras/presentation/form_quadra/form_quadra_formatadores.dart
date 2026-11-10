import 'package:flutter/services.dart';

import 'form_quadra_campos.dart';

/// Máscara de dinheiro por centavos: "9500" vira "95,00" e "123456" vira
/// "1.234,56". Aceita até 8 dígitos inteiros e 2 decimais (`QuadraRequest`).
class MoedaInputFormatter extends TextInputFormatter {
  const MoedaInputFormatter();

  static const int _maxDigitos =
      LimitesQuadra.precoDigitosInteiros + LimitesQuadra.precoDigitosDecimais;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitos = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digitos.isEmpty) return TextEditingValue.empty;
    final semZeros = digitos.replaceFirst(RegExp('^0+'), '');
    if (semZeros.length > _maxDigitos) return oldValue;
    final texto =
        formatarCentavos(int.parse(semZeros.isEmpty ? '0' : semZeros));
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

/// Máscara de CEP `00000-000`.
class CepInputFormatter extends TextInputFormatter {
  const CepInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digitos = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digitos.length > 8) digitos = digitos.substring(0, 8);
    final texto = digitos.length > 5
        ? '${digitos.substring(0, 5)}-${digitos.substring(5)}'
        : digitos;
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

/// Converte para maiúsculas (UF).
class MaiusculasInputFormatter extends TextInputFormatter {
  const MaiusculasInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
