import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:rocky_offline_sdk/screens/home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pantalla de inicio de sesión para validar acceso a la aplicación.
///
/// Esta pantalla permite al usuario ingresar una contraseña previamente
/// registrada en el dispositivo. La validación se realiza contra los datos
/// almacenados en `SharedPreferences`.
///
/// ### Características principales:
/// - Entrada de contraseña con opción de mostrar/ocultar.
/// - Validación de credenciales almacenadas localmente.
/// - Mensajes de error o éxito mediante modales y SnackBars.
/// - Redirección automática a la pantalla principal (`FormScreen`) en caso de éxito.
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// Muestra un mensaje modal con estilo de éxito o error.
///
/// - [mensaje]: texto principal que se mostrará.
/// - [exito]: si es `true`, se mostrará un ícono verde de éxito;
///   en caso contrario, un ícono rojo de error.
/// - [mostrarSubtitulo]: si es `true`, mostrará un subtítulo adicional.
/// - [subtitulo]: texto opcional que aparece debajo del mensaje principal.
class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;
  bool _passwordVisible = false;

  Future<void> mostrarMensajeModal(
    BuildContext context,
    String mensaje, {
    bool exito = true,
    bool mostrarSubtitulo = false,
    String? subtitulo,
  }) {
    return showDialog(
      context: context,
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    exito ? Icons.check_circle_outline : Icons.error_outline,
                    color: exito ? Colors.green : Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    mensaje,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (mostrarSubtitulo && subtitulo != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      subtitulo,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007BFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Continuar',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Inicia el proceso de autenticación del usuario.
  ///
  /// Flujo de validación:
  /// 1. Verifica que el campo de contraseña no esté vacío.
  /// 2. Recupera los datos de validación almacenados en `SharedPreferences`.
  /// 3. Compara la contraseña ingresada con la guardada en el dispositivo.
  /// 4. Si es correcta, muestra un modal de bienvenida y navega a `FormScreen`.
  /// 5. Si falla, muestra mensajes de error mediante `SnackBar`.
  Future<void> _iniciarSesion() async {
    setState(() => _isLoading = true);
    try {
      final inputPassword = passwordController.text.trim();
      if (inputPassword.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor ingresa tu contraseña')),
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final storedData = prefs.getString('device_validation');

      if (storedData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error: No hay datos de validación")),
        );
        return;
      }

      final data = jsonDecode(storedData);
      if (data["password"] != inputPassword) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Contraseña incorrecta")),
        );
        return;
      }

      // Acceso concedido, mostrar mensaje de bienvenida
      if (!mounted) return;

      // Obtener el nombre de la IPS del JSON guardado
      final nombreIPS = data['name_ips'] ?? 'Usuario';

      await mostrarMensajeModal(
        context,
        '¡Bienvenido!\n\n$nombreIPS',
        mostrarSubtitulo: true,
        subtitulo: 'Sesión iniciada correctamente',
      );

      // Navegar al FormScreen
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => FormScreen()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al verificar la contraseña")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF007BFF),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Container(
                  width: 600,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/imagenInicio.png',
                        width: 80,
                        height: 80,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Iniciar sesión',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Ingresa la contraseña proporcionada para validar tu acceso',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Contraseña',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: passwordController,
                        obscureText: !_passwordVisible,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock),
                          hintText: 'Ingresa tu contraseña',
                          hintStyle: const TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _passwordVisible
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _passwordVisible = !_passwordVisible;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _iniciarSesion,
                          child: const Text('Iniciar sesión'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF007BFF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(fontSize: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
