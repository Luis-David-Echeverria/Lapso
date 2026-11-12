import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lapso_jornada/app.dart';
import 'package:lapso_jornada/data/fake_lapso_api.dart';
import 'package:lapso_jornada/platform/device_capture.dart';
import 'package:lapso_jornada/state/app_controller.dart';

Future<AppController> pumpApp(WidgetTester tester) async {
  final AppController controller = AppController(
    api: FakeLapsoApi(),
    device: FakeDeviceCapture(),
  );
  await tester.pumpWidget(LapsoApp(controller: controller));
  await controller.start();
  await tester.pump();
  return controller;
}

void main() {
  testWidgets('de la organización al inicio de sesión', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Tu organización'), findsOneWidget);
    expect(find.text('Número de empleado'), findsNothing);

    await tester.enterText(find.byType(TextField), 'campo-prueba');
    await tester.ensureVisible(find.text('Continuar'));
    await tester.tap(find.text('Continuar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(find.text('Número de empleado'), findsOneWidget);
    expect(find.text('Servicios Campo de Prueba'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('un código desconocido muestra el error en el campo', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.enterText(find.byType(TextField), 'otra-empresa');
    await tester.ensureVisible(find.text('Continuar'));
    await tester.tap(find.text('Continuar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(
      find.textContaining('No encontramos esa organización'),
      findsOneWidget,
    );
    expect(find.text('Tu organización'), findsOneWidget);
  });
}
