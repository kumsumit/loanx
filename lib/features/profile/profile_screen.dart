import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:loanx/db/app_settings.dart';
import 'package:loanx/domain/country_catalog.dart';
import 'package:loanx/service/auth_client.dart';
import 'package:loanx/widget/phone.dart';

/// Private, optional profile information for the current local workspace.
///
/// This is deliberately not a marketplace profile and does not publish or
/// synchronize any field. A person can use the lender and borrower experiences
/// without filling in any of these fields.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({required this.experience, super.key});

  final ProfileExperience experience;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

enum ProfileExperience { lender, borrower }

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers = {
    'Full name': TextEditingController(text: AppSettings.getProfileFullName()),
    'Email': TextEditingController(text: AppSettings.getProfileEmail()),
    'Alternate phone': TextEditingController(
      text: AppSettings.getProfileAlternatePhone(),
    ),
    'Business or lending name': TextEditingController(
      text: AppSettings.getProfileBusinessName(),
    ),
    'Occupation': TextEditingController(
      text: AppSettings.getProfileOccupation(),
    ),
    'Address': TextEditingController(text: AppSettings.getProfileAddress()),
    'Locality': TextEditingController(text: AppSettings.getProfileLocality()),
    'City': TextEditingController(text: AppSettings.getProfileCity()),
    'State / region': TextEditingController(
      text: AppSettings.getProfileState(),
    ),
    'Postal code': TextEditingController(
      text: AppSettings.getProfilePostalCode(),
    ),
    'Country': TextEditingController(text: AppSettings.getProfileCountry()),
    'About me': TextEditingController(text: AppSettings.getProfileAbout()),
  };
  bool _saving = false;
  late PhoneNumber _alternatePhone = _initialAlternatePhone();
  late bool _borrowerLookupEnabled =
      AppSettings.getBorrowerProfileLookupEnabled();

  PhoneNumber _initialAlternatePhone() {
    final stored = AppSettings.getProfileAlternatePhone();
    final digits = stored.replaceAll(RegExp(r'[^0-9]'), '');
    if (stored.trim().startsWith('+')) {
      final countries = [...CountryCatalog.all]
        ..sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));
      for (final country in countries) {
        final dialCode = country.dialCode.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.startsWith(dialCode) && digits.length > dialCode.length) {
          return PhoneNumber(
            isoCode: country.code,
            nsn: digits.substring(dialCode.length),
          );
        }
      }
    }

    // Legacy profile numbers were saved as free-form text. Retain a leading
    // Indian country code when present; all other ambiguous legacy values
    // default to IN until the user chooses their country in the input.
    final nsn = digits.length == 12 && digits.startsWith('91')
        ? digits.substring(2)
        : digits;
    return PhoneNumber(isoCode: 'IN', nsn: nsn);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int get _completedFields => _controllers.values
      .where((controller) => controller.text.trim().isNotEmpty)
      .length;

  String? _emailValidator(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return null;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address'.tr();
    }
    return null;
  }

  String? _postalValidator(String? value) {
    final postal = value?.trim() ?? '';
    if (postal.isEmpty) return null;
    if (!RegExp(r'^[A-Za-z0-9 -]{3,12}$').hasMatch(postal)) {
      return 'Enter a valid postal code'.tr();
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_controllers['Alternate phone']!.text.trim().isNotEmpty &&
        !_alternatePhone.isValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enter a valid phone number'.tr())),
      );
      return;
    }
    setState(() => _saving = true);
    if (widget.experience == ProfileExperience.borrower &&
        _borrowerLookupEnabled &&
        !AuthClient.hasServerConfiguration) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Connect your account before enabling phone lookup'.tr(),
          ),
        ),
      );
      return;
    }
    AppSettings.putProfileFullName(_value('Full name'));
    AppSettings.putProfileEmail(_value('Email'));
    AppSettings.putProfileAlternatePhone(
      _alternatePhone.nsn.isEmpty
          ? ''
          : CountryCatalog.e164(_alternatePhone.isoCode, _alternatePhone.nsn),
    );
    AppSettings.putProfileBusinessName(_value('Business or lending name'));
    AppSettings.putProfileOccupation(_value('Occupation'));
    AppSettings.putProfileAddress(_value('Address'));
    AppSettings.putProfileLocality(_value('Locality'));
    AppSettings.putProfileCity(_value('City'));
    AppSettings.putProfileState(_value('State / region'));
    AppSettings.putProfilePostalCode(_value('Postal code'));
    AppSettings.putProfileCountry(_value('Country'));
    AppSettings.putProfileAbout(_value('About me'));
    AppSettings.putBorrowerProfileLookupEnabled(_borrowerLookupEnabled);
    await AppSettings.flush();
    try {
      if (widget.experience == ProfileExperience.borrower &&
          AuthClient.hasServerConfiguration) {
        final auth = activeAuthClient ?? AuthClient();
        if (!await auth.restoreSession()) {
          throw StateError('Sign in is required to update phone lookup');
        }
        await auth.saveBorrowerLookupProfile(
          searchableByPhone: _borrowerLookupEnabled,
          displayName: _value('Full name'),
          address: _value('Address'),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update phone lookup: $error'.tr())),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Profile saved on this device'.tr())),
    );
  }

  String _value(String field) => _controllers[field]!.text.trim();

  @override
  Widget build(BuildContext context) {
    final completed = _completedFields;
    final label = widget.experience == ProfileExperience.lender
        ? 'Lender profile'.tr()
        : 'Borrower profile'.tr();
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            32 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          children: [
            LinearProgressIndicator(value: completed / _controllers.length),
            const SizedBox(height: 6),
            Text(
              'profileDetailsAdded'.tr(
                namedArgs: {
                  'completed': '$completed',
                  'total': '${_controllers.length}',
                },
              ),
            ),
            if (widget.experience == ProfileExperience.borrower) ...[
              const SizedBox(height: 16),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _borrowerLookupEnabled,
                onChanged: (value) =>
                    setState(() => _borrowerLookupEnabled = value),
                title: Text('Allow lenders to find this profile by phone'.tr()),
                subtitle: Text(
                  'Only your name and address are shared after an authenticated lender enters a valid phone number. You can turn this off at any time.'
                      .tr(),
                ),
              ),
            ],
            const SizedBox(height: 24),
            _field('Full name', maxLength: 120),
            _field(
              'Email',
              keyboardType: TextInputType.emailAddress,
              validator: _emailValidator,
              maxLength: 254,
            ),
            PhoneWidget(
              labelText: 'Alternate phone'.tr(),
              hint: 'Alternate phone'.tr(),
              initialValue: _alternatePhone,
              textEditingController: _controllers['Alternate phone'],
              allowEmpty: true,
              onChanged: (phone) => setState(() => _alternatePhone = phone),
            ),
            const SizedBox(height: 8),
            Text(
              'Work details (optional)'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            _field('Business or lending name', maxLength: 120),
            _field('Occupation', maxLength: 120),
            const SizedBox(height: 8),
            Text(
              'Address details (optional)'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            _field('Address', maxLines: 2, maxLength: 300),
            _field('Locality', maxLength: 120),
            _field('City', maxLength: 120),
            _field('State / region', maxLength: 120),
            _field('Postal code', validator: _postalValidator, maxLength: 12),
            _field('Country', maxLength: 120),
            const SizedBox(height: 8),
            _field('About me', maxLines: 4, maxLength: 500),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving'.tr() : 'Save profile'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    required int maxLength,
  }) => TextFormField(
    controller: _controllers[label],
    keyboardType: keyboardType,
    validator: validator,
    maxLines: maxLines,
    maxLength: maxLength,
    textCapitalization: TextCapitalization.words,
    onChanged: (_) => setState(() {}),
    decoration: InputDecoration(labelText: label.tr()),
  );
}
