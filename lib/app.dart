import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/acceso/bloqueada_screen.dart';
import 'screens/acceso/cambiar_pin_screen.dart';
import 'screens/acceso/login_screen.dart';
import 'screens/acceso/organizacion_screen.dart';
import 'screens/home_shell.dart';
import 'state/app_controller.dart';
import 'state/app_scope.dart';
import 'theme/theme.dart';

class LapsoApp extends StatelessWidget {
  const LapsoApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: MaterialApp(
        title: 'Lapso Jornada',
        debugShowCheckedModeBanner: false,
        theme: buildLapsoTheme(),
        locale: const Locale('es', 'MX'),
        supportedLocales: const <Locale>[Locale('es', 'MX'), Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const RootGate(),
      ),
    );
  }
}

/// Decide qué ve el usuario según el estado de la sesión.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final AppController c = AppScope.of(context);
    if (!c.hasOrganization) return const OrganizacionScreen();
    if (!c.loggedIn) {
      return c.lockedUntil != null
          ? const BloqueadaScreen()
          : const LoginScreen();
    }
    if (c.mustChangePin) return const CambiarPinScreen(forced: true);
    return const HomeShell();
  }
}
