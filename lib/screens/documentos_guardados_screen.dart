import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../models/documento_viatico.dart';
import '../services/documento_storage_service.dart';

import 'solicitud_qls_screen.dart';
import 'informe_qls_screen.dart';
import 'solicitud_diamed_screen.dart';
import 'informe_diamed_screen.dart';

class DocumentosGuardadosScreen extends StatefulWidget {
  const DocumentosGuardadosScreen({super.key});

  @override
  State<DocumentosGuardadosScreen> createState() =>
      _DocumentosGuardadosScreenState();
}

class _DocumentosGuardadosScreenState extends State<DocumentosGuardadosScreen> {
  List<DocumentoViatico> documentos = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    cargarDocumentos();
  }

  Future<void> cargarDocumentos() async {
    final data = await DocumentoStorageService.instance.obtenerDocumentos();

    setState(() {
      documentos = data;
      cargando = false;
    });
  }

  Future<void> abrirPdf(DocumentoViatico documento) async {
    if (documento.pdfPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este documento todavía no tiene PDF generado'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final archivo = File(documento.pdfPath);

    if (!await archivo.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se encontró el archivo PDF en el dispositivo'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await OpenFilex.open(documento.pdfPath);
  }

  Future<void> editarDocumento(DocumentoViatico documento) async {
    Widget pantalla;

    if (documento.empresa == 'QLS' && documento.tipo == 'Solicitud') {
      pantalla = SolicitudQlsScreen(documentoEditar: documento);
    } else if (documento.empresa == 'QLS' && documento.tipo == 'Informe') {
      pantalla = InformeQlsScreen(documentoEditar: documento);
    } else if (documento.empresa == 'Diamed' && documento.tipo == 'Solicitud') {
      pantalla = SolicitudDiamedScreen(documentoEditar: documento);
    } else if (documento.empresa == 'Diamed' && documento.tipo == 'Informe') {
      pantalla = InformeDiamedScreen(documentoEditar: documento);
    } else {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => pantalla),
    );

    await cargarDocumentos();
  }

  Future<void> eliminarDocumento(DocumentoViatico documento) async {
    await DocumentoStorageService.instance.eliminarDocumento(documento.id);
    await cargarDocumentos();
  }

  IconData iconoDocumento(DocumentoViatico doc) {
    return doc.tipo == 'Solicitud'
        ? Icons.description
        : Icons.picture_as_pdf;
  }

  Color colorDocumento(DocumentoViatico doc) {
    return doc.tipo == 'Solicitud' ? Colors.blue : Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documentos guardados'),
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : documentos.isEmpty
              ? const Center(
                  child: Text('No hay documentos guardados'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: documentos.length,
                  itemBuilder: (context, index) {
                    final doc = documentos[index];

                    return Card(
                      child: ListTile(
                        leading: Icon(
                          iconoDocumento(doc),
                          color: colorDocumento(doc),
                        ),
                        title: Text('${doc.tipo} - ${doc.empresa}'),
                        subtitle: Text(
                          '${doc.nombre}\n${doc.fecha} • ${doc.destino}',
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'ver') {
                              await abrirPdf(doc);
                            }

                            if (value == 'editar') {
                              await editarDocumento(doc);
                            }

                            if (value == 'eliminar') {
                              await eliminarDocumento(doc);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'ver',
                              child: Row(
                                children: [
                                  Icon(Icons.picture_as_pdf, color: Colors.red),
                                  SizedBox(width: 10),
                                  Text('Ver PDF'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'editar',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, color: Colors.blue),
                                  SizedBox(width: 10),
                                  Text('Editar'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'eliminar',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red),
                                  SizedBox(width: 10),
                                  Text('Eliminar'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        onTap: () async {
                          await abrirPdf(doc);
                        },
                      ),
                    );
                  },
                ),
    );
  }
}