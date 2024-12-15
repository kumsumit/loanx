import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loanx/model/mortgage_material.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/widget/snackbar.dart';

class MortgageMaterialView extends StatelessWidget {
  const MortgageMaterialView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer(builder: (context, ref, child) {
        final mortgageMaterials = ref.watch(mortgageMaterialListProvider);

        return mortgageMaterials.when(
            data: (data) {
              return data.isEmpty
                  ? Center(child: Text('No mortgage material found'))
                  : ListView.builder(
                      itemCount: data.length,
                      itemBuilder: (context, index) => ListTile(
                        onTap: () => mortgageDialog(context, data[index]),
                        onLongPress: data[index].isAddedByUser == 1
                            ? () =>
                                mortgageDeleteDialog(context, ref, data[index])
                            : null,
                        title: Text(data[index].name),
                      ),
                    );
            },
            error: (_, __) {
              return Center(child: Text("An error occurred"));
            },
            loading: () => Center(child: CircularProgressIndicator()));
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
                            context, 'loanx Material added successfully');
                      } else {
                        showSnackBar(context, 'loanx Material already exists');
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
