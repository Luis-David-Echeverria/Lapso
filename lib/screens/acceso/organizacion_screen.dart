import 'package:flutter/material.dart';

import '../../state/app_scope.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../jornada/escaner_qr_screen.dart';
import '../mas/privacidad_screen.dart';

/// Primer paso: el trabajador indica a qué organización pertenece.
class OrganizacionScreen extends StatefulWidget {
  const OrganizacionScreen({super.key});

  @override
  State<OrganizacionScreen> createState() => _OrganizacionScreenState();
}

class _OrganizacionScreenState extends State<OrganizacionScreen> {
  final TextEditingController _code = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final String? problem =
        await AppScope.read(context).chooseOrganization(_code.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = problem;
    });
  }

  Future<void> _scan() async {
    final String? payload = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (BuildContext context) => const EscanerQrScreen(
          title: 'Tu organización',
          heading: 'Escanea el código QR de tu organización',
          hint: 'Te lo dio Recursos Humanos, impreso o en un mensaje.',
        ),
      ),
    );
    if (payload == null || payload.isEmpty || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final String? problem =
        await AppScope.read(context).chooseOrganizationByQr(payload);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = problem;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LapsoColors.surface,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFEEF4FD),
                border: Border(bottom: BorderSide(color: LapsoColors.line)),
              ),
              padding: EdgeInsets.fromLTRB(
                28,
                MediaQuery.paddingOf(context).top + 56,
                28,
                56,
              ),
              child: Image.asset(
                'assets/brand/lapso-lockup.png',
                height: 70,
                semanticLabel: 'Lapso Jornada',
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 36, 28, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Semantics(
                    header: true,
                    child: Text('Tu organización', style: LapsoText.heading(28)),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Escribe el código de tu organización o pega el enlace '
                    'que te dieron. Lo recordaremos en este teléfono.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: LapsoColors.muted,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text('Código de la organización', style: LapsoText.label),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _code,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (String _) => _submit(),
                    style: const TextStyle(fontSize: 17),
                    decoration: InputDecoration(
                      hintText: 'Ej. campo-prueba',
                      errorText: _error,
                    ),
                  ),
                  const SizedBox(height: 22),
                  PrimaryButton(
                    label: 'Continuar',
                    busy: _busy,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: <Widget>[
                      Expanded(child: Divider(color: LapsoColors.line)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('o', style: LapsoText.caption),
                      ),
                      Expanded(child: Divider(color: LapsoColors.line)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SecondaryButton(
                    label: 'Escanear QR',
                    icon: Icons.qr_code_scanner,
                    onPressed: _busy ? null : _scan,
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (BuildContext context) =>
                              const PrivacidadScreen(),
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: LapsoColors.muted,
                      ),
                      child: const Text('Privacidad y ayuda'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Image.asset(
                      'assets/brand/powered-fluence.png',
                      width: 150,
                      semanticLabel: 'Powered by FLU3NCE',
                    ),
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
