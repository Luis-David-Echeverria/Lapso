import 'package:flutter/material.dart';

import '../config.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// Trámites que se hacen en la web de Lapso, no en la app.
enum WebPage { correccion, confirmar }

String _path(WebPage page) {
  switch (page) {
    case WebPage.correccion:
      return '/historial/correccion';
    case WebPage.confirmar:
      return '/historial/confirmar';
  }
}

String _title(WebPage page) {
  switch (page) {
    case WebPage.correccion:
      return 'Pedir la corrección de un registro';
    case WebPage.confirmar:
      return 'Confirmar tu periodo';
  }
}

/// Avisa que el trámite continúa en el navegador y abre la web.
///
/// Punto de integración: falta abrir la dirección en el navegador (por
/// ejemplo con `url_launcher`). Por ahora se muestra la dirección.
Future<void> openWeb(BuildContext context, WebPage page) {
  final String url = '$kWebBaseUrl${_path(page)}';
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(_title(page), style: LapsoText.heading(22)),
              ),
              const SizedBox(height: 6),
              const Text(
                'Este trámite se hace en la web de Lapso. Se abrirá en el '
                'navegador de tu teléfono.',
                style: LapsoText.secondary,
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: LapsoColors.ground,
                  borderRadius: BorderRadius.circular(LapsoRadius.field),
                  border: Border.all(color: LapsoColors.line),
                ),
                child: SelectableText(
                  url,
                  style: const TextStyle(
                    fontSize: 14,
                    color: LapsoColors.navy,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Abrir la web',
                icon: Icons.open_in_new,
                onPressed: () {
                  Navigator.of(context).pop();
                  // Punto de integración: launchUrl(Uri.parse(url)).
                },
              ),
              const SizedBox(height: 8),
              SecondaryButton(
                label: 'Ahora no',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      );
    },
  );
}
