import 'package:alacena/components/boton_carrito.dart';
import 'package:alacena/components/estatus.dart';
import 'package:alacena/components/imagen_producto.dart';
import 'package:alacena/database/alacena_db.dart';
import 'package:alacena/database/categoria_dao.dart';
import 'package:alacena/database/producto_dao.dart';
import 'package:flutter/material.dart';

class ProductosScreen extends StatefulWidget {
  const ProductosScreen({super.key});

  @override
  State<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
  final AlacenaDB _db = AlacenaDB();
  late Future<List<ProductoDAO>> _futuro;
  List<CategoriaDAO> _categorias = [];
  int? _idCategoria;
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _futuro = _db.productos();
    _cargarCategorias();
  }

  Future<void> _cargarCategorias() async {
    final lista = await _db.categorias();
    if (!mounted) return;
    setState(() => _categorias = lista);
  }

  void _refrescar() {
    if (!mounted) return;
    setState(() {
      _futuro = _db.productos(idCategoria: _idCategoria);
    });
    _cargarCategorias();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nuevo producto',
        onPressed: () {
          Navigator.pushNamed(context, '/producto/form')
              .then((_) => _refrescar());
        },
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<ProductoDAO>>(
        future: _futuro,
        builder: (context, snapshot) {
          final productos = (snapshot.data ?? [])
              .where((p) =>
                  p.nombre.toLowerCase().contains(_busqueda.toLowerCase()))
              .toList();
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                floating: true,
                title: const Text('Productos'),
                actions: [BotonCarrito(alVolver: _refrescar)],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(64),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar producto',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (texto) => setState(() => _busqueda = texto),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _chipsCategorias()),
              if (!snapshot.hasData && !snapshot.hasError)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (productos.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('No hay productos')),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisExtent: 240,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _tarjeta(productos[index]),
                      childCount: productos.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _chipsCategorias() {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: const Text('Todas'),
              selected: _idCategoria == null,
              onSelected: (_) {
                _idCategoria = null;
                _refrescar();
              },
            ),
          ),
          ..._categorias.map(
            (c) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(c.nombre),
                selected: _idCategoria == c.idCategoria,
                onSelected: (_) {
                  _idCategoria = c.idCategoria;
                  _refrescar();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjeta(ProductoDAO p) {
    final estatus = CalculoEstatus.deProducto(p);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, '/producto', arguments: p.idProducto)
              .then((_) => _refrescar());
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ImagenProducto(
                ruta: p.imagen,
                size: 90,
                ancho: double.infinity,
                alto: double.infinity,
                radio: 0,
                heroTag: 'img_${p.idProducto}',
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${p.stock} ${p.unidad} · ${p.categoriaNombre}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  EtiquetaEstatus(estatus: estatus),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
