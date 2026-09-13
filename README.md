# LoanX client

Flutter application for local loan and collateral records, interest estimates,
receipts and Google Drive backup. The separate `../loanx_server/` repository is
reserved for the backend; it currently contains only a Hello World program.

The current application uses legacy SQLCipher loan storage and encrypted
FlatBuffers settings. It does not yet implement the canonical relationship model,
repayment ledger or cloud sync. See [implementation status](IMPLEMENTATION_STATUS.md)
for verified changes and remaining requirements.

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

Local onboarding does not require a phone account or exclusive lender/borrower
role. Google authorization is required only for Drive features. Device
authentication protects access when enabled. Storage initialization errors must
be resolved without deleting existing encrypted data.

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
checksums. Restore validates archive contents, settings and SQL records before
merging; conflicting legacy loan matches abort the SQL transaction. Legacy ZIP
and raw `.db` backups remain supported within validated schema versions 1–7.
Drive generations are retained.

Checksums detect corruption, not authenticity. Archives are not independently
encrypted. SQL and settings restore are not yet one crash-atomic operation, and
snapshot consistency and key migration remain open release requirements. Do not
delete original backups after a restore solely because the operation returned success.

# Localization generation

Translations are authored as ARB files in `lib/l10n` and compiled into Dart for
runtime use. Regenerate both Dart files after changing a translation:

```sh
dart run tool/generate_localizations.dart
dart format lib/l10n/codegen_loader.g.dart lib/l10n/locale_keys.g.dart
```
