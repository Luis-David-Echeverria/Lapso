import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'historial/historial_screen.dart';
import 'jornada/mi_jornada_screen.dart';
import 'mas/mas_screen.dart';

/// Contenedor de las tres pestañas: Mi jornada, Historial y Más.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _go(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LapsoColors.ground,
      body: IndexedStack(
        index: _index,
        children: <Widget>[
          MiJornadaScreen(onOpenHistory: () => _go(1)),
          const HistorialScreen(),
          const MasScreen(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: LapsoColors.line)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _go,
          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.schedule_outlined),
              selectedIcon: Icon(Icons.schedule),
              label: 'Mi jornada',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today),
              label: 'Historial',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu),
              selectedIcon: Icon(Icons.menu),
              label: 'Más',
            ),
          ],
        ),
      ),
    );
  }
}
