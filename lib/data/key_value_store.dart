/// Almacén pequeño de texto en el teléfono: la organización elegida, la
/// sesión, la copia de la última respuesta y la cola sin conexión.
///
/// La implementación real (`SecureStore`) usa el llavero de iOS y el
/// Keystore de Android, así que lo guardado queda cifrado.
abstract class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Almacén en memoria, para pruebas y para el modo de demostración.
class MemoryStore implements KeyValueStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}
