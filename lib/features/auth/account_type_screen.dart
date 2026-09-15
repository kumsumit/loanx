import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:loanx/l10n/locale_keys.g.dart';
import 'package:loanx/service/device_performance.dart';

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
    final basicEffects = DevicePerformance.isSafe;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    // Keep the entire choice set within reach on common narrow phones. These
    // screens have enough horizontal room for a compact row, but not enough
    // vertical room for three full-height marketing cards.
    final compactLayout = screenWidth < 600;
    final shortLayout = screenHeight < 700;
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
          color: basicEffects ? colors.surface : null,
          gradient: basicEffects
              ? null
              : LinearGradient(
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
              padding: EdgeInsets.fromLTRB(
                compactLayout ? 16 : 20,
                compactLayout ? 16 : 24,
                compactLayout ? 16 : 20,
                20,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!shortLayout) ...[
                      _InterestHero(
                        colors: colors,
                        basicEffects: basicEffects,
                        compact: compactLayout,
                      ),
                      SizedBox(height: compactLayout ? 20 : 28),
                    ],
                    Text(
                      LocaleKeys.chooseAccountType.tr(),
                      style: compactLayout
                          ? theme.textTheme.headlineMedium
                          : theme.textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      LocaleKeys.accountTypePrompt.tr(),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: compactLayout ? 20 : 26),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compactCards =
                            compactLayout || constraints.maxWidth < 600;
                        final cards = choices
                            .map(
                              (choice) => _AccountTypeCard(
                                key: Key('interest-${choice.type.name}'),
                                icon: choice.icon,
                                title: choice.title,
                                description: choice.description,
                                compact: compactCards,
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
                    SizedBox(height: compactLayout ? 20 : 28),
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
  const _InterestHero({
    required this.colors,
    required this.basicEffects,
    required this.compact,
  });
  final ColorScheme colors;
  final bool basicEffects;
  final bool compact;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Container(
      width: compact ? 88 : 104,
      height: compact ? 76 : 88,
      decoration: BoxDecoration(
        color: basicEffects ? colors.primary : null,
        gradient: basicEffects
            ? null
            : LinearGradient(colors: [colors.primary, colors.tertiary]),
        borderRadius: BorderRadius.circular(28),
        boxShadow: basicEffects
            ? null
            : [
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
          Icon(
            Icons.handshake_rounded,
            size: compact ? 38 : 44,
            color: colors.onPrimary,
          ),
          PositionedDirectional(
            end: compact ? 10 : 13,
            bottom: compact ? 9 : 12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: EdgeInsets.all(compact ? 3 : 4),
                child: Icon(
                  Icons.sync_alt_rounded,
                  size: compact ? 14 : 16,
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
    required this.compact,
    required this.selected,
    required this.onTap,
    super.key,
  });
  final IconData icon;
  final String title;
  final String description;
  final bool compact;
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
            padding: EdgeInsets.all(compact ? 12 : 18),
            child: compact
                ? Row(
                    children: [
                      _AccountTypeIcon(
                        icon: icon,
                        selected: selected,
                        colors: colors,
                        compact: true,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _AccountTypeSelection(selected: selected, colors: colors),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _AccountTypeIcon(
                            icon: icon,
                            selected: selected,
                            colors: colors,
                          ),
                          const Spacer(),
                          _AccountTypeSelection(
                            selected: selected,
                            colors: colors,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
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

class _AccountTypeIcon extends StatelessWidget {
  const _AccountTypeIcon({
    required this.icon,
    required this.selected,
    required this.colors,
    this.compact = false,
  });

  final IconData icon;
  final bool selected;
  final ColorScheme colors;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 44.0 : 50.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: selected ? colors.primary : colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(compact ? 13 : 15),
      ),
      child: Icon(
        icon,
        color: selected ? colors.onPrimary : colors.onSurfaceVariant,
      ),
    );
  }
}

class _AccountTypeSelection extends StatelessWidget {
  const _AccountTypeSelection({required this.selected, required this.colors});

  final bool selected;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) => Icon(
    selected ? Icons.check_circle_rounded : Icons.circle_outlined,
    color: selected ? colors.primary : colors.outline,
  );
}
