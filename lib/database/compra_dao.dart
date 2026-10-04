class CompraDAO {
  int? idCompra;
  int idProducto;
  int idTienda;
  int cantidad;
  double precioUnitario;
  String fechaCompra;

  String? tiendaNombre;
  String? productoNombre;

  CompraDAO({
    this.idCompra,
    required this.idProducto,
    required this.idTienda,
    required this.cantidad,
    required this.precioUnitario,
    required this.fechaCompra,
    this.tiendaNombre,
    this.productoNombre,
  });

  double get total => cantidad * precioUnitario;

  factory CompraDAO.fromMap(Map<String, dynamic> map) {
    return CompraDAO(
      idCompra: map['id_compra'] as int?,
      idProducto: map['id_producto'] as int,
      idTienda: map['id_tienda'] as int,
      cantidad: map['cantidad'] as int,
      precioUnitario: ((map['precio_unitario'] as num?) ?? 0).toDouble(),
      fechaCompra: map['fecha_compra'] as String,
      tiendaNombre: map['tienda_nombre'] as String?,
      productoNombre: map['producto_nombre'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id_compra': idCompra,
      'id_producto': idProducto,
      'id_tienda': idTienda,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
      'fecha_compra': fechaCompra,
    };
  }
}
