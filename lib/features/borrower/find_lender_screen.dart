import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

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
  });

  final String id;
  final String displayName;
  final String locationLabel;
  final String? loanRangeLabel;
  final String? verificationLabel;
  final List<String> categories;
}

typedef NearbyLenderSearch =
    Future<List<NearbyLender>> Function(LenderSearchRequest request);

class FindLenderScreen extends StatefulWidget {
  const FindLenderScreen({this.search, this.onLenderSelected, super.key});

  /// The connected marketplace supplies this callback. Until it is connected,
  /// searches safely return no public profiles instead of showing demo data.
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
      final results =
          await (widget.search?.call(request) ??
              Future<List<NearbyLender>>.value(const []));
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
                  onLenderSelected: widget.onLenderSelected,
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
