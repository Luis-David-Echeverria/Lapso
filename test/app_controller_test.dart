import 'package:flutter_test/flutter_test.dart';
import 'package:lapso_jornada/data/fake_lapso_api.dart';
import 'package:lapso_jornada/data/lapso_api.dart';
import 'package:lapso_jornada/domain/models.dart';
import 'package:lapso_jornada/state/app_controller.dart';

Future<AppController> signedIn() async {
  final AppController c = AppController(api: FakeLapsoApi());
  expect(await c.chooseOrganization('campo-prueba'), isNull);
  final LoginResult r = await c.login('gil-001', '482913');
  expect(r.status, LoginStatus.ok);
  return c;
}

void main() {
  test('una organización desconocida devuelve un mensaje', () async {
    final AppController c = AppController(api: FakeLapsoApi());
    expect(await c.chooseOrganization('no-existe'), isNotNull);
    expect(c.hasOrganization, isFalse);
  });

  test('el tercer PIN incorrecto bloquea la cuenta', () async {
    final AppController c = AppController(api: FakeLapsoApi());
    await c.chooseOrganization('campo-prueba');

    final LoginResult first = await c.login('GIL-001', '000000');
    expect(first.status, LoginStatus.wrongCredentials);
    expect(first.attemptsLeft, 2);

    await c.login('GIL-001', '000000');
    final LoginResult third = await c.login('GIL-001', '000000');
    expect(third.status, LoginStatus.locked);
    expect(c.isLocked, isTrue);
    expect(c.loggedIn, isFalse);

    final LoginResult right = await c.login('GIL-001', '482913');
    expect(right.status, LoginStatus.locked);
  });

  test('el PIN temporal obliga a cambiarlo', () async {
    final AppController c = AppController(api: FakeLapsoApi());
    await c.chooseOrganization('campo-prueba');
    await c.login('GIL-001', '735194');
    expect(c.loggedIn, isTrue);
    expect(c.mustChangePin, isTrue);

    expect(await c.changePin('735194'), isNotNull);
    expect(await c.changePin('123456'), isNotNull);
    expect(await c.changePin('608417'), isNull);
    expect(c.mustChangePin, isFalse);
    expect(c.isCurrentPin('608417'), isTrue);
  });

  test('una jornada completa: entrada, pausa, reanudación y salida', () async {
    final AppController c = await signedIn();
    expect(c.status, WorkStatus.sinEntrada);

    final TimeEvent entry = await c.register(EventType.entrada);
    expect(entry.pending, isFalse);
    expect(entry.seq, isNotNull);
    expect(entry.hash, isNotNull);
    expect(c.status, WorkStatus.enJornada);

    await expectLater(
      c.register(EventType.entrada),
      throwsA(isA<LapsoException>()),
    );
    await expectLater(
      c.register(EventType.pausaInicio),
      throwsA(isA<LapsoException>()),
    );

    await c.register(EventType.pausaInicio, pauseType: PauseType.comida);
    expect(c.status, WorkStatus.enPausa);
    await expectLater(
      c.register(EventType.salida),
      throwsA(isA<LapsoException>()),
    );

    await c.register(EventType.pausaFin);
    expect(c.status, WorkStatus.enJornada);

    await c.register(EventType.salida);
    expect(c.status, WorkStatus.terminada);
    expect(c.shift.length, 4);
  });

  test('sin conexión el registro queda pendiente y luego se envía', () async {
    final AppController c = await signedIn();
    c.setOffline(true);

    final TimeEvent entry = await c.register(EventType.entrada);
    expect(entry.pending, isTrue);
    expect(c.pending.length, 1);
    expect(c.status, WorkStatus.enJornada);
    await expectLater(c.syncPending(), throwsA(isA<LapsoException>()));

    c.setOffline(false);
    expect(await c.syncPending(), 1);
    expect(c.pending, isEmpty);
    expect(c.rejections, isEmpty);
    expect(c.status, WorkStatus.enJornada);
    expect(c.shift.single.pending, isFalse);
  });

  test('un registro con el reloj adelantado se rechaza al enviar', () async {
    final AppController c = await signedIn();
    c.setOffline(true);
    c.advanceClock(const Duration(hours: 2));
    await c.register(EventType.entrada);

    c.resetClock();
    c.setOffline(false);
    expect(await c.syncPending(), 0);
    expect(c.pending, isEmpty);
    expect(c.rejections.length, 1);
    expect(c.status, WorkStatus.sinEntrada);
  });

  test('una jornada de más de 16 horas dispara el aviso', () async {
    final AppController c = await signedIn();
    await c.register(EventType.entrada);
    expect(c.shouldWarnLongSession, isFalse);

    c.advanceClock(const Duration(hours: 17));
    expect(c.shouldWarnLongSession, isTrue);

    await c.register(EventType.entrada, forceNewEntry: true);
    expect(c.shouldWarnLongSession, isFalse);
    expect(c.shift.length, 1);
  });

  test('sin consentimiento no se lee la ubicación', () async {
    final AppController c = await signedIn();
    expect(await c.readLocation(), LocationResult.dentro);

    await c.setConsent(Capability.ubicacion, accepted: false);
    expect(await c.readLocation(), LocationResult.sinConsentimiento);

    await c.setConsent(Capability.ubicacion, accepted: true);
    c.setLocationPermission(false);
    expect(await c.readLocation(), LocationResult.sinPermiso);
  });

  test('cerrar sesión limpia la sesión', () async {
    final AppController c = await signedIn();
    await c.logout();
    expect(c.loggedIn, isFalse);
    expect(c.hasOrganization, isTrue);
    expect(c.allEvents, isEmpty);
  });
}
