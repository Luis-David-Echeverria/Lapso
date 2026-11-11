import 'package:flutter/material.dart';

import '../../config.dart';
import '../../domain/models.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../acceso/cambiar_pin_screen.dart';
import '../web_handoff.dart';
import 'actualizacion_screen.dart';
import 'mis_datos_screen.dart';
import 'privacidad_screen.dart';

/// Pestaña Más: perfil, datos de captura, trámites en la web y cuenta.
class MasScreen extends StatelessWidget {
  const MasScreen({super.key});

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (BuildContext context) => screen),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final AppController c = AppScope.read(context);
    final int pending = c.pending.length;
    if (pending > 0) {
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Aún no puedes cerrar sesión'),
          content: Text(
            pending == 1
                ? 'Tienes 1 registro guardado en este teléfono que no se ha '
                    'enviado. Si cierras sesión se perdería. Envíalo primero '
                    'desde Mi jornada.'
                : 'Tienes $pending registros guardados en este teléfono que '
                    'no se han enviado. Si cierras sesión se perderían. '
                    'Envíalos primero desde Mi jornada.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Para volver a entrar necesitarás tu número de empleado y tu PIN.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmed == true) await c.logout();
  }

  @override
  Widget build(BuildContext context) {
    final AppController c = AppScope.of(context);
    final Employee? employee = c.employee;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: <Widget>[
          Semantics(
            header: true,
            child: Text('Más', style: LapsoText.heading(26)),
          ),
          const SizedBox(height: 14),
          if (employee != null) ...<Widget>[
            _ProfileCard(
              employee: employee,
              organization: c.organization?.name ?? '',
              center: c.center?.name ?? '',
            ),
            const SizedBox(height: 20),
          ],
          const SectionLabel('Mis datos'),
          LapsoCard(
            child: NavRow(
              icon: Icons.shield_outlined,
              title: 'Mis datos de captura',
              subtitle: 'Ubicación, foto y quién los consultó.',
              onTap: () => _push(context, const MisDatosScreen()),
            ),
          ),
          const SizedBox(height: 20),
          const SectionLabel('Trámites en la web'),
          LapsoCard(
            child: DividedColumn(
              children: <Widget>[
                NavRow(
                  icon: Icons.edit_calendar_outlined,
                  title: 'Corregir un registro',
                  external: true,
                  bold: true,
                  onTap: () => openWeb(context, WebPage.correccion),
                ),
                NavRow(
                  icon: Icons.fact_check_outlined,
                  title: 'Confirmar mi periodo',
                  external: true,
                  bold: true,
                  onTap: () => openWeb(context, WebPage.confirmar),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionLabel('Cuenta'),
          LapsoCard(
            child: DividedColumn(
              children: <Widget>[
                NavRow(
                  icon: Icons.pin_outlined,
                  title: 'Cambiar mi PIN',
                  bold: true,
                  onTap: () => _push(context, const CambiarPinScreen()),
                ),
                NavRow(
                  icon: Icons.help_outline,
                  title: 'Privacidad y ayuda',
                  bold: true,
                  onTap: () => _push(context, const PrivacidadScreen()),
                ),
                NavRow(
                  icon: Icons.system_update_outlined,
                  title: 'Actualización de la app',
                  subtitle: 'Versión $kAppVersion · $kAppChannel',
                  onTap: () => _push(context, const ActualizacionScreen()),
                ),
              ],
            ),
          ),
          if (c.demoTools) ...<Widget>[
            const SizedBox(height: 20),
            const SectionLabel('Herramientas de demostración'),
            const _DemoTools(),
          ],
          const SizedBox(height: 24),
          SecondaryButton(
            label: 'Cerrar sesión',
            icon: Icons.logout,
            onPressed: () => _logout(context),
          ),
          const SizedBox(height: 24),
          Center(
            child: Image.asset(
              'assets/brand/powered-fluence.png',
              width: 150,
              semanticLabel: 'Powered by FLU3NCE',
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.employee,
    required this.organization,
    required this.center,
  });

  final Employee employee;
  final String organization;
  final String center;

  @override
  Widget build(BuildContext context) {
    return LapsoCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          ExcludeSemantics(
            child: Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: LapsoColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Text(
                employee.initials,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: LapsoColors.primaryDark,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  employee.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: LapsoColors.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Empleado ${employee.number}',
                  style: LapsoText.caption,
                ),
                if (organization.isNotEmpty || center.isNotEmpty)
                  Text(
                    <String>[
                      if (organization.isNotEmpty) organization,
                      if (center.isNotEmpty) center,
                    ].join(' · '),
                    style: LapsoText.caption,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Simula estados difíciles de provocar a mano. Solo aparece con el
/// servidor simulado (`demoTools`).
class _DemoTools extends StatelessWidget {
  const _DemoTools();

  @override
  Widget build(BuildContext context) {
    final AppController c = AppScope.of(context);
    return LapsoCard(
      color: LapsoColors.keyFill,
      child: DividedColumn(
        children: <Widget>[
          SwitchRow(
            title: 'Sin conexión',
            subtitle: 'Los registros se guardan en el teléfono.',
            value: c.offline,
            onChanged: c.setOffline,
          ),
          SwitchRow(
            title: 'Permiso de ubicación del teléfono',
            subtitle: 'Apágalo para ver el registro sin ubicación.',
            value: c.locationPermission,
            onChanged: c.setLocationPermission,
          ),
          NavRow(
            title: 'Adelantar el reloj 1 hora',
            bold: true,
            trailing: const Icon(Icons.fast_forward, color: LapsoColors.muted),
            onTap: () {
              c.advanceClock(const Duration(hours: 1));
              showLapsoSnack(context, 'Reloj adelantado 1 hora.');
            },
          ),
          NavRow(
            title: 'Adelantar el reloj 17 horas',
            subtitle: 'Con una jornada abierta, dispara el aviso de jornada '
                'larga.',
            trailing: const Icon(Icons.fast_forward, color: LapsoColors.muted),
            onTap: () {
              c.advanceClock(const Duration(hours: 17));
              showLapsoSnack(context, 'Reloj adelantado 17 horas.');
            },
          ),
          NavRow(
            title: 'Volver a la hora real',
            bold: true,
            trailing: const Icon(Icons.restore, color: LapsoColors.muted),
            onTap: () {
              c.resetClock();
              showLapsoSnack(context, 'El reloj volvió a la hora real.');
            },
          ),
        ],
      ),
    );
  }
}
