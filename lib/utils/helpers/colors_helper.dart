import 'package:flutter/material.dart';

class ColorHelper {

  static Color fromHex(String hex) {
    final buffer = StringBuffer();

    // Si viene con #
    hex = hex.replaceAll('#', '');

    // Si no trae alpha, agregamos FF (opacidad completa)
    if (hex.length == 6) {
      buffer.write('FF');
    }

    buffer.write(hex);

    return Color(int.parse(buffer.toString(), radix: 16));
  }

}
