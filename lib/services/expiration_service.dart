import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para gestionar y verificar la expiración de la licencia de uso.
///
/// Esta clase se encarga de:
/// - Consultar en `SharedPreferences` la fecha de expiración guardada.
/// - Validar si la licencia está expirada en función de la fecha actual.
/// - Mostrar un mensaje modal al usuario cuando la licencia ha expirado.
/// - Ofrecer un método práctico para verificar y mostrar automáticamente
///   la alerta en caso necesario.
class ExpirationService {
  /// Verifica si la licencia ha expirado.
  ///
  /// Busca la clave `'expiration_date'` en `SharedPreferences`.
  /// Si no existe o ocurre un error, devuelve `true` (expirado por seguridad).
  ///
  /// Retorna `true` si la licencia ha expirado o `false` en caso contrario.
  static Future<bool> isExpired() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expirationDateStr = prefs.getString('expiration_date');

      if (expirationDateStr == null) {
        return true; // Si no hay fecha de expiración, consideramos expirado
      }

      final expirationDate = DateTime.parse(expirationDateStr);
      return DateTime.now().isAfter(expirationDate);
    } catch (e) {
      debugPrint('Error verificando expiración: $e');
      return true; // En caso de error, consideramos expirado por seguridad
    }
  }

  /// Muestra un modal de alerta indicando que la licencia ha expirado.
  ///
  /// - El diálogo es modal y no puede cerrarse tocando fuera (`barrierDismissible: false`).
  /// - Informa al usuario que debe contactar al administrador.
  /// - Incluye un botón "Cerrar" que:
  ///   - Cierra el modal.
  ///   - Redirige a la ruta `/form` usando `Navigator.pushReplacementNamed`.
  static Future<void> mostrarMensajeExpiracion(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Center(
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              width: 280,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'La licencia de uso ha expirado. Por favor, contacte al administrador para renovar su acceso.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007BFF), // Azul
                      foregroundColor: Colors.white, // Texto blanco
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.pushReplacementNamed(context, '/form');
                    },
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Verifica si la licencia está expirada y muestra el mensaje si es necesario.
  ///
  /// - Llama internamente a [isExpired].
  /// - Si ha expirado, abre el modal de [mostrarMensajeExpiracion].
  ///
  /// Retorna `true` si está expirada y se mostró el mensaje,
  /// o `false` si aún está vigente.
  static Future<bool> verificarYMostrarExpiracion(BuildContext context) async {
    final expired = await isExpired();
    if (expired) {
      await mostrarMensajeExpiracion(context);
      return true;
    }
    return false;
  }
}
