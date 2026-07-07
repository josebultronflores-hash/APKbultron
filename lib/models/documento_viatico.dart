import 'dart:convert';

class DocumentoViatico {
  final String id;
  final String empresa; // QLS o Diamed
  final String tipo; // Solicitud o Informe
  final String nombre;
  final String fecha;
  final String destino;
  final String pdfPath;
  final Map<String, dynamic> datosFormulario;
  final DateTime creadoEn;
  final DateTime actualizadoEn;

  DocumentoViatico({
    required this.id,
    required this.empresa,
    required this.tipo,
    required this.nombre,
    required this.fecha,
    required this.destino,
    required this.pdfPath,
    required this.datosFormulario,
    required this.creadoEn,
    required this.actualizadoEn,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'empresa': empresa,
      'tipo': tipo,
      'nombre': nombre,
      'fecha': fecha,
      'destino': destino,
      'pdfPath': pdfPath,
      'datosFormulario': jsonEncode(datosFormulario),
      'creadoEn': creadoEn.toIso8601String(),
      'actualizadoEn': actualizadoEn.toIso8601String(),
    };
  }

  factory DocumentoViatico.fromJson(Map<String, dynamic> json) {
    return DocumentoViatico(
      id: json['id'],
      empresa: json['empresa'],
      tipo: json['tipo'],
      nombre: json['nombre'],
      fecha: json['fecha'],
      destino: json['destino'],
      pdfPath: json['pdfPath'],
      datosFormulario: json['datosFormulario'] == null
          ? {}
          : jsonDecode(json['datosFormulario']),
      creadoEn: DateTime.parse(json['creadoEn']),
      actualizadoEn: DateTime.parse(json['actualizadoEn']),
    );
  }
}