import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mortgage/model/item.dart';
import 'package:mortgage/provider/provider.dart';
import 'package:mortgage/widget/snackbar.dart';

class ItemView extends StatelessWidget {
  const ItemView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer(builder: (context, ref, child) {
        final items = ref.watch(itemListProvider);
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              title: Text(item.name),
              onTap: item.isAddedByUser == 1
                  ? () => itemDialog(context, item)
                  : null,
              onLongPress: item.isAddedByUser == 1
                  ? () async => await itemDeleteDialog(context, ref, item)
                  : null,
            );
          },
        );
      }),
      floatingActionButton: FloatingActionButton(
          onPressed: () {
            itemDialog(context, null);
          },
          child: Icon(Icons.add)),
    );
  }

  Future<void> itemDeleteDialog(
      BuildContext context, WidgetRef ref, Item item) async {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Text('Delete Item'),
              content: Text('Are you sure you want to delete this item?'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    await ref.read(itemListProvider.notifier).delete(item.id!);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      showSnackBar(context, 'Item deleted successfully');
                    }
                  },
                  child: const Text('Delete'),
                ),
              ],
            ));
  }

  void itemDialog(BuildContext context, Item? item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final itemInputController = TextEditingController(text: item?.name);
        final formKey = GlobalKey<FormState>();
        return AlertDialog(
          title: Text(item == null ? 'Add item' : 'Edit item'),
          content: Form(
            key: formKey,
            child: TextFormField(
              validator: (value) {
                if (value == null || value.isEmpty || value.trim().isEmpty) {
                  return 'Item name cannot be empty';
                }
                return null;
              },
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Enter the item name',
                errorStyle: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 16.0,
                ),
              ),
              controller: itemInputController,
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
                        .read(itemListProvider.notifier)
                        .add(itemInputController.text);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      if (status > 0) {
                        showSnackBar(context, 'Item added successfully');
                      } else {
                        showSnackBar(context, 'Item already exists');
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
