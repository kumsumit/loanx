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
    return Scaffold(
        appBar: AppBar(
          title: const Text('Back up'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Do you want to backup your mortgage data?',
                style: TextStyle(
                    fontSize: 18, color: Theme.of(context).colorScheme.primary),
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
                                await DatabaseHelper.instance.onCreate(data, 1);
                              },
                              error: (_, __) {
                                showSnackBar(context,
                                    "An Error occured, Please try again later");
                              },
                              loading: () {});
                        }
                        Navigator.push(
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
                        await registerBackUp();
                        final BackupService backupService = BackupService();
                        await backupService.downloadFileToDevice();
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
                          Navigator.push(
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
        ));
  }
}
