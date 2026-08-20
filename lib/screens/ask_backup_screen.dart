import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loanx/db/fastdb.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/screens/dashboard.dart';
import 'package:loanx/service/backup_service.dart';
import 'package:loanx/service/database_helper.dart';
import 'package:loanx/widget/loading_overlay.dart';
import 'package:loanx/widget/snackbar.dart';

class AskBackupScreen extends HookWidget {
  const AskBackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isLoading = useState(false);

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
      return null;
    }, [theme]);

    return Scaffold(
      body: LoadingOverlay(
        isLoading: isLoading.value,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: colors.primaryContainer,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.cloud_sync_outlined,
                                  size: 32,
                                  color: colors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Welcome to LoanX',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Restore your loan records',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'If you have used LoanX before, bring your saved records back from Google Drive. Otherwise, start with a new workspace.',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colors.onSurfaceVariant,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colors.secondaryContainer,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: colors.onSecondaryContainer,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Restoring replaces the records currently on this device.',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: colors.onSecondaryContainer,
                                            height: 1.35,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Consumer(
                              builder: (context, ref, child) => FilledButton.icon(
                                onPressed: () async {
                                  final networkStatus = ref.read(
                                    networkCheckerProvider,
                                  );
                                  final backupRegistered = ref.read(
                                    backUpRegisteredProvider.notifier,
                                  );
                                  final db = ref.read(dBProvider);

                                  networkStatus.when(
                                    data: (connected) async {
                                      if (connected) {
                                        isLoading.value = true;
                                        final restored =
                                            await BackupService.downloadFileToDevice();
                                        if (!restored) {
                                          if (context.mounted) {
                                            showSnackBar(
                                              context,
                                              BackupService.lastError,
                                            );
                                          }
                                          isLoading.value = false;
                                          return;
                                        }
                                        ref.invalidate(loanListProvider);
                                        ref.invalidate(
                                          familyRelationListProvider,
                                        );
                                        ref.invalidate(
                                          mortgageMaterialListProvider,
                                        );
                                        ref.invalidate(weightUnitListProvider);
                                        if (!FastDB.getIsTableCreated()) {
                                          ref
                                              .read(dBProvider)
                                              .when(
                                                data: (data) async {
                                                  await DatabaseHelper.instance
                                                      .onCreate(data, 1);
                                                },
                                                error: (_, _) => showSnackBar(
                                                  context,
                                                  'Something went wrong. Please try again.',
                                                ),
                                                loading: () {},
                                              );
                                        }
                                        FastDB.putScheduledBackUpTimeHour(02);
                                        FastDB.putScheduledBackUpTimeMinute(00);
                                        await registerBackUp();
                                        backupRegistered.set(true);
                                        FastDB.putIsTableCreated(true);
                                        await FastDB.flush();
                                        db.when(
                                          data: (data) async {
                                            ref
                                                .read(
                                                  mortgageMaterialListProvider
                                                      .notifier,
                                                )
                                                .readAllMortgageMaterials();
                                            ref
                                                .read(
                                                  familyRelationListProvider
                                                      .notifier,
                                                )
                                                .readAllFamilyRelations();
                                            ref
                                                .read(loanListProvider.notifier)
                                                .readAllLoans();
                                          },
                                          error: (_, _) => showSnackBar(
                                            context,
                                            'Could not restore your backup. Please try again.',
                                          ),
                                          loading: () {},
                                        );
                                      } else {
                                        showSnackBar(
                                          context,
                                          'Connect to the internet to restore a backup.',
                                        );
                                        return;
                                      }
                                      isLoading.value = false;
                                      if (context.mounted) {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const DashBoard(),
                                          ),
                                        );
                                      }
                                    },
                                    error: (_, _) => showSnackBar(
                                      context,
                                      'Could not check your connection. Please try again.',
                                    ),
                                    loading: () {},
                                  );
                                },
                                icon: const Icon(Icons.cloud_download_outlined),
                                label: const Text('Restore from Google Drive'),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Consumer(
                              builder: (context, ref, child) => OutlinedButton.icon(
                                onPressed: () async {
                                  isLoading.value = true;
                                  if (!FastDB.getIsTableCreated()) {
                                    ref
                                        .read(dBProvider)
                                        .when(
                                          data: (data) async {
                                            await DatabaseHelper.instance
                                                .onCreate(data, 1);
                                          },
                                          error: (_, _) => showSnackBar(
                                            context,
                                            'Something went wrong. Please try again.',
                                          ),
                                          loading: () {},
                                        );
                                  }
                                  isLoading.value = false;
                                  if (context.mounted) {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const DashBoard(),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.add_circle_outline),
                                label: const Text('Start with a new workspace'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'You can manage backups later from Settings.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
