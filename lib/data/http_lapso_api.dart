import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../config.dart';
import '../domain/format.dart';
import '../domain/models.dart';
import 'key_value_store.dart';
import 'lapso_api.dart';
import 'mappers.dart';

/// Cliente HTTP de la API de Lapso (contrato 0.9.0).
///
/// - La sesión es la cookie `flu3nce_session`. Se guarda en el almacén
///   seguro del teléfono y se reenvía en cada solicitud.
/// - Los errores llegan como `application/problem+json`; se convierten en
///   [LapsoException] con el `code` del servidor.
/// - Si no hay red, [today], [captureSettings] y [restoreSession] responden
///   con la última copia guardada y dejan [servedFromCache] en verdadero,
///   para que la persona pueda registrar sin conexión.
class HttpLapsoApi implements LapsoApi {
  HttpLapsoApi({
    required this.store,
    this.baseUrl = kApiBaseUrl,
    HttpClient? client,
  }) : _client = client ?? HttpClient() {
    _client.connectionTimeout = const Duration(seconds: 10);
  }

  final KeyValueStore store;
  final String baseUrl;
  final HttpClient _client;

  static const String _cookieName = 'flu3nce_session';
  static const String _cookieKey = 'lapso.session';
  static const String _cacheMe = 'lapso.cache.me';
  static const String _cacheToday = 'lapso.cache.today';
  static const String _cacheCapture = 'lapso.cache.capture';
  static const Duration _timeout = Duration(seconds: 20);

  String? _cookie;
  bool _cookieLoaded = false;

  @override
  bool servedFromCache = false;

  // ---- Transporte --------------------------------------------------------

  Future<void> _loadCookie() async {
    if (_cookieLoaded) return;
    _cookie = await store.read(_cookieKey);
    _cookieLoaded = true;
  }

  Future<void> _setCookie(String? value) async {
    _cookie = value;
    _cookieLoaded = true;
    if (value == null) {
      await store.delete(_cookieKey);
    } else {
      await store.write(_cookieKey, value);
    }
  }

  /// Lee la cookie de sesión de la respuesta, si el servidor la cambió.
  Future<void> _captureCookie(HttpClientResponse response) async {
    final List<String>? lines = response.headers[HttpHeaders.setCookieHeader];
    if (lines == null) return;
    for (final String line in lines) {
      final String pair = line.split(';').first;
      final int eq = pair.indexOf('=');
      if (eq <= 0) continue;
      if (pair.substring(0, eq).trim() != _cookieName) continue;
      final String value = pair.substring(eq + 1).trim();
      final bool expired = line.toLowerCase().contains('max-age=0');
      await _setCookie(value.isEmpty || expired ? null : value);
    }
  }

  Future<_Reply> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? json,
    Uint8List? bytes,
    String? contentType,
    String? idempotencyKey,
  }) async {
    await _loadCookie();
    Uri uri = Uri.parse('$baseUrl$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }
    try {
      final HttpClientRequest request =
          await _client.openUrl(method, uri).timeout(_timeout);
      request.followRedirects = false;
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/json, application/problem+json, image/jpeg',
      );
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'LapsoJornada/$kAppVersion (${Platform.operatingSystem})',
      );
      if (kGateUser.isNotEmpty) {
        // Candado del ambiente de validación (no es la sesión de la persona).
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Basic ${base64Encode(utf8.encode('$kGateUser:$kGatePass'))}',
        );
      }
      final String? cookie = _cookie;
      if (cookie != null) {
        request.headers.set(HttpHeaders.cookieHeader, '$_cookieName=$cookie');
      }
      if (idempotencyKey != null) {
        request.headers.set('Idempotency-Key', idempotencyKey);
      }
      if (json != null) {
        final List<int> body = utf8.encode(jsonEncode(json));
        request.headers.set(
          HttpHeaders.contentTypeHeader,
          'application/json; charset=utf-8',
        );
        request.contentLength = body.length;
        request.add(body);
      } else if (bytes != null) {
        request.headers.set(
          HttpHeaders.contentTypeHeader,
          contentType ?? 'application/octet-stream',
        );
        request.contentLength = bytes.length;
        request.add(bytes);
      } else {
        request.contentLength = 0;
      }
      final HttpClientResponse response =
          await request.close().timeout(_timeout);
      final BytesBuilder builder = BytesBuilder(copy: false);
      await response.forEach(builder.add).timeout(_timeout);
      final Uint8List data = builder.takeBytes();
      await _captureCookie(response);
      if (response.statusCode >= 400) throw _problem(response, data);
      return _Reply(response.statusCode, data);
    } on LapsoException {
      rethrow;
    } on TimeoutException {
      throw const LapsoException.network();
    } on IOException {
      // Sin red, servidor inalcanzable o falla de TLS.
      throw const LapsoException.network();
    }
  }

  LapsoException _problem(HttpClientResponse response, Uint8List data) {
    final int status = response.statusCode;
    String code = _fallbackCode(status);
    String? detail;
    try {
      final Json? body = asJson(jsonDecode(utf8.decode(data)));
      if (body != null) {
        final Object? rawCode = body['code'];
        if (rawCode is String && rawCode.isNotEmpty) code = rawCode;
        final Object? rawDetail = body['detail'] ?? body['title'];
        if (rawDetail is String && rawDetail.isNotEmpty) detail = rawDetail;
        // En un 422 el servidor dice qué dato está mal.
        final List<Json> errors = asJsonList(body['errors']);
        if (errors.isNotEmpty && errors.first['message'] is String) {
          detail = errors.first['message'] as String;
        }
      }
    } on FormatException {
      // La respuesta no es JSON; se usa el mensaje genérico.
    }
    Duration? retryAfter;
    final int? seconds =
        int.tryParse(response.headers.value('retry-after') ?? '');
    if (seconds != null) retryAfter = Duration(seconds: seconds);
    return LapsoException(
      detail ?? _fallbackMessage(status),
      code: code,
      status: status,
      retryAfter: retryAfter,
    );
  }

  static String _fallbackCode(int status) {
    switch (status) {
      case 401:
        return 'UNAUTHENTICATED';
      case 403:
        return 'FORBIDDEN';
      case 404:
        return 'NOT_FOUND';
      case 423:
        return 'ACCOUNT_LOCKED';
      case 429:
        return 'RATE_LIMITED';
      case 503:
        return 'SERVICE_UNAVAILABLE';
      default:
        return 'ERROR';
    }
  }

  static String _fallbackMessage(int status) {
    switch (status) {
      case 401:
        return 'Tu sesión terminó. Entra de nuevo.';
      case 429:
        return 'Demasiados intentos. Espera un momento e inténtalo de nuevo.';
      case 503:
        return 'El servicio no está disponible. Inténtalo de nuevo.';
      default:
        return 'No se pudo completar la operación.';
    }
  }

  Json _jsonOf(_Reply reply) {
    if (reply.data.isEmpty) return <String, dynamic>{};
    try {
      return asJson(jsonDecode(utf8.decode(reply.data))) ??
          <String, dynamic>{};
    } on FormatException {
      throw const LapsoException(
        'El servidor respondió algo que la app no entiende.',
        code: 'BAD_RESPONSE',
      );
    }
  }

  /// GET que guarda su respuesta y, si no hay red, devuelve la guardada.
  Future<Json> _getCached(String path, String cacheKey) async {
    try {
      final _Reply reply = await _send('GET', path);
      servedFromCache = false;
      await store.write(cacheKey, utf8.decode(reply.data));
      return _jsonOf(reply);
    } on LapsoException catch (e) {
      if (!e.isNetwork) rethrow;
      final String? saved = await store.read(cacheKey);
      if (saved == null) rethrow;
      final Json? json = asJson(jsonDecode(saved));
      if (json == null) rethrow;
      servedFromCache = true;
      return json;
    }
  }

  Future<void> _clearSession() async {
    await _setCookie(null);
    await store.delete(_cacheMe);
    await store.delete(_cacheToday);
    await store.delete(_cacheCapture);
  }

  // ---- Operaciones -------------------------------------------------------

  @override
  Future<Organization?> findOrganization(String slug) async {
    try {
      final _Reply reply = await _send(
        'GET',
        '/tenants/${Uri.encodeComponent(slug)}/public',
      );
      return organizationOf(_jsonOf(reply));
    } on LapsoException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  @override
  Future<Organization?> resolveOrganizationQr(String token) async {
    try {
      final _Reply reply =
          await _send('GET', '/qr/${Uri.encodeComponent(token)}');
      return organizationOf(asJson(_jsonOf(reply)['tenant']));
    } on LapsoException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  @override
  Future<Session> login({
    required String tenant,
    required String employeeNumber,
    required String pin,
  }) async {
    final _Reply reply = await _send(
      'POST',
      '/auth/pin',
      json: <String, dynamic>{
        'tenant': tenant,
        'login_id': employeeNumber.trim(),
        'pin': pin,
      },
    );
    servedFromCache = false;
    await store.write(_cacheMe, utf8.decode(reply.data));
    return sessionOf(_jsonOf(reply));
  }

  @override
  Future<Session?> restoreSession() async {
    await _loadCookie();
    if (_cookie == null) return null;
    try {
      return sessionOf(await _getCached('/me', _cacheMe));
    } on LapsoException catch (e) {
      if (e.isUnauthenticated) {
        await _clearSession();
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<void> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    await _send(
      'POST',
      '/auth/pin/change',
      json: <String, dynamic>{'current_pin': currentPin, 'new_pin': newPin},
    );
  }

  @override
  Future<void> logout() async {
    try {
      await _send('POST', '/auth/logout');
    } on LapsoException {
      // Sin red o con la sesión ya vencida, igual se borra en el teléfono.
    }
    await _clearSession();
  }

  @override
  Future<TodaySnapshot> today() async {
    return todayOf(await _getCached('/me/today', _cacheToday));
  }

  @override
  Future<CaptureSettings> captureSettings() async {
    return captureSettingsOf(await _getCached('/me/capture', _cacheCapture));
  }

  @override
  Future<String> uploadPhoto(Uint8List jpeg, {DateTime? capturedAt}) async {
    final _Reply reply = await _send(
      'POST',
      '/evidence/photos',
      query: capturedAt == null
          ? null
          : <String, String>{
              'captured_at': capturedAt.toUtc().toIso8601String(),
            },
      bytes: jpeg,
      contentType: 'image/jpeg',
    );
    final Object? id = _jsonOf(reply)['photo_id'];
    if (id is! String) {
      throw const LapsoException(
        'No se pudo subir la foto.',
        code: 'BAD_RESPONSE',
      );
    }
    return id;
  }

  @override
  Future<RegisterResult> register(RegisterDraft draft) async {
    final _Reply reply = await _send(
      'POST',
      clockPath(draft.type),
      json: clockBody(draft),
      idempotencyKey: draft.key,
    );
    final Json body = _jsonOf(reply);
    final TimeEvent? event = eventOf(asJson(body['event']));
    final Json? today = asJson(body['today']);
    if (event == null || today == null) {
      throw const LapsoException(
        'El servidor respondió algo que la app no entiende.',
        code: 'BAD_RESPONSE',
      );
    }
    servedFromCache = false;
    await store.write(_cacheToday, jsonEncode(today));
    return RegisterResult(event: event, today: todayOf(today));
  }

  @override
  Future<SyncResult> sync(List<RegisterDraft> drafts) async {
    final _Reply reply = await _send(
      'POST',
      '/time-events/sync',
      json: <String, dynamic>{
        'events': <Json>[
          for (final RegisterDraft draft in drafts) offlineEventBody(draft),
        ],
      },
    );
    final Json body = _jsonOf(reply);
    final Json? today = asJson(body['today']);
    if (today != null) {
      servedFromCache = false;
      await store.write(_cacheToday, jsonEncode(today));
    }
    return syncResultOf(body);
  }

  @override
  Future<List<DaySummary>> history({
    required DateTime from,
    required DateTime to,
  }) async {
    final _Reply reply = await _send(
      'GET',
      '/me/timesheets',
      query: <String, String>{'from': isoDate(from), 'to': isoDate(to)},
    );
    return timesheetOf(_jsonOf(reply));
  }

  @override
  Future<void> setConsent(
    Capability capability, {
    required bool accepted,
    int? noticeVersion,
  }) async {
    final String code = capabilityCode(capability);
    if (accepted) {
      await _send(
        'POST',
        '/me/consents',
        json: <String, dynamic>{
          'capability': code,
          'notice_version': noticeVersion,
        },
      );
    } else {
      await _send('POST', '/me/consents/$code/revoke');
    }
  }

  @override
  Future<List<EvidenceView>> evidenceViews() async {
    final _Reply reply = await _send(
      'GET',
      '/me/evidence-views',
      query: const <String, String>{'limit': '100'},
    );
    return evidenceViewsOf(_jsonOf(reply));
  }

  @override
  Future<List<Rejection>> rejections() async {
    final _Reply reply = await _send(
      'GET',
      '/me/offline/rejections',
      query: const <String, String>{'limit': '50'},
    );
    return rejectionsOf(_jsonOf(reply));
  }

  @override
  Future<LegalText?> legalText(String kind) async {
    try {
      final _Reply reply =
          await _send('GET', '/public/legal/${Uri.encodeComponent(kind)}');
      return legalTextOf(_jsonOf(reply));
    } on LapsoException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  @override
  Future<Uint8List?> eventPhoto(String eventId) async {
    try {
      final _Reply reply = await _send(
        'GET',
        '/me/events/${Uri.encodeComponent(eventId)}/photo',
      );
      return reply.data.isEmpty ? null : reply.data;
    } on LapsoException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  @override
  Future<SupportContact> supportContact() async {
    final _Reply reply = await _send('GET', '/branding/current');
    return supportContactOf(_jsonOf(reply));
  }
}

class _Reply {
  const _Reply(this.status, this.data);
  final int status;
  final Uint8List data;
}
