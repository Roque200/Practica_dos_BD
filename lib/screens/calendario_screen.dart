import 'package:alacena/components/lista_dia.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

/// Calendario de alertas.
///
/// - Cada producto con alerta ese dia dibuja un punto debajo del numero
///   (del color de su estatus, maximo 5 puntos).
/// - Al tocar un dia se abre un modal a pantalla completa con el listado.
class CalendarioScreen extends StatefulWidget {
  const CalendarioScreen({super.key});

  @override
  State<CalendarioScreen> createState() => _CalendarioScreenState();
}

class _CalendarioScreenState extends State<CalendarioScreen> {
  Map<DateTime, List<AlertaDia>> _porDia = {};
  bool _cargando = true;
  String? _error;

  DateTime _enfocado = DateTime.now();
  DateTime? _seleccionado;
  CalendarFormat _formato = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final alertas = await AlertaDia.cargarTodas();
      if (!mounted) return;
      setState(() {
        _porDia = AlertaDia.agruparPorDia(alertas);
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _cargando = false;
      });
    }
  }

  // table_calendar entrega los dias en UTC a medianoche.
  List<AlertaDia> _eventosDe(DateTime dia) {
    return _porDia[DateTime.utc(dia.year, dia.month, dia.day)] ?? const [];
  }

  void _alTocarDia(DateTime seleccionado, DateTime enfocado) {
    setState(() {
      _seleccionado = seleccionado;
      _enfocado = enfocado;
    });
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => DiaAlertasScreen(
          dia: seleccionado,
          alertas: _eventosDe(seleccionado),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text('Calendario de alertas'),
            actions: [
              IconButton(
                tooltip: 'Actualizar',
                icon: const Icon(Icons.refresh),
                onPressed: _cargando ? null : _cargar,
              ),
            ],
          ),
          if (_cargando)
            const SliverToBoxAdapter(child: LinearProgressIndicator()),
          if (_error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No se pudieron cargar las alertas: $_error',
                  style: TextStyle(color: colores.error),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Card(
              margin: const EdgeInsets.all(12),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TableCalendar<AlertaDia>(
                  locale: 'es_MX',
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2035, 12, 31),
                  focusedDay: _enfocado,
                  calendarFormat: _formato,
                  availableCalendarFormats: const {
                    CalendarFormat.month: 'Mes',
                    CalendarFormat.twoWeeks: '2 semanas',
                    CalendarFormat.week: 'Semana',
                  },
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  selectedDayPredicate: (dia) => isSameDay(_seleccionado, dia),
                  eventLoader: _eventosDe,
                  onDaySelected: _alTocarDia,
                  onFormatChanged: (formato) =>
                      setState(() => _formato = formato),
                  onPageChanged: (enfocado) => _enfocado = enfocado,
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: colores.primary.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    todayTextStyle: TextStyle(color: colores.onSurface),
                    selectedDecoration: BoxDecoration(
                      color: colores.primary,
                      shape: BoxShape.circle,
                    ),
                    selectedTextStyle: TextStyle(color: colores.onPrimary),
                  ),
                  calendarBuilders: CalendarBuilders<AlertaDia>(
                    // Un punto por alerta, del color de su estatus.
                    markerBuilder: (context, dia, eventos) {
                      if (eventos.isEmpty) return null;
                      return Positioned(
                        left: 0,
                        right: 0,
                        bottom: 4,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final e in eventos.take(5))
                              Container(
                                width: 6,
                                height: 6,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 1),
                                decoration: BoxDecoration(
                                  color: e.tipo.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  for (final tipo in TipoAlerta.values)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(tipo.icono, size: 16, color: tipo.color),
                        const SizedBox(width: 4),
                        Text(
                          tipo.etiqueta,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Text(
                'Toca un día para ver sus alertas. Los productos agotados o '
                'por agotarse aparecen en el día de hoy.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}