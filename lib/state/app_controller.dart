import 'package:flutter/foundation.dart';

import '../data/lapso_api.dart';
import '../domain/models.dart';
import '../domain/rules.dart';

/// Estado de toda la app. Las pantallas lo leen con `AppScope.of(context)`.
class AppController extends ChangeNotifier {
  AppController({required this.api, this.demoTools = false});

  final LapsoApi api;

  /// Muestra en Más las herramientas para simular estados (sin conexión,
  /// sin permiso de ubicación, jornada larga). Solo con el servidor simulado.
  final bool demoTools;

  // ---- Reloj -------------------------------------------------------------

  Duration _clockOffset = Duration.zero;

  /// Hora actual. En demostración puede adelantarse con [advanceClock].
  DateTime get now => DateTime.now().add(_clockOffset);

  // ---- Sesión ------------------------------------------------------------

  Organization? organization;
  Employee? employee;
  WorkCenter? center;
  bool mustChangePin = false;
  DateTime? lockedUntil;

  bool get hasOrganization => organization != null;
  bool get loggedIn => employee != null;

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

  /// Devuelve `null` si la organización existe; si no, el mensaje de error.
  Future<String?> chooseOrganization(String code) async {
    if (code.trim().isEmpty) return 'Escribe el código de tu organización.';
    if (offline) return 'Para entrar necesitas conexión a internet.';
    final Organization? found = await api.findOrganization(code);
    if (found == null) {
      return 'No encontramos esa organización. Revisa el código o pídelo de '
          'nuevo a Recursos Humanos.';
    }
    organization = found;
    notifyListeners();
    return null;
  }

  void forgetOrganization() {
    organization = null;
    lockedUntil = null;
    notifyListeners();
  }

  Future<LoginResult> login(String employeeNumber, String pin) async {
    final Organization? org = organization;
    if (org == null) {
      throw const LapsoException('Primero elige tu organización.');
    }
    if (offline) {
      throw const LapsoException('Para entrar necesitas conexión a internet.');
    }
    final LoginResult result = await api.login(
      organization: org,
      employeeNumber: employeeNumber,
      pin: pin,
      now: now,
    );
    switch (result.status) {
      case LoginStatus.ok:
        _currentPin = pin;
        lockedUntil = null;
        center = await api.workCenter();
        _events
          ..clear()
          ..addAll(await api.history());
        _consents
          ..clear()
          ..addAll(await api.consents());
        _views
          ..clear()
          ..addAll(await api.evidenceViews());
        _rejections
          ..clear()
          ..addAll(await api.rejections());
        mustChangePin = result.mustChangePin;
        employee = result.employee;
        longSessionDismissed = false;
      case LoginStatus.locked:
        lockedUntil = result.lockedUntil;
      case LoginStatus.wrongCredentials:
      case LoginStatus.noWorkerProfile:
        break;
    }
    notifyListeners();
    return result;
  }

  String? _currentPin;

  bool isCurrentPin(String pin) => pin == _currentPin;

  /// Quita el bloqueo cuando ya pasó el tiempo de espera.
  void clearExpiredLock() {
    if (!isLocked) {
      lockedUntil = null;
      notifyListeners();
    }
  }

  /// Devuelve `null` si el PIN se cambió; si no, el motivo.
  Future<String?> changePin(String newPin) async {
    final Employee? who = employee;
    if (who == null) return 'Tu sesión terminó. Vuelve a entrar.';
    final String? problem = validateNewPin(
      newPin,
      employeeNumber: who.number,
      currentPin: _currentPin,
    );
    if (problem != null) return problem;
    if (offline) return 'Para cambiar tu PIN necesitas conexión a internet.';
    await api.changePin(newPin);
    _currentPin = newPin;
    mustChangePin = false;
    notifyListeners();
    return null;
  }

  Future<void> logout() async {
    if (!offline) await api.logout();
    employee = null;
    center = null;
    mustChangePin = false;
    _currentPin = null;
    _events.clear();
    _pending.clear();
    notifyListeners();
  }

  // ---- Jornada -----------------------------------------------------------

  final List<TimeEvent> _events = <TimeEvent>[];
  final List<TimeEvent> _pending = <TimeEvent>[];
  final List<Rejection> _rejections = <Rejection>[];
  int _localId = 0;

  /// Todos los registros conocidos, enviados o no, en orden cronológico.
  List<TimeEvent> get allEvents {
    final List<TimeEvent> all = <TimeEvent>[..._events, ..._pending];
    all.sort((TimeEvent a, TimeEvent b) => a.at.compareTo(b.at));
    return all;
  }

  List<TimeEvent> get pending => List<TimeEvent>.unmodifiable(_pending);
  List<Rejection> get rejections => List<Rejection>.unmodifiable(_rejections);

  /// Registros de la jornada vigente. Una jornada terminada en un día
  /// anterior ya no cuenta: hoy empieza sin entrada.
  List<TimeEvent> get shift {
    final List<TimeEvent> s = currentShift(allEvents);
    if (s.isEmpty) return s;
    if (statusOf(s) == WorkStatus.terminada && !isSameDay(s.first.at, now)) {
      return const <TimeEvent>[];
    }
    return s;
  }

  WorkStatus get status => statusOf(shift);
  Duration get worked => workedOf(shift, now);
  Duration get pauses => pausesOf(shift, now);

  /// Último registro antes de la jornada vigente (para "Último movimiento").
  TimeEvent? get lastEvent {
    final List<TimeEvent> all = allEvents;
    return all.isEmpty ? null : all.last;
  }

  DateTime? get scheduledEnd {
    final WorkCenter? c = center;
    final List<TimeEvent> s = shift;
    if (c == null) return null;
    final DateTime base = s.isEmpty ? now : s.first.at;
    return DateTime(base.year, base.month, base.day, c.endHour);
  }

  bool longSessionDismissed = false;

  bool get shouldWarnLongSession =>
      !longSessionDismissed && isLongSession(shift, now);

  void dismissLongSession() {
    longSessionDismissed = true;
    notifyListeners();
  }

  /// Registra un evento. Sin conexión lo guarda en el teléfono como pendiente.
  ///
  /// Lanza [LapsoException] si la regla de negocio no lo permite.
  Future<TimeEvent> register(
    EventType type, {
    PauseType? pauseType,
    Evidence evidence = Evidence.none,
    bool forceNewEntry = false,
  }) async {
    final WorkStatus current = forceNewEntry ? WorkStatus.sinEntrada : status;
    final String? problem = validateNext(current, type);
    if (problem != null) throw LapsoException(problem);
    if (type == EventType.pausaInicio && pauseType == null) {
      throw const LapsoException('Elige el tipo de pausa.');
    }
    _localId += 1;
    final TimeEvent draft = TimeEvent(
      id: 'local-$_localId',
      type: type,
      at: now,
      pauseType: pauseType,
      offline: offline,
      evidence: evidence,
    );
    late final TimeEvent saved;
    if (offline) {
      _pending.add(draft);
      saved = draft;
    } else {
      saved = await api.register(draft);
      _events.add(saved);
    }
    if (type == EventType.entrada) longSessionDismissed = false;
    notifyListeners();
    return saved;
  }

  /// Envía los pendientes. Devuelve cuántos aceptó el servidor.
  Future<int> syncPending() async {
    if (_pending.isEmpty) return 0;
    if (offline) {
      throw const LapsoException(
        'Sin señal por ahora. Se enviarán solos al reconectar.',
      );
    }
    final SyncResult result = await api.sync(
      List<TimeEvent>.of(_pending),
      now: now,
    );
    _pending.clear();
    _events.addAll(result.accepted);
    _rejections.addAll(result.rejected);
    notifyListeners();
    return result.accepted.length;
  }

  // ---- Evidencia y consentimientos ---------------------------------------

  final Map<Capability, bool> _consents = <Capability, bool>{};
  final List<EvidenceView> _views = <EvidenceView>[];

  bool consent(Capability c) => _consents[c] ?? false;
  List<EvidenceView> get evidenceViews =>
      List<EvidenceView>.unmodifiable(_views);

  Future<void> setConsent(Capability c, {required bool accepted}) async {
    _consents[c] = accepted;
    notifyListeners();
    if (!offline) await api.setConsent(c, accepted: accepted);
  }

  /// Permiso de ubicación del sistema. En la app real lo da el teléfono.
  bool locationPermission = true;

  /// Hace la única lectura de ubicación del registro.
  ///
  /// Punto de integración: aquí va la lectura real del GPS y la comparación
  /// con la zona del centro.
  Future<LocationResult> readLocation() async {
    if (!consent(Capability.ubicacion)) return LocationResult.sinConsentimiento;
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!locationPermission) return LocationResult.sinPermiso;
    return LocationResult.dentro;
  }

  // ---- Conexión y herramientas de demostración ---------------------------

  bool offline = false;

  void setOffline(bool value) {
    offline = value;
    notifyListeners();
  }

  void setLocationPermission(bool value) {
    locationPermission = value;
    notifyListeners();
  }

  void advanceClock(Duration by) {
    _clockOffset += by;
    notifyListeners();
  }

  void resetClock() {
    _clockOffset = Duration.zero;
    notifyListeners();
  }
}
