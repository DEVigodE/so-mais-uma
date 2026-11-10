import 'package:dio/dio.dart';

import '../../../config/app_config.dart';
import '../../../services/auth_service.dart';
import '../../../utils/logger.dart';
import '../../../utils/task_runner.dart';
import '../../../utils/typedefs.dart';
import '../../domain/brasilia.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/endereco_cep.dart';
import '../../domain/entities/horario_funcionamento.dart';
import '../../domain/entities/pagamento.dart';
import '../../domain/entities/quadra.dart';
import '../../domain/entities/reserva.dart';
import '../../domain/entities/slot.dart';
import '../../domain/enums.dart';
import '../../domain/repositories/repositorios.dart';
import '../json/mapeadores.dart';

/// Implementações HTTP dos contratos de `repositorios.dart`, sobre o `Dio`
/// único de [AppConfig]. O token Bearer já vai nos cabeçalhos do `Dio`.

Dio get _dio => AppConfig.dio;

Map<String, dynamic> _obj(Object? dados) =>
    dados is Map<String, dynamic> ? dados : const {};

class QuadraRepositoryImpl implements QuadraRepository {
  @override
  FutureEither<List<Quadra>> listar({TipoEsporte? esporte, String? cidade}) =>
      runTask(
        () async {
          final r = await _dio.get<Object?>('/quadras', queryParameters: {
            if (esporte != null) 'esporte': esporte.api,
            if (cidade != null && cidade.isNotEmpty) 'cidade': cidade,
          });
          return Mapeadores.lista(r.data).map(Mapeadores.quadra).toList();
        },
        operation: 'quadras.listar',
        category: LogCategory.backend,
      );

  @override
  FutureEither<List<Quadra>> minhas() => runTask(
        () async {
          final r = await _dio.get<Object?>('/quadras/minhas');
          return Mapeadores.lista(r.data).map(Mapeadores.quadra).toList();
        },
        operation: 'quadras.minhas',
        category: LogCategory.backend,
      );

  @override
  FutureEither<Quadra> detalhar(int id) => runTask(
        () async {
          final r = await _dio.get<Object?>('/quadras/$id');
          return Mapeadores.quadra(_obj(r.data));
        },
        operation: 'quadras.detalhar',
        category: LogCategory.backend,
        context: {'id': id},
      );

  @override
  FutureEither<Quadra> criar(QuadraDados dados) => runTask(
        () async {
          final r = await _dio.post<Object?>(
            '/quadras',
            data: Mapeadores.quadraDados(dados),
          );
          return Mapeadores.quadra(_obj(r.data));
        },
        operation: 'quadras.criar',
        category: LogCategory.backend,
      );

  @override
  FutureEither<Quadra> atualizar(int id, QuadraDados dados) => runTask(
        () async {
          final r = await _dio.put<Object?>(
            '/quadras/$id',
            data: Mapeadores.quadraDados(dados),
          );
          return Mapeadores.quadra(_obj(r.data));
        },
        operation: 'quadras.atualizar',
        category: LogCategory.backend,
        context: {'id': id},
      );

  @override
  FutureEither<void> desativar(int id) => runTask(
        () async {
          await _dio.delete<Object?>('/quadras/$id');
        },
        operation: 'quadras.desativar',
        category: LogCategory.backend,
        context: {'id': id},
      );
}

class CepRepositoryImpl implements CepRepository {
  @override
  FutureEither<EnderecoCep> buscar(String cep) => runTask(
        () async {
          final digitos = cep.replaceAll(RegExp(r'\D'), '');
          final r = await _dio.get<Object?>('/cep/$digitos');
          return Mapeadores.enderecoCep(_obj(r.data));
        },
        operation: 'cep.buscar',
        category: LogCategory.backend,
      );
}

class HorarioRepositoryImpl implements HorarioRepository {
  String _base(int quadraId) => '/quadras/$quadraId/horarios-funcionamento';

  @override
  FutureEither<List<HorarioFuncionamento>> listar(int quadraId) => runTask(
        () async {
          final r = await _dio.get<Object?>(_base(quadraId));
          return Mapeadores.lista(r.data).map(Mapeadores.horario).toList();
        },
        operation: 'horarios.listar',
        category: LogCategory.backend,
        context: {'quadraId': quadraId},
      );

  @override
  FutureEither<HorarioFuncionamento> criar(
    int quadraId, {
    required int diaSemana,
    required String horaAbertura,
    required String horaFechamento,
  }) =>
      runTask(
        () async {
          final r = await _dio.post<Object?>(_base(quadraId), data: {
            'diaSemana': diaSemana,
            'horaAbertura': horaAbertura,
            'horaFechamento': horaFechamento,
          });
          return Mapeadores.horario(_obj(r.data));
        },
        operation: 'horarios.criar',
        category: LogCategory.backend,
        context: {'quadraId': quadraId, 'diaSemana': diaSemana},
      );

  @override
  FutureEither<HorarioFuncionamento> atualizar(
    int quadraId,
    int horarioId, {
    required String horaAbertura,
    required String horaFechamento,
  }) =>
      runTask(
        () async {
          final r = await _dio.put<Object?>(
            '${_base(quadraId)}/$horarioId',
            data: {
              'horaAbertura': horaAbertura,
              'horaFechamento': horaFechamento,
            },
          );
          return Mapeadores.horario(_obj(r.data));
        },
        operation: 'horarios.atualizar',
        category: LogCategory.backend,
        context: {'quadraId': quadraId, 'horarioId': horarioId},
      );

  @override
  FutureEither<void> remover(int quadraId, int horarioId) => runTask(
        () async {
          await _dio.delete<Object?>('${_base(quadraId)}/$horarioId');
        },
        operation: 'horarios.remover',
        category: LogCategory.backend,
        context: {'quadraId': quadraId, 'horarioId': horarioId},
      );
}

class SlotRepositoryImpl implements SlotRepository {
  @override
  FutureEither<List<Slot>> slots(int quadraId, DateTime data) => runTask(
        () async {
          final r = await _dio.get<Object?>(
            '/quadras/$quadraId/slots',
            queryParameters: {'data': Brasilia.dataApi(data)},
          );
          return Mapeadores.lista(r.data).map(Mapeadores.slot).toList();
        },
        operation: 'slots.listar',
        category: LogCategory.backend,
        context: {'quadraId': quadraId},
      );
}

class ReservaRepositoryImpl implements ReservaRepository {
  @override
  FutureEither<List<Reserva>> listar({String? situacao}) => runTask(
        () async {
          final r = await _dio.get<Object?>('/reservas', queryParameters: {
            if (situacao != null) 'situacao': situacao,
          });
          return Mapeadores.lista(r.data).map(Mapeadores.reserva).toList();
        },
        operation: 'reservas.listar',
        category: LogCategory.backend,
      );

  @override
  FutureEither<Reserva> detalhar(int id) => runTask(
        () async {
          final r = await _dio.get<Object?>('/reservas/$id');
          return Mapeadores.reserva(_obj(r.data));
        },
        operation: 'reservas.detalhar',
        category: LogCategory.backend,
        context: {'id': id},
      );

  @override
  FutureEither<Reserva> criar({
    required int quadraId,
    required DateTime inicio,
    String? observacao,
  }) =>
      runTask(
        () async {
          final r = await _dio.post<Object?>('/reservas', data: {
            'quadraId': quadraId,
            'inicio': Brasilia.inicioApi(inicio),
            if (observacao != null && observacao.trim().isNotEmpty)
              'observacao': observacao.trim(),
          });
          return Mapeadores.reserva(_obj(r.data));
        },
        operation: 'reservas.criar',
        category: LogCategory.backend,
        context: {'quadraId': quadraId},
      );

  @override
  FutureEither<Reserva> atualizarObservacao(int id, String? observacao) =>
      runTask(
        () async {
          final texto = observacao?.trim();
          final r = await _dio.patch<Object?>('/reservas/$id', data: {
            'observacao': (texto == null || texto.isEmpty) ? null : texto,
          });
          return Mapeadores.reserva(_obj(r.data));
        },
        operation: 'reservas.atualizarObservacao',
        category: LogCategory.backend,
        context: {'id': id},
      );

  @override
  FutureEither<Reserva> cancelar(int id, String motivo) => runTask(
        () async {
          final r = await _dio.post<Object?>(
            '/reservas/$id/cancelar',
            data: {'motivo': motivo.trim()},
          );
          return Mapeadores.reserva(_obj(r.data));
        },
        operation: 'reservas.cancelar',
        category: LogCategory.backend,
        context: {'id': id},
      );

  @override
  FutureEither<List<Reserva>> agendaDaQuadra(int quadraId, {DateTime? data}) =>
      runTask(
        () async {
          final r = await _dio.get<Object?>(
            '/quadras/$quadraId/reservas',
            queryParameters: {
              if (data != null) 'data': Brasilia.dataApi(data),
            },
          );
          return Mapeadores.lista(r.data).map(Mapeadores.reserva).toList();
        },
        operation: 'reservas.agendaDaQuadra',
        category: LogCategory.backend,
        context: {'quadraId': quadraId},
      );
}

class PagamentoRepositoryImpl implements PagamentoRepository {
  @override
  FutureEither<Pagamento> estado(int reservaId) => runTask(
        () async {
          final r = await _dio.get<Object?>('/reservas/$reservaId/pagamento');
          return Mapeadores.pagamento(_obj(r.data));
        },
        operation: 'pagamento.estado',
        category: LogCategory.backend,
        context: {'reservaId': reservaId},
      );

  @override
  FutureEither<void> simular(String txid) => runTask(
        () async {
          await _dio.post<Object?>(
            '/dev/pagamentos/$txid/confirmar',
            options: Options(headers: {'X-Dev-Key': AppConfig.devKey}),
          );
        },
        operation: 'pagamento.simular',
        category: LogCategory.backend,
      );
}

class UsuarioRepositoryImpl implements UsuarioRepository {
  @override
  FutureEither<AppUser> obter() => runTask(
        () async {
          final r = await _dio.get<Object?>('/usuarios/me');
          final json = _obj(r.data);
          await AuthService.instance.publicarUsuario(json);
          return Mapeadores.usuario(json);
        },
        operation: 'usuarios.obter',
        category: LogCategory.backend,
      );

  @override
  FutureEither<AppUser> atualizar({
    required String nome,
    String? telefone,
    String? senhaAtual,
    String? novaSenha,
  }) =>
      runTask(
        () async {
          final tel = telefone?.replaceAll(RegExp(r'\D'), '');
          final r = await _dio.put<Object?>('/usuarios/me', data: {
            'nome': nome.trim(),
            'telefone': (tel == null || tel.isEmpty) ? null : tel,
            if (novaSenha != null && novaSenha.isNotEmpty) ...{
              'senhaAtual': senhaAtual,
              'novaSenha': novaSenha,
            },
          });
          final json = _obj(r.data);
          await AuthService.instance.publicarUsuario(json);
          return Mapeadores.usuario(json);
        },
        operation: 'usuarios.atualizar',
        category: LogCategory.backend,
      );
}
