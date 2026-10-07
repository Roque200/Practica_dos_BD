import 'package:alacena/components/fechas.dart';
import 'package:alacena/database/lote_dao.dart';
import 'package:alacena/database/producto_dao.dart';
import 'package:flutter/material.dart';

/// El orden define la prioridad (el primero es el más urgente)
enum Estatus { caducado, sinExistencia, porCaducar, porAgotarse, ok }

extension EstatusInfo on Estatus {
  String get etiqueta {
    switch (this) {
      case Estatus.caducado:
        return 'Caducado';
      case Estatus.sinExistencia:
        return 'Sin existencia';
      case Estatus.porCaducar:
        return 'Por caducar';
      case Estatus.porAgotarse:
        return 'Por agotarse';
      case Estatus.ok:
        return 'En orden';
    }
  }

  Color get color {
    switch (this) {
      case Estatus.caducado:
        return Colors.red.shade700;
      case Estatus.sinExistencia:
        return Colors.blueGrey.shade600;
      case Estatus.porCaducar:
        return Colors.orange.shade800;
      case Estatus.porAgotarse:
        return Colors.indigo.shade400;
      case Estatus.ok:
        return Colors.green.shade700;
    }
  }

  IconData get icono {
    switch (this) {
      case Estatus.caducado:
        return Icons.dangerous;
      case Estatus.sinExistencia:
        return Icons.remove_shopping_cart;
      case Estatus.porCaducar:
        return Icons.hourglass_bottom;
      case Estatus.porAgotarse:
        return Icons.trending_down;
      case Estatus.ok:
        return Icons.check_circle;
    }
  }
}

class CalculoEstatus {
  static Estatus deProducto(ProductoDAO p) {
    // Agotado: stock total 0 o sin lotes activos
    if (p.stock <= 0) return Estatus.sinExistencia;

    final proxima = p.proximaCaducidad;
    if (proxima != null) {
      final dias = Fechas.diasRestantes(proxima);
      if (dias < 0) return Estatus.caducado;
      if (dias <= p.diasAviso) return Estatus.porCaducar;
    }

    if (p.stock <= p.stockMinimo) return Estatus.porAgotarse;
    return Estatus.ok;
  }

  static Estatus deFecha(String fechaCaducidad, int diasAviso) {
    final dias = Fechas.diasRestantes(fechaCaducidad);
    if (dias < 0) return Estatus.caducado;
    if (dias <= diasAviso) return Estatus.porCaducar;
    return Estatus.ok;
  }

  static Estatus deLote(LoteDAO lote) {
    if (lote.cantidad <= 0) return Estatus.sinExistencia;
    return deFecha(lote.fechaCaducidad, lote.diasAviso);
  }
}

class EtiquetaEstatus extends StatelessWidget {
  const EtiquetaEstatus({super.key, required this.estatus});

  final Estatus estatus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: estatus.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: estatus.color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(estatus.icono, size: 14, color: estatus.color),
          const SizedBox(width: 4),
          Text(
            estatus.etiqueta,
            style: TextStyle(
              color: estatus.color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
