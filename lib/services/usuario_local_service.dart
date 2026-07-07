import 'package:shared_preferences/shared_preferences.dart';

class UsuarioLocalService {
  static const String _keyNombreUsuario = 'nombre_usuario';

  static Future<void> guardarNombreUsuario(String nombre) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNombreUsuario, nombre.trim());
  }

  static Future<String?> obtenerNombreUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyNombreUsuario);
  }

  static Future<bool> existeUsuario() async {
    final nombre = await obtenerNombreUsuario();
    return nombre != null && nombre.trim().isNotEmpty;
  }

  static Future<void> eliminarUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyNombreUsuario);
  }
}