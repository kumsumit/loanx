import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:loanx/db/tostore_database.dart';
import 'package:loanx/domain/country_catalog.dart';
import 'package:loanx/model/loan.dart';

/// A lender-owned contact suggestion for a new loan form.
///
/// This deliberately searches only records belonging to [ownerId]. A valid
/// phone format is useful for matching a local contact, but is not identity
/// verification and must never be used to retrieve another user's profile.
class BorrowerPrefill {
  const BorrowerPrefill({
    required this.displayName,
    required this.address,
    required this.relativeName,
  });

  final String displayName;
  final String address;
  final String relativeName;
}

abstract final class BorrowerPrefillService {
  /// Finds the latest lender-owned borrower details for an already-valid
  /// international phone number. Returns null for no local match.
  static Future<BorrowerPrefill?> findForPhone(
    DatabaseExecutor database, {
    required String ownerId,
    required PhoneNumber phone,
  }) async {
    final target = _e164(phone.isoCode, phone.nsn);
    if (target == null) return null;

    final parties = await database.query(
      'parties',
      where: 'ownerId = ? AND status = ?',
      whereArgs: [ownerId, 'ACTIVE'],
    );
    final matchingPartyIds = <String>{};
    String displayName = '';
    for (final party in parties) {
      final partyPhone = party['phone'] as String? ?? '';
      if (!_matches(target, partyPhone, party['countryCode'] as String?)) {
        continue;
      }
      matchingPartyIds.add(party['id'] as String);
      if (displayName.isEmpty) {
        displayName = party['displayName'] as String? ?? '';
      }
    }

    final loans = await database.query(
      Loan.tableName,
      where: 'ownerId = ?',
      whereArgs: [ownerId],
      orderBy: 'dateCreated DESC, id DESC',
    );
    var address = '';
    var relativeName = '';
    for (final loan in loans) {
      final partyId = loan['borrowerPartyId'] as String?;
      final matchesParty =
          partyId != null && matchingPartyIds.contains(partyId);
      final matchesPhone = _matches(
        target,
        loan['phoneNumber'] as String? ?? '',
        null,
      );
      if (!matchesParty && !matchesPhone) continue;
      if (displayName.isEmpty) {
        displayName = loan['depositorName'] as String? ?? '';
      }
      if (address.isEmpty) address = loan['address'] as String? ?? '';
      if (relativeName.isEmpty) {
        relativeName = loan['relativeName'] as String? ?? '';
      }
      if (displayName.isNotEmpty &&
          address.isNotEmpty &&
          relativeName.isNotEmpty) {
        break;
      }
    }

    if (displayName.isEmpty && matchingPartyIds.isEmpty) return null;
    return BorrowerPrefill(
      displayName: displayName,
      address: address,
      relativeName: relativeName,
    );
  }

  static bool _matches(String target, String stored, String? countryCode) {
    if (stored.trim().isEmpty) return false;
    final normalized = _e164(countryCode, stored);
    return normalized == target;
  }

  static String? _e164(String? countryCode, String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    if (value.trim().startsWith('+')) return '+$digits';
    final code = (countryCode == null || countryCode.isEmpty)
        ? 'IN' // Legacy local loan records did not persist their country.
        : countryCode.toUpperCase();
    try {
      final dialDigits = CountryCatalog.byCode(
        code,
      ).dialCode.replaceAll(RegExp(r'[^0-9]'), '');
      return digits.startsWith(dialDigits) ? '+$digits' : '+$dialDigits$digits';
    } catch (_) {
      return null;
    }
  }
}
