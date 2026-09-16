import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:loanx/service/auth_client.dart';
import 'package:loanx/src/rust/api/network.dart' as network;

enum LenderSearchArea { locality, city, pincode }

class LenderSearchRequest {
  const LenderSearchRequest({required this.area, required this.query});

  final LenderSearchArea area;
  final String query;
}

/// Public marketplace information returned by the lender directory.
///
/// Private contact details and precise addresses deliberately do not belong in
/// this model. They can be shared only after the borrower and lender connect.
class NearbyLender {
  const NearbyLender({
    required this.id,
    required this.displayName,
    required this.locationLabel,
    this.loanRangeLabel,
    this.verificationLabel,
    this.categories = const [],
    this.publicDescription = '',
  });

  final String id;
  final String displayName;
  final String locationLabel;
  final String? loanRangeLabel;
  final String? verificationLabel;
  final List<String> categories;
  final String publicDescription;
}

typedef NearbyLenderSearch =
    Future<List<NearbyLender>> Function(LenderSearchRequest request);

class FindLenderScreen extends StatefulWidget {
  const FindLenderScreen({this.search, this.onLenderSelected, super.key});

  /// Tests and alternate deployments may override the production directory.
  final NearbyLenderSearch? search;
  final ValueChanged<NearbyLender>? onLenderSelected;

  @override
  State<FindLenderScreen> createState() => _FindLenderScreenState();
}

class _FindLenderScreenState extends State<FindLenderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _queryController = TextEditingController();

  LenderSearchArea _area = LenderSearchArea.locality;
  List<NearbyLender>? _results;
  String? _error;
  bool _isSearching = false;
  int _searchGeneration = 0;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _selectArea(LenderSearchArea area) {
    if (_area == area) return;
    setState(() {
      _area = area;
      _results = null;
      _error = null;
    });
    _formKey.currentState?.reset();
  }

  String get _fieldLabel => switch (_area) {
    LenderSearchArea.locality => 'Locality or neighbourhood'.tr(),
    LenderSearchArea.city => 'City'.tr(),
    LenderSearchArea.pincode => 'Pincode or postal code'.tr(),
  };

  String get _fieldHint => switch (_area) {
    LenderSearchArea.locality => 'For example, Indiranagar'.tr(),
    LenderSearchArea.city => 'For example, Bengaluru'.tr(),
    LenderSearchArea.pincode => 'For example, 560038'.tr(),
  };

  String? _validateQuery(String? value) {
    final query = value?.trim() ?? '';
    if (query.isEmpty) {
      return 'Enter an area to search'.tr();
    }
    if (_area == LenderSearchArea.pincode) {
      final valid = RegExp(r'^[A-Za-z0-9][A-Za-z0-9 -]{1,10}[A-Za-z0-9]$');
      if (!valid.hasMatch(query) || !RegExp(r'\d').hasMatch(query)) {
        return 'Enter a valid pincode or postal code'.tr();
      }
    } else if (query.length < 2) {
      return 'Enter at least 2 characters'.tr();
    }
    return null;
  }

  Future<void> _search() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final generation = ++_searchGeneration;
    final request = LenderSearchRequest(
      area: _area,
      query: _queryController.text.trim(),
    );
    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final results = await (widget.search ?? _searchPublicDirectory)(request);
      if (!mounted || generation != _searchGeneration) return;
      setState(() => _results = results);
    } catch (_) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _results = null;
        _error = 'Lenders could not be loaded. Please try again.'.tr();
      });
    } finally {
      if (mounted && generation == _searchGeneration) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<List<NearbyLender>> _searchPublicDirectory(
    LenderSearchRequest request,
  ) async {
    final client = activeAuthClient;
    if (client == null) {
      throw StateError('Authentication is unavailable');
    }
    final result = await client.searchPublicLenders(
      area: switch (request.area) {
        LenderSearchArea.locality => 1,
        LenderSearchArea.city => 2,
        LenderSearchArea.pincode => 3,
      },
      query: request.query,
    );
    return result.lenders.map(_nearbyLender).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Find lenders'.tr())),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                const _SearchIntroduction(),
                const SizedBox(height: 24),
                Text(
                  'Search within'.tr(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _AreaChoice(
                      key: const Key('area-locality'),
                      icon: Icons.near_me_outlined,
                      label: 'Locality'.tr(),
                      selected: _area == LenderSearchArea.locality,
                      onSelected: () => _selectArea(LenderSearchArea.locality),
                    ),
                    _AreaChoice(
                      key: const Key('area-city'),
                      icon: Icons.location_city_outlined,
                      label: 'City'.tr(),
                      selected: _area == LenderSearchArea.city,
                      onSelected: () => _selectArea(LenderSearchArea.city),
                    ),
                    _AreaChoice(
                      key: const Key('area-pincode'),
                      icon: Icons.pin_drop_outlined,
                      label: 'Pincode'.tr(),
                      selected: _area == LenderSearchArea.pincode,
                      onSelected: () => _selectArea(LenderSearchArea.pincode),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Form(
                  key: _formKey,
                  child: TextFormField(
                    key: const Key('lender-area-query'),
                    controller: _queryController,
                    enabled: !_isSearching,
                    textInputAction: TextInputAction.search,
                    keyboardType: _area == LenderSearchArea.pincode
                        ? TextInputType.text
                        : TextInputType.streetAddress,
                    autofillHints: _area == LenderSearchArea.pincode
                        ? const [AutofillHints.postalCode]
                        : const [AutofillHints.addressCity],
                    decoration: InputDecoration(
                      labelText: _fieldLabel,
                      hintText: _fieldHint,
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _queryController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear'.tr(),
                              onPressed: () {
                                _queryController.clear();
                                setState(() {
                                  _results = null;
                                  _error = null;
                                });
                              },
                              icon: const Icon(Icons.clear_rounded),
                            ),
                    ),
                    validator: _validateQuery,
                    onChanged: (_) => setState(() {}),
                    onFieldSubmitted: (_) => _isSearching ? null : _search(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('search-lenders'),
                  onPressed: _isSearching ? null : _search,
                  icon: _isSearching
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.travel_explore_rounded),
                  label: Text(
                    _isSearching ? 'Searching…'.tr() : 'Search lenders'.tr(),
                  ),
                ),
                const SizedBox(height: 24),
                _SearchResults(
                  results: _results,
                  error: _error,
                  onLenderSelected:
                      widget.onLenderSelected ??
                      (lender) async {
                        final blockedId = await Navigator.of(context)
                            .push<String>(
                              MaterialPageRoute(
                                builder: (_) =>
                                    PublicLenderProfileScreen(lender: lender),
                              ),
                            );
                        if (blockedId != null && mounted) {
                          setState(
                            () => _results = _results
                                ?.where((item) => item.id != blockedId)
                                .toList(growable: false),
                          );
                        }
                      },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

NearbyLender _nearbyLender(network.PublicLender lender) => NearbyLender(
  id: lender.id,
  displayName: lender.displayName,
  locationLabel: [
    lender.locality,
    lender.city,
  ].where((value) => value.isNotEmpty).join(', '),
  loanRangeLabel:
      '${_minorAmount(lender.minimumLoanMinor, lender.currency, lender.currencyScale)}–'
      '${_minorAmount(lender.maximumLoanMinor, lender.currency, lender.currencyScale)}',
  verificationLabel: switch (lender.verificationLevel) {
    'phone_verified' => 'Phone verified'.tr(),
    'identity_verified' => 'Identity verified'.tr(),
    'business_verified' => 'Business verified'.tr(),
    _ => null,
  },
  categories: lender.categories,
  publicDescription: lender.publicDescription,
);

String _minorAmount(Object value, String currency, int scale) {
  final minor = BigInt.parse(value.toString());
  final divisor = BigInt.from(10).pow(scale);
  final whole = minor ~/ divisor;
  final fraction = (minor % divisor).abs();
  final decimal = scale == 0
      ? whole.toString()
      : '${whole.toString()}.${fraction.toString().padLeft(scale, '0')}';
  return '$currency $decimal';
}

class PublicLenderProfileScreen extends StatefulWidget {
  const PublicLenderProfileScreen({required this.lender, super.key});

  final NearbyLender lender;

  @override
  State<PublicLenderProfileScreen> createState() =>
      _PublicLenderProfileScreenState();
}

class _PublicLenderProfileScreenState extends State<PublicLenderProfileScreen> {
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final lender = widget.lender;
    return Scaffold(
      appBar: AppBar(title: Text('Lender profile'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CircleAvatar(
            radius: 36,
            child: Text(
              lender.displayName.isEmpty
                  ? '?'
                  : lender.displayName.characters.first.toUpperCase(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            lender.displayName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(lender.locationLabel, textAlign: TextAlign.center),
          if (lender.verificationLabel case final verification?) ...[
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.verified_outlined),
              title: Text(verification),
              subtitle: Text(
                'Verification applies only to the stated attribute and is not a safety guarantee.'
                    .tr(),
              ),
            ),
          ],
          if (lender.loanRangeLabel case final range?)
            ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: Text('Loan range'.tr()),
              subtitle: Text(range),
            ),
          if (lender.publicDescription.trim().isNotEmpty)
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: Text('About'.tr()),
              subtitle: Text(lender.publicDescription),
            ),
          if (lender.categories.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in lender.categories)
                  Chip(label: Text(category)),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'LoanX helps you discover lenders. It does not guarantee a lender or approve, disburse, or collect a loan.'
                .tr(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _submitting ? null : _report,
            icon: const Icon(Icons.flag_outlined),
            label: Text('Report profile'.tr()),
          ),
          TextButton.icon(
            onPressed: _submitting ? null : _block,
            icon: const Icon(Icons.block_outlined),
            label: Text('Block lender'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _report() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Report profile'.tr()),
        content: TextField(
          controller: controller,
          maxLength: 1000,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(
            labelText: 'Reason'.tr(),
            helperText: 'Enter at least 10 characters'.tr(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel'.tr()),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.length >= 10) Navigator.pop(dialogContext, value);
            },
            child: Text('Submit report'.tr()),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) return;
    await _perform(
      () => activeAuthClient!.reportPublicLender(widget.lender.id, reason),
      success: 'Report submitted'.tr(),
    );
  }

  Future<void> _block() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Block lender?'.tr()),
        content: Text(
          'This profile will no longer appear in your searches.'.tr(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Block'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final succeeded = await _perform(
      () => activeAuthClient!.blockPublicLender(widget.lender.id),
      success: 'Lender blocked'.tr(),
    );
    if (succeeded && mounted) Navigator.pop(context, widget.lender.id);
  }

  Future<bool> _perform(
    Future<void> Function() action, {
    required String success,
  }) async {
    if (activeAuthClient == null) return false;
    setState(() => _submitting = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(success)));
      }
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action could not be completed'.tr())),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _SearchIntroduction extends StatelessWidget {
  const _SearchIntroduction();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.handshake_outlined, size: 32, color: colors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Discover lenders near you'.tr(),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Search public lender profiles by an area you choose. Your precise location is never shared.'
                      .tr(),
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AreaChoice extends StatelessWidget {
  const _AreaChoice({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.results,
    required this.error,
    required this.onLenderSelected,
  });

  final List<NearbyLender>? results;
  final String? error;
  final ValueChanged<NearbyLender>? onLenderSelected;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return _ResultMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Search unavailable'.tr(),
        message: error!,
      );
    }
    if (results == null) {
      return _ResultMessage(
        icon: Icons.manage_search_rounded,
        title: 'Choose where to search'.tr(),
        message:
            'Select a locality, city, or pincode to find public lender profiles.'
                .tr(),
      );
    }
    if (results!.isEmpty) {
      return _ResultMessage(
        icon: Icons.location_off_outlined,
        title: 'No lenders found'.tr(),
        message:
            'No public lender profiles are available in this area yet. Try a nearby city or locality.'
                .tr(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lenders (${results!.length})',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        for (final lender in results!) ...[
          _LenderCard(
            lender: lender,
            onTap: onLenderSelected == null
                ? null
                : () => onLenderSelected!(lender),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ResultMessage extends StatelessWidget {
  const _ResultMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(icon, size: 42, color: colors.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _LenderCard extends StatelessWidget {
  const _LenderCard({required this.lender, required this.onTap});

  final NearbyLender lender;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    child: Text(
                      lender.displayName.isEmpty
                          ? '?'
                          : lender.displayName.characters.first.toUpperCase(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lender.displayName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          lender.locationLabel,
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (lender.verificationLabel case final label?)
                    Tooltip(
                      message:
                          'Verification applies only to the stated attribute and is not a safety guarantee.'
                              .tr(),
                      child: Chip(
                        avatar: const Icon(Icons.verified_outlined, size: 16),
                        label: Text(label),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
              if (lender.loanRangeLabel case final range?) ...[
                const SizedBox(height: 12),
                Text('${'Loan range'.tr()}: $range'),
              ],
              if (lender.categories.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final category in lender.categories)
                      Chip(
                        label: Text(category),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
              if (onTap != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: onTap,
                    child: Text('View profile'.tr()),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
