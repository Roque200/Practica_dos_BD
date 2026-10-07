import 'package:alacena/components/global_values.dart';
import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';

class BotonCarrito extends StatelessWidget {
  const BotonCarrito({super.key, this.alVolver});

  final VoidCallback? alVolver;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: GlobalValues.carritoCount,
      builder: (context, total, _) {
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: badges.Badge(
            showBadge: total > 0,
            position: badges.BadgePosition.topEnd(top: 0, end: 0),
            badgeAnimation: const badges.BadgeAnimation.scale(),
            badgeStyle: const badges.BadgeStyle(badgeColor: Colors.red),
            badgeContent: Text(
              total > 99 ? '99+' : '$total',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            child: IconButton(
              tooltip: 'Carrito',
              icon: const Icon(Icons.shopping_cart_outlined),
              onPressed: () {
                Navigator.pushNamed(context, '/carrito')
                    .then((_) => alVolver?.call());
              },
            ),
          ),
        );
      },
    );
  }
}
