import 'package:auto_injector/auto_injector.dart';

import '../features/auth/data/repositories/auth_repository_impl.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/presentation/login/login_store.dart';
import '../features/auth/presentation/providers/auth_store.dart';
import '../features/horarios/domain/salvar_horarios_use_case.dart';
import '../features/horarios/presentation/horarios_quadra/horarios_quadra_store.dart';
import '../features/quadras/presentation/form_quadra/form_quadra_store.dart';
import '../features/quadras/presentation/minhas_quadras/minhas_quadras_store.dart';
import '../features/quadras/presentation/detalhe_quadra/detalhe_quadra_store.dart';
import '../features/quadras/presentation/quadras/quadras_store.dart';
import '../features/reservas/presentation/confirmar_reserva/confirmar_reserva_store.dart';
import '../features/reservas/presentation/grade/grade_slots_store.dart';
import '../features/perfil/presentation/perfil/perfil_store.dart';
import '../features/reservas/presentation/cancelamento_dono/cancelamento_dono_store.dart';
import '../features/reservas/presentation/reservas_quadra/reservas_quadra_store.dart';
import '../features/pagamento/presentation/pagamento/pagamento_store.dart';
import '../features/reservas/presentation/cancelamento/cancelamento_cliente_store.dart';
import '../features/reservas/presentation/detalhe_reserva/detalhe_reserva_store.dart';
import '../features/reservas/presentation/minhas_reservas/minhas_reservas_store.dart';
import '../shared/data/repositories/repositorios_impl.dart';
import '../shared/domain/brasilia.dart';
import '../shared/domain/repositories/repositorios.dart';
import '../shared/session/session_store.dart';

/// Composition root. Resolve dependencies with `injector.get<T>()`.
final injector = AutoInjector();

void setupInjector() {
  injector
    // ── Infraestrutura e repositórios (singletons) ────────────────────────
    ..addLazySingleton<Relogio>(Relogio.new)
    ..addLazySingleton<AuthRepository>(AuthRepositoryImpl.new)
    ..addLazySingleton<QuadraRepository>(QuadraRepositoryImpl.new)
    ..addLazySingleton<CepRepository>(CepRepositoryImpl.new)
    ..addLazySingleton<HorarioRepository>(HorarioRepositoryImpl.new)
    ..addLazySingleton<SlotRepository>(SlotRepositoryImpl.new)
    ..addLazySingleton<ReservaRepository>(ReservaRepositoryImpl.new)
    ..addLazySingleton<PagamentoRepository>(PagamentoRepositoryImpl.new)
    ..addLazySingleton<UsuarioRepository>(UsuarioRepositoryImpl.new)
    ..addLazySingleton<SessionStore>(
      SessionStore.new,
      config: BindConfig(onDispose: (store) => store.dispose()),
    )
    // ── Stores de tela (fábrica: uma instância por abertura) ──────────────
    ..add<AuthStore>(AuthStore.new)
    ..add<LoginStore>(LoginStore.new);

  registrarStoresQuadrasCliente(injector);
  registrarStoresReservasCliente(injector);
  registrarStoresDono(injector);
  registrarStoresReservasDonoEPerfil(injector);

  injector.commit();
}

// Cada bloco abaixo registra os stores de um grupo de telas. Registre stores de
// tela com `i.add<XStore>(XStore.new)`; o construtor recebe por tipo os
// repositórios e o `Relogio` registrados acima.

/// Quadras (cliente), DetalheQuadra, grade de slots e ConfirmarReserva.
void registrarStoresQuadrasCliente(AutoInjector i) {
  i
    ..add<QuadrasStore>(QuadrasStore.new)
    ..add<DetalheQuadraStore>(DetalheQuadraStore.new)
    ..add<GradeSlotsStore>(GradeSlotsStore.new)
    ..add<ConfirmarReservaStore>(ConfirmarReservaStore.new);
}

/// MinhasReservas, DetalheReserva, cancelamento do cliente e Pagamento.
void registrarStoresReservasCliente(AutoInjector i) {
  i
    ..add<MinhasReservasStore>(MinhasReservasStore.new)
    ..add<DetalheReservaStore>(DetalheReservaStore.new)
    ..add<CancelamentoClienteStore>(CancelamentoClienteStore.new)
    ..add<PagamentoStore>(PagamentoStore.new);
}

/// MinhasQuadras, FormQuadra e HorariosQuadra.
void registrarStoresDono(AutoInjector i) {
  i
    ..addLazySingleton<SalvarHorariosUseCase>(SalvarHorariosUseCase.new)
    ..add<MinhasQuadrasStore>(MinhasQuadrasStore.new)
    ..add<FormQuadraStore>(FormQuadraStore.new)
    ..add<HorariosQuadraStore>(HorariosQuadraStore.new);
}

/// ReservasQuadra (dono), cancelamento do dono e Perfil.
void registrarStoresReservasDonoEPerfil(AutoInjector i) {
  i
    ..add<ReservasQuadraStore>(ReservasQuadraStore.new)
    ..add<CancelamentoDonoStore>(CancelamentoDonoStore.new)
    ..add<PerfilStore>(PerfilStore.new);
}
