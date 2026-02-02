// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get loan => 'ঋণ';

  @override
  String get loans => 'ঋণ';

  @override
  String get loanx => 'ঋণ-এক্স';

  @override
  String get simpleInterest => 'সরল সুদ';

  @override
  String get compoundInterest => 'চক্রবৃদ্ধি সুদ';

  @override
  String get addLoan => 'ঋণ যোগ করুন';

  @override
  String get addMortgage => 'বন্ধকী যোগ করুন';

  @override
  String get addMortgageMaterial => 'বন্ধকী উপাদান যোগ করুন';

  @override
  String get addFamilyRelation => 'পারিবারিক সম্পর্ক যোগ করুন';

  @override
  String get editLoan => 'ঋণ সম্পাদনা করুন';

  @override
  String get editMortgage => 'Edit Mortgage';

  @override
  String get editMortgageMaterial => 'Edit Mortgage Material';

  @override
  String get editFamilyRelation => 'Edit Family Relation';

  @override
  String get deleteLoan => 'Delete Loan';

  @override
  String get deleteMortgage => 'Delete Mortgage';

  @override
  String get deleteMortgageMaterial => 'Delete Mortgage Material';

  @override
  String get deleteFamilyRelation => 'Delete Family Relation';

  @override
  String get deleteMultipleLoan => 'Delete Multiple Loan';

  @override
  String get deleteMultipleMortgage => 'Delete Multiple Mortgage';

  @override
  String get deleteMultipleMortgageMaterial =>
      'Delete Multiple Mortgage Material';

  @override
  String get deleteMultipleFamilyRelation => 'Delete Multiple Family Relation';

  @override
  String get confirmDelete =>
      'Are you sure you want to delete this loan record?';

  @override
  String get confirmDeleteMultiple =>
      'Are you sure you want to delete these loan records?';

  @override
  String get confirmDeleteMortgage =>
      'Are you sure you want to delete this mortgage record?';

  @override
  String get confirmDeleteMultipleMortgage =>
      'Are you sure you want to delete these mortgage records?';

  @override
  String get confirmDeleteMortgageMaterial =>
      'Are you sure you want to delete this mortgage material record?';

  @override
  String get confirmDeleteMultipleMortgageMaterial =>
      'Are you sure you want to delete these mortgage material records?';

  @override
  String get confirmDeleteFamilyRelation =>
      'Are you sure you want to delete this family relation record?';

  @override
  String get confirmDeleteMultipleFamilyRelation =>
      'Are you sure you want to delete these family relation records?';
}
