import 'package:flutter/widgets.dart';

/// Returns an `intl` locale with formatting data for the selected app locale.
///
/// Some app languages are not included in the `intl` package. Those languages
/// use formatting conventions from the closest supported locale while their
/// translated app strings remain unchanged.
String intlLocaleName(Locale locale) => switch (locale.languageCode) {
  'hi' || 'bho' || 'bra' || 'mai' || 'mwr' => 'hi_IN',
  'bn' || 'mni' => 'bn_IN',
  'as' => 'as_IN',
  'gu' => 'gu_IN',
  'kn' => 'kn_IN',
  'ml' => 'ml_IN',
  'mr' => 'mr_IN',
  'ne' => 'ne_IN',
  'or' => 'or_IN',
  'pa' => 'pa_IN',
  'ta' => 'ta_IN',
  'te' => 'te_IN',
  'ur' => 'ur_IN',
  _ => 'en_IN',
};
