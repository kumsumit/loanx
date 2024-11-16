import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mortgage/model/item.dart';
import 'package:mortgage/provider/provider.dart';

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
              onTap: () async => await itemDialog(context, item),
              onLongPress: item.isAddedByUser == 1
                  ? () async => await itemDeleteDialog(context, ref, item)
                  : null,
            );
          },
        );
      }),
      floatingActionButton: FloatingActionButton(
          onPressed: () async {
            await itemDialog(context, null);
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
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: const Text('Delete'),
                ),
              ],
            ));
  }

  Future<void> itemDialog(BuildContext context, Item? item) async {
    final itemInputController = TextEditingController(text: item?.name);
    final dialog = await showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(item == null ? 'Add item' : 'Edit item'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter the item name'),
          controller: itemInputController,
        ),
        actions: [
          Consumer(builder: (context, ref, child) {
            return TextButton(
              child: const Text('Submit'),
              onPressed: () async {
                final status = await ref
                    .read(itemListProvider.notifier)
                    .add(itemInputController.text);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  if (status > 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Item added successfully')));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Item already exists')));
                  }
                }
              },
            );
          }),
        ],
      ),
    );
    itemInputController.clear();
    return dialog;
  }
}
