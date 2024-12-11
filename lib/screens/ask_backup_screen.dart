import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mortgage/db/fastdb.dart';
import 'package:mortgage/provider/provider.dart';
import 'package:mortgage/screens/dashboard.dart';
import 'package:mortgage/service/backup_service.dart';
import 'package:mortgage/service/database_helper.dart';
import 'package:mortgage/widget/loading_overlay.dart';
import 'package:mortgage/widget/snackbar.dart';

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
                color: Colors.black38.withOpacity(0.7),
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
                        'Do you want to backup your mortgage data from/to Google Drive?',
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
                          return OutlinedButton(
                            onPressed: () async {
                              networkStatus.when(
                                  data: (data) async {
                                    if (data) {
                                      isLoading.value = true;
                                      // await Workmanager().registerOneOffTask(
                                      //   DateTime.now()
                                      //       .microsecondsSinceEpoch
                                      //       .toString(),
                                      //   dailyBackUpDownload,
                                      // );
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
                                      ref
                                          .read(
                                              backUpRegisteredProvider.notifier)
                                          .set(true);
                                      FastDB.putIsTableCreated(true);
                                      await FastDB.flush();
                                      ref.read(dBProvider).when(
                                          data: (data) async {
                                            ref.read(itemListProvider);
                                            ref
                                                .read(
                                                    mortgageMaterialListProvider
                                                        .notifier)
                                                .readAllMortgageMaterials();
                                            ref
                                                .read(familyRelationListProvider
                                                    .notifier)
                                                .readAllFamilyRelations();
                                            ref
                                                .read(mortgageListProvider
                                                    .notifier)
                                                .readAllMortgages();
                                          },
                                          error: (_, __) {
                                            if (!FastDB.getIsTableCreated()) {
                                              ref.read(dBProvider).when(
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

  // void _showDialog(BuildContext context) {
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text('Backup',textAlign: TextAlign.center,),
  //       content: Column(
  //         children: [ Image.asset("assets/backup.png",height: 200,width: 200,),
  //           const Text(
  //               'Do you want to backup your mortgage data from/to Google Drive?'),
  //         ],
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () {
  //             Navigator.pop(context);
  //           },
  //           child: const Text('No'),
  //         ),
  //         TextButton(
  //           onPressed: () {
  //             Navigator.pop(context);
  //           },
  //           child: const Text('Yes'),
  //         ),
  //       ],
  //     ),
  //   );
  // }
}
