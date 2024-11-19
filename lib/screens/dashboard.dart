import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mortgage/db/fastdb.dart';
import 'package:mortgage/provider/provider.dart';
import 'package:mortgage/screens/home.dart';
import 'package:mortgage/screens/manage.dart';
import 'package:mortgage/screens/mortgage_input.dart';
import 'package:mortgage/service/backup_service.dart';

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
    final title = useState<String>("Mortgage");
    if (!FastDB.getIsBackUpRegistered()) {
      useEffect(() {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showBackUpDialog(context);
        });
        return null;
      }, []);
    }
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title.value),
            Consumer(builder: (context, ref, child) {
              final mortgageSelectionList =
                  ref.watch(mortgageSelectionListProvider);
              return Row(
                children: [
                  IconButton(
                      onPressed: () {
                        ref.read(searchBarStatusProvider.notifier).toogle();
                      },
                      icon: Icon(Icons.search)),
                  if (mortgageSelectionList.length == 1)
                    IconButton(
                      icon: Icon(Icons.edit),
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => MortgageInput(
                                    mortgage: ref.read(mortgageListProvider)[
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
                                      ? 'Are you sure you want to delete this mortgage?'
                                      : 'Are you sure you want to delete these mortgages?'),
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
                                            .read(mortgageListProvider.notifier)
                                            .bulkDelete(mortgageSelectionList);
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
          ],
        ),
      ),
      drawer: MyDrawer(),
      body: _pages[currentIndex.value],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex.value,
        onTap: (index) {
          currentIndex.value = index;
          title.value = index == 0 ? "Mortgage" : "Manage";
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

  showBackUpDialog(BuildContext context) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Text('Backup'),
              content: Text(
                'Do you want to backup your mortgage data?',
                style: TextStyle(
                    fontSize: 18, color: Theme.of(context).colorScheme.primary),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('No'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await registerBackUp();
                    final BackupService backupService = BackupService();
                    await backupService.downloadFileToDevice();
                  },
                  child: const Text('Yes'),
                ),
              ],
            ));
  }
}
