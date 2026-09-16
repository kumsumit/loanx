import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:loanx/db/app_settings.dart';
import 'package:loanx/service/auth_client.dart';
import 'package:loanx/service/currency_presentation.dart';
import 'package:loanx/features/auth/connect_account_screen.dart';

/// Lenders opt in to a deliberately public directory record. Never populate
/// contact details or private loan data from a lender's local workspace.
class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({super.key});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _locality = TextEditingController();
  final _city = TextEditingController();
  final _postal = TextEditingController();
  final _min = TextEditingController();
  final _max = TextEditingController();
  final _categories = TextEditingController();
  final _description = TextEditingController();
  late String _currency = CurrencyPresentation.defaultCurrency;
  late String _country = AppSettings.getVerifiedPhoneCountryCode();
  bool _published = false;
  bool _available = true;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await activeAuthClient!.myLenderProfile();
      if (!mounted) return;
      final profile = value.profile;
      if (profile != null) {
        _name.text = profile.displayName;
        _locality.text = profile.locality;
        _city.text = profile.city;
        _postal.text = profile.postalCode;
        _currency = profile.currency.trim();
        _country = profile.countryCode.trim();
        _min.text = _minorAmount(
          profile.minimumLoanMinor,
          profile.currencyScale,
        );
        _max.text = _minorAmount(
          profile.maximumLoanMinor,
          profile.currencyScale,
        );
        _categories.text = profile.categories.join(', ');
        _description.text = profile.publicDescription;
        _available = profile.available;
        _published = value.published;
      }
      setState(() => _loading = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Public profile could not be loaded. Connect and try again.'
              .tr();
        });
      }
    }
  }

  static String _minorAmount(Object value, int scale) {
    final units = BigInt.parse(value.toString());
    final digits = units.toString().padLeft(scale + 1, '0');
    if (scale == 0) return digits;
    return '${digits.substring(0, digits.length - scale)}.${digits.substring(digits.length - scale)}';
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _locality,
      _city,
      _postal,
      _min,
      _max,
      _categories,
      _description,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) {
    final text = value?.trim() ?? '';
    return text.length < 2 || text.length > 120
        ? 'Enter 2–120 characters'.tr()
        : null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await activeAuthClient!.publishPublicLender(
        displayName: _name.text.trim(),
        locality: _locality.text.trim(),
        city: _city.text.trim(),
        postalCode: _postal.text.trim(),
        countryCode: _country,
        minimumLoan: _min.text.trim(),
        maximumLoan: _max.text.trim(),
        currency: _currency,
        currencyScale: CurrencyPresentation.fractionDigits(_currency),
        categories: _categories.text
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(),
        description: _description.text.trim(),
        available: _available,
        published: _published,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Public profile saved'.tr())));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Public profile could not be saved'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Public lender profile'.tr())),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    final linked = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => const ConnectAccountScreen(),
                      ),
                    );
                    if (linked == true && mounted) {
                      setState(() {
                        _loading = true;
                        _error = null;
                      });
                      await _load();
                    }
                  },
                  child: Text('Connect account'.tr()),
                ),
              ],
            ),
          )
        : Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Only the details you enter here are published. Your phone, address and private loans stay private.'
                      .tr(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _name,
                  maxLength: 120,
                  decoration: InputDecoration(labelText: 'Public name'.tr()),
                  validator: _required,
                ),
                TextFormField(
                  controller: _locality,
                  maxLength: 120,
                  decoration: InputDecoration(labelText: 'Locality'.tr()),
                  validator: _required,
                ),
                TextFormField(
                  controller: _city,
                  maxLength: 120,
                  decoration: InputDecoration(labelText: 'City'.tr()),
                  validator: _required,
                ),
                TextFormField(
                  controller: _postal,
                  maxLength: 12,
                  decoration: InputDecoration(
                    labelText: 'Pincode or postal code'.tr(),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.length < 3 ||
                        text.length > 12 ||
                        !RegExp(r'\d').hasMatch(text) ||
                        !RegExp(r'^[A-Za-z0-9 -]+$').hasMatch(text)) {
                      return 'Enter a valid pincode or postal code'.tr();
                    }
                    return null;
                  },
                ),
                Text('${'Currency'.tr()}: $_currency · $_country'),
                TextFormField(
                  controller: _min,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Minimum loan amount'.tr(),
                  ),
                  validator: (value) => _amountValidator(value),
                ),
                TextFormField(
                  controller: _max,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Maximum loan amount'.tr(),
                  ),
                  validator: (value) => _amountValidator(value),
                ),
                TextFormField(
                  controller: _categories,
                  maxLength: 400,
                  decoration: InputDecoration(
                    labelText: 'Loan categories, separated by commas'.tr(),
                  ),
                ),
                TextFormField(
                  controller: _description,
                  maxLength: 1000,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Public description'.tr(),
                  ),
                ),
                SwitchListTile(
                  title: Text('Accepting enquiries'.tr()),
                  value: _available,
                  onChanged: (value) => setState(() => _available = value),
                ),
                SwitchListTile(
                  title: Text('Publish in lender search'.tr()),
                  subtitle: Text(
                    'You can unpublish this profile at any time.'.tr(),
                  ),
                  value: _published,
                  onChanged: (value) => setState(() => _published = value),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…'.tr() : 'Save'.tr()),
                ),
              ],
            ),
          ),
  );

  String? _amountValidator(String? value) {
    final text = value?.trim() ?? '';
    if (!RegExp(r'^\d+(?:\.\d+)?$').hasMatch(text) || text.length > 20) {
      return 'Enter a valid amount'.tr();
    }
    final fraction = text.split('.');
    if (fraction.length > 1 &&
        fraction.last.length > CurrencyPresentation.fractionDigits(_currency)) {
      return 'Enter a valid amount'.tr();
    }
    return null;
  }
}
