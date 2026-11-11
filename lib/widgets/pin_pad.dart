import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Indicador de los seis dígitos del PIN. No muestra los números.
class PinDots extends StatelessWidget {
  const PinDots({
    super.key,
    required this.filled,
    this.length = 6,
    this.error = false,
  });

  final int filled;
  final int length;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final Color empty = error ? LapsoColors.bad : LapsoColors.control;
    return Semantics(
      label: '$filled de $length dígitos escritos',
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            for (int i = 0; i < length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < filled ? LapsoColors.primary : null,
                    border: i < filled
                        ? null
                        : Border.all(color: empty, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Teclado numérico propio para el PIN. El teclado del sistema no se usa
/// para que el PIN no quede en sugerencias ni en el portapapeles.
class PinPad extends StatelessWidget {
  const PinPad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.enabled = true,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    Widget key(String d) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Semantics(
            button: true,
            label: d,
            excludeSemantics: true,
            child: Material(
              color: LapsoColors.keyFill,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: enabled ? () => onDigit(d) : null,
                child: SizedBox(
                  height: 60,
                  child: Center(
                    child: Text(d, style: LapsoText.heading(24)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget row(List<Widget> children) => Row(children: children);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        row(<Widget>[key('1'), key('2'), key('3')]),
        row(<Widget>[key('4'), key('5'), key('6')]),
        row(<Widget>[key('7'), key('8'), key('9')]),
        row(<Widget>[
          const Expanded(child: SizedBox(height: 60)),
          key('0'),
          Expanded(
            child: SizedBox(
              height: 60,
              child: IconButton(
                tooltip: 'Borrar',
                onPressed: enabled ? onBackspace : null,
                icon: const Icon(
                  Icons.backspace_outlined,
                  size: 26,
                  color: LapsoColors.navy,
                ),
              ),
            ),
          ),
        ]),
      ],
    );
  }
}
