import 'package:alacena/database/alacena_db.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum _Periodo { semana, mes, anio, todo }

extension on _Periodo {
  String get etiqueta {
    switch (this) {
      case _Periodo.semana:
        return 'Semana';
      case _Periodo.mes:
        return 'Mes';
      case _Periodo.anio:
        return 'Año';
      case _Periodo.todo:
        return 'Todo';
    }
  }

  String get descripcion {
    switch (this) {
      case _Periodo.semana:
        return 'últimos 7 días';
      case _Periodo.mes:
        return 'últimos 30 días';
      case _Periodo.anio:
        return 'últimos 365 días';
      case _Periodo.todo:
        return 'todo el historial';
    }
  }

  /// Fecha inicial (yyyy-MM-dd) para filtrar; null = sin filtro.
  String? get desde {
    final int dias;
    switch (this) {
      case _Periodo.semana:
        dias = 7;
      case _Periodo.mes:
        dias = 30;
      case _Periodo.anio:
        dias = 365;
      case _Periodo.todo:
        return null;
    }
    final inicio = DateTime.now().subtract(Duration(days: dias));
    return DateFormat('yyyy-MM-dd').format(inicio);
  }
}

/// Resumen de gastos (funcionalidad extra): cuanto se ha gastado en total,
/// por tienda y por producto, filtrado por periodo.
class GastosScreen extends StatefulWidget {
  const GastosScreen({super.key});

  @override
  State<GastosScreen> createState() => _GastosScreenState();
}

class _GastosScreenState extends State<GastosScreen> {
  final _db = AlacenaDB();
  final _moneda = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  _Periodo _periodo = _Periodo.mes;
  bool _cargando = true;
  String? _error;

  double _total = 0;
  List<Map<String, dynamic>> _tiendas = [];
  List<Map<String, dynamic>> _productos = [];

  // Evita que una respuesta lenta pise a una mas reciente.
  int _peticion = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final id = ++_peticion;
    setState(() {
      _cargando = true;
      _error = null;
    });
    final desde = _periodo.desde;
    try {
      final total = await _db.gastoTotal(desde);
      final tiendas = await _db.gastosPorTienda(desde);
      final productos = await _db.gastosPorProducto(desde);
      if (!mounted || id != _peticion) return;
      setState(() {
        _total = total;
        _tiendas = tiendas;
        _productos = productos;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted || id != _peticion) return;
      setState(() {
        _error = '$e';
        _cargando = false;
      });
    }
  }

  double _monto(Map<String, dynamic> fila) =>
      ((fila['total'] as num?) ?? 0).toDouble();

  int get _numCompras => _tiendas.fold<int>(
        0,
        (suma, t) => suma + ((t['compras'] as num?) ?? 0).toInt(),
      );

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final texto = Theme.of(context).textTheme;
    final sinDatos = !_cargando && _error == null && _total == 0;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text('Resumen de gastos'),
            actions: [
              IconButton(
                tooltip: 'Actualizar',
                icon: const Icon(Icons.refresh),
                onPressed: _cargando ? null : _cargar,
              ),
            ],
          ),
          if (_cargando)
            const SliverToBoxAdapter(child: LinearProgressIndicator()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: SegmentedButton<_Periodo>(
                showSelectedIcon: false,
                segments: [
                  for (final p in _Periodo.values)
                    ButtonSegment(value: p, label: Text(p.etiqueta)),
                ],
                selected: {_periodo},
                onSelectionChanged: (seleccion) {
                  setState(() => _periodo = seleccion.first);
                  _cargar();
                },
              ),
            ),
          ),
          if (_error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No se pudo cargar el resumen: $_error',
                  style: TextStyle(color: colores.error),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Card(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              color: colores.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total gastado · ${_periodo.descripcion}',
                      style: texto.labelLarge
                          ?.copyWith(color: colores.onPrimaryContainer),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _moneda.format(_total),
                      style: texto.headlineLarge?.copyWith(
                        color: colores.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _numCompras == 1
                          ? '1 compra registrada'
                          : '$_numCompras compras registradas',
                      style: texto.bodyMedium
                          ?.copyWith(color: colores.onPrimaryContainer),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (sinDatos)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 56),
                      SizedBox(height: 12),
                      Text(
                        'Aún no hay compras en este periodo',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            _encabezado('Por tienda'),
            _listaBarras(
              filas: _tiendas,
              titulo: (f) => f['nombre'] as String,
              detalle: (f) {
                final n = ((f['compras'] as num?) ?? 0).toInt();
                return n == 1 ? '1 compra' : '$n compras';
              },
              icono: Icons.storefront_outlined,
            ),
            _encabezado('Productos con mayor gasto'),
            _listaBarras(
              filas: _productos,
              titulo: (f) => f['nombre'] as String,
              detalle: (f) {
                final unidades = ((f['unidades'] as num?) ?? 0).toInt();
                return '$unidades ${f['unidad']} compradas';
              },
              icono: Icons.shopping_basket_outlined,
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ],
      ),
    );
  }

  Widget _encabezado(String texto) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(texto, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }

  /// Lista con una barra proporcional al gasto maximo de la lista.
  Widget _listaBarras({
    required List<Map<String, dynamic>> filas,
    required String Function(Map<String, dynamic>) titulo,
    required String Function(Map<String, dynamic>) detalle,
    required IconData icono,
  }) {
    if (filas.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    final maximo = _monto(filas.first); // vienen ordenadas de mayor a menor
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverList.builder(
        itemCount: filas.length,
        itemBuilder: (context, i) {
          final fila = filas[i];
          final monto = _monto(fila);
          return _FilaGasto(
            icono: icono,
            titulo: titulo(fila),
            detalle: detalle(fila),
            monto: _moneda.format(monto),
            fraccion: maximo <= 0 ? 0 : (monto / maximo).clamp(0.0, 1.0),
          );
        },
      ),
    );
  }
}

class _FilaGasto extends StatelessWidget {
  const _FilaGasto({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.monto,
    required this.fraccion,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
  final String monto;
  final double fraccion;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icono),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: texto.titleSmall,
                      ),
                      Text(detalle, style: texto.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  monto,
                  style: texto.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: fraccion, minHeight: 6),
            ),
          ],
        ),
      ),
    );
  }
}