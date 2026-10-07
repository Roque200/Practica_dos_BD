import 'package:alacena/components/global_values.dart';
import 'package:alacena/components/notificaciones.dart';
import 'package:alacena/components/theme_app.dart';
import 'package:alacena/database/alacena_db.dart';
import 'package:alacena/pages/categorias_page.dart';
import 'package:alacena/pages/tiendas_page.dart';
import 'package:alacena/screens/add_producto_screen.dart';
import 'package:alacena/screens/detalle_producto_screen.dart';
import 'package:alacena/screens/productos_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

// main.dart PROVISIONAL: se reemplaza por el definitivo cuando
// esté lista la pantalla principal.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_MX');
  await Notificaciones.inicializar();
  runApp(const AlacenaApp());
}

class AlacenaApp extends StatefulWidget {
  const AlacenaApp({super.key});

  @override
  State<AlacenaApp> createState() => _AlacenaAppState();
}

class _AlacenaAppState extends State<AlacenaApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await AlacenaDB().refrescarContadorCarrito();
      await Notificaciones.revisarLanzamiento();
      await Notificaciones.reprogramar();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: GlobalValues.banTheme,
      builder: (context, value, _) {
        return MaterialApp(
          title: 'Mi Alacena',
          debugShowCheckedModeBanner: false,
          navigatorKey: GlobalValues.navigatorKey,
          theme: ThemeApp.claro(),
          darkTheme: ThemeApp.oscuro(),
          themeMode: value == 0 ? ThemeMode.dark : ThemeMode.light,
          home: const InicioPage(),
          routes: {
            '/producto': (context) => const DetalleProductoScreen(),
            '/producto/form': (context) => const AddProductoScreen(),
            '/categorias': (context) => const CategoriasPage(),
            '/tiendas': (context) => const TiendasPage(),
          },
          // Rutas que todavía no existen (carrito, compra, calendario...)
          onUnknownRoute: (settings) => MaterialPageRoute(
            settings: settings,
            builder: (context) => EnConstruccion(ruta: settings.name ?? ''),
          ),
        );
      },
    );
  }
}

class InicioPage extends StatefulWidget {
  const InicioPage({super.key});

  @override
  State<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends State<InicioPage> {
  int _indice = 0;

  // Sin IndexedStack: cada pestaña se vuelve a construir al entrar,
  // así siempre muestra los datos actualizados.
  Widget _pagina() {
    switch (_indice) {
      case 1:
        return const CategoriasPage();
      case 2:
        return const TiendasPage();
      default:
        return const ProductosScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pagina(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() => _indice = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Productos',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            label: 'Categorías',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            label: 'Tiendas',
          ),
        ],
      ),
    );
  }
}

class EnConstruccion extends StatelessWidget {
  const EnConstruccion({super.key, required this.ruta});

  final String ruta;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('En construcción')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.construction, size: 64),
            const SizedBox(height: 12),
            Text('La pantalla "$ruta" todavía no está lista'),
          ],
        ),
      ),
    );
  }
}
