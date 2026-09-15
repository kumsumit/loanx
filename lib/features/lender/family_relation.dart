import 'package:loanx/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loanx/extension/string.dart';
import 'package:loanx/extension/system_value_localization.dart';
import 'package:loanx/model/family_relation.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/widget/snackbar.dart';
import 'package:loanx/widget/styled_text.dart';

class FamilyRelationView extends StatelessWidget {
  const FamilyRelationView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.familyRelations.tr()),
        centerTitle: false,
      ),
      body: Consumer(
        builder: (context, ref, child) {
          final familyRelations = ref.watch(familyRelationListProvider);
          return familyRelations.when(
            data: (data) {
              if (data.isEmpty) {
                return _EmptyState(onAdd: () => familyDialog(context, null));
              }
              final jsonList = data.map((e) => e.toJson()).toList();
              return GroupedListView<dynamic, String>(
                elements: jsonList,
                groupBy: (element) =>
                    element['isAddedByUser'] == 1 ? 'user' : 'system',
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                separator: const SizedBox(height: 10),
                groupSeparatorBuilder: (String groupByValue) => Padding(
                  padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
                  child: Row(
                    children: [
                      Icon(
                        groupByValue == 'user'
                            ? Icons.person_outline_rounded
                            : Icons.verified_outlined,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        groupByValue == 'user'
                            ? LocaleKeys.addedByYou.tr()
                            : LocaleKeys.addedBySystem.tr(),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                itemBuilder: (context, dynamic element) {
                  final isCustom = element['isAddedByUser'] == 1;
                  return Card(
                    margin: EdgeInsets.zero,
                    elevation: 0,
                    color: theme.colorScheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      leading: CircleAvatar(
                        backgroundColor: isCustom
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.secondaryContainer,
                        child: Icon(
                          Icons.people_outline_rounded,
                          color: isCustom
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                      title: Text(
                        data
                            .firstWhere((item) => item.id == element['id'])
                            .localizedName,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        isCustom
                            ? LocaleKeys.customRelation.tr()
                            : LocaleKeys.systemRelation.tr(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: isCustom
                          ? const Icon(Icons.chevron_right_rounded)
                          : Icon(
                              Icons.lock_outline_rounded,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.6),
                            ),
                      onTap: isCustom
                          ? () => familyDialog(
                              context,
                              data.firstWhere(
                                (item) => item.id == element["id"],
                              ),
                            )
                          : null,
                      onLongPress: isCustom
                          ? () => familyDeleteDialog(
                              context,
                              ref,
                              data.firstWhere(
                                (item) => item.id == element["id"],
                              ),
                            )
                          : null,
                    ),
                  );
                },
                itemComparator: (item1, item2) =>
                    item1['name'].compareTo(item2['name']),
                // Keep the current group's label visible without letting it
                // float over a relation card.
                useStickyGroupSeparators: true,
                floatingHeader: false,
                stickyHeaderBackgroundColor: theme.scaffoldBackgroundColor,
                order: GroupedListOrder.ASC,
              );
            },
            error: (_, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 40,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                  Text(LocaleKeys.somethingWentWrong.tr()),
                ],
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => familyDialog(context, null),
        icon: const Icon(Icons.add),
        label: Text(LocaleKeys.addRelation.tr()),
      ),
    );
  }

  void familyDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    FamilyRelation familyRelation,
  ) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.delete_outline_rounded,
            color: theme.colorScheme.onErrorContainer,
          ),
        ),
        title: StyledHeading(
          LocaleKeys.deleteNamedRelation.tr(
            namedArgs: {'name': familyRelation.name},
          ),
        ),
        content: StyledSubtitle(
          'This family relation will be removed permanently. This action cannot be undone.'
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
              backgroundColor: theme.colorScheme.errorContainer,
              foregroundColor: theme.colorScheme.onErrorContainer,
            ),
            onPressed: () async {
              await ref
                  .read(familyRelationListProvider.notifier)
                  .delete(familyRelation.id!);
              if (context.mounted) {
                Navigator.of(context).pop();
                showSnackBar(
                  context,
                  LocaleKeys.familyRelationDeletedSuccessfully.tr(),
                );
              }
            },
            child: Text(LocaleKeys.delete.tr()),
          ),
        ],
      ),
    );
  }

  void familyDialog(BuildContext context, FamilyRelation? familyRelation) {
    final isEditing = familyRelation != null;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        final familyInputController = TextEditingController(
          text: familyRelation?.name,
        );
        final formKey = GlobalKey<FormState>();
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isEditing ? Icons.edit_outlined : Icons.person_add_alt_1_outlined,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          title: StyledHeading(
            isEditing
                ? LocaleKeys.editFamilyRelation2.tr()
                : LocaleKeys.addFamilyRelation2.tr(),
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              style: TextStyle(color: theme.colorScheme.secondary),
              validator: (value) {
                if (value == null || value.isEmpty || value.trim().isEmpty) {
                  return LocaleKeys.familyRelationCannotBeEmpty.tr();
                }
                return null;
              },
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: LocaleKeys.enterTheFamilyRelation.tr(),
                hintStyle: TextStyle(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
                prefixIcon: const Icon(Icons.people_outline_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              controller: familyInputController,
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
                          .read(familyRelationListProvider.notifier)
                          .add(familyInputController.text.toSentenceCase());
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        if (status > 0) {
                          showSnackBar(
                            context,
                            LocaleKeys.familyRelationAddedSuccessfully.tr(),
                          );
                        } else {
                          showSnackBar(
                            context,
                            LocaleKeys.familyRelationAlreadyExists.tr(),
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
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.5,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.family_restroom_rounded,
                size: 40,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            StyledHeading(LocaleKeys.noFamilyRelationsYet.tr()),
            const SizedBox(height: 8),
            Text(
              'Add relations like Father, Mother, or Sibling to get started.'
                  .tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(LocaleKeys.addRelation.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
