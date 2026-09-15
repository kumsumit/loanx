import 'package:flutter/material.dart';
import 'package:loanx/db/app_settings.dart';
import 'package:loanx/domain/country_catalog.dart';
import 'package:loanx/service/plan_pricing.dart';

/// Captures an onboarding preference only. Subscription activation must be
/// confirmed by the billing provider and enforced by the server.
class PlanSelectionScreen extends StatefulWidget {
  const PlanSelectionScreen({required this.onContinue, super.key});

  final VoidCallback onContinue;

  @override
  State<PlanSelectionScreen> createState() => _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends State<PlanSelectionScreen> {
  String _selectedPlan = 'pro';
  late final bool _requiresPro;
  late final CountryConfig _country;
  late final Future<PlanPrice> _proPrice;

  @override
  void initState() {
    super.initState();
    _requiresPro = AppSettings.getUsesBothExperience();
    _country = CountryCatalog.byCode(AppSettings.getVerifiedPhoneCountryCode());
    _proPrice = PlanPricingService().proPriceFor(_country);
  }

  Future<void> _continue() async {
    if (_requiresPro) _selectedPlan = 'pro';
    AppSettings.putSelectedPlan(_selectedPlan);
    AppSettings.putPlanSelectionCompleted(true);
    await AppSettings.flush();
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Choose how you want to use LoanX',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _requiresPro
                        ? 'Lend and borrow uses the paid LoanX Pro workspace so both portfolios stay available together.'
                        : 'You can keep managing loans locally for free, or choose Pro for connected features.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FutureBuilder<PlanPrice>(
                    future: _proPrice,
                    builder: (context, snapshot) {
                      final price = snapshot.data;
                      final priceUnavailable = snapshot.hasError;
                      return _PlanOption(
                        selected: _selectedPlan == 'pro',
                        title: 'LoanX Pro',
                        price: price == null
                            ? priceUnavailable
                                  ? 'Price unavailable'
                                  : 'Loading price…'
                            : '${price.currentLabel} / year',
                        previousPrice: price == null
                            ? null
                            : '${price.previousLabel} / year',
                        subtitle: price == null
                            ? priceUnavailable
                                  ? 'Connect to the internet to get the current ${_country.currency} estimate'
                                  : 'Getting the current price for ${_country.name}'
                            : price.isEstimate
                            ? 'Estimated current price in ${price.currency}'
                            : 'Introductory price in ${price.currency}',
                        features: const [
                          'Cloud sync and multi-device access',
                          'Connected borrower relationships',
                          'Automated reminders and shared statements',
                        ],
                        onTap: () => setState(() => _selectedPlan = 'pro'),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  if (!_requiresPro)
                    _PlanOption(
                      selected: _selectedPlan == 'free',
                      title: 'Free',
                      price: '${_country.symbol}0 (${_country.currency})',
                      subtitle: 'Local loan management',
                      features: const [
                        'Loans, repayments, receipts and reports',
                        'External people and Google Drive backup',
                      ],
                      onTap: () => setState(() => _selectedPlan = 'free'),
                    ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _continue,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text('Continue'),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Selecting Pro does not activate a subscription. Payment and entitlement confirmation happen securely before connected features are enabled.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanOption extends StatelessWidget {
  const _PlanOption({
    required this.selected,
    required this.title,
    required this.price,
    this.previousPrice,
    required this.subtitle,
    required this.features,
    required this.onTap,
  });
  final bool selected;
  final String title;
  final String price;
  final String? previousPrice;
  final String subtitle;
  final List<String> features;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primaryContainer : colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: selected ? colors.primary : colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    price,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (previousPrice != null)
                Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: Text(
                    previousPrice!,
                    style: TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(left: 48, top: 2),
                child: Text(
                  subtitle,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 12),
              ...features.map(
                (feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(feature)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
