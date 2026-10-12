import 'package:alacena/components/imagen_producto.dart';
import 'package:alacena/database/alacena_db.dart';
import 'package:alacena/database/carrito_dao.dart';
import 'package:flutter/material.dart';

class CarritoScreen extends StatefulWidget {
  const CarritoScreen({super.key});

  @override
  State<CarritoScreen> createState() => _CarritoScreenState();
}

class _CarritoScreenState extends State<CarritoScreen> {
  final AlacenaDB _db = AlacenaDB();
  late Future<List<CarritoDAO>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = _db.carrito();
  }

  void _refrescar() {
    if (!mounted) return;
    setState(() {
      _futuro = _db.carrito();
    });
  }

  Future<void> _cambiarCantidad(CarritoDAO item, int nueva) async {
    await _db.cambiarCantidadCarrito(item.idCarrito!, nueva);
    _refrescar();
  }

  Future<void> _quitar(CarritoDAO item) async {
    await _db.quitarDelCarrito(item.idProducto);
    _refrescar();
  }

  void _yaLoCompre(CarritoDAO item) {
    Navigator.pushNamed(
      context,
      '/compra',
      arguments: {'idProducto': item.idProducto, 'cantidad': item.cantidad},
    ).then((guardado) async {
      if (guardado == true) {
        await _db.quitarDelCarrito(item.idProducto);
      }
      _refrescar();
    });
  }

  Future<void> _vaciar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vaciar carrito'),
        content: const Text('¿Quieres quitar todos los artículos del carrito?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Vaciar'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await _db.vaciarCarrito();
      _refrescar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<CarritoDAO>>(
        future: _futuro,
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];
          final totalPiezas = items.fold<int>(0, (s, e) => s + e.cantidad);
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 120,
                flexibleSpace: const FlexibleSpaceBar(
                  title: Text('Lista de compra'),
                ),
                actions: [
                  if (items.isNotEmpty)
                    IconButton(
                      tooltip: 'Vaciar carrito',
                      icon: const Icon(Icons.delete_sweep),
                      onPressed: _vaciar,
                    ),
                ],
              ),
              if (!snapshot.hasData && !snapshot.hasError)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (items.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 72),
                        SizedBox(height: 12),
                        Text('Tu carrito está vacío'),
                      ],
                    ),
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      '${items.length} producto(s) · $totalPiezas unidad(es)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _item(items[index]),
                      childCount: items.length,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _item(CarritoDAO item) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                ImagenProducto(ruta: item.imagen, size: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productoNombre ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.store, size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.ultimaTiendaNombre == null
                                  ? 'Sin compras registradas'
                                  : 'Última compra: ${item.ultimaTiendaNombre}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Quitar',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _quitar(item),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                IconButton.outlined(
                  icon: const Icon(Icons.remove),
                  onPressed: () => _cambiarCantidad(item, item.cantidad - 1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '${item.cantidad} ${item.unidad}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                IconButton.outlined(
                  icon: const Icon(Icons.add),
                  onPressed: () => _cambiarCantidad(item, item.cantidad + 1),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.check),
                  label: const Text('Ya lo compré'),
                  onPressed: () => _yaLoCompre(item),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
