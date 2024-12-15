import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loanx/model/mortgage.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/widget/snackbar.dart';

class MortgageView extends StatelessWidget {
  const MortgageView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer(builder: (context, ref, child) {
        final mortgages = ref.watch(mortgageListProvider);
        return mortgages.when(
            data: (data) {
              if (data.isEmpty) {
                return Center(child: Text("No data found"));
              }
              return ListView.builder(
                itemCount: data.length,
                itemBuilder: (context, index) {
                  final mortgage = data[index];
                  return ListTile(
                    title: Text(mortgage.name),
                    onTap: mortgage.isAddedByUser == 1
                        ? () => mortgageDialog(context, mortgage)
                        : null,
                    onLongPress: mortgage.isAddedByUser == 1
                        ? () async => await mortgageDeleteDialog(context, ref, mortgage)
                        : null,
                  );
                },
              );
            },
            error: (_, p) {
              return Center(child: Text("An Error Occurred"));
            },
            loading: () => Center(child: CircularProgressIndicator()));
      }),
      floatingActionButton: FloatingActionButton(
          onPressed: () {
            mortgageDialog(context, null);
          },
          child: Icon(Icons.add)),
    );
  }

  Future<void> mortgageDeleteDialog(
      BuildContext context, WidgetRef ref, Mortgage mortgage) async {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Text('Delete Mortgage'),
              content: Text('Are you sure you want to delete this mortgage?'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    await ref.read(mortgageListProvider.notifier).delete(mortgage.id!);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      showSnackBar(context, 'Mortgage deleted successfully');
                    }
                  },
                  child: const Text('Delete'),
                ),
              ],
            ));
  }

  void mortgageDialog(BuildContext context, Mortgage? mortgage) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final mortgageInputController = TextEditingController(text: mortgage?.name);
        final formKey = GlobalKey<FormState>();
        return AlertDialog(
          title: Text(mortgage == null ? 'Add Mortgage' : 'Edit Mortgage'),
          content: Form(
            key: formKey,
            child: TextFormField(
              validator: (value) {
                if (value == null || value.isEmpty || value.trim().isEmpty) {
                  return 'Mortgage name cannot be empty';
                }
                return null;
              },
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Enter the mortgage name',
                errorStyle: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 16.0,
                ),
              ),
              controller: mortgageInputController,
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
                        .read(mortgageListProvider.notifier)
                        .add(mortgageInputController.text);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      if (status > 0) {
                        showSnackBar(context, 'Mortgage added successfully');
                      } else {
                        showSnackBar(context, 'Mortgage already exists');
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
