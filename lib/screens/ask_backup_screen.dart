import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mortgage/db/fastdb.dart';
import 'package:mortgage/provider/provider.dart';
import 'package:mortgage/screens/dashboard.dart';
import 'package:mortgage/service/backup_service.dart';
import 'package:mortgage/service/database_helper.dart';
import 'package:mortgage/widget/snackbar.dart';

class AskBackupScreen extends StatelessWidget {
  const AskBackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
        child: Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                // Theme.of(context).colorScheme.primary.computeLuminance() >
                //         0.5
                ? Colors.grey[800]
                : Colors.grey[200],
            borderRadius: BorderRadius.circular(12.0),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.5),
                spreadRadius: 2,
                blurRadius: 5,
                offset: Offset(0, 3),
              ),
            ],
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
                Text(
                  'Do you want to backup your mortgage data on Google Drive?',
                  style: TextStyle(
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.primary),
                  textAlign: TextAlign.center,
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
                          Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const DashBoard()));
                        },
                        child: const Text('No'),
                      );
                    }),
                    Consumer(builder: (context, ref, child) {
                      return OutlinedButton(
                        onPressed: () async {
                          final BackupService backupService = BackupService();
                          final isDownloaded =
                              await backupService.downloadFileToDevice();
                          if (!isDownloaded) {
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
                          }
                          FastDB.putScheduledBackUpTimeHour(13);
                          FastDB.putScheduledBackUpTimeMinute(10);
                          await registerBackUp();
                          FastDB.putIsTableCreated(true);
                          await FastDB.flush();
                          ref.read(dBProvider).when(
                              data: (data) async {
                                ref.read(itemListProvider);
                                ref
                                    .read(mortgageMaterialListProvider.notifier)
                                    .readAllMortgageMaterials();
                                ref
                                    .read(familyRelationListProvider.notifier)
                                    .readAllFamilyRelations();
                                ref
                                    .read(mortgageListProvider.notifier)
                                    .readAllMortgages();
                              },
                              error: (_, __) {
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
                                showSnackBar(context,
                                    "An Error occured During Back Up, Please try again later");
                              },
                              loading: () {});
                          if (context.mounted) {
                            Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const DashBoard()));
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
    ));
  }
}
