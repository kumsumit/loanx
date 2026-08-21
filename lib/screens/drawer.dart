import 'dart:io';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_color_picker_plus/flutter_color_picker_plus.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loanx/extension/string.dart';
import 'package:loanx/model/loan.dart';
import 'package:loanx/service/backup_service.dart';
import 'package:loanx/db/fastdb.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/service/update_service.dart';
import 'package:loanx/widget/avatar.dart';
import 'package:loanx/widget/bullet.dart';
import 'package:loanx/widget/loading_overlay.dart';
import 'package:loanx/widget/snackbar.dart';
import 'package:loanx/widget/styled_text.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

// import 'package:workmanager/workmanager.dart';

class MyDrawer extends HookConsumerWidget {
  const MyDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = useState(false);
    final scrollController = useScrollController(keepScrollOffset: false);
    return LoadingOverlay(
      isLoading: isLoading.value,
      child: Drawer(
        child: Scrollbar(
          controller: scrollController,
          thumbVisibility: true,
          child: ListView(
            controller: scrollController,
            primary: false,
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  // A solid fill avoids gradient render-target corruption on
                  // older Android GPUs.
                  color: Theme.of(context).colorScheme.primary,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'LoanX',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 26,
                          ),
                        ),
                        Consumer(
                          builder: (context, ref, child) {
                            final networkStatus = ref.watch(
                              networkCheckerProvider,
                            );
                            final imageUrl = ref.watch(photoUrlProvider);
                            final displayName = ref.watch(displayNameProvider);
                            return networkStatus.when(
                              data: (data) {
                                return data
                                    ? ProfilePicture(
                                        imageUrl: imageUrl,
                                        displayName: displayName,
                                      )
                                    : LocalProfilePicture(
                                        displayName: displayName,
                                      );
                              },
                              error: (obj, trace) {
                                return ProfilePicture(
                                  imageUrl: ref.watch(photoUrlProvider),
                                  displayName: ref.watch(displayNameProvider),
                                );
                              },
                              loading: () => ProfilePicture(
                                imageUrl: ref.watch(photoUrlProvider),
                                displayName: ref.watch(displayNameProvider),
                              ),
                            );
                          },
                        ),
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
                              Consumer(
                                builder: (context, ref, child) {
                                  return AutoSizeText(
                                    ref.watch(displayNameProvider),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                    ),
                                    minFontSize: 10,
                                  );
                                },
                              ),
                              Consumer(
                                builder: (context, ref, child) {
                                  return AutoSizeText(
                                    ref.watch(emailProvider),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                    ),
                                    maxLines:
                                        3, // Set the maximum number of lines
                                    overflow: TextOverflow.visible,
                                    minFontSize: 10,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        Consumer(
                          builder: (context, ref, child) {
                            return InkWell(
                              onTap: ref.watch(backupDownloadStatusProvider)
                                  ? null
                                  : () async {
                                      await ref
                                          .read(
                                            themeModeManagerProvider.notifier,
                                          )
                                          .set();
                                    },
                              child:
                                  ref.watch(themeModeManagerProvider).index == 2
                                  ? Icon(
                                      Icons.light_mode,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                    )
                                  : Icon(
                                      Icons.dark_mode,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                    ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ExpansionTile(
                leading: StyledIcon(Icons.info_outline),
                title: StyledText('About LoanX'),
                subtitle: StyledSubtitle('Learn about the app'),
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerLow,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                children: [
                  const Divider(indent: 16, endIndent: 16),
                  ListTile(
                    leading: StyledIcon(Icons.article_outlined),
                    title: StyledText('What is LoanX?'),
                    subtitle: StyledSubtitle('Learn what LoanX can do'),
                    onTap: () {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) {
                          return Dialog(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(height: 10),
                                    StyledHeading('About'),
                                    BulletPoint(
                                      'Traditionally practiced, now technologically advanced.',
                                      italic: true,
                                    ),
                                    BulletPoint(
                                      'A revolutionary app to keep records of loans provided by the unorganized sector of the Lenders across the world without any paperwork.',
                                    ),
                                    BulletPoint(
                                      'LoanX is a simple and easy to use app that allows you to track your loans. It is designed to be user-friendly and intuitive, making it easy for anyone to manage their loan records.',
                                    ),
                                    BulletPoint(
                                      'With LoanX, you can easily create, update, and delete loan records, as well as view your loan history.',
                                    ),
                                    BulletPoint(
                                      'The app also provides a feature to backup your data, ensuring that your information is secure and accessible in case of any data loss.',
                                    ),
                                    BulletPoint(
                                      'Currently, Loanx is available on only Android, But soon will be accessible to other platforms too for making it accessible to a wide range of users.',
                                    ),
                                    BulletPoint(
                                      'Whether you\'re a seasoned loan professional or just starting out, Loanx is the perfect app to help you manage your loans smoothly, efficiently and economically.',
                                    ),
                                    OutlinedButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                      child: Text('OK'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
              ExpansionTile(
                leading: StyledIcon(Icons.tune_rounded),
                title: StyledText('App preferences'),
                subtitle: StyledSubtitle('Security and appearance'),
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerLow,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                children: [
                  const Divider(indent: 16, endIndent: 16),
                  Consumer(
                    builder: (context, ref, child) {
                      final secure = ref.watch(secureProvider);
                      return ListTile(
                        leading: StyledIcon(
                          secure
                              ? Icons.lock_open_rounded
                              : Icons.lock_outlined,
                        ),
                        title: StyledText(
                          secure ? 'Disable app lock' : 'Enable app lock',
                        ),
                        onTap: () {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => Dialog(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: SingleChildScrollView(
                                  child: Column(
                                    spacing: 10,
                                    children: [
                                      SizedBox(height: 10),
                                      StyledHeading('Confirmation'),
                                      StyledSubtitle(
                                        secure
                                            ? "Disable the app lock on this device?"
                                            : "Enable an app lock on this device?",
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          OutlinedButton(
                                            child: const Text('Cancel'),
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                          ),
                                          OutlinedButton(
                                            child: const Text('Ok'),
                                            onPressed: () async {
                                              await ref
                                                  .read(secureProvider.notifier)
                                                  .toggle();
                                              if (context.mounted) {
                                                Navigator.of(context).pop();
                                                if (secure) {
                                                  showSnackBar(
                                                    context,
                                                    "App gets unsecured, Now you need to restart the app",
                                                  );
                                                } else {
                                                  showSnackBar(
                                                    context,
                                                    "App gets secured, Now you need to restart the app",
                                                  );
                                                }
                                              }
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
                          );
                        },
                      );
                    },
                  ),
                  ListTile(
                    leading: StyledIcon(Icons.color_lens),
                    title: StyledText('App color'),
                    onTap: () {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => Dialog(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SingleChildScrollView(
                              child: Column(
                                spacing: 10,
                                children: [
                                  SizedBox(height: 10),
                                  StyledHeading('Pick a color!'),
                                  Consumer(
                                    builder: (context, ref, child) {
                                      final color = ref.watch(
                                        pickerColorProvider,
                                      );
                                      return ColorPicker(
                                        pickerColor: Color(
                                          int.parse(color, radix: 16),
                                        ),
                                        onColorChanged: ref
                                            .read(pickerColorProvider.notifier)
                                            .set,
                                      );
                                    },
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: <Widget>[
                                      OutlinedButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                        child: Text('Cancel'),
                                      ),
                                      Consumer(
                                        builder: (context, ref, child) {
                                          return OutlinedButton(
                                            child: const Text('Ok'),
                                            onPressed: () async {
                                              await ref
                                                  .read(
                                                    appColorProvider.notifier,
                                                  )
                                                  .set();
                                              if (context.mounted) {
                                                Navigator.of(context).pop();
                                                showSnackBar(
                                                  context,
                                                  "App Color Changed",
                                                );
                                              }
                                            },
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  Consumer(
                                    builder: (context, ref, child) {
                                      return OutlinedButton(
                                        onPressed: () async {
                                          await ref
                                              .read(appColorProvider.notifier)
                                              .setFromLogo(context);
                                          if (context.mounted) {
                                            Navigator.pop(context);
                                          }
                                        },
                                        child: Text("Set Color Using Image"),
                                      );
                                    },
                                  ),
                                  SizedBox(height: 10),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              ExpansionTile(
                leading: StyledIcon(Icons.calculate_outlined),
                title: StyledText('Loan defaults'),
                subtitle: StyledSubtitle('Interest and mortgage settings'),
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerLow,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                children: [
                  const Divider(indent: 16, endIndent: 16),
                  ListTile(
                    leading: StyledIcon(Icons.currency_exchange),
                    title: StyledText('Mortgage term'),
                    subtitle: Consumer(
                      builder: (context, ref, child) {
                        final holdingPeriod = ref.watch(holdingPeriodProvider);
                        return StyledSubtitle(
                          "Default is $holdingPeriod Years",
                        );
                      },
                    ),
                    onTap: () {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) {
                          return Dialog(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: SingleChildScrollView(
                                child: Column(
                                  children: [
                                    SizedBox(height: 10),
                                    StyledHeading(
                                      'Change Mortgage Holding Period',
                                      maxLines: 2,
                                    ),
                                    Consumer(
                                      builder: (context, ref, child) {
                                        final holdingPeriod = ref.watch(
                                          holdingPeriodProvider,
                                        );
                                        debugPrint(holdingPeriod.toString());
                                        return Slider(
                                          value: holdingPeriod.toDouble(),
                                          min: 0,
                                          max: 30,
                                          divisions: 30,
                                          label: holdingPeriod.toString(),
                                          onChanged: (value) {
                                            if (value.toInt() == 0) {
                                              showErrorSnackBar(
                                                context,
                                                "Holding Period can't be 0",
                                              );
                                              return;
                                            }
                                            if (value.toInt() !=
                                                holdingPeriod.toInt()) {
                                              ref
                                                  .read(
                                                    holdingPeriodProvider
                                                        .notifier,
                                                  )
                                                  .set(value.toInt());
                                            }
                                          },
                                        );
                                      },
                                    ),
                                    Consumer(
                                      builder: (context, ref, child) {
                                        final holdingPeriod = ref.watch(
                                          holdingPeriodProvider,
                                        );
                                        return StyledSubtitle(
                                          "Mortgage Holding Period : $holdingPeriod Years",
                                        );
                                      },
                                    ),
                                    StyledSubtitle(
                                      "Default holding Period is 5 years",
                                      fontSize: 12,
                                    ),
                                    SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        OutlinedButton(
                                          onPressed: () async {
                                            Navigator.pop(context);
                                          },
                                          child: Text('Cancel'),
                                        ),
                                        Consumer(
                                          builder: (context, ref, child) {
                                            return OutlinedButton(
                                              onPressed: () async {
                                                await FastDB.flush();
                                                if (context.mounted) {
                                                  Navigator.of(context).pop();
                                                  showSnackBar(
                                                    context,
                                                    "Mortgage Holding Period changed",
                                                  );
                                                }
                                              },
                                              child: Text(
                                                'OK',
                                                style: TextStyle(
                                                  fontSize: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium!
                                                      .fontSize,
                                                ),
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
                          );
                        },
                      );
                    },
                  ),
                  ListTile(
                    leading: StyledIcon(Icons.input),
                    title: StyledText('Interest type'),
                    subtitle: Consumer(
                      builder: (context, ref, child) {
                        final interestType = ref.watch(
                          interestTypeStatusProvider,
                        );
                        return StyledSubtitle(
                          "Default is ${interestType.name.toSentenceCase()} Interest",
                        );
                      },
                    ),
                    onTap: () async {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) {
                          return Dialog(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(height: 10),
                                    StyledHeading('Select Interest Type'),
                                    Consumer(
                                      builder: (context, ref, child) {
                                        final interestType = ref.watch(
                                          interestTypeStatusProvider,
                                        );
                                        return RadioGroup<InterestType>(
                                          groupValue: interestType,
                                          onChanged: (value) {
                                            if (value != null) {
                                              ref
                                                  .read(
                                                    interestTypeStatusProvider
                                                        .notifier,
                                                  )
                                                  .set(value);
                                            }
                                          },
                                          child: ListView.builder(
                                            shrinkWrap: true,
                                            itemCount:
                                                InterestType.values.length,
                                            itemBuilder: (context, index) {
                                              return RadioListTile(
                                                value:
                                                    InterestType.values[index],
                                                title: StyledSubtitle(
                                                  InterestType
                                                      .values[index]
                                                      .name
                                                      .toSentenceCase(),
                                                ),
                                              );
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        OutlinedButton(
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                          child: Text('Cancel'),
                                        ),
                                        Consumer(
                                          builder: (context, ref, child) {
                                            return OutlinedButton(
                                              onPressed: () async {
                                                await FastDB.flush();
                                                if (context.mounted) {
                                                  Navigator.of(context).pop();
                                                  showSnackBar(
                                                    context,
                                                    "Interest Type changed successfully",
                                                  );
                                                }
                                              },
                                              child: Text(
                                                'OK',
                                                style: TextStyle(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                ),
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
                          );
                        },
                      );
                    },
                  ),
                  Consumer(
                    builder: (context, ref, child) {
                      final interestFrequency = ref.watch(
                        interestFrequencyStatusProvider,
                      );
                      return ListTile(
                        leading: StyledIcon(Icons.calendar_month_outlined),
                        title: StyledText('Interest frequency'),
                        subtitle: StyledSubtitle(
                          'Default interest frequency is ${interestFrequency.name}',
                        ),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => Dialog(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: [
                                      SizedBox(height: 10),
                                      StyledHeading('Interest Frequency'),
                                      RadioGroup<InterestFrequency>(
                                        groupValue: interestFrequency,
                                        onChanged: (value) {
                                          if (value != null) {
                                            ref
                                                .read(
                                                  interestFrequencyStatusProvider
                                                      .notifier,
                                                )
                                                .set(value);
                                          }
                                        },
                                        child: Wrap(
                                          alignment: WrapAlignment.center,
                                          spacing: 20.0,
                                          children: [
                                            for (final option
                                                in InterestFrequency.values)
                                              RadioListTile(
                                                value: option,
                                                title: StyledSubtitle(
                                                  option.name.toSentenceCase(),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      StyledText(
                                        'The interest frequency is set to ${interestFrequency.name}',
                                      ),
                                      SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          OutlinedButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                            },
                                            child: Text("Cancel"),
                                          ),
                                          OutlinedButton(
                                            onPressed: () async {
                                              await FastDB.flush();
                                              if (context.mounted) {
                                                Navigator.pop(context);
                                              }
                                            },
                                            child: Text('Ok'),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 10),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  ListTile(
                    leading: StyledIcon(Icons.percent),
                    title: StyledText('Interest rate'),
                    subtitle: Consumer(
                      builder: (context, ref, child) {
                        final interestRate = ref.watch(interestRateProvider);
                        return StyledSubtitle(
                          "Default Interest Rate is $interestRate %",
                        );
                      },
                    ),
                    onTap: () {
                      List<String> interestRateString = [];
                      showDialog(
                        context: context,
                        builder: (context) => Dialog(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SingleChildScrollView(
                              child: Column(
                                spacing: 10,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(height: 10),
                                  StyledHeading('Change Interest Rate'),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Consumer(
                                          builder: (context, ref, child) {
                                            final interestRate = ref.watch(
                                              interestRateProvider,
                                            );
                                            interestRateString = interestRate
                                                .toString()
                                                .split(".");
                                            return CupertinoPicker(
                                              itemExtent: 32,
                                              scrollController:
                                                  FixedExtentScrollController(
                                                    initialItem: interestRate
                                                        .toInt(),
                                                  ),
                                              selectionOverlay:
                                                  const CupertinoPickerDefaultSelectionOverlay(
                                                    capEndEdge: false,
                                                  ),
                                              onSelectedItemChanged: (val) {
                                                interestRateString[0] = val
                                                    .toString();
                                              },
                                              children: List.generate(
                                                51,
                                                (index) => StyledSubtitle(
                                                  index.toString(),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      SizedBox(width: 5),
                                      Center(
                                        child: StyledSubtitle(
                                          ".",
                                          fontSize: 20,
                                        ),
                                      ),
                                      SizedBox(width: 5),
                                      Expanded(
                                        child: Consumer(
                                          builder: (context, ref, child) {
                                            return CupertinoPicker(
                                              itemExtent: 32,
                                              scrollController:
                                                  FixedExtentScrollController(
                                                    initialItem:
                                                        int.tryParse(
                                                          interestRateString[1],
                                                        ) ??
                                                        0,
                                                  ),
                                              selectionOverlay:
                                                  CupertinoPickerDefaultSelectionOverlay(
                                                    // background: Theme.of(context).colorScheme.primary,
                                                    capStartEdge: false,
                                                  ),
                                              onSelectedItemChanged: (val) {
                                                interestRateString[1] = val
                                                    .toString();
                                              },
                                              children: List.generate(
                                                100,
                                                (index) => StyledSubtitle(
                                                  index.toString(),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      SizedBox(width: 5),
                                      Center(
                                        child: StyledSubtitle(
                                          "%",
                                          fontSize: 20,
                                        ),
                                      ),
                                      SizedBox(width: 5),
                                    ],
                                  ),
                                  Consumer(
                                    builder: (context, ref, child) {
                                      final interestRate = ref.watch(
                                        interestRateProvider,
                                      );
                                      return StyledSubtitle(
                                        "Current Interest rate is $interestRate %",
                                      );
                                    },
                                  ),
                                  SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      OutlinedButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                        child: Text('Cancel'),
                                      ),
                                      Consumer(
                                        builder: (context, ref, child) {
                                          return OutlinedButton(
                                            onPressed: () async {
                                              if (interestRateString[1].length >
                                                  2) {
                                                interestRateString[1] =
                                                    interestRateString[1]
                                                        .substring(0, 2);
                                              } else if (interestRateString[1]
                                                      .length ==
                                                  1) {
                                                interestRateString[1] =
                                                    "0${interestRateString[1]}";
                                              }
                                              ref
                                                  .read(
                                                    interestRateProvider
                                                        .notifier,
                                                  )
                                                  .set(
                                                    double.parse(
                                                      '${interestRateString[0]}.${interestRateString[1]}',
                                                    ),
                                                  );
                                              await FastDB.flush();
                                              if (context.mounted) {
                                                Navigator.of(context).pop();
                                                showSnackBar(
                                                  context,
                                                  "Interest Rate Changed",
                                                );
                                              }
                                            },
                                            child: Text('OK'),
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
                      );
                    },
                  ),
                  const _DefaultLockInSetting(),
                  const _DefaultTermsAndConditionsSetting(),
                ],
              ),
              ExpansionTile(
                leading: StyledIcon(Icons.cloud_outlined),
                title: StyledText('Backup & Google Drive'),
                subtitle: Consumer(
                  builder: (context, ref, child) {
                    final email = ref.watch(emailProvider);
                    return StyledSubtitle(
                      email.isEmpty ? 'Not connected' : email,
                    );
                  },
                ),
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerLow,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                children: [
                  const Divider(indent: 16, endIndent: 16),
                  Consumer(
                    builder: (context, ref, child) {
                      final hour = ref.watch(scheduledBackUpTimeHourProvider);
                      final minute = ref.watch(
                        scheduledBackUpTimeMinuteProvider,
                      );
                      final isBackUpRegistered = ref.watch(
                        backUpRegisteredProvider,
                      );
                      final time = TimeOfDay(hour: hour, minute: minute);
                      if (isBackUpRegistered) {
                        return ListTile(
                          leading: StyledIcon(Icons.settings_backup_restore),
                          title: StyledText('Change Backup Time'),
                          subtitle: StyledSubtitle(
                            "Default is ${time.format(context)}",
                          ),
                          onTap: () async {
                            final TimeOfDay? picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: hour,
                                minute: minute,
                              ),
                            );
                            if (picked != null) {
                              ref
                                  .read(
                                    scheduledBackUpTimeHourProvider.notifier,
                                  )
                                  .set(picked.hour);
                              ref
                                  .read(
                                    scheduledBackUpTimeMinuteProvider.notifier,
                                  )
                                  .set(picked.minute);
                              await FastDB.flush();
                              await registerBackUp();
                              ref
                                  .read(backUpRegisteredProvider.notifier)
                                  .set(true);
                              if (context.mounted) {
                                Navigator.pop(context);
                                showSnackBar(
                                  context,
                                  'Backup Time Updated to Time ${picked.format(context)}',
                                );
                              }
                            }
                          },
                        );
                      } else {
                        return SizedBox();
                      }
                    },
                  ),
                  Consumer(
                    builder: (context, ref, child) {
                      final token = ref.watch(driveAccessTokenProvider);
                      if (token.isEmpty) {
                        return SizedBox();
                      }
                      return ref.watch(backupDownloadStatusProvider)
                          ? SizedBox()
                          : ListTile(
                              leading: StyledIcon(Icons.backup),
                              title: StyledText("Back up now"),
                              subtitle: ref.watch(backupStatusProvider)
                                  ? Text(
                                      "Creating your secure Google Drive backup…",
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      ),
                                    )
                                  : null,
                              onTap: ref.watch(backupStatusProvider)
                                  ? null
                                  : () async {
                                      ref
                                          .read(backupStatusProvider.notifier)
                                          .set(true);
                                      isLoading.value = true;
                                      try {
                                        final connected = await ref
                                            .read(networkCheckerProvider.future)
                                            .timeout(
                                              const Duration(seconds: 10),
                                            );
                                        if (!connected) {
                                          if (context.mounted) {
                                            showErrorSnackBar(
                                              context,
                                              'No internet connection.',
                                            );
                                          }
                                          return;
                                        }
                                        if (!FastDB.getIsBackUpRegistered()) {
                                          await registerBackUp();
                                          ref
                                              .read(
                                                backUpRegisteredProvider
                                                    .notifier,
                                              )
                                              .set(true);
                                        }
                                        final status =
                                            await BackupService.performBackup(
                                              promptIfNeeded: true,
                                            );
                                        if (!context.mounted) return;
                                        if (status) {
                                          ref
                                              .read(
                                                backupAvailableProvider
                                                    .notifier,
                                              )
                                              .set(true);
                                          showSnackBar(
                                            context,
                                            'Backup created successfully.',
                                          );
                                        } else {
                                          showErrorSnackBar(
                                            context,
                                            BackupService.lastError,
                                          );
                                        }
                                      } catch (error, stackTrace) {
                                        debugPrint(
                                          'Manual backup failed: '
                                          '$error\n$stackTrace',
                                        );
                                        if (context.mounted) {
                                          showErrorSnackBar(
                                            context,
                                            'Could not create the backup. '
                                            'Please try again.',
                                          );
                                        }
                                      } finally {
                                        ref
                                            .read(backupStatusProvider.notifier)
                                            .set(false);
                                        if (context.mounted) {
                                          isLoading.value = false;
                                        }
                                      }
                                    },
                            );
                    },
                  ),
                  Consumer(
                    builder: (context, ref, child) {
                      final token = ref.watch(driveAccessTokenProvider);
                      final backupAvailable = ref.watch(
                        backupAvailableProvider,
                      );
                      if (token.isEmpty || !backupAvailable) {
                        return SizedBox();
                      }
                      return ref.watch(backupStatusProvider)
                          ? SizedBox()
                          : ListTile(
                              leading: StyledIcon(Icons.download),
                              title: StyledText('Restore latest backup'),
                              subtitle: ref.watch(backupDownloadStatusProvider)
                                  ? Text(
                                      "Restoring your backup…",
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      ),
                                    )
                                  : null,
                              onTap: () async {
                                ref
                                    .read(backupDownloadStatusProvider.notifier)
                                    .set(true);
                                isLoading.value = true;
                                try {
                                  final connected = await ref
                                      .read(networkCheckerProvider.future)
                                      .timeout(const Duration(seconds: 10));
                                  if (!connected) {
                                    if (context.mounted) {
                                      showErrorSnackBar(
                                        context,
                                        "No internet connection.",
                                      );
                                    }
                                    return;
                                  }
                                  final restored =
                                      await BackupService.downloadFileToDevice();
                                  if (!context.mounted) return;
                                  if (restored) {
                                    _refreshAfterRestore(ref);
                                    showSnackBar(
                                      context,
                                      "Backup restored successfully.",
                                    );
                                  } else {
                                    showErrorSnackBar(
                                      context,
                                      BackupService.lastError,
                                    );
                                  }
                                } catch (_) {
                                  if (context.mounted) {
                                    showErrorSnackBar(
                                      context,
                                      "Could not restore the backup. Please try again.",
                                    );
                                  }
                                } finally {
                                  ref
                                      .read(
                                        backupDownloadStatusProvider.notifier,
                                      )
                                      .set(false);
                                  if (context.mounted) isLoading.value = false;
                                }
                              },
                            );
                    },
                  ),
                  Consumer(
                    builder: (context, ref, child) {
                      final token = ref.watch(driveAccessTokenProvider);
                      return ListTile(
                        leading: StyledIcon(Icons.change_circle_outlined),
                        title: StyledText(
                          token.isEmpty ? 'Add Account' : 'Change Account',
                        ),
                        onTap: () async {
                          final isAddingAccount = token.isEmpty;
                          if (!isAddingAccount) {
                            FastDB.putDriveFileId("");
                            ref
                                .read(backupAvailableProvider.notifier)
                                .set(false);
                          }
                          isLoading.value = true;
                          try {
                            var mergedBackup = false;
                            var mergeFailed = false;
                            final chngAccount = await changeAccount(
                              context,
                            ).timeout(const Duration(seconds: 90));
                            if (chngAccount.length == 2) {
                              final authentication = chngAccount[0];
                              final account = chngAccount[1];
                              if (account != null) {
                                ref
                                    .read(displayNameProvider.notifier)
                                    .set(account.displayName ?? "");
                                ref
                                    .read(photoUrlProvider.notifier)
                                    .set(account.photoUrl ?? "");
                                ref
                                    .read(emailProvider.notifier)
                                    .set(account.email);
                                ref
                                    .read(driveAccessTokenProvider.notifier)
                                    .set(authentication.accessToken ?? "");
                                ref
                                    .read(backUpRegisteredProvider.notifier)
                                    .set(true);
                                // Account details are published before the Drive
                                // lookup, so the drawer updates as soon as sign-in
                                // succeeds. The lookup only controls restore access.
                                final hasBackup =
                                    await BackupService.hasBackupOnDrive(
                                      account: account,
                                    );
                                ref
                                    .read(backupAvailableProvider.notifier)
                                    .set(hasBackup);
                                await FastDB.flush();
                                if (hasBackup) {
                                  mergedBackup =
                                      await BackupService.downloadFileToDevice(
                                        account: account,
                                      );
                                  if (mergedBackup) {
                                    _refreshAfterRestore(ref);
                                  } else {
                                    mergeFailed = true;
                                  }
                                }
                              }
                              if (context.mounted) {
                                if (mergeFailed) {
                                  showErrorSnackBar(
                                    context,
                                    'Account connected, but its backup could '
                                    'not be merged. ${BackupService.lastError}',
                                  );
                                } else {
                                  showSnackBar(
                                    context,
                                    mergedBackup
                                        ? 'Google account connected and backup data merged.'
                                        : isAddingAccount
                                        ? 'Google account connected.'
                                        : 'Google account updated.',
                                  );
                                }
                              }
                            } else if (context.mounted) {
                              showSnackBar(
                                context,
                                "You have not selected any account.",
                              );
                            }
                          } catch (error, stackTrace) {
                            debugPrint(
                              'Google account connection failed: $error\n$stackTrace',
                            );
                            if (context.mounted) {
                              final message =
                                  BackupService.userFacingGoogleSignInError(
                                    error,
                                  );
                              if (BackupService.isUserCancelledGoogleSignIn(
                                error,
                              )) {
                                showSnackBar(context, message);
                              } else {
                                showErrorSnackBar(context, message);
                              }
                            }
                          } finally {
                            if (context.mounted) {
                              isLoading.value = false;
                            }
                          }
                        },
                      );
                    },
                  ),
                  Consumer(
                    builder: (context, ref, child) {
                      final token = ref.watch(driveAccessTokenProvider);
                      if (token.isEmpty) {
                        return SizedBox();
                      }
                      return ListTile(
                        leading: StyledIcon(Icons.account_circle_outlined),
                        title: StyledText('View connected account'),
                        subtitle: StyledSubtitle(ref.watch(emailProvider)),
                        onTap: () {
                          final name = ref.read(displayNameProvider);
                          final email = ref.read(emailProvider);
                          showModalBottomSheet<void>(
                            context: context,
                            showDragHandle: true,
                            builder: (sheetContext) => Padding(
                              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 30,
                                    child: const Icon(
                                      Icons.person_outline,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    name.isEmpty ? 'Google account' : name,
                                    style: Theme.of(
                                      sheetContext,
                                    ).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(email),
                                  const SizedBox(height: 16),
                                  Text(
                                    'This account stores your LoanX backups in Google Drive.',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(
                                      sheetContext,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  Consumer(
                    builder: (context, ref, child) {
                      final token = ref.watch(driveAccessTokenProvider);
                      if (token.isEmpty) {
                        return SizedBox();
                      }
                      return ListTile(
                        leading: StyledIcon(Icons.logout),
                        title: StyledText('Disconnect Google account'),
                        onTap: () async {
                          isLoading.value = true;
                          try {
                            await removeAccount();
                            ref.read(displayNameProvider.notifier).set("");
                            ref.read(photoUrlProvider.notifier).set("");
                            ref.read(emailProvider.notifier).set("");
                            ref.read(driveAccessTokenProvider.notifier).set("");
                            ref
                                .read(backUpRegisteredProvider.notifier)
                                .set(false);
                            ref
                                .read(backupAvailableProvider.notifier)
                                .set(false);
                            if (context.mounted) {
                              showSnackBar(
                                context,
                                'Google account disconnected.',
                              );
                            }
                          } catch (error, stackTrace) {
                            debugPrint(
                              'Google account disconnect failed: '
                              '$error\n$stackTrace',
                            );
                            if (context.mounted) {
                              showErrorSnackBar(
                                context,
                                'Could not disconnect the Google account.',
                              );
                            }
                          } finally {
                            if (context.mounted) isLoading.value = false;
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
              ExpansionTile(
                leading: StyledIcon(Icons.support_agent_outlined),
                title: StyledText('Help & feedback'),
                subtitle: StyledSubtitle('Support, sharing, and updates'),
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerLow,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                children: [
                  const Divider(indent: 16, endIndent: 16),
                  ListTile(
                    leading: StyledIcon(Icons.star_rate),
                    title: StyledText('Rate LoanX'),
                    onTap: _openReview,
                  ),
                  ListTile(
                    leading: StyledIcon(Icons.share),
                    title: StyledText('Share App'),
                    onTap: () {
                      final box = context.findRenderObject() as RenderBox?;
                      SharePlus.instance.share(
                        ShareParams(
                          text:
                              '''loanx is a loanx calculator app that helps you calculate your monthly loanx payments. It also helps you understand the different types of loanxs and how much you can borrow. loanx is available on both Android and iOS.
                \nYou can download loanx from the Google Play Store or the App Store.
                Playstore: https://play.google.com/store/apps/details?id=com.kumpali.loanx
                App Store: https://apps.apple.com/us/app/loanx-loanx-calculator/id1502002892
                \n\nThank you for using loanx!
                ''',
                          subject: 'Install this awesome app!',
                          sharePositionOrigin:
                              box!.localToGlobal(Offset.zero) & box.size,
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: StyledIcon(Icons.edit_square),
                    title: StyledText("Contact support"),
                    onTap: () {
                      _launchURL('https://forms.gle/zSRbdvU45hvPWEYp7');
                    },
                  ),
                  ListTile(
                    leading: StyledIcon(Icons.policy),
                    title: StyledText('Privacy Policy'),
                    onTap: () {
                      _launchURL(
                        'https://loanx.kumpali.com/privacy-policy.html',
                      );
                    },
                  ),
                  if (Platform.isAndroid || Platform.isIOS)
                    ListTile(
                      leading: StyledIcon(Icons.update),
                      title: StyledText('Check for updates'),
                      onTap: () => checkForUpdates(context, true),
                    ),
                  ListTile(
                    leading: StyledIcon(Icons.info_outline),
                    title: Consumer(
                      builder: (context, ref, child) {
                        return ref
                            .watch(appVersionProvider)
                            .when(
                              data: (appVersion) {
                                return StyledText('Version $appVersion');
                              },
                              error: (obj, trace) {
                                return Text(
                                  "Version unavailable",
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                );
                              },
                              loading: () => StyledText("Version…"),
                            );
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: MediaQuery.paddingOf(context).bottom + 32),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openReview() async {
    const loanx = MethodChannel('loanx');
    try {
      await loanx.invokeMethod('openReview');
    } on PlatformException catch (e) {
      debugPrint("Failed to open review page: '${e.message}'.");
    }
  }

  void _refreshAfterRestore(WidgetRef ref) {
    ref.invalidate(loanListProvider);
    ref.invalidate(familyRelationListProvider);
    ref.invalidate(mortgageMaterialListProvider);
    ref.invalidate(weightUnitListProvider);
    ref.invalidate(themeModeManagerProvider);
    ref.invalidate(appColorProvider);
    ref.invalidate(pickerColorProvider);
    ref.invalidate(secureProvider);
    ref.invalidate(holdingPeriodProvider);
    ref.invalidate(interestTypeStatusProvider);
    ref.invalidate(interestRateProvider);
    ref.invalidate(interestFrequencyStatusProvider);
    ref.invalidate(scheduledBackUpTimeHourProvider);
    ref.invalidate(scheduledBackUpTimeMinuteProvider);
    ref.invalidate(displayNameProvider);
    ref.invalidate(emailProvider);
    ref.invalidate(photoUrlProvider);
  }

  void _launchURL(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.inAppWebView,
        browserConfiguration: BrowserConfiguration(showTitle: true),
      );
    } else {
      throw 'Could not launch $url';
    }
  }
}

class _DefaultTermsAndConditionsSetting extends StatefulWidget {
  const _DefaultTermsAndConditionsSetting();

  @override
  State<_DefaultTermsAndConditionsSetting> createState() =>
      _DefaultTermsAndConditionsSettingState();
}

class _DefaultTermsAndConditionsSettingState
    extends State<_DefaultTermsAndConditionsSetting> {
  String _terms = '';

  @override
  void initState() {
    super.initState();
    _terms = FastDB.getDefaultTermsAndConditions();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: StyledIcon(Icons.gavel_outlined),
      title: StyledText('Terms and conditions'),
      subtitle: StyledSubtitle(
        _terms.trim().isEmpty
            ? 'No default terms set'
            : 'Prefilled for new loans',
      ),
      onTap: _editTerms,
    );
  }

  Future<void> _editTerms() async {
    final terms = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DefaultTermsAndConditionsSheet(initialTerms: _terms),
    );
    if (terms == null) return;

    FastDB.putDefaultTermsAndConditions(terms);
    await FastDB.flush();
    if (!mounted) return;
    setState(() => _terms = terms);
    showSnackBar(context, 'Default terms and conditions updated');
  }
}

class _DefaultTermsAndConditionsSheet extends StatefulWidget {
  const _DefaultTermsAndConditionsSheet({required this.initialTerms});

  final String initialTerms;

  @override
  State<_DefaultTermsAndConditionsSheet> createState() =>
      _DefaultTermsAndConditionsSheetState();
}

class _DefaultTermsAndConditionsSheetState
    extends State<_DefaultTermsAndConditionsSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTerms);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Default terms and conditions',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                minLines: 4,
                maxLines: 8,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Terms and conditions',
                  hintText: 'Enter the default terms for new loans',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'These terms are copied into new loans and can be edited on each loan.',
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, _controller.text.trim()),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DefaultLockInSetting extends StatefulWidget {
  const _DefaultLockInSetting();

  @override
  State<_DefaultLockInSetting> createState() => _DefaultLockInSettingState();
}

class _DefaultLockInSettingState extends State<_DefaultLockInSetting> {
  late int _lockInDays;
  late double _charge;

  @override
  void initState() {
    super.initState();
    _lockInDays = FastDB.getDefaultLockInDays();
    _charge = FastDB.getDefaultEarlyRedemptionCharge();
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _lockInDays == 0
        ? 'New loans have no lock-in by default'
        : 'Default: $_lockInDays days · ₹${_charge.toStringAsFixed(2)} charge';
    return ListTile(
      leading: StyledIcon(Icons.lock_clock_outlined),
      title: StyledText('Default lock-in'),
      subtitle: StyledSubtitle(subtitle),
      onTap: _edit,
    );
  }

  Future<void> _edit() async {
    var selectedDays = _lockInDays;
    final formKey = GlobalKey<FormState>();
    final chargeController = TextEditingController(
      text: _charge > 0 ? _charge.toStringAsFixed(2) : '',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Default lock-in'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: selectedDays,
                  decoration: const InputDecoration(
                    labelText: 'Lock-in period',
                  ),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('No lock-in')),
                    DropdownMenuItem(value: 7, child: Text('7 days')),
                    DropdownMenuItem(value: 15, child: Text('15 days')),
                  ],
                  onChanged: (value) {
                    setDialogState(() => selectedDays = value ?? 0);
                  },
                ),
                if (selectedDays > 0) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: chargeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Early redemption charge',
                      prefixText: '₹ ',
                    ),
                    validator: (value) {
                      final amount = double.tryParse(value?.trim() ?? '');
                      if (amount == null || amount <= 0) {
                        return 'Enter a charge greater than zero';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'These defaults apply to new loans only and can be changed on each loan.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (selectedDays > 0 &&
                    formKey.currentState?.validate() != true) {
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      final charge = selectedDays == 0
          ? 0.0
          : double.parse(chargeController.text.trim());
      FastDB.putDefaultLockInDays(selectedDays);
      FastDB.putDefaultEarlyRedemptionCharge(charge);
      await FastDB.flush();
      if (mounted) {
        setState(() {
          _lockInDays = selectedDays;
          _charge = charge;
        });
        showSnackBar(context, 'Default lock-in updated');
      }
    }
    chargeController.dispose();
  }
}
