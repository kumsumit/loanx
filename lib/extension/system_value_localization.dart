import 'package:easy_localization/easy_localization.dart';
import 'package:loanx/l10n/locale_keys.g.dart';
import 'package:loanx/model/family_relation.dart';
import 'package:loanx/model/mortgage_material.dart';
import 'package:loanx/model/weight_unit.dart';

extension FamilyRelationLocalization on FamilyRelation {
  String get localizedName => isAddedByUser == 1
      ? name
      : switch (name) {
          'Husband' => LocaleKeys.systemHusband.tr(),
          'Father' => LocaleKeys.systemFather.tr(),
          'Wife' => LocaleKeys.systemWife.tr(),
          _ => name,
        };
}

extension MortgageMaterialLocalization on MortgageMaterial {
  String get localizedName => localizedMortgageMaterialName(name);
}

String localizedMortgageMaterialName(String name) {
  return switch (name) {
    'Ring' => LocaleKeys.systemRing.tr(),
    'Anklet' => LocaleKeys.systemAnklet.tr(),
    'Bracelet' => LocaleKeys.systemBracelet.tr(),
    'Armlet' => LocaleKeys.systemArmlet.tr(),
    'Chain' => LocaleKeys.systemChain.tr(),
    'Ear-Ring' => LocaleKeys.systemEarRing.tr(),
    'Head-Locket' => LocaleKeys.systemHeadLocket.tr(),
    'Medal' => LocaleKeys.systemMedal.tr(),
    'Necklace' => LocaleKeys.systemNecklace.tr(),
    'Locket' => LocaleKeys.systemLocket.tr(),
    'Neck band' => LocaleKeys.systemNeckBand.tr(),
    // Custom material names are user content and should not be translated.
    // Match built-in names first so older/imported records that were
    // incorrectly marked as custom still follow the selected locale.
    _ => name,
  };
}

extension WeightUnitLocalization on WeightUnit {
  String get localizedName => isAddedByUser == 1
      ? name
      : switch (name) {
          'Gram' => LocaleKeys.systemGram.tr(),
          'Kilogram' => LocaleKeys.systemKilogram.tr(),
          'Milligram' => LocaleKeys.systemMilligram.tr(),
          'Tola' => LocaleKeys.systemTola.tr(),
          _ => name,
        };
}
