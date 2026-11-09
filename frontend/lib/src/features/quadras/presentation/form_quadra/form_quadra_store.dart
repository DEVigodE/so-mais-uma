import 'package:easy_localization/easy_localization.dart';
import 'package:signals/signals_flutter.dart';

import '../../../../shared/domain/entities/endereco_cep.dart';
import '../../../../shared/domain/entities/quadra.dart';
import '../../../../shared/domain/enums.dart';
import '../../../../shared/domain/repositories/repositorios.dart';
import '../../../../shared/formatters/formatadores.dart';
import '../../../../utils/async_state.dart';
import '../../../../utils/failure.dart';
import 'form_quadra_campos.dart';

/// Situação da busca de endereço pelo CEP.
sealed class EstadoCep {
  const EstadoCep();
}

final class CepOcioso extends EstadoCep {
  const CepOcioso();
}

/// "Buscando..." no botão.
final class CepBuscando extends EstadoCep {
  const CepBuscando();
}

/// "Endereço encontrado via BrasilAPI/ViaCEP".
final class CepEncontrado extends EstadoCep {
  const CepEncontrado(this.fonte);

  final FonteCep? fonte;
}

/// 503 `CEP_INDISPONIVEL` ou sem conexão: aviso e preenchimento manual.
final class CepIndisponivel extends EstadoCep {
  const CepIndisponivel(this.mensagem);

  final String mensagem;
}

/// Eventos de uma leitura para o contêiner.
sealed class EventoFormQuadra {
  const EventoFormQuadra();
}

/// 2xx: `Quadra "<nome>" salva com sucesso!` e `pop(true)`.
final class QuadraSalva extends EventoFormQuadra {
  const QuadraSalva(this.nome);

  final String nome;
}

/// Põe o foco no primeiro campo inválido.
final class FocarCampo extends EventoFormQuadra {
  const FocarCampo(this.campo);

  final CampoQuadra campo;
}

/// 403: "Você não tem permissão para isso" e volta.
final class SemPermissaoFormQuadra extends EventoFormQuadra {
  const SemPermissaoFormQuadra();
}

/// Outra falha ao salvar (rede, 5xx...).
final class FalhaFormQuadra extends EventoFormQuadra {
  const FalhaFormQuadra(this.mensagem);

  final String mensagem;
}

/// Estado da FormQuadra (`/dono/quadras/nova` e `/dono/quadras/:id/editar`).
///
/// Os `TextEditingController` ficam no contêiner: ele repassa cada digitação
/// com [alterar] e, quando [versaoExterna] muda (carga da edição, CEP), copia
/// [campos] de volta para os controladores.
class FormQuadraStore {
  FormQuadraStore(this._quadras, this._cepRepositorio);

  final QuadraRepository _quadras;
  final CepRepository _cepRepositorio;

  static const String codigoCepIndisponivel = 'CEP_INDISPONIVEL';

  int? _quadraId;
  String? _ultimoCepBuscado;
  bool _descartado = false;

  final _carga = signal<RequestState<void>>(const RequestInitial());
  final _campos = signal(const FormQuadraCampos());
  final _inicial = signal(const FormQuadraCampos());
  final _versaoExterna = signal(0);
  final _erros = signal<Map<CampoQuadra, String>>(const {});
  final _cep = signal<EstadoCep>(const CepOcioso());
  final _coordenadasAuto = signal(false);
  final _urlPreview = signal('');
  final _salvando = signal(false);
  final _salvo = signal(false);
  final _evento = signal<EventoFormQuadra?>(null);

  /// Carga da quadra na edição (na criação vira sucesso na hora).
  ReadonlySignal<RequestState<void>> get carga => _carga;
  ReadonlySignal<FormQuadraCampos> get campos => _campos;

  /// Muda quando o store preenche campos sem digitação (edição, CEP).
  ReadonlySignal<int> get versaoExterna => _versaoExterna;

  /// Mensagem por campo (validação local ou `campos[]` do 400).
  ReadonlySignal<Map<CampoQuadra, String>> get erros => _erros;
  ReadonlySignal<EstadoCep> get estadoCep => _cep;

  /// Coordenadas vieram do CEP ("Preenchido auto").
  ReadonlySignal<bool> get coordenadasAuto => _coordenadasAuto;

  /// URL aplicada na pré-visualização (botão de recarregar).
  ReadonlySignal<String> get urlPreview => _urlPreview;
  ReadonlySignal<bool> get salvando => _salvando;
  ReadonlySignal<EventoFormQuadra?> get evento => _evento;

  bool get edicao => _quadraId != null;

  late final ReadonlySignal<bool> alterado =
      computed(() => _campos.value != _inicial.value);

  /// Sair sem perguntar: nada alterado ou já salvo.
  late final ReadonlySignal<bool> podeSair =
      computed(() => !alterado.value || _salvo.value);

  /// "Buscar CEP" habilitado com 8 dígitos e sem busca em andamento.
  late final ReadonlySignal<bool> podeBuscarCep = computed(
    () =>
        Formatadores.digitos(_campos.value.cep).length == 8 &&
        _cep.value is! CepBuscando,
  );

  /// `null` = nova quadra; id = edição (`GET /quadras/{id}`).
  Future<void> carregar(int? quadraId) async {
    _quadraId = quadraId;
    if (quadraId == null) {
      _carga.value = const RequestSuccess(null);
      return;
    }
    _carga.value = const RequestLoading();
    final r = await _quadras.detalhar(quadraId);
    if (_descartado) return;
    r.fold(
      (falha) => batch(() {
        _carga.value = RequestFailure(falha);
        if (falha is ApiFailure && falha.status == 403) {
          _evento.value = const SemPermissaoFormQuadra();
        }
      }),
      _preencherEdicao,
    );
  }

  void alterar(CampoQuadra campo, String valor) {
    if (_campos.value.texto(campo) == valor) return;
    batch(() {
      _campos.value = _campos.value.comTexto(campo, valor);
      _limparErro(campo);
      switch (campo) {
        case CampoQuadra.latitude || CampoQuadra.longitude:
          _limparErro(CampoQuadra.latitude);
          _limparErro(CampoQuadra.longitude);
          _coordenadasAuto.value = false;
        case CampoQuadra.cep:
          if (_cep.value is! CepBuscando) _cep.value = const CepOcioso();
        case CampoQuadra.fotoUrl:
          if (valor.trim().isEmpty) _urlPreview.value = '';
        default:
          break;
      }
    });

    if (campo == CampoQuadra.cep) {
      final digitos = Formatadores.digitos(valor);
      if (digitos.length == 8 && digitos != _ultimoCepBuscado) buscarCep();
    }
  }

  void selecionarEsporte(TipoEsporte? esporte) {
    batch(() {
      _campos.value = _campos.value.comEsporte(esporte);
      _limparErro(CampoQuadra.esporte);
    });
  }

  /// `GET /cep/{cep}` do backend (nunca BrasilAPI/ViaCEP direto).
  Future<void> buscarCep() async {
    final digitos = Formatadores.digitos(_campos.value.cep);
    if (digitos.length != 8 || _cep.value is CepBuscando) return;
    _ultimoCepBuscado = digitos;
    batch(() {
      _cep.value = const CepBuscando();
      _limparErro(CampoQuadra.cep);
    });

    final r = await _cepRepositorio.buscar(digitos);
    if (_descartado) return;

    final atual = Formatadores.digitos(_campos.value.cep);
    if (atual != digitos) {
      // O dono trocou o CEP durante a busca: descarta e busca o novo.
      _cep.value = const CepOcioso();
      if (atual.length == 8) buscarCep();
      return;
    }

    r.fold(_falhaCep, _aplicarEndereco);
  }

  /// Aplica a URL digitada na pré-visualização.
  void atualizarPreview() => _urlPreview.value = _campos.value.fotoUrl.trim();

  /// Valida e envia `POST /quadras` ou `PUT /quadras/{id}`.
  Future<void> salvar() async {
    if (_salvando.value || !_carga.value.isSuccess) return;
    final erros = validarQuadra(_campos.value);
    if (erros.isNotEmpty) {
      _mostrarErros(erros);
      return;
    }

    _salvando.value = true;
    final dados = montarQuadraDados(_campos.value);
    final id = _quadraId;
    final r = id == null
        ? await _quadras.criar(dados)
        : await _quadras.atualizar(id, dados);
    if (_descartado) return;

    r.fold(
      (falha) => batch(() {
        _salvando.value = false;
        _tratarFalhaAoSalvar(falha);
      }),
      (quadra) => batch(() {
        _salvando.value = false;
        _salvo.value = true;
        _evento.value = QuadraSalva(quadra.nome);
      }),
    );
  }

  void consumirEvento() => _evento.value = null;

  void _preencherEdicao(Quadra quadra) {
    final campos = FormQuadraCampos.daQuadra(quadra);
    _ultimoCepBuscado = Formatadores.digitos(quadra.cep);
    batch(() {
      _campos.value = campos;
      _inicial.value = campos;
      _urlPreview.value = campos.fotoUrl;
      _erros.value = const {};
      _versaoExterna.value++;
      _carga.value = const RequestSuccess(null);
    });
  }

  void _aplicarEndereco(EnderecoCep endereco) {
    final campos = _campos.value.comEndereco(endereco);
    batch(() {
      _campos.value = campos;
      _coordenadasAuto.value = campos.latitude.isNotEmpty;
      _cep.value = CepEncontrado(endereco.fonte);
      for (final c in const [
        CampoQuadra.logradouro,
        CampoQuadra.bairro,
        CampoQuadra.cidade,
        CampoQuadra.uf,
        CampoQuadra.latitude,
        CampoQuadra.longitude,
      ]) {
        _limparErro(c);
      }
      _versaoExterna.value++;
    });
  }

  void _falhaCep(Failure falha) {
    batch(() {
      switch (falha) {
        case ApiFailure(status: 404):
          _cep.value = const CepOcioso();
          _definirErro(CampoQuadra.cep, 'quadras.form.cep_nao_encontrado'.tr());
        case ApiFailure(status: 400):
          _cep.value = const CepOcioso();
          _definirErro(CampoQuadra.cep, 'quadras.form.cep_invalido'.tr());
        case ApiFailure(status: 503) ||
              ApiFailure(codigo: codigoCepIndisponivel):
          _cep.value = CepIndisponivel('quadras.form.cep_indisponivel'.tr());
        default:
          _cep.value = CepIndisponivel(falha.message);
      }
    });
  }

  void _tratarFalhaAoSalvar(Failure falha) {
    switch (falha) {
      case ApiFailure(status: 400, :final campos) when campos.isNotEmpty:
        final erros = <CampoQuadra, String>{};
        for (final MapEntry(:key, :value) in campos.entries) {
          final campo = CampoQuadra.daApi(key);
          if (campo != null && !erros.containsKey(campo)) {
            erros[campo] = value.isEmpty ? falha.message : value;
          }
        }
        if (erros.isEmpty) {
          _evento.value = FalhaFormQuadra(falha.message);
        } else {
          _mostrarErros(erros);
        }
      case ApiFailure(status: 403):
        _evento.value = const SemPermissaoFormQuadra();
      case ApiFailure(status: 404):
        _carga.value = RequestFailure(falha);
      default:
        _evento.value = FalhaFormQuadra(falha.message);
    }
  }

  void _mostrarErros(Map<CampoQuadra, String> erros) {
    final primeiro = CampoQuadra.values.firstWhere(erros.containsKey);
    batch(() {
      _erros.value = Map.unmodifiable(erros);
      _evento.value = FocarCampo(primeiro);
    });
  }

  void _definirErro(CampoQuadra campo, String mensagem) {
    _erros.value = Map.unmodifiable({..._erros.value, campo: mensagem});
  }

  void _limparErro(CampoQuadra campo) {
    if (!_erros.value.containsKey(campo)) return;
    _erros.value = Map.unmodifiable(Map.of(_erros.value)..remove(campo));
  }

  void dispose() {
    _descartado = true;
    alterado.dispose();
    podeSair.dispose();
    podeBuscarCep.dispose();
    _carga.dispose();
    _campos.dispose();
    _inicial.dispose();
    _versaoExterna.dispose();
    _erros.dispose();
    _cep.dispose();
    _coordenadasAuto.dispose();
    _urlPreview.dispose();
    _salvando.dispose();
    _salvo.dispose();
    _evento.dispose();
  }
}
