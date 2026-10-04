import 'dart:io';

import 'package:alacena/components/global_values.dart';
import 'package:alacena/database/carrito_dao.dart';
import 'package:alacena/database/categoria_dao.dart';
import 'package:alacena/database/compra_dao.dart';
import 'package:alacena/database/lote_dao.dart';
import 'package:alacena/database/producto_dao.dart';
import 'package:alacena/database/tienda_dao.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AlacenaDB {
  static const nameDB = 'ALACENADB';
  static const versionDB = 1;
  static Future<Database>? _database;

  Future<Database> get database => _database ??= _initDatabase();

  Future<Database> _initDatabase() async {
    final Directory folder = await getApplicationDocumentsDirectory();
    final String pathDB = join(folder.path, nameDB);
    return openDatabase(
      pathDB,
      version: versionDB,
      onConfigure: _onConfigure,
      onCreate: _createTables,
    );
  }

  // SQLite trae las llaves foráneas apagadas por defecto
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _createTables(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE categoria(
        id_categoria INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL UNIQUE COLLATE NOCASE
          CHECK(length(trim(nombre)) BETWEEN 1 AND 40),
        descripcion TEXT CHECK(descripcion IS NULL OR length(descripcion) <= 120)
      )
    ''');

    batch.execute('''
      CREATE TABLE tienda(
        id_tienda INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL UNIQUE COLLATE NOCASE
          CHECK(length(trim(nombre)) BETWEEN 1 AND 40),
        direccion TEXT CHECK(direccion IS NULL OR length(direccion) <= 120)
      )
    ''');

    batch.execute('''
      CREATE TABLE producto(
        id_producto INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL CHECK(length(trim(nombre)) BETWEEN 1 AND 50),
        descripcion TEXT CHECK(descripcion IS NULL OR length(descripcion) <= 200),
        unidad TEXT NOT NULL DEFAULT 'pza'
          CHECK(unidad IN ('pza','kg','g','l','ml','paq','lata','caja')),
        stock_minimo INTEGER NOT NULL DEFAULT 1 CHECK(stock_minimo >= 0),
        dias_aviso INTEGER NOT NULL DEFAULT 3 CHECK(dias_aviso BETWEEN 0 AND 60),
        alarma_activa INTEGER NOT NULL DEFAULT 1 CHECK(alarma_activa IN (0,1)),
        hora_alarma TEXT NOT NULL DEFAULT '09:00'
          CHECK(hora_alarma GLOB '[0-2][0-9]:[0-5][0-9]' AND hora_alarma <= '23:59'),
        imagen TEXT,
        id_categoria INTEGER NOT NULL
          REFERENCES categoria(id_categoria) ON UPDATE CASCADE ON DELETE RESTRICT,
        ultima_tienda_id INTEGER
          REFERENCES tienda(id_tienda) ON UPDATE CASCADE ON DELETE SET NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE historial_compras(
        id_compra INTEGER PRIMARY KEY AUTOINCREMENT,
        id_producto INTEGER NOT NULL
          REFERENCES producto(id_producto) ON UPDATE CASCADE ON DELETE CASCADE,
        id_tienda INTEGER NOT NULL
          REFERENCES tienda(id_tienda) ON UPDATE CASCADE ON DELETE RESTRICT,
        cantidad INTEGER NOT NULL CHECK(cantidad > 0),
        precio_unitario REAL NOT NULL DEFAULT 0 CHECK(precio_unitario >= 0),
        fecha_compra TEXT NOT NULL CHECK(date(fecha_compra) = fecha_compra)
      )
    ''');

    batch.execute('''
      CREATE TABLE lote(
        id_lote INTEGER PRIMARY KEY AUTOINCREMENT,
        id_producto INTEGER NOT NULL
          REFERENCES producto(id_producto) ON UPDATE CASCADE ON DELETE CASCADE,
        id_compra INTEGER
          REFERENCES historial_compras(id_compra) ON UPDATE CASCADE ON DELETE CASCADE,
        cantidad INTEGER NOT NULL CHECK(cantidad >= 0),
        fecha_caducidad TEXT NOT NULL CHECK(date(fecha_caducidad) = fecha_caducidad),
        fecha_registro TEXT NOT NULL DEFAULT (date('now','localtime'))
      )
    ''');

    batch.execute('''
      CREATE TABLE carrito(
        id_carrito INTEGER PRIMARY KEY AUTOINCREMENT,
        id_producto INTEGER NOT NULL UNIQUE
          REFERENCES producto(id_producto) ON UPDATE CASCADE ON DELETE CASCADE,
        cantidad INTEGER NOT NULL DEFAULT 1 CHECK(cantidad > 0),
        fecha_agregado TEXT NOT NULL DEFAULT (date('now','localtime'))
      )
    ''');

    batch.execute(
        'CREATE INDEX idx_lote_producto ON lote(id_producto, fecha_caducidad)');
    batch.execute(
        'CREATE INDEX idx_compra_producto ON historial_compras(id_producto)');
    batch.execute(
        'CREATE INDEX idx_compra_tienda ON historial_compras(id_tienda)');

    // Regla de negocio: la última tienda se actualiza al registrar una compra
    batch.execute('''
      CREATE TRIGGER trg_ultima_tienda_insert
      AFTER INSERT ON historial_compras
      BEGIN
        UPDATE producto SET ultima_tienda_id = NEW.id_tienda
        WHERE id_producto = NEW.id_producto;
      END
    ''');

    // Si se elimina una compra, se recalcula la última tienda con lo que quede
    batch.execute('''
      CREATE TRIGGER trg_ultima_tienda_delete
      AFTER DELETE ON historial_compras
      BEGIN
        UPDATE producto SET ultima_tienda_id = (
          SELECT h.id_tienda FROM historial_compras h
          WHERE h.id_producto = OLD.id_producto
          ORDER BY h.fecha_compra DESC, h.id_compra DESC
          LIMIT 1
        )
        WHERE id_producto = OLD.id_producto;
      END
    ''');

    // Datos iniciales
    const categorias = [
      'Lácteos',
      'Abarrotes',
      'Carnes y embutidos',
      'Frutas y verduras',
      'Panadería',
      'Bebidas',
      'Congelados',
      'Limpieza',
    ];
    for (final c in categorias) {
      batch.insert('categoria', {'nombre': c});
    }
    const tiendas = ['Supermercado', 'Mercado municipal', 'Tienda de la esquina'];
    for (final t in tiendas) {
      batch.insert('tienda', {'nombre': t});
    }

    await batch.commit(noResult: true);
  }

  // ---------------------------------------------------------------------------
  // CRUD genérico
  // ---------------------------------------------------------------------------

  Future<int> insertar(String tabla, Map<String, Object?> datos) async {
    final conexion = await database;
    return conexion.insert(tabla, datos);
  }

  Future<int> actualizar(
      String tabla, Map<String, Object?> datos, String campoId) async {
    final conexion = await database;
    return conexion.update(tabla, datos,
        where: '$campoId = ?', whereArgs: [datos[campoId]]);
  }

  Future<int> eliminar(String tabla, String campoId, int id) async {
    final conexion = await database;
    return conexion.delete(tabla, where: '$campoId = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------------
  // Categorías
  // ---------------------------------------------------------------------------

  Future<List<CategoriaDAO>> categorias() async {
    final conexion = await database;
    final res = await conexion.rawQuery('''
      SELECT c.*,
        (SELECT COUNT(*) FROM producto p WHERE p.id_categoria = c.id_categoria)
          AS total_productos
      FROM categoria c
      ORDER BY c.nombre COLLATE NOCASE
    ''');
    return res.map((e) => CategoriaDAO.fromMap(e)).toList();
  }

  Future<int> contarProductosCategoria(int idCategoria) async {
    final conexion = await database;
    final res = await conexion.rawQuery(
        'SELECT COUNT(*) AS total FROM producto WHERE id_categoria = ?',
        [idCategoria]);
    return (res.first['total'] as int?) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Tiendas
  // ---------------------------------------------------------------------------

  Future<List<TiendaDAO>> tiendas() async {
    final conexion = await database;
    final res = await conexion.rawQuery('''
      SELECT t.*,
        (SELECT COUNT(*) FROM historial_compras h WHERE h.id_tienda = t.id_tienda)
          AS total_compras
      FROM tienda t
      ORDER BY t.nombre COLLATE NOCASE
    ''');
    return res.map((e) => TiendaDAO.fromMap(e)).toList();
  }

  Future<int> contarComprasTienda(int idTienda) async {
    final conexion = await database;
    final res = await conexion.rawQuery(
        'SELECT COUNT(*) AS total FROM historial_compras WHERE id_tienda = ?',
        [idTienda]);
    return (res.first['total'] as int?) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Productos
  // ---------------------------------------------------------------------------

  static const String _consultaProductos = '''
    SELECT p.*,
      c.nombre AS categoria_nombre,
      t.nombre AS ultima_tienda_nombre,
      IFNULL((SELECT SUM(l.cantidad) FROM lote l
              WHERE l.id_producto = p.id_producto AND l.cantidad > 0), 0) AS stock,
      (SELECT MIN(l.fecha_caducidad) FROM lote l
       WHERE l.id_producto = p.id_producto AND l.cantidad > 0) AS proxima_caducidad
    FROM producto p
    JOIN categoria c ON c.id_categoria = p.id_categoria
    LEFT JOIN tienda t ON t.id_tienda = p.ultima_tienda_id
  ''';

  Future<List<ProductoDAO>> productos({int? idCategoria}) async {
    final conexion = await database;
    final res = idCategoria == null
        ? await conexion.rawQuery(
            '$_consultaProductos ORDER BY p.nombre COLLATE NOCASE')
        : await conexion.rawQuery(
            '$_consultaProductos WHERE p.id_categoria = ? ORDER BY p.nombre COLLATE NOCASE',
            [idCategoria]);
    return res.map((e) => ProductoDAO.fromMap(e)).toList();
  }

  Future<ProductoDAO?> producto(int idProducto) async {
    final conexion = await database;
    final res = await conexion.rawQuery(
        '$_consultaProductos WHERE p.id_producto = ?', [idProducto]);
    if (res.isEmpty) return null;
    return ProductoDAO.fromMap(res.first);
  }

  // ---------------------------------------------------------------------------
  // Lotes
  // ---------------------------------------------------------------------------

  Future<List<LoteDAO>> lotesProducto(int idProducto) async {
    final conexion = await database;
    final res = await conexion.rawQuery('''
      SELECT l.*, p.unidad, p.dias_aviso, p.nombre AS producto_nombre
      FROM lote l JOIN producto p ON p.id_producto = l.id_producto
      WHERE l.id_producto = ?
      ORDER BY (l.cantidad > 0) DESC, l.fecha_caducidad ASC, l.id_lote ASC
    ''', [idProducto]);
    return res.map((e) => LoteDAO.fromMap(e)).toList();
  }

  static const String _consultaCaducidades = '''
    SELECT l.id_producto, l.fecha_caducidad,
      SUM(l.cantidad) AS cantidad,
      COUNT(*) AS num_lotes,
      p.nombre AS producto_nombre, p.imagen, p.unidad, p.dias_aviso,
      c.nombre AS categoria_nombre,
      (SELECT IFNULL(SUM(l2.cantidad), 0) FROM lote l2
       WHERE l2.id_producto = l.id_producto AND l2.cantidad > 0) AS stock_total
    FROM lote l
    JOIN producto p ON p.id_producto = l.id_producto
    JOIN categoria c ON c.id_categoria = p.id_categoria
    WHERE l.cantidad > 0
  ''';

  static const String _agrupacionCaducidades = '''
    GROUP BY l.id_producto, l.fecha_caducidad, p.nombre, p.imagen, p.unidad,
      p.dias_aviso, c.nombre
    ORDER BY l.fecha_caducidad, p.nombre COLLATE NOCASE
  ''';

  /// Lotes activos agrupados por producto y fecha (para el calendario)
  Future<List<LoteDAO>> caducidadesActivas() async {
    final conexion = await database;
    final res =
        await conexion.rawQuery('$_consultaCaducidades $_agrupacionCaducidades');
    return res.map((e) => LoteDAO.fromMap(e)).toList();
  }

  /// Productos que caducan en una fecha específica (yyyy-MM-dd)
  Future<List<LoteDAO>> caducidadesDelDia(String fecha) async {
    final conexion = await database;
    final res = await conexion.rawQuery(
        '$_consultaCaducidades AND l.fecha_caducidad = ? $_agrupacionCaducidades',
        [fecha]);
    return res.map((e) => LoteDAO.fromMap(e)).toList();
  }

  Future<int> actualizarLote(int idLote, int cantidad, String fecha) async {
    final conexion = await database;
    return conexion.update(
      'lote',
      {'cantidad': cantidad, 'fecha_caducidad': fecha},
      where: 'id_lote = ?',
      whereArgs: [idLote],
    );
  }

  /// Regla FEFO: se descuenta primero del lote con la caducidad más próxima.
  /// Regresa cuántas unidades se pudieron consumir.
  Future<int> consumir(int idProducto, int cantidad) async {
    final conexion = await database;
    return conexion.transaction((txn) async {
      final lotes = await txn.query(
        'lote',
        where: 'id_producto = ? AND cantidad > 0',
        whereArgs: [idProducto],
        orderBy: 'fecha_caducidad ASC, id_lote ASC',
      );
      int restante = cantidad;
      for (final lote in lotes) {
        if (restante <= 0) break;
        final int disponible = lote['cantidad'] as int;
        final int quitar = disponible < restante ? disponible : restante;
        await txn.update(
          'lote',
          {'cantidad': disponible - quitar},
          where: 'id_lote = ?',
          whereArgs: [lote['id_lote']],
        );
        restante -= quitar;
      }
      return cantidad - restante;
    });
  }

  // ---------------------------------------------------------------------------
  // Historial de compras
  // ---------------------------------------------------------------------------

  /// Registra la compra y su lote en una sola transacción.
  /// El trigger trg_ultima_tienda_insert actualiza producto.ultima_tienda_id.
  Future<int> registrarCompra(CompraDAO compra, String fechaCaducidad) async {
    final conexion = await database;
    return conexion.transaction((txn) async {
      final idCompra = await txn.insert('historial_compras', compra.toMap());
      await txn.insert('lote', {
        'id_producto': compra.idProducto,
        'id_compra': idCompra,
        'cantidad': compra.cantidad,
        'fecha_caducidad': fechaCaducidad,
      });
      return idCompra;
    });
  }

  Future<List<CompraDAO>> comprasProducto(int idProducto) async {
    final conexion = await database;
    final res = await conexion.rawQuery('''
      SELECT h.*, t.nombre AS tienda_nombre
      FROM historial_compras h JOIN tienda t ON t.id_tienda = h.id_tienda
      WHERE h.id_producto = ?
      ORDER BY h.fecha_compra DESC, h.id_compra DESC
    ''', [idProducto]);
    return res.map((e) => CompraDAO.fromMap(e)).toList();
  }

  /// Histórico global: todas las tiendas donde se ha comprado un producto
  Future<List<Map<String, dynamic>>> tiendasProducto(int idProducto) async {
    final conexion = await database;
    return conexion.rawQuery('''
      SELECT t.id_tienda, t.nombre,
        COUNT(*) AS veces,
        MIN(h.precio_unitario) AS precio_min,
        MAX(h.fecha_compra) AS ultima_fecha
      FROM historial_compras h JOIN tienda t ON t.id_tienda = h.id_tienda
      WHERE h.id_producto = ?
      GROUP BY t.id_tienda, t.nombre
      ORDER BY ultima_fecha DESC
    ''', [idProducto]);
  }

  // ---------------------------------------------------------------------------
  // Carrito
  // ---------------------------------------------------------------------------

  Future<List<CarritoDAO>> carrito() async {
    final conexion = await database;
    final res = await conexion.rawQuery('''
      SELECT ca.*, p.nombre AS producto_nombre, p.imagen, p.unidad,
        t.nombre AS ultima_tienda_nombre
      FROM carrito ca
      JOIN producto p ON p.id_producto = ca.id_producto
      LEFT JOIN tienda t ON t.id_tienda = p.ultima_tienda_id
      ORDER BY t.nombre COLLATE NOCASE, p.nombre COLLATE NOCASE
    ''');
    return res.map((e) => CarritoDAO.fromMap(e)).toList();
  }

  Future<void> agregarAlCarrito(int idProducto, {int cantidad = 1}) async {
    final conexion = await database;
    final existe = await conexion.query('carrito',
        where: 'id_producto = ?', whereArgs: [idProducto]);
    if (existe.isEmpty) {
      await conexion.insert(
          'carrito', {'id_producto': idProducto, 'cantidad': cantidad});
    } else {
      await conexion.update(
        'carrito',
        {'cantidad': (existe.first['cantidad'] as int) + cantidad},
        where: 'id_producto = ?',
        whereArgs: [idProducto],
      );
    }
    await refrescarContadorCarrito();
  }

  Future<void> cambiarCantidadCarrito(int idCarrito, int cantidad) async {
    final conexion = await database;
    if (cantidad <= 0) {
      await conexion
          .delete('carrito', where: 'id_carrito = ?', whereArgs: [idCarrito]);
    } else {
      await conexion.update('carrito', {'cantidad': cantidad},
          where: 'id_carrito = ?', whereArgs: [idCarrito]);
    }
    await refrescarContadorCarrito();
  }

  Future<void> quitarDelCarrito(int idProducto) async {
    final conexion = await database;
    await conexion
        .delete('carrito', where: 'id_producto = ?', whereArgs: [idProducto]);
    await refrescarContadorCarrito();
  }

  Future<void> vaciarCarrito() async {
    final conexion = await database;
    await conexion.delete('carrito');
    await refrescarContadorCarrito();
  }

  Future<void> refrescarContadorCarrito() async {
    final conexion = await database;
    final res = await conexion
        .rawQuery('SELECT IFNULL(SUM(cantidad), 0) AS total FROM carrito');
    GlobalValues.carritoCount.value = ((res.first['total'] as num?) ?? 0).toInt();
  }

  // ---------------------------------------------------------------------------
  // Alarmas
  // ---------------------------------------------------------------------------

  /// Fechas y horas en que hay que lanzar alarma (productos con alarma_activa = 1)
  Future<List<Map<String, dynamic>>> alarmasPendientes(String desde) async {
    final conexion = await database;
    return conexion.rawQuery('''
      SELECT l.fecha_caducidad AS fecha, p.hora_alarma AS hora,
        COUNT(DISTINCT p.id_producto) AS total,
        GROUP_CONCAT(DISTINCT p.nombre) AS nombres
      FROM lote l JOIN producto p ON p.id_producto = l.id_producto
      WHERE l.cantidad > 0 AND p.alarma_activa = 1 AND l.fecha_caducidad >= ?
      GROUP BY l.fecha_caducidad, p.hora_alarma
      ORDER BY l.fecha_caducidad, p.hora_alarma
      LIMIT 60
    ''', [desde]);
  }

  // ---------------------------------------------------------------------------
  // Gastos (funcionalidad extra)
  // ---------------------------------------------------------------------------

  Future<double> gastoTotal(String? desde) async {
    final conexion = await database;
    final res = await conexion.rawQuery('''
      SELECT IFNULL(SUM(cantidad * precio_unitario), 0) AS total
      FROM historial_compras
      ${desde == null ? '' : 'WHERE fecha_compra >= ?'}
    ''', desde == null ? [] : [desde]);
    return ((res.first['total'] as num?) ?? 0).toDouble();
  }

  Future<List<Map<String, dynamic>>> gastosPorTienda(String? desde) async {
    final conexion = await database;
    return conexion.rawQuery('''
      SELECT t.nombre, COUNT(*) AS compras,
        SUM(h.cantidad * h.precio_unitario) AS total
      FROM historial_compras h JOIN tienda t ON t.id_tienda = h.id_tienda
      ${desde == null ? '' : 'WHERE h.fecha_compra >= ?'}
      GROUP BY t.id_tienda, t.nombre
      ORDER BY total DESC
    ''', desde == null ? [] : [desde]);
  }

  Future<List<Map<String, dynamic>>> gastosPorProducto(String? desde) async {
    final conexion = await database;
    return conexion.rawQuery('''
      SELECT p.nombre, p.unidad, SUM(h.cantidad) AS unidades,
        SUM(h.cantidad * h.precio_unitario) AS total
      FROM historial_compras h JOIN producto p ON p.id_producto = h.id_producto
      ${desde == null ? '' : 'WHERE h.fecha_compra >= ?'}
      GROUP BY p.id_producto, p.nombre, p.unidad
      ORDER BY total DESC
      LIMIT 10
    ''', desde == null ? [] : [desde]);
  }
}
