import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/app_utils.dart';
import '../core/widgets/premium_widgets.dart';
import '../data/models.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/profile_setup_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/manager/manager_shell.dart';
import '../features/owner/owner_shell.dart';
import '../features/tenant/tenant_shell.dart';
import 'providers.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  static const _minimumSplash = Duration(milliseconds: 3000);

  late final Timer _splashTimer;
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    _splashTimer = Timer(_minimumSplash, () {
      if (mounted) setState(() => _splashDone = true);
    });
  }

  @override
  void dispose() {
    _splashTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 520),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _resolve(),
    );
  }

  Widget _resolve() {
    final controller = ref.watch(sessionControllerProvider);
    // Prefetch while the splash is showing so the app opens instantly after it.
    final profileAsync = ref.watch(currentProfileProvider);
    if (!_splashDone) return const SplashScreen(key: ValueKey('splash'));

    if (controller.loading) {
      return const SplashScreen(
        key: ValueKey('session-splash'),
        message: 'جاري تجهيز جلستك…',
      );
    }

    final session = controller.session;
    if (session == null) return const LoginScreen(key: ValueKey('login'));

    return profileAsync.when(
      loading: () => const SplashScreen(
        key: ValueKey('profile-splash'),
        message: 'جاري تحميل حسابك…',
      ),
      error: (error, _) => Scaffold(
        key: const ValueKey('profile-error'),
        backgroundColor: AppColors.navy900,
        body: PremiumBackground(
          child: ErrorView(
            message: friendlyError(error),
            onRetry: () => ref.invalidate(currentProfileProvider),
          ),
        ),
      ),
      data: (profile) {
        if (profile == null) {
          return ProfileSetupScreen(
            key: const ValueKey('profile-setup'),
            phone: session.phone,
          );
        }
        defaultDisplayCountry = profile.country;
        return KeyedSubtree(
          key: ValueKey('role-${profile.role}'),
          child: switch (profile.role) {
            UserRole.owner => OwnerShell(profile: profile),
            UserRole.manager => ManagerShell(profile: profile),
            UserRole.tenant => TenantShell(profile: profile),
          },
        );
      },
    );
  }
}
