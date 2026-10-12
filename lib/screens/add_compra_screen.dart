import 'package:alacena/database/alacena_db.dart';
import 'package:alacena/database/compra_dao.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Registro de una compra: producto, tienda, cantidad, precio y caducidad.
///
/// Se abre desde el menu o desde el carrito ("Ya lo compre"). Desde el
/// carrito se pasa el id del producto para que llegue preseleccionado:
///   Navigator.pushNamed(context, '/add_compra', arguments: idProducto);
///
/// Al guardar usa AlacenaDB.registrarCompra(), que en una transaccion inserta
/// la compra y su lote; el trigger actualiza producto.ultima_tienda_id.
class AddCompraScreen extends StatefulWidget {
  const AddCompraScreen({super.key});

  @override
  State<AddCompraScreen> createState() => _AddCompraScreenState();
}

class _AddCompraScreenState extends State<AddCompraScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = AlacenaDB();
  final _fmt = DateFormat('yyyy-MM-dd');

  final _conCantidad = TextEditingController(text: '1');
  final _conPrecio = TextEditingController();

  List<Map<String, dynamic>> _productos = [];
  List<Map<String, dynamic>> _tiendas = [];
  bool _cargando = true;
  bool _guardando = false;
  bool _argumentoLeido = false;

  int? _idProducto;
  int? _idTienda;
  DateTime _fechaCompra = DateTime.now();
  DateTime? _fechaCaducidad;

  // DropdownMenu no es un FormField, por eso sus errores se manejan aparte.
  String? _errorProducto;
  String? _errorTienda;
  String? _errorCaducidad;

  @override
  void initState() {
    super.initState();
    _cargarListas();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argumentoLeido) {
      _argumentoLeido = true;
      final arg = ModalRoute.of(context)?.settings.arguments;
      if (arg is int) _idProducto = arg;
    }
  }

  @override
  void dispose() {
    _conCantidad.dispose();
    _conPrecio.dispose();
    super.dispose();
  }

  Future<void> _cargarListas() async {
    final conexion = await _db.database;
    final productos = await conexion.query(
      'producto',
      columns: ['id_producto', 'nombre'],
      orderBy: 'nombre COLLATE NOCASE',
    );
    final tiendas = await conexion.query(
      'tienda',
      columns: ['id_tienda', 'nombre'],
      orderBy: 'nombre COLLATE NOCASE',
    );
    if (!mounted) return;
    setState(() {
      _productos = productos;
      _tiendas = tiendas;
      _cargando = false;
    });
  }

  Future<void> _elegirFecha({required bool esCaducidad}) async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: esCaducidad ? (_fechaCaducidad ?? hoy) : _fechaCompra,
      firstDate: esCaducidad ? DateTime(hoy.year - 1) : DateTime(hoy.year - 5),
      lastDate: esCaducidad ? DateTime(hoy.year + 10) : hoy,
    );
    if (elegida == null) return;
    setState(() {
      if (esCaducidad) {
        _fechaCaducidad = elegida;
        _errorCaducidad = null;
      } else {
        _fechaCompra = elegida;
      }
    });
  }

  bool _validarSelectores() {
    setState(() {
      _errorProducto = _idProducto == null ? 'Selecciona un producto' : null;
      _errorTienda = _idTienda == null ? 'Selecciona una tienda' : null;
      _errorCaducidad =
          _fechaCaducidad == null ? 'Elige la fecha de caducidad' : null;
    });
    return _errorProducto == null &&
        _errorTienda == null &&
        _errorCaducidad == null;
  }

  Future<void> _guardar() async {
    final formOk = _formKey.currentState!.validate();
    final selectoresOk = _validarSelectores();
    if (!formOk || !selectoresOk) return;

    setState(() => _guardando = true);
    try {
      final compra = CompraDAO(
        idProducto: _idProducto!,
        idTienda: _idTienda!,
        cantidad: int.parse(_conCantidad.text.trim()),
        precioUnitario: double.parse(_conPrecio.text.trim()),
        fechaCompra: _fmt.format(_fechaCompra),
      );
      await _db.registrarCompra(compra, _fmt.format(_fechaCaducidad!));

      // Ya se compro: sale del carrito (tambien actualiza el badge).
      await _db.quitarDelCarrito(_idProducto!);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compra registrada')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(
            pinned: true,
            title: Text('Registrar compra'),
          ),
          if (_cargando)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(child: _formulario()),
            ),
        ],
      ),
    );
  }

  Widget _formulario() {
    final sinDatos = _productos.isEmpty || _tiendas.isEmpty;
    final colores = Theme.of(context).colorScheme;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sinDatos)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Necesitas tener al menos un producto y una tienda registrados.',
              ),
            ),
          DropdownMenu<int>(
            initialSelection: _idProducto,
            expandedInsets: EdgeInsets.zero,
            label: const Text('Producto'),
            errorText: _errorProducto,
            enableFilter: true,
            dropdownMenuEntries: [
              for (final p in _productos)
                DropdownMenuEntry(
                  value: p['id_producto'] as int,
                  label: p['nombre'] as String,
                ),
            ],
            onSelected: (v) => setState(() {
              _idProducto = v;
              _errorProducto = null;
            }),
          ),
          const SizedBox(height: 16),
          DropdownMenu<int>(
            initialSelection: _idTienda,
            expandedInsets: EdgeInsets.zero,
            label: const Text('Tienda'),
            errorText: _errorTienda,
            dropdownMenuEntries: [
              for (final t in _tiendas)
                DropdownMenuEntry(
                  value: t['id_tienda'] as int,
                  label: t['nombre'] as String,
                ),
            ],
            onSelected: (v) => setState(() {
              _idTienda = v;
              _errorTienda = null;
            }),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _conCantidad,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Cantidad',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              final n = int.tryParse((v ?? '').trim());
              if (n == null) return 'Escribe un numero entero';
              if (n <= 0) return 'Debe ser mayor a 0';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _conPrecio,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Precio unitario',
              prefixText: '\$ ',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              final n = double.tryParse((v ?? '').trim());
              if (n == null) return 'Escribe un precio valido';
              if (n < 0) return 'No puede ser negativo';
              return null;
            },
          ),
          const SizedBox(height: 16),
          ListTile(
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(4),
            ),
            leading: const Icon(Icons.shopping_bag_outlined),
            title: const Text('Fecha de compra'),
            subtitle: Text(_fmt.format(_fechaCompra)),
            trailing: const Icon(Icons.edit_calendar),
            onTap: () => _elegirFecha(esCaducidad: false),
          ),
          const SizedBox(height: 16),
          ListTile(
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color: _errorCaducidad == null
                    ? Theme.of(context).dividerColor
                    : colores.error,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            leading: const Icon(Icons.event_busy),
            title: const Text('Fecha de caducidad'),
            subtitle: Text(
              _fechaCaducidad == null
                  ? (_errorCaducidad ?? 'Toca para elegir')
                  : _fmt.format(_fechaCaducidad!),
              style: _errorCaducidad == null
                  ? null
                  : TextStyle(color: colores.error),
            ),
            trailing: const Icon(Icons.edit_calendar),
            onTap: () => _elegirFecha(esCaducidad: true),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: (_guardando || sinDatos) ? null : _guardar,
            icon: _guardando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text('Guardar compra'),
          ),
        ],
      ),
    );
  }
}