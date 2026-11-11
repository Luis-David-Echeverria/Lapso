import 'package:flutter/widgets.dart';

import 'app_controller.dart';

/// Expone el [AppController] al árbol de widgets.
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Lee el controlador y reconstruye el widget cuando cambia.
  static AppController of(BuildContext context) {
    final AppScope? scope =
        context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No hay AppScope sobre este widget.');
    return scope!.notifier!;
  }

  /// Lee el controlador sin suscribirse. Para manejadores de eventos.
  static AppController read(BuildContext context) {
    final AppScope? scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No hay AppScope sobre este widget.');
    return scope!.notifier!;
  }
}
