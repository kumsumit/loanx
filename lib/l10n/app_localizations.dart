import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
    Locale('hi'),
  ];

  /// No description provided for @loan.
  ///
  /// In en, this message translates to:
  /// **'Loan'**
  String get loan;

  /// No description provided for @loans.
  ///
  /// In en, this message translates to:
  /// **'Loans'**
  String get loans;

  /// No description provided for @loanx.
  ///
  /// In en, this message translates to:
  /// **'Loanx'**
  String get loanx;

  /// No description provided for @simpleInterest.
  ///
  /// In en, this message translates to:
  /// **'Simple Interest'**
  String get simpleInterest;

  /// No description provided for @compoundInterest.
  ///
  /// In en, this message translates to:
  /// **'Compound Interest'**
  String get compoundInterest;

  /// No description provided for @addLoan.
  ///
  /// In en, this message translates to:
  /// **'Add Loan'**
  String get addLoan;

  /// No description provided for @addMortgage.
  ///
  /// In en, this message translates to:
  /// **'Add Mortgage'**
  String get addMortgage;

  /// No description provided for @addMortgageMaterial.
  ///
  /// In en, this message translates to:
  /// **'Add Mortgage Material'**
  String get addMortgageMaterial;

  /// No description provided for @addFamilyRelation.
  ///
  /// In en, this message translates to:
  /// **'Add Family Relation'**
  String get addFamilyRelation;

  /// No description provided for @editLoan.
  ///
  /// In en, this message translates to:
  /// **'Edit Loan'**
  String get editLoan;

  /// No description provided for @editMortgage.
  ///
  /// In en, this message translates to:
  /// **'Edit Mortgage'**
  String get editMortgage;

  /// No description provided for @editMortgageMaterial.
  ///
  /// In en, this message translates to:
  /// **'Edit Mortgage Material'**
  String get editMortgageMaterial;

  /// No description provided for @editFamilyRelation.
  ///
  /// In en, this message translates to:
  /// **'Edit Family Relation'**
  String get editFamilyRelation;

  /// No description provided for @deleteLoan.
  ///
  /// In en, this message translates to:
  /// **'Delete Loan'**
  String get deleteLoan;

  /// No description provided for @deleteMortgage.
  ///
  /// In en, this message translates to:
  /// **'Delete Mortgage'**
  String get deleteMortgage;

  /// No description provided for @deleteMortgageMaterial.
  ///
  /// In en, this message translates to:
  /// **'Delete Mortgage Material'**
  String get deleteMortgageMaterial;

  /// No description provided for @deleteFamilyRelation.
  ///
  /// In en, this message translates to:
  /// **'Delete Family Relation'**
  String get deleteFamilyRelation;

  /// No description provided for @deleteMultipleLoan.
  ///
  /// In en, this message translates to:
  /// **'Delete Multiple Loan'**
  String get deleteMultipleLoan;

  /// No description provided for @deleteMultipleMortgage.
  ///
  /// In en, this message translates to:
  /// **'Delete Multiple Mortgage'**
  String get deleteMultipleMortgage;

  /// No description provided for @deleteMultipleMortgageMaterial.
  ///
  /// In en, this message translates to:
  /// **'Delete Multiple Mortgage Material'**
  String get deleteMultipleMortgageMaterial;

  /// No description provided for @deleteMultipleFamilyRelation.
  ///
  /// In en, this message translates to:
  /// **'Delete Multiple Family Relation'**
  String get deleteMultipleFamilyRelation;

  /// No description provided for @confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this loan record?'**
  String get confirmDelete;

  /// No description provided for @confirmDeleteMultiple.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete these loan records?'**
  String get confirmDeleteMultiple;

  /// No description provided for @confirmDeleteMortgage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this mortgage record?'**
  String get confirmDeleteMortgage;

  /// No description provided for @confirmDeleteMultipleMortgage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete these mortgage records?'**
  String get confirmDeleteMultipleMortgage;

  /// No description provided for @confirmDeleteMortgageMaterial.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this mortgage material record?'**
  String get confirmDeleteMortgageMaterial;

  /// No description provided for @confirmDeleteMultipleMortgageMaterial.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete these mortgage material records?'**
  String get confirmDeleteMultipleMortgageMaterial;

  /// No description provided for @confirmDeleteFamilyRelation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this family relation record?'**
  String get confirmDeleteFamilyRelation;

  /// No description provided for @confirmDeleteMultipleFamilyRelation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete these family relation records?'**
  String get confirmDeleteMultipleFamilyRelation;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bn', 'en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
