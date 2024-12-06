import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
// import 'package:mortgage/db/fastdb.dart';
import 'package:mortgage/provider/provider.dart';
import 'package:mortgage/screens/home.dart';
import 'package:mortgage/screens/manage.dart';
import 'package:mortgage/screens/mortgage_input.dart';
import 'package:mortgage/widget/styled_text.dart';
// import 'package:mortgage/service/backup_service.dart';
// import 'package:mortgage/service/database_helper.dart';
// import 'package:mortgage/widget/snackbar.dart';

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
    // if (!FastDB.getIsBackUpRegistered()) {
    //   useEffect(() {
    //     WidgetsBinding.instance.addPostFrameCallback((_) {
    //       showBackUpDialog(context);
    //     });
    //     return null;
    //   }, []);
    // }
    return Scaffold(
      appBar: AppBar(
        foregroundColor: Theme.of(context).colorScheme.primary,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            StyledHeading(title.value),
            currentIndex.value == 0 ? 
            Consumer(builder: (context, ref, child) {
              final mortgageSelectionList =
                  ref.watch(mortgageSelectionListProvider);
              return Row(
                children: [
                  IconButton(
                      onPressed: () {
                        ref.read(searchBarStatusProvider.notifier).toogle();
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
                                        .value![mortgageSelectionList.first])));
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
            }): const SizedBox()
          ],
        ),
      ),
      drawer: MyDrawer(),
      body:   _pages[currentIndex.value],
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.secondary,
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

//   showBackUpDialog(BuildContext context) {
//     showDialog(
//         context: context,
//         builder: (context) => AlertDialog(
//               title: Text('Backup'),
//               content: Text(
//                 'Do you want to backup your mortgage data?',
//                 style: TextStyle(
//                     fontSize: 18, color: Theme.of(context).colorScheme.primary),
//               ),
//               actions: [
//                 Consumer(builder: (context, ref, child) {
//                   return TextButton(
//                     onPressed: () async {
//                       if (!FastDB.getIsTableCreated()) {
//                         ref.read(dBProvider).when(
//                             data: (data) async {
//                               await DatabaseHelper.instance.onCreate(data, 1);
//                             },
//                             error: (_, __) {
//                               showSnackBar(context,
//                                   "An Error occured, Please try again later");
//                             },
//                             loading: () {});
//                       }
//                       Navigator.of(context).pop();
//                     },
//                     child: const Text('No'),
//                   );
//                 }),
//                 Consumer(builder: (context, ref, child) {
//                   return TextButton(
//                     onPressed: () async {
//                       await registerBackUp();
//                       final BackupService backupService = BackupService();
//                       await backupService.downloadFileToDevice();
//                       ref.read(dBProvider).when(
//                           data: (data) async {
//                             ref.read(itemListProvider);
//                             ref
//                                 .read(mortgageMaterialListProvider.notifier)
//                                 .readAllMortgageMaterials();
//                             ref
//                                 .read(familyRelationListProvider.notifier)
//                                 .readAllFamilyRelations();
//                             ref
//                                 .read(mortgageListProvider.notifier)
//                                 .readAllMortgages();
//                           },
//                           error: (_, __) {
//                             showSnackBar(context,
//                                 "An Error occured, Please try again later");
//                           },
//                           loading: () {});
//                           if(context.mounted){
//                             Navigator.of(context).pop();
//                           }
//                     },
//                     child: const Text('Yes'),
//                   );
//                 }),
//               ],
//             ));
//   }
}
