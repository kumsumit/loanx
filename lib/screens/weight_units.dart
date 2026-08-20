import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loanx/model/weight_unit.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/widget/snackbar.dart';

class WeightUnitView extends ConsumerWidget {
  const WeightUnitView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(weightUnitListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Weight Units')),
      body: units.when(
        data: (items) => items.isEmpty
            ? const Center(child: Text('No weight units yet'))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final unit = items[index];
                  final isCustom = unit.isAddedByUser == 1;
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.straighten_rounded),
                      ),
                      title: Text(unit.name),
                      subtitle: Text(
                        '${unit.symbol} · ${isCustom ? 'Custom unit' : 'System unit'}',
                      ),
                      onTap: isCustom
                          ? () => _showUnitDialog(context, ref, unit)
                          : null,
                      trailing: isCustom
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Edit',
                                  onPressed: () =>
                                      _showUnitDialog(context, ref, unit),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  color: Theme.of(context).colorScheme.error,
                                  onPressed: () =>
                                      _deleteUnit(context, ref, unit),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            )
                          : const Icon(Icons.lock_outline_rounded),
                    ),
                  );
                },
              ),
        error: (_, _) => const Center(child: Text('Unable to load units')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUnitDialog(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Add unit'),
      ),
    );
  }

  Future<void> _showUnitDialog(
    BuildContext context,
    WidgetRef ref,
    WeightUnit? unit,
  ) async {
    final nameController = TextEditingController(text: unit?.name);
    final symbolController = TextEditingController(text: unit?.symbol);
    final formKey = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.straighten_rounded),
        title: Text(unit == null ? 'Add Weight Unit' : 'Edit Weight Unit'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Unit name',
                  hintText: 'Example: Ounce',
                ),
                validator: _required,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: symbolController,
                decoration: const InputDecoration(
                  labelText: 'Symbol',
                  hintText: 'Example: oz',
                ),
                validator: _required,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final notifier = ref.read(weightUnitListProvider.notifier);
              if (unit == null) {
                final result = await notifier.add(
                  nameController.text,
                  symbolController.text,
                );
                if (result < 0) {
                  if (dialogContext.mounted) {
                    showSnackBar(dialogContext, 'Unit already exists');
                  }
                  return;
                }
              } else {
                await notifier.updateData(
                  unit.copy(
                    name: nameController.text.trim(),
                    symbol: symbolController.text.trim(),
                  ),
                );
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: Text(unit == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
    nameController.dispose();
    symbolController.dispose();
  }

  Future<void> _deleteUnit(
    BuildContext context,
    WidgetRef ref,
    WeightUnit unit,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete weight unit?'),
        content: Text(
          'Remove ${unit.name} (${unit.symbol}) from future selections? Existing loans will keep their saved unit.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(weightUnitListProvider.notifier).delete(unit.id!);
    }
  }

  static String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required' : null;
}
