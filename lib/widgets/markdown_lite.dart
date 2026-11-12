import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Muestra el Markdown limitado de los textos legales: encabezados,
/// párrafos, listas, tablas y negritas. No interpreta HTML ni enlaces.
class MarkdownLite extends StatelessWidget {
  const MarkdownLite(this.source, {super.key});

  final String source;

  static const TextStyle _body = TextStyle(
    fontSize: 15,
    height: 1.55,
    color: LapsoColors.navy,
  );

  @override
  Widget build(BuildContext context) {
    final List<Widget> blocks = <Widget>[];
    final List<String> paragraph = <String>[];

    void flush() {
      if (paragraph.isEmpty) return;
      blocks.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text.rich(
            TextSpan(children: _inline(paragraph.join(' '))),
            style: _body,
          ),
        ),
      );
      paragraph.clear();
    }

    for (final String raw in source.split('\n')) {
      final String line = raw.trim();
      if (line.isEmpty) {
        flush();
        continue;
      }
      final RegExpMatch? heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line);
      if (heading != null) {
        flush();
        final int level = heading.group(1)!.length;
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Semantics(
              header: true,
              child: Text(
                _plain(heading.group(2)!),
                style: LapsoText.heading(level <= 1 ? 22 : (level == 2 ? 19 : 17)),
              ),
            ),
          ),
        );
        continue;
      }
      final RegExpMatch? item = RegExp(r'^([-*•]|\d+[.)])\s+(.*)$').firstMatch(line);
      if (item != null) {
        flush();
        final String marker = item.group(1)!;
        final bool numbered = RegExp(r'^\d').hasMatch(marker);
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 24,
                  child: Text(numbered ? marker : '•', style: _body),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: _inline(item.group(2)!)),
                    style: _body,
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }
      if (line.startsWith('|')) {
        flush();
        // Renglón separador de una tabla: |---|---|
        if (RegExp(r'^[|\s:-]+$').hasMatch(line)) continue;
        final List<String> cells = line
            .split('|')
            .map((String c) => c.trim())
            .where((String c) => c.isNotEmpty)
            .toList();
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text.rich(
              TextSpan(children: _inline(cells.join(' · '))),
              style: _body,
            ),
          ),
        );
        continue;
      }
      paragraph.add(line);
    }
    flush();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }

  static String _plain(String text) =>
      text.replaceAll('**', '').replaceAll('__', '');

  /// Negritas con `**texto**` y cursivas con `_texto_` o `*texto*`.
  static List<InlineSpan> _inline(String text) {
    final List<InlineSpan> spans = <InlineSpan>[];
    final RegExp pattern = RegExp(r'\*\*(.+?)\*\*|__(.+?)__|\*(.+?)\*|\b_(.+?)_\b');
    int cursor = 0;
    for (final RegExpMatch match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final String? bold = match.group(1) ?? match.group(2);
      final String? italic = match.group(3) ?? match.group(4);
      if (bold != null) {
        spans.add(
          TextSpan(
            text: bold,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      } else if (italic != null) {
        spans.add(
          TextSpan(
            text: italic,
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      }
      cursor = match.end;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
    return spans;
  }
}
