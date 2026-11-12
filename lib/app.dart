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
import 'theme/tokens.dart';

class LapsoApp extends StatefulWidget {
  const LapsoApp({super.key, required this.controller});

  final AppController controller;

  @override
  State<LapsoApp> createState() => _LapsoAppState();
}

class _LapsoAppState extends State<LapsoApp> {
  final GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();
  bool _wasLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _wasLoggedIn = widget.controller.loggedIn;
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  /// Si la sesión termina (la cerró la persona, venció o el servidor la
  /// revocó), se cierran las pantallas abiertas y queda la de acceso.
  void _onChange() {
    final bool loggedIn = widget.controller.loggedIn;
    if (_wasLoggedIn && !loggedIn) {
      _navigator.currentState?.popUntil((Route<dynamic> r) => r.isFirst);
    }
    _wasLoggedIn = loggedIn;
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: widget.controller,
      child: MaterialApp(
        navigatorKey: _navigator,
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
    if (!c.ready) return const _Splash();
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

/// Se muestra un instante mientras se lee la sesión guardada.
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LapsoColors.surface,
      body: Center(
        child: Image.asset(
          'assets/brand/lapso-lockup.png',
          height: 70,
          semanticLabel: 'Lapso Jornada',
        ),
      ),
    );
  }
}
