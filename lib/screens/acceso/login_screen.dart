import 'package:flutter/material.dart';

import '../../data/lapso_api.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/pin_pad.dart';
import '../mas/privacidad_screen.dart';

/// Inicio de sesión con número de empleado y PIN de seis dígitos.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const int _pinLength = 6;

  final TextEditingController _employee = TextEditingController();
  String _pin = '';
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _employee.dispose();
    super.dispose();
  }

  void _digit(String d) {
    if (_pin.length >= _pinLength) return;
    setState(() {
      _pin += d;
      _error = null;
    });
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    if (_employee.text.trim().isEmpty) {
      setState(() => _error = 'Escribe tu número de empleado.');
      return;
    }
    if (_pin.length < _pinLength) {
      setState(() => _error = 'Escribe los seis dígitos de tu PIN.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final AppController c = AppScope.read(context);
    String? problem;
    try {
      final LoginResult r = await c.login(_employee.text, _pin);
      switch (r.status) {
        case LoginStatus.ok:
        case LoginStatus.locked:
          // RootGate cambia de pantalla al notificar el controlador.
          break;
        case LoginStatus.wrongCredentials:
          problem = 'Número de empleado o PIN incorrecto. Después de varios '
              'intentos fallidos la cuenta se bloquea 15 minutos.';
        case LoginStatus.noWorkerProfile:
          problem = r.message ??
              'Tu usuario no tiene perfil de trabajador. Consulta a '
                  'Recursos Humanos.';
      }
    } on LapsoException catch (e) {
      problem = e.message;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _pin = '';
      _error = problem;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppController c = AppScope.of(context);
    final String? error = _error;
    return Scaffold(
      backgroundColor: LapsoColors.surface,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Image.asset(
                      'assets/brand/lapso-lockup.png',
                      height: 50,
                      semanticLabel: 'Lapso Jornada',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      c.organization?.name ?? '',
                      textAlign: TextAlign.center,
                      style: LapsoText.secondary,
                    ),
                    const SizedBox(height: 18),
                    if (c.sessionExpired) ...<Widget>[
                      const NoticeBanner(
                        text: 'Tu sesión terminó. Entra de nuevo para '
                            'continuar.',
                      ),
                      const SizedBox(height: 14),
                    ],
                    const Text('Número de empleado', style: LapsoText.label),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _employee,
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(fontSize: 17),
                      decoration: const InputDecoration(hintText: 'Ej. GIL-001'),
                    ),
                    const SizedBox(height: 18),
                    const Text('PIN de 6 dígitos', style: LapsoText.label),
                    const SizedBox(height: 12),
                    PinDots(filled: _pin.length, error: error != null),
                    if (error != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Icon(
                              Icons.error_outline,
                              size: 18,
                              color: LapsoColors.bad,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                error,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                  fontWeight: FontWeight.w600,
                                  color: LapsoColors.bad,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: PinPad(
                        onDigit: _digit,
                        onBackspace: _backspace,
                        enabled: !_busy,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: PrimaryButton(
                label: 'Iniciar sesión',
                busy: _busy,
                onPressed: _submit,
              ),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: <Widget>[
                TextButton(
                  onPressed: _busy ? null : c.forgetOrganization,
                  child: const Text('No es mi organización'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) =>
                          const PrivacidadScreen(),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: LapsoColors.muted,
                  ),
                  child: const Text('Privacidad y ayuda'),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
