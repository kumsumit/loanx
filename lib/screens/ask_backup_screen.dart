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

    final isLoading = useState(false);
    return Material(
      child: LoadingOverlay(
        isLoading: isLoading.value,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.cloud_sync_outlined,
                          size: 34,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Restore your backup?',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Image.asset("assets/backup.png", height: 140, width: 140),
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                        child: Text(
                          'Bring back your previous LoanX records from Google Drive, or start with a fresh workspace.',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: 20),
                      Row(
                        children: [
                          Consumer(
                            builder: (context, ref, child) {
                              return Expanded(
                                child: OutlinedButton(
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
                                            error: (_, _) {
                                              showSnackBar(
                                                context,
                                                "An Error occured, Please try again later",
                                              );
                                            },
                                            loading: () {},
                                          );
                                    }
                                    isLoading.value = false;
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const DashBoard(),
                                      ),
                                    );
                                  },
                                  child: const Text('Start fresh'),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          Consumer(
                            builder: (context, ref, child) {
                              final networkStatus = ref.watch(
                                networkCheckerProvider,
                              );
                              final backupRegistered = ref.read(
                                backUpRegisteredProvider.notifier,
                              );
                              final db = ref.read(dBProvider);

                              return Expanded(
                                child: FilledButton(
                                  onPressed: () async {
                                    networkStatus.when(
                                      data: (data) async {
                                        if (data) {
                                          isLoading.value = true;
                                          await BackupService.downloadFileToDevice();
                                          if (!FastDB.getIsTableCreated()) {
                                            ref
                                                .read(dBProvider)
                                                .when(
                                                  data: (data) async {
                                                    await DatabaseHelper
                                                        .instance
                                                        .onCreate(data, 1);
                                                  },
                                                  error: (_, _) {
                                                    showSnackBar(
                                                      context,
                                                      "An Error occured, Please try again later",
                                                    );
                                                  },
                                                  loading: () {},
                                                );
                                          }
                                          FastDB.putScheduledBackUpTimeHour(02);
                                          FastDB.putScheduledBackUpTimeMinute(
                                            00,
                                          );
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
                                                  .read(
                                                    loanListProvider.notifier,
                                                  )
                                                  .readAllLoans();
                                            },
                                            error: (_, _) {
                                              if (!FastDB.getIsTableCreated()) {
                                                db.when(
                                                  data: (data) async {
                                                    await DatabaseHelper
                                                        .instance
                                                        .onCreate(data, 1);
                                                  },
                                                  error: (_, _) {
                                                    showSnackBar(
                                                      context,
                                                      "An Error occured, Please try again later",
                                                    );
                                                  },
                                                  loading: () {},
                                                );
                                              }
                                              showSnackBar(
                                                context,
                                                "An Error occured During Back Up, Please try again later",
                                              );
                                            },
                                            loading: () {},
                                          );
                                        } else {
                                          if (!FastDB.getIsTableCreated()) {
                                            db.when(
                                              data: (data) async {
                                                await DatabaseHelper.instance
                                                    .onCreate(data, 1);
                                              },
                                              error: (_, _) {
                                                showSnackBar(
                                                  context,
                                                  "An Error occured, Please try again later",
                                                );
                                              },
                                              loading: () {},
                                            );
                                          }
                                        }
                                      },
                                      error: (_, _) {
                                        showSnackBar(
                                          context,
                                          "An Error occured, Please try again later",
                                        );
                                      },
                                      loading: () {},
                                    );

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
                                  child: const Text('Restore'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                    ],
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
