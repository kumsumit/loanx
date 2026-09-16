import 'package:loanx/l10n/locale_keys.g.dart';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loanx/db/app_settings.dart';
import 'package:loanx/model/loan.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/features/lender/home.dart';
import 'package:loanx/features/lender/manage.dart';
import 'package:loanx/features/lender/add_loan.dart';
import 'package:loanx/features/lender/public_profile_screen.dart';
import 'package:loanx/features/auth/connect_account_screen.dart';
import 'package:loanx/features/borrower/home.dart';
import 'package:loanx/service/printing_service.dart';
import 'package:loanx/service/update_service.dart';
import 'package:loanx/widget/k_icon.dart';
import 'package:loanx/widget/styled_text.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'drawer.dart';

class DashBoard extends HookWidget {
  const DashBoard({super.key});

  @override
  Widget build(BuildContext context) {
    final usesBorrowerExperience = AppSettings.getUsesBorrowerExperience();
    final usesBothExperience = AppSettings.getUsesBothExperience();
    final pages = usesBorrowerExperience
        ? <Widget>[const BorrowerHome()]
        : <Widget>[
            const Home(),
            const Manage(),
            if (usesBothExperience) const BorrowerHome(),
          ];
    final currentIndex = useState<int>(0);
    final title = useState<String>(
      usesBorrowerExperience ? 'My loans'.tr() : LocaleKeys.loanx.tr(),
    );
    final theme = Theme.of(context);
    useEffect(() {
      title.value = switch (currentIndex.value) {
        0 => usesBorrowerExperience ? 'My loans'.tr() : LocaleKeys.loanx.tr(),
        1 => LocaleKeys.manage.tr(),
        _ => 'Borrowing'.tr(),
      };
      return null;
    }, [context.locale]);
    if (Platform.isAndroid || Platform.isIOS) {
      useEffect(() {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          SystemChrome.setSystemUIOverlayStyle(
            SystemUiOverlayStyle(
              statusBarColor: theme.scaffoldBackgroundColor,
              statusBarIconBrightness: theme.brightness == Brightness.dark
                  ? Brightness.light
                  : Brightness.dark,
              systemNavigationBarColor: theme.scaffoldBackgroundColor,
              systemNavigationBarDividerColor: theme.scaffoldBackgroundColor,
              systemNavigationBarIconBrightness:
                  theme.brightness == Brightness.dark
                  ? Brightness.light
                  : Brightness.dark,
            ),
          );
        });
        if (kDebugMode) {
          return null;
        }
        checkForUpdates(context, false);
        return;
      }, const []);
    }

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (!usesBorrowerExperience && !AppSettings.getPhoneAuthVerified())
            IconButton(
              tooltip: 'Connect account'.tr(),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ConnectAccountScreen()),
              ),
            ),
          if (!usesBorrowerExperience)
            IconButton(
              tooltip: 'Sign in as borrower'.tr(),
              icon: const Icon(Icons.switch_account_outlined),
              onPressed: () async {
                final switched = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) =>
                        const ConnectAccountScreen(switchToBorrower: true),
                  ),
                );
                if (switched == true && context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const DashBoard()),
                    (route) => false,
                  );
                }
              },
            ),
          if (!usesBorrowerExperience && !AppSettings.getIsProPlanSelected())
            IconButton(
              tooltip: 'Public lender profile'.tr(),
              icon: const Icon(Icons.storefront_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PublicProfileScreen()),
              ),
            ),
        ],
        title: Row(
          children: [
            // The contextual actions can grow to six buttons when a loan is
            // selected.  Let the title yield space to them on compact screens
            // instead of forcing the app bar Row past its right edge.
            Expanded(child: StyledHeading(title.value)),
            currentIndex.value == 0 && !usesBorrowerExperience
                ? Consumer(
                    builder: (context, ref, child) {
                      final loanSelectionList = ref.watch(
                        loanSelectionListProvider,
                      );
                      return Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              ref
                                  .read(searchBarStatusProvider.notifier)
                                  .toogle();
                            },
                            icon: StyledIcon(Icons.search),
                          ),
                          if (loanSelectionList.length == 1)
                            IconButton(
                              icon: Icon(Icons.edit),
                              onPressed: () {
                                final selectedId = loanSelectionList.single;
                                final selectedLoan = ref
                                    .read(loanListProvider)
                                    .value
                                    ?.firstWhere(
                                      (loan) => loan.id == selectedId,
                                    );
                                if (selectedLoan == null) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        LoanInput(loan: selectedLoan),
                                  ),
                                );
                              },
                            ),
                          if (loanSelectionList.isNotEmpty)
                            IconButton(
                              icon: Icon(Icons.delete),
                              onPressed: () {
                                final selectedLoans = List<int>.from(
                                  loanSelectionList,
                                );
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(
                                      selectedLoans.length == 1
                                          ? LocaleKeys.deleteThisLoan.tr()
                                          : LocaleKeys.deleteLoanCount.tr(
                                              namedArgs: {
                                                'count': selectedLoans.length
                                                    .toString(),
                                              },
                                            ),
                                    ),
                                    content: Text(
                                      selectedLoans.length == 1
                                          ? 'This permanently removes the loan record. This action cannot be undone.'
                                                .tr()
                                          : 'This permanently removes the selected loan records. This action cannot be undone.'
                                                .tr(),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                        child: Text(LocaleKeys.cancel.tr()),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          await ref
                                              .read(loanListProvider.notifier)
                                              .bulkDelete(selectedLoans);
                                          ref
                                              .read(
                                                loanSelectionListProvider
                                                    .notifier,
                                              )
                                              .clear();
                                          if (context.mounted) {
                                            Navigator.of(context).pop();
                                          }
                                        },
                                        child: Text(
                                          LocaleKeys.deletePermanently.tr(),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          if (loanSelectionList.isNotEmpty)
                            IconButton(
                              icon: Icon(Icons.share),
                              onPressed: () {
                                String formattedText = "";
                                final loanList = ref.read(loanListProvider);
                                final familyRelationList = ref.read(
                                  familyRelationListProvider,
                                );
                                final mortgageMaterialList = ref.read(
                                  mortgageMaterialListProvider,
                                );
                                familyRelationList.when(
                                  data: (familyRelations) {
                                    mortgageMaterialList.when(
                                      data: (mortgageMaterials) {
                                        loanList.when(
                                          data: (data) {
                                            List<Loan> filteredLoans = data
                                                .where(
                                                  (loan) => loanSelectionList
                                                      .contains(loan.id),
                                                )
                                                .toList();
                                            for (Loan loan in filteredLoans) {
                                              formattedText +=
                                                  """
Name: ${loan.depositorName}
Phone Number: ${loan.phoneNumber}
Address: ${loan.address}
Relative Name: ${loan.relativeName} (${familyRelations.firstWhere((familyRelation) => familyRelation.id == loan.familyRelationId).name})
Loan Amount: ${loan.loanAmount}
Additional Details: ${loan.additionalDetails}
Terms and Conditions: ${loan.termsAndConditions.isEmpty ? 'Not recorded' : loan.termsAndConditions}
Mortgage Name: ${mortgageMaterials.firstWhere((mortgageMaterial) => mortgageMaterial.id == loan.mortgageMaterialId).name}
Weight: ${loan.weight > 0 ? '${loan.weight.toStringAsFixed(2)} ${loan.weightUnit}' : 'Not recorded'}

""";
                                            }
                                            formattedText +=
                                                "Shared from LoanX";
                                            SharePlus.instance.share(
                                              ShareParams(text: formattedText),
                                            );
                                          },
                                          error: (_, _) {},
                                          loading: () {},
                                        );
                                      },
                                      error: (_, _) {},
                                      loading: () {},
                                    );
                                  },
                                  error: (_, _) {},
                                  loading: () {},
                                );
                              },
                            ),
                          if (loanSelectionList.length == 1)
                            IconButton(
                              onPressed: () {
                                final selectedId = loanSelectionList.single;
                                final loan = ref
                                    .read(loanListProvider)
                                    .value
                                    ?.where((item) => item.id == selectedId)
                                    .firstOrNull;
                                if (loan == null) return;
                                final familyRelationList = ref.read(
                                  familyRelationListProvider,
                                );
                                final mortgageMaterialList = ref.read(
                                  mortgageMaterialListProvider,
                                );
                                familyRelationList.when(
                                  data: (familyRelations) {
                                    mortgageMaterialList.when(
                                      data: (mortgageMaterials) {
                                        final formattedText =
                                            """
Name: ${loan.depositorName}
Phone Number: ${loan.phoneNumber}
Address: ${loan.address}
Relative Name: ${loan.relativeName} (${familyRelations.firstWhere((familyRelation) => familyRelation.id == loan.familyRelationId).name})
Loan Amount: ${loan.loanAmount}
Additional Details: ${loan.additionalDetails}
Terms and Conditions: ${loan.termsAndConditions.isEmpty ? 'Not recorded' : loan.termsAndConditions}
Mortgage Name: ${mortgageMaterials.firstWhere((mortgageMaterial) => mortgageMaterial.id == loan.mortgageMaterialId).name}
Weight: ${loan.weight > 0 ? '${loan.weight.toStringAsFixed(2)} ${loan.weightUnit}' : 'Not recorded'}

Shared from LoanX
""";
                                        showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (context) => Dialog(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                StyledHeading(
                                                  LocaleKeys.sentVia.tr(),
                                                ),
                                                OutlinedButton.icon(
                                                  label: Text(
                                                    LocaleKeys.sms.tr(),
                                                  ),
                                                  icon: Icon(Icons.sms),
                                                  onPressed: () async {
                                                    final whatsappUrl =
                                                        "sms:${loan.phoneNumber}?body=${Uri.encodeFull(formattedText)}";
                                                    await launchUrl(
                                                      Uri.parse(whatsappUrl),
                                                    );
                                                    if (context.mounted) {
                                                      Navigator.of(
                                                        context,
                                                      ).pop();
                                                    }
                                                  },
                                                ),
                                                OutlinedButton.icon(
                                                  label: Text(
                                                    LocaleKeys.whatsapp2.tr(),
                                                  ),
                                                  icon: Icon(K.whatsapp),
                                                  onPressed: () async {
                                                    String whatsappUrl =
                                                        "https://wa.me/${loan.phoneNumber}?text=${Uri.encodeComponent(formattedText)}";
                                                    await launchUrl(
                                                      Uri.parse(whatsappUrl),
                                                    );
                                                    if (context.mounted) {
                                                      Navigator.of(
                                                        context,
                                                      ).pop();
                                                    }
                                                  },
                                                ),
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.of(context).pop();
                                                  },
                                                  child: Text(
                                                    LocaleKeys.cancel.tr(),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                      error: (_, q) {},
                                      loading: () {},
                                    );
                                  },
                                  error: (_, q) {},
                                  loading: () {},
                                );
                              },
                              icon: Icon(Icons.forward_to_inbox),
                            ),
                          if (loanSelectionList.length == 1)
                            IconButton(
                              icon: Icon(Icons.print),
                              tooltip: LocaleKeys.printLoanReceipt.tr(),
                              onPressed: () async {
                                final selectedLoan = ref
                                    .read(loanListProvider)
                                    .value
                                    ?.where(
                                      (loan) =>
                                          loan.id == loanSelectionList.single,
                                    )
                                    .firstOrNull;
                                if (selectedLoan == null) return;

                                if (!context.mounted) return;
                                final action =
                                    await showModalBottomSheet<_ReceiptAction>(
                                      context: context,
                                      builder: (context) => SafeArea(
                                        child: Wrap(
                                          children: [
                                            ListTile(
                                              leading: const Icon(Icons.print),
                                              title: Text(
                                                LocaleKeys.printReceipt.tr(),
                                              ),
                                              subtitle: Text(
                                                'Print using a USB or Bluetooth printer'
                                                    .tr(),
                                              ),
                                              onTap: () => Navigator.pop(
                                                context,
                                                _ReceiptAction.print,
                                              ),
                                            ),
                                            ListTile(
                                              leading: const Icon(
                                                Icons.picture_as_pdf_outlined,
                                              ),
                                              title: Text(
                                                LocaleKeys.sharePdf.tr(),
                                              ),
                                              subtitle: Text(
                                                'Save or open the receipt as a PDF file'
                                                    .tr(),
                                              ),
                                              onTap: () => Navigator.pop(
                                                context,
                                                _ReceiptAction.sharePdf,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                if (action == null) return;

                                try {
                                  if (action == _ReceiptAction.print) {
                                    await LoanPrintingService.printLoan(
                                      selectedLoan,
                                    );
                                  } else {
                                    await LoanPrintingService.shareLoanPdf(
                                      selectedLoan,
                                    );
                                  }
                                } catch (_) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Unable to create the receipt. Please try again.'
                                            .tr(),
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                        ],
                      );
                    },
                  )
                : const SizedBox(),
          ],
        ),
      ),
      drawer: MyDrawer(),
      body: pages[currentIndex.value.clamp(0, pages.length - 1)],
      bottomNavigationBar: usesBorrowerExperience
          ? null
          : NavigationBar(
              selectedIndex: currentIndex.value,
              onDestinationSelected: (index) {
                currentIndex.value = index;
                title.value = switch (index) {
                  0 => LocaleKeys.loanx.tr(),
                  1 => LocaleKeys.manage.tr(),
                  _ => 'Borrowing'.tr(),
                };
              },
              destinations: [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: LocaleKeys.home.tr(),
                ),
                NavigationDestination(
                  icon: Icon(Icons.tune_outlined),
                  selectedIcon: Icon(Icons.tune_rounded),
                  label: LocaleKeys.manage2.tr(),
                ),
                if (usesBothExperience)
                  NavigationDestination(
                    icon: const Icon(Icons.account_balance_wallet_outlined),
                    selectedIcon: const Icon(Icons.account_balance_wallet),
                    label: 'Borrowing'.tr(),
                  ),
              ],
            ),
    );
  }
}

enum _ReceiptAction { print, sharePdf }
