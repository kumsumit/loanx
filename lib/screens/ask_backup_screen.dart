import 'package:flutter/material.dart';
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
    final isLoading = useState(false);
    return Material(
        child: LoadingOverlay(
      isLoading: isLoading.value,
      child: DecoratedBox(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/background.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black38.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Backup',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: Theme.of(context)
                              .textTheme
                              .headlineMedium!
                              .fontSize,
                        )),
                    Image.asset(
                      "assets/backup.png",
                      height: 200,
                      width: 200,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                      child: Text(
                        'Do you want to backup your Loanx data from/to Google Drive?',
                        style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.primary),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(
                      height: 20,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Consumer(builder: (context, ref, child) {
                          return OutlinedButton(
                            onPressed: () async {
                              isLoading.value = true;
                              if (!FastDB.getIsTableCreated()) {
                                ref.read(dBProvider).when(
                                    data: (data) async {
                                      await DatabaseHelper.instance
                                          .onCreate(data, 1);
                                    },
                                    error: (_, __) {
                                      showSnackBar(context,
                                          "An Error occured, Please try again later");
                                    },
                                    loading: () {});
                              }
                              isLoading.value = false;
                              Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => const DashBoard()));
                            },
                            child: const Text('No'),
                          );
                        }),
                        Consumer(builder: (context, ref, child) {
                          final networkStatus =
                              ref.watch(networkCheckerProvider);
                          final backupRegistered =
                              ref.read(backUpRegisteredProvider.notifier);
                          final db = ref.read(dBProvider);
                          final itemList = ref.read(itemListProvider.notifier);
                          final familyRelationList =
                              ref.read(familyRelationListProvider.notifier);
                          final mortgageMaterialList =
                              ref.read(mortgageMaterialListProvider.notifier);
                          final mortgageList =
                              ref.read(mortgageListProvider.notifier);
                          return OutlinedButton(
                            onPressed: () async {
                              networkStatus.when(
                                  data: (data) async {
                                    if (data) {
                                      isLoading.value = true;
                                      await BackupService
                                          .downloadFileToDevice();
                                      if (!FastDB.getIsTableCreated()) {
                                        ref.read(dBProvider).when(
                                            data: (data) async {
                                              await DatabaseHelper.instance
                                                  .onCreate(data, 1);
                                            },
                                            error: (_, __) {
                                              showSnackBar(context,
                                                  "An Error occured, Please try again later");
                                            },
                                            loading: () {});
                                      }
                                      FastDB.putScheduledBackUpTimeHour(02);
                                      FastDB.putScheduledBackUpTimeMinute(00);
                                      await registerBackUp();
                                      backupRegistered.set(true);
                                      FastDB.putIsTableCreated(true);
                                      await FastDB.flush();
                                      db.when(
                                          data: (data) async {
                                            itemList.readAllItems();
                                            mortgageMaterialList
                                                .readAllMortgageMaterials();
                                            familyRelationList
                                                .readAllFamilyRelations();
                                            mortgageList.readAllMortgages();
                                          },
                                          error: (_, __) {
                                            if (!FastDB.getIsTableCreated()) {
                                              db.when(
                                                  data: (data) async {
                                                    await DatabaseHelper
                                                        .instance
                                                        .onCreate(data, 1);
                                                  },
                                                  error: (_, __) {
                                                    showSnackBar(context,
                                                        "An Error occured, Please try again later");
                                                  },
                                                  loading: () {});
                                            }
                                            showSnackBar(context,
                                                "An Error occured During Back Up, Please try again later");
                                          },
                                          loading: () {});
                                    } else {
                                      if (!FastDB.getIsTableCreated()) {
                                        db.when(
                                            data: (data) async {
                                              await DatabaseHelper.instance
                                                  .onCreate(data, 1);
                                            },
                                            error: (_, __) {
                                              showSnackBar(context,
                                                  "An Error occured, Please try again later");
                                            },
                                            loading: () {});
                                      }
                                    }
                                  },
                                  error: (_, __) {
                                    showSnackBar(context,
                                        "An Error occured, Please try again later");
                                  },
                                  loading: () {});

                              isLoading.value = false;
                              if (context.mounted) {
                                Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const DashBoard()));
                              }
                            },
                            child: const Text('Yes'),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ));
  }
}
