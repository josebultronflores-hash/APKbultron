import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/documento_viatico.dart';

class DocumentoStorageService {
  static final DocumentoStorageService instance =
      DocumentoStorageService._init();

  static Database? _database;

  DocumentoStorageService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDB('documentos_viaticos.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE documentos (
        id TEXT PRIMARY KEY,
        empresa TEXT NOT NULL,
        tipo TEXT NOT NULL,
        nombre TEXT NOT NULL,
        fecha TEXT NOT NULL,
        destino TEXT NOT NULL,
        pdfPath TEXT NOT NULL,
        datosFormulario TEXT NOT NULL,
        creadoEn TEXT NOT NULL,
        actualizadoEn TEXT NOT NULL
      )
    ''');
  }

  Future<void> guardarDocumento(DocumentoViatico documento) async {
    final db = await instance.database;

    await db.insert(
      'documentos',
      documento.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<DocumentoViatico>> obtenerDocumentos() async {
    final db = await instance.database;

    final result = await db.query(
      'documentos',
      orderBy: 'actualizadoEn DESC',
    );

    return result.map((json) => DocumentoViatico.fromJson(json)).toList();
  }

  Future<List<DocumentoViatico>> obtenerRecientes({int limite = 5}) async {
    final db = await instance.database;

    final result = await db.query(
      'documentos',
      orderBy: 'actualizadoEn DESC',
      limit: limite,
    );

    return result.map((json) => DocumentoViatico.fromJson(json)).toList();
  }

  Future<List<DocumentoViatico>> obtenerPorEmpresaYTipo({
    required String empresa,
    required String tipo,
  }) async {
    final db = await instance.database;

    final result = await db.query(
      'documentos',
      where: 'empresa = ? AND tipo = ?',
      whereArgs: [empresa, tipo],
      orderBy: 'actualizadoEn DESC',
    );

    return result.map((json) => DocumentoViatico.fromJson(json)).toList();
  }

  Future<void> eliminarDocumento(String id) async {
    final db = await instance.database;

    await db.delete(
      'documentos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> cerrarDB() async {
    final db = await instance.database;
    await db.close();
    _database = null;
  }
}