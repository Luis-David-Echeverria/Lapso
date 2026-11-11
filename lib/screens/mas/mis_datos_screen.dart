import 'package:flutter/material.dart';

import '../../config.dart';
import '../../domain/models.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import 'mis_fotos_screen.dart';
import 'quien_vio_screen.dart';

/// Mis datos de captura: consentimientos de ubicación y foto, y acceso a
/// quién los consultó.
class MisDatosScreen extends StatelessWidget {
  const MisDatosScreen({super.key});

  static String _name(Capability c) {
    switch (c) {
      case Capability.ubicacion:
        return 'ubicación';
      case Capability.foto:
        return 'foto';
    }
  }

  Future<void> _toggle(
    BuildContext context,
    Capability capability,
    bool accepted,
  ) async {
    final AppController c = AppScope.read(context);
    final String name = _name(capability);
    if (!accepted) {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: Text('¿Retirar tu consentimiento de $name?'),
          content: Text(
            'Podrás seguir registrando tu jornada: tus registros se '
            'guardarán marcados como sin $name. Lo que ya se capturó no se '
            'borra.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Retirar'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await c.setConsent(capability, accepted: accepted);
    if (!context.mounted) return;
    showLapsoSnack(
      context,
      accepted
          ? 'Aceptaste la captura de $name.'
          : 'Retiraste tu consentimiento de $name.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppController c = AppScope.of(context);
    final int views = c.evidenceViews.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Mis datos de captura')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 0, 8, 16),
              child: Text(
                'Tú decides qué se captura cuando registras tu jornada, y '
                'puedes ver quién lo consultó.',
                style: LapsoText.secondary,
              ),
            ),
            const SectionLabel('Lo que aceptas capturar'),
            LapsoCard(
              child: DividedColumn(
                children: <Widget>[
                  SwitchRow(
                    title: 'Ubicación al registrar',
                    subtitle: 'Una sola lectura, en el momento del registro.',
                    value: c.consent(Capability.ubicacion),
                    onChanged: (bool v) =>
                        _toggle(context, Capability.ubicacion, v),
                  ),
                  SwitchRow(
                    title: 'Foto al registrar',
                    subtitle: 'Una foto con la cámara frontal.',
                    value: c.consent(Capability.foto),
                    onChanged: (bool v) =>
                        _toggle(context, Capability.foto, v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionLabel('Transparencia'),
            LapsoCard(
              child: DividedColumn(
                children: <Widget>[
                  NavRow(
                    icon: Icons.visibility_outlined,
                    title: 'Quién vio mis datos',
                    subtitle: views == 0
                        ? 'Nadie los ha consultado.'
                        : (views == 1 ? '1 consulta.' : '$views consultas.'),
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) =>
                            const QuienVioScreen(),
                      ),
                    ),
                  ),
                  NavRow(
                    icon: Icons.photo_library_outlined,
                    title: 'Mis fotos',
                    subtitle: 'De los últimos $kPhotoRetentionDays días.',
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) =>
                            const MisFotosScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const NoticeBanner(
              text: 'Si retiras un consentimiento, tu registro no se pierde: '
                  'se guarda sin esa evidencia y queda marcado.',
            ),
          ],
        ),
      ),
    );
  }
}
