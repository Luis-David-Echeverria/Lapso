import 'dart:typed_data';

import '../domain/format.dart';
import '../domain/models.dart';
import '../domain/rules.dart';
import 'ids.dart';
import 'lapso_api.dart';

/// Servidor simulado en memoria, para el modo de demostración y las pruebas.
/// Aplica las mismas reglas que el contrato 0.9.0 en lo que la app usa.
///
/// Datos de prueba: organización `campo-prueba`, empleado `GIL-001`,
/// PIN `482913`. Con el PIN temporal `735194` obliga a cambiarlo.
class FakeLapsoApi implements LapsoApi {
  FakeLapsoApi() {
    _seed();
  }

  static const Organization _org = Organization(
    slug: 'campo-prueba',
    name: 'Servicios Campo de Prueba',
    contactEmail: 'privacidad@campo-prueba.test',
  );
  static const Employee _employee =
      Employee(number: 'GIL-001', name: 'Gilberto Damián');
  static const String _center = 'Oficina Campo';
  static const String _temporaryPin = '735194';
  static const Duration _latency = Duration(milliseconds: 350);
  static const Set<EventType> _clocking = <EventType>{
    EventType.entrada,
    EventType.salida,
  };

  /// Simula que no hay red: las consultas responden con la última copia y
  /// los envíos fallan.
  bool offline = false;

  /// Adelanta el reloj del servidor (para simular que pasó el tiempo).
  Duration clockOffset = Duration.zero;

  @override
  bool servedFromCache = false;

  String _pin = '482913';
  bool _signedIn = false;
  bool _mustChangePin = false;
  int _failedAttempts = 0;
  DateTime? _lockedUntil;
  int _seq = 40;

  final List<TimeEvent> _events = <TimeEvent>[];
  final List<Rejection> _rejections = <Rejection>[];
  final List<EvidenceView> _views = <EvidenceView>[];
  final Map<Capability, ConsentStatus> _consents = <Capability, ConsentStatus>{
    Capability.ubicacion: ConsentStatus.accepted,
    Capability.foto: ConsentStatus.none,
  };
  final Set<String> _photoIds = <String>{};
  final Map<String, TimeEvent> _byKey = <String, TimeEvent>{};

  DateTime get _now => DateTime.now().add(clockOffset);

  // ---- Datos sembrados ---------------------------------------------------

  void _seed() {
    final DateTime today = dayOf(_now);
    DateTime at(int daysAgo, int h, int m) =>
        DateTime(today.year, today.month, today.day - daysAgo, h, m);
    const Evidence full = Evidence(
      qrRead: true,
      location: LocationResult.dentro,
      photoTaken: true,
      photoAvailable: true,
    );
    void add(EventType type, DateTime when, {PauseType? pause}) {
      _events.add(
        TimeEvent(
          id: newUuid(),
          type: type,
          at: when,
          pauseType: pause,
          seq: ++_seq,
          hash: _hash(_seq),
          evidence: _clocking.contains(type) ? full : Evidence.none,
        ),
      );
    }

    add(EventType.entrada, at(2, 8, 56));
    add(EventType.pausaInicio, at(2, 13, 4), pause: PauseType.comida);
    add(EventType.pausaFin, at(2, 13, 58));
    add(EventType.salida, at(2, 18, 2));
    add(EventType.entrada, at(1, 9, 1));
    add(EventType.pausaInicio, at(1, 13, 30), pause: PauseType.comida);
    add(EventType.pausaFin, at(1, 14, 22));
    add(EventType.salida, at(1, 18, 5));

    _views
      ..add(
        EvidenceView(
          viewerName: 'Laura Méndez',
          viewerRole: 'HR',
          what: Capability.ubicacion,
          at: at(1, 9, 40),
          eventId: _events[4].id,
        ),
      )
      ..add(
        EvidenceView(
          viewerName: 'Laura Méndez',
          viewerRole: 'HR',
          what: Capability.foto,
          at: at(1, 9, 41),
          eventId: _events[4].id,
        ),
      );
  }

  static String _hash(int seq) {
    final StringBuffer out = StringBuffer();
    int x = (seq * 2654435761) & 0xFFFFFFFF;
    for (int i = 0; i < 8; i++) {
      x = (x * 1103515245 + 12345) & 0xFFFFFFFF;
      out.write(x.toRadixString(16).padLeft(8, '0'));
    }
    return out.toString();
  }

  // ---- Utilidades --------------------------------------------------------

  Future<void> _wait() => Future<void>.delayed(_latency);

  Future<void> _online() async {
    await _wait();
    if (offline) throw const LapsoException.network();
  }

  Future<void> _authed() async {
    await _online();
    if (!_signedIn) {
      throw const LapsoException(
        'Tu sesión terminó. Entra de nuevo.',
        code: 'UNAUTHENTICATED',
        status: 401,
      );
    }
    if (_mustChangePin) {
      throw const LapsoException(
        'Debes cambiar tu PIN temporal.',
        code: 'PIN_CHANGE_REQUIRED',
        status: 403,
      );
    }
  }

  /// Jornada vigente: la abierta o, si no hay, la última de hoy.
  List<TimeEvent> get _shift {
    final List<TimeEvent> shift = currentShift(_events);
    if (shift.isEmpty) return shift;
    final bool open = statusOf(shift) != WorkStatus.terminada;
    return open || isSameDay(shift.first.at, _now)
        ? shift
        : const <TimeEvent>[];
  }

  TodaySnapshot _today() {
    final List<TimeEvent> shift = _shift;
    final WorkStatus status = statusOf(shift);
    final DateTime now = _now;
    final Set<EventType> allowed = actionsFor(status);
    if (isLongSession(shift, now)) allowed.add(EventType.entrada);
    final DateTime today = dayOf(now);
    return TodaySnapshot(
      status: status,
      allowedActions: allowed,
      events: List<TimeEvent>.unmodifiable(shift),
      serverTime: now,
      employee: _employee,
      workCenterName: _center,
      sessionStart: shift.isEmpty ? null : shift.first.at,
      worked: workedOf(shift, now),
      pauses: pausesOf(shift, now),
      scheduledEnd: DateTime(today.year, today.month, today.day, 18),
      lastEvent: _events.isEmpty ? null : _events.last,
    );
  }

  CaptureRule _rule(Capability c) {
    final ConsentStatus consent = _consents[c] ?? ConsentStatus.none;
    return CaptureRule(
      mode: CaptureMode.optional,
      eventTypes: _clocking,
      active: consent == ConsentStatus.accepted,
      consent: consent,
    );
  }

  Evidence _evidenceFor(RegisterDraft draft) {
    if (!_clocking.contains(draft.type)) return Evidence.none;
    LocationResult location;
    final LocationReading? reading = draft.location;
    if (_consents[Capability.ubicacion] != ConsentStatus.accepted) {
      location = LocationResult.sinConsentimiento;
    } else if (reading != null && reading.hasCoordinates) {
      location = LocationResult.dentro;
    } else if (reading?.status == 'DENEGADO') {
      location = LocationResult.sinPermiso;
    } else {
      location = LocationResult.noDisponible;
    }
    final bool photo = _consents[Capability.foto] == ConsentStatus.accepted &&
        draft.photoId != null &&
        _photoIds.remove(draft.photoId);
    return Evidence(
      qrRead: draft.qr != null,
      location: location,
      photoTaken: photo,
      photoAvailable: photo,
    );
  }

  /// Motivo por el que [type] no procede ahora, o `null` si procede.
  String? _conflict(EventType type, DateTime when) {
    final List<TimeEvent> shift = currentShift(_events);
    final WorkStatus status = statusOf(shift);
    if (type == EventType.entrada && isLongSession(shift, when)) return null;
    switch (type) {
      case EventType.entrada:
        return status == WorkStatus.enJornada || status == WorkStatus.enPausa
            ? 'SESSION_ALREADY_OPEN'
            : null;
      case EventType.salida:
        return status == WorkStatus.enJornada || status == WorkStatus.enPausa
            ? null
            : 'NO_OPEN_SESSION';
      case EventType.pausaInicio:
        if (status == WorkStatus.enPausa) return 'BREAK_ALREADY_OPEN';
        return status == WorkStatus.enJornada ? null : 'NO_OPEN_SESSION';
      case EventType.pausaFin:
        return status == WorkStatus.enPausa ? null : 'NO_OPEN_BREAK';
    }
  }

  TimeEvent _append(RegisterDraft draft, DateTime at, {bool offline = false}) {
    // Una salida con una pausa abierta cierra la pausa en el mismo instante.
    final TimeEvent event = TimeEvent(
      id: newUuid(),
      type: draft.type,
      at: at,
      pauseType: draft.type == EventType.pausaInicio
          ? (draft.pauseType ?? PauseType.otra)
          : null,
      seq: ++_seq,
      hash: _hash(_seq),
      offline: offline,
      evidence: _evidenceFor(draft),
    );
    _events
      ..add(event)
      ..sort((TimeEvent a, TimeEvent b) => a.at.compareTo(b.at));
    _byKey[draft.key] = event;
    return event;
  }

  // ---- Operaciones -------------------------------------------------------

  @override
  Future<Organization?> findOrganization(String slug) async {
    await _online();
    return slug.trim().toLowerCase() == _org.slug ? _org : null;
  }

  @override
  Future<Organization?> resolveOrganizationQr(String token) async {
    await _online();
    return _org;
  }

  @override
  Future<Session> login({
    required String tenant,
    required String employeeNumber,
    required String pin,
  }) async {
    await _online();
    final DateTime now = _now;
    final DateTime? until = _lockedUntil;
    if (until != null && now.isBefore(until)) {
      throw LapsoException(
        'Tu cuenta está bloqueada por intentos fallidos.',
        code: 'ACCOUNT_LOCKED',
        status: 423,
        retryAfter: until.difference(now),
      );
    }
    final bool known = tenant == _org.slug &&
        employeeNumber.trim().toUpperCase() == _employee.number;
    final bool temporary = known && pin == _temporaryPin;
    if (!known || (pin != _pin && !temporary)) {
      _failedAttempts++;
      if (_failedAttempts >= kMaxPinAttempts) {
        _failedAttempts = 0;
        _lockedUntil = now.add(const Duration(minutes: kLockMinutes));
        throw const LapsoException(
          'Tu cuenta está bloqueada por intentos fallidos.',
          code: 'ACCOUNT_LOCKED',
          status: 423,
          retryAfter: Duration(minutes: kLockMinutes),
        );
      }
      throw const LapsoException(
        'Número de empleado o PIN incorrecto.',
        code: 'INVALID_CREDENTIALS',
        status: 401,
      );
    }
    _failedAttempts = 0;
    _lockedUntil = null;
    _signedIn = true;
    _mustChangePin = temporary;
    return Session(
      displayName: _employee.name,
      mustChangePin: temporary,
      organization: _org,
    );
  }

  @override
  Future<Session?> restoreSession() async => null;

  @override
  Future<void> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    await _online();
    final bool matches =
        currentPin == _pin || (_mustChangePin && currentPin == _temporaryPin);
    if (!matches) {
      throw const LapsoException(
        'Ese no es tu PIN actual.',
        code: 'INVALID_CREDENTIALS',
        status: 422,
      );
    }
    final String? problem = validateNewPin(
      newPin,
      employeeNumber: _employee.number,
      currentPin: currentPin,
    );
    if (problem != null) {
      throw LapsoException(problem, code: 'VALIDATION_ERROR', status: 422);
    }
    _pin = newPin;
    _mustChangePin = false;
  }

  @override
  Future<void> logout() async {
    await _wait();
    _signedIn = false;
  }

  @override
  Future<TodaySnapshot> today() async {
    await _wait();
    servedFromCache = offline;
    if (!offline) await _authedNoWait();
    return _today();
  }

  @override
  Future<CaptureSettings> captureSettings() async {
    await _wait();
    servedFromCache = offline;
    if (!offline) await _authedNoWait();
    return CaptureSettings(
      workCenterName: _center,
      zoneConfigured: true,
      noticeVersion: 2,
      location: _rule(Capability.ubicacion),
      qr: const CaptureRule(
        mode: CaptureMode.optional,
        eventTypes: _clocking,
        active: true,
      ),
      photo: _rule(Capability.foto),
      offlineAllowed: true,
    );
  }

  Future<void> _authedNoWait() async {
    if (!_signedIn) {
      throw const LapsoException(
        'Tu sesión terminó. Entra de nuevo.',
        code: 'UNAUTHENTICATED',
        status: 401,
      );
    }
    if (_mustChangePin) {
      throw const LapsoException(
        'Debes cambiar tu PIN temporal.',
        code: 'PIN_CHANGE_REQUIRED',
        status: 403,
      );
    }
  }

  @override
  Future<String> uploadPhoto(Uint8List jpeg, {DateTime? capturedAt}) async {
    await _authed();
    if (_consents[Capability.foto] != ConsentStatus.accepted) {
      throw const LapsoException(
        'Falta tu aceptación para la foto.',
        code: 'CONSENT_REQUIRED',
        status: 403,
      );
    }
    final String id = newUuid();
    _photoIds.add(id);
    return id;
  }

  @override
  Future<RegisterResult> register(RegisterDraft draft) async {
    await _authed();
    final TimeEvent? replay = _byKey[draft.key];
    if (replay != null) return RegisterResult(event: replay, today: _today());
    final DateTime now = _now;
    final String? conflict = _conflict(draft.type, now);
    if (conflict != null) {
      throw LapsoException(
        rejectionReason(conflict),
        code: conflict,
        status: 409,
      );
    }
    final TimeEvent event = _append(draft, now);
    return RegisterResult(event: event, today: _today());
  }

  @override
  Future<SyncResult> sync(List<RegisterDraft> drafts) async {
    await _authed();
    final DateTime now = _now;
    final List<SyncItem> items = <SyncItem>[];
    for (final RegisterDraft draft in drafts) {
      if (_byKey.containsKey(draft.key)) {
        items.add(SyncItem(key: draft.key, outcome: SyncOutcome.replayed));
        continue;
      }
      String? cause;
      if (draft.declaredAt.isAfter(now.add(const Duration(minutes: 2)))) {
        cause = 'FUTURE';
      } else if (now.difference(draft.declaredAt).inHours >= 24) {
        cause = 'TOO_OLD';
      } else {
        cause = _conflict(draft.type, draft.declaredAt);
      }
      if (cause != null) {
        _rejections.insert(
          0,
          Rejection(
            event: draft.toPendingEvent(),
            reason: rejectionReason(cause),
          ),
        );
        items.add(
          SyncItem(
            key: draft.key,
            outcome: SyncOutcome.rejected,
            cause: cause,
          ),
        );
        continue;
      }
      _append(draft, draft.declaredAt, offline: true);
      items.add(SyncItem(key: draft.key, outcome: SyncOutcome.created));
    }
    return SyncResult(items: items, today: _today());
  }

  @override
  Future<List<DaySummary>> history({
    required DateTime from,
    required DateTime to,
  }) async {
    await _authed();
    final DateTime now = _now;
    final List<DaySummary> days = <DaySummary>[];
    DateTime day = dayOf(to);
    final DateTime first = dayOf(from);
    while (!day.isBefore(first)) {
      days.add(summarizeDay(day, _events, now));
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return days;
  }

  @override
  Future<void> setConsent(
    Capability capability, {
    required bool accepted,
    int? noticeVersion,
  }) async {
    await _authed();
    _consents[capability] =
        accepted ? ConsentStatus.accepted : ConsentStatus.revoked;
  }

  @override
  Future<List<EvidenceView>> evidenceViews() async {
    await _authed();
    return List<EvidenceView>.unmodifiable(_views.reversed);
  }

  @override
  Future<List<Rejection>> rejections() async {
    await _authed();
    return List<Rejection>.unmodifiable(_rejections);
  }

  @override
  Future<LegalText?> legalText(String kind) async {
    await _online();
    switch (kind) {
      case 'AVISO_PRIVACIDAD':
        return const LegalText(
          title: 'Aviso de privacidad',
          version: 2,
          draft: true,
          body: '## Qué datos se recaban\n\n'
              'Para registrar tu jornada se guardan la **hora** de cada '
              'registro y, si tu centro lo pide y tú lo aceptas:\n\n'
              '- Una lectura de tu **ubicación** al registrar.\n'
              '- Una **foto** tomada con la cámara frontal al registrar.\n\n'
              '## Para qué se usan\n\n'
              'Solo para acreditar tu registro de jornada ante tu '
              'organización.\n\n'
              '## Tus derechos\n\n'
              'Puedes retirar tu consentimiento en cualquier momento y '
              'pedir el acceso, la corrección o la cancelación de tus '
              'datos con el contacto de tu organización.\n\n'
              '_Texto de demostración._',
        );
      case 'POLITICA_CONSERVACION':
        return const LegalText(
          title: 'Política de conservación',
          version: 1,
          draft: true,
          body: 'Las fotos y las ubicaciones se conservan por un plazo '
              'limitado y después se eliminan.\n\n_Texto de demostración._',
        );
      case 'MEDIO_REGISTRO':
        return const LegalText(
          title: 'Medio de registro de la jornada',
          version: 1,
          draft: true,
          body: 'Esta aplicación es el medio acordado para registrar tu '
              'jornada.\n\n_Texto de demostración._',
        );
      default:
        return null;
    }
  }

  @override
  Future<Uint8List?> eventPhoto(String eventId) async {
    await _authed();
    return null;
  }

  @override
  Future<SupportContact> supportContact() async {
    await _authed();
    return const SupportContact(email: 'soporte@campo-prueba.test');
  }
}
