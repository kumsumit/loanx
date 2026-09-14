import 'package:flutter/material.dart';

typedef AppLanguage = ({Locale locale, String nativeName, String englishName});

/// Single source of truth for the languages supported by the app.
const appLanguages = <AppLanguage>[
  (locale: Locale('as'), nativeName: 'অসমীয়া', englishName: 'Assamese'),
  (locale: Locale('bho'), nativeName: 'भोजपुरी', englishName: 'Bhojpuri'),
  (locale: Locale('en'), nativeName: 'English', englishName: 'English'),
  (locale: Locale('bn'), nativeName: 'বাংলা', englishName: 'Bengali'),
  (locale: Locale('bra'), nativeName: 'ब्रज भाषा', englishName: 'Braj'),
  (locale: Locale('gu'), nativeName: 'ગુજરાતી', englishName: 'Gujarati'),
  (locale: Locale('hi'), nativeName: 'हिन्दी', englishName: 'Hindi'),
  (locale: Locale('kn'), nativeName: 'ಕನ್ನಡ', englishName: 'Kannada'),
  (locale: Locale('mai'), nativeName: 'मैथिली', englishName: 'Maithili'),
  (locale: Locale('ml'), nativeName: 'മലയാളം', englishName: 'Malayalam'),
  (locale: Locale('mni'), nativeName: 'মৈতৈলোন্', englishName: 'Manipuri'),
  (locale: Locale('mr'), nativeName: 'मराठी', englishName: 'Marathi'),
  (locale: Locale('mwr'), nativeName: 'मारवाड़ी', englishName: 'Marwari'),
  (locale: Locale('ne'), nativeName: 'नेपाली', englishName: 'Nepali'),
  (locale: Locale('or'), nativeName: 'ଓଡ଼ିଆ', englishName: 'Odia'),
  (locale: Locale('pa'), nativeName: 'ਪੰਜਾਬੀ', englishName: 'Punjabi'),
  (locale: Locale('ta'), nativeName: 'தமிழ்', englishName: 'Tamil'),
  (locale: Locale('te'), nativeName: 'తెలుగు', englishName: 'Telugu'),
  (locale: Locale('ur'), nativeName: 'اردو', englishName: 'Urdu'),
];

final appSupportedLocales = <Locale>[
  for (final language in appLanguages) language.locale,
];
const appDefaultLocale = Locale('en');

String appLanguageName(Locale locale) => appLanguages
    .firstWhere((language) => language.locale.languageCode == locale.languageCode,
        orElse: () => appLanguages.first)
    .nativeName;
