/// Janela de pagamento do Pix (RN10).
const Duration janelaPix = Duration(minutes: 15);

/// Tempo restante do Pix (D14): `max(0, expiraEm - agora)`. Sem `expiraEm`,
/// devolve zero.
Duration restantePix(DateTime? expiraEm, DateTime agora) {
  if (expiraEm == null) return Duration.zero;
  final restante = expiraEm.difference(agora);
  return restante.isNegative ? Duration.zero : restante;
}

/// Barra de progresso (D14): `restante / 900 s`, entre 0 e 1.
double progressoPix(Duration restante) {
  final p = restante.inMilliseconds / janelaPix.inMilliseconds;
  if (p < 0) return 0;
  if (p > 1) return 1;
  return p;
}

/// Contador `mm:ss` (segundos inteiros, truncados).
String formatarContadorPix(Duration restante) {
  final total = restante.isNegative ? 0 : restante.inSeconds;
  final m = (total ~/ 60).toString().padLeft(2, '0');
  final s = (total % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Marcos em que o contador é anunciado ao leitor de tela (5 min, 1 min e
/// zero), em segundos.
const List<int> marcosAnuncioPix = [300, 60, 0];

/// Marco cruzado entre [anterior] e [atual] (segundos restantes), se houver.
int? marcoCruzado(int? anterior, int atual) {
  if (anterior == null) return null;
  for (final marco in marcosAnuncioPix) {
    if (anterior > marco && atual <= marco) return marco;
  }
  return null;
}
