# LoanX client

Flutter application for local loan and collateral records, interest estimates,
receipts and Google Drive backup. The separate `../loanx_server/` repository is
an implemented Rust/PostgreSQL/QUIC backend foundation. New standalone lender
loans now use a durable client queue and the server's idempotent `loan/create`
mutation; pull synchronization and full loan-update reconciliation are not
yet wired end to end.

The current application uses encrypted ToStore local storage. Canonical identity,
exact-money, repayment and connected repositories exist, but the visible lender
flow still uses the legacy floating-point Loan model. See [implementation
status](IMPLEMENTATION_STATUS.md) and the
[repository feature-gap audit](../docs/feature-gap-audit-2026-09-16.md).

## Local development

Use a Flutter installation compatible with the Dart constraint in `pubspec.yaml`,
Rust/Cargo for the native bridge, and the Android SDK/NDK versions configured in
`android/app/build.gradle.kts`. Several dependencies are Git forks; keep lockfiles
and avoid unrelated dependency upgrades.

```sh
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
flutter run
```

`flutter run` without Dart defines is intentionally a local-only build. To
enable connected borrower/lender features, provide the server address, TLS
server name, and base64-encoded trusted certificate described in
`../loanx_server/README.md`, for example:

```sh
flutter run \
  --dart-define=LOANX_SERVER_ADDRESS=127.0.0.1:4433 \
  --dart-define=LOANX_SERVER_NAME=localhost \
  --dart-define=LOANX_SERVER_CERTIFICATE_BASE64="$(base64 < ../certs/cert.pem | tr -d '\n')"
```

Without these values, cloud refreshes are skipped and local loan management
continues to work.

Current onboarding requires phone OTP before workspace access. A failed session
refresh can also return an offline user to OTP; this is a known local-first
release blocker rather than intended behavior. The lender/borrower/both choice is
a presentation preference, not a permanent authorization role. Google
authorization is required only for Drive features. Device authentication protects
access when enabled. Storage initialization errors must be resolved without
deleting existing encrypted data.

## Android verification

```sh
flutter build apk --release
flutter test integration_test/simple_test.dart -d DEVICE_ID
```

Use an available Android test device for the integration command. Release signing
uses local `android/key.properties`; the existing build configuration falls back
to debug signing when those values are missing. A successful release-mode build
alone is not evidence of production signing or readiness. Never commit signing
credentials or keystores.

Keep Flutter's default preparation step for release builds. With this installed
SDK, `--no-pub` can retain a development plugin registrant from an earlier test
or pub command and cause a missing `IntegrationTestPlugin` compilation error.

## Backup compatibility

New `.loanxbackup` archives contain a versioned manifest and per-file SHA-256
checksums. Restore validates archive structure, checksums and settings before
asking ToStore to restore the database. Drive generations are retained.

Checksums detect corruption, not authenticity. Archives are not independently
encrypted or authenticated. Database and settings restore are not one
crash-atomic operation; attachments are unsupported; financial reconciliation,
snapshot consistency and cross-device encryption-key recovery remain open release
requirements. Do not delete original backups solely because restore returned
success.

## Current verification caveat

On 2026-09-16 static analysis passed, but the Flutter suite stalled reproducibly
in the borrower onboarding startup test after 85 passing tests. Treat the suite as
failing until that test completes normally. Newer screens also emit missing
localization-key warnings, and most non-English ARB files are missing 44 keys
present in English.

# Localization generation

Translations are authored as ARB files in `lib/l10n` and compiled into Dart for
runtime use. Regenerate both Dart files after changing a translation:

```sh
dart run tool/generate_localizations.dart
dart format lib/l10n/codegen_loader.g.dart lib/l10n/locale_keys.g.dart
```
