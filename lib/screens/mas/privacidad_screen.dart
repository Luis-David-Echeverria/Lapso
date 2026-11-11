import 'package:flutter/material.dart';

import '../../config.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';

/// Privacidad y ayuda. Se puede abrir sin haber iniciado sesión.
class PrivacidadScreen extends StatelessWidget {
  const PrivacidadScreen({super.key});

  void _openLegal(BuildContext context, String title, String kind) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            _LegalScreen(title: title, kind: kind),
      ),
    );
  }

  /// Contacto de soporte, cuando esté definido en `config.dart`.
  static List<Widget> _supportRows() {
    final List<Widget> rows = <Widget>[];
    void add(String label, String? value) {
      if (value != null) rows.add(InfoRow(label: label, value: value));
    }

    add('Correo de soporte', kSupportEmail);
    add('Teléfono de soporte', kSupportPhone);
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacidad y ayuda')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            const SectionLabel('Lo esencial'),
            const LapsoCard(
              child: DividedColumn(
                children: <Widget>[
                  _Point(
                    icon: Icons.place_outlined,
                    text: 'Tu ubicación se lee una sola vez, en el momento '
                        'de registrar.',
                  ),
                  _Point(
                    icon: Icons.photo_camera_outlined,
                    text: 'Tu foto se toma con la cámara frontal, solo al '
                        'registrar.',
                  ),
                  _Point(
                    icon: Icons.visibility_outlined,
                    text: 'Puedes ver quién consultó tu ubicación o tus '
                        'fotos, y con qué motivo.',
                  ),
                  _Point(
                    icon: Icons.toggle_on_outlined,
                    text: 'Puedes retirar tu consentimiento cuando quieras, '
                        'en Más, en Mis datos de captura.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionLabel('Documentos'),
            LapsoCard(
              child: DividedColumn(
                children: <Widget>[
                  NavRow(
                    title: 'Aviso de privacidad',
                    bold: true,
                    onTap: () => _openLegal(
                      context,
                      'Aviso de privacidad',
                      'privacy',
                    ),
                  ),
                  NavRow(
                    title: 'Términos de uso',
                    bold: true,
                    onTap: () =>
                        _openLegal(context, 'Términos de uso', 'terms'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionLabel('Ayuda'),
            LapsoCard(
              child: DividedColumn(
                children: <Widget>[
                  const _Point(
                    icon: Icons.badge_outlined,
                    text: 'Para tu PIN, tu horario o tus registros, acude a '
                        'Recursos Humanos de tu organización.',
                  ),
                  ..._supportRows(),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Center(
              child: Text(
                'Lapso Jornada · versión $kAppVersion ($kAppChannel)',
                style: LapsoText.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: LapsoColors.primaryDark),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                height: 1.45,
                color: LapsoColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Documento legal.
///
/// Punto de integración: el texto lo entrega el servidor con
/// `GET /public/legal/{kind}`. Mientras no esté conectado, se avisa que el
/// documento no está disponible en esta versión.
class _LegalScreen extends StatelessWidget {
  const _LegalScreen({required this.title, required this.kind});

  final String title;

  /// Identificador del documento en el servidor.
  final String kind;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LapsoColors.surface,
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(title, style: LapsoText.heading(24)),
            ),
            const SizedBox(height: 16),
            const NoticeBanner(
              text: 'Este documento se descarga del servidor de Lapso y '
                  'todavía no está disponible en esta versión de prueba. '
                  'Pídelo a Recursos Humanos si lo necesitas hoy.',
            ),
          ],
        ),
      ),
    );
  }
}
