import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mortgage/model/family_relation.dart';
import 'package:mortgage/provider/provider.dart';

class FamilyRelationView extends StatelessWidget {
  const FamilyRelationView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer(builder: (context, ref, child) {
        final familyRelations = ref.watch(familyRelationListProvider);
        return ListView.builder(
          itemCount: familyRelations.length,
          itemBuilder: (context, index) => ListTile(
            onTap: () async =>
                await familyDialog(context, familyRelations[index]),
            onLongPress: familyRelations[index].isAddedByUser == 1
                ? () async => await familyDeleteDialog(
                    context, ref, familyRelations[index])
                : null,
            title: Text(familyRelations[index].name),
          ),
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () async => await familyDialog(context, null),
        child: Icon(Icons.add),
      ),
    );
  }

  Future<void> familyDeleteDialog(BuildContext context, WidgetRef ref,
      FamilyRelation familyRelation) async {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Text('Delete Family Relation'),
              content:
                  Text('Are you sure you want to delete this family relation?'),
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
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: const Text('Delete'),
                ),
              ],
            ));
  }

  Future<void> familyDialog(
      BuildContext context, FamilyRelation? familyRelation) async {
    final familyInputController =
        TextEditingController(text: familyRelation?.name);
    final dialog = await showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Add Family Relation'),
        content: TextField(
          autofocus: true,
          decoration:
              const InputDecoration(hintText: 'Enter the Family Relation'),
          controller: familyInputController,
        ),
        actions: [
          Consumer(builder: (context, ref, child) {
            return TextButton(
              child: const Text('Submit'),
              onPressed: () async {
                final status = await ref
                    .read(familyRelationListProvider.notifier)
                    .add(familyInputController.text);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  if (status > 0) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Family Relation added successfully')));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Family Relation already exists')));
                  }
                }
              },
            );
          }),
        ],
      ),
    );
    familyInputController.clear();
    return dialog;
  }
}
