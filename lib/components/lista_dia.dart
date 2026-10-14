import 'dart:io';

import 'package:alacena/database/alacena_db.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Tipos de alerta, ordenados de mas a menos grave.
enum TipoAlerta { caducado, agotado, porCaducar, porAgotarse }

extension TipoAlertaInfo on TipoAlerta {
  Color get color {
    switch (this) {
      case TipoAlerta.caducado:
        return Colors.red.shade700;
      case TipoAlerta.agotado:
        return Colors.blueGrey.shade600;
      case TipoAlerta.porCaducar:
        return Colors.orange.shade800;
      case TipoAlerta.porAgotarse:
        return Colors.amber.shade700;
    }
  }

  IconData get icono {
    switch (this) {
      case TipoAlerta.caducado:
        return Icons.event_busy;
      case TipoAlerta.agotado:
        return Icons.remove_shopping_cart_outlined;
      case TipoAlerta.porCaducar:
        return Icons.hourglass_bottom;
      case TipoAlerta.porAgotarse:
        return Icons.trending_down;
    }
  }

  String get etiqueta {
    switch (this) {
      case TipoAlerta.caducado:
        return 'Caducado';
      case TipoAlerta.agotado:
        return 'Sin existencia';
      case TipoAlerta.porCaducar:
        return 'Por caducar';
      case TipoAlerta.porAgotarse:
        return 'Por agotarse';
    }
  }
}

/// Una alerta de un producto en un dia concreto.
///
/// - caducado / porCaducar: se ubican en la fecha de caducidad del lote.
/// - agotado / porAgotarse: no tienen fecha propia, se ubican en HOY.
class AlertaDia {
  final int idProducto;
  final String nombre;
  final String? imagen;
  final String unidad;
  final String categoria;
  final TipoAlerta tipo;

  /// Dia de la alerta (UTC a medianoche, como usa table_calendar).
  final DateTime fecha;

  /// Unidades del lote (caducidades) o stock actual (agotamientos).
  final int cantidad;
  final int stockTotal;
  final int stockMinimo;

  const AlertaDia({
    required this.idProducto,
    required this.nombre,
    required this.imagen,
    required this.unidad,
    required this.categoria,
    required this.tipo,
    required this.fecha,
    required this.cantidad,
    required this.stockTotal,
    required this.stockMinimo,
  });

  static DateTime hoy() {
    final n = DateTime.now();
    return DateTime.utc(n.year, n.month, n.day);
  }

  static DateTime _fecha(String texto) {
    final p = texto.split('-');
    return DateTime.utc(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  /// Texto corto con lo mas importante de la alerta.
  String get detalle {
    final f = DateFormat('d MMM yyyy', 'es_MX');
    switch (tipo) {
      case TipoAlerta.caducado:
        return 'Caducó el ${f.format(fecha)} · $cantidad $unidad';
      case TipoAlerta.porCaducar:
        final d = fecha.difference(hoy()).inDays;
        final cuando = d == 0
            ? 'Caduca hoy'
            : d == 1
                ? 'Caduca mañana'
                : 'Caduca en $d días';
        return '$cuando · $cantidad $unidad';
      case TipoAlerta.agotado:
        return 'Sin existencia';
      case TipoAlerta.porAgotarse:
        return 'Quedan $cantidad $unidad (mínimo $stockMinimo)';
    }
  }

  // Lotes activos agrupados por producto y fecha de caducidad.
  static const String _sqlLotes = '''
    SELECT l.id_producto, l.fecha_caducidad,
      SUM(l.cantidad) AS cantidad,
      p.nombre, p.imagen, p.unidad, p.dias_aviso, p.stock_minimo,
      c.nombre AS categoria,
      (SELECT IFNULL(SUM(l2.cantidad), 0) FROM lote l2
       WHERE l2.id_producto = l.id_producto AND l2.cantidad > 0) AS stock_total
    FROM lote l
    JOIN producto p ON p.id_producto = l.id_producto
    JOIN categoria c ON c.id_categoria = p.id_categoria
    WHERE l.cantidad > 0
    GROUP BY l.id_producto, l.fecha_caducidad, p.nombre, p.imagen, p.unidad,
      p.dias_aviso, p.stock_minimo, c.nombre
    ORDER BY l.fecha_caducidad, p.nombre COLLATE NOCASE
  ''';

  // Productos con stock en el minimo o por debajo (incluye los de stock 0).
  static const String _sqlBajos = '''
    SELECT * FROM (
      SELECT p.id_producto, p.nombre, p.imagen, p.unidad, p.stock_minimo,
        c.nombre AS categoria,
        IFNULL((SELECT SUM(l.cantidad) FROM lote l
                WHERE l.id_producto = p.id_producto AND l.cantidad > 0), 0) AS stock
      FROM producto p
      JOIN categoria c ON c.id_categoria = p.id_categoria
    )
    WHERE stock <= stock_minimo
    ORDER BY nombre COLLATE NOCASE
  ''';

  /// Carga todas las alertas vigentes de la alacena.
  static Future<List<AlertaDia>> cargarTodas() async {
    final db = await AlacenaDB().database;
    final hoyDia = hoy();
    final alertas = <AlertaDia>[];

    final lotes = await db.rawQuery(_sqlLotes);
    for (final r in lotes) {
      final fecha = _fecha(r['fecha_caducidad'] as String);
      final dias = fecha.difference(hoyDia).inDays;
      final aviso = (r['dias_aviso'] as num).toInt();

      TipoAlerta? tipo;
      if (dias < 0) {
        tipo = TipoAlerta.caducado;
      } else if (dias <= aviso) {
        tipo = TipoAlerta.porCaducar;
      }
      if (tipo == null) continue; // todavia no hay alerta para este lote

      alertas.add(AlertaDia(
        idProducto: r['id_producto'] as int,
        nombre: r['nombre'] as String,
        imagen: r['imagen'] as String?,
        unidad: r['unidad'] as String,
        categoria: r['categoria'] as String,
        tipo: tipo,
        fecha: fecha,
        cantidad: (r['cantidad'] as num).toInt(),
        stockTotal: (r['stock_total'] as num).toInt(),
        stockMinimo: (r['stock_minimo'] as num).toInt(),
      ));
    }

    final bajos = await db.rawQuery(_sqlBajos);
    for (final r in bajos) {
      final stock = (r['stock'] as num).toInt();
      alertas.add(AlertaDia(
        idProducto: r['id_producto'] as int,
        nombre: r['nombre'] as String,
        imagen: r['imagen'] as String?,
        unidad: r['unidad'] as String,
        categoria: r['categoria'] as String,
        tipo: stock == 0 ? TipoAlerta.agotado : TipoAlerta.porAgotarse,
        fecha: hoyDia,
        cantidad: stock,
        stockTotal: stock,
        stockMinimo: (r['stock_minimo'] as num).toInt(),
      ));
    }

    alertas.sort((a, b) {
      final porFecha = a.fecha.compareTo(b.fecha);
      if (porFecha != 0) return porFecha;
      final porTipo = a.tipo.index.compareTo(b.tipo.index);
      if (porTipo != 0) return porTipo;
      return a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
    });
    return alertas;
  }

  /// Agrupa las alertas por dia (llave: UTC a medianoche).
  static Map<DateTime, List<AlertaDia>> agruparPorDia(List<AlertaDia> alertas) {
    final mapa = <DateTime, List<AlertaDia>>{};
    for (final a in alertas) {
      mapa.putIfAbsent(a.fecha, () => []).add(a);
    }
    return mapa;
  }
}

/// Lista de alertas como sliver (para usar dentro de un CustomScrollView).
class SliverListaAlertas extends StatelessWidget {
  const SliverListaAlertas({
    super.key,
    required this.alertas,
    required this.onAgregarCarrito,
  });

  final List<AlertaDia> alertas;
  final Future<void> Function(AlertaDia alerta) onAgregarCarrito;

  @override
  Widget build(BuildContext context) {
    if (alertas.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, size: 56),
              SizedBox(height: 12),
              Text('Sin alertas para este día'),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      sliver: SliverList.builder(
        itemCount: alertas.length,
        itemBuilder: (context, i) => _TarjetaAlerta(
          alerta: alertas[i],
          onAgregarCarrito: onAgregarCarrito,
        ),
      ),
    );
  }
}

class _TarjetaAlerta extends StatelessWidget {
  const _TarjetaAlerta({required this.alerta, required this.onAgregarCarrito});

  final AlertaDia alerta;
  final Future<void> Function(AlertaDia alerta) onAgregarCarrito;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: alerta.tipo.color, width: 5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              _Foto(ruta: alerta.imagen),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alerta.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: texto.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    _EtiquetaEstatus(tipo: alerta.tipo),
                    const SizedBox(height: 4),
                    Text(alerta.detalle, style: texto.bodyMedium),
                    Text(
                      '${alerta.categoria} · Stock total: '
                      '${alerta.stockTotal} ${alerta.unidad}',
                      style: texto.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Agregar al carrito',
                icon: const Icon(Icons.add_shopping_cart),
                onPressed: () => onAgregarCarrito(alerta),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EtiquetaEstatus extends StatelessWidget {
  const _EtiquetaEstatus({required this.tipo});

  final TipoAlerta tipo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: tipo.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tipo.icono, size: 14, color: tipo.color),
          const SizedBox(width: 4),
          Text(
            tipo.etiqueta,
            style: TextStyle(
              color: tipo.color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Foto extends StatelessWidget {
  const _Foto({required this.ruta});

  final String? ruta;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.inventory_2_outlined),
    );
    final tieneRuta = ruta != null && ruta!.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 64,
        height: 64,
        child: tieneRuta
            ? Image.file(
                File(ruta!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => placeholder,
              )
            : placeholder,
      ),
    );
  }
}

/// Modal que cubre toda la pantalla con las alertas de un dia.
/// Se abre con un MaterialPageRoute con `fullscreenDialog: true` cuyo
/// builder regresa `DiaAlertasScreen(dia: dia, alertas: alertas)`.
class DiaAlertasScreen extends StatelessWidget {
  const DiaAlertasScreen({super.key, required this.dia, required this.alertas});

  final DateTime dia;
  final List<AlertaDia> alertas;

  Future<void> _agregarAlCarrito(BuildContext context, AlertaDia a) async {
    final mensajes = ScaffoldMessenger.of(context);
    try {
      await AlacenaDB().agregarAlCarrito(a.idProducto);
      mensajes.showSnackBar(
        SnackBar(content: Text('${a.nombre} agregado al carrito')),
      );
    } catch (e) {
      mensajes.showSnackBar(
        SnackBar(content: Text('No se pudo agregar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final titulo = toBeginningOfSentenceCase(
      DateFormat("EEEE d 'de' MMMM", 'es_MX').format(dia),
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            leading: IconButton(
              tooltip: 'Cerrar',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(titulo),
          ),
          if (alertas.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  alertas.length == 1
                      ? '1 alerta'
                      : '${alertas.length} alertas',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
          SliverListaAlertas(
            alertas: alertas,
            onAgregarCarrito: (a) => _agregarAlCarrito(context, a),
          ),
        ],
      ),
    );
  }
}