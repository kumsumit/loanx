import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:loanx/domain/country_catalog.dart';
import 'package:loanx/l10n/app_languages.dart';
import 'package:loanx/l10n/locale_keys.g.dart';
import 'package:loanx/service/country_resolver.dart';
import 'package:loanx/widget/language_picker.dart';
import 'package:loanx/widget/phone.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({required this.onContinue, super.key});

  final Future<String?> Function(PhoneNumber) onContinue;

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phoneController = TextEditingController();
  PhoneNumber _phoneNumber = PhoneNumber(isoCode: 'IN', nsn: '');
  bool _isValid = false;
  bool _isSubmitting = false;
  String? _error;
  String _defaultCountryCode = 'IN';
  int _phoneWidgetGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadCountryDefault();
  }

  Future<void> _loadCountryDefault() async {
    final resolution = await CountryResolver().resolve();
    if (!mounted) return;
    setState(() {
      // Do not replace a number entered while the asynchronous lookup ran.
      // `initialValue` resets the third-party widget's controller, so it must
      // never be driven from the value emitted on every keystroke.
      if (_phoneController.text.isEmpty) {
        _defaultCountryCode = resolution.countryCode;
        _phoneNumber = PhoneNumber(isoCode: resolution.countryCode, nsn: '');
        _phoneWidgetGeneration++;
      }
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _onPhoneChanged(PhoneNumber phoneNumber) {
    final isValid = phoneNumber.nsn.isNotEmpty && phoneNumber.isValid();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final isUnchanged =
          _phoneNumber.isoCode == phoneNumber.isoCode &&
          _phoneNumber.nsn == phoneNumber.nsn &&
          _isValid == isValid;
      if (isUnchanged) return;

      setState(() {
        _phoneNumber = phoneNumber;
        _isValid = isValid;
      });
    });
  }

  Future<void> _continue() async {
    if (!_isValid || _isSubmitting) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final error = await widget.onContinue(_phoneNumber);
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // `_resolution` is only the initial, best-effort device default. The phone
    // input owns subsequent country selections, so render that live value.
    final selectedCountry = CountryCatalog.byCode(_phoneNumber.isoCode);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      onPressed: () => showAppLanguagePicker(context),
                      icon: const Icon(Icons.translate_rounded, size: 20),
                      label: Text(appLanguageName(context.locale)),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Align(
                    child: Container(
                      width: 88,
                      height: 88,
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Image.asset('assets/logo.png'),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    LocaleKeys.welcomeToLoanx.tr(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    LocaleKeys.phoneLoginPrompt.tr(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 36),
                  PhoneWidget(
                    key: ValueKey(_phoneWidgetGeneration),
                    labelText: LocaleKeys.phoneNumber.tr(),
                    hint: LocaleKeys.phoneNumber.tr(),
                    // The controller owns typed text. This stays blank except
                    // when the auto-default changes before input begins.
                    initialValue: PhoneNumber(
                      isoCode: _defaultCountryCode,
                      nsn: '',
                    ),
                    textEditingController: _phoneController,
                    onChanged: _onPhoneChanged,
                    onSubmit: _continue,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Country selected: ${selectedCountry.name}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_error != null) ...[
                    _InlineError(message: _error!),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      key: const Key('send-otp'),
                      onPressed: _isValid && !_isSubmitting ? _continue : null,
                      child: _isSubmitting
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(LocaleKeys.continueAction.tr()),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    LocaleKeys.validMobileNumberHelper.tr(),
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

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: colors.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
