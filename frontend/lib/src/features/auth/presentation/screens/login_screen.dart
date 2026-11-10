import 'package:package_info_plus/package_info_plus.dart';
import 'package:so_mais_uma/src/imports/core_imports.dart';
import 'package:so_mais_uma/src/imports/packages_imports.dart';

import '../login/login_store.dart';
import '../login/login_view.dart';

/// Contêiner do Login: controllers, foco, versão do app e navegação.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _senhaFocus = FocusNode();
  late final LoginStore _store;
  var _senhaOculta = true;
  String? _versao;

  @override
  void initState() {
    super.initState();
    _store = injector.get<LoginStore>();
    _carregarVersao();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Aviso único depois de um 401 TOKEN_INVALIDO (design D7).
      if (AuthService.instance.consumirSessaoExpirada()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('login.sessao_expirada'.tr())),
        );
      }
    });
  }

  Future<void> _carregarVersao() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _versao = '${info.version} (Build ${info.buildNumber})');
    } on Exception catch (e) {
      AppLogger.warning(
        'login.versao indisponível',
        category: LogCategory.app,
        context: {'error': e.toString()},
      );
    }
  }

  Future<void> _entrar() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final resultado = await _store.entrar(
      email: _emailController.text,
      senha: _senhaController.text,
    );
    if (!mounted || resultado == null) return;

    switch (resultado) {
      case LoginConcluido():
        // O redirect leva à home do perfil e substitui a pilha.
        context.go(AppRoutes.home);
      case LoginCredencialInvalida():
        _senhaController.clear();
      case LoginFalhou():
        break;
    }
  }

  @override
  void dispose() {
    _store.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _senhaFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) => LoginView(
        formKey: _formKey,
        emailController: _emailController,
        senhaController: _senhaController,
        senhaFocus: _senhaFocus,
        senhaOculta: _senhaOculta,
        emailValido: _store.emailValido.value,
        enviando: _store.enviando.value,
        bloqueado: _store.bloqueado.value,
        erro: _store.erro.value,
        versao: _versao,
        onEmailMudou: _store.atualizarEmail,
        onAlternarSenha: () => setState(() => _senhaOculta = !_senhaOculta),
        onEntrar: _entrar,
        onCriarConta: () => context.push(AppRoutes.signup),
        onAcessoGestor: () => context.push(AppRoutes.signupGestor),
      ),
    );
  }
}
