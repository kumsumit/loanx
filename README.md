# storage_example

Demonstrates how to use the storage plugin.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
# Localization generation

Translations are authored in `assets/translations` and compiled into Dart for
runtime use. Regenerate both Dart files after changing a translation:

```sh
flutter pub run easy_localization:generate -S assets/translations -O lib/l10n -o codegen_loader.g.dart -f json
dart run tool/generate_locale_keys.dart
dart format lib/l10n/codegen_loader.g.dart lib/l10n/locale_keys.g.dart
```
