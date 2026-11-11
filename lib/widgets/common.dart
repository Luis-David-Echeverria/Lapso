import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Tono de avisos y etiquetas. Siempre va acompañado de texto o ícono.
enum Tone { info, good, warn, bad, neutral }

Color toneBg(Tone t) {
  switch (t) {
    case Tone.info:
      return LapsoColors.primarySoft;
    case Tone.good:
      return LapsoColors.goodBg;
    case Tone.warn:
      return LapsoColors.warnBg;
    case Tone.bad:
      return LapsoColors.badBg;
    case Tone.neutral:
      return LapsoColors.keyFill;
  }
}

Color toneFg(Tone t) {
  switch (t) {
    case Tone.info:
      return LapsoColors.infoText;
    case Tone.good:
      return LapsoColors.good;
    case Tone.warn:
      return LapsoColors.warnText;
    case Tone.bad:
      return LapsoColors.bad;
    case Tone.neutral:
      return LapsoColors.muted;
  }
}

/// Reconstruye su contenido cada segundo. Para relojes y cronómetros.
class TickBuilder extends StatefulWidget {
  const TickBuilder({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  State<TickBuilder> createState() => _TickBuilderState();
}

class _TickBuilderState extends State<TickBuilder> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer _) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

/// Encabezado de sección en mayúsculas.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Semantics(
        header: true,
        child: Text(text.toUpperCase(), style: LapsoText.section),
      ),
    );
  }
}

/// Tarjeta blanca con borde.
class LapsoCard extends StatelessWidget {
  const LapsoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.color = LapsoColors.surface,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(LapsoRadius.card),
        border: Border.all(color: LapsoColors.line),
      ),
      child: child,
    );
  }
}

/// Columna de filas separadas por una línea.
class DividedColumn extends StatelessWidget {
  const DividedColumn({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final List<Widget> out = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      if (i > 0) out.add(const Divider());
      out.add(children[i]);
    }
    return Column(mainAxisSize: MainAxisSize.min, children: out);
  }
}

/// Fila "etiqueta — valor".
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor = LapsoColors.navy,
    this.mono = false,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: <Widget>[
            Text(label, style: LapsoText.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: mono ? 14 : 15,
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                  fontFamily: mono ? 'monospace' : null,
                  fontFeatures: LapsoText.tabular,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila navegable con título, subtítulo y flecha.
class NavRow extends StatelessWidget {
  const NavRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.onTap,
    this.external = false,
    this.titleColor = LapsoColors.navy,
    this.bold = false,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onTap;

  /// Abre la web: muestra el ícono de enlace externo.
  final bool external;
  final Color titleColor;
  final bool bold;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final String? sub = subtitle;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 20, color: LapsoColors.primaryDark),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: bold || sub != null
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: titleColor,
                      ),
                    ),
                    if (sub != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(sub, style: LapsoText.caption),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ??
                  Icon(
                    external ? Icons.open_in_new : Icons.chevron_right,
                    size: external ? 18 : 22,
                    color: LapsoColors.muted,
                    semanticLabel: external ? 'Abre la web' : null,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila con interruptor. Toda la fila es el objetivo táctil.
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final String? sub = subtitle;
    final ValueChanged<bool>? change = onChanged;
    return MergeSemantics(
      child: InkWell(
        onTap: change == null ? null : () => change(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: LapsoColors.navy,
                        ),
                      ),
                      if (sub != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(sub, style: LapsoText.caption),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch(value: value, onChanged: change),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Etiqueta pequeña de estado.
class TonePill extends StatelessWidget {
  const TonePill(this.text, {super.key, this.tone = Tone.neutral});

  final String text;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: toneBg(tone),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: toneFg(tone),
        ),
      ),
    );
  }
}

/// Aviso con ícono y texto.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    required this.text,
    this.tone = Tone.info,
    this.icon = Icons.info_outline,
    this.title,
  });

  final String text;
  final String? title;
  final Tone tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final Color fg = toneFg(tone);
    final String? t = title;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: toneBg(tone),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  if (t != null)
                    TextSpan(
                      text: '$t ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  TextSpan(text: text),
                ],
              ),
              style: TextStyle(fontSize: 14, height: 1.45, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón principal. Una sola acción principal por pantalla.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.busy = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: LapsoColors.muted,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: 22),
                  const SizedBox(width: 10),
                ],
                Flexible(child: Text(label, textAlign: TextAlign.center)),
              ],
            ),
    );
  }
}

/// Botón secundario con borde.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 20),
            const SizedBox(width: 8),
          ],
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

/// Círculo con ícono para estados grandes (éxito, bloqueo, aviso).
class StateBadge extends StatelessWidget {
  const StateBadge({
    super.key,
    required this.icon,
    this.tone = Tone.good,
    this.size = 84,
  });

  final IconData icon;
  final Tone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color fg = tone == Tone.good
        ? LapsoColors.goodIcon
        : (tone == Tone.warn ? LapsoColors.warn : toneFg(tone));
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: toneBg(tone), shape: BoxShape.circle),
      child: Icon(icon, size: size * 0.5, color: fg),
    );
  }
}

/// Zona inferior fija con las acciones de la pantalla.
class BottomActions extends StatelessWidget {
  const BottomActions({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

void showLapsoSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
