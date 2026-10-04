class CarritoDAO {
  int? idCarrito;
  int idProducto;
  int cantidad;
  String? fechaAgregado;

  String? productoNombre;
  String? imagen;
  String? unidad;
  String? ultimaTiendaNombre;

  CarritoDAO({
    this.idCarrito,
    required this.idProducto,
    this.cantidad = 1,
    this.fechaAgregado,
    this.productoNombre,
    this.imagen,
    this.unidad,
    this.ultimaTiendaNombre,
  });

  factory CarritoDAO.fromMap(Map<String, dynamic> map) {
    return CarritoDAO(
      idCarrito: map['id_carrito'] as int?,
      idProducto: map['id_producto'] as int,
      cantidad: map['cantidad'] as int,
      fechaAgregado: map['fecha_agregado'] as String?,
      productoNombre: map['producto_nombre'] as String?,
      imagen: map['imagen'] as String?,
      unidad: map['unidad'] as String?,
      ultimaTiendaNombre: map['ultima_tienda_nombre'] as String?,
    );
  }
}
