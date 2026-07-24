import 'package:flutter/material.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loanx/extension/string.dart';
import 'package:loanx/model/family_relation.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/widget/snackbar.dart';
import 'package:loanx/widget/styled_text.dart';

class FamilyRelationView extends StatelessWidget {
  const FamilyRelationView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer(
        builder: (context, ref, child) {
          final familyRelations = ref.watch(familyRelationListProvider);
          return familyRelations.when(
            data: (data) {
              if (data.isEmpty) {
                return Center(child: StyledHeading('No family relation found'));
              }
              final jsonList = data.map((e) => e.toJson()).toList();
              return GroupedListView<dynamic, String>(
                elements: jsonList,
                groupBy: (element) => element['isAddedByUser'] == 1
                    ? 'Added By You'
                    : 'Added By System',
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                separator: const SizedBox(height: 8),
                groupSeparatorBuilder: (String groupByValue) => Padding(
                  padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      groupByValue,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                itemBuilder: (context, dynamic element) => Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.people_outline_rounded),
                    ),
                    title: Text(element['name']),
                    subtitle: Text(
                      element['isAddedByUser'] == 1
                          ? 'Custom relation'
                          : 'System relation',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => familyDialog(
                      context,
                      data.firstWhere((item) => item.id == element["id"]),
                    ),
                    onLongPress: element['isAddedByUser'] == 1
                        ? () => familyDeleteDialog(
                            context,
                            ref,
                            data.firstWhere((item) => item.id == element["id"]),
                          )
                        : null,
                  ),
                ),
                itemComparator: (item1, item2) =>
                    item1['name'].compareTo(item2['name']), // optional
                useStickyGroupSeparators: true, // optional
                floatingHeader: true, // optional
                order: GroupedListOrder.ASC, // optional
              );
            },
            error: (_, _) {
              return Center(child: Text("An error occurred"));
            },
            loading: () => Center(child: CircularProgressIndicator()),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => familyDialog(context, null),
        child: Icon(Icons.add),
      ),
    );
  }

  void familyDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    FamilyRelation familyRelation,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: StyledHeading('Delete Family Relation'),
        content: StyledSubtitle(
          'Are you sure you want to delete this family relation?',
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref
                  .read(familyRelationListProvider.notifier)
                  .delete(familyRelation.id!);
              if (context.mounted) {
                Navigator.of(context).pop();
                showSnackBar(context, 'Family Relation Deleted Successfully');
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void familyDialog(BuildContext context, FamilyRelation? familyRelation) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final familyInputController = TextEditingController(
          text: familyRelation?.name,
        );
        final formKey = GlobalKey<FormState>();
        return AlertDialog(
          title: StyledHeading('Add Family Relation'),
          content: Form(
            key: formKey,
            child: TextFormField(
              style: TextStyle(color: Theme.of(context).colorScheme.secondary),
              validator: (value) {
                if (value == null || value.isEmpty || value.trim().isEmpty) {
                  return 'Family Relation cannot be empty';
                }
                return null;
              },
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Enter the Family Relation',
                hintStyle: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
              controller: familyInputController,
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            Consumer(
              builder: (context, ref, child) {
                return TextButton(
                  child: const Text('Submit'),
                  onPressed: () async {
                    if (formKey.currentState != null &&
                        formKey.currentState!.validate()) {
                      final status = await ref
                          .read(familyRelationListProvider.notifier)
                          .add(familyInputController.text.toSentenceCase());
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        if (status > 0) {
                          showSnackBar(
                            context,
                            "Family Relation added successfully",
                          );
                        } else {
                          showSnackBar(
                            context,
                            'Family Relation already exists',
                          );
                        }
                      }
                    }
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }
}
