import 'package:flutter/material.dart';
import 'package:flutter_color_picker_plus/flutter_color_picker_plus.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mortgage/service/backup_service.dart';
import 'package:mortgage/db/fastdb.dart';
import 'package:mortgage/provider/provider.dart';

class MyDrawer extends StatelessWidget {
  const MyDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary,
            ),
            child: Stack(
              children: [
                Text(
                  'Mortgage',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSecondary,
                      fontSize: 24),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Consumer(
                    builder: (context, ref, child) {
                      return IconButton(
                        onPressed: ()async {
                         await ref.read(themeModeManagerProvider.notifier).set();
                        },
                        icon: ref.watch(themeModeManagerProvider).index == 2 ?  Icon( Icons.light_mode,color: Theme.of(context).colorScheme.onSecondary)  : 
                        Icon( Icons.dark_mode, color: Theme.of(context).colorScheme.onSecondary),
                      );
                    }
                  ),
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
                    content: Text(
                      'This is a sample app demonstrating a Flutter Drawer with persistent storage for font size and displaying app version.',
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
                        return ElevatedButton(
                          child: const Text('Got it'),
                          onPressed: () async {
                            await ref.read(appColorProvider.notifier).set();
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                        );
                      }),
                    ],
                  ),
                );
              }),
          ListTile(
            leading: Icon(Icons.text_fields),
            title: Text('Change Font Size',
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
                    title: Text('Change Font Size'),
                    content: SizedBox(
                      height: 200,
                      child: Column(
                        children: [
                          Consumer(builder: (context, ref, child) {
                            final sliderFontSize =
                                ref.watch(sliderFontSizeProvider);
                            return Slider(
                              value: sliderFontSize,
                              min: 10.0,
                              max: 30.0,
                              divisions: 20,
                              label: sliderFontSize.round().toString(),
                              onChanged: (value) {
                                ref
                                    .read(sliderFontSizeProvider.notifier)
                                    .set(value);
                              },
                            );
                          }),
                          Consumer(builder: (context, ref, child) {
                            return Text(
                              "Mortgage",
                              style: TextStyle(
                                  fontSize: ref.watch(sliderFontSizeProvider)),
                            );
                          })
                        ],
                      ),
                    ),
                    actions: [
                      Consumer(builder: (context, ref, child) {
                        return TextButton(
                          onPressed: () async {
                            await ref.read(fontSizeProvider.notifier).set();
                            if (context.mounted) {
                              Navigator.of(context).pop();
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
                            await ref.read(fontSizeProvider.notifier).set();
                            if (context.mounted) {
                              Navigator.of(context).pop();
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
          Consumer(builder: (context, ref, child) {
            final hour = ref.watch(scheduledBackUpTimeHourProvider);
            final minute = ref.watch(scheduledBackUpTimeMinuteProvider);
            return ListTile(
                leading: Icon(Icons.settings_backup_restore),
                title: Text('Set Backup Time'),
                onTap: () async {
                  final TimeOfDay? picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(hour: hour, minute: minute),
                  );
                  if (picked != null) {
                    FastDB.putScheduledBackUpTimeHour(picked.hour);
                    FastDB.putScheduledBackUpTimeMinute(picked.minute);
                    await FastDB.flush();
                    ref
                        .read(scheduledBackUpTimeHourProvider.notifier)
                        .set(picked.hour);
                    ref
                        .read(scheduledBackUpTimeMinuteProvider.notifier)
                        .set(picked.minute);
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  }
                });
          }),
          Consumer(
            builder: (context, ref, child) {
              return ListTile(leading: Icon(Icons.backup), title: Text("Back up now"),
              subtitle: ref.watch(backupStatusProvider) ? Text("Backup in progress", style: TextStyle(fontSize: 15, color:Colors.red),) : null,
              onTap:ref.watch(backupStatusProvider) ? null : () async{
                final BackupService backupService = BackupService();
                ref.read(backupStatusProvider.notifier).set(true);
                await backupService.performBackup();
                ref.read(backupStatusProvider.notifier).set(false);
              },
              );
            }
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
    );
  }
}
