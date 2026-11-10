import 'package:equatable/equatable.dart';

import '../../../../shared/domain/entities/horario_funcionamento.dart';

/// Linha do cartão "Horários de Funcionamento": dias consecutivos (ISO,
/// 1 = segunda ... 7 = domingo) com a mesma faixa ou fechados.
class GrupoFuncionamento extends Equatable {
  const GrupoFuncionamento({
    required this.primeiroDia,
    required this.ultimoDia,
    this.abertura,
    this.fechamento,
  });

  final int primeiroDia;
  final int ultimoDia;

  /// "HH:mm"; `null` quando o grupo está fechado.
  final String? abertura;

  /// "HH:mm"; `null` quando o grupo está fechado.
  final String? fechamento;

  bool get fechado => abertura == null;
  int get quantidadeDias => ultimoDia - primeiroDia + 1;

  @override
  List<Object?> get props => [primeiroDia, ultimoDia, abertura, fechamento];
}

/// Agrupa as faixas de funcionamento (design D14).
///
/// Percorre os dias de segunda (1) a domingo (7); cada dia vale a sua faixa
/// `(abertura, fechamento)` ou "fechado" (dia sem registro). Dias consecutivos
/// com o mesmo valor viram um grupo. Como a semana começa na segunda, domingo
/// nunca se junta à segunda seguinte. Sem nenhuma faixa, devolve lista vazia
/// (o cartão mostra "Esta quadra ainda não tem horários cadastrados").
List<GrupoFuncionamento> agruparHorarios(List<HorarioFuncionamento> horarios) {
  if (horarios.isEmpty) return const [];

  (String, String)? faixaDo(int dia) {
    for (final h in horarios) {
      if (h.diaSemana == dia) return (h.horaAbertura, h.horaFechamento);
    }
    return null;
  }

  final grupos = <GrupoFuncionamento>[];
  var inicio = 1;
  var atual = faixaDo(1);
  for (var dia = 2; dia <= 8; dia++) {
    final valor = dia <= 7 ? faixaDo(dia) : null;
    if (dia == 8 || valor != atual) {
      grupos.add(GrupoFuncionamento(
        primeiroDia: inicio,
        ultimoDia: dia - 1,
        abertura: atual?.$1,
        fechamento: atual?.$2,
      ));
      inicio = dia;
      atual = valor;
    }
  }
  return grupos;
}

/// Rótulo dos dias do grupo: o nome do dia (1 dia), `"<a> e <b>"` (2 dias) ou
/// `"<primeiro> a <último>"` (3 ou mais). Os nomes e os conectores vêm de fora
/// para a função não depender do idioma.
String rotuloDiasDoGrupo(
  GrupoFuncionamento grupo, {
  required String Function(int diaSemana) nomeDia,
  required String Function(String primeiro, String segundo) doisDias,
  required String Function(String primeiro, String ultimo) intervalo,
}) {
  final primeiro = nomeDia(grupo.primeiroDia);
  return switch (grupo.quantidadeDias) {
    1 => primeiro,
    2 => doisDias(primeiro, nomeDia(grupo.ultimoDia)),
    _ => intervalo(primeiro, nomeDia(grupo.ultimoDia)),
  };
}
