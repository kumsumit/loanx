import 'package:loanx/src/rust/frb_generated.dart';

/// Initializes the Rust bridge at most once for the lifetime of the process.
///
/// flutter_rust_bridge rejects a second initialization, while several UI
/// entry points may need to use the network API independently of app startup.
final class RustBridge {
  RustBridge._();

  static Future<void>? _initialization;

  static Future<void> ensureInitialized() {
    return _initialization ??= RustLib.init();
  }
}
