import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:loanx/model/loan.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/screens/home.dart';
import 'package:loanx/screens/manage.dart';
import 'package:loanx/screens/add_loan.dart';
import 'package:loanx/service/update_service.dart';
import 'package:loanx/widget/k_icon.dart';
import 'package:loanx/widget/styled_text.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'drawer.dart';

class DashBoard extends HookWidget {
  const DashBoard({super.key});

  final List<Widget> _pages = const [
    Home(),
    Manage(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = useState<int>(0);
    final title = useState<String>(AppLocalizations.of(context)!.loanx);
    final theme = Theme.of(context);
    if (Platform.isAndroid) {
      useEffect(() {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
              statusBarColor: theme.scaffoldBackgroundColor,
              statusBarIconBrightness: Brightness.dark,
              systemNavigationBarColor: theme.scaffoldBackgroundColor,
              systemNavigationBarDividerColor: theme.scaffoldBackgroundColor,
              systemNavigationBarIconBrightness: Brightness.dark));
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
        foregroundColor: Theme.of(context).colorScheme.primary,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(),
            StyledHeading(title.value),
            currentIndex.value == 0
                ? Consumer(builder: (context, ref, child) {
                    final loanSelectionList =
                        ref.watch(loanSelectionListProvider);
                    return Row(
                      children: [
                        IconButton(
                            onPressed: () {
                              ref
                                  .read(searchBarStatusProvider.notifier)
                                  .toogle();
                            },
                            icon: StyledIcon(Icons.search)),
                        if (loanSelectionList.length == 1)
                          IconButton(
                            icon: Icon(Icons.edit),
                            onPressed: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => LoanInput(
                                          loan: ref
                                              .read(loanListProvider)
                                              .value![0])));
                            },
                          ),
                        if (loanSelectionList.isNotEmpty)
                          IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () {
                              showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                        title: Text(ref
                                                    .read(
                                                        loanSelectionListProvider)
                                                    .length ==
                                                1
                                            ? 'Delete Loan Record'
                                            : 'Delete Multiple Loan Records'),
                                        content: Text(ref
                                                    .read(
                                                        loanSelectionListProvider)
                                                    .length ==
                                                1
                                            ? 'Are you sure you want to delete this loan record?'
                                            : 'Are you sure you want to delete these loan records?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              ref
                                                  .read(
                                                      loanListProvider.notifier)
                                                  .bulkDelete(
                                                      loanSelectionList);
                                              Navigator.of(context).pop();
                                            },
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ));
                            },
                          ),
                        if (loanSelectionList.isNotEmpty)
                          IconButton(
                              icon: Icon(Icons.share),
                              onPressed: () {
                                String formattedText = "";
                                final loanList = ref.read(loanListProvider);
                                final familyRelationList =
                                    ref.read(familyRelationListProvider);
                                final mortgageMaterialList =
                                    ref.read(mortgageMaterialListProvider);
                                familyRelationList.when(
                                    data: (familyRelations) {
                                      mortgageMaterialList.when(
                                          data: (mortgageMaterials) {
                                            loanList.when(
                                                data: (data) {
                                                  List<Loan> filteredLoans =
                                                      data
                                                          .where((loan) =>
                                                              loanSelectionList
                                                                  .contains(
                                                                      loan.id))
                                                          .toList();
                                                  for (Loan loan
                                                      in filteredLoans) {
                                                    formattedText += """
Name: ${loan.depositorName}
Phone Number: ${loan.phoneNumber}
Address: ${loan.address}
Relative Name: ${loan.relativeName} (${familyRelations.firstWhere((familyRelation) => familyRelation.id == loan.familyRelationId).name})
Loan Amount: ${loan.loanAmount}
Additional Details: ${loan.additionalDetails}
Mortgage Material: ${mortgageMaterials.firstWhere((mortgageMaterial) => mortgageMaterial.id == loan.mortgageMaterialId).name}

""";
                                                  }
                                                  formattedText += "Sent with Love via LoanX";
                                                  Share.share(formattedText);
                                                },
                                                error: (_, __) {},
                                                loading: () {});
                                          },
                                          error: (_, __) {},
                                          loading: () {});
                                    },
                                    error: (_, __) {},
                                    loading: () {});
                              }),
                        if (loanSelectionList.length == 1)
                          IconButton(
                            onPressed: () {
                              final loan = ref.read(loanListProvider).value![0];
                              final familyRelationList =
                                  ref.read(familyRelationListProvider);
                              final mortgageMaterialList =
                                  ref.read(mortgageMaterialListProvider);
                              familyRelationList.when(
                                  data: (familyRelations) {
                                    mortgageMaterialList.when(
                                        data: (mortgageMaterials) {
                                          final formattedText = """
Name: ${loan.depositorName}
Phone Number: ${loan.phoneNumber}
Address: ${loan.address}
Relative Name: ${loan.relativeName} (${familyRelations.firstWhere((familyRelation) => familyRelation.id == loan.familyRelationId).name})
Loan Amount: ${loan.loanAmount}
Additional Details: ${loan.additionalDetails}
Mortgage Material: ${mortgageMaterials.firstWhere((mortgageMaterial) => mortgageMaterial.id == loan.mortgageMaterialId).name}

Sent with Love via LoanX
""";
                                          showDialog(
                                              context: context,
                                              barrierDismissible: false,
                                              builder: (context) => Dialog(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.center,
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        StyledHeading("Sent via :"),
                                                        OutlinedButton.icon(
                                                          label: const Text(
                                                              'SMS'),
                                                          icon: Icon(Icons.sms),
                                                          onPressed: () async {
                                                            final whatsappUrl =
                                                                "sms:${loan.phoneNumber}?body=${Uri.encodeFull(formattedText)}";
                                                            await launchUrl(
                                                                Uri.parse(
                                                                    whatsappUrl));
                                                            if (context
                                                                .mounted) {
                                                              Navigator.of(
                                                                      context)
                                                                  .pop();
                                                            }
                                                          },
                                                        ),
                                                        OutlinedButton.icon(
                                                          label: const Text(
                                                              'Whatsapp'),
                                                          icon:
                                                              Icon(K.whatsapp),
                                                          onPressed: () async {
                                                            String whatsappUrl =
                                                                "https://wa.me/${loan.phoneNumber}?text=${Uri.encodeComponent(formattedText)}";
                                                            await launchUrl(
                                                                Uri.parse(
                                                                    whatsappUrl));
                                                            if (context
                                                                .mounted) {
                                                              Navigator.of(
                                                                      context)
                                                                  .pop();
                                                            }
                                                          },
                                                        ),
                                                        TextButton(
                                                          onPressed: () {
                                                            Navigator.of(context)
                                                                .pop();
                                                          },
                                                          child: const Text(
                                                              'Cancel'),
                                                        ),
                                                      ],
                                                    ),
                                                  ));
                                        },
                                        error: (_, q) {},
                                        loading: () {});
                                  },
                                  error: (_, q) {},
                                  loading: () {});
                            },
                            icon: Icon(Icons.forward_to_inbox),
                          ),
                          if (loanSelectionList.length == 1)
                            IconButton(
                              icon: Icon(Icons.print),
                              onPressed:(){
                                
                              }
                            )
                      ],
                    );
                  })
                : const SizedBox()
          ],
        ),
      ),
      drawer: MyDrawer(),
      body: _pages[currentIndex.value],
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.secondary,
        currentIndex: currentIndex.value,
        onTap: (index) {
          currentIndex.value = index;
          title.value = index == 0 ? "Loanx" : "Manage";
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Manage',
          ),
        ],
      ),
    );
  }
}
