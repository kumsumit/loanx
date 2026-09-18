import 'package:loanx/src/rust/frb_generated.dart';

/// Initializes the Rust bridge at most once for the lifetime of the process.
///
/// flutter_rust_bridge rejects a second initialization, while several UI
/// entry points may need to use the network API independently of app startup.
final class RustBridge {
  RustBridge._();

  static Future<void>? _initialization;

  static Future<void> ensureInitialized() {
    final initialization = _initialization;
    if (initialization != null) return initialization;

    final attempt = RustLibApi.init();
    _initialization = attempt;
    attempt.onError((Object _, StackTrace _) {
      // Do not permanently cache a transient library-load failure. A later
      // connected action can safely retry initialization.
      if (identical(_initialization, attempt)) {
        _initialization = null;
      }
    });
    return attempt;
  }
}
