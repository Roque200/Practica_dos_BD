class ProductoDAO {
  int? idProducto;
  String nombre;
  String? descripcion;
  String unidad;
  int stockMinimo;
  int diasAviso;
  bool alarmaActiva;
  String horaAlarma;
  String? imagen;
  int idCategoria;
  int? ultimaTiendaId;

  // Campos calculados (no se guardan en la tabla)
  String? categoriaNombre;
  String? ultimaTiendaNombre;
  int stock;
  String? proximaCaducidad;

  ProductoDAO({
    this.idProducto,
    required this.nombre,
    this.descripcion,
    this.unidad = 'pza',
    this.stockMinimo = 1,
    this.diasAviso = 3,
    this.alarmaActiva = true,
    this.horaAlarma = '09:00',
    this.imagen,
    required this.idCategoria,
    this.ultimaTiendaId,
    this.categoriaNombre,
    this.ultimaTiendaNombre,
    this.stock = 0,
    this.proximaCaducidad,
  });

  factory ProductoDAO.fromMap(Map<String, dynamic> map) {
    return ProductoDAO(
      idProducto: map['id_producto'] as int?,
      nombre: map['nombre'] as String,
      descripcion: map['descripcion'] as String?,
      unidad: map['unidad'] as String,
      stockMinimo: map['stock_minimo'] as int,
      diasAviso: map['dias_aviso'] as int,
      alarmaActiva: (map['alarma_activa'] as int) == 1,
      horaAlarma: map['hora_alarma'] as String,
      imagen: map['imagen'] as String?,
      idCategoria: map['id_categoria'] as int,
      ultimaTiendaId: map['ultima_tienda_id'] as int?,
      categoriaNombre: map['categoria_nombre'] as String?,
      ultimaTiendaNombre: map['ultima_tienda_nombre'] as String?,
      stock: ((map['stock'] as num?) ?? 0).toInt(),
      proximaCaducidad: map['proxima_caducidad'] as String?,
    );
  }

  /// Solo columnas reales de la tabla producto.
  /// ultima_tienda_id no se incluye: la mantiene el trigger de historial_compras.
  Map<String, Object?> toMap() {
    return {
      'id_producto': idProducto,
      'nombre': nombre.trim(),
      'descripcion': (descripcion == null || descripcion!.trim().isEmpty)
          ? null
          : descripcion!.trim(),
      'unidad': unidad,
      'stock_minimo': stockMinimo,
      'dias_aviso': diasAviso,
      'alarma_activa': alarmaActiva ? 1 : 0,
      'hora_alarma': horaAlarma,
      'imagen': imagen,
      'id_categoria': idCategoria,
    };
  }
}
