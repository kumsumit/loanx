import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:loanx/db/app_settings.dart';
import 'package:loanx/db/tostore_database.dart';
import 'package:loanx/domain/country_catalog.dart';
import 'package:loanx/domain/money.dart';
import 'package:loanx/domain/calculation_contract.dart';
import 'package:loanx/model/loan.dart';
import 'package:loanx/service/currency_presentation.dart';
import 'package:loanx/service/database_helper.dart';
import 'package:loanx/src/rust/api/network.dart' as network;

class AuthClient {
  AuthClient([this._storage = const FlutterSecureStorage()]);

  /// The last non-authentication sync error, retained for the UI to explain
  /// why a cloud restore is unavailable instead of silently showing an empty
  /// local workspace.
  String? lastSyncError;
  static const _address = String.fromEnvironment('LOANX_SERVER_ADDRESS');
  static const _name = String.fromEnvironment('LOANX_SERVER_NAME');
  static const _certificate64 = String.fromEnvironment(
    'LOANX_SERVER_CERTIFICATE_BASE64',
  );
  final FlutterSecureStorage _storage;
  static const _sessionKey = 'loanx.auth-session.v1';
  String? _challenge;
  Future<void>? _pendingSync;
  Future<bool>? _pendingSessionRestore;

  /// Set only when the device must perform the OTP connection flow again.
  /// A transient transport failure deliberately does not set this: local work
  /// remains queued and can retry when the server is reachable.
  bool requiresReconnect = false;

  /// Whether this build has enough information to attempt a cloud request.
  ///
  /// The cloud service is optional for local-first workspaces. In particular,
  /// a normal `flutter run` without Dart defines must not turn a local borrower
  /// dashboard refresh into a configuration exception.
  static bool get hasServerConfiguration =>
      _address.trim().isNotEmpty &&
      _name.trim().isNotEmpty &&
      _certificate64.trim().isNotEmpty;

  String get _certificate {
    if (!hasServerConfiguration) {
      throw StateError(
        'LoanX server configuration is missing. Launch with '
        'LOANX_SERVER_ADDRESS, LOANX_SERVER_NAME, and '
        'LOANX_SERVER_CERTIFICATE_BASE64.',
      );
    }
    try {
      return utf8.decode(base64Decode(_certificate64));
    } on FormatException {
      throw StateError('LoanX server certificate is not valid base64');
    }
  }

  Future<void> requestOtp(PhoneNumber phone) async {
    final result = await network.requestOtp(
      serverAddress: _address,
      serverName: _name,
      trustedCertificatePem: _certificate,
      deviceId: _deviceId(),
      phoneE164: _e164(phone),
    );
    if (!result.success) {
      throw StateError(result.errorMessage ?? 'OTP request failed');
    }
    _challenge = result.challengeId;
  }

  Future<bool> verifyOtp(PhoneNumber phone, String otp, String language) async {
    if (_challenge == null) throw StateError('OTP challenge is missing');
    final result = await network.verifyOtp(
      serverAddress: _address,
      serverName: _name,
      trustedCertificatePem: _certificate,
      deviceId: _deviceId(),
      challengeId: _challenge!,
      phoneE164: _e164(phone),
      otp: otp,
      preferredLanguage: language,
    );
    if (!result.success) return false;
    final bootstrap = await network.accountBootstrap(
      serverAddress: _address,
      serverName: _name,
      trustedCertificatePem: _certificate,
      deviceId: _deviceId(),
      accessToken: result.accessToken,
    );
    if (!bootstrap.success) {
      throw StateError(bootstrap.errorMessage ?? 'Account bootstrap failed');
    }
    final identity = CloudIdentity(
      userId: bootstrap.userId,
      workspaceId: bootstrap.workspaceId,
      selfPartyId: bootstrap.selfPartyId,
      phoneE164: bootstrap.phoneE164,
    );
    final linkedToLocalOwner = await linkLocalOwner(identity);
    await _storeTokens(
      result.accessToken,
      result.refreshToken,
      identity: identity,
    );
    if (linkedToLocalOwner) {
      try {
        lastSyncError = null;
        await syncPendingWork();
      } catch (error, stackTrace) {
        lastSyncError = '$error';
        // Authentication succeeded; a queued share can retry on the next
        // session refresh or explicit account connection.
        developer.log(
          'Cloud workspace sync after OTP login failed',
          name: 'loanx.auth',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    _challenge = null;
    return true;
  }

  /// Verifies a phone challenge in the authenticated lender context. This
  /// never signs the device into the borrower's account.
  Future<String?> verifyOtpForContact(PhoneNumber phone, String otp) async {
    if (_challenge == null) throw StateError('OTP challenge is missing');
    final tokens = await _readTokens();
    if (tokens == null) {
      throw StateError('Lender account session is missing');
    }
    final result = await network.verifyContactOtp(
      serverAddress: _address,
      serverName: _name,
      trustedCertificatePem: _certificate,
      deviceId: _deviceId(),
      accessToken: tokens.accessToken,
      challengeId: _challenge!,
      phoneE164: _e164(phone),
      otp: otp,
    );
    if (!result.success) {
      throw StateError(result.errorMessage ?? 'OTP verification failed');
    }
    _challenge = null;
    return result.verificationId;
  }

  Future<bool> createVerifiedLoan({
    required String verificationId,
    required String operationId,
    required String borrowerPartyId,
    required String borrowerName,
    String borrowerEmail = '',
    String borrowerCountryCode = '',
    required Map<String, Object?> loanPayload,
  }) async {
    final tokens = await _readTokens();
    final session = await _readSessionJson();
    final workspaceId = session['workspace_id'] as String?;
    if (tokens == null || workspaceId == null || workspaceId.isEmpty) {
      return false;
    }
    final result = await network.createVerifiedLoan(
      serverAddress: _address,
      serverName: _name,
      trustedCertificatePem: _certificate,
      deviceId: _deviceId(),
      accessToken: tokens.accessToken,
      workspaceId: workspaceId,
      operationId: operationId,
      verificationId: verificationId,
      borrowerPartyId: borrowerPartyId,
      borrowerName: borrowerName,
      borrowerEmail: borrowerEmail,
      borrowerCountryCode: borrowerCountryCode,
      loanPayloadJson: utf8.encode(jsonEncode(loanPayload)),
    );
    if (!result.success) {
      throw StateError(result.errorMessage ?? 'Unable to save loan to server');
    }
    return true;
  }

  Future<bool> createPendingLoan({
    required String borrowerPhoneE164,
    required String borrowerName,
    required String operationId,
    required Map<String, Object?> loanPayload,
  }) async {
    final tokens = await _readTokens();
    final session = await _readSessionJson();
    final workspaceId = session['workspace_id'] as String?;
    if (tokens == null || workspaceId == null || workspaceId.isEmpty) {
      return false;
    }
    final result = await network.createPendingLoan(
      serverAddress: _address,
      serverName: _name,
      trustedCertificatePem: _certificate,
      deviceId: _deviceId(),
      accessToken: tokens.accessToken,
      workspaceId: workspaceId,
      operationId: operationId,
      borrowerPhoneE164: borrowerPhoneE164,
      borrowerName: borrowerName,
      loanPayloadJson: utf8.encode(jsonEncode(loanPayload)),
    );
    if (!result.success) {
      throw StateError(result.errorMessage ?? 'Unable to share loan');
    }
    return true;
  }

  Future<List<network.SharedLoanSummary>> listSharedLoans({
    int limit = 100,
  }) async {
    // A local-only build may still contain an old cloud session. Do not let
    // that stale session make the optional refresh fail on every dashboard
    // rebuild; local data remains the source of truth while unconfigured.
    if (!hasServerConfiguration) return const [];
    final tokens = await _readTokens();
    if (tokens == null) return const [];
    // Claim invitations created while this borrower already had an active
    // session; no logout/login or app restart should be required.
    await _refreshAccountBootstrap(tokens.accessToken);
    final result = await network.listSharedLoans(
      serverAddress: _address,
      serverName: _name,
      trustedCertificatePem: _certificate,
      deviceId: _deviceId(),
      accessToken: tokens.accessToken,
      limit: limit,
    );
    if (!result.success) {
      throw StateError(
        result.errorMessage ?? 'Shared loans could not be loaded',
      );
    }
    return result.loans;
  }

  /// Sends locally committed financial events when the lender has a cloud
  /// session. Pending rows remain durable until the server acknowledges the
  /// event, so recording a repayment never depends on network availability.
  Future<void> flushPendingFinancialEvents({
    LoanxDatabasePort? database,
  }) async {
    final tokens = await _readTokens();
    final session = await _readSessionJson();
    final workspaceId = session['workspace_id'] as String?;
    if (tokens == null || workspaceId == null || workspaceId.isEmpty) return;
    final db = database ?? await DatabaseHelper.instance.database;
    final rows = await db.query(
      'pendingFinancialEvents',
      where: 'status = ?',
      whereArgs: ['PENDING'],
      orderBy: 'createdAt ASC',
    );
    for (final row in rows) {
      final eventId = row['eventId'] as String;
      final now = DateTime.now().toUtc().toIso8601String();
      try {
        final payload = Map<String, dynamic>.from(
          jsonDecode(row['payloadJson'] as String) as Map,
        );
        final result = await network.pushFinancialEvent(
          serverAddress: _address,
          serverName: _name,
          trustedCertificatePem: _certificate,
          deviceId: _deviceId(),
          accessToken: tokens.accessToken,
          workspaceId: workspaceId,
          operationId: eventId,
          loanId: payload['loan_id'] as String,
          eventType: payload['type'] as String,
          amountMinor: payload['amount_minor'] as String,
          currency: payload['currency'] as String,
          currencyScale: (payload['currency_scale'] as num).toInt(),
          effectiveDate: payload['effective_date'] as String,
          paymentMethod: payload['payment_method'] as String?,
          referenceNumber: payload['reference_number'] as String?,
          reversesEventId: payload['reverses_event_id'] as String?,
          reason: payload['reason'] as String?,
          principalMinor: payload['principal_minor'] as String?,
          loanDate: payload['loan_date'] as String?,
        );
        if (!result.success) {
          throw StateError(
            result.errorMessage ?? 'Financial event sync failed',
          );
        }
        await db.update(
          'pendingFinancialEvents',
          {'status': 'SENT', 'lastError': null, 'updatedAt': now},
          where: 'eventId = ?',
          whereArgs: [eventId],
        );
      } catch (error) {
        final attempts = ((row['attemptCount'] as num?)?.toInt() ?? 0) + 1;
        await db.update(
          'pendingFinancialEvents',
          {'attemptCount': attempts, 'lastError': '$error', 'updatedAt': now},
          where: 'eventId = ?',
          whereArgs: [eventId],
        );
        await db.flush();
        throw StateError('Financial event sync failed: $error');
      }
    }
    await db.flush();
  }

  Future<void> queueVerifiedLoan({
    required String verificationId,
    required String operationId,
    required String borrowerPartyId,
    required String borrowerName,
    String borrowerEmail = '',
    String borrowerCountryCode = '',
    required Map<String, Object?> loanPayload,
    LoanxDatabasePort? database,
  }) async {
    final db = database ?? await DatabaseHelper.instance.database;
    final owners = await db.query('localOwners');
    if (owners.length != 1) {
      throw StateError('A single local owner is required');
    }
    final ownerId = owners.single['id'] as String;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((tx) async {
      await tx.insert('pendingVerifiedLoans', {
        'ownerId': ownerId,
        'operationId': operationId,
        'verificationId': verificationId,
        'borrowerPartyId': borrowerPartyId,
        'borrowerName': borrowerName,
        'borrowerEmail': borrowerEmail,
        'borrowerCountryCode': borrowerCountryCode,
        'loanPayloadJson': jsonEncode(loanPayload),
        'status': 'PENDING',
        'attemptCount': 0,
        'createdAt': now,
        'updatedAt': now,
      });
    });
  }

  Future<void> flushPendingVerifiedLoans({LoanxDatabasePort? database}) async {
    if (!hasServerConfiguration) return;
    final tokens = await _readTokens();
    final session = await _readSessionJson();
    final workspaceId = session['workspace_id'] as String?;
    if (tokens == null || workspaceId == null || workspaceId.isEmpty) return;
    final db = database ?? await DatabaseHelper.instance.database;
    final owners = await db.query('localOwners');
    if (owners.length != 1 ||
        owners.single['remoteWorkspaceId'] != workspaceId) {
      return;
    }
    final ownerId = owners.single['id'] as String;
    final rows = await db.query(
      'pendingVerifiedLoans',
      where: 'ownerId = ? AND status = ?',
      whereArgs: [ownerId, 'PENDING'],
      orderBy: 'createdAt ASC',
    );
    for (final row in rows) {
      final operationId = row['operationId'] as String;
      final now = DateTime.now().toUtc().toIso8601String();
      try {
        final result = await network.createVerifiedLoan(
          serverAddress: _address,
          serverName: _name,
          trustedCertificatePem: _certificate,
          deviceId: _deviceId(),
          accessToken: tokens.accessToken,
          workspaceId: workspaceId,
          operationId: operationId,
          verificationId: row['verificationId'] as String,
          borrowerPartyId: row['borrowerPartyId'] as String,
          borrowerName: row['borrowerName'] as String,
          borrowerEmail: row['borrowerEmail'] as String? ?? '',
          borrowerCountryCode: row['borrowerCountryCode'] as String? ?? '',
          loanPayloadJson: utf8.encode(row['loanPayloadJson'] as String),
        );
        if (!result.success) {
          throw StateError(result.errorMessage ?? 'Verified loan sync failed');
        }
        final payload = jsonDecode(row['loanPayloadJson'] as String);
        final loanUid = payload is Map ? payload['loan_id'] : null;
        await db.transaction((tx) async {
          await tx.update(
            'pendingVerifiedLoans',
            {'status': 'SENT', 'lastError': null, 'updatedAt': now},
            where: 'operationId = ? AND ownerId = ?',
            whereArgs: [operationId, ownerId],
          );
          if (loanUid is String && loanUid.isNotEmpty) {
            await tx.update(
              'loans',
              {'syncState': 'SERVER_SAVED'},
              where: 'uid = ? AND ownerId = ?',
              whereArgs: [loanUid, ownerId],
            );
          }
        });
      } catch (error) {
        final attempts = ((row['attemptCount'] as num?)?.toInt() ?? 0) + 1;
        await db.update(
          'pendingVerifiedLoans',
          {'attemptCount': attempts, 'lastError': '$error', 'updatedAt': now},
          where: 'operationId = ? AND ownerId = ?',
          whereArgs: [operationId, ownerId],
        );
        break;
      }
    }
    await db.flush();
  }

  /// Sends locally committed entity mutations to PostgreSQL. Mutations are
  /// marked SENT only after the server commits its durable mutation, change,
  /// audit, and idempotency records. Rows stay pending across offline runs.
  Future<void> flushPendingSyncMutations({LoanxDatabasePort? database}) async {
    if (!hasServerConfiguration) return;
    final tokens = await _readTokens();
    final session = await _readSessionJson();
    final workspaceId = session['workspace_id'] as String?;
    if (tokens == null || workspaceId == null || workspaceId.isEmpty) return;

    final db = database ?? await DatabaseHelper.instance.database;
    final owners = await db.query('localOwners');
    if (owners.length != 1 ||
        owners.single['remoteWorkspaceId'] != workspaceId) {
      return;
    }
    final ownerId = owners.single['id'] as String;
    final rows = await db.query(
      'pendingSyncMutations',
      where: 'ownerId = ? AND status = ?',
      whereArgs: [ownerId, 'PENDING'],
      orderBy: 'createdAt ASC',
    );
    for (final row in rows) {
      final operationId = row['operationId'] as String;
      final now = DateTime.now().toUtc().toIso8601String();
      try {
        final result = await network.pushMutation(
          serverAddress: _address,
          serverName: _name,
          trustedCertificatePem: _certificate,
          deviceId: _deviceId(),
          accessToken: tokens.accessToken,
          workspaceId: workspaceId,
          operationId: operationId,
          entityType: row['entityType'] as String,
          entityId: row['entityId'] as String,
          operation: row['operation'] as String,
          expectedRevision: (row['expectedRevision'] as num?)?.toInt() ?? 0,
          payloadJson: utf8.encode(row['payloadJson'] as String),
        );
        if (!result.success) {
          throw StateError(result.errorMessage ?? 'Sync mutation failed');
        }
        await db.transaction((tx) async {
          await tx.update(
            'pendingSyncMutations',
            {'status': 'SENT', 'lastError': null, 'updatedAt': now},
            where: 'operationId = ? AND ownerId = ?',
            whereArgs: [operationId, ownerId],
          );
          if (row['entityType'] == 'loan' && row['entityId'] is String) {
            await tx.update(
              'loans',
              {
                'syncState': 'SERVER_SAVED',
                // A create starts at revision 1; a successful update advances
                // exactly the revision supplied with that mutation.
                'serverRevision': row['operation'] == 'update'
                    ? ((row['expectedRevision'] as num?)?.toInt() ?? 1) + 1
                    : 1,
              },
              where: 'uid = ? AND ownerId = ?',
              whereArgs: [row['entityId'], ownerId],
            );
          }
        });
      } catch (error) {
        final attempts = ((row['attemptCount'] as num?)?.toInt() ?? 0) + 1;
        await db.update(
          'pendingSyncMutations',
          {'attemptCount': attempts, 'lastError': '$error', 'updatedAt': now},
          where: 'operationId = ? AND ownerId = ?',
          whereArgs: [operationId, ownerId],
        );
        // Preserve party-before-loan ordering. A loan mutation must not race
        // ahead of the party it references after a transient failure.
        await db.flush();
        throw StateError('Cloud mutation sync failed: $error');
      }
    }
    await db.flush();
  }

  /// Flushes every durable local queue once a connected session is available.
  /// Calls are coalesced because app-resume and connectivity events can arrive
  /// together.  A failure remains inspectable in the queue's `lastError` and
  /// is retried by the next connectivity or lifecycle event.
  Future<void> syncPendingWork() {
    if (!hasServerConfiguration) return Future.value();
    return _pendingSync ??= _syncPendingWork().whenComplete(() {
      _pendingSync = null;
    });
  }

  Future<void> _syncPendingWork() async {
    await queueExistingLoansForSync();
    await flushPendingLoanShares();
    await flushPendingVerifiedLoans();
    await flushPendingSyncMutations();
    await flushPendingFinancialEvents();
    await pullAndApplyChanges();
  }

  /// Pulls the owner's durable server changes into the local workspace.
  ///
  /// This is required after reinstall: the local ToStore database is removed
  /// by the operating system, while the server workspace survives. The
  /// cursor is advanced in the same local transaction as the applied batch,
  /// so a crash causes a safe replay instead of a skipped change.
  Future<void> pullAndApplyChanges({LoanxDatabasePort? database}) async {
    if (!hasServerConfiguration) return;
    final tokens = await _readTokens();
    final session = await _readSessionJson();
    final workspaceId = session['workspace_id'] as String?;
    if (tokens == null || workspaceId == null || workspaceId.isEmpty) return;

    final db = database ?? await DatabaseHelper.instance.database;
    final owners = await db.query('localOwners');
    if (owners.length != 1 ||
        owners.single['remoteWorkspaceId'] != workspaceId) {
      return;
    }
    final ownerId = owners.single['id'] as String;
    final cursorRows = await db.query(
      'syncCursors',
      where: 'ownerId = ? AND workspaceId = ?',
      whereArgs: [ownerId, workspaceId],
      limit: 1,
    );
    var cursor = cursorRows.isEmpty
        ? 0
        : (cursorRows.single['lastSequence'] as num?)?.toInt() ?? 0;

    do {
      final result = await network.pullChanges(
        serverAddress: _address,
        serverName: _name,
        trustedCertificatePem: _certificate,
        deviceId: _deviceId(),
        accessToken: tokens.accessToken,
        workspaceId: workspaceId,
        afterSequence: cursor,
        limit: 500,
      );
      if (!result.success) {
        throw StateError(
          result.errorMessage ?? 'Cloud records could not be loaded',
        );
      }

      // Server sequence order is authoritative, but dependencies within a
      // batch are applied in dependency order. This also makes recovery work
      // if an older server emitted an event before its local loan snapshot.
      final changes = [...result.changes]
        ..sort((a, b) {
          final priority = <String, int>{
            'party': 0,
            'relationship': 1,
            'loan': 2,
            'financial_event': 3,
          };
          final byType = (priority[a.entityType] ?? 99).compareTo(
            priority[b.entityType] ?? 99,
          );
          return byType == 0 ? a.sequence.compareTo(b.sequence) : byType;
        });
      final previousCursor = cursor;
      final nextCursor = result.nextSequence.toInt();
      await db.transaction((tx) async {
        for (final change in changes) {
          await _applySyncChange(tx, ownerId, change);
        }
        final now = DateTime.now().toUtc().toIso8601String();
        final existing = await tx.query(
          'syncCursors',
          where: 'ownerId = ?',
          whereArgs: [ownerId],
          limit: 1,
        );
        final row = {
          // `syncCursors` uses application-supplied string primary keys.
          // One cursor belongs to one local owner, so its owner ID is a
          // stable, deterministic key that also keeps retries idempotent.
          'id': ownerId,
          'ownerId': ownerId,
          'workspaceId': workspaceId,
          'lastSequence': nextCursor,
          'updatedAt': now,
        };
        if (existing.isEmpty) {
          await tx.insert('syncCursors', row);
        } else {
          await tx.update(
            'syncCursors',
            row,
            where: 'ownerId = ?',
            whereArgs: [ownerId],
          );
        }
      });
      await db.flush();
      cursor = nextCursor;
      if (changes.isEmpty && !result.hasMore) break;
      if (result.hasMore && nextCursor <= previousCursor) {
        throw StateError('Cloud sync returned an unchanged cursor');
      }
      // The server returns has_more when another page is available. A
      // defensive cursor check above prevents an accidental infinite loop.
      if (!result.hasMore) break;
    } while (true);
  }

  /// Converts records made in the local-only experience into durable cloud
  /// mutations when the owner explicitly links an account. Without this
  /// handoff, a local loan created before sign-in would remain on one device
  /// forever and could not be recovered after an uninstall.
  Future<void> queueExistingLoansForSync({LoanxDatabasePort? database}) async {
    if (!hasServerConfiguration) return;
    final tokens = await _readTokens();
    final session = await _readSessionJson();
    final workspaceId = session['workspace_id'] as String?;
    if (tokens == null || workspaceId == null || workspaceId.isEmpty) return;
    final db = database ?? await DatabaseHelper.instance.database;
    final owners = await db.query('localOwners');
    if (owners.length != 1 ||
        owners.single['remoteWorkspaceId'] != workspaceId) {
      return;
    }
    final owner = owners.single;
    final ownerId = owner['id'] as String;
    final remoteLender = owner['remotePartyId'] as String?;
    if (remoteLender == null || remoteLender.isEmpty) return;
    final loans = await db.query(
      'loans',
      where: 'ownerId = ?',
      whereArgs: [ownerId],
    );
    await db.transaction((tx) async {
      for (final loan in loans) {
        if (loan['syncState'] == Loan.serverSaved) continue;
        final loanUid = loan['uid'] as String?;
        final borrowerId = loan['borrowerPartyId'] as String?;
        if (loanUid == null ||
            loanUid.isEmpty ||
            borrowerId == null ||
            borrowerId.isEmpty) {
          continue;
        }
        final borrowerRows = await tx.query(
          'parties',
          where: 'id = ? AND ownerId = ?',
          whereArgs: [borrowerId, ownerId],
          limit: 1,
        );
        if (borrowerRows.length != 1) continue;
        final borrower = borrowerRows.single;
        final currency = loan['currency'] as String? ?? 'INR';
        final scale = CurrencyPresentation.fractionDigits(currency);
        final exact =
            loan['loanAmountExact'] as String? ??
            (loan['loanAmount'] as num).toString();
        final principal = Money.parse(exact, currency: currency, scale: scale);
        final now = DateTime.now().toUtc().toIso8601String();
        await _queueMutationIfMissing(tx, {
          'id': borrowerId,
          'ownerId': ownerId,
          'operationId': borrowerId,
          'entityType': 'party',
          'entityId': borrowerId,
          'operation': 'create',
          'expectedRevision': 0,
          'payloadJson': jsonEncode({
            'display_name': borrower['displayName'],
            'phone_e164': null,
            'email': borrower['email'],
            'country_code': borrower['countryCode'],
            'status': 'active',
          }),
          'status': 'PENDING',
          'attemptCount': 0,
          'createdAt': now,
          'updatedAt': now,
        });
        await _queueMutationIfMissing(tx, {
          'id': loanUid,
          'ownerId': ownerId,
          'operationId': loanUid,
          'entityType': 'loan',
          'entityId': loanUid,
          'operation': 'create',
          'expectedRevision': 0,
          'payloadJson': jsonEncode({
            'relationship_id': null,
            'lender_party_id': remoteLender,
            'borrower_party_id': borrowerId,
            'borrower_name': borrower['displayName'],
            'borrower_phone': borrower['phone'],
            'relative_name': loan['relativeName'],
            'address': loan['address'],
            'principal_minor': int.parse(principal.minorUnits.toString()),
            'currency': currency,
            'currency_scale': scale,
            'loan_date': (loan['dateCreated'] as String).substring(0, 10),
            'maturity_date': null,
            'lifecycle': 'active',
            'calculation_contract':
                loan['calculationVersion'] ?? CalculationContract.legacyV1,
            'status': 'active',
            'interest_rate': loan['interestRate'],
            'interest_type': loan['interestType'],
            'interest_frequency': loan['interestFrequency'],
            'mortgage_term_years': loan['mortgageTermYears'],
            'lock_in_days': loan['lockInDays'],
            'early_redemption_charge': loan['earlyRedemptionCharge'],
            'weight': loan['weight'],
            'weight_unit': loan['weightUnit'],
            'additional_details': loan['additionalDetails'],
            'terms_and_conditions': loan['termsAndConditions'],
            'date_finished': loan['dateFinished'],
            'completed_by': loan['completedBy'],
            'settlement_amount': loan['settlementAmount'],
            'completion_reference': loan['completionReference'],
            'completion_notes': loan['completionNotes'],
            'client_confirmed_at': loan['clientConfirmedAt'],
          }),
          'status': 'PENDING',
          'attemptCount': 0,
          'createdAt': now,
          'updatedAt': now,
        });
      }
    });
    await db.flush();
  }

  Future<void> _queueMutationIfMissing(
    DatabaseExecutor tx,
    Map<String, Object?> row,
  ) async {
    final existing = await tx.query(
      'pendingSyncMutations',
      where: 'operationId = ?',
      whereArgs: [row['operationId']],
      limit: 1,
    );
    if (existing.isEmpty) await tx.insert('pendingSyncMutations', row);
  }

  Future<void> _applySyncChange(
    DatabaseExecutor tx,
    String ownerId,
    network.SyncChange change,
  ) async {
    if (change.operation == 'delete') {
      if (change.entityType == 'loan') {
        await tx.delete(
          'loans',
          where: 'uid = ? AND ownerId = ?',
          whereArgs: [change.entityId, ownerId],
        );
      }
      return;
    }
    final payload = jsonDecode(utf8.decode(change.payloadJson));
    if (payload is! Map) {
      throw const FormatException('Invalid cloud change payload');
    }
    final data = Map<String, dynamic>.from(payload);
    switch (change.entityType) {
      case 'party':
        await _applyPartyChange(tx, ownerId, change.entityId, data);
        break;
      case 'relationship':
        await _applyRelationshipChange(tx, ownerId, change.entityId, data);
        break;
      case 'loan':
        await _applyLoanChange(
          tx,
          ownerId,
          change.entityId,
          data,
          change.entityRevision.toInt(),
        );
        break;
      case 'financial_event':
        await _applyFinancialEventChange(
          tx,
          ownerId,
          change.entityId,
          data,
          change,
        );
        break;
    }
  }

  String _localPartyId(Map<String, Object?> owner, String remotePartyId) =>
      remotePartyId == owner['remotePartyId']
      ? owner['selfPartyId'] as String
      : remotePartyId;

  Future<void> _applyPartyChange(
    DatabaseExecutor tx,
    String ownerId,
    String remoteId,
    Map<String, dynamic> data,
  ) async {
    final owner = (await tx.query(
      'localOwners',
      where: 'id = ?',
      whereArgs: [ownerId],
      limit: 1,
    )).single;
    final id = _localPartyId(owner, remoteId);
    final existing = await tx.query(
      'parties',
      where: 'id = ? AND ownerId = ?',
      whereArgs: [id, ownerId],
      limit: 1,
    );
    final now = DateTime.now().toUtc().toIso8601String();
    final row = <String, Object?>{
      'id': id,
      'ownerId': ownerId,
      'displayName':
          (data['display_name'] as String?)?.trim().isNotEmpty == true
          ? (data['display_name'] as String).trim()
          : 'LoanX contact',
      'phone': data['phone_e164'],
      'email': data['email'],
      'countryCode': data['country_code'],
      'userId': data['linked_user_id'],
      'status': ((data['status'] as String?) ?? 'active').toUpperCase(),
      'createdAt': now,
      'updatedAt': now,
    };
    if (existing.isEmpty) {
      await tx.insert('parties', row);
    } else {
      await tx.update(
        'parties',
        row
          ..remove('id')
          ..remove('ownerId')
          ..remove('createdAt'),
        where: 'id = ? AND ownerId = ?',
        whereArgs: [id, ownerId],
      );
    }
  }

  Future<void> _applyRelationshipChange(
    DatabaseExecutor tx,
    String ownerId,
    String id,
    Map<String, dynamic> data,
  ) async {
    final owner = (await tx.query(
      'localOwners',
      where: 'id = ?',
      whereArgs: [ownerId],
      limit: 1,
    )).single;
    final partyA = _localPartyId(owner, data['party_a_id'] as String);
    final partyB = _localPartyId(owner, data['party_b_id'] as String);
    final now = DateTime.now().toUtc().toIso8601String();
    final row = <String, Object?>{
      'id': id,
      'ownerId': ownerId,
      'partyAId': partyA,
      'partyBId': partyB,
      'status': ((data['status'] as String?) ?? 'active').toUpperCase(),
      'createdAt': now,
      'updatedAt': now,
    };
    final existing = await tx.query(
      'relationships',
      where: 'id = ? AND ownerId = ?',
      whereArgs: [id, ownerId],
      limit: 1,
    );
    if (existing.isEmpty) {
      await tx.insert('relationships', row);
    } else {
      await tx.update(
        'relationships',
        row
          ..remove('id')
          ..remove('ownerId')
          ..remove('createdAt'),
        where: 'id = ? AND ownerId = ?',
        whereArgs: [id, ownerId],
      );
    }
  }

  Future<void> _applyLoanChange(
    DatabaseExecutor tx,
    String ownerId,
    String remoteId,
    Map<String, dynamic> data,
    int serverRevision,
  ) async {
    final owner = (await tx.query(
      'localOwners',
      where: 'id = ?',
      whereArgs: [ownerId],
      limit: 1,
    )).single;
    final uid = (data['loan_id'] as String?) ?? remoteId;
    final lender = _localPartyId(owner, data['lender_party_id'] as String);
    final borrower = _localPartyId(owner, data['borrower_party_id'] as String);
    final principalExact = _minorToDecimal(
      data['principal_minor'],
      ((data['currency_scale'] as num?)?.toInt() ?? 2).clamp(0, 6),
    );
    final principal = double.parse(principalExact);
    final existing = await tx.query(
      'loans',
      where: 'uid = ? AND ownerId = ?',
      whereArgs: [uid, ownerId],
      limit: 1,
    );
    var borrowerRows = await tx.query(
      'parties',
      where: 'id = ? AND ownerId = ?',
      whereArgs: [borrower, ownerId],
      limit: 1,
    );
    if (borrowerRows.isEmpty) {
      final now = DateTime.now().toUtc().toIso8601String();
      await tx.insert('parties', {
        'id': borrower,
        'ownerId': ownerId,
        'displayName':
            (data['borrower_name'] as String?)?.trim().isNotEmpty == true
            ? (data['borrower_name'] as String).trim()
            : 'LoanX borrower',
        'phone': data['borrower_phone'],
        'status': 'ACTIVE',
        'createdAt': now,
        'updatedAt': now,
      });
      borrowerRows = await tx.query(
        'parties',
        where: 'id = ? AND ownerId = ?',
        whereArgs: [borrower, ownerId],
        limit: 1,
      );
    }
    final borrowerName =
        (data['borrower_name'] as String?)?.trim().isNotEmpty == true
        ? (data['borrower_name'] as String).trim()
        : borrowerRows.isEmpty
        ? 'LoanX borrower'
        : borrowerRows.single['displayName'] as String;
    final relations = await tx.query('familyRelations', limit: 1);
    final materials = await tx.query('mortgageMaterials', limit: 1);
    final date = _dateTimeString(data['loan_date'] as String?);
    final row = <String, Object?>{
      'uid': uid,
      'ownerId': ownerId,
      'lenderPartyId': lender,
      'borrowerPartyId': borrower,
      'relationshipId': data['relationship_id'],
      'depositorName': borrowerName,
      'phoneNumber':
          (data['borrower_phone'] as String?)?.trim() ??
          (borrowerRows.isEmpty
              ? ''
              : borrowerRows.single['phone'] as String? ?? ''),
      'relativeName': data['relative_name'] as String? ?? '',
      'address': data['address'] as String? ?? '',
      'loanAmount': principal,
      'loanAmountExact': principalExact,
      'weight': (data['weight'] as num?)?.toDouble() ?? 0,
      'weightUnit': data['weight_unit'] as String? ?? 'g',
      'interestRate': (data['interest_rate'] as num?)?.toDouble() ?? 0,
      'interestType': (data['interest_type'] as num?)?.toInt() ?? 0,
      'interestFrequency': (data['interest_frequency'] as num?)?.toInt() ?? 0,
      'mortgageTermYears': (data['mortgage_term_years'] as num?)?.toInt() ?? 5,
      'lockInDays': (data['lock_in_days'] as num?)?.toInt() ?? 0,
      'earlyRedemptionCharge':
          (data['early_redemption_charge'] as num?)?.toDouble() ?? 0,
      'additionalDetails': data['additional_details'] as String? ?? '',
      'termsAndConditions': data['terms_and_conditions'] as String? ?? '',
      'dateCreated': date,
      'dateFinished': data['date_finished'],
      'completedBy': data['completed_by'] as String? ?? '',
      'settlementAmount': (data['settlement_amount'] as num?)?.toDouble(),
      'completionReference': data['completion_reference'] as String? ?? '',
      'completionNotes': data['completion_notes'] as String? ?? '',
      'familyRelationId': relations.isEmpty ? 1 : relations.first['id'],
      'mortgageMaterialId': materials.isEmpty ? 1 : materials.first['id'],
      'currency': data['currency'] as String? ?? 'INR',
      'calculationVersion':
          data['calculation_contract'] as String? ??
          CalculationContract.legacyV1,
      'syncState': Loan.serverSaved,
      'serverRevision': serverRevision,
      'clientConfirmedAt': data['client_confirmed_at'],
    };
    if (existing.isEmpty) {
      await tx.insert('loans', row);
    } else {
      row.remove('uid');
      row.remove('ownerId');
      await tx.update(
        'loans',
        row,
        where: 'uid = ? AND ownerId = ?',
        whereArgs: [uid, ownerId],
      );
    }
  }

  Future<void> _applyFinancialEventChange(
    DatabaseExecutor tx,
    String ownerId,
    String remoteId,
    Map<String, dynamic> data,
    network.SyncChange change,
  ) async {
    final loanUid = data['loan_id'] as String?;
    if (loanUid == null || loanUid.isEmpty) return;
    final existing = await tx.query(
      'financialEvents',
      where: 'id = ? AND ownerId = ?',
      whereArgs: [remoteId, ownerId],
      limit: 1,
    );
    if (existing.isNotEmpty) return;
    final recordedAt = DateTime.fromMillisecondsSinceEpoch(
      change.createdAtMs,
      isUtc: true,
    ).toIso8601String();
    await tx.insert('financialEvents', {
      'id': remoteId,
      'ownerId': ownerId,
      'loanUid': loanUid,
      'type': data['type'] as String? ?? 'repayment',
      'amountMinor': (data['amount_minor'] ?? '0').toString(),
      'currency': data['currency'] as String? ?? 'INR',
      'currencyScale': (data['currency_scale'] as num?)?.toInt() ?? 2,
      'effectiveDate': _dateTimeString(data['effective_date'] as String?),
      'recordedAt': recordedAt,
      'paymentMethod': data['payment_method'],
      'referenceNumber': data['reference_number'],
      'notes': data['reason'],
      'createdBy': ownerId,
      'reversesEventId': data['reverses_event_id'],
      'payloadHash': 'remote-${change.sequence}',
    });
  }

  String _dateTimeString(String? value) {
    final date = (value ?? '1970-01-01').trim();
    return date.contains('T') ? date : '${date}T00:00:00.000Z';
  }

  String _minorToDecimal(Object? value, int scale) {
    final minor = BigInt.parse(value.toString());
    final negative = minor.isNegative;
    final digits = minor.abs().toString().padLeft(scale + 1, '0');
    final result = scale == 0
        ? digits
        : '${digits.substring(0, digits.length - scale)}.${digits.substring(digits.length - scale)}';
    return negative ? '-$result' : result;
  }

  /// Queues a lender share when the local lender workspace has not yet been
  /// connected to a LoanX account. Verifying the borrower's phone proves the
  /// contact number, but must never authorize a lender write as that borrower.
  Future<void> queuePendingLoanShare({
    required String borrowerPhoneE164,
    required String borrowerName,
    required String operationId,
    required Map<String, Object?> loanPayload,
    LoanxDatabasePort? database,
  }) async {
    final db = database ?? await DatabaseHelper.instance.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final payloadJson = jsonEncode(loanPayload);
    await db.transaction((tx) async {
      final previous = await tx.query(
        'pendingLoanShares',
        where: 'operationId = ?',
        whereArgs: [operationId],
      );
      if (previous.isNotEmpty) {
        final row = previous.single;
        if (row['borrowerPhoneE164'] != borrowerPhoneE164 ||
            row['borrowerName'] != borrowerName ||
            row['loanPayloadJson'] != payloadJson) {
          throw StateError('Share operation ID was already used differently');
        }
        return;
      }
      await tx.insert('pendingLoanShares', {
        'id': operationId,
        'operationId': operationId,
        'borrowerPhoneE164': borrowerPhoneE164,
        'borrowerName': borrowerName,
        'loanPayloadJson': payloadJson,
        'status': 'PENDING',
        'createdAt': now,
        'updatedAt': now,
      });
    });
  }

  /// Retries queued lender shares after this local workspace gets a cloud
  /// session. Rows remain pending until the server acknowledges them.
  Future<void> flushPendingLoanShares({LoanxDatabasePort? database}) async {
    if (await _readTokens() == null) return;
    final db = database ?? await DatabaseHelper.instance.database;
    final rows = await db.query(
      'pendingLoanShares',
      where: 'status = ?',
      whereArgs: ['PENDING'],
      orderBy: 'createdAt ASC',
    );
    for (final row in rows) {
      final operationId = row['operationId'] as String;
      try {
        final sent = await createPendingLoan(
          borrowerPhoneE164: row['borrowerPhoneE164'] as String,
          borrowerName: row['borrowerName'] as String,
          operationId: operationId,
          loanPayload: Map<String, Object?>.from(
            jsonDecode(row['loanPayloadJson'] as String) as Map,
          ),
        );
        if (!sent) continue;
        await db.update(
          'pendingLoanShares',
          {
            'status': 'SENT',
            'lastError': null,
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          },
          where: 'operationId = ?',
          whereArgs: [operationId],
        );
      } catch (error) {
        await db.update(
          'pendingLoanShares',
          {
            'lastError': '$error',
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          },
          where: 'operationId = ?',
          whereArgs: [operationId],
        );
      }
    }
    await db.flush();
  }

  /// Returns true only when the authenticated server profile was updated.
  ///
  /// A language selected before sign-in remains queued locally and is sent
  /// during OTP verification or the next restored session.
  Future<bool> updateLanguage(String language) async {
    final token = (await _readTokens())?.accessToken;
    if (token == null || token.isEmpty) return false;
    final result = await network.updateLanguage(
      serverAddress: _address,
      serverName: _name,
      trustedCertificatePem: _certificate,
      deviceId: _deviceId(),
      accessToken: token,
      preferredLanguage: language,
    );
    if (!result.success) {
      throw StateError(result.errorMessage ?? 'Language update failed');
    }
    return true;
  }

  Future<network.LenderSearchResult> searchPublicLenders({
    required int area,
    required String query,
    int limit = 25,
    String afterId = '',
  }) async {
    final token = (await _readTokens())?.accessToken;
    if (token == null || token.isEmpty) {
      throw StateError('Sign in is required to search public lenders');
    }
    final result = await network.searchPublicLenders(
      serverAddress: _address,
      serverName: _name,
      trustedCertificatePem: _certificate,
      deviceId: _deviceId(),
      accessToken: token,
      area: area,
      query: query,
      limit: limit,
      afterId: afterId,
    );
    if (!result.success) {
      throw StateError(result.errorMessage ?? 'Lender search failed');
    }
    return result;
  }

  Future<void> reportPublicLender(String profileId, String reason) async {
    final token = await _requiredAccessToken();
    final result = await network.reportPublicLender(
      serverAddress: _address,
      serverName: _name,
      trustedCertificatePem: _certificate,
      deviceId: _deviceId(),
      accessToken: token,
      profileId: profileId,
      reason: reason,
    );
    if (!result.success) {
      throw StateError(result.errorMessage ?? 'Unable to report lender');
    }
  }

  Future<void> blockPublicLender(String profileId) async {
    final token = await _requiredAccessToken();
    final result = await network.blockPublicLender(
      serverAddress: _address,
      serverName: _name,
      trustedCertificatePem: _certificate,
      deviceId: _deviceId(),
      accessToken: token,
      profileId: profileId,
    );
    if (!result.success) {
      throw StateError(result.errorMessage ?? 'Unable to block lender');
    }
  }

  Future<void> publishPublicLender({
    required String displayName,
    required String locality,
    required String city,
    required String postalCode,
    required String countryCode,
    required String minimumLoan,
    required String maximumLoan,
    required String currency,
    required int currencyScale,
    required List<String> categories,
    required String description,
    required bool available,
    required bool published,
  }) async {
    final min = Money.parse(
      minimumLoan,
      currency: currency,
      scale: currencyScale,
    );
    final max = Money.parse(
      maximumLoan,
      currency: currency,
      scale: currencyScale,
    );
    if (min.minorUnits < BigInt.zero ||
        max.minorUnits < min.minorUnits ||
        max.minorUnits > BigInt.from(9223372036854775807)) {
      throw ArgumentError('Invalid public loan range');
    }
    final result = await network.publishPublicLender(
      serverAddress: _address,
      serverName: _name,
      trustedCertificatePem: _certificate,
      deviceId: _deviceId(),
      accessToken: await _requiredAccessToken(),
      displayName: displayName,
      locality: locality,
      city: city,
      postalCode: postalCode,
      countryCode: countryCode,
      minimumLoanMinor: min.minorUnits.toString(),
      maximumLoanMinor: max.minorUnits.toString(),
      currency: currency,
      currencyScale: currencyScale,
      categories: categories,
      available: available,
      published: published,
      publicDescription: description,
    );
    if (!result.success) {
      throw StateError(
        result.errorMessage ?? 'Unable to update public profile',
      );
    }
  }

  Future<network.MyLenderProfile> myLenderProfile() async {
    final result = await network.myLenderProfile(
      serverAddress: _address,
      serverName: _name,
      trustedCertificatePem: _certificate,
      deviceId: _deviceId(),
      accessToken: await _requiredAccessToken(),
    );
    if (!result.success) {
      throw StateError(result.errorMessage ?? 'Unable to load public profile');
    }
    return result;
  }

  Future<void> saveBorrowerLookupProfile({
    required bool searchableByPhone,
    required String displayName,
    required String address,
  }) async {
    final result = await network.saveBorrowerLookupProfile(
      serverAddress: _address,
      serverName: _name,
      trustedCertificatePem: _certificate,
      deviceId: _deviceId(),
      accessToken: await _requiredAccessToken(),
      searchableByPhone: searchableByPhone,
      displayName: displayName,
      address: address,
    );
    if (!result.success) {
      throw StateError(
        result.errorMessage ?? 'Unable to update borrower profile',
      );
    }
  }

  Future<network.BorrowerProfileLookup?> lookupBorrowerProfile(
    String phoneE164,
  ) async {
    final result = await network.lookupBorrowerProfile(
      serverAddress: _address,
      serverName: _name,
      trustedCertificatePem: _certificate,
      deviceId: _deviceId(),
      accessToken: await _requiredAccessToken(),
      phoneE164: phoneE164,
    );
    if (!result.success) return null;
    return result.found ? result : null;
  }

  Future<String> _requiredAccessToken() async {
    final token = (await _readTokens())?.accessToken;
    if (token == null || token.isEmpty) {
      throw StateError('Sign in is required');
    }
    return token;
  }

  /// Restores credentials and reconciles the complete local workspace.
  ///
  /// Startup, connectivity changes, and an explicit user sync can happen at
  /// nearly the same time. Refresh tokens may rotate, so those callers must
  /// share one restore instead of issuing competing refresh requests.
  Future<bool> restoreSession() {
    return _pendingSessionRestore ??= _restoreSession().whenComplete(() {
      _pendingSessionRestore = null;
    });
  }

  Future<bool> _restoreSession() async {
    final refreshToken = (await _readTokens())?.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      requiresReconnect = true;
      lastSyncError = 'Cloud session is missing. Connect your account again.';
      return false;
    }
    try {
      final result = await network
          .refreshSession(
            serverAddress: _address,
            serverName: _name,
            trustedCertificatePem: _certificate,
            deviceId: _deviceId(),
            refreshToken: refreshToken,
          )
          .timeout(const Duration(seconds: 10));
      if (!result.success) {
        lastSyncError = result.errorMessage ?? 'Cloud session refresh failed';
        if (!result.transportUnavailable) {
          requiresReconnect = true;
          await clearLocalSession();
        }
        return false;
      }
      final bootstrap = await network.accountBootstrap(
        serverAddress: _address,
        serverName: _name,
        trustedCertificatePem: _certificate,
        deviceId: _deviceId(),
        accessToken: result.accessToken,
      );
      if (!bootstrap.success) {
        // The refresh succeeded, but bootstrap may be temporarily offline.
        // Keep the rotated credentials so they can be retried later.
        await _storeTokens(result.accessToken, result.refreshToken);
        lastSyncError =
            bootstrap.errorMessage ?? 'Cloud workspace could not be loaded';
        return false;
      }
      final identity = CloudIdentity(
        userId: bootstrap.userId,
        workspaceId: bootstrap.workspaceId,
        selfPartyId: bootstrap.selfPartyId,
        phoneE164: bootstrap.phoneE164,
      );
      final linkedToLocalOwner = await linkLocalOwner(identity);
      await _storeTokens(
        result.accessToken,
        result.refreshToken,
        identity: identity,
      );
      requiresReconnect = false;
      if (linkedToLocalOwner) {
        try {
          lastSyncError = null;
          await syncPendingWork();
        } catch (error, stackTrace) {
          lastSyncError = '$error';
          // Keep the refreshed session even if the share queue is temporarily
          // unavailable.
          developer.log(
            'Cloud workspace sync after session restore failed',
            name: 'loanx.auth',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
      final pendingLanguage = AppSettings.getPendingPreferredLanguage();
      if (pendingLanguage.isNotEmpty) {
        try {
          if (await updateLanguage(pendingLanguage)) {
            AppSettings.putPendingPreferredLanguage('');
            await AppSettings.flush();
          }
        } catch (_) {
          // Authentication is valid; preference sync can retry later.
        }
      }
      return true;
    } catch (error, stackTrace) {
      // A network/configuration error must not erase the local identity or
      // credentials. The caller controls local access independently.
      lastSyncError = '$error';
      developer.log(
        'Cloud session restore failed',
        name: 'loanx.auth',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Revokes the cloud session and removes this device's cloud credentials.
  ///
  /// A user may explicitly choose [localOnly] when the server cannot be
  /// reached. That is a device logout: it removes local credentials while
  /// leaving the server session to expire or be revoked on another device.
  Future<void> logout({bool localOnly = false}) async {
    if (localOnly) {
      await clearLocalSession();
      return;
    }

    final token = (await _readTokens())?.accessToken;
    if (token == null || token.isEmpty) {
      await clearLocalSession();
      return;
    }
    final result = await network
        .logoutSession(
          serverAddress: _address,
          serverName: _name,
          trustedCertificatePem: _certificate,
          deviceId: _deviceId(),
          accessToken: token,
        )
        .timeout(const Duration(seconds: 10));
    if (!result.success) {
      throw StateError(result.errorMessage ?? 'Unable to revoke session');
    }
    await clearLocalSession();
  }

  Future<void> clearLocalSession() async {
    await _storage.delete(key: _sessionKey);
    // Remove pre-upgrade token records after migration or logout.
    await _storage.delete(key: 'loanx.access-token');
    await _storage.delete(key: 'loanx.refresh-token');
    // The onboarding marker is only presentation state. Keeping it true after
    // credentials have been removed leaves a dead Sync button that can never
    // restore a session. Local loan data is intentionally not touched.
    AppSettings.putPhoneAuthVerified(false);
    AppSettings.putVerifiedPhoneNumber('');
    AppSettings.putVerifiedPhoneCountryCode('');
    await AppSettings.flush();
  }

  Future<void> _storeTokens(
    String accessToken,
    String refreshToken, {
    CloudIdentity? identity,
  }) async {
    final previous = await _readSessionJson();
    final encoded = jsonEncode({
      'access_token': accessToken,
      'refresh_token': refreshToken,
      if (identity != null)
        ...identity.toJson()
      else ...{
        if (previous['user_id'] != null) 'user_id': previous['user_id'],
        if (previous['workspace_id'] != null)
          'workspace_id': previous['workspace_id'],
        if (previous['self_party_id'] != null)
          'self_party_id': previous['self_party_id'],
        if (previous['phone_e164'] != null)
          'phone_e164': previous['phone_e164'],
      },
    });
    await _storage.write(key: _sessionKey, value: encoded);
    await _storage.delete(key: 'loanx.access-token');
    await _storage.delete(key: 'loanx.refresh-token');
  }

  Future<_StoredTokens?> _readTokens() async {
    final value = await _readSessionJson();
    if (value.isNotEmpty) {
      try {
        final access = value['access_token'] as String?;
        final refresh = value['refresh_token'] as String?;
        if (access != null && refresh != null) {
          return _StoredTokens(access, refresh);
        }
      } catch (_) {
        await clearLocalSession();
        return null;
      }
    }
    // One-time migration from the two-record implementation.
    final access = await _storage.read(key: 'loanx.access-token');
    final refresh = await _storage.read(key: 'loanx.refresh-token');
    if (access == null ||
        refresh == null ||
        access.isEmpty ||
        refresh.isEmpty) {
      return null;
    }
    await _storeTokens(access, refresh);
    return _StoredTokens(access, refresh);
  }

  Future<Map<String, dynamic>> _readSessionJson() async {
    final encoded = await _storage.read(key: _sessionKey);
    if (encoded == null || encoded.isEmpty) return <String, dynamic>{};
    try {
      return Map<String, dynamic>.from(jsonDecode(encoded) as Map);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<bool> linkLocalOwner(
    CloudIdentity identity, {
    LoanxDatabasePort? database,
  }) async {
    final db = database ?? await DatabaseHelper.instance.database;
    final owners = await db.query('localOwners');
    if (owners.length != 1) {
      throw StateError('A single local owner is required');
    }
    final owner = owners.single;
    final currentRemoteUser = owner['remoteUserId'] as String?;
    if (currentRemoteUser != null &&
        currentRemoteUser.isNotEmpty &&
        currentRemoteUser != identity.userId) {
      // A device may be shared by a lender and a borrower. Do not relink the
      // previous owner's local workspace to the new account; that would expose
      // or upload private local records. Remote borrower records are queried
      // through the authenticated session instead.
      return false;
    }
    final localOwnerId = owner['id'] as String;
    final localPartyId = owner['selfPartyId'] as String;
    await db.transaction((tx) async {
      await tx.update(
        'localOwners',
        {
          'remoteUserId': identity.userId,
          'remoteWorkspaceId': identity.workspaceId,
          'remotePartyId': identity.selfPartyId,
        },
        where: 'id = ?',
        whereArgs: [localOwnerId],
      );
      await tx.update(
        'parties',
        {
          'userId': identity.userId,
          'phone': identity.phoneE164,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ? AND ownerId = ?',
        whereArgs: [localPartyId, localOwnerId],
      );
    });
    await db.flush();
    return true;
  }

  String _deviceId() {
    var value = AppSettings.getDeviceId();
    if (value.isNotEmpty) return value;
    final random = Random.secure();
    value = base64UrlEncode(List.generate(24, (_) => random.nextInt(256)));
    AppSettings.putDeviceId(value);
    return value;
  }

  String _e164(PhoneNumber p) => CountryCatalog.e164(p.isoCode, p.nsn);

  Future<void> _refreshAccountBootstrap(String accessToken) async {
    final bootstrap = await network.accountBootstrap(
      serverAddress: _address,
      serverName: _name,
      trustedCertificatePem: _certificate,
      deviceId: _deviceId(),
      accessToken: accessToken,
    );
    if (!bootstrap.success) {
      throw StateError(bootstrap.errorMessage ?? 'Account bootstrap failed');
    }
  }
}

class _StoredTokens {
  const _StoredTokens(this.accessToken, this.refreshToken);
  final String accessToken;
  final String refreshToken;
}

AuthClient? activeAuthClient;

class CloudIdentity {
  const CloudIdentity({
    required this.userId,
    required this.workspaceId,
    required this.selfPartyId,
    required this.phoneE164,
  });

  final String userId;
  final String workspaceId;
  final String selfPartyId;
  final String phoneE164;

  Map<String, String> toJson() => {
    'user_id': userId,
    'workspace_id': workspaceId,
    'self_party_id': selfPartyId,
    'phone_e164': phoneE164,
  };
}
