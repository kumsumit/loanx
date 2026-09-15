import 'package:loanx/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/service/device_performance.dart';

class AuthScreen extends HookConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final animate = DevicePerformance.enableHeavyAnimations;
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: theme.scaffoldBackgroundColor,
            statusBarIconBrightness: theme.brightness,
            systemNavigationBarColor: theme.scaffoldBackgroundColor,
            systemNavigationBarDividerColor: theme.scaffoldBackgroundColor,
            systemNavigationBarIconBrightness: theme.brightness,
          ),
        );
      });
      return;
    }, const []);

    final controller = useAnimationController(
      duration: const Duration(seconds: 2),
    );

    useEffect(() {
      if (animate) {
        controller.repeat(reverse: true);
      } else {
        // This screen can remain visible while local authentication is
        // running. Keeping a ticker alive here makes old software-rendered
        // devices repaint indefinitely and can starve platform messages.
        controller
          ..stop()
          ..value = 1;
      }
      return controller.stop;
    }, [controller, animate]);

    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    );

    ref.watch(appColorProvider);
    final colors = Theme.of(context).colorScheme;
    final basicEffects = DevicePerformance.isSafe;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: basicEffects ? colors.primary : null,
          gradient: basicEffects
              ? null
              : LinearGradient(
                  colors: [colors.primary, colors.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
        ),
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: Tween<double>(begin: .65, end: 1).animate(animation),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 112,
                    height: 112,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: basicEffects
                          ? null
                          : [
                              BoxShadow(
                                color: colors.onSurface.withValues(alpha: 0.12),
                                blurRadius: 30,
                                offset: Offset(0, 12),
                              ),
                            ],
                    ),
                    child: Image.asset("assets/logo.png"),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    LocaleKeys.loanx2.tr(),
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: colors.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    LocaleKeys.yourLendingWorkspace.tr(),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colors.onPrimary.withValues(alpha: .8),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: colors.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    LocaleKeys.securingYourData.tr(),
                    style: TextStyle(
                      color: colors.onPrimary.withValues(alpha: .75),
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
