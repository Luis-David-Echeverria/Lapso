import 'dart:async';

import 'package:flutter/material.dart';

import '../../config.dart';
import '../../state/app_scope.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';

enum _Phase { idle, checking, upToDate, available, downloading, ready }

/// Actualización de la app fuera de la tienda: buscar, descargar, verificar
/// e instalar.
///
/// Punto de integración: la búsqueda, la descarga y la verificación SHA-256
/// están simuladas. Con el servidor simulado siempre "encuentra" una
/// versión nueva para poder recorrer el flujo.
class ActualizacionScreen extends StatefulWidget {
  const ActualizacionScreen({super.key});

  @override
  State<ActualizacionScreen> createState() => _ActualizacionScreenState();
}

class _ActualizacionScreenState extends State<ActualizacionScreen> {
  static const String _newVersion = '0.2.1';

  _Phase _phase = _Phase.idle;
  double _progress = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    final bool demo = AppScope.read(context).demoTools;
    setState(() => _phase = _Phase.checking);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _phase = demo ? _Phase.available : _Phase.upToDate);
  }

  void _download() {
    setState(() {
      _phase = _Phase.downloading;
      _progress = 0;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 120), (Timer t) {
      if (!mounted) return;
      setState(() {
        _progress += 0.04;
        if (_progress >= 1) {
          _progress = 1;
          _phase = _Phase.ready;
          t.cancel();
        }
      });
    });
  }

  void _install() {
    // Punto de integración: abrir el instalador del sistema con el archivo
    // ya verificado.
    showLapsoSnack(
      context,
      'En la app real, aquí se abre el instalador del teléfono.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LapsoColors.surface,
      appBar: AppBar(title: const Text('Actualización de la app')),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Column(children: _content()),
              ),
            ),
            BottomActions(children: _buttons()),
          ],
        ),
      ),
    );
  }

  List<Widget> _content() {
    Widget title(String text) => Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: LapsoText.heading(24),
          ),
        );
    Widget body(String text) => Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            height: 1.5,
            color: LapsoColors.muted,
          ),
        );
    const Widget gap = SizedBox(height: 16);
    const Widget small = SizedBox(height: 10);
    const Widget current = LapsoCard(
      child: DividedColumn(
        children: <Widget>[
          InfoRow(label: 'Versión instalada', value: kAppVersion),
          InfoRow(label: 'Canal', value: kAppChannel),
        ],
      ),
    );

    switch (_phase) {
      case _Phase.idle:
        return <Widget>[
          const StateBadge(
            icon: Icons.system_update_outlined,
            tone: Tone.info,
          ),
          gap,
          title('Busca si hay una versión nueva'),
          small,
          body(
            'Esta app se actualiza desde Lapso, no desde la tienda. Te '
            'conviene tener siempre la última versión.',
          ),
          const SizedBox(height: 20),
          current,
        ];
      case _Phase.checking:
        return <Widget>[
          const SizedBox(height: 32),
          const CircularProgressIndicator(),
          gap,
          title('Buscando…'),
        ];
      case _Phase.upToDate:
        return <Widget>[
          const StateBadge(icon: Icons.check),
          gap,
          title('Tu app está al día'),
          small,
          body('Tienes la versión más reciente.'),
          const SizedBox(height: 20),
          current,
        ];
      case _Phase.available:
        return <Widget>[
          const StateBadge(
            icon: Icons.system_update_outlined,
            tone: Tone.info,
          ),
          gap,
          title('Hay una versión nueva'),
          small,
          body(
            'Descárgala con wifi si puedes. Antes de instalarla se '
            'comprueba que el archivo sea el original.',
          ),
          const SizedBox(height: 20),
          const LapsoCard(
            child: DividedColumn(
              children: <Widget>[
                InfoRow(label: 'Versión instalada', value: kAppVersion),
                InfoRow(label: 'Versión nueva', value: _newVersion),
              ],
            ),
          ),
        ];
      case _Phase.downloading:
        final int percent = (_progress * 100).round();
        return <Widget>[
          const SizedBox(height: 32),
          title('Descargando la versión $_newVersion'),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 10,
              backgroundColor: LapsoColors.primarySoft,
              color: LapsoColors.primary,
            ),
          ),
          small,
          body('$percent %. No cierres la app.'),
        ];
      case _Phase.ready:
        return <Widget>[
          const StateBadge(icon: Icons.verified_outlined),
          gap,
          title('Lista para instalar'),
          small,
          body(
            'La descarga se comprobó con su huella SHA-256: es el archivo '
            'original.',
          ),
        ];
    }
  }

  List<Widget> _buttons() {
    switch (_phase) {
      case _Phase.idle:
      case _Phase.upToDate:
        return <Widget>[
          PrimaryButton(
            label: _phase == _Phase.idle
                ? 'Buscar actualización'
                : 'Buscar de nuevo',
            onPressed: _check,
          ),
        ];
      case _Phase.checking:
      case _Phase.downloading:
        return const <Widget>[];
      case _Phase.available:
        return <Widget>[
          PrimaryButton(
            label: 'Descargar',
            icon: Icons.download,
            onPressed: _download,
          ),
        ];
      case _Phase.ready:
        return <Widget>[
          PrimaryButton(label: 'Instalar', onPressed: _install),
        ];
    }
  }
}
