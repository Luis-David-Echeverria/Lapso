import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Tarjeta azul marino con el estado de la jornada.
class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: LapsoColors.navy,
        borderRadius: BorderRadius.circular(LapsoRadius.hero),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

/// Etiqueta de estado dentro de [HeroCard]: punto de color y texto.
class HeroPill extends StatelessWidget {
  const HeroPill(this.text, {super.key, this.dot = LapsoColors.cyan, this.icon});

  final String text;
  final Color dot;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: LapsoColors.onNavyChip,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null)
            Icon(icon, size: 14, color: dot)
          else
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HeroDivider extends StatelessWidget {
  const HeroDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: SizedBox(
        height: 1,
        width: double.infinity,
        child: ColoredBox(color: LapsoColors.onNavyLine),
      ),
    );
  }
}

/// Fila de datos pequeños dentro de [HeroCard].
class HeroStats extends StatelessWidget {
  const HeroStats({super.key, required this.items});

  /// Pares etiqueta → valor.
  final List<MapEntry<String, String>> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < items.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  items[i].key,
                  style: const TextStyle(
                    fontSize: 12,
                    color: LapsoColors.onNavyMuted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  items[i].value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontFeatures: LapsoText.tabular,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Cifra grande de [HeroCard] con su etiqueta. El lector de pantalla lee
/// [spokenValue] una vez, no cada segundo.
class HeroFigure extends StatelessWidget {
  const HeroFigure({
    super.key,
    required this.label,
    required this.value,
    required this.spokenValue,
    this.size = 52,
    this.note,
  });

  final String label;
  final String value;
  final String spokenValue;
  final double size;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final String? n = note;
    return Semantics(
      label: '$label: $spokenValue',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: LapsoColors.onNavySoft,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: LapsoText.heading(size, color: Colors.white)
                    .copyWith(height: 1),
              ),
            ),
            if (n != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                n,
                style: const TextStyle(
                  fontSize: 13,
                  color: LapsoColors.onNavySoft,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
