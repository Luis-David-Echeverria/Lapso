import 'package:flutter/material.dart';

import '../../state/app_scope.dart';
import '../../theme/tokens.dart';

/// Lector de código QR a pantalla completa.
///
/// Devuelve el contenido del código leído, una cadena vacía si la persona
/// dijo que no puede leerlo (solo con [allowSkip]) y `null` si cerró la
/// pantalla.
///
/// La vista de cámara la pone `DeviceCapture.buildQrScanner`: el lector real
/// en la app y uno simulado en el modo de demostración.
class EscanerQrScreen extends StatefulWidget {
  const EscanerQrScreen({
    super.key,
    required this.title,
    required this.heading,
    required this.hint,
    this.allowSkip = false,
  });

  final String title;
  final String heading;
  final String hint;

  /// Permite seguir sin QR. El registro se guarda y queda marcado.
  final bool allowSkip;

  @override
  State<EscanerQrScreen> createState() => _EscanerQrScreenState();
}

class _EscanerQrScreenState extends State<EscanerQrScreen> {
  bool _closed = false;

  /// Cierra la pantalla una sola vez, aunque el lector avise varias veces.
  void _close(String? result) {
    if (_closed) return;
    _closed = true;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LapsoColors.night,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
              child: Row(
                children: <Widget>[
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => _close(null),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
                child: Column(
                  children: <Widget>[
                    Semantics(
                      header: true,
                      child: Text(
                        widget.heading,
                        textAlign: TextAlign.center,
                        style: LapsoText.heading(22, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.hint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: LapsoColors.onNavySoft,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _Viewfinder(
                      scanner: AppScope.read(context).device.buildQrScanner(
                        onCode: _close,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Coloca el código dentro del recuadro. '
                      'Se lee solo, sin tocar nada.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: LapsoColors.onNavySoft,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.allowSkip)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: TextButton(
                  onPressed: () => _close(''),
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('No puedo leer el código'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Viewfinder extends StatelessWidget {
  const _Viewfinder({required this.scanner});

  /// Vista de la cámara que lee el código.
  final Widget scanner;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: ColoredBox(
          color: const Color(0xFF0B1B45),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Semantics(label: 'Vista de la cámara', child: scanner),
              IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: CustomPaint(painter: _CornersPainter()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Las cuatro esquinas del recuadro de lectura.
class _CornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double arm = 34;
    const double r = 14;
    final Paint paint = Paint()
      ..color = LapsoColors.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final Path path = Path()
      // Superior izquierda
      ..moveTo(0, arm)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(arm, 0)
      // Superior derecha
      ..moveTo(size.width - arm, 0)
      ..lineTo(size.width - r, 0)
      ..quadraticBezierTo(size.width, 0, size.width, r)
      ..lineTo(size.width, arm)
      // Inferior derecha
      ..moveTo(size.width, size.height - arm)
      ..lineTo(size.width, size.height - r)
      ..quadraticBezierTo(
        size.width,
        size.height,
        size.width - r,
        size.height,
      )
      ..lineTo(size.width - arm, size.height)
      // Inferior izquierda
      ..moveTo(arm, size.height)
      ..lineTo(r, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - r)
      ..lineTo(0, size.height - arm);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CornersPainter oldDelegate) => false;
}
