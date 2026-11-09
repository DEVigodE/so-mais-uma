import 'package:so_mais_uma/src/imports/imports.dart';

import 'prazo_cancelamento.dart';

/// "Faltam N horas" ou "Faltam N min" (D14), traduzido.
String textoFaltam(Duration restante) {
  final t = tempoRestante(restante);
  final n = {'n': '${t.valor}'};
  return switch (t.unidade) {
    UnidadeRestante.horas => t.valor == 1
        ? 'reservas.cancelamento_cliente.falta_uma_hora'.tr()
        : 'reservas.cancelamento_cliente.faltam_horas'.tr(namedArgs: n),
    UnidadeRestante.minutos => t.valor == 1
        ? 'reservas.cancelamento_cliente.falta_um_min'.tr()
        : 'reservas.cancelamento_cliente.faltam_min'.tr(namedArgs: n),
  };
}

/// Texto da pílula do prazo: "Dentro do prazo de cancelamento (Faltam 46
/// horas)", "Prazo de cancelamento encerrado" ou o prazo da pendente.
String textoPilulaPrazo(PrazoCancelamento prazo) {
  final restante = prazo.restante;
  return switch (prazo.situacao) {
    SituacaoPrazo.dentro => 'reservas.cancelamento_cliente.prazo_dentro'
        .tr(namedArgs: {'tempo': textoFaltam(restante ?? Duration.zero)}),
    SituacaoPrazo.encerrado =>
      'reservas.cancelamento_cliente.prazo_encerrado'.tr(),
    SituacaoPrazo.pendente => restante == null
        ? 'reservas.cancelamento_cliente.prazo_pendente_sem_tempo'.tr()
        : 'reservas.cancelamento_cliente.prazo_pendente'
            .tr(namedArgs: {'tempo': textoFaltam(restante)}),
    SituacaoPrazo.naoAplica => '',
  };
}
