import 'package:flutter/material.dart';

/// Formulario reutilizable para categorías (nombre + descripción)
/// y tiendas (nombre + dirección).
/// Devuelve true si se guardó. Si [guardar] lanza una excepción, el diálogo
/// se queda abierto y muestra el mensaje que regrese [mensajeError].
Future<bool> mostrarFormularioCatalogo({
  required BuildContext context,
  required String titulo,
  required String etiquetaDetalle,
  required Future<void> Function(String nombre, String? detalle) guardar,
  required String Function(Object error) mensajeError,
  String nombreInicial = '',
  String detalleInicial = '',
  int maxNombre = 40,
  int maxDetalle = 120,
}) async {
  final guardado = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _FormularioCatalogo(
      titulo: titulo,
      etiquetaDetalle: etiquetaDetalle,
      guardar: guardar,
      mensajeError: mensajeError,
      nombreInicial: nombreInicial,
      detalleInicial: detalleInicial,
      maxNombre: maxNombre,
      maxDetalle: maxDetalle,
    ),
  );
  return guardado ?? false;
}

class _FormularioCatalogo extends StatefulWidget {
  const _FormularioCatalogo({
    required this.titulo,
    required this.etiquetaDetalle,
    required this.guardar,
    required this.mensajeError,
    required this.nombreInicial,
    required this.detalleInicial,
    required this.maxNombre,
    required this.maxDetalle,
  });

  final String titulo;
  final String etiquetaDetalle;
  final Future<void> Function(String nombre, String? detalle) guardar;
  final String Function(Object error) mensajeError;
  final String nombreInicial;
  final String detalleInicial;
  final int maxNombre;
  final int maxDetalle;

  @override
  State<_FormularioCatalogo> createState() => _FormularioCatalogoState();
}

class _FormularioCatalogoState extends State<_FormularioCatalogo> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre =
      TextEditingController(text: widget.nombreInicial);
  late final TextEditingController _detalle =
      TextEditingController(text: widget.detalleInicial);
  bool _guardando = false;
  String? _errorBD;

  @override
  void dispose() {
    _nombre.dispose();
    _detalle.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _errorBD = null;
    });
    final detalle = _detalle.text.trim();
    try {
      await widget.guardar(_nombre.text.trim(), detalle.isEmpty ? null : detalle);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _errorBD = widget.mensajeError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nombre,
              autofocus: true,
              maxLength: widget.maxNombre,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Escribe un nombre' : null,
            ),
            TextFormField(
              controller: _detalle,
              maxLength: widget.maxDetalle,
              maxLines: 2,
              decoration: InputDecoration(labelText: widget.etiquetaDetalle),
            ),
            if (_errorBD != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _errorBD!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _enviar,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

/// Confirmación antes de borrar. Devuelve true si el usuario acepta.
Future<bool> confirmarEliminar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar')),
      ],
    ),
  );
  return r ?? false;
}

/// Aviso cuando la integridad referencial impide borrar.
Future<void> avisarBloqueo(
  BuildContext context, {
  required String titulo,
  required String mensaje,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        FilledButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
      ],
    ),
  );
}