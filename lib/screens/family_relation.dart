import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mortgage/model/family_relation.dart';
import 'package:mortgage/provider/provider.dart';
import 'package:mortgage/widget/snackbar.dart';

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
            onTap: () => familyDialog(context, familyRelations[index]),
            onLongPress: familyRelations[index].isAddedByUser == 1
                ? () => familyDeleteDialog(context, ref, familyRelations[index])
                : null,
            title: Text(familyRelations[index].name),
          ),
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () => familyDialog(context, null),
        child: Icon(Icons.add),
      ),
    );
  }

  void familyDeleteDialog(
      BuildContext context, WidgetRef ref, FamilyRelation familyRelation) {
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
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      showSnackBar(
                          context, 'Family Relation Deleted Successfully');
                    }
                  },
                  child: const Text('Delete'),
                ),
              ],
            ));
  }

  void familyDialog(BuildContext context, FamilyRelation? familyRelation) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final familyInputController =
            TextEditingController(text: familyRelation?.name);
        final formKey = GlobalKey<FormState>();
        return AlertDialog(
          title: Text('Add Family Relation'),
          content: Form(
            key: formKey,
            child: TextFormField(
              validator: (value) {
                if (value == null || value.isEmpty || value.trim().isEmpty) {
                  return 'Family Relation cannot be empty';
                }
                return null;
              },
              autofocus: true,
              decoration:
                  const InputDecoration(hintText: 'Enter the Family Relation'),
              controller: familyInputController,
            ),
          ),
          actions: [
            Consumer(builder: (context, ref, child) {
              return TextButton(
                child: const Text('Submit'),
                onPressed: () async {
                  if (formKey.currentState != null &&
                      formKey.currentState!.validate()) {
                    final status = await ref
                        .read(familyRelationListProvider.notifier)
                        .add(familyInputController.text);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      if (status > 0) {
                        showSnackBar(
                            context, "Family Relation added successfully");
                      } else {
                        showSnackBar(context, 'Family Relation already exists');
                      }
                    }
                  }
                },
              );
            }),
          ],
        );
      },
    );
  }
}
