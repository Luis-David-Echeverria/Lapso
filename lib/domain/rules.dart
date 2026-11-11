/// Reglas de negocio de la jornada y del PIN. Dart puro.
library;

import 'models.dart';

/// Horas tras las cuales una jornada abierta dispara el aviso de jornada larga.
const int kLongSessionHours = 16;

/// Minutos de bloqueo tras agotar los intentos de PIN.
const int kLockMinutes = 15;

/// Intentos de PIN antes del bloqueo.
const int kMaxPinAttempts = 3;

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
      if (status == WorkStatus.enPausa) {
        return 'Para registrar tu salida, primero reanuda tu jornada.';
      }
      if (status != WorkStatus.enJornada) {
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

/// Agrupa registros en resúmenes por día, del más reciente al más antiguo.
DaySummary summarizeDay(DateTime day, List<TimeEvent> all, DateTime now) {
  final List<TimeEvent> events = all
      .where((TimeEvent e) => isSameDay(e.at, day))
      .toList(growable: false);
  final List<TimeEvent> shift = currentShift(events);
  final DateTime ref = isSameDay(day, now)
      ? now
      : (shift.isEmpty ? day : shift.last.at);
  return DaySummary(
    day: dayOf(day),
    events: events,
    status: statusOf(shift),
    worked: workedOf(shift, ref),
    pauses: pausesOf(shift, ref),
  );
}
