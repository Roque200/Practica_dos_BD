import 'package:alacena/components/global_values.dart';
import 'package:alacena/components/notificaciones.dart';
import 'package:alacena/components/theme_app.dart';
import 'package:alacena/database/alacena_db.dart';
import 'package:alacena/pages/categorias_page.dart';
import 'package:alacena/pages/tiendas_page.dart';
import 'package:alacena/screens/add_compra_screen.dart';
import 'package:alacena/screens/add_producto_screen.dart';
import 'package:alacena/screens/caducan_hoy_screen.dart';
import 'package:alacena/screens/calendario_screen.dart';
import 'package:alacena/screens/carrito_screen.dart';
import 'package:alacena/screens/detalle_producto_screen.dart';
import 'package:alacena/screens/home_screen.dart';
import 'package:alacena/screens/productos_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

// main.dart PROVISIONAL: falta la ruta de gastos (funcionalidad extra).
// Mientras, esa opción del menú abre "En construcción".
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
      // Si la app se abrió tocando una alarma, abre "Caducan hoy"
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
          initialRoute: '/',
          routes: {
            '/': (context) => const HomeScreen(),
            '/carrito': (context) => const CarritoScreen(),
            '/productos': (context) => const ProductosScreen(),
            '/producto': (context) => const DetalleProductoScreen(),
            '/producto/form': (context) => const AddProductoScreen(),
            '/calendario': (context) => const CalendarioScreen(),
            '/caducan': (context) => const CaducanHoyScreen(),
            '/compra': (context) => const AddCompraScreen(),
            '/categorias': (context) => const CategoriasPage(),
            '/tiendas': (context) => const TiendasPage(),
          },
          // Rutas que todavía no existen (gastos)
          onUnknownRoute: (settings) => MaterialPageRoute(
            settings: settings,
            builder: (context) => EnConstruccion(ruta: settings.name ?? ''),
          ),
        );
      },
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
