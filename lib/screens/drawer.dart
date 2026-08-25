import 'package:loanx/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:io';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_color_picker_plus/flutter_color_picker_plus.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loanx/extension/loan_enum_localization.dart';
import 'package:loanx/model/loan.dart';
import 'package:loanx/service/backup_service.dart';
import 'package:loanx/db/fastdb.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/service/update_service.dart';
import 'package:loanx/service/upi_validator.dart';
import 'package:loanx/widget/avatar.dart';
import 'package:loanx/widget/bullet.dart';
import 'package:loanx/widget/loading_overlay.dart';
import 'package:loanx/widget/language_picker.dart';
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
                          LocaleKeys.loanx2.tr(),
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
              if (kDebugMode)
                Container(
                  color: Theme.of(context).colorScheme.errorContainer,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    'DEBUG APPLICATION',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ExpansionTile(
                leading: StyledIcon(Icons.info_outline),
                title: StyledText(LocaleKeys.aboutLoanx.tr()),
                subtitle: StyledSubtitle(LocaleKeys.learnAboutTheApp.tr()),
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerLow,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                children: [
                  const Divider(indent: 16, endIndent: 16),
                  ListTile(
                    leading: StyledIcon(Icons.article_outlined),
                    title: StyledText(LocaleKeys.whatIsLoanx.tr()),
                    subtitle: StyledSubtitle(
                      LocaleKeys.learnWhatLoanxCanDo.tr(),
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
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(height: 10),
                                    StyledHeading(LocaleKeys.about.tr()),
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
                                      child: Text(LocaleKeys.ok.tr()),
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
                title: StyledText(LocaleKeys.appPreferences.tr()),
                subtitle: StyledSubtitle(LocaleKeys.securityAndAppearance.tr()),
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerLow,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                children: [
                  const Divider(indent: 16, endIndent: 16),
                  ListTile(
                    leading: StyledIcon(Icons.translate_rounded),
                    title: StyledText(LocaleKeys.appLanguage.tr()),
                    subtitle: StyledSubtitle(appLanguageName(context.locale)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => showAppLanguagePicker(context),
                  ),
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
                          secure
                              ? LocaleKeys.disableAppLock.tr()
                              : LocaleKeys.enableAppLock.tr(),
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
                                      StyledHeading(
                                        LocaleKeys.confirmation.tr(),
                                      ),
                                      StyledSubtitle(
                                        secure
                                            ? 'Disable the app lock on this device?'
                                                  .tr()
                                            : 'Enable an app lock on this device?'
                                                  .tr(),
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          OutlinedButton(
                                            child: Text(LocaleKeys.cancel.tr()),
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                          ),
                                          OutlinedButton(
                                            child: Text(LocaleKeys.ok2.tr()),
                                            onPressed: () async {
                                              await ref
                                                  .read(secureProvider.notifier)
                                                  .toggle();
                                              if (context.mounted) {
                                                Navigator.of(context).pop();
                                                if (secure) {
                                                  showSnackBar(
                                                    context,
                                                    "App gets unsecured, Now you need to restart the app"
                                                        .tr(),
                                                  );
                                                } else {
                                                  showSnackBar(
                                                    context,
                                                    "App gets secured, Now you need to restart the app"
                                                        .tr(),
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
                    title: StyledText(LocaleKeys.appColor.tr()),
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
                                  StyledHeading(LocaleKeys.pickAColor.tr()),
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
                                        child: Text(LocaleKeys.cancel.tr()),
                                      ),
                                      Consumer(
                                        builder: (context, ref, child) {
                                          return OutlinedButton(
                                            child: Text(LocaleKeys.ok2.tr()),
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
                                                  LocaleKeys.appColorChanged
                                                      .tr(),
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
                                        child: Text(
                                          LocaleKeys.setColorUsingImage.tr(),
                                        ),
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
                title: StyledText(LocaleKeys.loanDefaults.tr()),
                subtitle: StyledSubtitle(
                  LocaleKeys.interestAndMortgageSettings.tr(),
                ),
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerLow,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                children: [
                  const Divider(indent: 16, endIndent: 16),
                  ListTile(
                    leading: StyledIcon(Icons.currency_exchange),
                    title: StyledText(LocaleKeys.mortgageTerm.tr()),
                    subtitle: Consumer(
                      builder: (context, ref, child) {
                        final holdingPeriod = ref.watch(holdingPeriodProvider);
                        return StyledSubtitle(
                          LocaleKeys.defaultYears.tr(
                            namedArgs: {'years': holdingPeriod.toString()},
                          ),
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
                                      LocaleKeys.changeMortgageHoldingPeriod
                                          .tr(),
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
                                                "Holding Period can't be 0"
                                                    .tr(),
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
                                          LocaleKeys.mortgageHoldingPeriod.tr(
                                            namedArgs: {
                                              'years': holdingPeriod.toString(),
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                    StyledSubtitle(
                                      LocaleKeys.defaultHoldingPeriodIs5Years
                                          .tr(),
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
                                          child: Text(LocaleKeys.cancel.tr()),
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
                                                    "Mortgage Holding Period changed"
                                                        .tr(),
                                                  );
                                                }
                                              },
                                              child: Text(
                                                LocaleKeys.ok.tr(),
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
                    title: StyledText(LocaleKeys.interestType.tr()),
                    subtitle: Consumer(
                      builder: (context, ref, child) {
                        final interestType = ref.watch(
                          interestTypeStatusProvider,
                        );
                        return StyledSubtitle(
                          LocaleKeys.defaultInterestType.tr(
                            namedArgs: {'type': interestType.localizedLabel},
                          ),
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
                                    StyledHeading(
                                      LocaleKeys.selectInterestType.tr(),
                                    ),
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
                                                      .localizedLabel,
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
                                          child: Text(LocaleKeys.cancel.tr()),
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
                                                    LocaleKeys
                                                        .interestTypeChangedSuccessfully
                                                        .tr(),
                                                  );
                                                }
                                              },
                                              child: Text(
                                                LocaleKeys.ok.tr(),
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
                        title: StyledText(LocaleKeys.interestFrequency2.tr()),
                        subtitle: StyledSubtitle(
                          LocaleKeys.defaultInterestFrequency.tr(
                            namedArgs: {
                              'frequency': interestFrequency.localizedLabel,
                            },
                          ),
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
                                      StyledHeading(
                                        LocaleKeys.interestFrequency.tr(),
                                      ),
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
                                                  option.localizedLabel,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      StyledText(
                                        LocaleKeys.interestFrequencySet.tr(
                                          namedArgs: {
                                            'frequency': interestFrequency
                                                .localizedLabel,
                                          },
                                        ),
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
                                            child: Text(LocaleKeys.cancel.tr()),
                                          ),
                                          OutlinedButton(
                                            onPressed: () async {
                                              await FastDB.flush();
                                              if (context.mounted) {
                                                Navigator.pop(context);
                                              }
                                            },
                                            child: Text(LocaleKeys.ok2.tr()),
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
                    title: StyledText(LocaleKeys.interestRate.tr()),
                    subtitle: Consumer(
                      builder: (context, ref, child) {
                        final interestRate = ref.watch(interestRateProvider);
                        return StyledSubtitle(
                          LocaleKeys.defaultInterestRate.tr(
                            namedArgs: {'rate': interestRate.toString()},
                          ),
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
                                  StyledHeading(
                                    LocaleKeys.changeInterestRate.tr(),
                                  ),
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
                                        LocaleKeys.currentInterestRate.tr(
                                          namedArgs: {
                                            'rate': interestRate.toString(),
                                          },
                                        ),
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
                                        child: Text(LocaleKeys.cancel.tr()),
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
                                                  LocaleKeys.interestRateChanged
                                                      .tr(),
                                                );
                                              }
                                            },
                                            child: Text(LocaleKeys.ok.tr()),
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
                  const _DefaultUpiIdSetting(),
                ],
              ),
              ExpansionTile(
                leading: StyledIcon(Icons.cloud_outlined),
                title: StyledText(LocaleKeys.backupGoogleDrive.tr()),
                subtitle: Consumer(
                  builder: (context, ref, child) {
                    final email = ref.watch(emailProvider);
                    return StyledSubtitle(
                      email.isEmpty ? LocaleKeys.notConnected.tr() : email,
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
                          title: StyledText(LocaleKeys.changeBackupTime.tr()),
                          subtitle: StyledSubtitle(
                            LocaleKeys.defaultTime.tr(
                              namedArgs: {'time': time.format(context)},
                            ),
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
                                  LocaleKeys.backupTimeUpdated.tr(
                                    namedArgs: {'time': picked.format(context)},
                                  ),
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
                              title: StyledText(LocaleKeys.backUpNow.tr()),
                              subtitle: ref.watch(backupStatusProvider)
                                  ? Text(
                                      "Creating your secure Google Drive backup…"
                                          .tr(),
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
                                              LocaleKeys.notConnected.tr(),
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
                                            LocaleKeys.backupCreatedSuccessfully
                                                .tr(),
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
                              title: StyledText(
                                LocaleKeys.restoreLatestBackup.tr(),
                              ),
                              subtitle: ref.watch(backupDownloadStatusProvider)
                                  ? Text(
                                      LocaleKeys.restoringYourBackup.tr(),
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
                                        LocaleKeys.notConnected.tr(),
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
                                      LocaleKeys.backupRestoredSuccessfully
                                          .tr(),
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
                          token.isEmpty
                              ? LocaleKeys.addAccount.tr()
                              : LocaleKeys.changeAccount.tr(),
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
                                        ? LocaleKeys.backupRestoredSuccessfully
                                              .tr()
                                        : isAddingAccount
                                        ? 'Google account connected.'
                                        : 'Google account updated.',
                                  );
                                }
                              }
                            } else if (context.mounted) {
                              showSnackBar(
                                context,
                                LocaleKeys.youHaveNotSelectedAnyAccount.tr(),
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
                        title: StyledText(LocaleKeys.viewConnectedAccount.tr()),
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
                                    name.isEmpty
                                        ? LocaleKeys.googleAccount.tr()
                                        : name,
                                    style: Theme.of(
                                      sheetContext,
                                    ).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(email),
                                  const SizedBox(height: 16),
                                  Text(
                                    'This account stores your LoanX backups in Google Drive.'
                                        .tr(),
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
                        title: StyledText(
                          LocaleKeys.disconnectGoogleAccount.tr(),
                        ),
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
                                LocaleKeys.googleAccountDisconnected.tr(),
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
                title: StyledText(LocaleKeys.helpFeedback.tr()),
                subtitle: StyledSubtitle(
                  LocaleKeys.supportSharingAndUpdates.tr(),
                ),
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerLow,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                children: [
                  const Divider(indent: 16, endIndent: 16),
                  ListTile(
                    leading: StyledIcon(Icons.star_rate),
                    title: StyledText(LocaleKeys.rateLoanx.tr()),
                    onTap: _openReview,
                  ),
                  ListTile(
                    leading: StyledIcon(Icons.share),
                    title: StyledText(LocaleKeys.shareApp.tr()),
                    onTap: () {
                      final box = context.findRenderObject() as RenderBox?;
                      SharePlus.instance.share(
                        ShareParams(
                          text: LocaleKeys.shareAppMessage.tr(),
                          subject: LocaleKeys.shareAppSubject.tr(),
                          sharePositionOrigin:
                              box!.localToGlobal(Offset.zero) & box.size,
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: StyledIcon(Icons.edit_square),
                    title: StyledText(LocaleKeys.contactSupport.tr()),
                    onTap: () {
                      _launchURL('https://forms.gle/zSRbdvU45hvPWEYp7');
                    },
                  ),
                  ListTile(
                    leading: StyledIcon(Icons.policy),
                    title: StyledText(LocaleKeys.privacyPolicy.tr()),
                    onTap: () {
                      _launchURL(
                        'https://loanx.kumpali.com/privacy-policy.html',
                      );
                    },
                  ),
                  if (Platform.isAndroid || Platform.isIOS)
                    ListTile(
                      leading: StyledIcon(Icons.update),
                      title: StyledText(LocaleKeys.checkForUpdates.tr()),
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
                                return StyledText(
                                  LocaleKeys.versionNumber.tr(
                                    namedArgs: {'version': appVersion},
                                  ),
                                );
                              },
                              error: (obj, trace) {
                                return Text(
                                  LocaleKeys.versionUnavailable.tr(),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                );
                              },
                              loading: () =>
                                  StyledText(LocaleKeys.version.tr()),
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

class _DefaultUpiIdSetting extends StatefulWidget {
  const _DefaultUpiIdSetting();

  @override
  State<_DefaultUpiIdSetting> createState() => _DefaultUpiIdSettingState();
}

class _DefaultUpiIdSettingState extends State<_DefaultUpiIdSetting> {
  String _upiId = '';

  @override
  void initState() {
    super.initState();
    _upiId = FastDB.getDefaultUpiId();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: StyledIcon(Icons.account_balance_outlined),
      title: StyledText(LocaleKeys.defaultUpiId.tr()),
      subtitle: StyledSubtitle(
        _upiId.isEmpty ? LocaleKeys.noDefaultUpiIdSet.tr() : _upiId,
      ),
      onTap: _edit,
    );
  }

  Future<void> _edit() async {
    final saved = await showDialog<String>(
      context: context,
      builder: (_) => _DefaultUpiIdDialog(initialUpiId: _upiId),
    );
    if (saved == null) return;

    FastDB.putDefaultUpiId(saved);
    await FastDB.flush();
    if (!mounted) return;
    setState(() => _upiId = saved);
    showSnackBar(context, LocaleKeys.defaultUpiIdUpdated.tr());
  }
}

class _DefaultUpiIdDialog extends StatefulWidget {
  const _DefaultUpiIdDialog({required this.initialUpiId});

  final String initialUpiId;

  @override
  State<_DefaultUpiIdDialog> createState() => _DefaultUpiIdDialogState();
}

class _DefaultUpiIdDialogState extends State<_DefaultUpiIdDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialUpiId);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(LocaleKeys.defaultUpiId.tr()),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: LocaleKeys.receivingUpiId.tr(),
            hintText: LocaleKeys.upiIdHint.tr(),
            helperText: LocaleKeys.defaultUpiIdHelper.tr(),
          ),
          validator: (value) {
            final upiId = value?.trim() ?? '';
            if (upiId.isNotEmpty && !isValidUpiIdFormat(upiId)) {
              return LocaleKeys.enterValidUpiId.tr();
            }
            if (upiId.isNotEmpty && !hasSupportedUpiHandle(upiId)) {
              return LocaleKeys.invalidUpiHandle.tr(
                namedArgs: {'handle': upiHandle(upiId)},
              );
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(LocaleKeys.cancel.tr()),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() != true) return;
            Navigator.pop(context, _controller.text.trim());
          },
          child: Text(LocaleKeys.save.tr()),
        ),
      ],
    );
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
      title: StyledText(LocaleKeys.termsAndConditions.tr()),
      subtitle: StyledSubtitle(
        _terms.trim().isEmpty
            ? LocaleKeys.noDefaultTermsSet.tr()
            : LocaleKeys.prefilledForNewLoans.tr(),
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
    showSnackBar(context, LocaleKeys.defaultTermsAndConditionsUpdated.tr());
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
              Text(
                LocaleKeys.defaultTermsAndConditions.tr(),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                minLines: 4,
                maxLines: 8,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: LocaleKeys.termsAndConditions.tr(),
                  hintText: LocaleKeys.enterTheDefaultTermsForNewLoans.tr(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'These terms are copied into new loans and can be edited on each loan.'
                    .tr(),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(LocaleKeys.cancel.tr()),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, _controller.text.trim()),
                    child: Text(LocaleKeys.save.tr()),
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
        ? LocaleKeys.newLoansHaveNoLockInByDefault.tr()
        : LocaleKeys.defaultLockInSummary.tr(
            namedArgs: {
              'days': _lockInDays.toString(),
              'charge': _charge.toStringAsFixed(2),
            },
          );
    return ListTile(
      leading: StyledIcon(Icons.lock_clock_outlined),
      title: StyledText(LocaleKeys.defaultLockIn.tr()),
      subtitle: StyledSubtitle(subtitle),
      onTap: _edit,
    );
  }

  Future<void> _edit() async {
    var selectedDays = _lockInDays;
    final formKey = GlobalKey<FormState>();
    final daysController = TextEditingController(text: _lockInDays.toString());
    final chargeController = TextEditingController(
      text: _charge > 0 ? _charge.toStringAsFixed(2) : '',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(LocaleKeys.defaultLockIn.tr()),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: daysController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: LocaleKeys.lockInPeriod.tr(),
                    suffixText: 'days'.tr(),
                    helperText: 'Enter 0 for no lock-in'.tr(),
                  ),
                  validator: (value) {
                    final days = int.tryParse(value?.trim() ?? '');
                    if (days == null || days < 0) {
                      return 'Enter a valid number of days'.tr();
                    }
                    return null;
                  },
                  onChanged: (value) {
                    setDialogState(
                      () => selectedDays = int.tryParse(value.trim()) ?? 0,
                    );
                  },
                ),
                if (selectedDays > 0) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: chargeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: LocaleKeys.earlyRedemptionCharge.tr(),
                      prefixText: '₹ ',
                    ),
                    validator: (value) {
                      final amount = double.tryParse(value?.trim() ?? '');
                      if (amount == null || amount <= 0) {
                        return LocaleKeys.enterAChargeGreaterThanZero.tr();
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'These defaults apply to new loans only and can be changed on each loan.'
                      .tr(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(LocaleKeys.cancel.tr()),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) {
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: Text(LocaleKeys.save.tr()),
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
        showSnackBar(context, LocaleKeys.defaultLockInUpdated.tr());
      }
    }
    daysController.dispose();
    chargeController.dispose();
  }
}
