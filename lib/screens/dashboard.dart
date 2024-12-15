import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

// import 'package:loanx/db/fastdb.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/screens/home.dart';
import 'package:loanx/screens/manage.dart';
import 'package:loanx/screens/mortgage_input.dart';
import 'package:loanx/service/update_service.dart';
import 'package:loanx/widget/styled_text.dart';
// import 'package:loanx/service/backup_service.dart';
// import 'package:loanx/service/database_helper.dart';
// import 'package:loanx/widget/snackbar.dart';

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
    final title = useState<String>("Loanx");
    if (Platform.isAndroid) {
      useEffect(() {
        checkForUpdates(context, false);
        return null;
      }, []);
    }

    return Scaffold(
      appBar: AppBar(
        foregroundColor: Theme.of(context).colorScheme.primary,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            StyledHeading(title.value),
            currentIndex.value == 0
                ? Consumer(builder: (context, ref, child) {
                    final mortgageSelectionList =
                        ref.watch(mortgageSelectionListProvider);
                    return Row(
                      children: [
                        IconButton(
                            onPressed: () {
                              ref
                                  .read(searchBarStatusProvider.notifier)
                                  .toogle();
                            },
                            icon: StyledIcon(Icons.search)),
                        if (mortgageSelectionList.length == 1)
                          IconButton(
                            icon: Icon(Icons.edit),
                            onPressed: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => MortgageInput(
                                          mortgage: ref
                                                  .read(mortgageListProvider)
                                                  .value![
                                              mortgageSelectionList.first])));
                            },
                          ),
                        if (mortgageSelectionList.isNotEmpty)
                          IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () {
                              showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                        title: Text(ref
                                                    .read(
                                                        mortgageSelectionListProvider)
                                                    .length ==
                                                1
                                            ? 'Delete Mortgage'
                                            : 'Delete Multiple Mortgages'),
                                        content: Text(ref
                                                    .read(
                                                        mortgageSelectionListProvider)
                                                    .length ==
                                                1
                                            ? 'Are you sure you want to delete this loanx?'
                                            : 'Are you sure you want to delete these loanxs?'),
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
                                                  .read(mortgageListProvider
                                                      .notifier)
                                                  .bulkDelete(
                                                      mortgageSelectionList);
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
