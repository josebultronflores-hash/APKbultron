import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import 'package:learning/widgets/empresa_card.dart';
import 'package:learning/screens/pantalla_qls.dart';
import 'package:learning/screens/pantalla_diamed.dart';
import 'package:learning/models/documento_viatico.dart';
import 'package:learning/services/documento_storage_service.dart';
import 'package:learning/services/usuario_local_service.dart';
import 'package:learning/animations/loading_pdf_dialog.dart';

import 'documentos_guardados_screen.dart';
import 'informe_qls_screen.dart';
import 'informe_diamed_screen.dart';

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  List<DocumentoViatico> documentosRecientes = [];
  bool cargandoDocumentos = true;
  String nombreUsuario = '';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      verificarUsuario();
    });

    cargarUsuario();
    cargarDocumentosRecientes();
  }

  String obtenerSubtituloDocumento(DocumentoViatico documento) {
    if (documento.tipo == 'Informe') {
      final lugarInforme = obtenerLugarInforme(documento);

      return '${documento.nombre} • ${documento.fecha}\n$lugarInforme';
    }

    return '${documento.nombre} • ${documento.fecha}\n${documento.destino}';
  }

  String obtenerLugarInforme(DocumentoViatico documento) {
    final datos = documento.datosFormulario;

    final lugaresDias = datos['lugaresDias'];

    if (lugaresDias is List) {
      final lugaresLimpios = lugaresDias
          .map((lugar) => lugar.toString().trim())
          .where((lugar) => lugar.isNotEmpty)
          .toSet()
          .toList();

      if (lugaresLimpios.isNotEmpty) {
        return lugaresLimpios.join(' / ');
      }
    }

    final posiblesCamposLugar = [
      'lugar',
      'lugarInforme',
      'destino',
      'ubicacion',
      'provincia',
    ];

    for (final campo in posiblesCamposLugar) {
      final valor = datos[campo]?.toString().trim();

      if (valor != null && valor.isNotEmpty) {
        return valor;
      }
    }

    return 'Lugar no especificado';
  }

  Future<void> cargarUsuario() async {
    final nombre = await UsuarioLocalService.obtenerNombreUsuario();

    if (!mounted) return;

    setState(() {
      nombreUsuario =
          nombre != null && nombre.trim().isNotEmpty ? nombre.trim() : '';
    });
  }

  Future<void> mostrarDialogoNombreUsuario() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Nombre de usuario'),
          content: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Escriba su nombre',
              hintText: 'Ejemplo: José Bultron',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: () async {
                final nombre = controller.text.trim();

                if (nombre.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('El nombre no puede estar vacío'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                await UsuarioLocalService.guardarNombreUsuario(nombre);

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }

                if (!mounted) return;

                setState(() {
                  nombreUsuario = nombre;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Usuario guardado: $nombre'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              icon: const Icon(Icons.save),
              label: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    controller.dispose();
  }

  Future<void> mostrarDialogoEditarUsuario() async {
    final nombreActual = await UsuarioLocalService.obtenerNombreUsuario();

    if (!mounted) return;

    final controller = TextEditingController(
      text: nombreActual ?? '',
    );

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Editar usuario'),
          content: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombre del usuario',
              hintText: 'Ejemplo: José Bultron',
              prefixIcon: Icon(Icons.manage_accounts),
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final nuevoNombre = controller.text.trim();

                if (nuevoNombre.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('El nombre no puede estar vacío'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                await UsuarioLocalService.guardarNombreUsuario(nuevoNombre);

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }

                if (!mounted) return;

                setState(() {
                  nombreUsuario = nuevoNombre;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Usuario actualizado: $nuevoNombre'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              icon: const Icon(Icons.save),
              label: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    controller.dispose();
  }

  Future<void> verificarUsuario() async {
    final existe = await UsuarioLocalService.existeUsuario();

    if (!existe && mounted) {
      await mostrarDialogoNombreUsuario();
    } else {
      await cargarUsuario();
    }
  }

  Future<void> cargarDocumentosRecientes() async {
    final data = await DocumentoStorageService.instance.obtenerRecientes(
      limite: 8,
    );

    if (!mounted) return;

    setState(() {
      documentosRecientes = data;
      cargandoDocumentos = false;
    });
  }

  Future<void> abrirDocumentosGuardados() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const DocumentosGuardadosScreen(),
      ),
    );

    await cargarDocumentosRecientes();

    if (!mounted) return;

    Navigator.popUntil(context, (route) => route.isFirst);
  }

  Future<void> abrirPdfExistente(DocumentoViatico documento) async {
    if (documento.pdfPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este documento no tiene PDF guardado'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final archivo = File(documento.pdfPath);

    if (!await archivo.exists()) {
      if (!mounted) return;

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

  Future<void> editarSoloInforme(DocumentoViatico documento) async {
    Widget pantalla;

    if (documento.empresa == 'QLS' && documento.tipo == 'Informe') {
      pantalla = InformeQlsScreen(documentoEditar: documento);
    } else if (documento.empresa == 'Diamed' && documento.tipo == 'Informe') {
      pantalla = InformeDiamedScreen(documentoEditar: documento);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Las solicitudes solo se pueden ver en PDF'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    mostrarLoadingPdf(
      context,
      mensaje: 'Abriendo informe',
      subMensaje: 'Por favor espere',
    );

    await Future.delayed(const Duration(milliseconds: 900));

    if (mounted) {
      cerrarLoadingPdf(context);
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => pantalla,
      ),
    );

    await cargarDocumentosRecientes();
  }

  Future<void> accionAlTocarDocumento(DocumentoViatico documento) async {
    final bool esInforme =
        documento.tipo == 'Informe' &&
        (documento.empresa == 'QLS' || documento.empresa == 'Diamed');

    if (esInforme) {
      await editarSoloInforme(documento);
      return;
    }

    await abrirPdfExistente(documento);
  }

  Future<void> eliminarDocumento(DocumentoViatico documento) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar documento'),
          content: Text(
            '¿Deseas eliminar ${documento.tipo} - ${documento.empresa}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.delete),
              label: const Text('Eliminar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    await DocumentoStorageService.instance.eliminarDocumento(documento.id);

    await cargarDocumentosRecientes();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Documento eliminado correctamente'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void mostrarAcercaDeDocFlow() {
    showAboutDialog(
      context: context,
      applicationName: 'DocFlow',
      applicationVersion: 'Versión 1.0.0',
      applicationIcon: const Icon(
        Icons.description,
        size: 48,
        color: Color(0xFF002B6B),
      ),
      children: const [
        Text('Sistema de Gestión Documental'),
        SizedBox(height: 12),
        Text('Desarrollado por José Bultrón'),
        Text('Ingeniero Biomédico'),
      ],
    );
  }

  IconData iconoDocumento(DocumentoViatico documento) {
    if (documento.tipo == 'Solicitud') {
      return Icons.description;
    }

    return Icons.picture_as_pdf;
  }

  Color colorDocumento(DocumentoViatico documento) {
    if (documento.tipo == 'Solicitud') {
      return Colors.blue;
    }

    return Colors.orange;
  }

  PopupMenuButton<String> menuDocumentoReciente(DocumentoViatico documento) {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'ver_pdf') {
          await abrirPdfExistente(documento);
        }

        if (value == 'editar') {
          await editarSoloInforme(documento);
        }

        if (value == 'eliminar') {
          await eliminarDocumento(documento);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'ver_pdf',
          child: Row(
            children: [
              Icon(
                Icons.picture_as_pdf,
                color: Colors.red,
              ),
              SizedBox(width: 10),
              Text('Ver PDF'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'editar',
          child: Row(
            children: [
              Icon(
                Icons.edit,
                color: Colors.blue,
              ),
              SizedBox(width: 10),
              Text('Editar'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'eliminar',
          child: Row(
            children: [
              Icon(
                Icons.delete,
                color: Colors.red,
              ),
              SizedBox(width: 10),
              Text('Eliminar'),
            ],
          ),
        ),
      ],
    );
  }

  Widget tarjetaDocumentoReciente(DocumentoViatico doc) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(
          iconoDocumento(doc),
          color: colorDocumento(doc),
        ),
        title: Text(
          '${doc.tipo} - ${doc.empresa}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          obtenerSubtituloDocumento(doc),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: menuDocumentoReciente(doc),
        onTap: () async {
          await accionAlTocarDocumento(doc);
        },
      ),
    );
  }

  Widget listaDocumentosRecientes() {
    if (cargandoDocumentos) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (documentosRecientes.isEmpty) {
      return ListView(
        children: const [
          Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No hay documentos guardados',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      itemCount: documentosRecientes.length,
      itemBuilder: (context, index) {
        final doc = documentosRecientes[index];
        return tarjetaDocumentoReciente(doc);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text('DocFlow'),
        centerTitle: true,
        backgroundColor: const Color(0xFF002B6B),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.manage_accounts),
          tooltip: 'Editar usuario',
          onPressed: mostrarDialogoEditarUsuario,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Acerca de DocFlow',
            onPressed: mostrarAcercaDeDocFlow,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    '¡Bienvenido!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  if (nombreUsuario.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      nombreUsuario,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF002B6B),
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),

                  const Text(
                    'Sistema de Gestión Documental',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black54,
                    ),
                  ),

                  const SizedBox(height: 4),

                  const Text(
                    'Seleccione la empresa para comenzar',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: EmpresaCard(
                    titulo: 'QLS Panamá',
                    subtitulo: 'Solicitudes e informes',
                    logoAsset: 'assets/images/qls_panama.png',
                    color: Colors.blue,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PantallaQLS(),
                        ),
                      );

                      await cargarDocumentosRecientes();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: EmpresaCard(
                    titulo: 'Diamed Panamá',
                    subtitulo: 'Solicitudes e informes',
                    logoAsset: 'assets/images/diamed_panama.png',
                    color: Colors.green,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PantallaDiamed(),
                        ),
                      );

                      await cargarDocumentosRecientes();
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Documentos recientes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: abrirDocumentosGuardados,
                  child: const Text('Ver todos'),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Expanded(
              child: RefreshIndicator(
                onRefresh: cargarDocumentosRecientes,
                child: listaDocumentosRecientes(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}