/// Reglas de negocio de la jornada y del PIN. Dart puro.
library;

import 'models.dart';

/// Horas tras las cuales una jornada abierta dispara el aviso de jornada larga.
const int kLongSessionHours = 16;

/// Minutos de bloqueo tras agotar los intentos de PIN.
const int kLockMinutes = 15;

/// Intentos fallidos de PIN que bloquean la cuenta (lo aplica el servidor).
const int kMaxPinAttempts = 5;

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// Registros de la jornada vigente: desde la última entrada.
List<TimeEvent> currentShift(List<TimeEvent> events) {
  int start = -1;
  for (int i = events.length - 1; i >= 0; i--) {
    if (events[i].type == EventType.entrada) {
      start = i;
      break;
    }
  }
  if (start < 0) return const <TimeEvent>[];
  return events.sublist(start);
}

WorkStatus statusOf(List<TimeEvent> shift) {
  if (shift.isEmpty) return WorkStatus.sinEntrada;
  switch (shift.last.type) {
    case EventType.entrada:
    case EventType.pausaFin:
      return WorkStatus.enJornada;
    case EventType.pausaInicio:
      return WorkStatus.enPausa;
    case EventType.salida:
      return WorkStatus.terminada;
  }
}

/// Tiempo total en pausa de una jornada. Una pausa abierta cuenta hasta [now].
Duration pausesOf(List<TimeEvent> shift, DateTime now) {
  Duration total = Duration.zero;
  DateTime? open;
  for (final TimeEvent e in shift) {
    if (e.type == EventType.pausaInicio) {
      open = e.at;
    } else if (open != null &&
        (e.type == EventType.pausaFin || e.type == EventType.salida)) {
      total += e.at.difference(open);
      open = null;
    }
  }
  if (open != null && now.isAfter(open)) total += now.difference(open);
  return total;
}

/// Tiempo trabajado: presencia menos pausas.
Duration workedOf(List<TimeEvent> shift, DateTime now) {
  if (shift.isEmpty) return Duration.zero;
  final DateTime start = shift.first.at;
  final DateTime end =
      shift.last.type == EventType.salida ? shift.last.at : now;
  final Duration presence = end.difference(start);
  final Duration worked = presence - pausesOf(shift, end);
  return worked.isNegative ? Duration.zero : worked;
}

/// Inicio de la pausa abierta, si la hay.
TimeEvent? openPause(List<TimeEvent> shift) {
  if (shift.isEmpty || shift.last.type != EventType.pausaInicio) return null;
  return shift.last;
}

/// Devuelve `null` si [type] se puede registrar en [status]; si no, el motivo.
String? validateNext(WorkStatus status, EventType type) {
  switch (type) {
    case EventType.entrada:
      if (status == WorkStatus.enJornada || status == WorkStatus.enPausa) {
        return 'Ya tienes una jornada abierta. Registra primero tu salida.';
      }
      return null;
    case EventType.salida:
      // Con una pausa abierta la salida procede: el servidor cierra la pausa
      // en el mismo instante.
      if (status != WorkStatus.enJornada && status != WorkStatus.enPausa) {
        return 'No tienes una jornada abierta.';
      }
      return null;
    case EventType.pausaInicio:
      if (status == WorkStatus.enPausa) {
        return 'Ya tienes una pausa en curso.';
      }
      if (status != WorkStatus.enJornada) {
        return 'Solo puedes iniciar una pausa durante tu jornada.';
      }
      return null;
    case EventType.pausaFin:
      if (status != WorkStatus.enPausa) {
        return 'No tienes una pausa en curso.';
      }
      return null;
  }
}

/// Lo que se puede registrar en [status]. Solo se usa cuando no hay
/// respuesta del servidor (registros sin conexión); con conexión manda
/// `allowed_actions`.
Set<EventType> actionsFor(WorkStatus status) {
  return <EventType>{
    for (final EventType t in EventType.values)
      if (validateNext(status, t) == null) t,
  };
}

/// Estado que resulta de aplicar [type] sobre [status].
WorkStatus applyEvent(WorkStatus status, EventType type) {
  switch (type) {
    case EventType.entrada:
    case EventType.pausaFin:
      return WorkStatus.enJornada;
    case EventType.pausaInicio:
      return WorkStatus.enPausa;
    case EventType.salida:
      return WorkStatus.terminada;
  }
}

/// La jornada lleva más de [kLongSessionHours] horas sin salida.
bool isLongSession(List<TimeEvent> shift, DateTime now) {
  final WorkStatus s = statusOf(shift);
  if (s != WorkStatus.enJornada && s != WorkStatus.enPausa) return false;
  return now.difference(shift.first.at).inHours >= kLongSessionHours;
}

/// Valida un PIN nuevo. Devuelve `null` si es válido; si no, el motivo.
String? validateNewPin(
  String pin, {
  required String employeeNumber,
  String? currentPin,
}) {
  if (pin.length != 6 || int.tryParse(pin) == null) {
    return 'El PIN debe tener seis dígitos.';
  }
  if (pin.split('').toSet().length == 1) {
    return 'No uses seis dígitos iguales.';
  }
  if (_isSequence(pin)) {
    return 'No uses una secuencia como 123456 o 654321.';
  }
  if (_isRepeatedGroup(pin)) {
    return 'No uses grupos repetidos como 121212 o 123123.';
  }
  final String digits = employeeNumber.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isNotEmpty) {
    final bool matches = digits.length >= 4
        ? pin.contains(digits) || digits.contains(pin)
        : pin == digits.padLeft(6, '0');
    if (matches) return 'No uses tu número de empleado.';
  }
  if (currentPin != null && pin == currentPin) {
    return 'El PIN nuevo debe ser distinto al actual.';
  }
  return null;
}

bool _isSequence(String pin) {
  bool up = true;
  bool down = true;
  for (int i = 1; i < pin.length; i++) {
    final int diff = pin.codeUnitAt(i) - pin.codeUnitAt(i - 1);
    if (diff != 1) up = false;
    if (diff != -1) down = false;
  }
  return up || down;
}

bool _isRepeatedGroup(String pin) {
  final String a = pin.substring(0, 2);
  if (pin == a * 3) return true;
  final String b = pin.substring(0, 3);
  return pin == b * 2;
}

/// Resume un día a partir de sus registros. Lo usa el servidor simulado;
/// con el servidor real los números del historial vienen ya calculados.
DaySummary summarizeDay(DateTime day, List<TimeEvent> all, DateTime now) {
  final List<TimeEvent> events = all
      .where((TimeEvent e) => isSameDay(e.at, day))
      .toList(growable: false);
  final List<TimeEvent> shift = currentShift(events);
  final bool today = isSameDay(day, now);
  final DateTime ref = today ? now : (shift.isEmpty ? day : shift.last.at);
  final WorkStatus status = statusOf(shift);
  final bool closed = status == WorkStatus.terminada;
  return DaySummary(
    day: dayOf(day),
    events: events,
    status: status,
    worked: workedOf(shift, ref),
    pauses: pausesOf(shift, ref),
    start: shift.isEmpty ? null : shift.first.at,
    end: closed ? shift.last.at : null,
    incomplete: shift.isNotEmpty && !closed && !today,
    canRequestCorrection: shift.isNotEmpty && !today,
  );
}

final RegExp _qrToken = RegExp(r'^[A-Za-z0-9_-]{16,64}$');
final RegExp _qrCode = RegExp(r'^[A-Za-z0-9_-]{16}$');
final RegExp _slug = RegExp(r'^[a-z0-9][a-z0-9-]{1,62}$');

/// Interpreta el contenido de un QR de Lapso.
///
/// Supuesto por confirmar con backend: el QR trae una dirección cuyo último
/// tramo de la ruta es el token y cuyo parámetro `k` es el código cambiante.
/// También se acepta el token solo.
QrReading? parseQrPayload(String payload) {
  final String text = payload.trim();
  if (text.isEmpty) return null;
  if (_qrToken.hasMatch(text)) return QrReading(token: text);
  final Uri? uri = Uri.tryParse(text);
  if (uri == null || !uri.hasScheme) return null;
  final List<String> segments =
      uri.pathSegments.where((String s) => s.isNotEmpty).toList();
  if (segments.isEmpty || !_qrToken.hasMatch(segments.last)) return null;
  final String? code = uri.queryParameters['k'];
  return QrReading(
    token: segments.last,
    rotatingCode: code != null && _qrCode.hasMatch(code) ? code : null,
  );
}

/// Saca el identificador de la organización de lo que la persona escribió o
/// pegó: el código tal cual o un enlace que lo trae al final de la ruta.
///
/// Supuesto por confirmar con backend: el formato del enlace.
String? parseOrganizationCode(String input) {
  final String text = input.trim().toLowerCase();
  if (text.isEmpty) return null;
  if (_slug.hasMatch(text)) return text;
  final Uri? uri = Uri.tryParse(text);
  if (uri == null || !uri.hasScheme) return null;
  final String? named =
      uri.queryParameters['tenant'] ?? uri.queryParameters['org'];
  if (named != null && _slug.hasMatch(named)) return named;
  final List<String> segments =
      uri.pathSegments.where((String s) => s.isNotEmpty).toList();
  if (segments.isNotEmpty && _slug.hasMatch(segments.last)) {
    return segments.last;
  }
  return null;
}
