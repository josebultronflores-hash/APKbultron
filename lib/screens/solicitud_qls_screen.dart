import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:learning/animations/loading_pdf_dialog.dart';
import 'package:learning/animations/success_check_dialog.dart';
import 'package:learning/models/documento_viatico.dart';
import 'package:learning/services/documento_storage_service.dart';
import 'package:learning/services/usuario_local_service.dart';

class SolicitudQlsScreen extends StatefulWidget {
  final DocumentoViatico? documentoEditar;

  const SolicitudQlsScreen({
    super.key,
    this.documentoEditar,
  });

  @override
  State<SolicitudQlsScreen> createState() => _SolicitudQlsScreenState();
}

class _SolicitudQlsScreenState extends State<SolicitudQlsScreen> {
  final _formKey = GlobalKey<FormState>();

  late final String idDocumentoActual;

  bool _loadingPdfVisible = false;

  final TextEditingController fechaController = TextEditingController();
  final TextEditingController beneficiarioController = TextEditingController();
  final TextEditingController montoLetraController = TextEditingController();
  final TextEditingController montoNumeroController = TextEditingController();
  final TextEditingController motivoController = TextEditingController();
  final TextEditingController tiempoController = TextEditingController();
  final TextEditingController lugarController = TextEditingController();

  String? metodoPagoSeleccionado;
  String? conceptoSeleccionado;

  final List<String> metodosPago = [
    'Transferencia',
    'Cheque',
  ];

  final List<String> conceptos = [
    'Viáticos y Transporte',
    'Viajes y Hospedajes',
    'Reembolsos',
    'Combustible',
    'Otros',
  ];

  @override
  void initState() {
    super.initState();

    idDocumentoActual = widget.documentoEditar?.id ??
        DateTime.now().millisecondsSinceEpoch.toString();

    if (widget.documentoEditar != null) {
      _cargarDatosGuardados(widget.documentoEditar!.datosFormulario);
    }

    cargarBeneficiario();
  }

  Future<void> cargarBeneficiario() async {
    final nombre = await UsuarioLocalService.obtenerNombreUsuario();

    if (!mounted) return;

    setState(() {
      beneficiarioController.text = nombre?.trim() ?? '';
    });
  }

  void _mostrarLoadingPdfSeguro() {
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
    fechaController.dispose();
    beneficiarioController.dispose();
    montoLetraController.dispose();
    montoNumeroController.dispose();
    motivoController.dispose();
    tiempoController.dispose();
    lugarController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
    final DateTime? fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (fechaSeleccionada != null) {
      fechaController.text = DateFormat('dd/MM/yyyy').format(fechaSeleccionada);
    }
  }

  double _topConceptoX(String? concepto) {
    switch (concepto) {
      case 'Viáticos y Transporte':
        return 285;
      case 'Viajes y Hospedajes':
        return 300;
      case 'Reembolsos':
        return 310;
      case 'Combustible':
        return 324;
      case 'Otros':
        return 337;
      default:
        return 289;
    }
  }

  double _topConceptoMonto(String? concepto) {
    switch (concepto) {
      case 'Viáticos y Transporte':
        return 285;
      case 'Viajes y Hospedajes':
        return 300;
      case 'Reembolsos':
        return 310;
      case 'Combustible':
        return 324;
      case 'Otros':
        return 337;
      default:
        return 289;
    }
  }

  String _moneyPdfSolicitud(String value) {
    final limpio = value.trim().replaceAll(',', '.');

    if (limpio.isEmpty) return '';

    final numero = double.tryParse(limpio);

    if (numero == null) return value.trim();

    return numero.toStringAsFixed(2);
  }

  void _normalizarMontoNumero() {
    final montoFormateado = _moneyPdfSolicitud(montoNumeroController.text);

    if (montoFormateado.isEmpty) return;

    montoNumeroController.text = montoFormateado;
  }

  void _cargarDatosGuardados(Map<String, dynamic> datos) {
    fechaController.text = datos['fecha'] ?? '';
    beneficiarioController.text = datos['beneficiario'] ?? '';
    montoLetraController.text = datos['montoLetra'] ?? '';
    montoNumeroController.text = datos['montoNumero'] ?? '';
    motivoController.text = datos['motivo'] ?? '';
    tiempoController.text = datos['tiempo'] ?? '';
    lugarController.text = datos['lugar'] ?? '';

    metodoPagoSeleccionado = datos['metodoPago'];
    conceptoSeleccionado = datos['concepto'];
  }

  bool _validarDatosMinimos() {
    if (fechaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccione la fecha'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    if (beneficiarioController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe registrar un usuario primero'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    return true;
  }

  Map<String, dynamic> _obtenerDatosFormulario() {
    return {
      'fecha': fechaController.text,
      'metodoPago': metodoPagoSeleccionado,
      'beneficiario': beneficiarioController.text.trim(),
      'montoLetra': montoLetraController.text,
      'montoNumero': montoNumeroController.text,
      'concepto': conceptoSeleccionado,
      'motivo': motivoController.text,
      'tiempo': tiempoController.text,
      'lugar': lugarController.text,
    };
  }

  Future<void> _guardarSolicitudQls({
    required String pdfPath,
  }) async {
    if (!_validarDatosMinimos()) return;

    final ahora = DateTime.now();

    final String rutaPdf = pdfPath.isNotEmpty
        ? pdfPath
        : (widget.documentoEditar?.pdfPath ?? '');

    final documento = DocumentoViatico(
      id: idDocumentoActual,
      empresa: 'QLS',
      tipo: 'Solicitud',
      nombre: beneficiarioController.text.trim(),
      fecha: fechaController.text,
      destino: lugarController.text,
      pdfPath: rutaPdf,
      datosFormulario: _obtenerDatosFormulario(),
      creadoEn: widget.documentoEditar?.creadoEn ?? ahora,
      actualizadoEn: ahora,
    );

    await DocumentoStorageService.instance.guardarDocumento(documento);
  }

  Future<void> _guardarBorrador() async {
    _normalizarMontoNumero();

    if (!_validarDatosMinimos()) return;

    await _guardarSolicitudQls(pdfPath: '');

    if (!mounted) return;

    await mostrarCheckGuardado(
      context,
      mensaje: 'Solicitud guardada como borrador',
    );
  }

  Future<void> _generarPdfSolicitudQLS() async {
    _normalizarMontoNumero();

    if (!_validarDatosMinimos()) return;

    final formularioValido = _formKey.currentState?.validate() ?? false;

    if (!formularioValido ||
        metodoPagoSeleccionado == null ||
        conceptoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete todos los campos obligatorios'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final String beneficiarioPdf = beneficiarioController.text.trim();

    _mostrarLoadingPdfSeguro();

    try {
      final pdf = pw.Document();

      final ByteData plantillaData = await rootBundle.load(
        'assets/templates/solicitud_qls_template.png',
      );

      final Uint8List plantillaBytes = plantillaData.buffer.asUint8List();
      final plantillaImagen = pw.MemoryImage(plantillaBytes);
      final String montoPdf = _moneyPdfSolicitud(montoNumeroController.text);

      pw.Widget textoPdf(
        String texto,
        double left,
        double top, {
        double fontSize = 7,
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

      pw.Widget textoMultilineaPdf(
        String texto,
        double left,
        double top, {
        double width = 330,
        double height = 38,
        double fontSize = 6.2,
        int maxLines = 3,
      }) {
        return pw.Positioned(
          left: left,
          top: top,
          child: pw.SizedBox(
            width: width,
            height: height,
            child: pw.Text(
              texto,
              maxLines: maxLines,
              overflow: pw.TextOverflow.clip,
              style: pw.TextStyle(
                fontSize: fontSize,
                lineSpacing: 2.2,
              ),
            ),
          ),
        );
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.Stack(
              children: [
                pw.Positioned.fill(
                  child: pw.Image(
                    plantillaImagen,
                    fit: pw.BoxFit.cover,
                  ),
                ),
                textoPdf(
                  fechaController.text,
                  155,
                  140,
                  width: 120,
                  fontSize: 12,
                ),
                textoPdf(
                  metodoPagoSeleccionado == 'Transferencia' ? 'X' : '',
                  165,
                  164.5,
                  width: 26,
                  fontSize: 12,
                  bold: true,
                  align: pw.TextAlign.center,
                ),
                textoPdf(
                  metodoPagoSeleccionado == 'Cheque' ? 'X' : '',
                  165,
                  189.5,
                  width: 26,
                  fontSize: 12,
                  bold: true,
                  align: pw.TextAlign.center,
                ),
                textoPdf(
                  beneficiarioPdf,
                  120,
                  228,
                  width: 325,
                  fontSize: 10,
                  align: pw.TextAlign.center,
                ),
                textoPdf(
                  montoLetraController.text,
                  125,
                  238,
                  width: 325,
                  fontSize: 12,
                  maxLines: 1,
                ),
                textoPdf(
                  montoPdf,
                  486,
                  250,
                  width: 45,
                  fontSize: 12,
                  align: pw.TextAlign.right,
                ),
                textoPdf(
                  'X',
                  165,
                  _topConceptoX(conceptoSeleccionado),
                  width: 26,
                  fontSize: 12,
                  bold: true,
                  align: pw.TextAlign.center,
                ),
                textoPdf(
                  montoPdf,
                  486,
                  _topConceptoMonto(conceptoSeleccionado),
                  width: 45,
                  fontSize: 12,
                  align: pw.TextAlign.right,
                ),
                textoMultilineaPdf(
                  motivoController.text,
                  170,
                  351,
                  width: 320,
                  height: 56,
                  fontSize: 9,
                  maxLines: 3,
                ),
                textoPdf(
                  tiempoController.text,
                  210,
                  395,
                  width: 100,
                  fontSize: 12,
                ),
                textoPdf(
                  lugarController.text,
                  210,
                  410,
                  width: 140,
                  fontSize: 12,
                ),
                textoPdf(
                  beneficiarioPdf,
                  118,
                  636,
                  width: 180,
                  fontSize: 12,
                  align: pw.TextAlign.center,
                ),
                textoPdf(
                  fechaController.text,
                  118,
                  659,
                  width: 180,
                  fontSize: 12,
                  align: pw.TextAlign.center,
                ),
              ],
            );
          },
        ),
      );

      final Directory directory = await getApplicationDocumentsDirectory();

      final String nombreArchivo =
          'solicitud_qls_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final File archivoPdf = File('${directory.path}/$nombreArchivo');

      await archivoPdf.writeAsBytes(await pdf.save());

      await _guardarSolicitudQls(pdfPath: archivoPdf.path);

      if (!mounted) return;

      _cerrarLoadingPdfSeguro();

      await Future.delayed(const Duration(milliseconds: 250));

      if (!mounted) return;



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

  Future<void> _vistaPreviaPdf() async {
    await _generarPdfSolicitudQLS();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: Text(
          widget.documentoEditar == null
              ? 'Solicitud QLS'
              : 'Editar Solicitud QLS',
        ),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Ir al inicio',
            onPressed: () {
              Navigator.popUntil(context, (route) => route.isFirst);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset(
                'assets/images/qls_panama.png',
                height: 100,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 20),
              const Text(
                'Solicitud de Cheques o Desembolsos',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 25),
              TextFormField(
                controller: fechaController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Fecha completa',
                  prefixIcon: Icon(Icons.calendar_month),
                  border: OutlineInputBorder(),
                ),
                onTap: _seleccionarFecha,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Seleccione la fecha';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: metodoPagoSeleccionado,
                decoration: const InputDecoration(
                  labelText: 'Método de pago',
                  prefixIcon: Icon(Icons.payments),
                  border: OutlineInputBorder(),
                ),
                items: metodosPago.map((metodo) {
                  return DropdownMenuItem(
                    value: metodo,
                    child: Text(metodo),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    metodoPagoSeleccionado = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Seleccione el método de pago';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: beneficiarioController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Beneficiario',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Debe registrar un usuario primero';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: montoLetraController,
                decoration: const InputDecoration(
                  labelText: 'Por la suma de',
                  hintText: 'Ejemplo: Cincuenta dólares con 00/100',
                  prefixIcon: Icon(Icons.text_fields),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingrese el monto en letras';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: montoNumeroController,
                keyboardType: TextInputType.number,
                onEditingComplete: () {
                  _normalizarMontoNumero();
                  FocusScope.of(context).nextFocus();
                },
                decoration: const InputDecoration(
                  labelText: 'Monto',
                  hintText: 'Ejemplo: 50.00',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingrese el monto';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: conceptoSeleccionado,
                decoration: const InputDecoration(
                  labelText: 'En concepto de',
                  prefixIcon: Icon(Icons.list_alt),
                  border: OutlineInputBorder(),
                ),
                items: conceptos.map((concepto) {
                  return DropdownMenuItem(
                    value: concepto,
                    child: Text(concepto),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    conceptoSeleccionado = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Seleccione el concepto';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: motivoController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Explique el motivo de la solicitud',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.edit_note),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Explique el motivo de la solicitud';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: tiempoController,
                decoration: const InputDecoration(
                  labelText: 'Tiempo',
                  hintText: 'Ejemplo: 1 día / 2 días (01 al 04 de enero)',
                  prefixIcon: Icon(Icons.access_time),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: lugarController,
                decoration: const InputDecoration(
                  labelText: 'Lugar',
                  hintText: 'Ejemplo: Chiriquí',
                  prefixIcon: Icon(Icons.location_on),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingrese el lugar';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _vistaPreviaPdf,
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('Vista'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _guardarBorrador,
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('Guardar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _generarPdfSolicitudQLS,
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      label: const Text('PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}