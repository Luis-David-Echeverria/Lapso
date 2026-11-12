import 'package:flutter/material.dart';

import '../../config.dart';
import '../../data/lapso_api.dart';
import '../../domain/models.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../jornada/consentimiento_screen.dart';
import 'mis_fotos_screen.dart';
import 'quien_vio_screen.dart';

/// Mis datos de captura: qué pide el centro, qué aceptó la persona y quién
/// consultó su ubicación o sus fotos.
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

  static String _subtitle(Capability c, CaptureRule rule) {
    if (rule.mode == CaptureMode.off) return 'Tu centro no la pide.';
    final String what = c == Capability.ubicacion
        ? 'Una sola lectura, en el momento del registro.'
        : 'Una foto con la cámara frontal.';
    if (rule.consent == ConsentStatus.outdated) {
      return '$what El aviso de privacidad cambió: acéptalo de nuevo.';
    }
    return rule.mode == CaptureMode.required
        ? '$what Tu centro la pide como obligatoria.'
        : what;
  }

  Future<void> _toggle(
    BuildContext context,
    Capability capability,
    bool accepted,
  ) async {
    final AppController c = AppScope.read(context);
    final String name = _name(capability);
    if (accepted) {
      // Aceptar pasa por la pantalla que explica qué se captura y para qué.
      await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (BuildContext context) =>
              ConsentimientoScreen(capability: capability),
        ),
      );
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('¿Retirar tu consentimiento de $name?'),
        content: Text(
          'Podrás seguir registrando tu jornada: tus registros se guardarán '
          'marcados como sin $name. Lo que ya se capturó no se borra con '
          'esto; para pedir que se elimine, usa el contacto de Privacidad y '
          'ayuda.',
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
    String message = 'Retiraste tu consentimiento de $name.';
    try {
      await c.setConsent(capability, accepted: false);
    } on LapsoException catch (e) {
      message = e.message;
    }
    if (!context.mounted) return;
    showLapsoSnack(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final AppController c = AppScope.of(context);
    final int views = c.evidenceViews.length;

    Widget consentRow(Capability capability, String title) {
      final CaptureRule rule = c.capture.rule(capability);
      return SwitchRow(
        title: title,
        subtitle: _subtitle(capability, rule),
        value: rule.accepted,
        onChanged: rule.mode == CaptureMode.off || c.offline
            ? null
            : (bool v) => _toggle(context, capability, v),
      );
    }

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
            if (c.offline) ...<Widget>[
              const NoticeBanner(
                tone: Tone.warn,
                icon: Icons.cloud_off_outlined,
                text: 'Sin conexión. Para cambiar lo que aceptas necesitas '
                    'internet.',
              ),
              const SizedBox(height: 16),
            ],
            const SectionLabel('Lo que aceptas capturar'),
            LapsoCard(
              child: DividedColumn(
                children: <Widget>[
                  consentRow(Capability.ubicacion, 'Ubicación al registrar'),
                  consentRow(Capability.foto, 'Foto al registrar'),
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
                    subtitle: 'De los últimos $kHistoryDays días.',
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
