import 'package:so_mais_uma/src/imports/core_imports.dart';
import 'package:so_mais_uma/src/imports/packages_imports.dart';

import 'package:so_mais_uma/src/features/auth/presentation/providers/session_store.dart';


class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final session = injector.get<SessionStore>();
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppTopBar(
        title: 'home.home_title'.tr(),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppIcon(
                icon: Icons.home_rounded,
                size: 60.sp,
                color: colorScheme.primary,
                ),
              SizedBox(height: AppSpacing.lg.h),
              SignalBuilder(builder: (_) {
                final user = session.user.value;
                return Text(
                  user?.name ?? user?.email ?? ('home.welcome_home'.tr()),
                  textAlign: TextAlign.center,
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: colorScheme.onSurface,
                    fontSize: 28.sp,
                  ),
                );
              }),
              SizedBox(height: AppSpacing.md.h),
              SignalBuilder(builder: (_) {
                final user = session.user.value;
                return Text(
                  user != null && user.name != null ? user.email : ('home.home_subtitle'.tr()),
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14.sp,
                  ),
                );
              }),
            ],
          ),
          ),
      ),
    );
  }
  }
