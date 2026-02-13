import 'package:flutter/material.dart';

enum TipoMensaje { exito, error, advertencia, info }
  /// Muestra un diálogo modal personalizado con mensaje, título e icono.
  ///
  /// Este método crea y presenta un diálogo modal con un diseño consistente que incluye:
  /// - Un título destacado para indicar el tipo de mensaje
  /// - Un icono que indica éxito o error según el parámetro [exito]
  /// - Un mensaje detallado
  /// - Un botón de aceptar para cerrar el diálogo
  ///
  /// Parámetros:
  /// - [context]: El BuildContext para mostrar el diálogo
  /// - [mensaje]: El texto detallado a mostrar en el diálogo
  /// - [titulo]: El título principal del diálogo
  /// - [exito]: Booleano que determina si se muestra un icono de éxito (true) o error (false)
  ///
  /// El diálogo utiliza una interfaz visual consistente con el diseño general de
  /// la aplicación y se centra en la pantalla para llamar la atención del usuario.
Future<void> mostrarMensajeModal(
  BuildContext context, {
  required String mensaje,
  String titulo = "Mensaje",
  TipoMensaje tipo = TipoMensaje.info,
}) {
  IconData icono;
  Color color;

  switch (tipo) {
    case TipoMensaje.exito:
      icono = Icons.check_circle_outline;
      color = Colors.green;
      break;
    case TipoMensaje.error:
      icono = Icons.error_outline;
      color = Colors.red;
      break;
    case TipoMensaje.advertencia:
      icono = Icons.warning_amber_outlined;
      color = Colors.orange;
      break;
    case TipoMensaje.info:
    default:
      icono = Icons.info_outline;
      color = Colors.blue;
  }

  return showDialog(
    context: context,
    builder: (context) {
      return Center(
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icono, color: color, size: 45),
                const SizedBox(height: 14),
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  mensaje,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Aceptar"),
                ),
              ],
            ),
          ),
        )
      );
    },
  );
}
