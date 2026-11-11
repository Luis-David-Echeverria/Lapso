/// Modelos de dominio. Sin dependencias de Flutter para poder probarlos solos.
library;

enum EventType { entrada, salida, pausaInicio, pausaFin }

enum PauseType { comida, personal, autorizada, otra }

enum WorkStatus { sinEntrada, enJornada, enPausa, terminada }

/// Resultado de la única lectura de ubicación que se hace al registrar.
enum LocationResult {
  dentro,
  dentroBajaPrecision,
  fuera,
  sinPermiso,
  sinConsentimiento,
  noDisponible,
}

/// Capturas que el trabajador puede aceptar o retirar.
enum Capability { ubicacion, foto }

/// Evidencia que acompaña a un registro. Un registro nunca se pierde por
/// falta de evidencia: se guarda y queda marcado.
class Evidence {
  const Evidence({this.qrRead, this.location, this.photoTaken});

  /// `null` si el centro no pide QR.
  final bool? qrRead;

  /// `null` si el centro no pide ubicación.
  final LocationResult? location;

  /// `null` si el centro no pide foto.
  final bool? photoTaken;

  static const Evidence none = Evidence();

  bool get locationOk =>
      location == LocationResult.dentro ||
      location == LocationResult.dentroBajaPrecision;
}

class TimeEvent {
  const TimeEvent({
    required this.id,
    required this.type,
    required this.at,
    this.pauseType,
    this.seq,
    this.hash,
    this.offline = false,
    this.evidence = Evidence.none,
  });

  final String id;
  final EventType type;
  final DateTime at;
  final PauseType? pauseType;

  /// Número de evento. Lo asigna el servidor; `null` mientras no se envía.
  final int? seq;

  /// Huella del registro. La asigna el servidor.
  final String? hash;

  /// Se registró sin conexión, con la hora declarada por el teléfono.
  final bool offline;
  final Evidence evidence;

  bool get pending => seq == null;

  TimeEvent accepted({required int seq, required String hash}) {
    return TimeEvent(
      id: id,
      type: type,
      at: at,
      pauseType: pauseType,
      seq: seq,
      hash: hash,
      offline: offline,
      evidence: evidence,
    );
  }
}

/// Registro sin conexión que el servidor no aceptó.
class Rejection {
  const Rejection({required this.event, required this.reason});
  final TimeEvent event;
  final String reason;
}

/// Consulta de la ubicación o la foto de un trabajador.
class EvidenceView {
  const EvidenceView({
    required this.viewer,
    required this.what,
    required this.eventLabel,
    required this.reason,
    required this.at,
  });
  final String viewer;
  final Capability what;
  final String eventLabel;
  final String reason;
  final DateTime at;
}

class Organization {
  const Organization({required this.slug, required this.name});
  final String slug;
  final String name;
}

/// Configuración del centro de trabajo del empleado.
class WorkCenter {
  const WorkCenter({
    required this.name,
    required this.startHour,
    required this.endHour,
    required this.mealMinutes,
    required this.requiresQr,
    required this.requiresLocation,
    required this.requiresPhoto,
  });
  final String name;
  final int startHour;
  final int endHour;
  final int mealMinutes;
  final bool requiresQr;
  final bool requiresLocation;
  final bool requiresPhoto;
}

class Employee {
  const Employee({required this.number, required this.name});
  final String number;
  final String name;

  String get firstName => name.split(' ').first;

  String get initials {
    final List<String> parts =
        name.split(' ').where((String p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}

/// Resumen de un día: una jornada con sus registros.
class DaySummary {
  const DaySummary({
    required this.day,
    required this.events,
    required this.status,
    required this.worked,
    required this.pauses,
  });

  final DateTime day;
  final List<TimeEvent> events;
  final WorkStatus status;
  final Duration worked;
  final Duration pauses;

  TimeEvent? get entry {
    for (final TimeEvent e in events) {
      if (e.type == EventType.entrada) return e;
    }
    return null;
  }

  TimeEvent? get exit {
    for (final TimeEvent e in events.reversed) {
      if (e.type == EventType.salida) return e;
    }
    return null;
  }

  Duration get presence => worked + pauses;
  bool get incomplete => events.isNotEmpty && exit == null;
}
