import 'package:flutter/material.dart';

import '../../data/lapso_api.dart';
import '../../domain/models.dart';
import '../../state/app_scope.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/markdown_lite.dart';

/// Un texto legal público (aviso de privacidad, política de conservación o
/// medio de registro). Se puede abrir sin haber iniciado sesión.
class TextoLegalScreen extends StatefulWidget {
  const TextoLegalScreen({super.key, required this.kind, required this.title});

  /// Tipo de texto en el servidor, por ejemplo `AVISO_PRIVACIDAD`.
  final String kind;

  /// Título mientras carga o si no hay texto.
  final String title;

  @override
  State<TextoLegalScreen> createState() => _TextoLegalScreenState();
}

class _TextoLegalScreenState extends State<TextoLegalScreen> {
  bool _started = false;
  bool _loading = true;
  LegalText? _text;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _fetch();
  }

  Future<void> _retry() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await _fetch();
  }

  Future<void> _fetch() async {
    LegalText? text;
    String? error;
    try {
      text = await AppScope.read(context).api.legalText(widget.kind);
    } on LapsoException catch (e) {
      error = e.message;
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _text = text;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final LegalText? text = _text;
    final String? error = _error;
    final String title =
        text == null || text.title.isEmpty ? widget.title : text.title;

    final List<Widget> body;
    if (_loading) {
      body = const <Widget>[
        SizedBox(height: 48),
        Center(child: CircularProgressIndicator()),
      ];
    } else if (error != null) {
      body = <Widget>[
        NoticeBanner(
          tone: Tone.warn,
          icon: Icons.cloud_off_outlined,
          text: error,
        ),
        const SizedBox(height: 16),
        SecondaryButton(label: 'Intentar de nuevo', onPressed: _retry),
      ];
    } else if (text == null) {
      body = const <Widget>[
        NoticeBanner(
          text: 'Este documento todavía no está publicado. Pídelo a '
              'Recursos Humanos si lo necesitas.',
        ),
      ];
    } else {
      body = <Widget>[
        Text('Versión ${text.version}', style: LapsoText.caption),
        const SizedBox(height: 12),
        if (text.draft) ...<Widget>[
          const NoticeBanner(
            tone: Tone.warn,
            icon: Icons.edit_note,
            text: 'Borrador técnico: pendiente de revisión legal.',
          ),
          const SizedBox(height: 16),
        ],
        MarkdownLite(text.body),
      ];
    }

    return Scaffold(
      backgroundColor: LapsoColors.surface,
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(title, style: LapsoText.heading(24)),
            ),
            const SizedBox(height: 8),
            ...body,
          ],
        ),
      ),
    );
  }
}
