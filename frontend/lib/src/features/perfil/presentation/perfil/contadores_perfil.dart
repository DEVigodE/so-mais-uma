import 'package:equatable/equatable.dart';

import '../../../../shared/domain/entities/quadra.dart';
import '../../../../shared/domain/entities/reserva.dart';
import '../../../../shared/domain/enums.dart';

/// Contadores do cartão do Perfil (design D14). Funções puras.

/// Um contador da faixa: rótulo (chave de tradução) e valor.
class ContadorPerfil extends Equatable {
  const ContadorPerfil(this.rotuloKey, this.valor);

  final String rotuloKey;
  final int valor;

  @override
  List<Object?> get props => [rotuloKey, valor];
}

/// "Jogos" do CLIENTE: reservas `CONFIRMADA` que já terminaram.
int contarJogos(Iterable<Reserva> reservas, DateTime agora) =>
    reservas.where((r) => r.concluida(agora)).length;

/// "Arenas" do CLIENTE: quadras distintas entre os jogos.
int contarArenas(Iterable<Reserva> reservas, DateTime agora) => reservas
    .where((r) => r.concluida(agora))
    .map((r) => r.quadraId)
    .toSet()
    .length;

/// "Reservas" do DONO: reservas `CONFIRMADA` recebidas (a API devolve os
/// últimos 12 meses e as futuras).
int contarReservasConfirmadas(Iterable<Reserva> reservas) =>
    reservas.where((r) => r.status == StatusReserva.confirmada).length;

/// Contadores do perfil. Cada contador só aparece quando a fonte dele chegou
/// (`null` = não carregada): número sem dado é omitido.
///
/// - CLIENTE: "Jogos" e "Arenas", de [reservas];
/// - DONO: "Quadras" (tamanho de [quadras], escopo MINHAS) e "Reservas".
List<ContadorPerfil> calcularContadoresPerfil({
  required PerfilUsuario perfil,
  required DateTime agora,
  List<Reserva>? reservas,
  List<Quadra>? quadras,
}) {
  switch (perfil) {
    case PerfilUsuario.cliente:
      if (reservas == null) return const [];
      return [
        ContadorPerfil('perfil.contadores.jogos', contarJogos(reservas, agora)),
        ContadorPerfil(
            'perfil.contadores.arenas', contarArenas(reservas, agora)),
      ];
    case PerfilUsuario.dono:
      return [
        if (quadras != null)
          ContadorPerfil('perfil.contadores.quadras', quadras.length),
        if (reservas != null)
          ContadorPerfil(
            'perfil.contadores.reservas',
            contarReservasConfirmadas(reservas),
          ),
      ];
  }
}
