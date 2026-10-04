class LoteDAO {
  int? idLote;
  int idProducto;
  int? idCompra;
  int cantidad;
  String fechaCaducidad;
  String? fechaRegistro;

  // Datos del producto (para listados, calendario y alarmas)
  String? productoNombre;
  String? imagen;
  String? unidad;
  int diasAviso;
  String? categoriaNombre;
  int stockTotal;
  int numLotes;

  LoteDAO({
    this.idLote,
    required this.idProducto,
    this.idCompra,
    required this.cantidad,
    required this.fechaCaducidad,
    this.fechaRegistro,
    this.productoNombre,
    this.imagen,
    this.unidad,
    this.diasAviso = 3,
    this.categoriaNombre,
    this.stockTotal = 0,
    this.numLotes = 1,
  });

  factory LoteDAO.fromMap(Map<String, dynamic> map) {
    return LoteDAO(
      idLote: map['id_lote'] as int?,
      idProducto: map['id_producto'] as int,
      idCompra: map['id_compra'] as int?,
      cantidad: ((map['cantidad'] as num?) ?? 0).toInt(),
      fechaCaducidad: map['fecha_caducidad'] as String,
      fechaRegistro: map['fecha_registro'] as String?,
      productoNombre: map['producto_nombre'] as String?,
      imagen: map['imagen'] as String?,
      unidad: map['unidad'] as String?,
      diasAviso: (map['dias_aviso'] as int?) ?? 3,
      categoriaNombre: map['categoria_nombre'] as String?,
      stockTotal: ((map['stock_total'] as num?) ?? 0).toInt(),
      numLotes: (map['num_lotes'] as int?) ?? 1,
    );
  }
}
