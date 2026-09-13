# LoanX implementation status

Updated 2026-09-13. This is an implementation checkpoint, not a launch certification.

## Repository assessment

The Flutter client has legacy loan/collateral records in SQLCipher schema v7,
encrypted FlatBuffers settings, Google Drive backup code, receipt printing,
local device authentication and localization. The Rust bridge is a greeting
example. The separate `../loanx_server/` Rust repository is a Hello World program;
the user confirmed this is the intended backend location and authorized replacing
it with the real server in the backend milestone.
There is no operational account backend, repayment ledger, cloud sync or billing.

The application entry was a Rust greeting demo with the original startup
commented out. Loan fields contain participant details and floating-point amounts.
No separate Party/Relationship entities exist. Settlement fields are historical
evidence, not a repayment ledger. Legacy interest conventions include 30-day
months and 120-day quarters; these have not been reinterpreted.

## Current milestone: restore local application and protect existing data

Part 1 implementation verified by host tests, analysis and Android release build.
Android device and live Drive acceptance checks remain open as listed below.

- `lib/main.dart`: restore localized local application, remove mandatory phone
  and exclusive role onboarding, gate workspace access with local authentication,
  isolate optional provider initialization, show storage failure without resetting.
- `lib/provider/provider.dart`: transactionally persist loan insert/update and
  change history; read prior values from storage to avoid mutated UI snapshots;
  remove full loan-row logging.
- `lib/model/loan.dart`: serialize new timestamps in UTC with subsecond precision,
  preserve local presentation, reject nonfinite serialized monetary fields.
- `lib/service/backup_archive.dart`: version 1 manifest with SHA-256 per-file
  checksums, bounded ZIP decoding and explicit file allowlist; legacy ZIP/raw
  database support. Limits: archive 128 MiB, database 120 MiB, settings 4 MiB.
- `lib/service/backup_service.dart`: validate settings before SQL mutation,
  retain Drive generations, avoid interactive authorization in background calls.
- `lib/service/database_helper.dart`: validate schema/integrity and financial
  fields; reject orphan history and conflicting legacy merge matches; reconcile
  inserted values inside the SQL transaction. Schema remains v7.
- Added startup, archive, real SQLite restore and loan/audit rollback tests;
  replaced the obsolete Rust greeting integration assertion with startup smoke coverage.
- `rust_builder/cargokit/gradle/plugin.gradle`: use Android's numeric compile SDK
  property; the previous string conversion failed on AGP's `android-37.0` value.

## Verification evidence

- Before changes: `flutter test --no-pub`: 22 passed, 0 failed.
- `flutter pub get`: passed; dependencies and lockfile resolved.
- `flutter test --no-pub`: **49 passed, 0 failed, 0 skipped**. Includes archive
  corruption/limits, real SQLite restore and transaction rollback, settings
  recovery, UTC round trips and local startup/authentication gates. Coverage not measured.
- `flutter analyze --no-pub`: **no issues found**.
- Changed Dart files formatted; `git diff --check` passed.
- `cargo test --offline` in `../loanx_server/`: compiled successfully, **0 tests**;
  this does not verify a backend implementation.
- First Android release build failed on Cargokit's SDK string parsing; fixed.
  The next `--no-pub` build retained a test-plugin registrant; rebuilding with
  Flutter's default release preparation removed the stale integration-test reference.
  `flutter build apk --release` then **passed**, producing
  `build/app/outputs/flutter-apk/app-release.apk` (92.6 MB reported by Flutter).
- `apksigner verify --print-certs`: passed, signed with the local LoanX certificate
  (not the Android debug certificate). This does not verify Play Store acceptance.
- APK ZIP integrity passed; Rust libraries present for `armeabi-v7a`,
  `arm64-v8a` and `x86_64`.
- `flutter devices` / `flutter emulators`: macOS and Chrome available; no Android
  device or Android emulator. Android startup integration remains unrun.

Reproduce host/build verification from the client directory:

```sh
flutter pub get
dart format lib/main.dart lib/db/fastdb.dart lib/model/loan.dart lib/provider/provider.dart lib/service/backup_archive.dart lib/service/backup_service.dart lib/service/database_helper.dart test integration_test/simple_test.dart
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --release
```

Run the startup integration test on an available supported device. Record target
and signing configuration; a local build is not a production deployment.

## Remaining gates and limitations

| Requirement | Status | Next evidence needed |
| --- | --- | --- |
| Current safety milestone | Verified on host/build; device check open | 49 tests, clean analysis, signed APK; Android device smoke test still needed |
| Canonical owner/User/Party/Relationship/Loan model | Not started | Additive migration, reference and amount reconciliation |
| Exact financial engine and repayment ledger | Not started | Versioned contracts, allocation/reversal/idempotency tests |
| Borrower and lender views | Not started | Local repository-backed flows supporting both directions |
| Collateral lifecycle and private attachments | Not started | Offline files, lifecycle and ownership tests |
| Crash-safe complete backup/restore | In progress | SQL/settings/files atomic recovery and consistent snapshot tests |
| Authentication and verified linking | Not started | Real provider integration and consent/authorization tests |
| Sync, queue, multi-device, entitlements | Not started | Backend and offline retry/conflict/security tests |
| Notifications and connections | Not started | Durable idempotent workflows and provider verification |
| Production security and release | Not started | Dependency audit, signing/build, secrets and operational checks |

Restore currently merges SQL transactionally, then writes settings separately;
a settings disk failure after SQL commit is not crash-atomic. Backup snapshot
creation still checkpoints and reads the live database without a full write
barrier. The archive is not independently encrypted and settings include private
data. SQLCipher still uses the legacy embedded key; rotating it requires a
recoverable migration. Legacy identity matching rejects conflicts but cannot
reliably distinguish identical independent loans. Financial doubles, editable
legacy balances/settlements and destructive deletion remain to be replaced.

No live Drive round trip, canonical migration, server authorization, sync,
subscription, notification or release acceptance criterion is verified. Preserve
original data while resolving these gaps; do not call the product launch-ready.
