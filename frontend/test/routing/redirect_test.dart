import 'package:flutter_test/flutter_test.dart';
import 'package:so_mais_uma/src/routing/app_routes.dart';
import 'package:so_mais_uma/src/routing/redirect.dart';
import 'package:so_mais_uma/src/shared/domain/entities/app_user.dart';
import 'package:so_mais_uma/src/shared/domain/enums.dart';
import 'package:so_mais_uma/src/shared/session/session_store.dart';

void main() {
  const cliente = SessionAuthenticated(
    AppUser(id: '1', email: 'c@demo.com', name: 'Cliente Demo'),
  );
  const dono = SessionAuthenticated(
    AppUser(
      id: '2',
      email: 'd@demo.com',
      name: 'Dono Demo',
      perfil: PerfilUsuario.dono,
    ),
  );
  const semSessao = SessionUnauthenticated();
  const desconhecida = SessionUnknown();

  String? r(SessionState s, String caminho, {bool splash = true}) =>
      redirecionar(sessao: s, splashConcluida: splash, caminho: caminho);

  group('sessão desconhecida', () {
    test('qualquer rota vai para a Splash', () {
      expect(r(desconhecida, AppRoutes.quadras), AppRoutes.splash);
      expect(r(desconhecida, AppRoutes.login), AppRoutes.splash);
    });

    test('a Splash fica', () {
      expect(r(desconhecida, AppRoutes.splash), isNull);
    });
  });

  group('Splash com mínimo de 1 s', () {
    test('fica na Splash antes do mínimo, mesmo com sessão resolvida', () {
      expect(r(semSessao, AppRoutes.splash, splash: false), isNull);
      expect(r(cliente, AppRoutes.splash, splash: false), isNull);
    });

    test('depois do mínimo vai ao Login ou à home do perfil', () {
      expect(r(semSessao, AppRoutes.splash), AppRoutes.login);
      expect(r(cliente, AppRoutes.splash), AppRoutes.quadras);
      expect(r(dono, AppRoutes.splash), AppRoutes.donoQuadras);
    });
  });

  group('sem sessão', () {
    test('rotas públicas seguem', () {
      expect(r(semSessao, AppRoutes.login), isNull);
      expect(r(semSessao, AppRoutes.signup), isNull);
    });

    test('rotas protegidas vão ao Login', () {
      expect(r(semSessao, AppRoutes.quadras), AppRoutes.login);
      expect(r(semSessao, AppRoutes.reserva(3)), AppRoutes.login);
      expect(r(semSessao, AppRoutes.donoQuadras), AppRoutes.login);
    });
  });

  group('com sessão', () {
    test('Login, Cadastro e / levam à home do perfil', () {
      expect(r(cliente, AppRoutes.login), AppRoutes.quadras);
      expect(r(cliente, AppRoutes.signup), AppRoutes.quadras);
      expect(r(cliente, AppRoutes.home), AppRoutes.quadras);
      expect(r(dono, AppRoutes.home), AppRoutes.donoQuadras);
    });

    test('rotas do próprio perfil seguem', () {
      expect(r(cliente, AppRoutes.quadra(1)), isNull);
      expect(r(cliente, AppRoutes.pagamento(1)), isNull);
      expect(r(dono, AppRoutes.donoHorarios(1)), isNull);
      expect(r(dono, AppRoutes.donoReservas), isNull);
    });

    test('rota do outro perfil volta à home do perfil', () {
      expect(r(cliente, AppRoutes.donoQuadras), AppRoutes.quadras);
      expect(r(dono, AppRoutes.reservas), AppRoutes.donoQuadras);
      expect(r(dono, AppRoutes.perfil), AppRoutes.donoQuadras);
    });
  });
}
