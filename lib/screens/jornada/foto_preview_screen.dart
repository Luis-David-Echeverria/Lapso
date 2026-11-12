import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Vista previa de la foto recién tomada. Devuelve `true` para usarla y
/// `false` para tomar otra.
class FotoPreviewScreen extends StatelessWidget {
  const FotoPreviewScreen({super.key, required this.bytes});

  /// La foto, en JPEG.
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LapsoColors.night,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                child: Column(
                  children: <Widget>[
                    Semantics(
                      header: true,
                      child: Text(
                        '¿Se ve bien tu foto?',
                        textAlign: TextAlign.center,
                        style: LapsoText.heading(22, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tu cara debe verse completa y con buena luz.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: LapsoColors.onNavySoft,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Semantics(
                      label: 'Foto que acabas de tomar',
                      child: ExcludeSemantics(
                        child: AspectRatio(
                          aspectRatio: 3 / 4,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: ColoredBox(
                              color: const Color(0xFF16295C),
                              child: Image.memory(
                                bytes,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                                errorBuilder: (
                                  BuildContext context,
                                  Object error,
                                  StackTrace? stack,
                                ) =>
                                    const Center(
                                  child: Icon(
                                    Icons.person,
                                    size: 140,
                                    color: Color(0xFF3A5190),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Solo se guarda esta foto, junto con tu registro.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
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
                    child: const Text('Usar esta foto'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Tomar otra'),
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
