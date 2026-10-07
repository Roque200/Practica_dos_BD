import 'dart:io';

import 'package:alacena/components/estatus.dart';
import 'package:alacena/components/fechas.dart';
import 'package:alacena/components/imagen_producto.dart';
import 'package:alacena/components/notificaciones.dart';
import 'package:alacena/database/alacena_db.dart';
import 'package:alacena/database/compra_dao.dart';
import 'package:alacena/database/lote_dao.dart';
import 'package:alacena/database/producto_dao.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class _DatosDetalle {
  _DatosDetalle(this.producto, this.lotes, this.compras, this.tiendas);

  final ProductoDAO? producto;
  final List<LoteDAO> lotes;
  final List<CompraDAO> compras;
  final List<Map<String, dynamic>> tiendas;
}

class DetalleProductoScreen extends StatefulWidget {
  const DetalleProductoScreen({super.key});

  @override
  State<DetalleProductoScreen> createState() => _DetalleProductoScreenState();
}

class _DetalleProductoScreenState extends State<DetalleProductoScreen> {
  final AlacenaDB _db = AlacenaDB();
  int? _idProducto;
  Future<_DatosDetalle>? _futuro;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_idProducto == null) {
      _idProducto = ModalRoute.of(context)!.settings.arguments as int;
      _futuro = _cargar();
    }
  }

  Future<_DatosDetalle> _cargar() async {
    final id = _idProducto!;
    final producto = await _db.producto(id);
    final lotes = await _db.lotesProducto(id);
    final compras = await _db.comprasProducto(id);
    final tiendas = await _db.tiendasProducto(id);
    return _DatosDetalle(producto, lotes, compras, tiendas);
  }

  void _refrescar() {
    if (!mounted) return;
    setState(() {
      _futuro = _cargar();
    });
  }

  void _mensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), duration: const Duration(seconds: 2)),
    );
  }

  // ---------------------------------------------------------------------------
  // Acciones
  // ---------------------------------------------------------------------------

  Future<void> _agregarCarrito(ProductoDAO p) async {
    await _db.agregarAlCarrito(p.idProducto!);
    if (!mounted) return;
    _mensaje('${p.nombre} agregado al carrito');
  }

  void _editar(ProductoDAO p) {
    Navigator.pushNamed(context, '/producto/form', arguments: p)
        .then((_) => _refrescar());
  }

  void _registrarCompra(ProductoDAO p) {
    Navigator.pushNamed(context, '/compra',
        arguments: {'idProducto': p.idProducto}).then((_) => _refrescar());
  }

  Future<void> _eliminar(ProductoDAO p) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text(
          'Se eliminará "${p.nombre}" junto con sus lotes, su historial de '
          'compras y su registro en el carrito. ¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    await _db.eliminar('producto', 'id_producto', p.idProducto!);
    if (p.imagen != null) {
      final archivo = File(p.imagen!);
      if (await archivo.exists()) await archivo.delete();
    }
    await _db.refrescarContadorCarrito();
    await Notificaciones.reprogramar();
    if (!mounted) return;
    _mensaje('Producto eliminado');
    Navigator.pop(context, true);
  }

  Future<void> _consumir(ProductoDAO p) async {
    final control = TextEditingController(text: '1');
    final cantidad = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Consumir'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Disponible: ${p.stock} ${p.unidad}'),
            const SizedBox(height: 4),
            const Text(
              'Se descuenta primero del lote que caduca antes (FEFO).',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: control,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Cantidad (${p.unidad})',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context, int.tryParse(control.text) ?? 0);
            },
            child: const Text('Consumir'),
          ),
        ],
      ),
    );
    if (cantidad == null) return;
    if (cantidad <= 0 || cantidad > p.stock) {
      if (!mounted) return;
      _mensaje('La cantidad debe estar entre 1 y ${p.stock}');
      return;
    }
    final consumidas = await _db.consumir(p.idProducto!, cantidad);
    await Notificaciones.reprogramar();
    if (!mounted) return;
    _mensaje('Se consumieron $consumidas ${p.unidad}');
    _refrescar();
  }

  Future<void> _editarLote(LoteDAO lote) async {
    final control = TextEditingController(text: '${lote.cantidad}');
    String fecha = lote.fechaCaducidad;
    final guardar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Lote #${lote.idLote}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: control,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Cantidad (${lote.unidad})',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.event),
                label: Text('Caduca: ${Fechas.legible(fecha)}'),
                onPressed: () async {
                  final elegida = await showDatePicker(
                    context: context,
                    initialDate: Fechas.deDb(fecha),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2040),
                  );
                  if (elegida != null) {
                    setDialogState(() => fecha = Fechas.aDb(elegida));
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    final cantidad = int.tryParse(control.text);
    if (guardar != true) return;
    if (cantidad == null || cantidad < 0) {
      if (!mounted) return;
      _mensaje('Cantidad no válida');
      return;
    }
    await _db.actualizarLote(lote.idLote!, cantidad, fecha);
    await Notificaciones.reprogramar();
    _refrescar();
  }

  Future<void> _eliminarLote(LoteDAO lote) async {
    final confirmar = await _confirmar(
      'Eliminar lote',
      '¿Eliminar el lote #${lote.idLote}? Úsalo para desechar un lote caducado.',
    );
    if (!confirmar) return;
    await _db.eliminar('lote', 'id_lote', lote.idLote!);
    await Notificaciones.reprogramar();
    _refrescar();
  }

  Future<void> _eliminarCompra(CompraDAO compra) async {
    final confirmar = await _confirmar(
      'Eliminar compra',
      'Se eliminará la compra y el lote que generó. '
          'La última tienda del producto se recalcula automáticamente.',
    );
    if (!confirmar) return;
    await _db.eliminar('historial_compras', 'id_compra', compra.idCompra!);
    await Notificaciones.reprogramar();
    _refrescar();
  }

  Future<bool> _confirmar(String titulo, String texto) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: Text(texto),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    return r == true;
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<_DatosDetalle>(
        future: _futuro,
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          final datos = snapshot.data!;
          final p = datos.producto;
          if (p == null) {
            return const Center(child: Text('El producto ya no existe'));
          }
          return CustomScrollView(
            slivers: [
              _cabecera(p),
              SliverToBoxAdapter(child: _informacion(p)),
              _titulo('Lotes (${datos.lotes.length})', Icons.layers),
              if (datos.lotes.isEmpty)
                _textoVacio('Sin lotes. Registra una compra para agregar existencia.')
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _lote(datos.lotes[i]),
                    childCount: datos.lotes.length,
                  ),
                ),
              _titulo('Tiendas donde se ha comprado', Icons.store),
              if (datos.tiendas.isEmpty)
                _textoVacio('Aún no hay compras registradas.')
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _tienda(datos.tiendas[i], p),
                    childCount: datos.tiendas.length,
                  ),
                ),
              _titulo('Historial de compras', Icons.receipt_long),
              if (datos.compras.isEmpty)
                _textoVacio('Sin historial.')
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _compra(datos.compras[i], p),
                    childCount: datos.compras.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
      ),
    );
  }

  Widget _cabecera(ProductoDAO p) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 260,
      actions: [
        IconButton(
          tooltip: 'Agregar al carrito',
          icon: const Icon(Icons.add_shopping_cart),
          onPressed: () => _agregarCarrito(p),
        ),
        IconButton(
          tooltip: 'Editar',
          icon: const Icon(Icons.edit),
          onPressed: () => _editar(p),
        ),
        IconButton(
          tooltip: 'Eliminar',
          icon: const Icon(Icons.delete),
          onPressed: () => _eliminar(p),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          p.nombre,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
          ),
        ),
        background: ImagenProducto(
          ruta: p.imagen,
          size: 160,
          ancho: double.infinity,
          alto: double.infinity,
          radio: 0,
          heroTag: 'img_${p.idProducto}',
        ),
      ),
    );
  }

  Widget _informacion(ProductoDAO p) {
    final estatus = CalculoEstatus.deProducto(p);
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                EtiquetaEstatus(estatus: estatus),
                const Spacer(),
                Text(
                  '${p.stock} ${p.unidad}',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (p.descripcion != null) ...[
              const SizedBox(height: 8),
              Text(p.descripcion!),
            ],
            const Divider(height: 24),
            _dato(Icons.category, 'Categoría', p.categoriaNombre ?? ''),
            _dato(Icons.event, 'Próxima caducidad',
                Fechas.legible(p.proximaCaducidad)),
            _dato(Icons.inventory, 'Stock mínimo', '${p.stockMinimo} ${p.unidad}'),
            _dato(Icons.notifications_active, 'Aviso',
                '${p.diasAviso} día(s) antes de caducar'),
            _dato(
              Icons.alarm,
              'Alarma',
              p.alarmaActiva ? 'Activa a las ${p.horaAlarma}' : 'Desactivada',
            ),
            _dato(Icons.store, 'Última tienda',
                p.ultimaTiendaNombre ?? 'Sin compras'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.restaurant),
                    label: const Text('Consumir'),
                    onPressed: p.stock > 0 ? () => _consumir(p) : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Compra'),
                    onPressed: () => _registrarCompra(p),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dato(IconData icono, String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icono, size: 18),
          const SizedBox(width: 8),
          Text('$etiqueta: ',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(valor, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _titulo(String texto, IconData icono) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Row(
          children: [
            Icon(icono, size: 20),
            const SizedBox(width: 8),
            Text(texto, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }

  Widget _textoVacio(String texto) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Text(texto, style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }

  Widget _lote(LoteDAO lote) {
    final estatus = CalculoEstatus.deLote(lote);
    final dias = Fechas.diasRestantes(lote.fechaCaducidad);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ExpansionTile(
        shape: const Border(),
        leading: Icon(estatus.icono, color: estatus.color),
        title: Text('${lote.cantidad} ${lote.unidad} · ${Fechas.legible(lote.fechaCaducidad)}'),
        subtitle: Text(
          lote.cantidad > 0 ? Fechas.textoDias(dias) : 'Lote consumido',
          style: TextStyle(color: estatus.color),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Lote #${lote.idLote} · Registrado ${Fechas.legible(lote.fechaRegistro)}'
                  '${lote.idCompra != null ? ' · Compra #${lote.idCompra}' : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              IconButton(
                tooltip: 'Editar lote',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editarLote(lote),
              ),
              IconButton(
                tooltip: 'Eliminar lote',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _eliminarLote(lote),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tienda(Map<String, dynamic> t, ProductoDAO p) {
    final precio = ((t['precio_min'] as num?) ?? 0).toDouble();
    final esUltima = t['id_tienda'] == p.ultimaTiendaId;
    return ListTile(
      leading: CircleAvatar(child: Text('${t['veces']}')),
      title: Text(t['nombre'] as String),
      subtitle: Text(
        'Mejor precio: \$${precio.toStringAsFixed(2)} · '
        'Última vez: ${Fechas.legible(t['ultima_fecha'] as String?)}',
      ),
      trailing: esUltima
          ? const Chip(
              label: Text('Última', style: TextStyle(fontSize: 11)),
              visualDensity: VisualDensity.compact,
            )
          : null,
    );
  }

  Widget _compra(CompraDAO c, ProductoDAO p) {
    return ListTile(
      leading: const Icon(Icons.shopping_bag_outlined),
      title: Text('${c.tiendaNombre} · ${c.cantidad} ${p.unidad}'),
      subtitle: Text(
        '${Fechas.legible(c.fechaCompra)} · '
        '\$${c.precioUnitario.toStringAsFixed(2)} c/u · '
        'Total \$${c.total.toStringAsFixed(2)}',
      ),
      trailing: IconButton(
        tooltip: 'Eliminar compra',
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _eliminarCompra(c),
      ),
    );
  }
}
