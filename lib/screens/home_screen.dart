import 'package:alacena/components/boton_carrito.dart';
import 'package:alacena/components/estatus.dart';
import 'package:alacena/components/fechas.dart';
import 'package:alacena/components/imagen_producto.dart';
import 'package:alacena/components/menu_lateral.dart';
import 'package:alacena/components/notificaciones.dart';
import 'package:alacena/database/alacena_db.dart';
import 'package:alacena/database/producto_dao.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AlacenaDB _db = AlacenaDB();
  late Future<List<ProductoDAO>> _futuro;

  // todos | caducidad | existencia
  String _filtro = 'todos';

  @override
  void initState() {
    super.initState();
    _futuro = _db.productos();
  }

  Future<void> _refrescar() async {
    setState(() {
      _futuro = _db.productos();
    });
    await _futuro;
  }

  List<ProductoDAO> _alertas(List<ProductoDAO> productos) {
    final lista = productos.where((p) {
      final e = CalculoEstatus.deProducto(p);
      switch (_filtro) {
        case 'caducidad':
          return e == Estatus.caducado || e == Estatus.porCaducar;
        case 'existencia':
          return e == Estatus.sinExistencia || e == Estatus.porAgotarse;
        default:
          return e != Estatus.ok;
      }
    }).toList();

    lista.sort((a, b) {
      final ea = CalculoEstatus.deProducto(a).index;
      final eb = CalculoEstatus.deProducto(b).index;
      if (ea != eb) return ea.compareTo(eb);
      final fa = a.proximaCaducidad ?? '9999-12-31';
      final fb = b.proximaCaducidad ?? '9999-12-31';
      return fa.compareTo(fb);
    });
    return lista;
  }

  Future<void> _consumir(ProductoDAO p) async {
    final consumidas = await _db.consumir(p.idProducto!, 1);
    await Notificaciones.reprogramar();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(consumidas > 0
            ? 'Se consumió 1 ${p.unidad} de ${p.nombre} (del lote más próximo a caducar)'
            : '${p.nombre} no tiene existencia'),
        duration: const Duration(seconds: 2),
      ),
    );
    _refrescar();
  }

  Future<void> _agregarCarrito(ProductoDAO p) async {
    await _db.agregarAlCarrito(p.idProducto!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${p.nombre} agregado al carrito'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _abrirDetalle(ProductoDAO p) {
    Navigator.pushNamed(context, '/producto', arguments: p.idProducto)
        .then((_) => _refrescar());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: MenuLateral(alVolver: _refrescar),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Producto'),
        onPressed: () {
          Navigator.pushNamed(context, '/producto/form')
              .then((_) => _refrescar());
        },
      ),
      body: FutureBuilder<List<ProductoDAO>>(
        future: _futuro,
        builder: (context, snapshot) {
          final productos = snapshot.data ?? [];
          final alertas = _alertas(productos);

          final conteo = <Estatus, int>{};
          for (final p in productos) {
            final e = CalculoEstatus.deProducto(p);
            conteo[e] = (conteo[e] ?? 0) + 1;
          }

          return RefreshIndicator(
            onRefresh: _refrescar,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 140,
                  flexibleSpace: FlexibleSpaceBar(
                    title: const Text('Mi Alacena'),
                    background: Align(
                      alignment: const Alignment(0.85, 0.1),
                      child: Icon(
                        Icons.kitchen,
                        size: 70,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                  actions: [
                    IconButton(
                      tooltip: 'Calendario',
                      icon: const Icon(Icons.calendar_month),
                      onPressed: () {
                        Navigator.pushNamed(context, '/calendario')
                            .then((_) => _refrescar());
                      },
                    ),
                    BotonCarrito(alVolver: _refrescar),
                  ],
                ),
                if (!snapshot.hasData && !snapshot.hasError)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snapshot.hasError)
                  SliverFillRemaining(
                    child: Center(child: Text(snapshot.error.toString())),
                  )
                else ...[
                  SliverToBoxAdapter(child: _resumen(conteo)),
                  SliverToBoxAdapter(child: _filtros()),
                  if (alertas.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _vacio(productos.isEmpty),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.only(bottom: 90),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _item(alertas[index]),
                          childCount: alertas.length,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _resumen(Map<Estatus, int> conteo) {
    const estados = [
      Estatus.caducado,
      Estatus.porCaducar,
      Estatus.sinExistencia,
      Estatus.porAgotarse,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: Row(
        children: estados.map((e) {
          return Expanded(
            child: Card(
              color: e.color.withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  children: [
                    Icon(e.icono, color: e.color),
                    Text(
                      '${conteo[e] ?? 0}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: e.color,
                      ),
                    ),
                    Text(
                      e.etiqueta,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _filtros() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SegmentedButton<String>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: 'todos',
            label: Text('Todas'),
            icon: Icon(Icons.warning_amber),
          ),
          ButtonSegment(
            value: 'caducidad',
            label: Text('Caducidad'),
            icon: Icon(Icons.event_busy),
          ),
          ButtonSegment(
            value: 'existencia',
            label: Text('Existencia'),
            icon: Icon(Icons.inventory),
          ),
        ],
        selected: {_filtro},
        onSelectionChanged: (seleccion) {
          setState(() => _filtro = seleccion.first);
        },
      ),
    );
  }

  Widget _vacio(bool sinProductos) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              sinProductos ? Icons.inventory_2_outlined : Icons.task_alt,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              sinProductos
                  ? 'Aún no tienes productos.\nAgrega el primero con el botón +'
                  : 'Todo en orden, no hay alertas',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(ProductoDAO p) {
    final estatus = CalculoEstatus.deProducto(p);
    final textoCaducidad = p.proximaCaducidad == null
        ? 'Sin lotes activos'
        : '${Fechas.textoDias(Fechas.diasRestantes(p.proximaCaducidad!))}'
            ' (${Fechas.legible(p.proximaCaducidad)})';

    return Dismissible(
      key: ValueKey('alerta_${p.idProducto}'),
      direction:
          p.stock > 0 ? DismissDirection.startToEnd : DismissDirection.none,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: Colors.green.shade600,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          children: [
            Icon(Icons.restaurant, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Consumir 1',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        await _consumir(p);
        return false;
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: estatus.color, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _abrirDetalle(p),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ImagenProducto(
                  ruta: p.imagen,
                  size: 64,
                  heroTag: 'img_${p.idProducto}',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${p.categoriaNombre} · ${p.stock} ${p.unidad}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        textoCaducidad,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      EtiquetaEstatus(estatus: estatus),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Agregar al carrito',
                  icon: const Icon(Icons.add_shopping_cart),
                  onPressed: () => _agregarCarrito(p),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
