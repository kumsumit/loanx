import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mortgage/model/mortgage_material.dart';
import 'package:mortgage/provider/provider.dart';

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
            onTap: () async =>
                await mortgageDialog(context, mortgageMaterials[index]),
            onLongPress: mortgageMaterials[index].isAddedByUser == 1
                ? () async => await mortgageDeleteDialog(
                    context, ref, mortgageMaterials[index])
                : null,
            title: Text(mortgageMaterials[index].name),
          ),
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () async => await mortgageDialog(context, null),
        child: Icon(Icons.add),
      ),
    );
  }

  Future<void> mortgageDeleteDialog(BuildContext context, WidgetRef ref,
      MortgageMaterial mortgageMaterial) async {
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
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: const Text('Delete'),
                ),
              ],
            ));
  }

  Future<void> mortgageDialog(
      BuildContext context, MortgageMaterial? mortgageMaterial) async {
    final mortgageMaterialInputController =
        TextEditingController(text: mortgageMaterial?.name);
    final dialog = await showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Add Mortgage Material'),
        content: TextField(
          autofocus: true,
          decoration:
              const InputDecoration(hintText: 'Enter the Mortgage Material'),
          controller: mortgageMaterialInputController,
        ),
        actions: [
          Consumer(builder: (context, ref, child) {
            return TextButton(
              child: const Text('Submit'),
              onPressed: () async {
                final status = await ref
                    .read(mortgageMaterialListProvider.notifier)
                    .add(mortgageMaterialInputController.text);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  if (status > 0) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Mortgage Material added successfully')));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Mortgage Material already exists')));
                  }
                }
              },
            );
          }),
        ],
      ),
    );
    mortgageMaterialInputController.clear();
    return dialog;
  }
}
