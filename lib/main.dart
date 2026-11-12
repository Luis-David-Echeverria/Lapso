import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'config.dart';
import 'data/fake_lapso_api.dart';
import 'data/http_lapso_api.dart';
import 'platform/device_capture.dart';
import 'platform/real_device_capture.dart';
import 'platform/secure_store.dart';
import 'state/app_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final AppController controller =
      kDemoMode ? _demoController() : _realController();
  unawaited(controller.start());
  runApp(LapsoApp(controller: controller));
}

/// La app de verdad: servidor de Lapso, cámara, ubicación y almacén cifrado.
AppController _realController() {
  const SecureStore store = SecureStore();
  return AppController(
    api: HttpLapsoApi(store: store),
    device: RealDeviceCapture(),
    store: store,
  );
}

/// Demostración sin servidor: `flutter run --dart-define=LAPSO_DEMO=true`.
AppController _demoController() {
  return AppController(
    api: FakeLapsoApi(),
    device: FakeDeviceCapture(),
    demoTools: true,
  );
}
