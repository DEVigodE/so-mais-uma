import 'package:easy_localization/easy_localization.dart';
import 'package:signals/signals_flutter.dart';

import '../../../../shared/domain/entities/horario_funcionamento.dart';
import '../../../../shared/domain/entities/quadra.dart';
import '../../../../shared/domain/repositories/repositorios.dart';
import '../../../../utils/async_state.dart';
import '../../../../utils/failure.dart';
import '../../domain/salvar_horarios_use_case.dart';

/// Eventos de uma leitura para o contêiner (snackbar e diálogo).
sealed class EventoHorarios {
  const EventoHorarios();
}

/// "Copiar" aplicou a faixa da segunda-feira aos outros dias.
final class HorarioCopiado extends EventoHorarios {
  const HorarioCopiado();
}

/// Todas as operações do salvamento deram certo.
final class HorariosSalvos extends EventoHorarios {
  const HorariosSalvos();
}

/// Parte das operações falhou.
final class SalvamentoIncompleto extends EventoHorarios {
  const SalvamentoIncompleto({
    required this.conflitoComReservas,
    required this.pendencias,
  });

  /// Algum dia voltou ao servidor por 409 `HORARIO_COM_RESERVAS`: abre o
  /// diálogo com o atalho "Ver reservas".
  final bool conflitoComReservas;

  /// Ficaram alterações pendentes (rede, validação, dia já cadastrado): mostra
  /// "Algumas alterações não foram salvas. Tente novamente.".
  final bool pendencias;
}

/// Estado da tela HorariosQuadra (`/dono/quadras/:id/horarios`).
///
/// A edição é local até "Salvar Horários de Funcionamento"; o salvamento
/// delega ao [SalvarHorariosUseCase], que envia uma operação por dia.
class HorariosQuadraStore {
  HorariosQuadraStore(this._horarios, this._quadras, this._salvarHorarios);

  final HorarioRepository _horarios;
  final QuadraRepository _quadras;
  final SalvarHorariosUseCase _salvarHorarios;

  static const String codigoHorarioComReservas = 'HORARIO_COM_RESERVAS';
  static const String codigoDiaJaCadastrado = 'DIA_JA_CADASTRADO';

  int? _quadraId;
  bool _descartado = false;
  bool _salvouAlgo = false;

  final _carga = signal<RequestState<void>>(const RequestInitial());
  final _quadra = signal<Quadra?>(null);
  final _servidor = signal<List<HorarioFuncionamento>>(const []);
  final _dias = signal<List<FaixaDia>>(semanaDoServidor(const []));
  final _errosDia = signal<Map<int, String>>(const {});
  final _salvando = signal(false);
  final _evento = signal<EventoHorarios?>(null);

  /// Carga das faixas (a tela inteira depende dela).
  ReadonlySignal<RequestState<void>> get carga => _carga;

  /// Quadra do cartão de identificação; nula enquanto carrega ou se falhar.
  ReadonlySignal<Quadra?> get quadra => _quadra;

  /// Os 7 dias em edição, de segunda a domingo.
  ReadonlySignal<List<FaixaDia>> get dias => _dias;

  /// Mensagem por dia (validação local ou erro do servidor).
  ReadonlySignal<Map<int, String>> get errosDia => _errosDia;
  ReadonlySignal<bool> get salvando => _salvando;
  ReadonlySignal<EventoHorarios?> get evento => _evento;

  /// Operações que o salvamento enviaria agora.
  late final ReadonlySignal<List<OperacaoHorario>> operacoes = computed(
    () => calcularOperacoesHorario(
      servidor: _servidor.value,
      editado: _dias.value,
    ),
  );

  /// Há alteração não salva.
  late final ReadonlySignal<bool> alterado =
      computed(() => operacoes.value.isNotEmpty);

  /// Dias que o salvamento fecharia (pede confirmação antes).
  late final ReadonlySignal<List<int>> diasParaFechar = computed(
    () => operacoes.value
        .whereType<RemoverHorario>()
        .map((o) => o.diaSemana)
        .toList(growable: false),
  );

  late final ReadonlySignal<bool> podeSalvar =
      computed(() => alterado.value && !_salvando.value);

  /// "Copiar" exige a segunda-feira aberta.
  late final ReadonlySignal<bool> podeCopiar =
      computed(() => _dias.value.first.aberto && !_salvando.value);

  /// Quadra sem nenhuma faixa: mostra a dica para ativar os dias.
  late final ReadonlySignal<bool> semFaixas = computed(
    () => _servidor.value.isEmpty && _dias.value.every((d) => !d.aberto),
  );

  /// Algum salvamento desta abertura deu certo (resultado do `pop`).
  bool get salvouAlgo => _salvouAlgo;

  int? get quadraId => _quadraId;

  Future<void> carregar(int quadraId) async {
    _quadraId = quadraId;
    _carga.value = const RequestLoading();

    final detalhe = _quadras.detalhar(quadraId).then((r) {
      if (_descartado) return;
      r.fold((_) {}, (q) => _quadra.value = q);
    });
    final faixas = await _horarios.listar(quadraId);
    if (_descartado) return;

    faixas.fold(
      (falha) => _carga.value = RequestFailure(falha),
      (lista) => batch(() {
        _servidor.value = List.unmodifiable(lista);
        _dias.value = semanaDoServidor(lista);
        _errosDia.value = const {};
        _carga.value = const RequestSuccess(null);
      }),
    );
    await detalhe;
  }

  /// Liga ou desliga o dia. Ao ligar, usa a faixa anterior do dia nesta edição
  /// ou 08:00 às 22:00.
  void alternarDia(int diaSemana, {required bool aberto}) {
    if (_salvando.value) return;
    _alterarDia(diaSemana, (d) => d.copyWith(aberto: aberto));
  }

  void definirAbertura(int diaSemana, int hora) {
    if (_salvando.value) return;
    _alterarDia(diaSemana, (d) => d.copyWith(abertura: hora));
  }

  void definirFechamento(int diaSemana, int hora) {
    if (_salvando.value) return;
    _alterarDia(diaSemana, (d) => d.copyWith(fechamento: hora));
  }

  /// Copia a faixa da segunda-feira para os outros 6 dias e os abre.
  void copiarSegunda() {
    if (!podeCopiar.value) return;
    final segunda = _dias.value.first;
    batch(() {
      _dias.value = List.unmodifiable(
        _dias.value.map(
          (d) => d.diaSemana == segunda.diaSemana
              ? d
              : d.copyWith(
                  aberto: true,
                  abertura: segunda.abertura,
                  fechamento: segunda.fechamento,
                ),
        ),
      );
      _errosDia.value = const {};
      _evento.value = const HorarioCopiado();
    });
  }

  /// Marca os dias abertos com fechamento antes da abertura. `true` = válido.
  bool validar() {
    final erros = <int, String>{
      for (final d in _dias.value)
        if (!d.valida) d.diaSemana: 'horarios.erro_fechamento'.tr(),
    };
    _errosDia.value = Map.unmodifiable(erros);
    return erros.isEmpty;
  }

  /// Envia as operações pendentes. O contêiner pede antes a confirmação dos
  /// [diasParaFechar].
  Future<void> salvar() async {
    final quadraId = _quadraId;
    if (quadraId == null || _salvando.value || !_carga.value.isSuccess) return;
    if (!validar() || !alterado.value) return;

    _salvando.value = true;
    final resultado = await _salvarHorarios(
      quadraId: quadraId,
      servidor: _servidor.value,
      editado: _dias.value,
    );
    if (_descartado) return;

    final erros = <int, String>{};
    for (final dia in resultado.dias) {
      final falha = dia.falha;
      if (falha == null) continue;
      if (dia.status == StatusOperacao.conflito ||
          dia.status == StatusOperacao.erro) {
        erros[dia.diaSemana] = _mensagem(falha);
      }
    }
    if (resultado.algumSucesso) _salvouAlgo = true;

    batch(() {
      _servidor.value = resultado.servidor;
      _dias.value = resultado.editado;
      _errosDia.value = Map.unmodifiable(erros);
    });

    final diasJaCadastrados = resultado
        .comStatus(StatusOperacao.conflito)
        .where((d) => d.codigo == codigoDiaJaCadastrado)
        .map((d) => d.diaSemana)
        .toList();
    if (diasJaCadastrados.isNotEmpty) {
      await _recarregarServidor(diasJaCadastrados);
      if (_descartado) return;
    }

    final conflitoComReservas = resultado
        .comStatus(StatusOperacao.conflito)
        .any((d) => d.codigo == codigoHorarioComReservas);
    final pendencias = resultado.interrompido ||
        resultado.comStatus(StatusOperacao.erro).isNotEmpty ||
        diasJaCadastrados.isNotEmpty;

    batch(() {
      _salvando.value = false;
      _evento.value = resultado.concluido
          ? const HorariosSalvos()
          : SalvamentoIncompleto(
              conflitoComReservas: conflitoComReservas,
              pendencias: pendencias,
            );
    });
  }

  void consumirEvento() => _evento.value = null;

  /// 409 `DIA_JA_CADASTRADO`: relê as faixas e põe os [dias] com o valor atual
  /// do servidor, preservando as outras edições pendentes.
  Future<void> _recarregarServidor(List<int> dias) async {
    final quadraId = _quadraId;
    if (quadraId == null) return;
    final r = await _horarios.listar(quadraId);
    if (_descartado) return;
    r.fold((_) {}, (lista) {
      final atualizados = semanaDoServidor(lista);
      batch(() {
        _servidor.value = List.unmodifiable(lista);
        _dias.value = List.unmodifiable(
          _dias.value.map(
            (d) =>
                dias.contains(d.diaSemana) ? atualizados[d.diaSemana - 1] : d,
          ),
        );
      });
    });
  }

  void _alterarDia(int diaSemana, FaixaDia Function(FaixaDia) mudar) {
    batch(() {
      _dias.value = List.unmodifiable(
        _dias.value.map((d) => d.diaSemana == diaSemana ? mudar(d) : d),
      );
      if (_errosDia.value.containsKey(diaSemana)) {
        _errosDia.value = Map.unmodifiable(
          Map.of(_errosDia.value)..remove(diaSemana),
        );
      }
    });
  }

  static String _mensagem(Failure falha) {
    if (falha is ApiFailure && falha.campos.isNotEmpty) {
      return falha.campos.values.where((m) => m.isNotEmpty).join('\n');
    }
    return falha.message;
  }

  void dispose() {
    _descartado = true;
    operacoes.dispose();
    alterado.dispose();
    diasParaFechar.dispose();
    podeSalvar.dispose();
    podeCopiar.dispose();
    semFaixas.dispose();
    _carga.dispose();
    _quadra.dispose();
    _servidor.dispose();
    _dias.dispose();
    _errosDia.dispose();
    _salvando.dispose();
    _evento.dispose();
  }
}
