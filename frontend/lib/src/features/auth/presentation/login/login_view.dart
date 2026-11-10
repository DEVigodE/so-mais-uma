import 'package:so_mais_uma/src/imports/imports.dart';

import 'login_store.dart';

/// Login a partir de `docs/Protótipo de Alta Fidelidade/login/code.html`.
///
/// Omitidos (spec `sessao-e-navegacao`): "Esqueceu a senha?", os links de Termos
/// de Uso, Privacidade e Suporte, e o código "(RF04)" do cartão de proteção.
class LoginView extends StatelessWidget {
  const LoginView({
    super.key,
    required this.formKey,
    required this.emailController,
    required this.senhaController,
    required this.senhaFocus,
    required this.senhaOculta,
    required this.emailValido,
    required this.enviando,
    required this.bloqueado,
    required this.erro,
    required this.versao,
    required this.onEmailMudou,
    required this.onAlternarSenha,
    required this.onEntrar,
    required this.onCriarConta,
    required this.onAcessoGestor,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController senhaController;
  final FocusNode senhaFocus;
  final bool senhaOculta;
  final bool emailValido;
  final bool enviando;
  final bool bloqueado;
  final String? erro;

  /// "1.0.0 (Build 1)"; `null` enquanto carrega.
  final String? versao;
  final ValueChanged<String> onEmailMudou;
  final VoidCallback onAlternarSenha;
  final VoidCallback onEntrar;
  final VoidCallback onCriarConta;
  final VoidCallback onAcessoGestor;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  _Cabecalho(cs: cs, tt: tt),
                  SizedBox(height: AppSpacing.lg),
                  _CartaoFormulario(view: this, cs: cs, tt: tt),
                  SizedBox(height: AppSpacing.lg),
                  _ChamadaCadastro(view: this, cs: cs, tt: tt),
                  SizedBox(height: AppSpacing.xl),
                  if (versao != null)
                    Padding(
                      padding: EdgeInsets.only(top: AppSpacing.md),
                      child: Text(
                        'login.rodape'.tr(namedArgs: {'versao': versao!}),
                        textAlign: TextAlign.center,
                        style: tt.bodySmall?.copyWith(color: cs.outline),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.cs, required this.tt});

  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            borderRadius: AppBorders.lg,
            boxShadow: AppShadows.subtle,
          ),
          child: ClipRRect(
            borderRadius: AppBorders.lg,
            child: LogoApp(tamanho: 80, semanticsLabel: 'comum.app_nome'.tr()),
          ),
        ),
        SizedBox(height: AppSpacing.md),
        DecoratedBox(
          decoration: BoxDecoration(
            color: cs.secondaryContainer,
            borderRadius: AppBorders.full,
            boxShadow: AppShadows.subtle,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.ms,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.sports_soccer,
                  size: 14,
                  color: cs.onSecondaryContainer,
                ),
                SizedBox(width: AppSpacing.s6),
                Text(
                  'comum.app_nome'.tr().toUpperCase(),
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: AppSpacing.sm),
        Semantics(
          header: true,
          child: Text(
            'login.titulo'.tr(),
            textAlign: TextAlign.center,
            style: tt.headlineMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
        ),
        SizedBox(height: AppSpacing.xs),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Text(
            'login.subtitulo'.tr(),
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _CartaoFormulario extends StatelessWidget {
  const _CartaoFormulario({
    required this.view,
    required this.cs,
    required this.tt,
  });

  final LoginView view;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final habilitado = !view.enviando;
    final podeEntrar = habilitado && !view.bloqueado;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: AppBorders.lg,
        boxShadow: AppShadows.subtle,
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: view.formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── E-mail ────────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'login.email'.tr(),
                        style: tt.labelMedium
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                    if (view.emailValido)
                      Text(
                        'login.formato_valido'.tr(),
                        style: tt.labelSmall?.copyWith(color: cs.outline),
                      ),
                  ],
                ),
                SizedBox(height: AppSpacing.s6),
                TextFormField(
                  controller: view.emailController,
                  enabled: habilitado,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  onChanged: view.onEmailMudou,
                  onFieldSubmitted: (_) => view.senhaFocus.requestFocus(),
                  validator: (v) => LoginStore.validarEmail(v)?.tr(),
                  style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                  decoration: _decoracao(
                    cs: cs,
                    tt: tt,
                    dica: 'login.email_placeholder'.tr(),
                    prefixo: Icon(
                      Icons.mail_outline,
                      color: view.emailValido ? cs.primary : cs.outline,
                    ),
                    sufixo: view.emailValido
                        ? Icon(Icons.check_circle, size: 20, color: cs.primary)
                        : null,
                  ),
                ),
                SizedBox(height: AppSpacing.md),

                // ── Senha ─────────────────────────────────────────────────
                Text(
                  'login.senha'.tr(),
                  style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                SizedBox(height: AppSpacing.s6),
                TextFormField(
                  controller: view.senhaController,
                  focusNode: view.senhaFocus,
                  enabled: habilitado,
                  obscureText: view.senhaOculta,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  autocorrect: false,
                  enableSuggestions: false,
                  onFieldSubmitted: (_) {
                    if (podeEntrar) view.onEntrar();
                  },
                  validator: (v) => LoginStore.validarSenha(v)?.tr(),
                  style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                  decoration: _decoracao(
                    cs: cs,
                    tt: tt,
                    dica: 'login.senha_placeholder'.tr(),
                    prefixo: Icon(Icons.lock_outline, color: cs.outline),
                    sufixo: IconButton(
                      tooltip: 'login.alternar_senha'.tr(),
                      onPressed: view.onAlternarSenha,
                      icon: Icon(
                        view.senhaOculta
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                        color: cs.outline,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.md),

                // ── Proteção de acesso ────────────────────────────────────
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: AppBorders.md,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.ms),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: AppSpacing.xxs),
                          child: Icon(
                            Icons.verified_user,
                            size: 18,
                            color: cs.primary,
                          ),
                        ),
                        SizedBox(width: AppSpacing.s10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'login.protecao_titulo'.tr(),
                                style: tt.labelSmall?.copyWith(
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'login.protecao_texto'.tr(),
                                style: tt.bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.md + AppSpacing.xs),

                // ── Entrar ────────────────────────────────────────────────
                SizedBox(
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: AppBorders.md,
                      boxShadow: podeEntrar ? AppShadows.card : AppShadows.none,
                    ),
                    child: FilledButton(
                      onPressed: podeEntrar ? view.onEntrar : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppBorders.md,
                        ),
                        textStyle: tt.labelLarge,
                      ),
                      child: view.enviando
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: cs.onPrimary,
                                semanticsLabel: 'comum.carregando'.tr(),
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('login.entrar'.tr()),
                                SizedBox(width: AppSpacing.sm),
                                const Icon(Icons.sports_score, size: 18),
                              ],
                            ),
                    ),
                  ),
                ),

                if (view.erro != null) ...[
                  SizedBox(height: AppSpacing.ms),
                  Semantics(
                    liveRegion: true,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline, size: 18, color: cs.error),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            view.erro!,
                            style: tt.bodySmall?.copyWith(color: cs.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoracao({
    required ColorScheme cs,
    required TextTheme tt,
    required String dica,
    required Widget prefixo,
    Widget? sufixo,
  }) {
    OutlineInputBorder borda(Color cor, double largura) => OutlineInputBorder(
          borderRadius: AppBorders.md,
          borderSide: largura == 0
              ? BorderSide.none
              : BorderSide(color: cor, width: largura),
        );

    return InputDecoration(
      hintText: dica,
      hintStyle: tt.bodyMedium?.copyWith(color: cs.outline),
      filled: true,
      fillColor: cs.surfaceContainerLow,
      prefixIcon: prefixo,
      suffixIcon: sufixo,
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.ms,
      ),
      border: borda(cs.outlineVariant, 0),
      enabledBorder: borda(cs.outlineVariant, 0),
      disabledBorder: borda(cs.outlineVariant, 0),
      focusedBorder: borda(cs.primary, 2),
      errorBorder: borda(cs.error, 1),
      focusedErrorBorder: borda(cs.error, 2),
    );
  }
}

class _ChamadaCadastro extends StatelessWidget {
  const _ChamadaCadastro({
    required this.view,
    required this.cs,
    required this.tt,
  });

  final LoginView view;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'login.sem_conta'.tr(),
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            TextButton(
              onPressed: view.enviando ? null : view.onCriarConta,
              style: TextButton.styleFrom(
                foregroundColor: cs.primary,
                minimumSize: const Size(48, 48),
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.s6),
                textStyle: tt.labelLarge,
              ),
              child: Text('login.criar_conta'.tr()),
            ),
          ],
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: Divider(color: cs.surfaceContainerHighest, height: 1),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: Text(
                    'login.ou'.tr(),
                    style: tt.labelSmall?.copyWith(color: cs.outline),
                  ),
                ),
                Expanded(
                  child: Divider(color: cs.surfaceContainerHighest, height: 1),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: AppSpacing.xs),
        TextButton.icon(
          onPressed: view.enviando ? null : view.onAcessoGestor,
          icon: Icon(Icons.stadium_outlined, size: 16, color: cs.primary),
          label: Text('login.acesso_gestor'.tr()),
          style: TextButton.styleFrom(
            backgroundColor: cs.surfaceContainer,
            foregroundColor: cs.onSurface,
            minimumSize: const Size(48, 48),
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            shape: const RoundedRectangleBorder(borderRadius: AppBorders.md),
            textStyle: tt.labelMedium,
          ),
        ),
      ],
    );
  }
}
