import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocky_offline_sdk/common/custom_modal.dart';

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
  static Future<Map<String, bool>> checkExpirationStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final expirationRockyStr = prefs.getString('expiration_date');
      final expirationSigiresStr = prefs.getString('expiration_date_sigires');

      bool rockyExpired = false;
      bool sigiresExpired = false;

      if (expirationRockyStr != null) {
        final rockyDate = DateTime.parse(expirationRockyStr);
        rockyExpired = DateTime.now().isAfter(rockyDate);
      }

      if (expirationSigiresStr != null) {
        final sigiresDate = DateTime.parse(expirationSigiresStr);
        sigiresExpired = DateTime.now().isAfter(sigiresDate);
      }

      return {
        "rocky": rockyExpired,
        "sigires": sigiresExpired,
      };
    } catch (e) {
      debugPrint('Error verificando expiración: $e');
      return {
        "rocky": false,
        "sigires": false,
      };
    }
  }

  /// Muestra un modal de alerta indicando que la licencia ha expirado.
  ///
  /// - El diálogo es modal y no puede cerrarse tocando fuera (`barrierDismissible: false`).
  /// - Informa al usuario que debe contactar al administrador.
  /// - Incluye un botón "Cerrar" que:
  ///   - Cierra el modal.
  ///   - Redirige a la ruta `/form` usando `Navigator.pushReplacementNamed`.

  /// Verifica si la licencia está expirada y muestra el mensaje si es necesario.
  ///
  /// - Llama internamente a [isExpired].
  /// - Si ha expirado, abre el modal de [mostrarMensajeExpiracion].
  ///
  /// Retorna `true` si está expirada y se mostró el mensaje,
  /// o `false` si aún está vigente.
  static Future<bool> verificarYMostrarExpiracion(BuildContext context) async {
    final status = await checkExpirationStatus();

    final rockyExpired = status["rocky"] ?? false;
    final sigiresExpired = status["sigires"] ?? false;

    if (!context.mounted) return false;
    if (rockyExpired && sigiresExpired) {
      mostrarMensajeModal(
        context,
        mensaje: "Las bases de datos de Rocky o Sigires han expirado verificalas según las fechas de cargue.",
        titulo: "Base de datos expirada",
        tipo: TipoMensaje.error,
      );
      return true;
    }

    return false; 
  }
}
