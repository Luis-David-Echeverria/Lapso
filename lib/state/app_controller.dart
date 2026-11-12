import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../config.dart';
import '../data/fake_lapso_api.dart';
import '../data/ids.dart';
import '../data/key_value_store.dart';
import '../data/lapso_api.dart';
import '../data/mappers.dart';
import '../domain/models.dart';
import '../domain/rules.dart';
import '../platform/device_capture.dart';

/// Estado de toda la app. Las pantallas lo leen con `AppScope.of(context)`.
///
/// Habla con el servidor a través de [api], con el teléfono (ubicación,
/// cámara, QR) a través de [device] y guarda lo necesario en [store]: la
/// organización elegida y la cola de registros hechos sin conexión.
class AppController extends ChangeNotifier {
  AppController({
    required this.api,
    required this.device,
    KeyValueStore? store,
    this.demoTools = false,
  }) : store = store ?? MemoryStore();

  final LapsoApi api;
  final DeviceCapture device;
  final KeyValueStore store;

  /// Muestra en Más las herramientas para simular estados. Solo con el
  /// servidor simulado; nunca en una compilación para tienda.
  final bool demoTools;

  static const String _orgKey = 'lapso.organization';
  static const String _loginKey = 'lapso.login_id';

  /// Mensaje de [changePin] cuando el PIN actual no coincide.
  static const String wrongCurrentPin = 'Ese no es tu PIN actual.';

  // ---- Arranque ----------------------------------------------------------

  /// Ya se leyó lo guardado en el teléfono y se sabe qué pantalla toca.
  bool ready = false;

  /// Lee la organización guardada y, si hay una sesión viva, entra directo.
  Future<void> start() async {
    try {
      organization = _organizationFromStore(await store.read(_orgKey));
      _loginId = await store.read(_loginKey);
      if (organization != null) {
        final Session? session = await api.restoreSession();
        if (session != null) await _enter(session);
      }
    } on LapsoException {
      // Sin red y sin copia guardada: se queda en la pantalla de acceso.
    }
    ready = true;
    notifyListeners();
  }

  static Organization? _organizationFromStore(String? raw) {
    if (raw == null) return null;
    try {
      return organizationOf(asJson(jsonDecode(raw)));
    } on FormatException {
      return null;
    }
  }

  // ---- Reloj -------------------------------------------------------------

  Duration _demoOffset = Duration.zero;
  Duration _phoneSkew = Duration.zero;
  final Stopwatch _monotonic = Stopwatch()..start();
  final String _monotonicSession = newUuid();
  ClockReference? _clockReference;

  /// Hora del teléfono. La hora oficial de cada registro la pone el servidor.
  DateTime get now => DateTime.now().add(_demoOffset + _phoneSkew);

  void _noteServerTime(DateTime serverTime) {
    _clockReference = ClockReference(
      serverTime: serverTime,
      deviceTime: now,
      monotonicMs: _monotonic.elapsedMilliseconds,
      monotonicSession: _monotonicSession,
    );
  }

  // ---- Sesión ------------------------------------------------------------

  Organization? organization;
  Employee? employee;
  bool mustChangePin = false;
  DateTime? lockedUntil;

  /// La sesión venció o la cerró el servidor; se avisa en la pantalla de
  /// acceso.
  bool sessionExpired = false;

  bool _signedIn = false;
  String? _loginId;
  String? _loginPin;
  String? _profileProblem;

  bool get hasOrganization => organization != null;
  bool get loggedIn => _signedIn;

  /// Para cambiar el PIN hay que pedir el actual (no se conserva el que se
  /// escribió al entrar).
  bool get needsCurrentPin => _loginPin == null;

  bool get isLocked {
    final DateTime? until = lockedUntil;
    return until != null && now.isBefore(until);
  }

  Duration get lockRemaining {
    final DateTime? until = lockedUntil;
    if (until == null) return Duration.zero;
    final Duration d = until.difference(now);
    return d.isNegative ? Duration.zero : d;
  }

  void _lock(Duration? retryAfter) {
    if (isLocked) return;
    lockedUntil =
        now.add(retryAfter ?? const Duration(minutes: kLockMinutes));
  }

  /// Vuelve a la pantalla de acceso para intentarlo otra vez.
  void clearExpiredLock() {
    lockedUntil = null;
    notifyListeners();
  }

  Future<void> _setOrganization(Organization found) async {
    organization = found;
    await store.write(
      _orgKey,
      jsonEncode(<String, dynamic>{
        'slug': found.slug,
        'display_name': found.name,
        'public_contact_email': found.contactEmail,
        'public_contact_phone': found.contactPhone,
      }),
    );
    notifyListeners();
  }

  /// Devuelve `null` si la organización existe; si no, el mensaje de error.
  Future<String?> chooseOrganization(String code) async {
    if (code.trim().isEmpty) return 'Escribe el código de tu organización.';
    final String? slug = parseOrganizationCode(code);
    if (slug == null) {
      return 'Ese código no tiene el formato esperado. Revísalo o pídelo de '
          'nuevo a Recursos Humanos.';
    }
    final Organization? found;
    try {
      found = await api.findOrganization(slug);
    } on LapsoException catch (e) {
      return e.message;
    }
    if (found == null) {
      return 'No encontramos esa organización. Revisa el código o pídelo de '
          'nuevo a Recursos Humanos.';
    }
    await _setOrganization(found);
    return null;
  }

  /// Elige la organización a partir del contenido de su código QR.
  Future<String?> chooseOrganizationByQr(String payload) async {
    final QrReading? qr = parseQrPayload(payload);
    if (qr == null) return chooseOrganization(payload);
    final Organization? found;
    try {
      found = await api.resolveOrganizationQr(qr.token);
    } on LapsoException catch (e) {
      return e.message;
    }
    if (found == null) {
      return 'Ese código QR no es válido o ya venció. Pide uno nuevo a '
          'Recursos Humanos.';
    }
    await _setOrganization(found);
    return null;
  }

  void forgetOrganization() {
    organization = null;
    lockedUntil = null;
    sessionExpired = false;
    unawaited(store.delete(_orgKey));
    notifyListeners();
  }

  Future<LoginResult> login(String employeeNumber, String pin) async {
    final Organization? org = organization;
    if (org == null) {
      throw const LapsoException('Primero elige tu organización.');
    }
    final String id = employeeNumber.trim();
    final Session session;
    try {
      session =
          await api.login(tenant: org.slug, employeeNumber: id, pin: pin);
    } on LapsoException catch (e) {
      if (e.code == 'INVALID_CREDENTIALS') {
        return const LoginResult(
          LoginStatus.wrongCredentials,
          message: 'Número de empleado o PIN incorrecto.',
        );
      }
      if (e.code == 'ACCOUNT_LOCKED') {
        _lock(e.retryAfter);
        notifyListeners();
        return const LoginResult(LoginStatus.locked);
      }
      rethrow;
    }
    _loginId = id.toLowerCase();
    await store.write(_loginKey, id.toLowerCase());
    _loginPin = pin;
    lockedUntil = null;
    await _enter(session);
    final String? problem = _profileProblem;
    if (problem != null) {
      await logout();
      return LoginResult(LoginStatus.noWorkerProfile, message: problem);
    }
    notifyListeners();
    return const LoginResult(LoginStatus.ok);
  }

  Future<void> _enter(Session session) async {
    _signedIn = true;
    sessionExpired = false;
    _profileProblem = null;
    mustChangePin = session.mustChangePin;
    employee = Employee(
      number: (_loginId ?? '').toUpperCase(),
      name: session.displayName,
    );
    if (!session.mustChangePin) await _loadAll();
  }

  Future<void> _loadAll() async {
    await _loadQueue();
    await refresh();
    if (_signedIn && _profileProblem == null) unawaited(_loadSecondary());
  }

  /// Cambia el PIN. Devuelve `null` si se cambió; si no, el motivo.
  /// [currentPin] solo hace falta cuando [needsCurrentPin] es verdadero.
  Future<String?> changePin(String newPin, {String? currentPin}) async {
    final String? current = currentPin ?? _loginPin;
    if (current == null) return 'Escribe tu PIN actual.';
    final String? problem = validateNewPin(
      newPin,
      employeeNumber: employee?.number ?? '',
      currentPin: current,
    );
    if (problem != null) return problem;
    try {
      await api.changePin(currentPin: current, newPin: newPin);
    } on LapsoException catch (e) {
      if (e.code == 'ACCOUNT_LOCKED') {
        // El quinto fallo bloquea la cuenta y cierra sus sesiones.
        _lock(e.retryAfter);
        _dropSession();
        notifyListeners();
        return e.message;
      }
      _absorb(e);
      notifyListeners();
      return e.code == 'INVALID_CREDENTIALS' ? wrongCurrentPin : e.message;
    }
    _loginPin = newPin;
    final bool wasForced = mustChangePin;
    mustChangePin = false;
    if (wasForced) await _loadAll();
    notifyListeners();
    return null;
  }

  Future<void> logout() async {
    await api.logout();
    _dropSession();
    notifyListeners();
  }

  /// Olvida la sesión en memoria. La cola sin conexión queda guardada en el
  /// teléfono y se envía cuando la misma persona vuelve a entrar.
  void _dropSession() {
    _signedIn = false;
    employee = null;
    mustChangePin = false;
    _loginPin = null;
    _today = TodaySnapshot.empty;
    _todayVersion++;
    capture = CaptureSettings.none;
    support = SupportContact.none;
    _queue.clear();
    _days = const <DaySummary>[];
    _rejections = const <Rejection>[];
    _views = const <EvidenceView>[];
    historyLoaded = false;
    longSessionDismissed = false;
    offline = false;
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Aplica a la sesión lo que significa un error del servidor.
  void _absorb(LapsoException e) {
    if (e.isNetwork) {
      offline = true;
      return;
    }
    switch (e.code) {
      case 'UNAUTHENTICATED':
        if (_signedIn) {
          _dropSession();
          sessionExpired = true;
          unawaited(api.logout());
        }
      case 'PIN_CHANGE_REQUIRED':
        mustChangePin = true;
      case 'NOT_A_WORKER':
      case 'WORKER_INACTIVE':
        _profileProblem = e.message;
    }
  }

  // ---- Mi jornada --------------------------------------------------------

  TodaySnapshot _today = TodaySnapshot.empty;

  /// Cambia cada vez que un registro o un envío trae un estado más nuevo,
  /// para que una consulta que venía en camino no lo pise con uno viejo.
  int _todayVersion = 0;

  /// Qué captura la app al registrar y si se permite registrar sin conexión.
  CaptureSettings capture = CaptureSettings.none;

  /// No se pudo llegar al servidor: se muestra la última copia guardada.
  bool offline = false;

  /// Vuelve a consultar el estado de hoy y lo que se captura.
  Future<void> refresh() async {
    if (!_signedIn) return;
    final int version = _todayVersion;
    try {
      final TodaySnapshot today = await api.today();
      final bool cached = api.servedFromCache;
      if (version == _todayVersion) {
        _today = today;
        final Employee? who = today.employee;
        if (who != null) employee = who;
        if (!cached) _noteServerTime(today.serverTime);
      }
      final CaptureSettings settings = await api.captureSettings();
      if (!_signedIn) return;
      capture = settings;
      offline = cached || api.servedFromCache;
      _profileProblem = null;
    } on LapsoException catch (e) {
      _absorb(e);
    }
    notifyListeners();
    if (_signedIn && !offline && _queue.isNotEmpty) unawaited(_autoSync());
  }

  String get centerName {
    final String? name = _today.workCenterName;
    if (name != null && name.isNotEmpty) return name;
    return capture.workCenterName;
  }

  /// Estado de la jornada, contando lo que aún está en el teléfono.
  WorkStatus get status {
    WorkStatus s = _today.status;
    for (final RegisterDraft draft in _queue) {
      s = applyEvent(s, draft.type);
    }
    return s;
  }

  /// Lo que se puede registrar ahora. Con conexión lo dice el servidor.
  Set<EventType> get allowedActions {
    if (_queue.isEmpty && _today.allowedActions.isNotEmpty) {
      return _today.allowedActions;
    }
    return actionsFor(status);
  }

  /// Registros de la jornada vigente, incluidos los pendientes de enviar.
  List<TimeEvent> get shift {
    if (_queue.isEmpty) return _today.events;
    return currentShift(<TimeEvent>[..._today.events, ...pending]);
  }

  Duration get worked {
    if (_queue.isEmpty && _today.status == WorkStatus.terminada) {
      return _today.worked;
    }
    return workedOf(shift, now);
  }

  Duration get pauses {
    if (_queue.isEmpty && _today.status == WorkStatus.terminada) {
      return _today.pauses;
    }
    return pausesOf(shift, now);
  }

  TimeEvent? get lastEvent {
    if (_queue.isNotEmpty) return _queue.last.toPendingEvent();
    return _today.lastEvent;
  }

  DateTime? get scheduledEnd => _today.scheduledEnd;

  /// Hay una jornada sin salida en los últimos 7 días.
  bool get hasIncompleteSession => _today.hasIncompleteSession;

  // ---- Jornada larga -----------------------------------------------------

  bool longSessionDismissed = false;

  bool get shouldWarnLongSession =>
      !longSessionDismissed && isLongSession(shift, now);

  void dismissLongSession() {
    longSessionDismissed = true;
    notifyListeners();
  }

  // ---- Registrar ---------------------------------------------------------

  static LocationResult _shownLocation(
    LocationReading? reading,
    CaptureRule rule,
  ) {
    if (!rule.accepted) return LocationResult.sinConsentimiento;
    if (reading == null) return LocationResult.noDisponible;
    if (reading.hasCoordinates) return LocationResult.capturada;
    return reading.status == 'DENEGADO'
        ? LocationResult.sinPermiso
        : LocationResult.noDisponible;
  }

  /// Registra una entrada, salida, pausa o reanudación.
  ///
  /// Con conexión devuelve el evento del servidor. Sin conexión, si la
  /// organización lo permite, lo guarda en el teléfono y devuelve el evento
  /// pendiente (`pending == true`). Nada de la evidencia bloquea el registro.
  ///
  /// Con [forceNewEntry] se registra una entrada aunque haya una jornada
  /// abierta de más de 16 horas; el servidor la marca como incompleta.
  Future<TimeEvent> register(
    EventType type, {
    PauseType? pauseType,
    QrReading? qr,
    LocationReading? location,
    PhotoCapture? photo,
    bool forceNewEntry = false,
  }) async {
    if (type == EventType.pausaInicio && pauseType == null) {
      throw const LapsoException('Elige el tipo de pausa.');
    }
    final CaptureSettings settings = capture;
    final bool canQueue = forceNewEntry || allowedActions.contains(type);
    final String? localProblem = validateNext(status, type);
    final DateTime declaredAt = now;
    final String key = newUuid();
    final bool locationAsked = settings.location.asks(type);
    final bool photoAsked = settings.photo.asks(type);
    final LocationReading? sentLocation =
        locationAsked && settings.location.active ? location : null;

    String? photoId;
    String? photoStatus;
    final Uint8List? jpeg = photo?.bytes;
    if (photoAsked && settings.photo.active) {
      if (jpeg != null) {
        try {
          photoId = await api.uploadPhoto(jpeg, capturedAt: photo?.capturedAt);
        } on LapsoException catch (e) {
          photoStatus = e.isNetwork ? 'NO_DISPONIBLE' : 'FALLO_SUBIDA';
        }
      } else {
        photoStatus = photo?.status ?? 'NO_DISPONIBLE';
      }
    }

    RegisterDraft build({String? photoId, String? photoStatus}) {
      return RegisterDraft(
        key: key,
        type: type,
        declaredAt: declaredAt,
        pauseType: type == EventType.pausaInicio ? pauseType : null,
        qr: settings.qr.asks(type) ? qr : null,
        location: sentLocation,
        photoId: photoId,
        photoStatus: photoStatus,
        monotonicMs: _monotonic.elapsedMilliseconds,
        monotonicSession: _monotonicSession,
        clockReference: _clockReference,
        evidence: Evidence(
          qrRead: settings.qr.asks(type) ? qr != null : null,
          location: locationAsked
              ? _shownLocation(location, settings.location)
              : null,
          photoTaken: photoAsked ? false : null,
        ),
      );
    }

    try {
      final RegisterResult result = await api.register(
        build(photoId: photoId, photoStatus: photoStatus),
      );
      _today = result.today;
      _todayVersion++;
      final Employee? who = result.today.employee;
      if (who != null) employee = who;
      _noteServerTime(result.today.serverTime);
      offline = false;
      if (type == EventType.entrada) longSessionDismissed = false;
      notifyListeners();
      unawaited(reloadHistory());
      return result.event;
    } on LapsoException catch (e) {
      if (!e.isNetwork) {
        _absorb(e);
        notifyListeners();
        // El estado que tenía la app ya no era el del servidor.
        if (e.status == 409) unawaited(refresh());
        rethrow;
      }
    }

    // Sin conexión: el registro se guarda en el teléfono.
    offline = true;
    if (!settings.offlineAllowed) {
      notifyListeners();
      throw const LapsoException(
        'No hay conexión y tu organización no permite registrar sin '
        'conexión. Inténtalo cuando tengas señal.',
        code: 'OFFLINE_DISABLED',
      );
    }
    if (!canQueue) {
      notifyListeners();
      throw LapsoException(
        localProblem ?? 'Ese registro no procede en este momento.',
      );
    }
    // Una foto no se puede enviar después: el registro va sin ella.
    final RegisterDraft queued = build(
      photoStatus: photoAsked && settings.photo.active ? 'NO_DISPONIBLE' : null,
    );
    _queue.add(queued);
    await _saveQueue();
    _startSyncTimer();
    if (type == EventType.entrada) longSessionDismissed = false;
    notifyListeners();
    return queued.toPendingEvent();
  }

  // ---- Sin conexión ------------------------------------------------------

  final List<RegisterDraft> _queue = <RegisterDraft>[];
  List<Rejection> _rejections = const <Rejection>[];
  Timer? _syncTimer;
  Future<int>? _syncInFlight;

  /// Registros guardados en el teléfono que aún no se envían.
  List<TimeEvent> get pending => <TimeEvent>[
        for (final RegisterDraft draft in _queue) draft.toPendingEvent(),
      ];

  /// Registros sin conexión que el servidor no aceptó.
  List<Rejection> get rejections => _rejections;

  String get _queueKey =>
      'lapso.queue.${organization?.slug ?? ''}.${_loginId ?? ''}';

  Future<void> _loadQueue() async {
    _queue.clear();
    final String? raw = await store.read(_queueKey);
    if (raw == null) return;
    try {
      for (final Json json in asJsonList(jsonDecode(raw))) {
        final RegisterDraft? draft = draftFromStore(json);
        if (draft != null) _queue.add(draft);
      }
    } on FormatException {
      // Una cola ilegible no debe impedir entrar.
    }
    if (_queue.isNotEmpty) _startSyncTimer();
  }

  Future<void> _saveQueue() async {
    if (_queue.isEmpty) {
      await store.delete(_queueKey);
      return;
    }
    await store.write(
      _queueKey,
      jsonEncode(<Json>[
        for (final RegisterDraft draft in _queue) draftToStore(draft),
      ]),
    );
  }

  void _startSyncTimer() {
    _syncTimer ??= Timer.periodic(
      const Duration(seconds: 45),
      (Timer _) => unawaited(_autoSync()),
    );
  }

  Future<void> _autoSync() async {
    if (!_signedIn || _queue.isEmpty || _syncInFlight != null) return;
    try {
      await syncPending();
    } on LapsoException {
      // Se reintenta en el siguiente ciclo.
    }
  }

  /// Envía los registros pendientes. Devuelve cuántos aceptó el servidor.
  /// Los rechazados salen de la cola y quedan en [rejections].
  ///
  /// Si ya hay un envío en curso, espera ese mismo.
  Future<int> syncPending() {
    final Future<int>? running = _syncInFlight;
    if (running != null) return running;
    final Future<int> run = _sync().whenComplete(() {
      _syncInFlight = null;
    });
    _syncInFlight = run;
    return run;
  }

  Future<int> _sync() async {
    if (_queue.isEmpty) return 0;
    try {
      int accepted = 0;
      while (_queue.isNotEmpty) {
        final List<RegisterDraft> batch = _queue.take(50).toList();
        final SyncResult result = await api.sync(batch);
        final Set<String> answered = <String>{};
        for (final SyncItem item in result.items) {
          answered.add(item.key);
          if (item.outcome != SyncOutcome.rejected) accepted++;
        }
        _queue.removeWhere((RegisterDraft d) => answered.contains(d.key));
        final TodaySnapshot? today = result.today;
        if (today != null) {
          _today = today;
          _todayVersion++;
          _noteServerTime(today.serverTime);
        }
        await _saveQueue();
        if (answered.isEmpty) break;
      }
      offline = false;
      if (_queue.isEmpty) {
        _syncTimer?.cancel();
        _syncTimer = null;
      }
      try {
        _rejections = await api.rejections();
      } on LapsoException {
        // Los rechazos se vuelven a pedir al abrir la pantalla.
      }
      unawaited(reloadHistory());
      return accepted;
    } on LapsoException catch (e) {
      _absorb(e);
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  // ---- Historial ---------------------------------------------------------

  List<DaySummary> _days = const <DaySummary>[];

  /// El historial ya se consultó al menos una vez.
  bool historyLoaded = false;

  /// Días con información, del más reciente al más antiguo.
  List<DaySummary> get days => _days;

  DaySummary? dayAt(DateTime day) {
    for (final DaySummary summary in _days) {
      if (isSameDay(summary.day, day)) return summary;
    }
    return null;
  }

  /// Registros con foto que todavía se puede consultar.
  List<TimeEvent> get photoEvents => <TimeEvent>[
        for (final DaySummary day in _days)
          for (final TimeEvent event in day.events.reversed)
            if (event.evidence.photoAvailable) event,
      ];

  Future<void> reloadHistory() async {
    if (!_signedIn) return;
    try {
      final DateTime today = dayOf(now);
      _days = await api.history(
        from: DateTime(today.year, today.month, today.day - kHistoryDays + 1),
        to: today,
      );
      historyLoaded = true;
    } on LapsoException catch (e) {
      _absorb(e);
    }
    notifyListeners();
  }

  // ---- Mis datos de captura ---------------------------------------------

  List<EvidenceView> _views = const <EvidenceView>[];

  /// Contacto de soporte de la organización.
  SupportContact support = SupportContact.none;

  bool consent(Capability c) => capture.rule(c).accepted;

  List<EvidenceView> get evidenceViews => _views;

  /// Acepta o retira el consentimiento de una captura.
  Future<void> setConsent(Capability c, {required bool accepted}) async {
    final int? notice = capture.noticeVersion;
    if (accepted && notice == null) {
      throw const LapsoException(
        'Todavía no hay un aviso de privacidad publicado. Inténtalo más '
        'tarde.',
      );
    }
    try {
      await api.setConsent(c, accepted: accepted, noticeVersion: notice);
      capture = await api.captureSettings();
    } on LapsoException catch (e) {
      _absorb(e);
      notifyListeners();
      rethrow;
    }
    notifyListeners();
  }

  Future<void> reloadEvidenceViews() async {
    try {
      _views = await api.evidenceViews();
    } on LapsoException catch (e) {
      _absorb(e);
    }
    notifyListeners();
  }

  Future<void> reloadRejections() async {
    try {
      _rejections = await api.rejections();
    } on LapsoException catch (e) {
      _absorb(e);
    }
    notifyListeners();
  }

  /// Lo que no hace falta para registrar: historial, transparencia, soporte.
  Future<void> _loadSecondary() async {
    await reloadHistory();
    await reloadEvidenceViews();
    await reloadRejections();
    try {
      support = await api.supportContact();
      notifyListeners();
    } on LapsoException {
      // Sin contacto de soporte la pantalla de ayuda muestra solo a RH.
    }
  }

  // ---- Herramientas de demostración -------------------------------------

  bool get locationPermission {
    final DeviceCapture d = device;
    return d is! FakeDeviceCapture || d.locationPermission;
  }

  /// El reloj del teléfono va dos horas adelante del servidor.
  bool get phoneClockAhead => _phoneSkew != Duration.zero;

  void setOffline(bool value) {
    final LapsoApi a = api;
    if (a is! FakeLapsoApi) return;
    a.offline = value;
    offline = value;
    notifyListeners();
    unawaited(refresh());
  }

  void setLocationPermission(bool value) {
    final DeviceCapture d = device;
    if (d is! FakeDeviceCapture) return;
    d.locationPermission = value;
    notifyListeners();
  }

  void setPhoneClockAhead(bool value) {
    _phoneSkew = value ? const Duration(hours: 2) : Duration.zero;
    notifyListeners();
  }

  /// Simula que pasó el tiempo, en el teléfono y en el servidor.
  void advanceClock(Duration by) {
    _demoOffset += by;
    _applyDemoClock();
  }

  void resetClock() {
    _demoOffset = Duration.zero;
    _applyDemoClock();
  }

  void _applyDemoClock() {
    final LapsoApi a = api;
    if (a is FakeLapsoApi) a.clockOffset = _demoOffset;
    notifyListeners();
    unawaited(refresh());
  }

  bool _disposed = false;

  /// Las consultas que venían en camino al cerrar la app no avisan a nadie.
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _syncTimer?.cancel();
    super.dispose();
  }
}
