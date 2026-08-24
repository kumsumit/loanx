import 'package:loanx/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

const appLanguages = <({Locale locale, String nativeName})>[
  (locale: Locale('as'), nativeName: 'অসমীয়া'),
  (locale: Locale('bho'), nativeName: 'भोजपुरी'),
  (locale: Locale('en'), nativeName: 'English'),
  (locale: Locale('bn'), nativeName: 'বাংলা'),
  (locale: Locale('bra'), nativeName: 'ब्रज भाषा'),
  (locale: Locale('gu'), nativeName: 'ગુજરાતી'),
  (locale: Locale('hi'), nativeName: 'हिन्दी'),
  (locale: Locale('kn'), nativeName: 'ಕನ್ನಡ'),
  (locale: Locale('mai'), nativeName: 'मैथिली'),
  (locale: Locale('ml'), nativeName: 'മലയാളം'),
  (locale: Locale('mni'), nativeName: 'মৈতৈলোন্'),
  (locale: Locale('mr'), nativeName: 'मराठी'),
  (locale: Locale('mwr'), nativeName: 'मारवाड़ी'),
  (locale: Locale('ne'), nativeName: 'नेपाली'),
  (locale: Locale('or'), nativeName: 'ଓଡ଼ିଆ'),
  (locale: Locale('pa'), nativeName: 'ਪੰਜਾਬੀ'),
  (locale: Locale('ta'), nativeName: 'தமிழ்'),
  (locale: Locale('te'), nativeName: 'తెలుగు'),
  (locale: Locale('ur'), nativeName: 'اردو'),
];

String appLanguageName(Locale locale) => appLanguages
    .firstWhere(
      (language) => language.locale.languageCode == locale.languageCode,
      orElse: () => appLanguages.first,
    )
    .nativeName;

Future<void> showAppLanguagePicker(BuildContext context) async {
  final selectedLocale = await showDialog<Locale>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(LocaleKeys.chooseAppLanguage.tr()),
      contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      content: SingleChildScrollView(
        child: RadioGroup<String>(
          groupValue: context.locale.languageCode,
          onChanged: (languageCode) {
            if (languageCode == null) return;
            Navigator.of(dialogContext).pop(Locale(languageCode));
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final language in appLanguages)
                RadioListTile<String>(
                  value: language.locale.languageCode,
                  title: Text(language.nativeName),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(LocaleKeys.cancel.tr()),
        ),
      ],
    ),
  );
  if (selectedLocale != null && context.mounted) {
    await context.setLocale(selectedLocale);
  }
}

class StartupLanguageScreen extends StatelessWidget {
  const StartupLanguageScreen({required this.onLanguageSelected, super.key});

  final VoidCallback onLanguageSelected;

  Future<void> _selectLanguage(BuildContext context, Locale locale) async {
    await context.setLocale(locale);
    if (!context.mounted) return;
    onLanguageSelected();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.translate_rounded,
                      size: 44,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    LocaleKeys.chooseAppLanguage.tr(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    LocaleKeys.youCanChangeThisLaterFromAppPreferences.tr(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  for (final language in appLanguages) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () =>
                            _selectLanguage(context, language.locale),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(language.nativeName),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
