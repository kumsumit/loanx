/// Storage port for small application settings.
///
/// The settings facade deliberately does not expose ToStore types. A future
/// persistence engine only needs another implementation of this interface.
abstract interface class SettingsStore {
  Future<Object?> read(String key);
  Future<void> write(String key, Object? value);
  Future<void> remove(String key);
  Future<void> flush();
}
