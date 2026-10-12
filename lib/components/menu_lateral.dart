import 'package:alacena/components/global_values.dart';
import 'package:flutter/material.dart';

class MenuLateral extends StatelessWidget {
  const MenuLateral({super.key, this.alVolver});

  final VoidCallback? alVolver;

  void _ir(BuildContext context, String ruta, {Object? argumentos}) {
    Navigator.pop(context);
    Navigator.pushNamed(context, ruta, arguments: argumentos)
        .then((_) => alVolver?.call());
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: const Text('Mi Alacena'),
            accountEmail: const Text('Inventario doméstico'),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.onPrimary,
              child: Icon(
                Icons.kitchen,
                size: 36,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2),
            title: const Text('Productos'),
            subtitle: const Text('Catálogo y existencias'),
            onTap: () => _ir(context, '/productos'),
          ),
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('Categorías'),
            onTap: () => _ir(context, '/categorias'),
          ),
          ListTile(
            leading: const Icon(Icons.store),
            title: const Text('Tiendas'),
            onTap: () => _ir(context, '/tiendas'),
          ),
          ListTile(
            leading: const Icon(Icons.add_shopping_cart),
            title: const Text('Registrar compra'),
            onTap: () => _ir(context, '/compra'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: const Text('Calendario de caducidad'),
            onTap: () => _ir(context, '/calendario'),
          ),
          ListTile(
            leading: const Icon(Icons.alarm),
            title: const Text('Caducan hoy'),
            onTap: () => _ir(context, '/caducan'),
          ),
          ListTile(
            leading: const Icon(Icons.shopping_cart),
            title: const Text('Carrito de compra'),
            onTap: () => _ir(context, '/carrito'),
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('Resumen de gastos'),
            onTap: () => _ir(context, '/gastos'),
          ),
          const Divider(),
          ValueListenableBuilder<int>(
            valueListenable: GlobalValues.banTheme,
            builder: (context, valor, _) {
              return SwitchListTile(
                secondary: const Icon(Icons.dark_mode),
                title: const Text('Modo oscuro'),
                value: valor == 0,
                onChanged: (activo) {
                  GlobalValues.banTheme.value = activo ? 0 : 1;
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
