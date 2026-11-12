import 'dart:math';

final Random _random = Random.secure();

/// UUID versión 4, para las llaves de idempotencia y la sesión del reloj
/// monótono.
String newUuid() {
  final List<int> bytes =
      List<int>.generate(16, (int _) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int from, int to) {
    final StringBuffer out = StringBuffer();
    for (int i = from; i < to; i++) {
      out.write(bytes[i].toRadixString(16).padLeft(2, '0'));
    }
    return out.toString();
  }

  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
