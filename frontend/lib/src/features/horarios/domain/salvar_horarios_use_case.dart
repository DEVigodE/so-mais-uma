import 'package:equatable/equatable.dart';

import '../../../shared/domain/entities/horario_funcionamento.dart';
import '../../../shared/domain/repositories/repositorios.dart';
import '../../../utils/failure.dart';
import '../../../utils/typedefs.dart';

/// Funcionamento de um dia da semana na edição da tela de horários.
///
/// As horas são sempre cheias. Um dia fechado guarda as últimas horas usadas,
/// para reabrir com a mesma faixa (ou 08:00 às 22:00 quando nunca teve uma).
class FaixaDia extends Equatable {
  const FaixaDia({
    required this.diaSemana,
    required this.aberto,
    this.abertura = aberturaPadrao,
    this.fechamento = fechamentoPadrao,
  });

  /// Dia como está no servidor: com a faixa, aberto; sem ela, fechado.
  factory FaixaDia.doServidor(int diaSemana, HorarioFuncionamento? horario) =>
      horario == null
          ? FaixaDia(diaSemana: diaSemana, aberto: false)
          : FaixaDia(
              diaSemana: diaSemana,
              aberto: true,
              abertura: horario.aberturaHora,
              fechamento: horario.fechamentoHora,
            );

  static const int aberturaPadrao = 8;
  static const int fechamentoPadrao = 22;

  /// Opções de abertura: 00:00 a 22:00.
  static const int aberturaMinima = 0;
  static const int aberturaMaxima = 22;

  /// Opções de fechamento: 01:00 a 23:00 (o 00:00 viola a RN19 no backend).
  static const int fechamentoMinimo = 1;
  static const int fechamentoMaximo = 23;

  /// 1 = segunda ... 7 = domingo.
  final int diaSemana;
  final bool aberto;
  final int abertura;
  final int fechamento;

  /// Dia aberto exige fechamento depois da abertura.
  bool get valida => !aberto || fechamento > abertura;

  String get horaAbertura => HorarioFuncionamento.hora(abertura);
  String get horaFechamento => HorarioFuncionamento.hora(fechamento);

  FaixaDia copyWith({bool? aberto, int? abertura, int? fechamento}) => FaixaDia(
        diaSemana: diaSemana,
        aberto: aberto ?? this.aberto,
        abertura: abertura ?? this.abertura,
        fechamento: fechamento ?? this.fechamento,
      );

  @override
  List<Object?> get props => [diaSemana, aberto, abertura, fechamento];
}

/// Operação individual enviada ao backend para um dia.
sealed class OperacaoHorario extends Equatable {
  const OperacaoHorario(this.diaSemana);

  final int diaSemana;
}

/// `POST /quadras/{id}/horarios-funcionamento`: dia aberto sem faixa no servidor.
final class CriarHorario extends OperacaoHorario {
  const CriarHorario(
    super.diaSemana, {
    required this.horaAbertura,
    required this.horaFechamento,
  });

  final String horaAbertura;
  final String horaFechamento;

  @override
  List<Object?> get props => [diaSemana, horaAbertura, horaFechamento];
}

/// `PUT /quadras/{id}/horarios-funcionamento/{hid}`: faixa alterada.
final class AtualizarHorario extends OperacaoHorario {
  const AtualizarHorario(
    super.diaSemana, {
    required this.horarioId,
    required this.horaAbertura,
    required this.horaFechamento,
  });

  final int horarioId;
  final String horaAbertura;
  final String horaFechamento;

  @override
  List<Object?> get props =>
      [diaSemana, horarioId, horaAbertura, horaFechamento];
}

/// `DELETE /quadras/{id}/horarios-funcionamento/{hid}`: dia fechado que tinha faixa.
final class RemoverHorario extends OperacaoHorario {
  const RemoverHorario(super.diaSemana, {required this.horarioId});

  final int horarioId;

  @override
  List<Object?> get props => [diaSemana, horarioId];
}

/// Compara o servidor com a edição e monta as operações, de segunda a domingo.
///
/// Dia ausente em [editado] conta como fechado. Faixa do servidor sem `id`
/// não pode ser endereçada e é ignorada.
List<OperacaoHorario> calcularOperacoesHorario({
  required List<HorarioFuncionamento> servidor,
  required List<FaixaDia> editado,
}) {
  final operacoes = <OperacaoHorario>[];
  for (var dia = 1; dia <= 7; dia++) {
    final atual = _horarioDoDia(servidor, dia);
    final novo = _faixaDoDia(editado, dia);
    final aberto = novo?.aberto ?? false;

    if (atual == null) {
      if (aberto) {
        operacoes.add(CriarHorario(
          dia,
          horaAbertura: novo!.horaAbertura,
          horaFechamento: novo.horaFechamento,
        ));
      }
      continue;
    }

    final id = atual.id;
    if (id == null) continue;
    if (!aberto) {
      operacoes.add(RemoverHorario(dia, horarioId: id));
    } else if (atual.aberturaHora != novo!.abertura ||
        atual.fechamentoHora != novo.fechamento) {
      operacoes.add(AtualizarHorario(
        dia,
        horarioId: id,
        horaAbertura: novo.horaAbertura,
        horaFechamento: novo.horaFechamento,
      ));
    }
  }
  return operacoes;
}

/// Resultado de uma operação dentro do salvamento em lote.
enum StatusOperacao {
  /// 2xx: a faixa do dia ficou salva.
  sucesso,

  /// 409 (`HORARIO_COM_RESERVAS` ou `DIA_JA_CADASTRADO`): só este dia volta ao
  /// valor do servidor.
  conflito,

  /// Outro erro da API (400, 403, 404, 5xx): o dia continua pendente.
  erro,

  /// Sem conexão: interrompe a sequência; o dia continua pendente.
  falhaRede,

  /// Não enviada porque uma falha de rede anterior interrompeu a sequência.
  naoEnviada,
}

class ResultadoDia extends Equatable {
  const ResultadoDia(this.operacao, this.status, {this.falha});

  final OperacaoHorario operacao;
  final StatusOperacao status;
  final Failure? falha;

  int get diaSemana => operacao.diaSemana;

  /// Código do `ApiFailure` (ex.: `HORARIO_COM_RESERVAS`), quando houver.
  String? get codigo => switch (falha) {
        final ApiFailure f => f.codigo,
        _ => null,
      };

  @override
  List<Object?> get props => [operacao, status, falha];
}

class ResultadoSalvarHorarios extends Equatable {
  const ResultadoSalvarHorarios({
    required this.dias,
    required this.servidor,
    required this.editado,
  });

  /// Uma entrada por operação, na ordem em que foram tentadas.
  final List<ResultadoDia> dias;

  /// Faixas do servidor depois das operações que deram certo.
  final List<HorarioFuncionamento> servidor;

  /// Edição com os dias em conflito revertidos ao valor do servidor.
  final List<FaixaDia> editado;

  bool get concluido => dias.every((d) => d.status == StatusOperacao.sucesso);

  bool get algumSucesso => dias.any((d) => d.status == StatusOperacao.sucesso);

  /// Uma falha de rede interrompeu a sequência.
  bool get interrompido =>
      dias.any((d) => d.status == StatusOperacao.falhaRede);

  Iterable<ResultadoDia> comStatus(StatusOperacao status) =>
      dias.where((d) => d.status == status);

  @override
  List<Object?> get props => [dias, servidor, editado];
}

/// Salva os horários de uma quadra com uma operação individual por dia
/// (POST, PUT ou DELETE), em sequência de segunda a domingo.
///
/// Cada erro afeta só o seu dia: um 409 reverte apenas aquela linha ao valor
/// do servidor, outros erros da API deixam a linha pendente e a sequência
/// continua; uma falha de rede interrompe a sequência e as operações seguintes
/// ficam como não enviadas. As operações que deram certo permanecem salvas.
///
/// Não segue `UseCase<P, R>` porque o resultado é sempre parcial (por dia), e
/// não um `Either` de sucesso ou falha total.
class SalvarHorariosUseCase {
  SalvarHorariosUseCase(this._repositorio);

  final HorarioRepository _repositorio;

  Future<ResultadoSalvarHorarios> call({
    required int quadraId,
    required List<HorarioFuncionamento> servidor,
    required List<FaixaDia> editado,
  }) async {
    final operacoes =
        calcularOperacoesHorario(servidor: servidor, editado: editado);
    final servidorPorDia = {for (final h in servidor) h.diaSemana: h};
    final editadoPorDia = {for (final f in editado) f.diaSemana: f};
    final resultados = <ResultadoDia>[];
    var interrompido = false;

    for (final operacao in operacoes) {
      final dia = operacao.diaSemana;
      if (interrompido) {
        resultados.add(ResultadoDia(operacao, StatusOperacao.naoEnviada));
        continue;
      }

      final resposta = await _executar(quadraId, operacao);
      resposta.fold(
        (falha) {
          final status = _classificar(falha);
          if (status == StatusOperacao.falhaRede) interrompido = true;
          if (status == StatusOperacao.conflito) {
            editadoPorDia[dia] =
                _reverter(dia, servidorPorDia[dia], editadoPorDia[dia]);
          }
          resultados.add(ResultadoDia(operacao, status, falha: falha));
        },
        (salvo) {
          if (salvo == null) {
            servidorPorDia.remove(dia);
          } else {
            servidorPorDia[dia] = salvo;
          }
          resultados.add(ResultadoDia(operacao, StatusOperacao.sucesso));
        },
      );
    }

    final servidorFinal = servidorPorDia.values.toList()
      ..sort((a, b) => a.diaSemana.compareTo(b.diaSemana));
    final editadoFinal = editadoPorDia.values.toList()
      ..sort((a, b) => a.diaSemana.compareTo(b.diaSemana));
    return ResultadoSalvarHorarios(
      dias: List.unmodifiable(resultados),
      servidor: List.unmodifiable(servidorFinal),
      editado: List.unmodifiable(editadoFinal),
    );
  }

  /// Executa a operação; o valor é a faixa salva (nulo na remoção).
  FutureEither<HorarioFuncionamento?> _executar(
    int quadraId,
    OperacaoHorario operacao,
  ) async {
    switch (operacao) {
      case CriarHorario(
          :final diaSemana,
          :final horaAbertura,
          :final horaFechamento
        ):
        final r = await _repositorio.criar(
          quadraId,
          diaSemana: diaSemana,
          horaAbertura: horaAbertura,
          horaFechamento: horaFechamento,
        );
        return r.map<HorarioFuncionamento?>((h) => h);
      case AtualizarHorario(
          :final horarioId,
          :final horaAbertura,
          :final horaFechamento
        ):
        final r = await _repositorio.atualizar(
          quadraId,
          horarioId,
          horaAbertura: horaAbertura,
          horaFechamento: horaFechamento,
        );
        return r.map<HorarioFuncionamento?>((h) => h);
      case RemoverHorario(:final horarioId):
        final r = await _repositorio.remover(quadraId, horarioId);
        return r.map<HorarioFuncionamento?>((_) => null);
    }
  }

  static StatusOperacao _classificar(Failure falha) => switch (falha) {
        NetworkFailure() => StatusOperacao.falhaRede,
        ApiFailure(conflito: true) => StatusOperacao.conflito,
        _ => StatusOperacao.erro,
      };

  /// Volta o dia ao servidor; sem faixa lá, fecha o dia mantendo as horas
  /// digitadas para uma reabertura.
  static FaixaDia _reverter(
    int dia,
    HorarioFuncionamento? servidor,
    FaixaDia? editado,
  ) {
    if (servidor != null) return FaixaDia.doServidor(dia, servidor);
    return (editado ?? FaixaDia(diaSemana: dia, aberto: false))
        .copyWith(aberto: false);
  }
}

HorarioFuncionamento? _horarioDoDia(List<HorarioFuncionamento> lista, int dia) {
  for (final h in lista) {
    if (h.diaSemana == dia) return h;
  }
  return null;
}

FaixaDia? _faixaDoDia(List<FaixaDia> lista, int dia) {
  for (final f in lista) {
    if (f.diaSemana == dia) return f;
  }
  return null;
}

/// Os 7 dias montados a partir das faixas do servidor.
List<FaixaDia> semanaDoServidor(List<HorarioFuncionamento> servidor) =>
    List.unmodifiable([
      for (var dia = 1; dia <= 7; dia++)
        FaixaDia.doServidor(dia, _horarioDoDia(servidor, dia)),
    ]);
