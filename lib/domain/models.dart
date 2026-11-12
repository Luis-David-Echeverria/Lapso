/// Modelos de dominio. Sin dependencias de Flutter para poder probarlos solos.
///
/// Siguen el contrato 0.9.0 de la API (`Lapso-Contrato/api`), reducidos a lo
/// que las pantallas muestran.
library;

enum EventType { entrada, salida, pausaInicio, pausaFin }

enum PauseType { comida, personal, autorizada, otra }

enum WorkStatus { sinEntrada, enJornada, enPausa, terminada }

/// Resultado de la única lectura de ubicación que se hace al registrar.
enum LocationResult {
  /// Dentro de la zona del centro.
  dentro,

  /// Dentro, pero con una precisión que no descarta que estuviera fuera.
  dentroBajaPrecision,
  fuera,

  /// Se capturó, pero el centro no tiene zona configurada.
  capturada,
  sinPermiso,
  sinConsentimiento,
  noDisponible,
}

/// Capturas con datos personales, que el trabajador acepta o retira.
enum Capability { ubicacion, foto }

/// Cómo pide el centro cada captura.
enum CaptureMode { off, optional, required }

/// Estado de la aceptación del aviso para una captura.
enum ConsentStatus { none, accepted, revoked, outdated }

/// Regla de una captura (ubicación, QR o foto) en el centro del trabajador.
class CaptureRule {
  const CaptureRule({
    this.mode = CaptureMode.off,
    this.eventTypes = const <EventType>{},
    this.active = false,
    this.consent,
  });

  final CaptureMode mode;

  /// En qué registros se pide.
  final Set<EventType> eventTypes;

  /// La app debe pedirla: el modo no es apagado y, si recolecta datos
  /// personales, la persona tiene la aceptación vigente. Si no está activa,
  /// la app no pide el permiso del sistema.
  final bool active;

  /// `null` para el QR, que no recolecta datos personales.
  final ConsentStatus? consent;

  static const CaptureRule off = CaptureRule();

  /// El centro la pide para este tipo de registro.
  bool asks(EventType type) =>
      mode != CaptureMode.off && eventTypes.contains(type);

  bool get accepted => consent == ConsentStatus.accepted;

  /// Falta preguntarle a la persona (nunca aceptó, o el aviso cambió).
  bool get needsAnswer =>
      mode != CaptureMode.off &&
      (consent == ConsentStatus.none || consent == ConsentStatus.outdated);
}

/// Lo que la app captura al registrar y los parámetros del modo sin conexión.
class CaptureSettings {
  const CaptureSettings({
    required this.workCenterName,
    this.zoneConfigured = false,
    this.noticeVersion,
    this.location = CaptureRule.off,
    this.qr = CaptureRule.off,
    this.photo = CaptureRule.off,
    this.qrRotationSeconds = 60,
    this.offlineAllowed = false,
    this.offlineMaxAgeHours = 24,
    this.clockToleranceSeconds = 120,
  });

  final String workCenterName;
  final bool zoneConfigured;

  /// Versión vigente del aviso de privacidad. Se manda al aceptar.
  final int? noticeVersion;
  final CaptureRule location;
  final CaptureRule qr;
  final CaptureRule photo;
  final int qrRotationSeconds;
  final bool offlineAllowed;
  final int offlineMaxAgeHours;
  final int clockToleranceSeconds;

  static const CaptureSettings none = CaptureSettings(workCenterName: '');

  CaptureRule rule(Capability c) {
    switch (c) {
      case Capability.ubicacion:
        return location;
      case Capability.foto:
        return photo;
    }
  }
}

/// Evidencia de un registro, como la muestra la app. Un registro nunca se
/// pierde por falta de evidencia: se guarda y queda marcado.
class Evidence {
  const Evidence({
    this.qrRead,
    this.location,
    this.photoTaken,
    this.photoAvailable = false,
    this.requiredMissing = false,
  });

  /// `null` si el centro no pide QR.
  final bool? qrRead;

  /// `null` si el centro no pide ubicación.
  final LocationResult? location;

  /// `null` si el centro no pide foto.
  final bool? photoTaken;

  /// La foto sigue guardada en el servidor y se puede consultar.
  final bool photoAvailable;

  /// Faltó alguna captura que el centro marca como obligatoria.
  final bool requiredMissing;

  static const Evidence none = Evidence();

  bool get locationOk =>
      location == LocationResult.dentro ||
      location == LocationResult.dentroBajaPrecision ||
      location == LocationResult.capturada;

  /// No faltó nada de lo que se pidió.
  bool get complete =>
      qrRead != false &&
      (location == null || locationOk) &&
      photoTaken != false;
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
    this.clockSuspect = false,
    this.evidence = Evidence.none,
  });

  /// Identificador del servidor o, si aún no se envía, la llave de
  /// idempotencia que generó el teléfono.
  final String id;
  final EventType type;

  /// Hora efectiva del registro, en la hora local del teléfono.
  final DateTime at;
  final PauseType? pauseType;

  /// Número de evento. Lo asigna el servidor; `null` mientras no se envía.
  final int? seq;

  /// Huella del registro. La asigna el servidor.
  final String? hash;

  /// Se registró sin conexión, con la hora declarada por el teléfono.
  final bool offline;

  /// El servidor detectó que el reloj del teléfono no coincidía.
  final bool clockSuspect;
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
      clockSuspect: clockSuspect,
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

/// Consulta que otra persona hizo de la ubicación o la foto del trabajador.
class EvidenceView {
  const EvidenceView({
    required this.viewerName,
    required this.viewerRole,
    required this.what,
    required this.at,
    this.eventId,
  });
  final String viewerName;
  final String viewerRole;
  final Capability what;
  final DateTime at;
  final String? eventId;
}

class Organization {
  const Organization({
    required this.slug,
    required this.name,
    this.contactEmail,
    this.contactPhone,
  });
  final String slug;
  final String name;

  /// Contacto público para dudas y derechos sobre los datos personales.
  final String? contactEmail;
  final String? contactPhone;
}

/// Contacto de soporte de la organización (solo con sesión).
class SupportContact {
  const SupportContact({this.email, this.phone});
  final String? email;
  final String? phone;

  static const SupportContact none = SupportContact();
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

/// Quien inició sesión.
class Session {
  const Session({
    required this.displayName,
    required this.mustChangePin,
    required this.organization,
    this.isWorker = true,
    this.unreadNotices = 0,
  });
  final String displayName;
  final bool mustChangePin;
  final Organization organization;
  final bool isWorker;
  final int unreadNotices;
}

/// Pantalla «Mi jornada»: lo que el servidor sabe de hoy.
class TodaySnapshot {
  const TodaySnapshot({
    required this.status,
    required this.allowedActions,
    required this.events,
    required this.serverTime,
    this.employee,
    this.workCenterName,
    this.sessionStart,
    this.worked = Duration.zero,
    this.pauses = Duration.zero,
    this.scheduledEnd,
    this.lastEvent,
    this.hasIncompleteSession = false,
    this.pendingCorrections = 0,
  });

  final WorkStatus status;

  /// Lo que el servidor aceptaría en este momento.
  final Set<EventType> allowedActions;

  /// Registros de la jornada vigente (o de la última de hoy).
  final List<TimeEvent> events;
  final DateTime serverTime;
  final Employee? employee;
  final String? workCenterName;

  /// Inicio de la jornada vigente.
  final DateTime? sessionStart;

  /// Totales de hoy según el servidor. Con una jornada abierta, la app
  /// calcula el tiempo en vivo a partir de [events].
  final Duration worked;
  final Duration pauses;
  final DateTime? scheduledEnd;
  final TimeEvent? lastEvent;

  /// Hay una jornada sin salida en los últimos 7 días.
  final bool hasIncompleteSession;
  final int pendingCorrections;

  static final TodaySnapshot empty = TodaySnapshot(
    status: WorkStatus.sinEntrada,
    allowedActions: const <EventType>{EventType.entrada},
    events: const <TimeEvent>[],
    serverTime: DateTime.fromMillisecondsSinceEpoch(0),
  );
}

/// Resumen de un día del historial, con los números del servidor.
class DaySummary {
  const DaySummary({
    required this.day,
    required this.events,
    required this.status,
    required this.worked,
    required this.pauses,
    this.start,
    this.end,
    this.incomplete = false,
    this.corrected = false,
    this.canRequestCorrection = false,
  });

  final DateTime day;
  final List<TimeEvent> events;
  final WorkStatus status;
  final Duration worked;
  final Duration pauses;

  /// Inicio y fin efectivos de la jornada (ya con correcciones aplicadas).
  final DateTime? start;
  final DateTime? end;

  /// La jornada quedó sin salida.
  final bool incomplete;

  /// La jornada tiene una corrección aprobada.
  final bool corrected;
  final bool canRequestCorrection;

  Duration get presence => worked + pauses;
  bool get hasRecords => events.isNotEmpty || start != null;
}

/// Texto legal público (aviso de privacidad y similares).
class LegalText {
  const LegalText({
    required this.title,
    required this.body,
    required this.version,
    this.draft = false,
  });
  final String title;

  /// Markdown limitado: encabezados, párrafos, listas, tablas y negritas.
  final String body;
  final int version;

  /// Borrador técnico: pendiente de revisión legal.
  final bool draft;
}

/// Lectura de ubicación del teléfono: coordenadas o el motivo de no tenerlas.
class LocationReading {
  const LocationReading.coordinates({
    required double this.lat,
    required double this.lon,
    required double this.accuracyMeters,
    required DateTime this.capturedAt,
  }) : status = null;

  /// [status] es `DENEGADO`, `NO_SOPORTADO` o `NO_DISPONIBLE`.
  const LocationReading.unavailable(String this.status)
      : lat = null,
        lon = null,
        accuracyMeters = null,
        capturedAt = null;

  final double? lat;
  final double? lon;
  final double? accuracyMeters;
  final DateTime? capturedAt;
  final String? status;

  bool get hasCoordinates => lat != null && lon != null;
}

/// Código QR leído: el token del centro y, si es cambiante, su código.
class QrReading {
  const QrReading({required this.token, this.rotatingCode});
  final String token;
  final String? rotatingCode;
}
