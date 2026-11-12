import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/key_value_store.dart';

/// Almacén cifrado: llavero en iOS y Keystore en Android.
class SecureStore implements KeyValueStore {
  const SecureStore();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
