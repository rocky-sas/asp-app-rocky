import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';

/// Clase auxiliar para la impresión con impresoras Bluetooth térmicas.
///
/// Proporciona métodos seguros para imprimir texto o contenido personalizado.
/// Se asegura de que exista conexión con la impresora seleccionada antes
/// de enviar comandos de impresión.
///
/// - Si la impresora no está conectada, intenta conectarse automáticamente.
/// - Si ocurre un error en la conexión o impresión, muestra un `SnackBar`
///   en el contexto actual con un mensaje de error.
class BluetoothPrinterHelper {
  final BuildContext context;
  final BluetoothDevice? selectedPrinter;

  BluetoothPrinterHelper({
    required this.context,
    required this.selectedPrinter,
  });

  /// Imprime un texto plano de manera segura.
  ///
  /// - Si no hay conexión activa, intenta conectarse a la [selectedPrinter].
  /// - Si no hay impresora seleccionada, muestra un mensaje de error.
  /// - Una vez conectada, imprime el texto recibido con formato básico.
  ///
  /// Uso típico:
  /// ```dart
  /// final printerHelper = BluetoothPrinterHelper(
  ///   context: context,
  ///   selectedPrinter: myPrinter,
  /// );
  /// await printerHelper.imprimirConSeguridad("Hola mundo!");
  /// ```
  Future<void> imprimirConSeguridad(String texto) async {
    final bluetooth = BlueThermalPrinter.instance;

    bool? isConnected = await bluetooth.isConnected;

    if (isConnected != true) {
      if (selectedPrinter == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No hay impresora seleccionada")),
        );
        return;
      }

      try {
        await bluetooth.connect(selectedPrinter!);
        await Future.delayed(const Duration(seconds: 1));
        isConnected = await bluetooth.isConnected;
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("No se pudo conectar con la impresora.")),
        );

        return;
      }
    }

    if (isConnected == true) {
      try {
        bluetooth.printNewLine();
        bluetooth.printCustom(texto, 1, 0);
        bluetooth.printNewLine();
        bluetooth.paperCut();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ocurrió un error al imprimir.")),
        );
      }
    }
  }

  /// Imprime contenido personalizado de manera segura.
  ///
  /// Acepta como parámetro una función [imprimirContenido] que recibe la
  /// instancia de [BlueThermalPrinter] ya conectada, para que se puedan enviar
  /// comandos avanzados o personalizados de impresión.
  ///
  /// - Verifica la conexión igual que [imprimirConSeguridad].
  /// - Si falla, muestra un `SnackBar` con el error correspondiente.
  ///
  /// Ejemplo:
  /// ```dart
  /// await printerHelper.imprimirConSeguridadCustom((bluetooth) {
  ///   bluetooth.printNewLine();
  ///   bluetooth.printCustom("Factura #123", 2, 1);
  ///   bluetooth.printQRcode("https://midominio.com/factura/123", 200, 200, 1);
  ///   bluetooth.printNewLine();
  /// });
  /// ```
  Future<void> imprimirConSeguridadCustom(
    void Function(BlueThermalPrinter bluetooth) imprimirContenido,
  ) async {
    final bluetooth = BlueThermalPrinter.instance;

    bool? isConnected = await bluetooth.isConnected;

    if (isConnected != true) {
      if (selectedPrinter == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No hay impresora seleccionada")),
        );
        return;
      }

      try {
        await bluetooth.connect(selectedPrinter!);
        await Future.delayed(const Duration(seconds: 1));
        isConnected = await bluetooth.isConnected;
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("No se pudo conectar con la impresora.")),
        );

        return;
      }
    }

    if (isConnected == true) {
      try {
        imprimirContenido(bluetooth);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ocurrió un error al imprimir.")),
        );
      }
    }
  }
}
