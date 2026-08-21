import 'package:loanx/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loanx/extension/string.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/widget/snackbar.dart';
import 'package:loanx/widget/styled_text.dart';

class MortgageMaterialView extends StatelessWidget {
  const MortgageMaterialView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.mortgageMaterials.tr()),
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: Consumer(
        builder: (context, ref, child) {
          final mortgageMaterials = ref.watch(mortgageMaterialListProvider);
          return mortgageMaterials.when(
            data: (data) {
              if (data.isEmpty) {
                return _EmptyState(theme: theme);
              }
              final jsonList = data.map((e) => e.toJson()).toList();
              return GroupedListView<dynamic, String>(
                elements: jsonList,
                groupBy: (element) => element['isAddedByUser'] == 1
                    ? 'Added By You'
                    : 'Added By System',
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                separator: const SizedBox(height: 10),
                groupSeparatorBuilder: (String groupByValue) => Padding(
                  padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
                  child: Row(
                    children: [
                      Icon(
                        groupByValue == 'Added By You'
                            ? Icons.person_outline_rounded
                            : Icons.settings_suggest_outlined,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        groupByValue.tr(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                itemBuilder: (context, dynamic element) {
                  final isCustom = element['isAddedByUser'] == 1;
                  return Material(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => mortgageDialog(context, element['name']),
                      onLongPress: isCustom
                          ? () => mortgageDeleteDialog(
                              context,
                              ref,
                              element['id'],
                            )
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: isCustom
                                  ? theme.colorScheme.primaryContainer
                                  : theme.colorScheme.secondaryContainer,
                              child: Icon(
                                Icons.inventory_2_outlined,
                                size: 20,
                                color: isCustom
                                    ? theme.colorScheme.onPrimaryContainer
                                    : theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    element['name'],
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isCustom
                                        ? LocaleKeys.customMaterial.tr()
                                        : LocaleKeys.systemMaterial.tr(),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isCustom)
                              IconButton(
                                tooltip: LocaleKeys.delete.tr(),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 20,
                                ),
                                color: theme.colorScheme.error,
                                onPressed: () => mortgageDeleteDialog(
                                  context,
                                  ref,
                                  element['id'],
                                ),
                              )
                            else
                              Icon(
                                Icons.chevron_right_rounded,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                itemComparator: (item1, item2) =>
                    item1['name'].compareTo(item2['name']),
                // Keep the current group's label visible without letting it
                // float over a material card.
                useStickyGroupSeparators: true,
                floatingHeader: false,
                stickyHeaderBackgroundColor: theme.scaffoldBackgroundColor,
                order: GroupedListOrder.ASC,
              );
            },
            error: (_, _) => _ErrorState(theme: theme),
            loading: () => const Center(child: CircularProgressIndicator()),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => mortgageDialog(context, null),
        icon: const Icon(Icons.add),
        label: Text(LocaleKeys.addMaterial.tr()),
      ),
    );
  }

  void mortgageDeleteDialog(BuildContext context, WidgetRef ref, int id) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.delete_outline_rounded,
          color: Theme.of(context).colorScheme.error,
          size: 32,
        ),
        title: StyledHeading(LocaleKeys.deleteMortgageMaterial2.tr()),
        content: StyledSubtitle(
          'Are you sure you want to delete this mortgage material? This action cannot be undone.'
              .tr(),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(LocaleKeys.cancel.tr()),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
            ),
            onPressed: () async {
              await ref.read(mortgageMaterialListProvider.notifier).delete(id);
              if (context.mounted) {
                Navigator.of(context).pop();
                showSnackBar(
                  context,
                  LocaleKeys.mortgageMaterialDeletedSuccessfully.tr(),
                );
              }
            },
            child: Text(LocaleKeys.delete.tr()),
          ),
        ],
      ),
    );
  }

  void mortgageDialog(BuildContext context, String? name) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final mortgageMaterialInputController = TextEditingController(
          text: name,
        );
        final formKey = GlobalKey<FormState>();
        return AlertDialog(
          icon: Icon(
            Icons.inventory_2_outlined,
            color: Theme.of(context).colorScheme.primary,
            size: 32,
          ),
          title: StyledHeading(
            name == null
                ? LocaleKeys.addMortgageMaterial2.tr()
                : LocaleKeys.editMortgageMaterial2.tr(),
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              style: TextStyle(color: Theme.of(context).colorScheme.secondary),
              validator: (value) {
                if (value == null || value.isEmpty || value.trim().isEmpty) {
                  return LocaleKeys.mortgageMaterialCannotBeEmpty.tr();
                }
                return null;
              },
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: LocaleKeys.enterTheMortgageMaterial.tr(),
                hintStyle: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
                prefixIcon: const Icon(Icons.edit_outlined, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              controller: mortgageMaterialInputController,
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(LocaleKeys.cancel.tr()),
            ),
            Consumer(
              builder: (context, ref, child) {
                return FilledButton(
                  child: Text(LocaleKeys.submit.tr()),
                  onPressed: () async {
                    if (formKey.currentState != null &&
                        formKey.currentState!.validate()) {
                      final status = await ref
                          .read(mortgageMaterialListProvider.notifier)
                          .add(
                            mortgageMaterialInputController.text
                                .toSentenceCase(),
                          );
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        if (status > 0) {
                          showSnackBar(
                            context,
                            LocaleKeys.mortgageMaterialAddedSuccessfully.tr(),
                          );
                        } else {
                          showSnackBar(
                            context,
                            LocaleKeys.mortgageMaterialAlreadyExists.tr(),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              LocaleKeys.noMortgageMaterialsYet.tr(),
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              LocaleKeys.tapAddMaterialToCreateYourFirstOne.tr(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              LocaleKeys.somethingWentWrong.tr(),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              LocaleKeys.pleaseTryAgainInAMoment.tr(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
