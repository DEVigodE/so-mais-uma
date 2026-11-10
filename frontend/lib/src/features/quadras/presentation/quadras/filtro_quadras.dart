import '../../../../shared/domain/entities/quadra.dart';
import '../../../../shared/domain/enums.dart';

/// Filtro local do catálogo (spec quadras-cliente, "Catálogo filtrado
/// localmente"): a busca procura o texto na cidade ou no bairro, sem acento e
/// sem caixa; o esporte é um só, e `null` ("Todos") não filtra. Os dois
/// critérios combinam com "e". O resultado sai em ordem alfabética de nome.
List<Quadra> filtrarQuadras(
  List<Quadra> quadras, {
  String busca = '',
  TipoEsporte? esporte,
}) {
  final termo = normalizarBusca(busca);
  final resultado = quadras.where((q) {
    if (esporte != null && q.tipoEsporte != esporte) return false;
    if (termo.isEmpty) return true;
    return normalizarBusca(q.cidade).contains(termo) ||
        normalizarBusca(q.bairro ?? '').contains(termo);
  }).toList();
  resultado.sort(
    (a, b) => normalizarBusca(a.nome).compareTo(normalizarBusca(b.nome)),
  );
  return resultado;
}

/// Minúsculas, sem acentos e com espaços simples nas pontas e no meio.
String normalizarBusca(String texto) {
  final buffer = StringBuffer();
  for (final rune in texto.toLowerCase().runes) {
    final c = String.fromCharCode(rune);
    buffer.write(_semAcento[c] ?? c);
  }
  return buffer.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
}

const Map<String, String> _semAcento = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', //
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', //
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', //
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', //
  'ç': 'c', 'ñ': 'n',
};
