import 'dart:ui' as ui;

import 'package:so_mais_uma/src/imports/imports.dart';

import 'contadores_perfil.dart';
import 'perfil_store.dart';
import 'telefone_input_formatter.dart';

/// Medidas do protótipo (`w-24 h-24` do avatar, bolhas decorativas do cartão).
const double _avatar = 96;
const double _bolhaMaior = 144;
const double _bolhaMenor = 112;

/// View do Perfil (`perfil_do_usu_rio/code.html`), variantes CLIENTE e DONO.
/// Sem estado: recebe o estado do store, os controllers e os callbacks.
class PerfilView extends StatelessWidget {
  const PerfilView({
    super.key,
    required this.usuario,
    required this.contadores,
    required this.carregandoContadores,
    required this.nomeController,
    required this.telefoneController,
    required this.senhaAtualController,
    required this.novaSenhaController,
    required this.confirmacaoController,
    required this.salvandoDados,
    required this.senhaExpandida,
    required this.salvandoSenha,
    required this.saindo,
    required this.onEditarCampo,
    required this.onSalvarDados,
    required this.onAlternarSenha,
    required this.onAtualizarSenha,
    required this.onSair,
    this.erroNome,
    this.erroTelefone,
    this.erroSenhaAtual,
    this.erroNovaSenha,
    this.erroConfirmacao,
  });

  final AppUser? usuario;
  final List<ContadorPerfil> contadores;
  final bool carregandoContadores;
  final TextEditingController nomeController;
  final TextEditingController telefoneController;
  final TextEditingController senhaAtualController;
  final TextEditingController novaSenhaController;
  final TextEditingController confirmacaoController;
  final bool salvandoDados;
  final bool senhaExpandida;
  final bool salvandoSenha;
  final bool saindo;
  final String? erroNome;
  final String? erroTelefone;
  final String? erroSenhaAtual;
  final String? erroNovaSenha;
  final String? erroConfirmacao;
  final ValueChanged<CampoPerfil> onEditarCampo;
  final VoidCallback onSalvarDados;
  final VoidCallback onAlternarSenha;
  final VoidCallback onAtualizarSenha;
  final VoidCallback onSair;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final perfil = usuario?.perfil ?? PerfilUsuario.cliente;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      children: [
        _CartaoIdentidade(
          usuario: usuario,
          perfil: perfil,
          contadores: contadores,
          carregandoContadores: carregandoContadores,
        ),
        SizedBox(height: AppSpacing.lg),
        _TituloSecao(
          icone: Icons.badge_outlined,
          titulo: 'perfil.dados.titulo'.tr(),
        ),
        SizedBox(height: AppSpacing.sm),
        _Painel(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Campo(
                rotulo: 'perfil.dados.nome'.tr(),
                dica: 'perfil.dados.nome_placeholder'.tr(),
                controller: nomeController,
                icone: Icons.edit_outlined,
                erro: erroNome,
                enabled: !salvandoDados,
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                onChanged: (_) => onEditarCampo(CampoPerfil.nome),
              ),
              SizedBox(height: AppSpacing.sm),
              _CampoEmail(email: usuario?.email ?? ''),
              SizedBox(height: AppSpacing.sm),
              _Campo(
                rotulo: 'perfil.dados.telefone'.tr(),
                dica: 'perfil.dados.telefone_placeholder'.tr(),
                controller: telefoneController,
                icone: Icons.call_outlined,
                erro: erroTelefone,
                enabled: !salvandoDados,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                inputFormatters: const [TelefoneInputFormatter()],
                onChanged: (_) => onEditarCampo(CampoPerfil.telefone),
              ),
              SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'perfil.dados.salvar'.tr(),
                color: cs.surfaceContainerHighest,
                textColor: cs.onSurface,
                isFullWidth: true,
                isLoading: salvandoDados,
                prefixIcon: Icon(
                  Icons.check,
                  size: AppSpacing.ml - AppSpacing.xxs,
                  color: cs.onSurface,
                ),
                onPressed: onSalvarDados,
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.lg),
        _TituloSecao(
          icone: Icons.shield_outlined,
          titulo: 'perfil.senha.titulo'.tr(),
        ),
        SizedBox(height: AppSpacing.sm),
        _PainelSenha(
          expandido: senhaExpandida,
          salvando: salvandoSenha,
          senhaAtualController: senhaAtualController,
          novaSenhaController: novaSenhaController,
          confirmacaoController: confirmacaoController,
          erroSenhaAtual: erroSenhaAtual,
          erroNovaSenha: erroNovaSenha,
          erroConfirmacao: erroConfirmacao,
          onEditarCampo: onEditarCampo,
          onAlternar: onAlternarSenha,
          onAtualizar: onAtualizarSenha,
        ),
        SizedBox(height: AppSpacing.lg + AppSpacing.sm),
        AppButton(
          label: 'perfil.sair.botao'.tr(),
          color: cs.errorContainer.withValues(alpha: 0.4),
          textColor: cs.error,
          isFullWidth: true,
          isLoading: saindo,
          prefixIcon: Icon(Icons.logout, size: AppSpacing.ml, color: cs.error),
          onPressed: onSair,
        ),
      ],
    );
  }
}

class _CartaoIdentidade extends StatelessWidget {
  const _CartaoIdentidade({
    required this.usuario,
    required this.perfil,
    required this.contadores,
    required this.carregandoContadores,
  });

  final AppUser? usuario;
  final PerfilUsuario perfil;
  final List<ContadorPerfil> contadores;
  final bool carregandoContadores;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final nome = usuario?.name?.trim();
    final dono = perfil == PerfilUsuario.dono;
    final placeholders = dono
        ? const [
            ContadorPerfil('perfil.contadores.quadras', 0),
            ContadorPerfil('perfil.contadores.reservas', 0),
          ]
        : const [
            ContadorPerfil('perfil.contadores.jogos', 0),
            ContadorPerfil('perfil.contadores.arenas', 0),
          ];

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: AppBorders.md,
        boxShadow: AppShadows.subtle,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -AppSpacing.xxl,
            right: -AppSpacing.xxl,
            child: _Bolha(
              diametro: _bolhaMaior,
              cor: cs.primaryFixed.withValues(alpha: 0.2),
              desfoque: AppSpacing.lg,
            ),
          ),
          Positioned(
            bottom: -(AppSpacing.xl + AppSpacing.sm),
            left: -(AppSpacing.xl + AppSpacing.sm),
            child: _Bolha(
              diametro: _bolhaMenor,
              cor: cs.secondaryContainer.withValues(alpha: 0.4),
              desfoque: AppSpacing.md,
            ),
          ),
          Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                Container(
                  width: _avatar,
                  height: _avatar,
                  padding: EdgeInsets.all(AppSpacing.xxs),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.card,
                  ),
                  child: AvatarIniciais(
                    iniciais: usuario?.iniciais ?? '?',
                    tamanho: _avatar - AppSpacing.xs,
                    semanticsLabel: nome,
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
                Semantics(
                  header: true,
                  child: Text(
                    (nome == null || nome.isEmpty)
                        ? (usuario?.email ?? '')
                        : nome,
                    textAlign: TextAlign.center,
                    style: tt.headlineSmall?.copyWith(color: cs.onSurface),
                  ),
                ),
                SizedBox(height: AppSpacing.xxs),
                Text(
                  usuario?.email ?? '',
                  textAlign: TextAlign.center,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                SizedBox(height: AppSpacing.sm),
                _PilulaPerfil(dono: dono),
                if (contadores.isNotEmpty) ...[
                  SizedBox(height: AppSpacing.md),
                  _FaixaContadores(contadores: contadores),
                ] else if (carregandoContadores) ...[
                  SizedBox(height: AppSpacing.md),
                  Skeletonizer(
                    child: _FaixaContadores(contadores: placeholders),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bolha extends StatelessWidget {
  const _Bolha({
    required this.diametro,
    required this.cor,
    required this.desfoque,
  });

  final double diametro;
  final Color cor;
  final double desfoque;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: desfoque, sigmaY: desfoque),
          child: Container(
            width: diametro,
            height: diametro,
            decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

class _PilulaPerfil extends StatelessWidget {
  const _PilulaPerfil({required this.dono});

  final bool dono;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final rotulo =
        dono ? 'perfil.perfil_dono'.tr() : 'perfil.perfil_cliente'.tr();
    final fixo = 'perfil.perfil_fixo'.tr();
    return Semantics(
      label: '$rotulo $fixo',
      readOnly: true,
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.ms,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.15),
          borderRadius: AppBorders.full,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              dono ? Icons.stadium : Icons.sports_score,
              size: AppSpacing.md,
              color: cs.primary,
            ),
            SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                rotulo,
                style: tt.labelMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            SizedBox(width: AppSpacing.xs),
            Text(
              fixo,
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaixaContadores extends StatelessWidget {
  const _FaixaContadores({required this.contadores});

  final List<ContadorPerfil> contadores;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    return Padding(
      padding: EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          for (var i = 0; i < contadores.length; i++) ...[
            if (i > 0) SizedBox(width: AppSpacing.xs),
            Expanded(
              child: MergeSemantics(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    vertical: AppSpacing.sm,
                    horizontal: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLowest.withValues(alpha: 0.8),
                    borderRadius: AppBorders.sm,
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${contadores[i].valor}',
                        style: tt.titleLarge?.copyWith(color: cs.primary),
                      ),
                      Text(
                        contadores[i].rotuloKey.tr(),
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TituloSecao extends StatelessWidget {
  const _TituloSecao({required this.icone, required this.titulo});

  final IconData icone;
  final String titulo;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Row(
      children: [
        Icon(icone, size: AppSpacing.ml, color: cs.primary),
        SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              titulo,
              style: context.textTheme.titleMedium?.copyWith(
                color: cs.onSurface,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Painel extends StatelessWidget {
  const _Painel({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: padding,
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLow,
        borderRadius: AppBorders.md,
        boxShadow: AppShadows.subtle,
      ),
      child: child,
    );
  }
}

/// Campo do protótipo: rótulo acima, caixa `surface-container-lowest` sem
/// borda e ícone à direita. O erro fica no próprio campo (anunciado).
class _Campo extends StatelessWidget {
  const _Campo({
    required this.rotulo,
    required this.controller,
    this.dica,
    this.icone,
    this.erro,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.inputFormatters,
    this.onChanged,
  });

  final String rotulo;
  final TextEditingController controller;
  final String? dica;
  final IconData? icone;
  final String? erro;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            rotulo,
            style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          SizedBox(height: AppSpacing.xs),
          TextField(
            controller: controller,
            enabled: enabled,
            obscureText: obscureText,
            enableSuggestions: !obscureText,
            autocorrect: !obscureText,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            autofillHints: autofillHints,
            inputFormatters: inputFormatters,
            onChanged: onChanged,
            style: tt.bodyMedium?.copyWith(color: cs.onSurface),
            decoration: _decoracao(
              context,
              dica: dica,
              erro: erro,
              icone: icone,
              preenchimento: cs.surfaceContainerLowest,
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _decoracao(
  BuildContext context, {
  required Color preenchimento,
  String? dica,
  String? erro,
  IconData? icone,
}) {
  final cs = context.colors;
  const semBorda = OutlineInputBorder(
    borderRadius: AppBorders.sm,
    borderSide: BorderSide.none,
  );
  return InputDecoration(
    hintText: dica,
    errorText: erro,
    errorMaxLines: 2,
    filled: true,
    fillColor: preenchimento,
    isDense: true,
    contentPadding: EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.ms + AppSpacing.xxs,
    ),
    suffixIcon: icone == null
        ? null
        : Icon(icone, size: AppSpacing.ml, color: cs.outline),
    border: semBorda,
    enabledBorder: semBorda,
    disabledBorder: semBorda,
    focusedBorder: OutlineInputBorder(
      borderRadius: AppBorders.sm,
      borderSide: BorderSide(color: cs.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: AppBorders.sm,
      borderSide: BorderSide(color: cs.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: AppBorders.sm,
      borderSide: BorderSide(color: cs.error, width: 1.5),
    ),
  );
}

/// "E-mail cadastrado": somente leitura, sem teclado, anunciado como
/// desabilitado.
class _CampoEmail extends StatelessWidget {
  const _CampoEmail({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'perfil.dados.email'.tr(),
                  style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: AppBorders.full,
                ),
                child: Text(
                  'perfil.dados.somente_leitura'.tr(),
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xs),
          TextFormField(
            key: ValueKey(email),
            initialValue: email,
            enabled: false,
            readOnly: true,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            decoration: _decoracao(
              context,
              icone: Icons.lock_outline,
              preenchimento: cs.surfaceContainerHigh.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _PainelSenha extends StatelessWidget {
  const _PainelSenha({
    required this.expandido,
    required this.salvando,
    required this.senhaAtualController,
    required this.novaSenhaController,
    required this.confirmacaoController,
    required this.onEditarCampo,
    required this.onAlternar,
    required this.onAtualizar,
    this.erroSenhaAtual,
    this.erroNovaSenha,
    this.erroConfirmacao,
  });

  final bool expandido;
  final bool salvando;
  final TextEditingController senhaAtualController;
  final TextEditingController novaSenhaController;
  final TextEditingController confirmacaoController;
  final String? erroSenhaAtual;
  final String? erroNovaSenha;
  final String? erroConfirmacao;
  final ValueChanged<CampoPerfil> onEditarCampo;
  final VoidCallback onAlternar;
  final VoidCallback onAtualizar;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;
    final quadrado = AppSpacing.xl + AppSpacing.xs;

    return _Painel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: expandido,
            child: InkWell(
              onTap: onAlternar,
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: quadrado,
                      height: quadrado,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.2),
                        borderRadius: AppBorders.sm,
                      ),
                      child: Icon(
                        Icons.key_outlined,
                        size: AppSpacing.ml,
                        color: cs.primary,
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'perfil.senha.alterar'.tr(),
                            style: tt.titleSmall?.copyWith(color: cs.onSurface),
                          ),
                          Text(
                            'perfil.senha.alterar_descricao'.tr(),
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: expandido ? 0.5 : 0,
                      duration: AppDurations.quick,
                      child: Icon(Icons.expand_more, color: cs.outline),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: AppDurations.normal,
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: !expandido
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Campo(
                            rotulo: 'perfil.senha.atual'.tr(),
                            dica: 'perfil.senha.atual_placeholder'.tr(),
                            controller: senhaAtualController,
                            obscureText: true,
                            erro: erroSenhaAtual,
                            enabled: !salvando,
                            autofillHints: const [AutofillHints.password],
                            onChanged: (_) =>
                                onEditarCampo(CampoPerfil.senhaAtual),
                          ),
                          SizedBox(height: AppSpacing.sm),
                          _Campo(
                            rotulo: 'perfil.senha.nova'.tr(),
                            dica: 'perfil.senha.nova_placeholder'.tr(),
                            controller: novaSenhaController,
                            obscureText: true,
                            erro: erroNovaSenha,
                            enabled: !salvando,
                            autofillHints: const [AutofillHints.newPassword],
                            onChanged: (_) =>
                                onEditarCampo(CampoPerfil.novaSenha),
                          ),
                          SizedBox(height: AppSpacing.sm),
                          _Campo(
                            rotulo: 'perfil.senha.confirmacao'.tr(),
                            dica: 'perfil.senha.confirmacao_placeholder'.tr(),
                            controller: confirmacaoController,
                            obscureText: true,
                            erro: erroConfirmacao,
                            enabled: !salvando,
                            autofillHints: const [AutofillHints.newPassword],
                            onChanged: (_) =>
                                onEditarCampo(CampoPerfil.confirmacao),
                          ),
                          SizedBox(height: AppSpacing.ms),
                          AppButton(
                            label: 'perfil.senha.atualizar'.tr(),
                            isFullWidth: true,
                            isLoading: salvando,
                            prefixIcon: Icon(
                              Icons.lock_reset,
                              size: AppSpacing.ml - AppSpacing.xxs,
                              color: cs.onPrimary,
                            ),
                            onPressed: onAtualizar,
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
