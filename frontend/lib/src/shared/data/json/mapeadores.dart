import '../../domain/entities/app_user.dart';
import '../../domain/entities/endereco_cep.dart';
import '../../domain/entities/horario_funcionamento.dart';
import '../../domain/entities/pagamento.dart';
import '../../domain/entities/quadra.dart';
import '../../domain/entities/reserva.dart';
import '../../domain/entities/slot.dart';
import '../../domain/enums.dart';

/// JSON escrito à mão (sem build_runner). Campos extras são ignorados e enums
/// desconhecidos caem no fallback de cada enum.
abstract final class Mapeadores {
  static Quadra quadra(Map<String, dynamic> j) => Quadra(
        id: _int(j['id']) ?? 0,
        donoId: _int(j['donoId']),
        nome: _str(j['nome']) ?? '',
        descricao: _str(j['descricao']),
        tipoEsporte: TipoEsporte.fromApi(j['tipoEsporte']),
        precoHora: dinheiro(j['precoHora']),
        cep: _str(j['cep']) ?? '',
        logradouro: _str(j['logradouro']) ?? '',
        numero: _str(j['numero']) ?? '',
        bairro: _str(j['bairro']),
        cidade: _str(j['cidade']) ?? '',
        uf: _str(j['uf']) ?? '',
        latitude: _double(j['latitude']),
        longitude: _double(j['longitude']),
        fotoUrl: _str(j['fotoUrl']),
        ativa: j['ativa'] is bool ? j['ativa'] as bool : true,
        atualizadoEm: _data(j['atualizadoEm']),
        horarios: _lista(j['horariosFuncionamento'])
            .map(horario)
            .toList(growable: false),
      );

  static Map<String, dynamic> quadraDados(QuadraDados d) => {
        'nome': d.nome,
        if (d.descricao != null && d.descricao!.isNotEmpty)
          'descricao': d.descricao,
        'tipoEsporte': d.tipoEsporte.api,
        'precoHora': d.precoHora.toStringAsFixed(2),
        'cep': d.cep,
        'logradouro': d.logradouro,
        'numero': d.numero,
        if (d.bairro != null && d.bairro!.isNotEmpty) 'bairro': d.bairro,
        'cidade': d.cidade,
        'uf': d.uf,
        if (d.latitude != null) 'latitude': d.latitude,
        if (d.longitude != null) 'longitude': d.longitude,
        if (d.fotoUrl != null && d.fotoUrl!.isNotEmpty) 'fotoUrl': d.fotoUrl,
      };

  static HorarioFuncionamento horario(Map<String, dynamic> j) =>
      HorarioFuncionamento(
        id: _int(j['id']),
        quadraId: _int(j['quadraId']),
        diaSemana: _int(j['diaSemana']) ?? 0,
        horaAbertura: _hora(j['horaAbertura']),
        horaFechamento: _hora(j['horaFechamento']),
      );

  static Slot slot(Map<String, dynamic> j) => Slot(
        inicio: _data(j['inicio']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        fim: _data(j['fim']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        status: StatusSlot.fromApi(j['status']),
        valor: dinheiro(j['valor']),
      );

  static Pagamento pagamento(Map<String, dynamic> j) => Pagamento(
        txid: _str(j['txid']) ?? '',
        status: StatusPagamento.fromApi(j['status']),
        provedor: ProvedorPagamento.fromApi(j['provedor']),
        valor: dinheiro(j['valor']),
        pixCopiaECola: _str(j['pixCopiaECola']),
        expiraEm: _data(j['expiraEm']),
        pagoEm: _data(j['pagoEm']),
      );

  static Reserva reserva(Map<String, dynamic> j) => Reserva(
        id: _int(j['id']) ?? 0,
        quadraId: _int(j['quadraId']) ?? 0,
        quadraNome: _str(j['quadraNome']) ?? '',
        quadraEndereco: _str(j['quadraEndereco']),
        clienteId: _int(j['clienteId']),
        clienteNome: _str(j['clienteNome']),
        clienteTelefone: _str(j['clienteTelefone']),
        inicio: _data(j['inicio']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        fim: _data(j['fim']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        status: StatusReserva.fromApi(j['status']),
        valor: dinheiro(j['valor']),
        observacao: _str(j['observacao']),
        expiraEm: _data(j['expiraEm']),
        criadoEm: _data(j['criadoEm']),
        canceladoEm: _data(j['canceladoEm']),
        canceladoPor: CanceladoPor.fromApi(j['canceladoPor']),
        motivoCancelamento: _str(j['motivoCancelamento']),
        pagamento: j['pagamento'] is Map<String, dynamic>
            ? pagamento(j['pagamento'] as Map<String, dynamic>)
            : null,
      );

  static EnderecoCep enderecoCep(Map<String, dynamic> j) => EnderecoCep(
        cep: _str(j['cep']) ?? '',
        logradouro: _str(j['logradouro']),
        bairro: _str(j['bairro']),
        cidade: _str(j['cidade']),
        uf: _str(j['uf']),
        latitude: _double(j['latitude']),
        longitude: _double(j['longitude']),
        fonte: FonteCep.fromApi(j['fonte']),
      );

  /// `UsuarioResponse`.
  static AppUser usuario(Map<String, dynamic> j) => AppUser(
        id: _str(j['id']) ?? '',
        email: _str(j['email']) ?? '',
        name: _str(j['nome']),
        perfil: PerfilUsuario.fromApi(j['perfil']),
        telefone: _str(j['telefone']),
        criadoEm: _data(j['criadoEm']),
      );

  /// Lê uma lista de objetos JSON de uma resposta.
  static List<Map<String, dynamic>> lista(Object? dados) => _lista(dados);

  /// Dinheiro chega como string decimal ("80.00").
  static double dinheiro(Object? v) => switch (v) {
        final num n => n.toDouble(),
        final String s => double.tryParse(s) ?? 0,
        _ => 0,
      };

  static List<Map<String, dynamic>> _lista(Object? v) => v is List
      ? v.whereType<Map<String, dynamic>>().toList(growable: false)
      : const [];

  static String? _str(Object? v) => v?.toString();

  static int? _int(Object? v) => switch (v) {
        final int i => i,
        final num n => n.toInt(),
        final String s => int.tryParse(s),
        _ => null,
      };

  static double? _double(Object? v) => switch (v) {
        final num n => n.toDouble(),
        final String s => double.tryParse(s),
        _ => null,
      };

  static DateTime? _data(Object? v) =>
      v == null ? null : DateTime.tryParse(v.toString());

  /// "08:00" ou "08:00:00" -> "08:00".
  static String _hora(Object? v) {
    final s = v?.toString() ?? '00:00';
    return s.length >= 5 ? s.substring(0, 5) : s;
  }
}
