import 'package:so_mais_uma/src/imports/imports.dart';

import 'faixa_datas.dart';

/// Busca da próxima data com slot livre, quando a data escolhida não tem
/// nenhum (spec reservas-cliente, "Grade de slots consultada a cada data").
sealed class ProximaDataLivre {
  const ProximaDataLivre();
}

/// Nada a oferecer (a data tem slot livre, ou a busca falhou).
final class ProximaNaoAplicavel extends ProximaDataLivre {
  const ProximaNaoAplicavel();
}

final class ProximaBuscando extends ProximaDataLivre {
  const ProximaBuscando();
}

final class ProximaEncontrada extends ProximaDataLivre {
  const ProximaEncontrada(this.data);
  final DataFaixa data;
}

/// Nenhuma data até hoje + 14 tem slot livre.
final class ProximaNenhuma extends ProximaDataLivre {
  const ProximaNenhuma();
}

/// Aviso de uma única leitura (snackbar), consumido pelo contêiner.
final class AvisoGrade {
  AvisoGrade(this.mensagem);
  final String mensagem;
}

/// Store da seção de grade da DetalheQuadra do cliente.
///
/// Mantém a faixa de datas, a grade da data escolhida (`GET
/// /quadras/{id}/slots?data=`) e o slot selecionado. Trocar de data descarta a
/// resposta pendente da data anterior; os slots não vão para cache.
class GradeSlotsStore {
  GradeSlotsStore(this._repositorio, this._relogio);

  final SlotRepository _repositorio;
  final Relogio _relogio;

  final _datas = signal<List<DataFaixa>>(const []);
  final _dataSelecionada = signal<DataFaixa?>(null);
  final _grade = signal<RequestState<List<Slot>>>(const RequestInitial());
  final _selecionado = signal<Slot?>(null);
  final _proxima = signal<ProximaDataLivre>(const ProximaNaoAplicavel());
  final _aviso = signal<AvisoGrade?>(null);

  int? _quadraId;
  bool _descartado = false;
  int _geracao = 0;

  /// Hoje a hoje + 14.
  ReadonlySignal<List<DataFaixa>> get datas => _datas;
  ReadonlySignal<DataFaixa?> get dataSelecionada => _dataSelecionada;
  ReadonlySignal<RequestState<List<Slot>>> get grade => _grade;
  ReadonlySignal<Slot?> get selecionado => _selecionado;
  ReadonlySignal<ProximaDataLivre> get proxima => _proxima;
  ReadonlySignal<AvisoGrade?> get aviso => _aviso;

  late final _visiveis = computed<List<Slot>>(
    () => switch (_grade.value) {
      RequestSuccess(:final data) =>
        data.where((s) => s.status != StatusSlot.fechado).toList(),
      _ => const [],
    },
  );

  /// Slots exibidos: os `FECHADO` ficam ocultos.
  ReadonlySignal<List<Slot>> get visiveis => _visiveis;

  late final _semLivre = computed(
    () => switch (_grade.value) {
      RequestSuccess(:final data) => !data.any((s) => s.livre),
      _ => false,
    },
  );

  /// A data carregada não tem nenhum slot `LIVRE`.
  ReadonlySignal<bool> get semLivre => _semLivre;

  /// Monta a faixa a partir de hoje e carrega a grade de hoje.
  Future<void> iniciar(int quadraId) async {
    if (_descartado) return;
    _quadraId = quadraId;
    final datas = gerarFaixaDatas(_relogio.agora());
    batch(() {
      _datas.value = datas;
      _dataSelecionada.value = datas.first;
      _selecionado.value = null;
    });
    await _carregar();
  }

  /// Troca a data: desfaz a seleção e busca a grade da nova data.
  Future<void> selecionarData(DataFaixa data) async {
    if (_descartado || data == _dataSelecionada.value) return;
    batch(() {
      _dataSelecionada.value = data;
      _selecionado.value = null;
    });
    await _carregar();
  }

  /// Toque num slot: só `LIVRE` seleciona; tocar o selecionado desfaz.
  void tocarSlot(Slot slot) {
    if (_descartado || !slot.livre) return;
    _selecionado.value = _selecionado.value == slot ? null : slot;
  }

  /// Recarrega a grade da data escolhida. Depois da ConfirmarReserva pedir
  /// recarga a seleção é limpa; na volta ao primeiro plano ela é mantida se o
  /// slot continuar livre.
  Future<void> recarregar({bool limparSelecao = true}) async {
    if (_descartado || _quadraId == null) return;
    final datas = gerarFaixaDatas(_relogio.agora());
    final atual = _dataSelecionada.value;
    final mantida = datas.where((d) => d.data == atual?.data);
    batch(() {
      _datas.value = datas;
      _dataSelecionada.value = mantida.isEmpty ? datas.first : mantida.first;
      if (limparSelecao || mantida.isEmpty) _selecionado.value = null;
    });
    await _carregar();
  }

  /// "Tentar novamente" da área da grade.
  Future<void> tentarNovamente() => _carregar();

  void consumirAviso() {
    if (_descartado) return;
    _aviso.value = null;
  }

  Future<void> _carregar() async {
    final quadraId = _quadraId;
    final data = _dataSelecionada.value;
    if (quadraId == null || data == null) return;

    final geracao = ++_geracao;
    batch(() {
      _grade.value = const RequestLoading();
      _proxima.value = const ProximaNaoAplicavel();
    });

    final resultado = await _repositorio.slots(quadraId, data.data);
    if (_descartado || geracao != _geracao) return;

    resultado.fold(
      (failure) => batch(() {
        _grade.value = RequestFailure(failure);
        _selecionado.value = null;
        if (_foraDaJanela(failure)) _aviso.value = AvisoGrade(failure.message);
      }),
      (slots) {
        batch(() {
          _grade.value = RequestSuccess(slots);
          final selecionado = _selecionado.value;
          if (selecionado != null &&
              !slots.any((s) => s.livre && s.inicio == selecionado.inicio)) {
            _selecionado.value = null;
          }
        });
        if (!slots.any((s) => s.livre)) _buscarProxima(geracao, data);
      },
    );
  }

  /// Procura em sequência as datas seguintes até hoje + 14 e para na primeira
  /// com slot livre. Uma troca de data ou recarga (nova geração) interrompe.
  Future<void> _buscarProxima(int geracao, DataFaixa apos) async {
    final quadraId = _quadraId;
    if (quadraId == null) return;
    _proxima.value = const ProximaBuscando();

    final seguintes = _datas.value.where((d) => d.data.isAfter(apos.data));
    for (final candidata in seguintes) {
      final resultado = await _repositorio.slots(quadraId, candidata.data);
      if (_descartado || geracao != _geracao) return;
      final achou = resultado.fold(
        (_) => null,
        (slots) => slots.any((s) => s.livre),
      );
      if (achou == null) {
        _proxima.value = const ProximaNaoAplicavel();
        return;
      }
      if (achou) {
        _proxima.value = ProximaEncontrada(candidata);
        return;
      }
    }
    _proxima.value = const ProximaNenhuma();
  }

  bool _foraDaJanela(Failure failure) =>
      failure is ApiFailure &&
      (failure.subcodigo == 'DATA_FORA_DA_JANELA' ||
          failure.codigo == 'DATA_FORA_DA_JANELA');

  void dispose() {
    if (_descartado) return;
    _descartado = true;
    _visiveis.dispose();
    _semLivre.dispose();
    _datas.dispose();
    _dataSelecionada.dispose();
    _grade.dispose();
    _selecionado.dispose();
    _proxima.dispose();
    _aviso.dispose();
  }
}
