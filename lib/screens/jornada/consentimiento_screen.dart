import 'package:flutter/material.dart';

import '../../config.dart';
import '../../data/lapso_api.dart';
import '../../domain/models.dart';
import '../../state/app_scope.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../mas/texto_legal_screen.dart';

/// Pide la aceptación de la persona antes de capturar su ubicación o su
/// foto. Se muestra antes de pedir el permiso del sistema.
///
/// Devuelve `true` si aceptó y `false` si prefirió no hacerlo. En los dos
/// casos el registro sigue adelante: nada de esto impide registrar.
class ConsentimientoScreen extends StatefulWidget {
  const ConsentimientoScreen({super.key, required this.capability});

  final Capability capability;

  @override
  State<ConsentimientoScreen> createState() => _ConsentimientoScreenState();
}

class _ConsentimientoScreenState extends State<ConsentimientoScreen> {
  bool _busy = false;

  bool get _isLocation => widget.capability == Capability.ubicacion;

  Future<void> _accept() async {
    setState(() => _busy = true);
    String? problem;
    try {
      await AppScope.read(context)
          .setConsent(widget.capability, accepted: true);
    } on LapsoException catch (e) {
      problem = e.message;
    }
    if (!mounted) return;
    if (problem != null) {
      setState(() => _busy = false);
      showLapsoSnack(context, problem);
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final List<String> points = _isLocation
        ? const <String>[
            'Se lee una sola vez, en el momento en que registras. No se '
                'sigue tu recorrido ni se lee con la app cerrada.',
            'Sirve para saber si registraste dentro de la zona de tu centro '
                'de trabajo.',
            'La pueden consultar las personas autorizadas de tu '
                'organización. Cada consulta queda anotada y tú puedes verla.',
          ]
        : const <String>[
            'Se toma una foto con la cámara frontal, solo cuando registras y '
                'tú tocas el botón. La app no usa tu galería.',
            'Sirve para acreditar que eres tú quien registra.',
            'La pueden consultar las personas autorizadas de tu '
                'organización. Cada consulta queda anotada y tú puedes verla.',
          ];

    return Scaffold(
      backgroundColor: LapsoColors.surface,
      appBar: AppBar(
        title: Text(_isLocation ? 'Tu ubicación' : 'Tu foto'),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Center(
                      child: StateBadge(
                        icon: _isLocation
                            ? Icons.place_outlined
                            : Icons.photo_camera_outlined,
                        tone: Tone.info,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      header: true,
                      child: Text(
                        _isLocation
                            ? '¿Aceptas que se lea tu ubicación al registrar?'
                            : '¿Aceptas que se tome tu foto al registrar?',
                        textAlign: TextAlign.center,
                        style: LapsoText.heading(24),
                      ),
                    ),
                    const SizedBox(height: 20),
                    LapsoCard(
                      child: DividedColumn(
                        children: <Widget>[
                          for (final String point in points)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  const Icon(
                                    Icons.check_circle_outline,
                                    size: 20,
                                    color: LapsoColors.primaryDark,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      point,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        height: 1.45,
                                        color: LapsoColors.navy,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const NoticeBanner(
                      text: 'Si no aceptas, igual puedes registrar tu '
                          'jornada: tu registro queda marcado sin esa '
                          'evidencia. Puedes cambiar tu respuesta cuando '
                          'quieras en Más, en Mis datos de captura.',
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) =>
                                const TextoLegalScreen(
                              kind: kLegalPrivacy,
                              title: 'Aviso de privacidad',
                            ),
                          ),
                        ),
                        child: const Text('Leer el aviso de privacidad'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            BottomActions(
              children: <Widget>[
                PrimaryButton(
                  label: 'Aceptar',
                  busy: _busy,
                  onPressed: _accept,
                ),
                const SizedBox(height: 8),
                SecondaryButton(
                  label: 'Ahora no',
                  onPressed:
                      _busy ? null : () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
