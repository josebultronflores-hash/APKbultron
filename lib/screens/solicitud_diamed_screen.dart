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

class SolicitudDiamedScreen extends StatefulWidget {
  final DocumentoViatico? documentoEditar;

  const SolicitudDiamedScreen({
    super.key,
    this.documentoEditar,
  });

  @override
  State<SolicitudDiamedScreen> createState() => _SolicitudDiamedScreenState();
}

class _SolicitudDiamedScreenState extends State<SolicitudDiamedScreen> {
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
    'Corredores',
    'Reembolsos',
    'Combustible',
    'Otros',
  ];

  @override
  void initState() {
    super.initState();

    idDocumentoActual = widget.documentoEditar?.id ??
        'solicitud_diamed_${DateTime.now().millisecondsSinceEpoch}';

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

  String _moneyPdfSolicitud(String value) {
    final limpio = value.trim().replaceAll(',', '.');

    if (limpio.isEmpty) {
      return '';
    }

    final numero = double.tryParse(limpio);

    if (numero == null) {
      return value.trim();
    }

    return numero.toStringAsFixed(2);
  }

  void _normalizarMontoNumero() {
    final montoFormateado = _moneyPdfSolicitud(montoNumeroController.text);

    if (montoFormateado.isEmpty) {
      return;
    }

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
    final fecha = fechaController.text.trim();
    final beneficiario = beneficiarioController.text.trim();

    if (fecha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccione la fecha de la solicitud'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    if (beneficiario.isEmpty) {
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

  Future<void> _guardarSolicitudDiamed({
    String pdfPath = '',
    bool mostrarMensaje = true,
  }) async {
    if (!_validarDatosMinimos()) return;

    final ahora = DateTime.now();

    final String rutaPdf = pdfPath.isNotEmpty
        ? pdfPath
        : (widget.documentoEditar?.pdfPath ?? '');

    final documento = DocumentoViatico(
      id: idDocumentoActual,
      empresa: 'Diamed',
      tipo: 'Solicitud',
      nombre: beneficiarioController.text.trim(),
      fecha: fechaController.text,
      destino: lugarController.text.trim().isEmpty
          ? 'Sin lugar'
          : lugarController.text.trim(),
      pdfPath: rutaPdf,
      datosFormulario: _obtenerDatosFormulario(),
      creadoEn: widget.documentoEditar?.creadoEn ?? ahora,
      actualizadoEn: ahora,
    );

    await DocumentoStorageService.instance.guardarDocumento(documento);

    if (!mounted || !mostrarMensaje) return;
  }

  double _topConcepto(String? concepto) {
    switch (concepto) {
      case 'Viáticos y Transporte':
        return 287;
      case 'Corredores':
        return 297;
      case 'Reembolsos':
        return 307;
      case 'Combustible':
        return 317;
      case 'Otros':
        return 327;
      default:
        return 287;
    }
  }

  Future<void> _generarPdfSolicitudDiamed() async {
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
        'assets/templates/solicitud_diamed_template.png',
      );

      final Uint8List plantillaBytes = plantillaData.buffer.asUint8List();
      final plantillaImagen = pw.MemoryImage(plantillaBytes);
      final String montoPdf = _moneyPdfSolicitud(montoNumeroController.text);

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

                pw.Positioned(
                  left: 160,
                  top: 143,
                  child: pw.Text(
                    fechaController.text,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),

                pw.Positioned(
                  left: 175,
                  top: metodoPagoSeleccionado == 'Transferencia' ? 164 : 189,
                  child: pw.Text(
                    'X',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),

                pw.Positioned(
                  left: 170,
                  top: 228,
                  child: pw.Text(
                    beneficiarioPdf,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),

                pw.Positioned(
                  left: 170,
                  top: 239,
                  child: pw.SizedBox(
                    width: 300,
                    child: pw.Text(
                      montoLetraController.text,
                      style: const pw.TextStyle(fontSize: 10),
                      maxLines: 1,
                      overflow: pw.TextOverflow.clip,
                    ),
                  ),
                ),

                pw.Positioned(
                  left: 500,
                  top: 252,
                  child: pw.Text(
                    montoPdf,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),

                pw.Positioned(
                  left: 175,
                  top: _topConcepto(conceptoSeleccionado),
                  child: pw.Text(
                    'X',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),

                pw.Positioned(
                  left: 500,
                  top: _topConcepto(conceptoSeleccionado),
                  child: pw.Text(
                    montoPdf,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),

                pw.Positioned(
                  left: 180,
                  top: 353,
                  child: pw.Container(
                    width: 245,
                    height: 38,
                    child: pw.Text(
                      motivoController.text,
                      style: const pw.TextStyle(fontSize: 9),
                      maxLines: 3,
                      overflow: pw.TextOverflow.clip,
                    ),
                  ),
                ),

                pw.Positioned(
                  left: 220,
                  top: 400,
                  child: pw.Text(
                    tiempoController.text,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),

                pw.Positioned(
                  left: 220,
                  top: 413,
                  child: pw.Text(
                    lugarController.text,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),

                pw.Positioned(
                  left: 170,
                  top: 640,
                  child: pw.SizedBox(
                    width: 120,
                    child: pw.Text(
                      beneficiarioPdf,
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ),
                ),

                pw.Positioned(
                  left: 170,
                  top: 663,
                  child: pw.Text(
                    fechaController.text,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ),
              ],
            );
          },
        ),
      );

      final Directory directory = await getApplicationDocumentsDirectory();

      final String nombreArchivo =
          'solicitud_diamed_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final File archivoPdf = File('${directory.path}/$nombreArchivo');

      await archivoPdf.writeAsBytes(await pdf.save());

      await _guardarSolicitudDiamed(
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

  Future<void> _guardarPendiente() async {
    _normalizarMontoNumero();

    if (!_validarDatosMinimos()) return;

    await _guardarSolicitudDiamed();

    if (!mounted) return;

    await mostrarCheckGuardado(
      context,
      mensaje: 'Solicitud Diamed guardada correctamente',
    );
  }

  Future<void> _vistaPreviaPdf() async {
    await _generarPdfSolicitudDiamed();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: Text(
          widget.documentoEditar == null
              ? 'Solicitud Diamed'
              : 'Editar Solicitud Diamed',
        ),
        centerTitle: true,
        backgroundColor: Colors.green,
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
                'assets/images/diamed_panama.png',
                height: 110,
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
                  prefixIcon: Icon(Icons.payment),
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
                  hintText: 'Ejemplo: 1 día / 2 días',
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
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Colors.green),
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
                      onPressed: _guardarPendiente,
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('Guardar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Colors.green),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _generarPdfSolicitudDiamed,
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      label: const Text('PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
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