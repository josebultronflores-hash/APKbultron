import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:learning/animations/loading_pdf_dialog.dart';
import 'package:learning/animations/success_check_dialog.dart';
import 'package:learning/models/documento_viatico.dart';
import 'package:learning/services/documento_storage_service.dart';
import 'package:learning/services/usuario_local_service.dart';

class InformeDiamedScreen extends StatefulWidget {
  final DocumentoViatico? documentoEditar;

  const InformeDiamedScreen({
    super.key,
    this.documentoEditar,
  });

  @override
  State<InformeDiamedScreen> createState() => _InformeDiamedScreenState();
}

class _InformeDiamedScreenState extends State<InformeDiamedScreen> {
  final _formKey = GlobalKey<FormState>();

  late String idDocumentoActual;
  String pdfPathActual = '';
  String? empleadoSeleccionado;

  bool _loadingPdfVisible = false;

  final fechaPreparacionController = TextEditingController();
  final tasaCambioController = TextEditingController();

  final propositoController = TextEditingController();
  final adelantoController = TextEditingController(text: '0.00');
  final reembolsoController = TextEditingController(text: '0.00');
  final otrosPagadosController = TextEditingController(text: '0.00');

  final preparadoPorController = TextEditingController();
  final fechaPreparadoController = TextEditingController();
  final revisadoPorController = TextEditingController();
  final fechaRevisadoController = TextEditingController();

  String codigoMonedaSeleccionada = 'USD';

  final List<MonedaInfo> monedasDisponibles = const [
    MonedaInfo(
      codigo: 'USD',
      nombre: 'Dólar estadounidense',
      simbolo: '\$',
    ),
    MonedaInfo(
      codigo: 'EUR',
      nombre: 'Euro',
      simbolo: '€',
    ),
    MonedaInfo(
      codigo: 'GBP',
      nombre: 'Libra esterlina',
      simbolo: '£',
    ),
    MonedaInfo(
      codigo: 'MXN',
      nombre: 'Peso mexicano',
      simbolo: '\$',
    ),
    MonedaInfo(
      codigo: 'COP',
      nombre: 'Peso colombiano',
      simbolo: '\$',
    ),
    MonedaInfo(
      codigo: 'CRC',
      nombre: 'Colón costarricense',
      simbolo: '₡',
    ),
    MonedaInfo(
      codigo: 'DOP',
      nombre: 'Peso dominicano',
      simbolo: 'RD\$',
    ),
    MonedaInfo(
      codigo: 'PEN',
      nombre: 'Sol peruano',
      simbolo: 'S/',
    ),
    MonedaInfo(
      codigo: 'CLP',
      nombre: 'Peso chileno',
      simbolo: '\$',
    ),
    MonedaInfo(
      codigo: 'ARS',
      nombre: 'Peso argentino',
      simbolo: '\$',
    ),
    MonedaInfo(
      codigo: 'BRL',
      nombre: 'Real brasileño',
      simbolo: 'R\$',
    ),
  ];

  MonedaInfo get monedaActual {
    return monedasDisponibles.firstWhere(
      (moneda) => moneda.codigo == codigoMonedaSeleccionada,
    );
  }

  bool get requiereTasaCambio {
    return codigoMonedaSeleccionada != 'USD';
  }

  final List<String> diasLargos = [
    'Domingo',
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
  ];

  final List<String> diasCortos = [
    'Dom',
    'Lun',
    'Mar',
    'Mié',
    'Jue',
    'Vie',
    'Sáb',
  ];

  late final List<TextEditingController> fechaDiaControllers;
  late final List<TextEditingController> lugarDiaControllers;

  DateTime? fechaInicioGira;
  DateTime? fechaFinGira;

  List<bool> diasHabilitados = [
    false,
    false,
    false,
    false,
    false,
    false,
    false,
  ];

  bool get rangoFechasSeleccionado {
    return fechaInicioGira != null && fechaFinGira != null;
  }

  bool _diaHabilitado(int index) {
    return rangoFechasSeleccionado && diasHabilitados[index];
  }

  late final List<FilaGasto> transporteRows;
  late final List<FilaGasto> hotelRows;
  late final List<FilaGasto> miscelaneosRows;

  final List<DetalleGasto> detalles = [];

  @override
  void initState() {
    super.initState();

    idDocumentoActual = widget.documentoEditar?.id ??
        'informe_diamed_${DateTime.now().millisecondsSinceEpoch}';

    pdfPathActual = widget.documentoEditar?.pdfPath ?? '';

    final hoy = DateFormat('dd/MM/yyyy').format(DateTime.now());
    fechaPreparacionController.text = hoy;
    fechaPreparadoController.text = hoy;

    fechaDiaControllers = List.generate(7, (_) => TextEditingController());
    lugarDiaControllers = List.generate(7, (_) => TextEditingController());

    transporteRows = [
      FilaGasto('Transporte y/o combustible'),
      FilaGasto('Estacionamiento y peaje'),
      FilaGasto('Taxi'),
    ];

    hotelRows = [
      FilaGasto('Hospedaje'),
      FilaGasto('Desayuno'),
      FilaGasto('Almuerzo'),
      FilaGasto('Cena'),
    ];

    miscelaneosRows = [
      FilaGasto('Propina'),
      FilaGasto('Agua'),
      FilaGasto('Herramientas'),
      FilaGasto('Atención al cliente'),
    ];

    detalles.add(DetalleGasto());

    if (widget.documentoEditar != null) {
      _cargarDatosInformeDiamed(widget.documentoEditar!.datosFormulario);
    }

    cargarUsuarioLocal();
  }

  Future<void> cargarUsuarioLocal() async {
    final nombre = await UsuarioLocalService.obtenerNombreUsuario();

    if (!mounted) return;

    final nombreLimpio = nombre?.trim() ?? '';

    if (nombreLimpio.isEmpty) return;

    setState(() {
      empleadoSeleccionado = nombreLimpio;
      preparadoPorController.text = nombreLimpio;
    });
  }

  void _mostrarLoadingPdfSeguro() {
    if (_loadingPdfVisible) return;

    _loadingPdfVisible = true;
    mostrarLoadingPdf(context);
  }

  void _cerrarLoadingPdfSeguro() {
    if (!_loadingPdfVisible) return;
    if (!mounted) return;

    Navigator.of(context, rootNavigator: true).pop();
    _loadingPdfVisible = false;
  }

  @override
  void dispose() {
    fechaPreparacionController.dispose();
    tasaCambioController.dispose();
    propositoController.dispose();
    adelantoController.dispose();
    reembolsoController.dispose();
    otrosPagadosController.dispose();
    preparadoPorController.dispose();
    fechaPreparadoController.dispose();
    revisadoPorController.dispose();
    fechaRevisadoController.dispose();

    for (final controller in fechaDiaControllers) {
      controller.dispose();
    }

    for (final controller in lugarDiaControllers) {
      controller.dispose();
    }

    for (final row in transporteRows) {
      row.dispose();
    }

    for (final row in hotelRows) {
      row.dispose();
    }

    for (final row in miscelaneosRows) {
      row.dispose();
    }

    for (final detalle in detalles) {
      detalle.dispose();
    }

    super.dispose();
  }

  double _toDouble(String value) {
    return double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
  }

  bool _esMontoCero(String value) {
    return _toDouble(value).abs() < 0.005;
  }

  void _limpiarMontoSiEsCero(TextEditingController controller) {
    if (_esMontoCero(controller.text)) {
      controller.clear();
    }
  }

  double _montoConvertidoADolares(double monto) {
    if (!requiereTasaCambio) {
      return monto;
    }

    final double tasaCambio = _toDouble(tasaCambioController.text);

    if (tasaCambio <= 0) {
      return 0.0;
    }

    return monto / tasaCambio;
  }

  bool _tasaCambioValida() {
    if (!requiereTasaCambio) {
      return true;
    }

    return _toDouble(tasaCambioController.text) > 0;
  }

  void _convertirCeldaGastoADolares(
    FilaGasto row,
    int dayIndex,
  ) {
    if (!requiereTasaCambio) {
      row.convertidoADolares[dayIndex] = true;
      setState(() {});
      return;
    }

    if (row.convertidoADolares[dayIndex]) {
      return;
    }

    if (!_tasaCambioValida()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingrese una tasa de cambio válida antes de convertir'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final TextEditingController controller = row.controllers[dayIndex];
    final double montoLocal = _toDouble(controller.text);

    if (montoLocal <= 0) {
      controller.text = '0.00';
      row.convertidoADolares[dayIndex] = true;
      setState(() {});
      return;
    }

    final double montoUsd = _montoConvertidoADolares(montoLocal);
    final String montoConvertido = _money(montoUsd);

    controller.value = TextEditingValue(
      text: montoConvertido,
      selection: TextSelection.collapsed(offset: montoConvertido.length),
    );

    row.convertidoADolares[dayIndex] = true;
    setState(() {});
  }

  void _convertirDetalleGastoADolares(DetalleGasto detalle) {
    if (!requiereTasaCambio) {
      detalle.montoConvertidoADolares = true;
      setState(() {});
      return;
    }

    if (detalle.montoConvertidoADolares) {
      return;
    }

    if (!_tasaCambioValida()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingrese una tasa de cambio válida antes de convertir'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final double montoLocal = _toDouble(detalle.montoController.text);

    if (montoLocal <= 0) {
      detalle.montoController.text = '0.00';
      detalle.montoConvertidoADolares = true;
      setState(() {});
      return;
    }

    final double montoUsd = _montoConvertidoADolares(montoLocal);
    final String montoConvertido = _money(montoUsd);

    detalle.montoController.value = TextEditingValue(
      text: montoConvertido,
      selection: TextSelection.collapsed(offset: montoConvertido.length),
    );

    detalle.montoConvertidoADolares = true;
    setState(() {});
  }

  void _convertirMontosPendientesADolares() {
    if (!requiereTasaCambio || !_tasaCambioValida()) {
      return;
    }

    for (final row in [
      ...transporteRows,
      ...hotelRows,
      ...miscelaneosRows,
    ]) {
      for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
        if (_diaHabilitado(dayIndex) && !row.convertidoADolares[dayIndex]) {
          final double montoLocal = _toDouble(row.controllers[dayIndex].text);
          final double montoUsd = _montoConvertidoADolares(montoLocal);
          row.controllers[dayIndex].text = _money(montoUsd);
          row.convertidoADolares[dayIndex] = true;
        }
      }
    }

    for (final detalle in detalles) {
      if (!detalle.montoConvertidoADolares) {
        final double montoLocal = _toDouble(detalle.montoController.text);
        final double montoUsd = _montoConvertidoADolares(montoLocal);
        detalle.montoController.text = _money(montoUsd);
        detalle.montoConvertidoADolares = true;
      }
    }

    setState(() {});
  }

  String _textoTasaCambioPdf() {
    final textoTasa = tasaCambioController.text.trim();

    if (!requiereTasaCambio && textoTasa.isEmpty) {
      return '';
    }

    if (textoTasa.isEmpty) {
      return '';
    }

    return '${monedaActual.codigo} $textoTasa';
  }

  String _money(double value) {
    return value.toStringAsFixed(2);
  }

  String _moneyPdf(double value) {
    if (value.abs() < 0.005) {
      return '';
    }

    return value.toStringAsFixed(2);
  }

  double _valorDiaValido(FilaGasto row, int dayIndex) {
    if (!_diaHabilitado(dayIndex)) {
      return 0.0;
    }

    return row.valorDia(dayIndex);
  }

  double _totalFilaValida(FilaGasto row) {
    return List.generate(7, (index) {
      return _valorDiaValido(row, index);
    }).fold(0.0, (sum, value) => sum + value);
  }

  double _totalRows(List<FilaGasto> rows) {
    return rows.fold(0.0, (sum, row) {
      return sum + _totalFilaValida(row);
    });
  }

  double get totalTransporte => _totalRows(transporteRows);
  double get totalHotel => _totalRows(hotelRows);
  double get totalMiscelaneos => _totalRows(miscelaneosRows);

  double get totalDetalleGastos {
    return detalles.fold(0.0, (sum, detalle) {
      return sum + _toDouble(detalle.montoController.text);
    });
  }

  double get totalGastos =>
      totalTransporte + totalHotel + totalMiscelaneos + totalDetalleGastos;

  double get adelanto => _toDouble(adelantoController.text);

  double get reembolso {
    final diferencia = adelanto - totalGastos;
    return diferencia > 0 ? diferencia : 0.0;
  }

  double get montoPorPagar {
    final diferencia = totalGastos - adelanto;
    return diferencia > 0 ? diferencia : 0.0;
  }

  double get otrosPagados {
    return _montoConvertidoADolares(
      _toDouble(otrosPagadosController.text),
    );
  }

  double get granTotal => totalGastos + otrosPagados;

  Future<void> _seleccionarMoneda() async {
    final MonedaInfo? monedaElegida = await showDialog<MonedaInfo>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Seleccione la moneda'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: monedasDisponibles.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final moneda = monedasDisponibles[index];

                return ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      moneda.simbolo,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text('${moneda.codigo} - ${moneda.nombre}'),
                  trailing: moneda.codigo == codigoMonedaSeleccionada
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () {
                    Navigator.of(dialogContext).pop(moneda);
                  },
                );
              },
            ),
          ),
        );
      },
    );

    if (monedaElegida == null) {
      return;
    }

    setState(() {
      codigoMonedaSeleccionada = monedaElegida.codigo;

      if (!requiereTasaCambio) {
        tasaCambioController.clear();
      }
    });
  }

  Future<void> _seleccionarFecha(TextEditingController controller) async {
    final DateTime? fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (fechaSeleccionada != null) {
      controller.text = DateFormat('dd/MM/yyyy').format(fechaSeleccionada);
      setState(() {});
    }
  }

  DateTime _fechaSinHora(DateTime fecha) {
    return DateTime(fecha.year, fecha.month, fecha.day);
  }

  DateTime _inicioSemanaDomingo(DateTime fecha) {
    final fechaLimpia = _fechaSinHora(fecha);
    return fechaLimpia.subtract(Duration(days: fechaLimpia.weekday % 7));
  }

  bool _mismoInicioSemana(DateTime inicio, DateTime fin) {
    final semanaInicio = _inicioSemanaDomingo(inicio);
    final semanaFin = _inicioSemanaDomingo(fin);

    return semanaInicio.year == semanaFin.year &&
        semanaInicio.month == semanaFin.month &&
        semanaInicio.day == semanaFin.day;
  }

  int _indiceDiaSemana(DateTime fecha) {
    return fecha.weekday % 7;
  }

  Future<void> _seleccionarRangoFechasGira() async {
    final DateTimeRange? rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: rangoFechasSeleccionado
          ? DateTimeRange(
              start: fechaInicioGira!,
              end: fechaFinGira!,
            )
          : null,
      helpText: 'Seleccione el rango de fechas de la gira',
      cancelText: 'Cancelar',
      saveText: 'OK',
    );

    if (rango == null) {
      return;
    }

    final DateTime inicio = _fechaSinHora(rango.start);
    final DateTime fin = _fechaSinHora(rango.end);

    if (!_mismoInicioSemana(inicio, fin)) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El rango debe estar dentro de la misma semana del formulario.',
          ),
          backgroundColor: Colors.orange,
        ),
      );

      return;
    }

    setState(() {
      fechaInicioGira = inicio;
      fechaFinGira = fin;

      diasHabilitados = List.generate(7, (_) => false);

      for (final controller in fechaDiaControllers) {
        controller.clear();
      }

      DateTime fechaActual = inicio;

      while (!fechaActual.isAfter(fin)) {
        final int indexDia = _indiceDiaSemana(fechaActual);

        diasHabilitados[indexDia] = true;

        fechaDiaControllers[indexDia].text =
            DateFormat('dd/MM/yyyy').format(fechaActual);

        fechaActual = fechaActual.add(const Duration(days: 1));
      }
    });
  }

  Future<void> _seleccionarFechaDetalle(
    TextEditingController controller,
  ) async {
    if (!rangoFechasSeleccionado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero seleccione el rango de fechas de la gira'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final DateTime? fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: fechaInicioGira!,
      firstDate: fechaInicioGira!,
      lastDate: fechaFinGira!,
      helpText: 'Seleccione fecha del gasto',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );

    if (fechaSeleccionada != null) {
      controller.text = DateFormat('dd/MM/yyyy').format(fechaSeleccionada);
      setState(() {});
    }
  }

  Future<void> _agregarMiscelaneo() async {
    String nombreMiscelaneo = '';

    final String? nuevoNombre = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Agregar misceláneo'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nombre del gasto',
              hintText: 'Ejemplo: Lavandería, Papelería, Agua',
              border: OutlineInputBorder(),
            ),
            onChanged: (String value) {
              nombreMiscelaneo = value.trim();
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(nombreMiscelaneo);
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );

    if (nuevoNombre == null || nuevoNombre.isEmpty) {
      return;
    }

    setState(() {
      miscelaneosRows.add(FilaGasto(nuevoNombre));
    });
  }

  void _eliminarMiscelaneo(int index) {
    if (index < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta fila base no se puede eliminar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      miscelaneosRows[index].dispose();
      miscelaneosRows.removeAt(index);
    });
  }

  void _agregarDetalle() {
    setState(() {
      detalles.add(DetalleGasto());
    });
  }

  void _eliminarDetalle(int index) {
    if (detalles.length == 1) return;

    setState(() {
      detalles[index].dispose();
      detalles.removeAt(index);
    });
  }

  Map<String, dynamic> _obtenerDatosInformeDiamed() {
    return {
      'empleado': preparadoPorController.text.trim(),
      'fechaPreparacion': fechaPreparacionController.text,
      'codigoMoneda': codigoMonedaSeleccionada,
      'tasaCambio': tasaCambioController.text,
      'fechaInicioGira': fechaInicioGira?.toIso8601String(),
      'fechaFinGira': fechaFinGira?.toIso8601String(),
      'diasHabilitados': diasHabilitados,
      'fechasDias': fechaDiaControllers.map((controller) => controller.text).toList(),
      'lugaresDias': lugarDiaControllers.map((controller) => controller.text).toList(),
      'transporte': transporteRows.map((row) {
        return {
          'nombre': row.nombre,
          'valores': row.controllers.map((controller) => controller.text).toList(),
          'convertidoADolares': row.convertidoADolares,
        };
      }).toList(),
      'hotel': hotelRows.map((row) {
        return {
          'nombre': row.nombre,
          'valores': row.controllers.map((controller) => controller.text).toList(),
          'convertidoADolares': row.convertidoADolares,
        };
      }).toList(),
      'miscelaneos': miscelaneosRows.map((row) {
        return {
          'nombre': row.nombre,
          'valores': row.controllers.map((controller) => controller.text).toList(),
          'convertidoADolares': row.convertidoADolares,
        };
      }).toList(),
      'detalles': detalles.map((detalle) {
        return {
          'fecha': detalle.fechaController.text,
          'detalle': detalle.detalleController.text,
          'lugar': detalle.lugarController.text,
          'monto': detalle.montoController.text,
          'montoConvertidoADolares': detalle.montoConvertidoADolares,
        };
      }).toList(),
      'proposito': propositoController.text,
      'adelanto': adelantoController.text,
      'reembolso': reembolso.toStringAsFixed(2),
      'montoPorPagar': montoPorPagar.toStringAsFixed(2),
      'otrosPagados': otrosPagadosController.text,
      'totalGastos': totalGastos.toStringAsFixed(2),
      'granTotal': granTotal.toStringAsFixed(2),
      'preparadoPor': preparadoPorController.text.trim(),
      'fechaPreparado': fechaPreparadoController.text,
      'revisadoPor': revisadoPorController.text,
      'fechaRevisado': fechaRevisadoController.text,
    };
  }

  void _cargarDatosInformeDiamed(Map<String, dynamic> datos) {
    empleadoSeleccionado = datos['empleado'] as String?;

    fechaPreparacionController.text =
        (datos['fechaPreparacion'] ?? '').toString();

    codigoMonedaSeleccionada = (datos['codigoMoneda'] ?? 'USD').toString();

    tasaCambioController.text = (datos['tasaCambio'] ?? '').toString();

    propositoController.text = (datos['proposito'] ?? '').toString();

    adelantoController.text = (datos['adelanto'] ?? '0.00').toString();

    otrosPagadosController.text = (datos['otrosPagados'] ?? '0.00').toString();

    preparadoPorController.text =
        (datos['preparadoPor'] ?? empleadoSeleccionado ?? '').toString();

    fechaPreparadoController.text =
        (datos['fechaPreparado'] ?? fechaPreparadoController.text).toString();

    revisadoPorController.text = (datos['revisadoPor'] ?? '').toString();

    fechaRevisadoController.text = (datos['fechaRevisado'] ?? '').toString();

    final fechaInicioTexto = datos['fechaInicioGira'];
    final fechaFinTexto = datos['fechaFinGira'];

    fechaInicioGira = fechaInicioTexto == null
        ? null
        : DateTime.tryParse(fechaInicioTexto.toString());

    fechaFinGira = fechaFinTexto == null
        ? null
        : DateTime.tryParse(fechaFinTexto.toString());

    final diasGuardados = datos['diasHabilitados'];
    if (diasGuardados is List) {
      diasHabilitados = List.generate(
        7,
        (index) => index < diasGuardados.length
            ? diasGuardados[index] == true
            : false,
      );
    }

    final fechasDias = datos['fechasDias'];
    if (fechasDias is List) {
      for (int i = 0;
          i < fechaDiaControllers.length && i < fechasDias.length;
          i++) {
        fechaDiaControllers[i].text = (fechasDias[i] ?? '').toString();
      }
    }

    final lugaresDias = datos['lugaresDias'];
    if (lugaresDias is List) {
      for (int i = 0;
          i < lugarDiaControllers.length && i < lugaresDias.length;
          i++) {
        lugarDiaControllers[i].text = (lugaresDias[i] ?? '').toString();
      }
    }

    _cargarFilasGasto(transporteRows, datos['transporte']);
    _cargarFilasGasto(hotelRows, datos['hotel']);
    _cargarMiscelaneos(datos['miscelaneos']);
    _cargarDetalles(datos['detalles']);

    setState(() {});
  }

  void _cargarFilasGasto(
    List<FilaGasto> filas,
    dynamic filasGuardadas,
  ) {
    if (filasGuardadas is! List) return;

    for (int i = 0; i < filas.length && i < filasGuardadas.length; i++) {
      final filaGuardada = filasGuardadas[i];
      if (filaGuardada is! Map) continue;

      final valores = filaGuardada['valores'];
      if (valores is List) {
        for (int j = 0;
            j < filas[i].controllers.length && j < valores.length;
            j++) {
          filas[i].controllers[j].text = (valores[j] ?? '0.00').toString();
        }
      }

      final convertido = filaGuardada['convertidoADolares'];
      if (convertido is List) {
        for (int j = 0;
            j < filas[i].convertidoADolares.length && j < convertido.length;
            j++) {
          filas[i].convertidoADolares[j] = convertido[j] == true;
        }
      }
    }
  }

  void _cargarMiscelaneos(dynamic filasGuardadas) {
    if (filasGuardadas is! List) return;

    for (final row in miscelaneosRows) {
      row.dispose();
    }

    miscelaneosRows.clear();

    for (final filaGuardada in filasGuardadas) {
      if (filaGuardada is! Map) continue;

      final fila = FilaGasto(
        (filaGuardada['nombre'] ?? 'Misceláneo').toString(),
      );

      final valores = filaGuardada['valores'];
      if (valores is List) {
        for (int j = 0; j < fila.controllers.length && j < valores.length; j++) {
          fila.controllers[j].text = (valores[j] ?? '0.00').toString();
        }
      }

      final convertido = filaGuardada['convertidoADolares'];
      if (convertido is List) {
        for (int j = 0;
            j < fila.convertidoADolares.length && j < convertido.length;
            j++) {
          fila.convertidoADolares[j] = convertido[j] == true;
        }
      }

      miscelaneosRows.add(fila);
    }

    if (miscelaneosRows.isEmpty) {
      miscelaneosRows.addAll([
        FilaGasto('Propina'),
        FilaGasto('Agua'),
        FilaGasto('Herramientas'),
        FilaGasto('Atención al cliente'),
      ]);
    }
  }

  void _cargarDetalles(dynamic detallesGuardados) {
    if (detallesGuardados is! List) return;

    for (final detalle in detalles) {
      detalle.dispose();
    }

    detalles.clear();

    for (final detalleGuardado in detallesGuardados) {
      if (detalleGuardado is! Map) continue;

      final detalle = DetalleGasto();

      detalle.fechaController.text = (detalleGuardado['fecha'] ?? '').toString();
      detalle.detalleController.text =
          (detalleGuardado['detalle'] ?? '').toString();
      detalle.lugarController.text = (detalleGuardado['lugar'] ?? '').toString();
      detalle.montoController.text =
          (detalleGuardado['monto'] ?? '0.00').toString();

      detalle.montoConvertidoADolares =
          detalleGuardado['montoConvertidoADolares'] == true;

      detalles.add(detalle);
    }

    if (detalles.isEmpty) {
      detalles.add(DetalleGasto());
    }
  }

  bool _validarDatosMinimos() {
    final preparadoPor = preparadoPorController.text.trim();

    if (preparadoPor.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe registrar un usuario primero'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    if (fechaPreparacionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccione la fecha de preparación'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    return true;
  }

  Future<void> _guardarInformeDiamed({
    String pdfPath = '',
    bool mostrarMensaje = true,
  }) async {
    if (!_validarDatosMinimos()) return;

    final ahora = DateTime.now();
    final pdfPathFinal = pdfPath.isNotEmpty ? pdfPath : pdfPathActual;

    final documento = DocumentoViatico(
      id: idDocumentoActual,
      empresa: 'Diamed',
      tipo: 'Informe',
      nombre: preparadoPorController.text.trim(),
      fecha: fechaPreparacionController.text,
      destino: fechaInicioGira == null || fechaFinGira == null
          ? 'Sin rango de gira'
          : '${DateFormat('dd/MM/yyyy').format(fechaInicioGira!)} - ${DateFormat('dd/MM/yyyy').format(fechaFinGira!)}',
      pdfPath: pdfPathFinal,
      datosFormulario: _obtenerDatosInformeDiamed(),
      creadoEn: widget.documentoEditar?.creadoEn ?? ahora,
      actualizadoEn: ahora,
    );

    await DocumentoStorageService.instance.guardarDocumento(documento);
    pdfPathActual = pdfPathFinal;

    if (!mounted || !mostrarMensaje) return;
  }

  Future<Uint8List> _crearPdfInformeDiamed() async {
    final ByteData plantillaData = await rootBundle.load(
      'assets/templates/informe_diamed_template.png',
    );

    final Uint8List plantillaBytes = plantillaData.buffer.asUint8List();
    final plantillaImagen = pw.MemoryImage(plantillaBytes);

    final pdf = pw.Document();

    final empleado = preparadoPorController.text.trim().isEmpty
        ? (empleadoSeleccionado ?? '')
        : preparadoPorController.text.trim();

    final List<double> dayMoneyX = [
      196,
      237,
      293,
      361,
      422,
      463,
      504,
    ];

    final List<double> dayDateX = [
      176,
      235,
      278,
      336,
      402,
      461,
      502,
    ];

    final List<double> dayDateWidth = [
      52,
      36,
      48,
      56,
      52,
      36,
      36,
    ];

    pw.Widget textoPdf(
      String texto,
      double left,
      double top, {
      double fontSize = 6.5,
      double width = 80,
      bool bold = false,
      pw.TextAlign align = pw.TextAlign.left,
      int maxLines = 1,
    }) {
      return pw.Positioned(
        left: left,
        top: top,
        child: pw.SizedBox(
          width: width,
          child: pw.Text(
            texto,
            textAlign: align,
            maxLines: maxLines,
            overflow: pw.TextOverflow.clip,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
      );
    }

    void agregarFilaGasto({
      required List<pw.Widget> widgets,
      required FilaGasto fila,
      required double top,
    }) {
      for (int i = 0; i < 7; i++) {
        widgets.add(
          textoPdf(
            _moneyPdf(_valorDiaValido(fila, i)),
            dayMoneyX[i],
            top,
            width: 34,
            fontSize: 5.1,
            align: pw.TextAlign.right,
          ),
        );
      }

      widgets.add(
        textoPdf(
          _moneyPdf(_totalFilaValida(fila)),
          544,
          top,
          width: 36,
          fontSize: 5.1,
          align: pw.TextAlign.right,
        ),
      );
    }

    void agregarTotalesPorDia({
      required List<pw.Widget> widgets,
      required List<FilaGasto> filas,
      required double top,
      bool bold = true,
    }) {
      for (int i = 0; i < 7; i++) {
        final totalDia = filas.fold(
          0.0,
          (sum, fila) => sum + _valorDiaValido(fila, i),
        );

        widgets.add(
          textoPdf(
            _moneyPdf(totalDia),
            dayMoneyX[i],
            top,
            width: 34,
            fontSize: 5.1,
            bold: bold,
            align: pw.TextAlign.right,
          ),
        );
      }

      widgets.add(
        textoPdf(
          _moneyPdf(_totalRows(filas)),
          544,
          top,
          width: 36,
          fontSize: 5.1,
          bold: bold,
          align: pw.TextAlign.right,
        ),
      );
    }

    final widgets = <pw.Widget>[
      pw.Positioned.fill(
        child: pw.Image(
          plantillaImagen,
          fit: pw.BoxFit.cover,
        ),
      ),
      textoPdf(
        empleado,
        176,
        105,
        width: 100,
        fontSize: 6.2,
      ),
      textoPdf(
        _textoTasaCambioPdf(),
        176,
        121,
        width: 70,
        fontSize: 6.2,
      ),
      textoPdf(
        fechaPreparacionController.text,
        461,
        121,
        width: 80,
        fontSize: 6.2,
      ),
    ];

    for (int i = 0; i < 7; i++) {
      widgets.add(
        textoPdf(
          _diaHabilitado(i) ? fechaDiaControllers[i].text : '',
          dayDateX[i],
          147,
          width: dayDateWidth[i],
          fontSize: 4.8,
          align: pw.TextAlign.center,
        ),
      );

      widgets.add(
        textoPdf(
          _diaHabilitado(i) ? lugarDiaControllers[i].text : '',
          dayDateX[i],
          158,
          width: dayDateWidth[i],
          fontSize: 4.8,
          align: pw.TextAlign.center,
        ),
      );
    }

    agregarFilaGasto(
      widgets: widgets,
      fila: transporteRows[0],
      top: 188,
    );

    agregarFilaGasto(
      widgets: widgets,
      fila: transporteRows[1],
      top: 198.5,
    );

    agregarFilaGasto(
      widgets: widgets,
      fila: transporteRows[2],
      top: 209,
    );

    agregarTotalesPorDia(
      widgets: widgets,
      filas: transporteRows,
      top: 220,
    );

    agregarFilaGasto(
      widgets: widgets,
      fila: hotelRows[0],
      top: 249,
    );

    agregarFilaGasto(
      widgets: widgets,
      fila: hotelRows[1],
      top: 260,
    );

    agregarFilaGasto(
      widgets: widgets,
      fila: hotelRows[2],
      top: 271,
    );

    agregarFilaGasto(
      widgets: widgets,
      fila: hotelRows[3],
      top: 282,
    );

    agregarTotalesPorDia(
      widgets: widgets,
      filas: hotelRows,
      top: 292.5,
    );

    if (miscelaneosRows.isNotEmpty) {
      agregarFilaGasto(
        widgets: widgets,
        fila: miscelaneosRows[0],
        top: 321,
      );
    }

    if (miscelaneosRows.length > 1) {
      agregarFilaGasto(
        widgets: widgets,
        fila: miscelaneosRows[1],
        top: 331,
      );
    }

    if (miscelaneosRows.length > 2) {
      agregarFilaGasto(
        widgets: widgets,
        fila: miscelaneosRows[2],
        top: 341,
      );
    }

    if (miscelaneosRows.length > 3) {
      agregarFilaGasto(
        widgets: widgets,
        fila: miscelaneosRows[3],
        top: 351,
      );
    }

    agregarTotalesPorDia(
      widgets: widgets,
      filas: miscelaneosRows,
      top: 379,
    );

    agregarTotalesPorDia(
      widgets: widgets,
      filas: [
        ...transporteRows,
        ...hotelRows,
        ...miscelaneosRows,
      ],
      top: 402,
    );

    for (int i = 0; i < detalles.length && i < 8; i++) {
      final detalle = detalles[i];
      final top = 441 + (i * 8.5);

      widgets.add(
        textoPdf(
          detalle.fechaController.text,
          24,
          top,
          width: 46,
          fontSize: 4.6,
          align: pw.TextAlign.center,
        ),
      );

      widgets.add(
        textoPdf(
          detalle.detalleController.text,
          84,
          top,
          width: 237,
          fontSize: 4.5,
        ),
      );

      widgets.add(
        textoPdf(
          detalle.lugarController.text,
          334,
          top,
          width: 160,
          fontSize: 4.5,
        ),
      );

      widgets.add(
        textoPdf(
          _moneyPdf(
            _toDouble(detalle.montoController.text),
          ),
          544,
          top,
          width: 36,
          fontSize: 4.5,
          align: pw.TextAlign.right,
        ),
      );
    }

    widgets.add(
      pw.Positioned(
        left: 39,
        top: 552,
        child: pw.SizedBox(
          width: 286,
          height: 38,
          child: pw.Text(
            propositoController.text,
            maxLines: 4,
            overflow: pw.TextOverflow.clip,
            style: const pw.TextStyle(
              fontSize: 5.0,
              lineSpacing: 5.2,
            ),
          ),
        ),
      ),
    );

    widgets.addAll([
      textoPdf(
        _moneyPdf(adelanto),
        544,
        541,
        width: 36,
        fontSize: 5.1,
        align: pw.TextAlign.right,
      ),
      textoPdf(
        _moneyPdf(totalGastos),
        544,
        552,
        width: 36,
        fontSize: 5.1,
        align: pw.TextAlign.right,
      ),
      textoPdf(
        _moneyPdf(reembolso),
        544,
        573,
        width: 36,
        fontSize: 5.1,
        align: pw.TextAlign.right,
      ),
      textoPdf(
        _moneyPdf(montoPorPagar),
        544,
        584,
        width: 36,
        fontSize: 5.1,
        align: pw.TextAlign.right,
      ),
    ]);

    widgets.addAll([
      textoPdf(
        _moneyPdf(totalGastos),
        544,
        681,
        width: 36,
        fontSize: 5.1,
        bold: true,
        align: pw.TextAlign.right,
      ),
      textoPdf(
        _moneyPdf(granTotal),
        544,
        692,
        width: 36,
        fontSize: 5.1,
        bold: true,
        align: pw.TextAlign.right,
      ),
    ]);

    widgets.addAll([
      textoPdf(
        preparadoPorController.text.isEmpty ? empleado : preparadoPorController.text,
        66,
        710,
        width: 70,
        fontSize: 6.4,
        align: pw.TextAlign.center,
      ),
      textoPdf(
        revisadoPorController.text,
        242,
        710,
        width: 80,
        fontSize: 6.4,
        align: pw.TextAlign.center,
      ),
    ]);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) {
          return pw.Stack(
            children: widgets,
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<void> _generarPdfPendiente() async {
    if (!_validarDatosMinimos()) return;

    final formularioValido = _formKey.currentState?.validate() ?? false;

    if (!rangoFechasSeleccionado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero seleccione el rango de fechas de la gira'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_tasaCambioValida()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingrese una tasa de cambio válida'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _convertirMontosPendientesADolares();

    if (!formularioValido) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete los campos obligatorios'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _mostrarLoadingPdfSeguro();

    try {
      final Uint8List pdfBytes = await _crearPdfInformeDiamed();

      final Directory directory = await getApplicationDocumentsDirectory();

      final String nombreArchivo =
          'informe_diamed_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final File archivoPdf = File('${directory.path}/$nombreArchivo');

      await archivoPdf.writeAsBytes(pdfBytes);

      await _guardarInformeDiamed(
        pdfPath: archivoPdf.path,
        mostrarMensaje: false,
      );

      if (!mounted) return;

      _cerrarLoadingPdfSeguro();

      await Future.delayed(const Duration(milliseconds: 250));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF guardado correctamente: $nombreArchivo'),
          backgroundColor: Colors.green,
        ),
      );

      await OpenFilex.open(archivoPdf.path);
    } catch (e) {
      _cerrarLoadingPdfSeguro();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _vistaPreviaPendiente() async {
    if (!_validarDatosMinimos()) return;

    final formularioValido = _formKey.currentState?.validate() ?? false;

    if (!rangoFechasSeleccionado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero seleccione el rango de fechas de la gira'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_tasaCambioValida()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingrese una tasa de cambio válida'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _convertirMontosPendientesADolares();

    if (!formularioValido) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete los campos obligatorios'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final Uint8List pdfBytes = await _crearPdfInformeDiamed();

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error en vista previa: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _campoTexto({
    required String label,
    required TextEditingController controller,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
    String? hintText,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: icon == null ? null : Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _campoFecha({
    required String label,
    required TextEditingController controller,
  }) {
    return _campoTexto(
      label: label,
      controller: controller,
      icon: Icons.calendar_month,
      readOnly: true,
      onTap: () => _seleccionarFecha(controller),
    );
  }

  Widget _sectionCard({
    required String titulo,
    required IconData icono,
    required Color color,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Icon(icono, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _campoTasaCambio() {
    return TextFormField(
      controller: tasaCambioController,
      readOnly: !requiereTasaCambio,
      keyboardType: TextInputType.number,
      onChanged: (_) => setState(() {}),
      validator: (_) {
        if (requiereTasaCambio && !_tasaCambioValida()) {
          return 'Ingrese una tasa válida';
        }

        return null;
      },
      decoration: InputDecoration(
        labelText: requiereTasaCambio
            ? 'Tasa de cambio (${monedaActual.codigo} → USD)'
            : 'Tasa de cambio',
        hintText: requiereTasaCambio ? 'Ejemplo: 17.80' : 'No requerida para USD',
        helperText: requiereTasaCambio
            ? 'Indique cuántos ${monedaActual.codigo} equivalen a 1 USD'
            : 'Toque el símbolo para cambiar la moneda',
        prefixIcon: IconButton(
          tooltip: 'Cambiar moneda',
          onPressed: _seleccionarMoneda,
          icon: Text(
            monedaActual.simbolo,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        suffixText: monedaActual.codigo,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: requiereTasaCambio ? Colors.white : Colors.grey.shade100,
      ),
    );
  }

  Widget _tablaSemanaGira() {
  const double anchoColumnaFija = 92;
  const double anchoDia = 100;
  const double altoEncabezado = 34;
  const double altoFilaFecha = 50;
  const double altoFilaLugar = 52;
  const double fontSizeTabla = 14;

  Widget celdaFija({
    required Widget child,
    required double height,
    Color? color,
    Alignment alignment = Alignment.centerLeft,
  }) {
    return Container(
      width: anchoColumnaFija,
      height: height,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.black12),
      ),
      child: child,
    );
  }

  Widget celdaDia({
    required Widget child,
    required double height,
    Color? color,
    Alignment alignment = Alignment.center,
  }) {
    return Container(
      width: anchoDia,
      height: height,
      alignment: alignment,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.black12),
      ),
      child: child,
    );
  }

  Widget campoFechaDia(int index) {
    final bool habilitado = _diaHabilitado(index);

    return TextFormField(
      controller: fechaDiaControllers[index],
      readOnly: true,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: fontSizeTabla,
      ),
      onTap: _seleccionarRangoFechasGira,
      decoration: InputDecoration(
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 7,
        ),
        suffixIcon: Icon(
          habilitado ? Icons.check_circle : Icons.calendar_month,
          size: 16,
          color: habilitado ? Colors.green : null,
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 24,
          minHeight: 22,
        ),
        filled: true,
        fillColor: habilitado
            ? Colors.green.withValues(alpha: 0.08)
            : Colors.white,
      ),
    );
  }

  Widget campoLugarDia(int index) {
    final bool habilitado = _diaHabilitado(index);

    return TextFormField(
      controller: lugarDiaControllers[index],
      enabled: habilitado,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: fontSizeTabla,
      ),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 7,
        ),
        filled: true,
        fillColor: habilitado ? Colors.white : Colors.grey.shade100,
      ),
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (!rangoFechasSeleccionado)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.orange.withValues(alpha: 0.35),
            ),
          ),
          child: const Text(
            'Seleccione primero el rango de fechas de la gira. '
            'Luego se habilitarán solo los días correspondientes.',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.orange,
            ),
          ),
        ),

      if (rangoFechasSeleccionado)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.green.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            'Rango seleccionado: '
            '${DateFormat('dd/MM/yyyy').format(fechaInicioGira!)} '
            'al ${DateFormat('dd/MM/yyyy').format(fechaFinGira!)}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.green.shade800,
            ),
          ),
        ),

      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              celdaFija(
                height: altoEncabezado,
                color: const Color(0xFFEAF2FF),
                alignment: Alignment.center,
                child: const SizedBox(),
              ),
              celdaFija(
                height: altoFilaFecha,
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Fecha',
                  style: TextStyle(
                    fontSize: fontSizeTabla,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              celdaFija(
                height: altoFilaLugar,
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Lugar /\nProvincia',
                  style: TextStyle(
                    fontSize: fontSizeTabla,
                    fontWeight: FontWeight.w600,
                    height: 1.05,
                  ),
                ),
              ),
            ],
          ),

          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(7, (index) {
                  final bool habilitado = _diaHabilitado(index);

                  return Column(
                    children: [
                      celdaDia(
                        height: altoEncabezado,
                        color: habilitado
                            ? Colors.green.withValues(alpha: 0.10)
                            : const Color(0xFFEAF2FF),
                        child: Text(
                          diasLargos[index],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: fontSizeTabla,
                            fontWeight: FontWeight.bold,
                            color: habilitado
                                ? Colors.green.shade800
                                : Colors.black87,
                          ),
                        ),
                      ),
                      celdaDia(
                        height: altoFilaFecha,
                        child: campoFechaDia(index),
                      ),
                      celdaDia(
                        height: altoFilaLugar,
                        child: campoLugarDia(index),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

  Widget _campoMontoTabla(
    FilaGasto row,
    int dayIndex,
  ) {
    final bool habilitado = _diaHabilitado(dayIndex);
    final TextEditingController controller = row.controllers[dayIndex];

    return Focus(
      onFocusChange: (hasFocus) {
        if (hasFocus && habilitado) {
          _limpiarMontoSiEsCero(controller);
        }

        if (!hasFocus && habilitado) {
          _convertirCeldaGastoADolares(row, dayIndex);
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: TextFormField(
          controller: controller,
          enabled: habilitado,
          textAlign: TextAlign.right,
          keyboardType: TextInputType.number,
          onChanged: (_) {
            row.convertidoADolares[dayIndex] = false;
            setState(() {});
          },
          decoration: InputDecoration(
            isDense: true,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 8,
            ),
            filled: true,
            fillColor: habilitado ? Colors.white : Colors.grey.shade100,
          ),
        ),
      ),
    );
  }

  String _textoConceptoCompacto(String texto) {
    String resultado = texto.trim();

    final Map<String, String> saltosPersonalizados = {
      'Transporte y/o combustible': 'Transporte y/o\ncombustible',
      'Estacionamiento y peaje': 'Estacionamiento\ny peaje',
      'Impuesto de salida': 'Impuesto de\nsalida',
      'Atención al cliente': 'Atención al\ncliente',
      'Atencion al cliente': 'Atencion al\ncliente',
      'TOTAL TRANSPORTE': 'TOTAL\nTRANSPORTE',
      'TOTAL HOTEL Y COMIDAS': 'TOTAL HOTEL Y\nCOMIDAS',
      'TOTAL MISCELÁNEOS': 'TOTAL\nMISCELÁNEOS',
      'TOTAL MISCELANEOS': 'TOTAL\nMISCELANEOS',
    };

    if (saltosPersonalizados.containsKey(resultado)) {
      return saltosPersonalizados[resultado]!;
    }

    resultado = resultado.replaceFirst(' y/o ', ' y/o\n');

    if (resultado.length > 14 && !resultado.contains('\n')) {
      resultado = resultado.replaceFirst(' y ', '\ny ');
    }

    if (resultado.length > 16 && !resultado.contains('\n')) {
      resultado = resultado.replaceFirst(' al ', ' al\n');
    }

    return resultado;
  }

  double _calcularAnchoColumnaConcepto(
    List<FilaGasto> rows,
    String totalLabel,
  ) {
    return 106.0;
  }

  Widget _tablaGastos({
    required List<FilaGasto> rows,
    required String totalLabel,
    required Color color,
    bool permitirEliminar = false,
    void Function(int index)? onEliminar,
  }) {
    final double conceptoWidth = _calcularAnchoColumnaConcepto(rows, totalLabel);
    const double dayWidth = 82;
    const double totalWidth = 90;
    const double accionWidth = 80;

    const double headerHeight = 44;
    const double rowHeight = 56;
    const double totalHeight = 44;

    Widget celda({
      required Widget child,
      double height = rowHeight,
      Alignment alignment = Alignment.centerLeft,
      Color? backgroundColor,
      EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    }) {
      return Container(
        height: height,
        padding: padding,
        alignment: alignment,
        color: backgroundColor,
        child: child,
      );
    }

    final List<double> totalPorDia = List.generate(7, (dayIndex) {
      return rows.fold(0.0, (sum, row) {
        return sum + _valorDiaValido(row, dayIndex);
      });
    });

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: conceptoWidth,
          child: Table(
            border: TableBorder.all(color: Colors.black12),
            columnWidths: {
              0: FixedColumnWidth(conceptoWidth),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(
                  color: Color(0xFFEAF2FF),
                ),
                children: [
                  celda(
                    height: headerHeight,
                    alignment: Alignment.center,
                    child: const Text(
                      'Concepto',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              ...List.generate(rows.length, (index) {
                return TableRow(
                  children: [
                    celda(
                      height: rowHeight,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _textoConceptoCompacto(rows[index].nombre),
                        softWrap: true,
                        overflow: TextOverflow.visible,
                        maxLines: 3,
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.05,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                );
              }),
              TableRow(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                ),
                children: [
                  celda(
                    height: totalHeight,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _textoConceptoCompacto(totalLabel),
                      softWrap: true,
                      overflow: TextOverflow.visible,
                      maxLines: 3,
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.05,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              border: TableBorder.all(color: Colors.black12),
              defaultColumnWidth: const FixedColumnWidth(dayWidth),
              columnWidths: {
                7: const FixedColumnWidth(totalWidth),
                if (permitirEliminar) 8: const FixedColumnWidth(accionWidth),
              },
              children: [
                TableRow(
                  decoration: const BoxDecoration(
                    color: Color(0xFFEAF2FF),
                  ),
                  children: [
                    ...diasCortos.map(
                      (dia) => celda(
                        height: headerHeight,
                        alignment: Alignment.center,
                        child: Text(
                          dia,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    celda(
                      height: headerHeight,
                      alignment: Alignment.center,
                      child: const Text(
                        'Total',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (permitirEliminar)
                      celda(
                        height: headerHeight,
                        alignment: Alignment.center,
                        child: const Text(
                          'Acción',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                ...List.generate(rows.length, (rowIndex) {
                  final FilaGasto row = rows[rowIndex];

                  return TableRow(
                    children: [
                      ...List.generate(7, (dayIndex) {
                        return SizedBox(
                          height: rowHeight,
                          child: _campoMontoTabla(
                            row,
                            dayIndex,
                          ),
                        );
                      }),
                      celda(
                        height: rowHeight,
                        alignment: Alignment.centerRight,
                        child: Text(
                          _money(_totalFilaValida(row)),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (permitirEliminar)
                        celda(
                          height: rowHeight,
                          alignment: Alignment.center,
                          padding: EdgeInsets.zero,
                          child: IconButton(
                            onPressed: rowIndex >= 4
                                ? () {
                                    onEliminar?.call(rowIndex);
                                  }
                                : null,
                            icon: Icon(
                              rowIndex >= 4 ? Icons.delete : Icons.lock_outline,
                              color: rowIndex >= 4 ? Colors.red : Colors.grey,
                            ),
                          ),
                        ),
                    ],
                  );
                }),
                TableRow(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                  ),
                  children: [
                    ...totalPorDia.map(
                      (value) => celda(
                        height: totalHeight,
                        alignment: Alignment.centerRight,
                        child: Text(
                          _money(value),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ),
                    celda(
                      height: totalHeight,
                      alignment: Alignment.centerRight,
                      child: Text(
                        _money(_totalRows(rows)),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                    if (permitirEliminar)
                      celda(
                        height: totalHeight,
                        alignment: Alignment.center,
                        child: const SizedBox(),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _detalleGastos() {
    return Column(
      children: [
        if (!rangoFechasSeleccionado)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.orange.withValues(alpha: 0.35),
              ),
            ),
            child: const Text(
              'Primero seleccione el rango de fechas de la gira '
              'para habilitar el detalle de gastos.',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.orange,
              ),
            ),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            border: TableBorder.all(color: Colors.black12),
            defaultColumnWidth: const FixedColumnWidth(130),
            columnWidths: const {
              1: FixedColumnWidth(260),
              2: FixedColumnWidth(190),
              4: FixedColumnWidth(80),
            },
            children: [
              const TableRow(
                decoration: BoxDecoration(
                  color: Color(0xFFEAF2FF),
                ),
                children: [
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Fecha',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Detalle y propósito del gasto',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Nombre del lugar',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Monto',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Acción',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              ...List.generate(detalles.length, (index) {
                final detalle = detalles[index];

                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: TextFormField(
                        controller: detalle.fechaController,
                        enabled: rangoFechasSeleccionado,
                        readOnly: true,
                        onTap: rangoFechasSeleccionado
                            ? () => _seleccionarFechaDetalle(
                                  detalle.fechaController,
                                )
                            : null,
                        decoration: InputDecoration(
                          isDense: true,
                          border: const OutlineInputBorder(),
                          suffixIcon: Icon(
                            Icons.calendar_month,
                            size: 16,
                            color: rangoFechasSeleccionado ? null : Colors.grey,
                          ),
                          filled: true,
                          fillColor: rangoFechasSeleccionado
                              ? Colors.white
                              : Colors.grey.shade100,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: TextFormField(
                        controller: detalle.detalleController,
                        enabled: rangoFechasSeleccionado,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          isDense: true,
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: rangoFechasSeleccionado
                              ? Colors.white
                              : Colors.grey.shade100,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: TextFormField(
                        controller: detalle.lugarController,
                        enabled: rangoFechasSeleccionado,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          isDense: true,
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: rangoFechasSeleccionado
                              ? Colors.white
                              : Colors.grey.shade100,
                        ),
                      ),
                    ),
                    Focus(
                      onFocusChange: (hasFocus) {
                        if (hasFocus && rangoFechasSeleccionado) {
                          _limpiarMontoSiEsCero(detalle.montoController);
                        }

                        if (!hasFocus && rangoFechasSeleccionado) {
                          _convertirDetalleGastoADolares(detalle);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: TextFormField(
                          controller: detalle.montoController,
                          enabled: rangoFechasSeleccionado,
                          textAlign: TextAlign.right,
                          keyboardType: TextInputType.number,
                          onChanged: (_) {
                            detalle.montoConvertidoADolares = false;
                            setState(() {});
                          },
                          decoration: InputDecoration(
                            isDense: true,
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: rangoFechasSeleccionado
                                ? Colors.white
                                : Colors.grey.shade100,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _eliminarDetalle(index),
                      icon: const Icon(Icons.delete, color: Colors.red),
                    ),
                  ],
                );
              }),
              TableRow(
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                ),
                children: [
                  const SizedBox(),
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'TOTAL DETALLE DE GASTOS',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      _money(totalDetalleGastos),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: rangoFechasSeleccionado ? _agregarDetalle : null,
          icon: const Icon(Icons.add),
          label: const Text('Agregar gasto'),
        ),
      ],
    );
  }

  Widget _resumenFinal() {
    return Column(
      children: [
        _campoTexto(
          label: 'Propósito del viaje / reunión',
          controller: propositoController,
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        _filaResumenEditable(
          label: '1. Adelanto al colaborador',
          controller: adelantoController,
        ),
        const SizedBox(height: 12),
        _filaResumenAutomatico(
          label: '2. Total de gastos',
          value: totalGastos,
          color: Colors.green,
        ),
        if (totalDetalleGastos > 0) ...[
          const SizedBox(height: 12),
          _filaResumenAutomatico(
            label: 'Detalle de gastos incluido',
            value: totalDetalleGastos,
            color: Colors.purple,
          ),
        ],
        const SizedBox(height: 12),
        _filaResumenAutomatico(
          label: '3. Reembolso por el colaborador',
          value: reembolso,
          color: Colors.orange,
        ),
        const SizedBox(height: 12),
        _filaResumenAutomatico(
          label: '4. Monto por pagar al colaborador',
          value: montoPorPagar,
          color: Colors.green,
        ),
        const SizedBox(height: 18),
        _resumenBox(
          label: 'GRAN TOTAL DE GASTOS',
          value: granTotal,
          color: Colors.green,
          grande: true,
        ),
      ],
    );
  }

  Widget _filaResumenEditable({
    required String label,
    required TextEditingController controller,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 135,
          child: TextFormField(
            controller: controller,
            textAlign: TextAlign.right,
            keyboardType: TextInputType.number,
            onTap: () => _limpiarMontoSiEsCero(controller),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixText: 'B/. ',
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _filaResumenAutomatico({
    required String label,
    required double value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$label (B/.)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          Text(
            _money(value),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _resumenBox({
    required String label,
    required double value,
    required Color color,
    bool grande = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$label (B/.)',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            _money(value),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: grande ? 26 : 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _firmas() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _campoTexto(
                label: 'Preparado por',
                controller: preparadoPorController,
                icon: Icons.person,
                readOnly: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _campoTexto(
                label: 'Revisado por',
                controller: revisadoPorController,
                icon: Icons.verified_user,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _campoFecha(
                label: 'Fecha preparado',
                controller: fechaPreparadoController,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _campoFecha(
                label: 'Fecha revisado',
                controller: fechaRevisadoController,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _botonesFinales() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _generarPdfPendiente,
            icon: const Icon(Icons.picture_as_pdf, size: 18),
            label: const Text('PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade800,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            icon: const Icon(Icons.home, size: 18),
            label: const Text('Home'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green.shade800,
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: Colors.green.shade800),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _vistaPreviaPendiente,
            icon: const Icon(Icons.remove_red_eye, size: 18),
            label: const Text('Vista'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green.shade800,
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: Colors.green.shade800),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              if (!_validarDatosMinimos()) return;

              await _guardarInformeDiamed();

              if (!mounted) return;

              await mostrarCheckGuardado(
                context,
                mensaje: 'Informe Diamed guardado correctamente',
              );
            },
            icon: const Icon(Icons.save, size: 18),
            label: const Text('Guardar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text('Informe Diamed Panamá'),
        centerTitle: true,
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Ir al inicio',
            onPressed: () {
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            icon: const Icon(Icons.home),
          ),
          IconButton(
            tooltip: 'Generar PDF',
            onPressed: _generarPdfPendiente,
            icon: const Icon(Icons.picture_as_pdf),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Image.asset(
                'assets/images/diamed_panama.png',
                height: 100,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 14),
              _sectionCard(
                titulo: '1. Datos generales',
                icono: Icons.feed,
                color: Colors.green.shade800,
                child: Column(
                  children: [
                    TextFormField(
                      controller: preparadoPorController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del empleado',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Debe registrar un usuario primero';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _campoFecha(
                      label: 'Fecha de preparación',
                      controller: fechaPreparacionController,
                    ),
                    const SizedBox(height: 12),
                    _campoTasaCambio(),
                  ],
                ),
              ),
              _sectionCard(
                titulo: '2. Semana de gira (Fecha y lugar por día)',
                icono: Icons.calendar_month,
                color: Colors.orange,
                child: _tablaSemanaGira(),
              ),
              _sectionCard(
                titulo: '3. Gasto de movilidad',
                icono: Icons.directions_car,
                color: Colors.green,
                child: _tablaGastos(
                  rows: transporteRows,
                  totalLabel: 'TOTAL TRANSPORTE',
                  color: Colors.green.shade800,
                ),
              ),
              _sectionCard(
                titulo: '4. Hotel y comidas',
                icono: Icons.hotel,
                color: Colors.deepOrange,
                child: _tablaGastos(
                  rows: hotelRows,
                  totalLabel: 'TOTAL HOTEL Y COMIDAS',
                  color: Colors.deepOrange,
                ),
              ),
              _sectionCard(
                titulo: '5. Misceláneos',
                icono: Icons.payments,
                color: Colors.purple,
                child: Column(
                  children: [
                    _tablaGastos(
                      rows: miscelaneosRows,
                      totalLabel: 'TOTAL MISCELÁNEOS',
                      color: Colors.purple,
                      permitirEliminar: true,
                      onEliminar: _eliminarMiscelaneo,
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _agregarMiscelaneo,
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar misceláneo'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.purple,
                        side: const BorderSide(color: Colors.purple),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _sectionCard(
                titulo: '6. Detalle de gastos',
                icono: Icons.list_alt,
                color: Colors.green,
                child: _detalleGastos(),
              ),
              _sectionCard(
                titulo: '7. Resumen final',
                icono: Icons.bar_chart,
                color: Colors.red,
                child: _resumenFinal(),
              ),
              _sectionCard(
                titulo: '8. Firmas',
                icono: Icons.person_pin,
                color: Colors.indigo,
                child: _firmas(),
              ),
              _botonesFinales(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class FilaGasto {
  final String nombre;
  final List<TextEditingController> controllers;
  final List<bool> convertidoADolares;

  FilaGasto(this.nombre)
      : controllers = List.generate(
          7,
          (_) => TextEditingController(text: '0.00'),
        ),
        convertidoADolares = List.generate(
          7,
          (_) => false,
        );

  double valorDia(int index) {
    return double.tryParse(
          controllers[index].text.replaceAll(',', '.'),
        ) ??
        0.0;
  }

  double get total {
    return List.generate(7, valorDia).fold(0.0, (a, b) => a + b);
  }

  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }
  }
}

class DetalleGasto {
  final TextEditingController fechaController = TextEditingController();
  final TextEditingController detalleController = TextEditingController();
  final TextEditingController lugarController = TextEditingController();
  final TextEditingController montoController = TextEditingController(text: '0.00');

  bool montoConvertidoADolares = false;

  void dispose() {
    fechaController.dispose();
    detalleController.dispose();
    lugarController.dispose();
    montoController.dispose();
  }
}

class MonedaInfo {
  final String codigo;
  final String nombre;
  final String simbolo;

  const MonedaInfo({
    required this.codigo,
    required this.nombre,
    required this.simbolo,
  });
}