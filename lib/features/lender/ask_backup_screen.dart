import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loanx/db/app_settings.dart';
import 'package:loanx/l10n/locale_keys.g.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/features/lender/dashboard.dart';
import 'package:loanx/service/backup_service.dart';
import 'package:loanx/widget/loading_overlay.dart';
import 'package:loanx/widget/snackbar.dart';

class AskBackupScreen extends HookWidget {
  const AskBackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isLoading = useState(false);
    final isDark = theme.brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: colors.surface,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: colors.surface,
        systemNavigationBarDividerColor: colors.surface,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        body: LoadingOverlay(
          isLoading: isLoading.value,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Keep the first-run decision visible on phone-sized screens.
                // The original vertical card consumed most of a compact viewport,
                // leaving the "start fresh" option below the fold.
                final isCompact = constraints.maxWidth < 600;

                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    isCompact ? 20 : 24,
                    isCompact ? 20 : 28,
                    isCompact ? 20 : 24,
                    20,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 48,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _BrandMark(colors: colors),
                              SizedBox(height: isCompact ? 20 : 28),
                              Text(
                                LocaleKeys.restoreYourLoanRecords.tr(),
                                style:
                                    (isCompact
                                            ? theme.textTheme.headlineMedium
                                            : theme.textTheme.headlineLarge)
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -1.1,
                                          height: 1.08,
                                        ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'If you have used LoanX before, bring your saved records back from Google Drive. Otherwise, start with a new workspace.'
                                    .tr(),
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  height: 1.5,
                                ),
                              ),
                              SizedBox(height: isCompact ? 24 : 32),
                              Consumer(
                                builder: (context, ref, child) => _RestoreCard(
                                  colors: colors,
                                  compact: isCompact,
                                  onPressed: () =>
                                      _restoreBackup(context, ref, isLoading),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Consumer(
                                builder: (context, ref, child) =>
                                    _FreshStartRow(
                                      colors: colors,
                                      onPressed: () =>
                                          _startFresh(context, ref, isLoading),
                                    ),
                              ),
                              const Spacer(),
                              const SizedBox(height: 28),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.settings_outlined,
                                    size: 16,
                                    color: colors.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 7),
                                  Flexible(
                                    child: Text(
                                      'You can manage backups later from Settings.'
                                          .tr(),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _restoreBackup(
    BuildContext context,
    WidgetRef ref,
    ValueNotifier<bool> isLoading,
  ) async {
    final backupRegistered = ref.read(backUpRegisteredProvider.notifier);
    final db = ref.read(dBProvider);

    isLoading.value = true;
    try {
      // Let Google Sign-In start immediately. The connectivity stream can stay
      // in its initial loading state on this first-run screen and must not gate
      // an explicit user action.
      final restored = await BackupService.downloadFileToDevice();
      if (!restored) {
        if (context.mounted) {
          showSnackBar(context, BackupService.lastError);
        }
        return;
      }

      ref.invalidate(loanListProvider);
      ref.invalidate(familyRelationListProvider);
      ref.invalidate(mortgageMaterialListProvider);
      ref.invalidate(weightUnitListProvider);
      AppSettings.putScheduledBackUpTimeHour(02);
      AppSettings.putScheduledBackUpTimeMinute(00);
      await registerBackUp();
      backupRegistered.set(true);
      AppSettings.putIsTableCreated(true);
      await AppSettings.flush();
      db.whenData((data) {
        ref
            .read(mortgageMaterialListProvider.notifier)
            .readAllMortgageMaterials();
        ref.read(familyRelationListProvider.notifier).readAllFamilyRelations();
        ref.read(loanListProvider.notifier).readAllLoans();
      });
      if (context.mounted) {
        isLoading.value = false;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashBoard()),
        );
      }
    } catch (_) {
      if (context.mounted) {
        showSnackBar(
          context,
          'Could not restore your backup. Please try again.'.tr(),
        );
      }
    } finally {
      if (context.mounted) isLoading.value = false;
    }
  }

  Future<void> _startFresh(
    BuildContext context,
    WidgetRef ref,
    ValueNotifier<bool> isLoading,
  ) async {
    isLoading.value = true;
    try {
      if (!AppSettings.getIsTableCreated()) {
        await ref.read(dBProvider.future);
        AppSettings.putIsTableCreated(true);
        await AppSettings.flush();
      }
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashBoard()),
        );
      }
    } catch (_) {
      if (context.mounted) {
        showSnackBar(context, LocaleKeys.somethingWentWrongPleaseTryAgain.tr());
      }
    } finally {
      isLoading.value = false;
    }
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.account_balance_wallet_rounded,
            color: colors.onPrimary,
            size: 23,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'LoanX',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -.4,
          ),
        ),
      ],
    );
  }
}

class _RestoreCard extends StatelessWidget {
  const _RestoreCard({
    required this.colors,
    required this.compact,
    required this.onPressed,
  });

  final ColorScheme colors;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: colors.primaryContainer,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(compact ? 18 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (compact)
              Row(
                children: [
                  _RestoreIcon(colors: colors),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _RestoreTitle(theme: theme, colors: colors),
                  ),
                ],
              )
            else ...[
              _RestoreIcon(colors: colors),
              const SizedBox(height: 22),
              _RestoreTitle(theme: theme, colors: colors),
            ],
            SizedBox(height: compact ? 12 : 7),
            Text(
              'Restoring replaces the records currently on this device.'.tr(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onPrimaryContainer.withValues(alpha: .76),
              ),
            ),
            SizedBox(height: compact ? 16 : 20),
            FilledButton.icon(
              onPressed: onPressed,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward_rounded, size: 20),
              label: Text(
                LocaleKeys.restoreLatestBackup.tr(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestoreIcon extends StatelessWidget {
  const _RestoreIcon({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) => Container(
    width: 46,
    height: 46,
    decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
    child: Icon(Icons.cloud_download_rounded, color: colors.onPrimary),
  );
}

class _RestoreTitle extends StatelessWidget {
  const _RestoreTitle({required this.theme, required this.colors});

  final ThemeData theme;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) => Text(
    LocaleKeys.restoreFromGoogleDrive.tr(),
    style: theme.textTheme.titleLarge?.copyWith(
      color: colors.onPrimaryContainer,
      fontWeight: FontWeight.w800,
    ),
  );
}

class _FreshStartRow extends StatelessWidget {
  const _FreshStartRow({required this.colors, required this.onPressed});

  final ColorScheme colors;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
          child: Row(
            children: [
              Icon(Icons.add_rounded, color: colors.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  LocaleKeys.startWithANewWorkspace.tr(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
