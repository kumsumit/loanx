import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mortgage/model/mortgage_material.dart';
import 'package:mortgage/provider/provider.dart';
import 'package:mortgage/widget/snackbar.dart';

class MortgageMaterialView extends StatelessWidget {
  const MortgageMaterialView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer(builder: (context, ref, child) {
        final mortgageMaterials = ref.watch(mortgageMaterialListProvider);
        return ListView.builder(
          itemCount: mortgageMaterials.length,
          itemBuilder: (context, index) => ListTile(
            onTap: () => mortgageDialog(context, mortgageMaterials[index]),
            onLongPress: mortgageMaterials[index].isAddedByUser == 1
                ? () =>
                    mortgageDeleteDialog(context, ref, mortgageMaterials[index])
                : null,
            title: Text(mortgageMaterials[index].name),
          ),
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () => mortgageDialog(context, null),
        child: Icon(Icons.add),
      ),
    );
  }

  void mortgageDeleteDialog(
      BuildContext context, WidgetRef ref, MortgageMaterial mortgageMaterial) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Text('Delete Mortgage Material'),
              content: Text(
                  'Are you sure you want to delete this mortgage material?'),
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
                        .read(mortgageMaterialListProvider.notifier)
                        .delete(mortgageMaterial.id!);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      showSnackBar(
                          context, 'Mortgage Material deleted successfully');
                    }
                  },
                  child: const Text('Delete'),
                ),
              ],
            ));
  }

  void mortgageDialog(
      BuildContext context, MortgageMaterial? mortgageMaterial) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final mortgageMaterialInputController =
            TextEditingController(text: mortgageMaterial?.name);
        final formKey = GlobalKey<FormState>();
        return AlertDialog(
          title: Text('Add Mortgage Material'),
          content: Form(
            key: formKey,
            child: TextFormField(
              validator: (value) {
                if (value == null || value.isEmpty || value.trim().isEmpty) {
                  return 'Mortgage Material cannot be empty';
                }
                return null;
              },
              autofocus: true,
              decoration: const InputDecoration(
                  hintText: 'Enter the Mortgage Material'),
              controller: mortgageMaterialInputController,
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
                        .read(mortgageMaterialListProvider.notifier)
                        .add(mortgageMaterialInputController.text);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      if (status > 0) {
                        showSnackBar(
                            context, 'Mortgage Material added successfully');
                      } else {
                        showSnackBar(
                            context, 'Mortgage Material already exists');
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
