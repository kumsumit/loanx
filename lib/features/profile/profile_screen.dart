import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:loanx/db/app_settings.dart';

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

  String? _phoneValidator(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return null;
    if (!RegExp(r'^[0-9+() -]{5,24}$').hasMatch(phone)) {
      return 'Enter a valid phone number'.tr();
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
    setState(() => _saving = true);
    AppSettings.putProfileFullName(_value('Full name'));
    AppSettings.putProfileEmail(_value('Email'));
    AppSettings.putProfileAlternatePhone(_value('Alternate phone'));
    AppSettings.putProfileBusinessName(_value('Business or lending name'));
    AppSettings.putProfileOccupation(_value('Occupation'));
    AppSettings.putProfileAddress(_value('Address'));
    AppSettings.putProfileLocality(_value('Locality'));
    AppSettings.putProfileCity(_value('City'));
    AppSettings.putProfileState(_value('State / region'));
    AppSettings.putProfilePostalCode(_value('Postal code'));
    AppSettings.putProfileCountry(_value('Country'));
    AppSettings.putProfileAbout(_value('About me'));
    await AppSettings.flush();
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
            Text(
              'Your profile is optional. Loan management works even if you leave every field blank.'
                  .tr(),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: completed / _controllers.length),
            const SizedBox(height: 6),
            Text('$completed of ${_controllers.length} details added'.tr()),
            const SizedBox(height: 24),
            _field('Full name', maxLength: 120),
            _field(
              'Email',
              keyboardType: TextInputType.emailAddress,
              validator: _emailValidator,
              maxLength: 254,
            ),
            _field(
              'Alternate phone',
              keyboardType: TextInputType.phone,
              validator: _phoneValidator,
              maxLength: 24,
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
