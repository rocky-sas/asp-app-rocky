import 'package:flutter/material.dart';
import 'package:rocky_offline_sdk/screens/auth/device_registration_screen.dart';
import 'package:rocky_offline_sdk/screens/home/home_screen.dart';
import 'package:rocky_offline_sdk/screens/SplashScreen.dart';

/// Punto de entrada principal de la aplicación Rocky Offline SDK.
/// Esta aplicación permite la gestión y consulta de pacientes en modo offline
/// con capacidades de validación de dispositivos y sincronización de datos.
void main() => runApp(const MyApp());

/// Widget raíz de la aplicación.
/// 
/// Define la configuración inicial de la aplicación, incluyendo:
/// * El título de la aplicación
/// * La desactivación del banner de debug
/// * La pantalla inicial [RegistroIPSScreen]
class MyApp extends StatelessWidget {
  /// Constructor con `Key` recomendado para widgets públicos.
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Consulta Offline',
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/form': (context) => FormScreen(),
      },
    );
  }
}
