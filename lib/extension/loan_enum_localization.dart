import 'package:easy_localization/easy_localization.dart';
import 'package:loanx/l10n/locale_keys.g.dart';
import 'package:loanx/model/loan.dart';

extension InterestFrequencyLocalization on InterestFrequency {
  String get localizedLabel => switch (this) {
    InterestFrequency.monthly => LocaleKeys.monthly.tr(),
    InterestFrequency.quarterly => LocaleKeys.quarterly.tr(),
    InterestFrequency.halfYearly => LocaleKeys.halfYearly.tr(),
    InterestFrequency.yearly => LocaleKeys.yearly.tr(),
  };
}

extension InterestTypeLocalization on InterestType {
  String get localizedLabel => switch (this) {
    InterestType.simple => LocaleKeys.simple.tr(),
    InterestType.compound => LocaleKeys.compound.tr(),
  };
}
