import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_color_picker_plus/flutter_color_picker_plus.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mortgage/extension/string.dart';
import 'package:mortgage/model/loan.dart';
import 'package:mortgage/service/backup_service.dart';
import 'package:mortgage/db/fastdb.dart';
import 'package:mortgage/provider/provider.dart';
import 'package:mortgage/widget/avatar.dart';
import 'package:mortgage/widget/bullet.dart';
import 'package:mortgage/widget/loading_overlay.dart';
import 'package:mortgage/widget/snackbar.dart';
import 'package:mortgage/widget/styled_dropdown.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
// import 'package:workmanager/workmanager.dart';

class MyDrawer extends HookWidget {
  const MyDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final isLoading = useState(false);
    return LoadingOverlay(
      isLoading: isLoading.value,
      child: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Mortgage',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSecondary,
                            fontSize: 20),
                      ),
                      Consumer(builder: (context, ref, child) {
                        return ProfilePicture(
                            imageUrl: ref.watch(photoUrlProvider),
                            displayName: ref.watch(displayNameProvider));
                      }),
                    ],
                  ),
                  Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Consumer(builder: (context, ref, child) {
                              return AutoSizeText(
                                ref.watch(displayNameProvider),
                                style: TextStyle(
                                  fontSize: 13,
                                  color:
                                      Theme.of(context).colorScheme.onSecondary,
                                ),
                                minFontSize: 10,
                              );
                            }),
                            Consumer(builder: (context, ref, child) {
                              return AutoSizeText(
                                ref.watch(emailProvider),
                                style: TextStyle(
                                  fontSize: 13,
                                  color:
                                      Theme.of(context).colorScheme.onSecondary,
                                ),
                                maxLines: 3, // Set the maximum number of lines
                                overflow: TextOverflow.visible,
                                minFontSize: 10,
                              );
                            }),
                          ],
                        ),
                      ),
                      Consumer(builder: (context, ref, child) {
                        return InkWell(
                          onTap: () async {
                            await ref
                                .read(themeModeManagerProvider.notifier)
                                .set();
                          },
                          child: ref.watch(themeModeManagerProvider).index == 2
                              ? Icon(Icons.light_mode,
                                  color:
                                      Theme.of(context).colorScheme.onSecondary)
                              : Icon(Icons.dark_mode,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSecondary),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.info),
              title: Text('About',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  )),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainer,
                      title: Text(
                        'About',
                      ),
                      content: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          BulletPoint(
                            'Traditionally practiced, now technologically advanced',
                            italic: true,
                          ),
                          BulletPoint(
                            'A revolutionary app to keep records of loans provided by the unorganized sector in India without any paperwork.\n',
                          ),
                          BulletPoint(
                            'Mortgage is a simple and easy to use app that allows you to track your mortgage loans. It is designed to be user-friendly and intuitive, making it easy for anyone to manage their mortgage records. With Mortgage, you can easily create, update, and delete mortgage loans, as well as view your loan history.',
                          ),
                          BulletPoint(
                              'The app also provides a feature to backup your data, ensuring that your information is secure and accessible in case of any data loss. Mortgage is available on both Android and iOS platforms, making it accessible to a wide range of users.'),
                          BulletPoint(
                            'Whether you\'re a seasoned mortgage professional or just starting out, Mortgage is the perfect app to help you manage your mortgage loans efficiently and efficiently.',
                          ),
                        ]),
                      ),
                      contentTextStyle: TextStyle(
                          color: Theme.of(context).colorScheme.inverseSurface),
                      actions: [
                        OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text(
                            'OK',
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            ListTile(
                leading: Icon(Icons.color_lens),
                title: Text('Change App Color',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    )),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainer,
                      title: const Text('Pick a color!'),
                      content: SingleChildScrollView(
                        child: Column(
                          children: [
                            Consumer(builder: (context, ref, child) {
                              final color = ref.watch(pickerColorProvider);
                              return ColorPicker(
                                pickerColor: Color(int.parse(
                                    'FF${color.substring(1)}',
                                    radix: 16)),
                                onColorChanged:
                                    ref.read(pickerColorProvider.notifier).set,
                              );
                            }),
                            Consumer(builder: (context, ref, child) {
                              return OutlinedButton(
                                  onPressed: () async {
                                    await ref
                                        .read(appColorProvider.notifier)
                                        .setFromLogo();
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                    }
                                  },
                                  child: Text("Set Logo Color"));
                            })
                          ],
                        ),
                      ),
                      actions: <Widget>[
                        Consumer(builder: (context, ref, child) {
                          return OutlinedButton(
                            child: const Text('Ok'),
                            onPressed: () async {
                              await ref.read(appColorProvider.notifier).set();
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                showSnackBar(context, "App Color Changed");
                              }
                            },
                          );
                        }),
                      ],
                    ),
                  );
                }),
            ListTile(
              leading: Icon(Icons.currency_exchange),
              title: Text('Change Mortgage Holding Period',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  )),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainer,
                      title: Text('Change Holding Period'),
                      content: SizedBox(
                        height: 200,
                        child: Column(
                          children: [
                            Consumer(builder: (context, ref, child) {
                              final holdingPeriod =
                                  ref.watch(holdingPeriodProvider);
                              return Slider(
                                value: holdingPeriod.toDouble(),
                                min: 0,
                                max: 30,
                                divisions: 30,
                                label: holdingPeriod.toString(),
                                onChanged: (value) {
                                  ref
                                      .read(holdingPeriodProvider.notifier)
                                      .set(value.toInt());
                                },
                              );
                            }),
                            Consumer(builder: (context, ref, child) {
                              final holdingPeriod =
                                  ref.watch(holdingPeriodProvider);
                              return Text(
                                "Mortgage Holding Period : $holdingPeriod Years",
                              );
                            }),
                            Text(
                              "Default holding Period is 5 years",
                              style: TextStyle(fontSize: 12),
                            )
                          ],
                        ),
                      ),
                      actions: [
                        Consumer(builder: (context, ref, child) {
                          return TextButton(
                            onPressed: () async {
                              await FastDB.flush();
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                showSnackBar(context,
                                    "Mortgage Data Holding Period changed");
                              }
                            },
                            child: Text('OK',
                                style: TextStyle(
                                    fontSize: Theme.of(context)
                                        .textTheme
                                        .bodyMedium!
                                        .fontSize)),
                          );
                        }),
                      ],
                    );
                  },
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.input),
              title: Text('Set Interest Type'),
              onTap: () async {
                showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        backgroundColor:
                            Theme.of(context).colorScheme.surfaceContainer,
                        title: Text('Select Interest Type'),
                        content: SizedBox(
                          height: 200,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Expanded(
                                child: Consumer(builder: (context, ref, child) {
                                  final interestType =
                                      ref.watch(interestTypeStatusProvider);
                                  return ListView.builder(
                                    itemCount: InterestType.values.length,
                                    itemBuilder: (context, index) {
                                      return RadioListTile(
                                        value: InterestType.values[index],
                                        groupValue: interestType,
                                        title: Text(InterestType
                                            .values[index].name
                                            .toSentenceCase()),
                                        onChanged: (value) {
                                          if (value != null) {
                                            ref
                                                .read(interestTypeStatusProvider
                                                    .notifier)
                                                .set(value);
                                          }
                                        },
                                      );
                                    },
                                  );
                                }),
                              ),
                              const SizedBox(height: 20),
                              Consumer(builder: (context, ref, child) {
                                final compoundingFrequency = ref
                                    .watch(compoundingFrequencyStatusProvider);
                                return ref.watch(interestTypeStatusProvider) ==
                                        InterestType.compound
                                    ? StyledDropdown(
                                        selectedValue: compoundingFrequency,
                                        onChanged: (value) {
                                          if (value != null) {
                                            ref
                                                .read(
                                                    compoundingFrequencyStatusProvider
                                                        .notifier)
                                                .set(value);
                                          }
                                        },
                                        items: [
                                          DropdownMenuItem(
                                            value: CompoundingFrequency.yearly,
                                            child: Text('Yearly',
                                                style: TextStyle(
                                                    fontSize: 15.0,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .secondary)),
                                          ),
                                          DropdownMenuItem(
                                            value:
                                                CompoundingFrequency.halfYearly,
                                            child: Text('Half-Yearly',
                                                style: TextStyle(
                                                    fontSize: 15.0,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .secondary)),
                                          ),
                                          DropdownMenuItem(
                                            value:
                                                CompoundingFrequency.quarterly,
                                            child: Text('Quarterly',
                                                style: TextStyle(
                                                    fontSize: 15.0,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .secondary)),
                                          ),
                                          DropdownMenuItem(
                                            value: CompoundingFrequency.monthly,
                                            child: Text('Monthly',
                                                style: TextStyle(
                                                    fontSize: 15.0,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .secondary)),
                                          ),
                                        ],
                                        hintText: "Compounding Frequency",
                                        labelText: "Compounding Frequency",
                                        onTap: () {})
                                    : SizedBox();
                              }),
                            ],
                          ),
                        ),
                        actions: [
                          Consumer(builder: (context, ref, child) {
                            return OutlinedButton(
                              onPressed: () async {
                                await FastDB.flush();
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                  showSnackBar(context,
                                      "Interest Type changed successfully");
                                }
                              },
                              child: Text('OK',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary)),
                            );
                          }),
                        ],
                      );
                    });
              },
            ),
            Consumer(builder: (context, ref, child) {
              final hour = ref.watch(scheduledBackUpTimeHourProvider);
              final minute = ref.watch(scheduledBackUpTimeMinuteProvider);
              final isBackUpRegistered = ref.watch(backUpRegisteredProvider);
              if (isBackUpRegistered) {
                return ListTile(
                    leading: Icon(Icons.settings_backup_restore),
                    title: Text('Set Backup Time'),
                    onTap: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: hour, minute: minute),
                      );
                      if (picked != null) {
                        ref
                            .read(scheduledBackUpTimeHourProvider.notifier)
                            .set(picked.hour);
                        ref
                            .read(scheduledBackUpTimeMinuteProvider.notifier)
                            .set(picked.minute);
                        await FastDB.flush();
                        await registerBackUp();
                        ref.read(backUpRegisteredProvider.notifier).set(true);
                        if (context.mounted) {
                          Navigator.pop(context);
                          showSnackBar(context,
                              'Backup Time Updated to Time ${picked.format(context)}');
                        }
                      }
                    });
              } else {
                return SizedBox();
              }
            }),
            Consumer(builder: (context, ref, child) {
              final token = ref.watch(driveAccessTokenProvider);
              if (token.isEmpty) {
                return SizedBox();
              }
              return ref.watch(backupDownloadStatusProvider)
                  ? SizedBox()
                  : ListTile(
                      leading: Icon(Icons.backup),
                      title: Text("Back up now"),
                      subtitle: ref.watch(backupStatusProvider)
                          ? Text(
                              "Backup in progress, Please wait ...",
                              style: TextStyle(fontSize: 15, color: Colors.red),
                            )
                          : null,
                      onTap: ref.watch(backupStatusProvider)
                          ? null
                          : () async {
                              final networkStatus =
                                  ref.watch(networkCheckerProvider);
                              networkStatus.when(
                                  data: (data) async {
                                    if (data) {
                                      isLoading.value = true;
                                      if (!FastDB.getIsBackUpRegistered()) {
                                        await registerBackUp();
                                        ref
                                            .read(backUpRegisteredProvider
                                                .notifier)
                                            .set(true);
                                      }
                                      ref
                                          .read(backupStatusProvider.notifier)
                                          .set(true);
                                      final status =
                                          await BackupService.performBackup();
                                      if (status && context.mounted) {
                                        showSnackBar(
                                            context, "Data Backup Completed");
                                      } else if (!status && context.mounted) {
                                        showErrorSnackBar(
                                            context, "Data Backup Failed");
                                      }
                                      ref
                                          .read(backupStatusProvider.notifier)
                                          .set(false);
                                      isLoading.value = false;
                                    } else {
                                      showErrorSnackBar(
                                          context, "No Internet Connection");
                                    }
                                  },
                                  error: (_, __) {
                                    showSnackBar(context,
                                        "An Error occured, Please try again later");
                                  },
                                  loading: () {});
                            });
            }),
            Consumer(builder: (context, ref, child) {
              final token = ref.watch(driveAccessTokenProvider);
              if (token.isEmpty) {
                return SizedBox();
              }
              return ref.watch(backupStatusProvider)
                  ? SizedBox()
                  : ListTile(
                      leading: Icon(Icons.download),
                      title: Text('Download Backup'),
                      subtitle: ref.watch(backupDownloadStatusProvider)
                          ? Text(
                              "Downloading in progress, Please wait ...",
                              style: TextStyle(fontSize: 15, color: Colors.red),
                            )
                          : null,
                      onTap: () async {
                        ref.watch(networkCheckerProvider).when(
                              data: (data) async {
                                if (data) {
                                  isLoading.value = true;
                                  final status = await BackupService
                                      .downloadFileToDevice();
                                  if (status && context.mounted) {
                                    showSnackBar(context, "Data Downloaded");
                                  } else if (!status && context.mounted) {
                                    showErrorSnackBar(
                                        context, "Data Download Failed");
                                  }
                                } else {
                                  showErrorSnackBar(
                                      context, "No Internet Connection");
                                }
                              },
                              error: (err, obj) => showErrorSnackBar(context,
                                  "An Error occured, Please try again later"),
                              loading: () =>
                                  showErrorSnackBar(context, "Please wait ..."),
                            );

                        isLoading.value = false;
                      },
                    );
            }),
            Consumer(builder: (context, ref, child) {
              final token = ref.watch(driveAccessTokenProvider);
              return ListTile(
                leading: Icon(Icons.change_circle_outlined),
                title: Text(token.isEmpty ? 'Add Account' : 'Change Account'),
                onTap: () async {
                  isLoading.value = true;
                  final chngAccount = await changeAccount(context);
                  if (chngAccount.length == 2) {
                    final authentication = chngAccount[0];
                    final account = chngAccount[1];
                    if (account != null) {
                      ref
                          .read(displayNameProvider.notifier)
                          .set(account!.displayName ?? "");
                      ref
                          .read(photoUrlProvider.notifier)
                          .set(account!.photoUrl ?? "");
                      ref.read(emailProvider.notifier).set(account!.email);
                      ref
                          .read(driveAccessTokenProvider.notifier)
                          .set(authentication.accessToken ?? "");
                    }
                    isLoading.value = false;
                    if (context.mounted) {
                      showSnackBar(context, "Account Changed");
                    }
                  }
                },
              );
            }),
            Consumer(builder: (context, ref, child) {
              final token = ref.watch(driveAccessTokenProvider);
              if (token.isEmpty) {
                return SizedBox();
              }
              return ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Remove Account'),
                  onTap: () async {
                    await removeAccount();
                    ref.read(displayNameProvider.notifier).set("");
                    ref.read(photoUrlProvider.notifier).set("");
                    ref.read(emailProvider.notifier).set("");
                    ref.read(backUpRegisteredProvider.notifier).set(false);
                  });
            }),
            ListTile(
                leading: Icon(Icons.star_rate),
                title: Text('Rate Us'),
                onTap: _openReview),
            ListTile(
              leading: Icon(Icons.share),
              title: Text('Share App'),
              onTap: () {
                Share.share(
                  '''Mortgage is a mortgage calculator app that helps you calculate your monthly mortgage payments. It also helps you understand the different types of mortgages and how much you can borrow. Mortgage is available on both Android and iOS.
                \nYou can download Mortgage from the Google Play Store or the App Store.
                Playstore: https://play.google.com/store/apps/details?id=com.kumpali.mortgage
                App Store: https://apps.apple.com/us/app/mortgage-mortgage-calculator/id1502002892
                \n\nThank you for using Mortgage!
                ''',
                  subject: 'Install this awesome app!',
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.edit_square),
              title: Text("Write Us"),
              onTap: () {
                _launchURL('https://forms.gle/zSRbdvU45hvPWEYp7');
              },
            ),
            ListTile(
              leading: Icon(Icons.policy),
              title: Text('Privacy Policy'),
              onTap: () {
                _launchURL('https://mortgage.kumpali.com/privacy.html');
              },
            ),
            ListTile(
              leading: Icon(Icons.info_outline),
              title: Consumer(builder: (context, ref, child) {
                return ref.watch(appVersionProvider).when(
                    data: (appVersion) {
                      return Text('App Version:  $appVersion');
                    },
                    error: (obj, trace) {
                      return Text("An error occurred");
                    },
                    loading: () => Text("..."));
              }),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openReview() async {
    const mortgage = MethodChannel('mortgage');
    try {
      await mortgage.invokeMethod('openReview');
    } on PlatformException catch (e) {
      debugPrint("Failed to open review page: '${e.message}'.");
    }
  }

  void _launchURL(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.inAppWebView,
        browserConfiguration: BrowserConfiguration(
          showTitle: true,
        ),
      );
    } else {
      throw 'Could not launch $url';
    }
  }
}
