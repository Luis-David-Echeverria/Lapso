import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config.dart';
import '../../domain/models.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import 'texto_legal_screen.dart';

/// Privacidad y ayuda. Se puede abrir sin haber iniciado sesión.
///
/// Reúne lo que piden las tiendas: el aviso de privacidad a la mano, qué se
/// captura y para qué, cómo retirar el consentimiento y a quién pedir el
/// acceso, la corrección o la eliminación de los datos.
class PrivacidadScreen extends StatelessWidget {
  const PrivacidadScreen({super.key});

  void _openLegal(BuildContext context, String kind, String title) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            TextoLegalScreen(kind: kind, title: title),
      ),
    );
  }

  Future<void> _launch(BuildContext context, Uri uri) async {
    bool opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Exception {
      opened = false;
    }
    if (!opened && context.mounted) {
      showLapsoSnack(context, 'No se pudo abrir. Copia el dato a mano.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppController c = AppScope.of(context);
    final Organization? org = c.organization;
    final SupportContact support = c.support;
    final String? rightsEmail = org?.contactEmail;
    final String? rightsPhone = org?.contactPhone;
    final String? supportEmail = support.email;
    final String? supportPhone = support.phone;

    Widget mail(String title, String email) => NavRow(
          icon: Icons.mail_outline,
          title: title,
          subtitle: email,
          external: true,
          onTap: () => _launch(context, Uri(scheme: 'mailto', path: email)),
        );
    Widget phone(String title, String number) => NavRow(
          icon: Icons.phone_outlined,
          title: title,
          subtitle: number,
          external: true,
          onTap: () => _launch(context, Uri(scheme: 'tel', path: number)),
        );

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
                        'de registrar. Nunca con la app cerrada.',
                  ),
                  _Point(
                    icon: Icons.photo_camera_outlined,
                    text: 'Tu foto se toma con la cámara frontal, solo al '
                        'registrar. La app no usa tu galería.',
                  ),
                  _Point(
                    icon: Icons.visibility_outlined,
                    text: 'Puedes ver quién consultó tu ubicación o tus '
                        'fotos.',
                  ),
                  _Point(
                    icon: Icons.toggle_on_outlined,
                    text: 'Puedes retirar tu consentimiento cuando quieras, '
                        'en Más, en Mis datos de captura. Seguirás pudiendo '
                        'registrar tu jornada.',
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
                      kLegalPrivacy,
                      'Aviso de privacidad',
                    ),
                  ),
                  NavRow(
                    title: 'Política de conservación',
                    bold: true,
                    onTap: () => _openLegal(
                      context,
                      kLegalRetention,
                      'Política de conservación',
                    ),
                  ),
                  NavRow(
                    title: 'Medio de registro de la jornada',
                    bold: true,
                    onTap: () => _openLegal(
                      context,
                      kLegalRecord,
                      'Medio de registro',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionLabel('Tus datos y tu cuenta'),
            LapsoCard(
              child: DividedColumn(
                children: <Widget>[
                  const _Point(
                    icon: Icons.manage_accounts_outlined,
                    text: 'Tu cuenta la crea y la da de baja tu '
                        'organización. Para pedir el acceso, la corrección '
                        'o la eliminación de tus datos o de tu cuenta, usa '
                        'este contacto o acude a Recursos Humanos.',
                  ),
                  if (rightsEmail != null)
                    mail('Escribir sobre mis datos', rightsEmail),
                  if (rightsPhone != null)
                    phone('Llamar sobre mis datos', rightsPhone),
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
                  if (supportEmail != null)
                    mail('Escribir a soporte', supportEmail),
                  if (supportPhone != null)
                    phone('Llamar a soporte', supportPhone),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Center(
              child: Text(
                'Lapso Jornada · versión $kAppVersion',
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
