import 'package:alacena/components/db_errores.dart';
import 'package:alacena/components/dialogos_catalogo.dart';
import 'package:alacena/database/alacena_db.dart';
import 'package:alacena/database/tienda_dao.dart';
import 'package:flutter/material.dart';

class TiendasPage extends StatefulWidget {
  const TiendasPage({super.key});

  @override
  State<TiendasPage> createState() => _TiendasPageState();
}

class _TiendasPageState extends State<TiendasPage> {
  final _db = AlacenaDB();
  late Future<List<TiendaDAO>> _futuro = _db.tiendas();

  void _recargar() => setState(() => _futuro = _db.tiendas());

  String _error(Object e) => mensajeErrorBD(e, entidad: 'una tienda');

  Future<void> _abrirFormulario([TiendaDAO? existente]) async {
    final guardado = await mostrarFormularioCatalogo(
      context: context,
      titulo: existente == null ? 'Nueva tienda' : 'Editar tienda',
      etiquetaDetalle: 'Dirección (opcional)',
      nombreInicial: existente?.nombre ?? '',
      detalleInicial: existente?.direccion ?? '',
      mensajeError: _error,
      guardar: (nombre, direccion) async {
        final t = TiendaDAO(
          idTienda: existente?.idTienda,
          nombre: nombre,
          direccion: direccion,
        );
        if (existente == null) {
          await _db.insertar('tienda', t.toMap());
        } else {
          await _db.actualizar('tienda', t.toMap(), 'id_tienda');
        }
      },
    );
    if (guardado) _recargar();
  }

  // historial_compras -> tienda es ON DELETE RESTRICT: con compras no se borra.
  Future<void> _eliminar(TiendaDAO tienda) async {
    final compras = await _db.contarComprasTienda(tienda.idTienda!);
    if (!mounted) return;
    if (compras > 0) {
      await avisarBloqueo(
        context,
        titulo: 'No se puede eliminar',
        mensaje: '"${tienda.nombre}" tiene $compras '
            '${compras == 1 ? 'compra registrada' : 'compras registradas'} '
            'en el historial, y ese historial se conserva.',
      );
      return;
    }
    final acepta = await confirmarEliminar(
      context,
      titulo: 'Eliminar tienda',
      mensaje: '¿Eliminar "${tienda.nombre}"?',
    );
    if (!acepta) return;
    try {
      await _db.eliminar('tienda', 'id_tienda', tienda.idTienda!);
      _recargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_error(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tiendas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva tienda'),
      ),
      body: FutureBuilder<List<TiendaDAO>>(
        future: _futuro,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text(_error(snap.error!)));
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(
                child: Text('Aún no hay tiendas. Agrega la primera.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final t = items[i];
              final n = t.totalCompras;
              return ListTile(
                title: Text(t.nombre),
                subtitle: Text([
                  if (t.direccion != null) t.direccion!,
                  '$n ${n == 1 ? 'compra' : 'compras'}',
                ].join('\n')),
                isThreeLine: t.direccion != null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Editar',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _abrirFormulario(t),
                    ),
                    IconButton(
                      tooltip: 'Eliminar',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _eliminar(t),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}