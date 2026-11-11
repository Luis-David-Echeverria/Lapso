import 'package:flutter/material.dart';

import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/pin_pad.dart';

enum _Step { current, fresh, confirm }

/// Cambio de PIN. Si [forced] es verdadero, el PIN era temporal y no se
/// puede salir sin cambiarlo.
class CambiarPinScreen extends StatefulWidget {
  const CambiarPinScreen({super.key, this.forced = false});

  final bool forced;

  @override
  State<CambiarPinScreen> createState() => _CambiarPinScreenState();
}

class _CambiarPinScreenState extends State<CambiarPinScreen> {
  static const int _pinLength = 6;

  late _Step _step = widget.forced ? _Step.fresh : _Step.current;
  String _entry = '';
  String _fresh = '';
  String? _error;
  bool _busy = false;

  List<_Step> get _steps => widget.forced
      ? const <_Step>[_Step.fresh, _Step.confirm]
      : const <_Step>[_Step.current, _Step.fresh, _Step.confirm];

  String get _title {
    switch (_step) {
      case _Step.current:
        return 'Escribe tu PIN actual';
      case _Step.fresh:
        return 'Elige un PIN nuevo de seis dígitos';
      case _Step.confirm:
        return 'Escribe otra vez tu PIN nuevo';
    }
  }

  String get _help {
    switch (_step) {
      case _Step.current:
        return 'Lo pedimos para confirmar que eres tú.';
      case _Step.fresh:
        return 'No uses seis iguales, una secuencia, grupos repetidos, '
            'tu número de empleado ni tu PIN actual.';
      case _Step.confirm:
        return 'Debe ser igual al que acabas de elegir.';
    }
  }

  void _digit(String d) {
    if (_entry.length >= _pinLength) return;
    setState(() {
      _entry += d;
      _error = null;
    });
  }

  void _backspace() {
    if (_entry.isEmpty) return;
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  Future<void> _next() async {
    if (_entry.length < _pinLength) {
      setState(() => _error = 'Escribe los seis dígitos.');
      return;
    }
    final AppController c = AppScope.read(context);
    switch (_step) {
      case _Step.current:
        if (!c.isCurrentPin(_entry)) {
          setState(() {
            _entry = '';
            _error = 'Ese no es tu PIN actual.';
          });
          return;
        }
        setState(() {
          _entry = '';
          _step = _Step.fresh;
        });
      case _Step.fresh:
        setState(() {
          _fresh = _entry;
          _entry = '';
          _step = _Step.confirm;
        });
      case _Step.confirm:
        if (_entry != _fresh) {
          setState(() {
            _entry = '';
            _fresh = '';
            _step = _Step.fresh;
            _error = 'Los dos PIN no coinciden. Elige uno de nuevo.';
          });
          return;
        }
        setState(() => _busy = true);
        final String? problem = await c.changePin(_fresh);
        if (!mounted) return;
        if (problem != null) {
          setState(() {
            _busy = false;
            _entry = '';
            _fresh = '';
            _step = _Step.fresh;
            _error = problem;
          });
          return;
        }
        if (!widget.forced) {
          showLapsoSnack(context, 'Tu PIN se cambió.');
          Navigator.of(context).pop();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? error = _error;
    final int position = _steps.indexOf(_step) + 1;
    return Scaffold(
      backgroundColor: LapsoColors.surface,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.forced,
        title: const Text('Cambia tu PIN'),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 8),
                child: Column(
                  children: <Widget>[
                    Text(
                      'Paso $position de ${_steps.length}',
                      style: LapsoText.caption.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Semantics(
                      header: true,
                      child: Text(
                        _title,
                        textAlign: TextAlign.center,
                        style: LapsoText.heading(24),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _help,
                      textAlign: TextAlign.center,
                      style: LapsoText.secondary,
                    ),
                    const SizedBox(height: 24),
                    PinDots(filled: _entry.length, error: error != null),
                    if (error != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          error,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: LapsoColors.bad,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
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
            BottomActions(
              children: <Widget>[
                PrimaryButton(
                  label: _step == _Step.confirm
                      ? 'Guardar y continuar'
                      : 'Continuar',
                  busy: _busy,
                  onPressed: _next,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
