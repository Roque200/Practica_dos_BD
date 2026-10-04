import 'package:flutter/material.dart';

class GlobalValues {
  // 0 -> Noche
  // 1 -> Día
  static ValueNotifier<int> banTheme = ValueNotifier(1);

  // Total de artículos en el carrito (para el badge)
  static ValueNotifier<int> carritoCount = ValueNotifier(0);

  // Permite navegar desde las notificaciones sin tener un context
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
}
