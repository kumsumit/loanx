import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:loanx/l10n/locale_keys.g.dart';

/// An onboarding preference, never an authorization role or capability gate.
enum AccountType { lender, borrower, both }

class AccountTypeScreen extends StatefulWidget {
  const AccountTypeScreen({required this.onContinue, super.key});
  final ValueChanged<AccountType> onContinue;

  @override
  State<AccountTypeScreen> createState() => _AccountTypeScreenState();
}

class _AccountTypeScreenState extends State<AccountTypeScreen> {
  AccountType _selectedType = AccountType.both;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final choices = [
      (
        type: AccountType.lender,
        icon: Icons.trending_up_rounded,
        title: LocaleKeys.lenderAccount.tr(),
        description: LocaleKeys.lenderAccountDescription.tr(),
      ),
      (
        type: AccountType.borrower,
        icon: Icons.account_balance_wallet_outlined,
        title: LocaleKeys.borrowerAccount.tr(),
        description: LocaleKeys.borrowerAccountDescription.tr(),
      ),
      (
        type: AccountType.both,
        icon: Icons.swap_horiz_rounded,
        title: LocaleKeys.bothLendingAndBorrowing.tr(),
        description: LocaleKeys.bothAccountDescription.tr(),
      ),
    ];

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.surface,
              colors.primaryContainer.withValues(alpha: .35),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _InterestHero(colors: colors),
                    const SizedBox(height: 28),
                    Text(
                      LocaleKeys.chooseAccountType.tr(),
                      style: theme.textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      LocaleKeys.accountTypePrompt.tr(),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 26),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cards = choices
                            .map(
                              (choice) => _AccountTypeCard(
                                key: Key('interest-${choice.type.name}'),
                                icon: choice.icon,
                                title: choice.title,
                                description: choice.description,
                                selected: _selectedType == choice.type,
                                onTap: () =>
                                    setState(() => _selectedType = choice.type),
                              ),
                            )
                            .toList();
                        if (constraints.maxWidth < 620) {
                          return Column(
                            children: [
                              for (
                                var index = 0;
                                index < cards.length;
                                index++
                              ) ...[
                                cards[index],
                                if (index < cards.length - 1)
                                  const SizedBox(height: 12),
                              ],
                            ],
                          );
                        }
                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (
                                var index = 0;
                                index < cards.length;
                                index++
                              ) ...[
                                Expanded(child: cards[index]),
                                if (index < cards.length - 1)
                                  const SizedBox(width: 12),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      key: const Key('interest-continue'),
                      onPressed: () => widget.onContinue(_selectedType),
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(LocaleKeys.continueAction.tr()),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(58),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 18,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            LocaleKeys.preferenceCanChangeLater.tr(),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InterestHero extends StatelessWidget {
  const _InterestHero({required this.colors});
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Container(
      width: 104,
      height: 88,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [colors.primary, colors.tertiary]),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: .24),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.handshake_rounded, size: 44, color: colors.onPrimary),
          PositionedDirectional(
            end: 13,
            bottom: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.sync_alt_rounded,
                  size: 16,
                  color: colors.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AccountTypeCard extends StatelessWidget {
  const _AccountTypeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
    super.key,
  });
  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected
            ? colors.primaryContainer
            : colors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: selected
                            ? colors.primary
                            : colors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        icon,
                        color: selected
                            ? colors.onPrimary
                            : colors.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: selected ? colors.primary : colors.outline,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
