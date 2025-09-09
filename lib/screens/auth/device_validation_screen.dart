import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:rocky_offline_sdk/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pantalla de validación de contraseña del dispositivo.
/// 
/// Esta pantalla maneja el proceso de validación de la clave generada para el dispositivo
/// después del registro inicial de la IPS. Es la segunda etapa en el flujo de autenticación
/// y seguridad del sistema.
/// 
/// Funcionalidades principales:
/// * Validación de la clave del dispositivo contra el servidor de autenticación
/// * Almacenamiento seguro de la información de validación en SharedPreferences
/// * Extracción y almacenamiento de datos adicionales como el número de teléfono
/// * Redirección automática a la pantalla de login si ya está validado
/// * Manejo de errores y retroalimentación visual al usuario
/// 
/// Flujo de trabajo:
/// 1. Al iniciar, verifica si el dispositivo ya ha sido validado previamente
/// 2. Si no está validado, muestra la interfaz para ingresar la clave de validación
/// 3. Al enviar la clave, se comunica con el servidor para validarla
/// 4. Procesa la respuesta y almacena localmente los datos de validación
/// 5. Redirige al usuario a la pantalla de login cuando la validación es exitosa
class ValidarContrasenaScreen extends StatefulWidget {
  const ValidarContrasenaScreen({super.key});

  @override
  State<ValidarContrasenaScreen> createState() =>
      _ValidarContrasenaScreenState();
}

class _ValidarContrasenaScreenState extends State<ValidarContrasenaScreen> {
  /// Controlador para el campo de texto de la contraseña de validación
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _verificarValidacion();
  }

  /// Verifica si el dispositivo ya ha sido validado previamente.
  /// 
  /// Este método consulta las preferencias compartidas para determinar
  /// si el dispositivo ya ha completado el proceso de validación.
  /// Si encuentra que el dispositivo está validado (device_validated = true), 
  /// redirige automáticamente a la pantalla de login, evitando pasos redundantes.
  /// 
  /// La verificación del estado de montaje (mounted) previene errores de navegación
  /// si el widget ya no está activo en la jerarquía de widgets.
  Future<void> _verificarValidacion() async {
    final prefs = await SharedPreferences.getInstance();
    final isValidated = prefs.getBool('device_validated') ?? false;

    if (isValidated && mounted) {

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }


  /// Valida la clave ingresada contra el servidor de autenticación.
  /// 
  /// Proceso completo de validación:
  /// 1. Recupera la información del dispositivo (código IPS y ID) de las preferencias
  /// 2. Valida que se haya ingresado una clave
  /// 3. Envía una solicitud POST al endpoint de validación de clave
  /// 4. Procesa la respuesta del servidor:
  ///    - Si es exitosa (200): 
  ///      * Almacena la respuesta completa en 'device_validation'
  ///      * Guarda la clave usada para validación futura
  ///      * Establece el flag 'device_validated' como true
  ///      * Extrae y almacena el número telefónico si está disponible
  ///      * Redirige a la pantalla de login
  ///    - Si falla: Muestra un mensaje de error apropiado
  /// 
  /// La función implementa verificaciones para:
  /// - Asegurar que exista información previa del dispositivo
  /// - Validar que el campo de clave no esté vacío
  /// - Verificar el estado de montaje del widget antes de actualizar la UI
  /// - Manejar errores de red y respuestas inesperadas del servidor
  Future<void> _validarClave() async {
    final prefs = await SharedPreferences.getInstance();
    final codIPS = prefs.getString('cod_ips');
    final deviceId = prefs.getString('device_id');

    if (codIPS == null || deviceId == null) {
      if (!mounted) return;
      await mostrarMensajeModal(context, 'Datos de dispositivo no encontrados',
          exito: false);
      return;
    }

    final clave = _passwordController.text.trim();
    if (clave.isEmpty) {
      if (!mounted) return;
      await mostrarMensajeModal(context, 'Por favor ingresa la clave',
          exito: false);
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(
            "https://b-rocky-intranet.onrender.com/api/v1/validate_key_device"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(
            {"cod_ips": codIPS, "device_id": deviceId, "key": clave}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Imprimir el JSON completo que se guarda
        print('JSON guardado en device_validation:');
        print(const JsonEncoder.withIndent('  ').convert(data));

        await prefs.setString('device_validation', jsonEncode(data));
        // Guardar la clave para verificaciones futuras
        await prefs.setString('device_key', clave);
        await prefs.setBool('device_validated', true);
        // Guardar el phone_number por separado
        if (data['phone_number'] != null) {
          await prefs.setString('phone_number', data['phone_number'].toString());
        }

        if (!mounted) return;
        await mostrarMensajeModal(
            context, data["mensaje"] ?? 'Validación exitosa',
            exito: true);

        _passwordController.clear();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        try {
          if (!mounted) return;
          final errorData = jsonDecode(response.body);
          final mensajeError = errorData['mensaje'] ?? 'Error desconocido';
          await mostrarMensajeModal(context, mensajeError, exito: false);
        } catch (_) {
          if (!mounted) return;
          await mostrarMensajeModal(context, 'Error: ${response.body}',
              exito: false);
        }
      }
    } catch (e) {
      if (!mounted) return;
      await mostrarMensajeModal(context, 'Error: $e', exito: false);
    }
  }

  /// Muestra un diálogo modal con un mensaje personalizado.
  /// 
  /// Esta función crea y presenta un diálogo modal centralizado con un diseño
  /// consistente que incluye:
  /// - Un icono (check para éxito, error para fallo)
  /// - Un mensaje personalizado
  /// - Un botón de cierre
  /// 
  /// Parámetros:
  /// - [context]: El BuildContext para mostrar el diálogo
  /// - [mensaje]: El texto a mostrar en el diálogo
  /// - [exito]: Booleano que determina si se muestra un icono de éxito (true) o error (false)
  ///
  /// El diálogo utiliza una interfaz visual consistente con el diseño general de
  /// la aplicación y presenta una experiencia modal para centrar la atención del usuario
  /// en el mensaje mostrado.
  Future<void> mostrarMensajeModal(BuildContext context, String mensaje,
      {bool exito = true}) {
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
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    exito ? Icons.check_circle_outline : Icons.error_outline,
                    color: exito ? Colors.green : Colors.red,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    mensaje,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
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
                    onPressed: () => Navigator.of(context).pop(),
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

  /// Construye la interfaz de usuario para la pantalla de validación.
  /// 
  /// Estructura de la UI:
  /// - Fondo con color azul corporativo
  /// - Contenedor central con bordes redondeados y sombra
  /// - Logo de la aplicación
  /// - Título "Validar dispositivo" y texto explicativo
  /// - Campo para ingresar la clave de validación
  /// - Sección de información con notas importantes sobre la responsabilidad del usuario
  /// - Botón de acción "Guardar y continuar"
  /// 
  /// El diseño implementa:
  /// - Restricciones de tamaño máximo para mejor visualización en distintos dispositivos
  /// - ScrollView para asegurar compatibilidad con pantallas pequeñas
  /// - Diseño visual consistente con la identidad corporativa (colores, bordes, sombras)
  /// - Componentes de UI organizados para facilitar la comprensión y uso
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF007BFF),
      body: Center(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
            maxWidth: 400,
          ),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/imagenInicio.png',
                  width: 80,
                  height: 80,
                ),
                const SizedBox(height: 16),
                const Text(
                  "Validar dispositivo",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,color: Colors.black,),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Ingrese la clave enviada para registrar este dispositivo.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: "Contraseña recibida",
                    prefixIcon: const Icon(Icons.vpn_key_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.grey),
                          SizedBox(width: 6),
                          Text(
                            "Información",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      SizedBox(height: 15),
                      Text(
                          " - El uso de esta clave es responsabilidad del usuario del dispositivo")
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: const Color(0xFF007BFF),
                    ),
                    onPressed: _validarClave,
                    child: const Text(
                      "Guardar y continuar",
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
