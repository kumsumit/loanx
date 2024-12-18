import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/screens/home.dart';
import 'package:loanx/screens/manage.dart';
import 'package:loanx/screens/add_loan.dart';
import 'package:loanx/service/update_service.dart';
import 'package:loanx/widget/styled_text.dart';

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
            systemNavigationBarIconBrightness: Brightness.dark
          ));
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
