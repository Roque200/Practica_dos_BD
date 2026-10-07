import 'dart:io';

import 'package:flutter/material.dart';

class ImagenProducto extends StatelessWidget {
  const ImagenProducto({
    super.key,
    required this.ruta,
    this.size = 56,
    this.ancho,
    this.alto,
    this.radio = 12,
    this.heroTag,
  });

  final String? ruta;
  final double size;
  final double? ancho;
  final double? alto;
  final double radio;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final double w = ancho ?? size;
    final double h = alto ?? size;
    final Widget imagen;
    if (ruta != null && File(ruta!).existsSync()) {
      imagen = Image.file(
        File(ruta!),
        width: w,
        height: h,
        fit: BoxFit.cover,
      );
    } else {
      imagen = Container(
        width: w,
        height: h,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.inventory_2_outlined,
          size: size * 0.5,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    final recorte = ClipRRect(
      borderRadius: BorderRadius.circular(radio),
      child: imagen,
    );

    if (heroTag == null) return recorte;
    return Hero(tag: heroTag!, child: recorte);
  }
}
