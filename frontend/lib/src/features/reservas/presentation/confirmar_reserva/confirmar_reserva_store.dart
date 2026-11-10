import 'package:so_mais_uma/src/imports/imports.dart';

/// Resultado do "Confirmar e gerar Pix", consumido uma vez pelo contêiner
/// (tabela "Criação da reserva" da spec reservas-cliente).
sealed class EventoConfirmacao {
  const EventoConfirmacao();

  /// O contêiner sai da ConfirmarReserva ao tratar o evento; até lá o botão
  /// continua bloqueado.
  bool get saiDaTela => true;
}

/// 2xx: `go` para a tela Pagamento da reserva criada.
final class IrParaPagamento extends EventoConfirmacao {
  IrParaPagamento(this.reservaId);
  final int reservaId;
}

/// 409 `HORARIO_INDISPONIVEL`: aviso e volta à grade pedindo recarga.
final class HorarioIndisponivel extends EventoConfirmacao {
  HorarioIndisponivel();
}

/// 422 `RESERVA_PENDENTE_EXISTENTE`: diálogo que leva à reserva pendente.
final class ReservaPendenteExistente extends EventoConfirmacao {
  ReservaPendenteExistente(this.reservaId);
  final int? reservaId;

  /// A tela só sai se o usuário escolher ir para a reserva.
  @override
  bool get saiDaTela => false;
}

/// 502 `PAGAMENTO_INDISPONIVEL`: diálogo e, ao fechar, volta à grade pedindo
/// recarga (o backend já liberou o slot).
final class PagamentoIndisponivel extends EventoConfirmacao {
  PagamentoIndisponivel();
}

/// 422 `FORA_DO_FUNCIONAMENTO` ou `DATA_FORA_DA_JANELA`: snackbar com a regra
/// ([mensagem], já traduzida pelo subcódigo) e volta à grade pedindo recarga.
final class HorarioForaDaRegra extends EventoConfirmacao {
  HorarioForaDaRegra(this.mensagem);
  final String mensagem;
}

/// 400 por início no passado: snackbar e volta à grade.
final class InicioNoPassado extends EventoConfirmacao {
  InicioNoPassado();
}

/// 404: snackbar "Quadra não encontrada" e volta.
final class QuadraIndisponivel extends EventoConfirmacao {
  QuadraIndisponivel();
}

/// Demais falhas (sem conexão, erro inesperado): mensagem e a tela continua
/// aberta.
final class FalhaConfirmacao extends EventoConfirmacao {
  FalhaConfirmacao(this.failure);
  final Failure failure;

  @override
  bool get saiDaTela => false;
}

/// Store da ConfirmarReserva (`/quadras/:id/reservar?inicio=`), no estado
/// anterior ao `POST /reservas`.
class ConfirmarReservaStore {
  ConfirmarReservaStore(this._quadras, this._reservas);

  /// Limite de `observacao` no backend (`CriarReservaRequest`, `@Size(max = 200)`).
  static const int limiteObservacao = 200;

  /// Duração do slot.
  static const Duration duracaoSlot = Duration(hours: 1);

  final QuadraRepository _quadras;
  final ReservaRepository _reservas;

  final _quadra = signal<RequestState<Quadra>>(const RequestInitial());
  final _inicio = signal<DateTime?>(null);
  final _observacao = signal('');
  final _enviando = signal(false);
  final _evento = signal<EventoConfirmacao?>(null);

  int? _quadraId;
  bool _descartado = false;
  bool _concluida = false;
  int _geracao = 0;

  ReadonlySignal<RequestState<Quadra>> get quadra => _quadra;

  /// Início do slot escolhido.
  ReadonlySignal<DateTime?> get inicio => _inicio;
  ReadonlySignal<String> get observacao => _observacao;

  /// `POST /reservas` em andamento (ou já concluído, até a navegação).
  ReadonlySignal<bool> get enviando => _enviando;
  ReadonlySignal<EventoConfirmacao?> get evento => _evento;

  late final _naoEncontrada = computed(
    () => switch (_quadra.value) {
      RequestFailure(failure: final ApiFailure f) => f.naoEncontrado,
      _ => false,
    },
  );

  /// 404 ao carregar o resumo.
  ReadonlySignal<bool> get naoEncontrada => _naoEncontrada;

  late final _podeConfirmar = computed(
    () =>
        _quadra.value is RequestSuccess<Quadra> &&
        _inicio.value != null &&
        !_enviando.value &&
        _observacao.value.length <= limiteObservacao,
  );

  ReadonlySignal<bool> get podeConfirmar => _podeConfirmar;

  /// Carrega a quadra (`GET /quadras/{id}`) para o resumo.
  Future<void> carregar(int quadraId, DateTime inicio) async {
    if (_descartado) return;
    _quadraId = quadraId;
    final geracao = ++_geracao;
    batch(() {
      _inicio.value = inicio;
      _quadra.value = const RequestLoading();
    });

    final resultado = await _quadras.detalhar(quadraId);
    if (_descartado || geracao != _geracao) return;

    _quadra.value = resultado.fold(
      RequestFailure<Quadra>.new,
      RequestSuccess<Quadra>.new,
    );
  }

  /// "Tentar novamente" da caixa de erro do resumo.
  Future<void> tentarNovamente() async {
    final id = _quadraId;
    final inicio = _inicio.value;
    if (id != null && inicio != null) await carregar(id, inicio);
  }

  void alterarObservacao(String texto) {
    if (_descartado) return;
    _observacao.value = texto;
  }

  /// "Confirmar e gerar Pix". Ignora novos toques até a resposta chegar e,
  /// quando o resultado tira o usuário da tela (2xx, 409, 502, 400, 404 e
  /// as regras de horário), até a navegação (sem POST duplicado).
  Future<void> confirmar() async {
    if (_descartado || _concluida || !_podeConfirmar.value) return;
    final quadraId = _quadraId;
    final inicio = _inicio.value;
    if (quadraId == null || inicio == null) return;

    _enviando.value = true;
    final texto = _observacao.value.trim();
    final resultado = await _reservas.criar(
      quadraId: quadraId,
      inicio: inicio,
      observacao: texto.isEmpty ? null : texto,
    );
    if (_descartado) return;

    final evento = resultado.fold<EventoConfirmacao>(
      _eventoDaFalha,
      (reserva) => IrParaPagamento(reserva.id),
    );
    batch(() {
      if (evento.saiDaTela) {
        _concluida = true;
      } else {
        _enviando.value = false;
      }
      _evento.value = evento;
    });
  }

  /// Tabela "Criação da reserva" da spec reservas-cliente.
  EventoConfirmacao _eventoDaFalha(Failure failure) {
    if (failure is! ApiFailure) return FalhaConfirmacao(failure);
    final codigos = {failure.codigo, failure.subcodigo};

    if (codigos.contains('HORARIO_INDISPONIVEL') ||
        (failure.conflito && failure.codigo == null)) {
      return HorarioIndisponivel();
    }
    if (codigos.contains('RESERVA_PENDENTE_EXISTENTE')) {
      return ReservaPendenteExistente(failure.reservaId);
    }
    if (codigos.contains('PAGAMENTO_INDISPONIVEL') || failure.status == 502) {
      return PagamentoIndisponivel();
    }
    if (codigos.contains('FORA_DO_FUNCIONAMENTO') ||
        codigos.contains('DATA_FORA_DA_JANELA')) {
      return HorarioForaDaRegra(failure.message);
    }
    // 400 `VALIDACAO` no campo `inicio`: início no passado (o app sempre
    // envia hora cheia, a outra regra do campo).
    if (failure.status == 400 && failure.campos.containsKey('inicio')) {
      return InicioNoPassado();
    }
    if (failure.naoEncontrado) return QuadraIndisponivel();
    return FalhaConfirmacao(failure);
  }

  void consumirEvento() {
    if (_descartado) return;
    _evento.value = null;
  }

  void dispose() {
    if (_descartado) return;
    _descartado = true;
    _naoEncontrada.dispose();
    _podeConfirmar.dispose();
    _quadra.dispose();
    _inicio.dispose();
    _observacao.dispose();
    _enviando.dispose();
    _evento.dispose();
  }
}
