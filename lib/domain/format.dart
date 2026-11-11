/// Formatos de fecha y hora en español. Dart puro, sin `intl`.
library;

import 'models.dart';

const List<String> _weekdays = <String>[
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

const List<String> _weekdaysShort = <String>[
  'lun',
  'mar',
  'mié',
  'jue',
  'vie',
  'sáb',
  'dom',
];

const List<String> _months = <String>[
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

const List<String> _monthsShort = <String>[
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

String two(int n) => n.toString().padLeft(2, '0');

String capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// 08:58
String hhmm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

/// 08:58:12
String hhmmss(DateTime d) => '${hhmm(d)}:${two(d.second)}';

/// 03:42:15
String clock(Duration d) {
  final int s = d.inSeconds < 0 ? 0 : d.inSeconds;
  return '${two(s ~/ 3600)}:${two((s % 3600) ~/ 60)}:${two(s % 60)}';
}

/// 23:40 (minutos y segundos)
String minSec(Duration d) {
  final int s = d.inSeconds < 0 ? 0 : d.inSeconds;
  return '${two(s ~/ 60)}:${two(s % 60)}';
}

/// 8 h 16 min · 58 min
String human(Duration d) {
  final int m = d.inMinutes < 0 ? 0 : d.inMinutes;
  final int h = m ~/ 60;
  final int r = m % 60;
  if (h == 0) return '$r min';
  return '$h h ${two(r)} min';
}

/// Para lectores de pantalla: "3 horas 42 minutos".
String spoken(Duration d) {
  final int m = d.inMinutes < 0 ? 0 : d.inMinutes;
  final int h = m ~/ 60;
  final int r = m % 60;
  final String hours = h == 1 ? '1 hora' : '$h horas';
  final String mins = r == 1 ? '1 minuto' : '$r minutos';
  if (h == 0) return mins;
  return '$hours $mins';
}

/// Martes 10 de noviembre de 2026
String longDate(DateTime d) => capitalize(
    '${_weekdays[d.weekday - 1]} ${d.day} de ${_months[d.month - 1]} de ${d.year}');

/// Martes 10 de noviembre
String dayDate(DateTime d) =>
    capitalize('${_weekdays[d.weekday - 1]} ${d.day} de ${_months[d.month - 1]}');

/// mar 10 nov
String shortDate(DateTime d) =>
    '${_weekdaysShort[d.weekday - 1]} ${d.day} ${_monthsShort[d.month - 1]}';

/// 10 nov 2026
String numericDate(DateTime d) =>
    '${d.day} ${_monthsShort[d.month - 1]} ${d.year}';

/// 10 nov 2026, 09:14
String dateTime(DateTime d) => '${numericDate(d)}, ${hhmm(d)}';

/// Noviembre 2026
String monthYear(DateTime d) =>
    capitalize('${_months[d.month - 1]} ${d.year}');

/// Hoy, Ayer o vacío.
String relativeDay(DateTime d, DateTime now) {
  final DateTime a = DateTime(d.year, d.month, d.day);
  final DateTime b = DateTime(now.year, now.month, now.day);
  final int diff = b.difference(a).inDays;
  if (diff == 0) return 'Hoy';
  if (diff == 1) return 'Ayer';
  return '';
}

String eventLabel(TimeEvent e) {
  switch (e.type) {
    case EventType.entrada:
      return 'Entrada';
    case EventType.salida:
      return 'Salida';
    case EventType.pausaInicio:
      return 'Inicio de pausa';
    case EventType.pausaFin:
      return 'Jornada reanudada';
  }
}

String pauseLabel(PauseType p) {
  switch (p) {
    case PauseType.comida:
      return 'Comida';
    case PauseType.personal:
      return 'Personal';
    case PauseType.autorizada:
      return 'Autorizada';
    case PauseType.otra:
      return 'Otra';
  }
}

String locationLabel(LocationResult r) {
  switch (r) {
    case LocationResult.dentro:
      return 'Dentro de la zona';
    case LocationResult.dentroBajaPrecision:
      return 'Dentro, precisión baja';
    case LocationResult.fuera:
      return 'Fuera de la zona';
    case LocationResult.sinPermiso:
      return 'Sin permiso';
    case LocationResult.sinConsentimiento:
      return 'Sin consentimiento';
    case LocationResult.noDisponible:
      return 'No disponible';
  }
}

/// Huella abreviada: a3f9 7c1e … 0b42
String shortHash(String hash) {
  if (hash.length < 12) return hash;
  final String a = hash.substring(0, 4);
  final String b = hash.substring(4, 8);
  final String c = hash.substring(hash.length - 4);
  return '$a $b … $c';
}

/// Resumen de la evidencia de un registro: "QR, ubicación y foto".
String evidenceSummary(Evidence e) {
  final List<String> got = <String>[];
  final List<String> missing = <String>[];
  if (e.qrRead != null) (e.qrRead! ? got : missing).add('QR');
  if (e.location != null) (e.locationOk ? got : missing).add('ubicación');
  if (e.photoTaken != null) (e.photoTaken! ? got : missing).add('foto');
  String join(List<String> xs) {
    if (xs.length <= 1) return xs.join();
    return '${xs.sublist(0, xs.length - 1).join(', ')} y ${xs.last}';
  }

  if (got.isEmpty && missing.isEmpty) return '';
  if (missing.isEmpty) return capitalize(join(got));
  if (got.isEmpty) return 'Sin ${join(missing)}';
  return '${capitalize(join(got))} · sin ${join(missing)}';
}
