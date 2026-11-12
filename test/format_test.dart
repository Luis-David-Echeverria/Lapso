import 'package:flutter_test/flutter_test.dart';
import 'package:lapso_jornada/domain/format.dart';
import 'package:lapso_jornada/domain/models.dart';

void main() {
  test('horas y duraciones', () {
    expect(hhmm(DateTime(2026, 11, 10, 8, 5)), '08:05');
    expect(hhmmss(DateTime(2026, 11, 10, 8, 5, 9)), '08:05:09');
    expect(
      clock(const Duration(hours: 3, minutes: 42, seconds: 15)),
      '03:42:15',
    );
    expect(minSec(const Duration(minutes: 14, seconds: 7)), '14:07');
    expect(human(const Duration(minutes: 58)), '58 min');
    expect(human(const Duration(hours: 8, minutes: 6)), '8 h 06 min');
    expect(spoken(const Duration(hours: 1, minutes: 1)), '1 hora 1 minuto');
    expect(
      spoken(const Duration(hours: 3, minutes: 42)),
      '3 horas 42 minutos',
    );
  });

  test('las duraciones negativas se muestran en cero', () {
    expect(clock(const Duration(seconds: -5)), '00:00:00');
    expect(human(const Duration(minutes: -5)), '0 min');
  });

  test('fechas en español', () {
    final DateTime d = DateTime(2026, 11, 10, 9, 14);
    expect(longDate(d), 'Martes 10 de noviembre de 2026');
    expect(dayDate(d), 'Martes 10 de noviembre');
    expect(shortDate(d), 'mar 10 nov');
    expect(numericDate(d), '10 nov 2026');
    expect(dateTime(d), '10 nov 2026, 09:14');
    expect(monthYear(d), 'Noviembre 2026');
  });

  test('día relativo', () {
    final DateTime now = DateTime(2026, 11, 10, 9);
    expect(relativeDay(DateTime(2026, 11, 10, 23), now), 'Hoy');
    expect(relativeDay(DateTime(2026, 11, 9, 1), now), 'Ayer');
    expect(relativeDay(DateTime(2026, 11, 8), now), '');
  });

  test('fecha para el servidor', () {
    expect(isoDate(DateTime(2026, 3, 7, 22, 15)), '2026-03-07');
  });

  test('huella abreviada', () {
    final String hash = 'a3f97c1e${'0' * 52}0b42';
    expect(shortHash(hash), 'a3f9 7c1e … 0b42');
    expect(shortHash('abc'), 'abc');
  });

  test('resumen de evidencia', () {
    expect(evidenceSummary(Evidence.none), '');
    expect(
      evidenceSummary(
        const Evidence(
          qrRead: true,
          location: LocationResult.dentro,
          photoTaken: true,
        ),
      ),
      'QR, ubicación y foto',
    );
    expect(
      evidenceSummary(
        const Evidence(
          qrRead: true,
          location: LocationResult.dentro,
          photoTaken: false,
        ),
      ),
      'QR y ubicación · sin foto',
    );
    expect(
      evidenceSummary(
        const Evidence(
          qrRead: false,
          location: LocationResult.sinPermiso,
          photoTaken: false,
        ),
      ),
      'Sin QR, ubicación y foto',
    );
    expect(
      evidenceSummary(
        const Evidence(qrRead: true, location: LocationResult.fuera),
      ),
      'QR y ubicación fuera de zona',
    );
  });
}
