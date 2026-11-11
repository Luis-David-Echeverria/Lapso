import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Lector de código QR a pantalla completa.
///
/// Devuelve `true` si leyó un código, `false` si el usuario dijo que no puede
/// leerlo (solo con [allowSkip]) y `null` si cerró la pantalla.
///
/// Punto de integración: la vista de cámara es un marcador. Aquí va el lector
/// real (por ejemplo `mobile_scanner`); al detectar un código se llama a
/// `Navigator.pop(context, true)` y el botón "Simular lectura" desaparece.
class EscanerQrScreen extends StatelessWidget {
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
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      title,
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
                        heading,
                        textAlign: TextAlign.center,
                        style: LapsoText.heading(22, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: LapsoColors.onNavySoft,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const _Viewfinder(),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Simular lectura'),
                  ),
                  if (allowSkip)
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('No puedo leer el código'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Viewfinder extends StatelessWidget {
  const _Viewfinder();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Vista de la cámara',
      child: ExcludeSemantics(
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0B1B45),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Stack(
              children: <Widget>[
                const Center(
                  child: Icon(
                    Icons.qr_code_2,
                    size: 120,
                    color: Color(0xFF2A3F78),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: CustomPaint(painter: _CornersPainter()),
                  ),
                ),
              ],
            ),
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
