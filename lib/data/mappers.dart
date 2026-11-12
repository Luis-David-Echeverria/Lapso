/// Traducción entre el JSON del contrato 0.9.0 y los modelos de la app.
/// Funciones puras, para poder probarlas con los ejemplos del contrato.
library;

import '../domain/format.dart';
import '../domain/models.dart';
import 'lapso_api.dart';

typedef Json = Map<String, dynamic>;

// ---- Lectura segura ------------------------------------------------------

Json? asJson(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map(
      (Object? k, Object? v) => MapEntry<String, dynamic>('$k', v),
    );
  }
  return null;
}

List<Json> asJsonList(Object? value) {
  if (value is! List) return const <Json>[];
  final List<Json> out = <Json>[];
  for (final Object? item in value) {
    final Json? json = asJson(item);
    if (json != null) out.add(json);
  }
  return out;
}

String? _string(Object? value) => value is String ? value : null;

int _int(Object? value) => value is num ? value.toInt() : 0;

/// Fecha y hora del servidor (UTC) en la hora local del teléfono.
DateTime? parseTime(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value)?.toLocal();
}

/// Fecha `AAAA-MM-DD` como medianoche local.
DateTime? parseDate(Object? value) {
  if (value is! String) return null;
  final List<String> parts = value.split('-');
  if (parts.length != 3) return null;
  final int? y = int.tryParse(parts[0]);
  final int? m = int.tryParse(parts[1]);
  final int? d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

// ---- Enumeraciones -------------------------------------------------------

const Map<String, EventType> _eventTypes = <String, EventType>{
  'CLOCK_IN': EventType.entrada,
  'CLOCK_OUT': EventType.salida,
  'BREAK_START': EventType.pausaInicio,
  'BREAK_END': EventType.pausaFin,
};

const Map<String, PauseType> _pauseTypes = <String, PauseType>{
  'MEAL': PauseType.comida,
  'PERSONAL': PauseType.personal,
  'AUTHORIZED': PauseType.autorizada,
  'OTHER': PauseType.otra,
};

EventType? eventTypeOf(Object? value) => _eventTypes[value];

PauseType? pauseTypeOf(Object? value) => _pauseTypes[value];

String eventTypeCode(EventType type) {
  switch (type) {
    case EventType.entrada:
      return 'CLOCK_IN';
    case EventType.salida:
      return 'CLOCK_OUT';
    case EventType.pausaInicio:
      return 'BREAK_START';
    case EventType.pausaFin:
      return 'BREAK_END';
  }
}

String pauseTypeCode(PauseType type) {
  switch (type) {
    case PauseType.comida:
      return 'MEAL';
    case PauseType.personal:
      return 'PERSONAL';
    case PauseType.autorizada:
      return 'AUTHORIZED';
    case PauseType.otra:
      return 'OTHER';
  }
}

String capabilityCode(Capability c) {
  switch (c) {
    case Capability.ubicacion:
      return 'LOCATION';
    case Capability.foto:
      return 'PHOTO';
  }
}

/// Tramo de la ruta para registrar cada tipo de evento.
String clockPath(EventType type) {
  switch (type) {
    case EventType.entrada:
      return '/time-events/clock-in';
    case EventType.salida:
      return '/time-events/clock-out';
    case EventType.pausaInicio:
      return '/time-events/break-start';
    case EventType.pausaFin:
      return '/time-events/break-end';
  }
}

WorkStatus statusOfCode(Object? value) {
  switch (value) {
    case 'OPEN':
      return WorkStatus.enJornada;
    case 'ON_BREAK':
      return WorkStatus.enPausa;
    case 'CLOSED':
    case 'INCOMPLETE':
      return WorkStatus.terminada;
    default:
      return WorkStatus.sinEntrada;
  }
}

CaptureMode _mode(Object? value) {
  switch (value) {
    case 'OPTIONAL':
      return CaptureMode.optional;
    case 'REQUIRED':
      return CaptureMode.required;
    default:
      return CaptureMode.off;
  }
}

ConsentStatus _consent(Object? value) {
  switch (value) {
    case 'ACCEPTED':
      return ConsentStatus.accepted;
    case 'REVOKED':
      return ConsentStatus.revoked;
    case 'OUTDATED':
      return ConsentStatus.outdated;
    default:
      return ConsentStatus.none;
  }
}

// ---- Organización y sesión ----------------------------------------------

Organization? organizationOf(Json? json) {
  if (json == null) return null;
  final String? slug = _string(json['slug']);
  if (slug == null) return null;
  return Organization(
    slug: slug,
    name: _string(json['display_name']) ?? slug,
    contactEmail: _string(json['public_contact_email']),
    contactPhone: _string(json['public_contact_phone']),
  );
}

Session sessionOf(Json json) {
  return Session(
    displayName: _string(json['display_name']) ?? '',
    mustChangePin: json['must_change_pin'] == true,
    organization: organizationOf(asJson(json['tenant'])) ??
        const Organization(slug: '', name: ''),
    isWorker: json['worker_id'] != null,
    unreadNotices: _int(json['unread_notices']),
  );
}

// ---- Registros -----------------------------------------------------------

Evidence evidenceOf(Json? verification) {
  if (verification == null) return Evidence.none;

  bool? qrRead;
  final Json? qr = asJson(verification['qr']);
  if (qr != null && _mode(qr['mode']) != CaptureMode.off) {
    final Object? status = qr['status'];
    qrRead = status == 'PRESENTADO' || status == 'VERIFICADO';
  }

  LocationResult? location;
  final Json? loc = asJson(verification['location']);
  if (loc != null && _mode(loc['mode']) != CaptureMode.off) {
    switch (loc['status']) {
      case 'OMITIDA':
        location = null;
      case 'CAPTURADA':
        if (loc['zone'] == 'DENTRO') {
          location = loc['low_precision'] == true
              ? LocationResult.dentroBajaPrecision
              : LocationResult.dentro;
        } else if (loc['zone'] == 'FUERA') {
          location = LocationResult.fuera;
        } else {
          location = LocationResult.capturada;
        }
      case 'DENEGADO':
        location = LocationResult.sinPermiso;
      case 'SIN_CONSENTIMIENTO':
        location = LocationResult.sinConsentimiento;
      default:
        location = LocationResult.noDisponible;
    }
  }

  bool? photoTaken;
  bool photoAvailable = false;
  final Json? photo = asJson(verification['photo']);
  if (photo != null &&
      _mode(photo['mode']) != CaptureMode.off &&
      photo['status'] != 'OMITIDA') {
    photoTaken = photo['status'] == 'CAPTURADA';
    photoAvailable = photoTaken && photo['available'] == true;
  }

  final Object? missing = verification['required_missing'];
  return Evidence(
    qrRead: qrRead,
    location: location,
    photoTaken: photoTaken,
    photoAvailable: photoAvailable,
    requiredMissing: missing is List && missing.isNotEmpty,
  );
}

TimeEvent? eventOf(Json? json) {
  if (json == null) return null;
  final String? id = _string(json['id']);
  final EventType? type = eventTypeOf(json['event_type']);
  final DateTime? at =
      parseTime(json['effective_at']) ?? parseTime(json['occurred_at']);
  if (id == null || type == null || at == null) return null;
  final Json? offline = asJson(json['offline']);
  final Object? seq = json['seq'];
  return TimeEvent(
    id: id,
    type: type,
    at: at,
    pauseType: pauseTypeOf(json['break_type']),
    seq: seq is num ? seq.toInt() : null,
    hash: _string(json['hash']),
    offline: offline != null,
    clockSuspect: offline != null && offline['clock'] == 'SUSPECT',
    evidence: evidenceOf(asJson(json['verification'])),
  );
}

List<TimeEvent> _eventsOf(Json session) {
  final List<TimeEvent> events = <TimeEvent>[];
  for (final Json json in asJsonList(session['events'])) {
    final TimeEvent? event = eventOf(json);
    if (event != null) events.add(event);
  }
  events.sort((TimeEvent a, TimeEvent b) => a.at.compareTo(b.at));
  return events;
}

bool _isOpen(Json session) =>
    session['status'] == 'OPEN' || session['status'] == 'ON_BREAK';

TodaySnapshot todayOf(Json json) {
  final List<Json> sessions = asJsonList(json['sessions']);
  Json? current;
  for (final Json session in sessions) {
    if (_isOpen(session)) current = session;
  }
  if (current == null) {
    DateTime? latest;
    for (final Json session in sessions) {
      final DateTime? started = parseTime(session['started_at']);
      if (started == null) continue;
      if (latest == null || started.isAfter(latest)) {
        latest = started;
        current = session;
      }
    }
  }

  final Set<EventType> allowed = <EventType>{};
  final Object? actions = json['allowed_actions'];
  if (actions is List) {
    for (final Object? action in actions) {
      final EventType? type = eventTypeOf(action);
      if (type != null) allowed.add(type);
    }
  }

  final Json? worker = asJson(json['worker']);
  return TodaySnapshot(
    status: statusOfCode(json['status']),
    allowedActions: allowed,
    events: current == null ? const <TimeEvent>[] : _eventsOf(current),
    serverTime: parseTime(json['server_time']) ?? DateTime.now(),
    employee: worker == null
        ? null
        : Employee(
            number: _string(worker['employee_number']) ?? '',
            name: _string(worker['full_name']) ?? '',
          ),
    workCenterName: _string(json['work_center_name']),
    sessionStart: current == null ? null : parseTime(current['started_at']),
    worked: Duration(seconds: _int(json['worked_seconds_today'])),
    pauses: Duration(seconds: _int(json['break_seconds_today'])),
    scheduledEnd: parseTime(json['scheduled_end']),
    lastEvent: eventOf(asJson(json['last_event'])),
    hasIncompleteSession: json['has_incomplete_session'] == true,
    pendingCorrections: _int(json['pending_corrections']),
  );
}

/// Días del historial, del más reciente al más antiguo.
List<DaySummary> timesheetOf(Json json) {
  final List<DaySummary> days = <DaySummary>[];
  for (final Json day in asJsonList(json['days'])) {
    final DateTime? date = parseDate(day['date']);
    if (date == null) continue;
    final List<Json> sessions = asJsonList(day['sessions']);
    final List<TimeEvent> events = <TimeEvent>[];
    WorkStatus status =
        sessions.isEmpty ? WorkStatus.sinEntrada : WorkStatus.terminada;
    DateTime? start;
    DateTime? end;
    bool allEnded = sessions.isNotEmpty;
    bool incomplete = false;
    bool corrected = false;
    bool canRequest = false;
    for (final Json session in sessions) {
      events.addAll(_eventsOf(session));
      if (_isOpen(session)) status = statusOfCode(session['status']);
      if (session['status'] == 'INCOMPLETE') incomplete = true;
      if (session['corrected'] == true) corrected = true;
      if (session['can_request_correction'] == true) canRequest = true;
      final DateTime? started = parseTime(session['started_at']);
      if (started != null && (start == null || started.isBefore(start))) {
        start = started;
      }
      final DateTime? ended = parseTime(session['ended_at']);
      if (ended == null) {
        allEnded = false;
      } else if (end == null || ended.isAfter(end)) {
        end = ended;
      }
    }
    events.sort((TimeEvent a, TimeEvent b) => a.at.compareTo(b.at));
    days.add(
      DaySummary(
        day: date,
        events: events,
        status: status,
        worked: Duration(seconds: _int(day['worked_seconds'])),
        pauses: Duration(seconds: _int(day['break_seconds'])),
        start: start,
        end: allEnded ? end : null,
        incomplete: incomplete,
        corrected: corrected,
        canRequestCorrection: canRequest,
      ),
    );
  }
  days.sort((DaySummary a, DaySummary b) => b.day.compareTo(a.day));
  return days;
}

// ---- Captura -------------------------------------------------------------

CaptureRule _ruleOf(Json json) {
  final Set<EventType> types = <EventType>{};
  final Object? raw = json['event_types'];
  if (raw is List) {
    for (final Object? item in raw) {
      final EventType? type = eventTypeOf(item);
      if (type != null) types.add(type);
    }
  }
  final Json? consent = asJson(json['consent']);
  return CaptureRule(
    mode: _mode(json['mode']),
    eventTypes: types,
    active: json['active'] == true,
    consent: consent == null ? null : _consent(consent['status']),
  );
}

CaptureSettings captureSettingsOf(Json json) {
  CaptureRule location = CaptureRule.off;
  CaptureRule qr = CaptureRule.off;
  CaptureRule photo = CaptureRule.off;
  for (final Json rule in asJsonList(json['capabilities'])) {
    switch (rule['capability']) {
      case 'LOCATION':
        location = _ruleOf(rule);
      case 'QR':
        qr = _ruleOf(rule);
      case 'PHOTO':
        photo = _ruleOf(rule);
    }
  }
  final Json? center = asJson(json['work_center']);
  final Json? offline = asJson(json['offline']);
  final Object? notice = json['notice_version'];
  final int rotation = _int(json['qr_rotation_seconds']);
  return CaptureSettings(
    workCenterName: _string(center?['name']) ?? '',
    zoneConfigured: center?['zone_configured'] == true,
    noticeVersion: notice is num ? notice.toInt() : null,
    location: location,
    qr: qr,
    photo: photo,
    qrRotationSeconds: rotation == 0 ? 60 : rotation,
    offlineAllowed: offline?['allowed'] == true,
    offlineMaxAgeHours:
        offline == null ? 24 : _int(offline['max_age_hours']),
    clockToleranceSeconds:
        offline == null ? 120 : _int(offline['clock_tolerance_seconds']),
  );
}

// ---- Transparencia y legales --------------------------------------------

List<EvidenceView> evidenceViewsOf(Json json) {
  final List<EvidenceView> views = <EvidenceView>[];
  for (final Json item in asJsonList(json['items'])) {
    final DateTime? at = parseTime(item['viewed_at']);
    if (at == null) continue;
    views.add(
      EvidenceView(
        viewerName: _string(item['viewer_name']) ?? '',
        viewerRole: _string(item['viewer_role']) ?? '',
        what: item['kind'] == 'PHOTO' ? Capability.foto : Capability.ubicacion,
        at: at,
        eventId: _string(item['event_id']),
      ),
    );
  }
  return views;
}

List<Rejection> rejectionsOf(Json json) {
  final List<Rejection> out = <Rejection>[];
  for (final Json item in asJsonList(json['items'])) {
    final EventType? type = eventTypeOf(item['event_type']);
    final DateTime? at = parseTime(item['client_declared_at']);
    if (type == null || at == null) continue;
    out.add(
      Rejection(
        event: TimeEvent(
          id: _string(item['id']) ?? '',
          type: type,
          at: at,
          pauseType: pauseTypeOf(item['break_type']),
          offline: true,
        ),
        reason: rejectionReason(_string(item['cause']) ?? ''),
      ),
    );
  }
  return out;
}

LegalText legalTextOf(Json json) {
  return LegalText(
    title: _string(json['title']) ?? '',
    body: _string(json['body']) ?? '',
    version: _int(json['version']),
    draft: json['status'] == 'BORRADOR_TECNICO',
  );
}

SupportContact supportContactOf(Json json) {
  return SupportContact(
    email: _string(json['support_email']),
    phone: _string(json['support_phone']),
  );
}

// ---- Lo que la app manda -------------------------------------------------

Json? _verificationBody(RegisterDraft draft) {
  final Json out = <String, dynamic>{};
  final LocationReading? location = draft.location;
  if (location != null) {
    if (location.hasCoordinates) {
      out['location'] = <String, dynamic>{
        'lat': location.lat,
        'lon': location.lon,
        'accuracy_m': location.accuracyMeters ?? 0,
        if (location.capturedAt != null)
          'captured_at': location.capturedAt!.toUtc().toIso8601String(),
      };
    } else if (location.status != null) {
      out['location'] = <String, dynamic>{'status': location.status};
    }
  }
  if (draft.photoId != null) {
    out['photo'] = <String, dynamic>{'photo_id': draft.photoId};
  } else if (draft.photoStatus != null) {
    out['photo'] = <String, dynamic>{'status': draft.photoStatus};
  }
  return out.isEmpty ? null : out;
}

/// Cuerpo de `clockIn`, `clockOut`, `breakStart` y `breakEnd`.
Json clockBody(RegisterDraft draft) {
  final Json? verification = _verificationBody(draft);
  final QrReading? qr = draft.qr;
  return <String, dynamic>{
    if (draft.type == EventType.pausaInicio)
      'break_type': pauseTypeCode(draft.pauseType ?? PauseType.otra),
    if (qr != null) 'qr_token': qr.token,
    if (qr?.rotatingCode != null) 'qr_rotating_code': qr!.rotatingCode,
    'client_time': draft.declaredAt.toUtc().toIso8601String(),
    if (verification != null) 'verification': verification,
    'channel': 'APP',
  };
}

/// Un evento dentro del cuerpo de `syncOfflineEvents`.
Json offlineEventBody(RegisterDraft draft) {
  final Json? verification = _verificationBody(draft);
  final QrReading? qr = draft.qr;
  final PauseType? pause = draft.pauseType;
  return <String, dynamic>{
    'idempotency_key': draft.key,
    'event_type': eventTypeCode(draft.type),
    if (draft.type == EventType.pausaInicio)
      'break_type': pauseTypeCode(pause ?? PauseType.otra),
    if (qr != null) 'qr_token': qr.token,
    if (qr?.rotatingCode != null) 'qr_rotating_code': qr!.rotatingCode,
    'client_declared_at': draft.declaredAt.toUtc().toIso8601String(),
    if (draft.monotonicMs != null) 'monotonic_ms': draft.monotonicMs,
    if (draft.monotonicSession != null)
      'monotonic_session': draft.monotonicSession,
    if (draft.clockReference != null)
      'clock_reference': draft.clockReference!.toJson(),
    if (verification != null) 'verification': verification,
    'channel': 'APP',
  };
}

SyncResult syncResultOf(Json json) {
  final List<SyncItem> items = <SyncItem>[];
  for (final Json item in asJsonList(json['results'])) {
    final String? key = _string(item['idempotency_key']);
    if (key == null) continue;
    final SyncOutcome outcome;
    switch (item['outcome']) {
      case 'CREATED':
        outcome = SyncOutcome.created;
      case 'REPLAYED':
        outcome = SyncOutcome.replayed;
      default:
        outcome = SyncOutcome.rejected;
    }
    items.add(
      SyncItem(
        key: key,
        outcome: outcome,
        cause: _string(asJson(item['rejection'])?['cause']),
      ),
    );
  }
  final Json? today = asJson(json['today']);
  return SyncResult(
    items: items,
    today: today == null ? null : todayOf(today),
  );
}

// ---- Cola guardada en el teléfono ---------------------------------------

/// Un registro pendiente, para guardarlo en el almacén del teléfono.
Json draftToStore(RegisterDraft draft) {
  final LocationReading? location = draft.location;
  final Evidence evidence = draft.evidence;
  return <String, dynamic>{
    ...offlineEventBody(draft),
    if (location != null && location.hasCoordinates)
      '_location': <String, dynamic>{
        'lat': location.lat,
        'lon': location.lon,
        'accuracy_m': location.accuracyMeters,
        'captured_at': location.capturedAt?.toUtc().toIso8601String(),
      }
    else if (location?.status != null)
      '_location': <String, dynamic>{'status': location!.status},
    '_photo_status': draft.photoStatus,
    '_evidence': <String, dynamic>{
      'qr': evidence.qrRead,
      'location': evidence.location?.name,
      'photo': evidence.photoTaken,
    },
  };
}

RegisterDraft? draftFromStore(Json json) {
  final String? key = _string(json['idempotency_key']);
  final EventType? type = eventTypeOf(json['event_type']);
  final DateTime? at = parseTime(json['client_declared_at']);
  if (key == null || type == null || at == null) return null;

  QrReading? qr;
  final String? token = _string(json['qr_token']);
  if (token != null) {
    qr = QrReading(
      token: token,
      rotatingCode: _string(json['qr_rotating_code']),
    );
  }

  LocationReading? location;
  final Json? loc = asJson(json['_location']);
  if (loc != null) {
    final Object? lat = loc['lat'];
    final Object? lon = loc['lon'];
    final Object? accuracy = loc['accuracy_m'];
    if (lat is num && lon is num) {
      location = LocationReading.coordinates(
        lat: lat.toDouble(),
        lon: lon.toDouble(),
        accuracyMeters: accuracy is num ? accuracy.toDouble() : 0,
        capturedAt: parseTime(loc['captured_at']) ?? at,
      );
    } else if (loc['status'] is String) {
      location = LocationReading.unavailable(loc['status'] as String);
    }
  }

  final Json? evidence = asJson(json['_evidence']);
  LocationResult? shown;
  for (final LocationResult r in LocationResult.values) {
    if (r.name == evidence?['location']) shown = r;
  }
  final Object? qrShown = evidence?['qr'];
  final Object? photoShown = evidence?['photo'];
  final Object? ms = json['monotonic_ms'];

  return RegisterDraft(
    key: key,
    type: type,
    declaredAt: at,
    pauseType: pauseTypeOf(json['break_type']),
    qr: qr,
    location: location,
    photoStatus: _string(json['_photo_status']),
    monotonicMs: ms is num ? ms.toInt() : null,
    monotonicSession: _string(json['monotonic_session']),
    clockReference: ClockReference.fromJson(json['clock_reference']),
    evidence: Evidence(
      qrRead: qrShown is bool ? qrShown : null,
      location: shown,
      photoTaken: photoShown is bool ? photoShown : null,
    ),
  );
}
