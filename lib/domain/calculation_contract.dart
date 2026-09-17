/// Versioned calculation policies attached to a loan at creation time.
///
/// A contract is immutable: changing it would reinterpret an existing
/// financial history. `legacyV1` is retained only for records created under
/// the pre-exact calculation implementation.
abstract final class CalculationContract {
  static const legacyV1 = 'legacy-v1';
  static const exactV1 = 'exact-v1';

  /// The policy used when this version of the application creates a loan.
  static const current = exactV1;

  static bool isSupported(String value) =>
      value == legacyV1 || value == exactV1;
}
