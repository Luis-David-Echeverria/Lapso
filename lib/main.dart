import 'package:flutter/material.dart';

import 'app.dart';
import 'data/fake_lapso_api.dart';
import 'state/app_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Mientras no haya acceso al backend, la app corre contra un servidor
  // simulado. Para conectarla al real, cambia FakeLapsoApi por una
  // implementación HTTP de LapsoApi y pon demoTools en false.
  final AppController controller = AppController(
    api: FakeLapsoApi(),
    demoTools: true,
  );
  runApp(LapsoApp(controller: controller));
}
