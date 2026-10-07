import 'package:alacena/components/global_values.dart';
import 'package:alacena/pages/categorias_page.dart';
import 'package:alacena/pages/tiendas_page.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const AlacenaApp());
}

class AlacenaApp extends StatelessWidget {
  const AlacenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alacena',
      navigatorKey: GlobalValues.navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const InicioPage(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _indice,
        children: const [CategoriasPage(), TiendasPage()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() => _indice = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.category_outlined), label: 'Categorías'),
          NavigationDestination(
              icon: Icon(Icons.storefront_outlined), label: 'Tiendas'),
        ],
      ),
    );
  }
}