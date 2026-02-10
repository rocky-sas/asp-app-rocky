import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:rocky_offline_sdk/screens/auth/device_validation_screen.dart';
import 'package:rocky_offline_sdk/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocky_offline_sdk/utils/helpers/network_helper.dart';

/// Pantalla de registro de Instituciones Prestadoras de Servicios de Salud (IPS).
///
/// Esta pantalla permite el registro inicial de una IPS en el dispositivo móvil.
/// La pantalla solicita al usuario ingresar un código de IPS válido para registrar
/// la aplicación en el sistema de validación de dispositivos.
///
/// Funcionalidades principales:
/// * Registro del código de IPS proporcionado por el proveedor
/// * Validación del dispositivo contra el servidor de autenticación
/// * Generación de clave única de registro para el dispositivo
/// * Almacenamiento seguro de credenciales en SharedPreferences
/// * Redirección automática a pantalla de login si el dispositivo ya está validado
///
/// Flujo de trabajo:
/// 1. Al iniciar, verifica si el dispositivo ya está validado
/// 2. Si no está validado, muestra el formulario para ingresar código IPS
/// 3. Al registrar, envía los datos del dispositivo al servidor
/// 4. Recibe una clave generada que se almacena localmente
/// 5. Redirige a la pantalla de validación de contraseña
class RegistroIPSScreen extends StatefulWidget {
  const RegistroIPSScreen({Key? key}) : super(key: key);

  @override
  State<RegistroIPSScreen> createState() => _RegistroIPSScreenState();
}

class _RegistroIPSScreenState extends State<RegistroIPSScreen> {
  /// Controlador para el campo de texto del código IPS
  final TextEditingController codIPSController = TextEditingController();

  /// Indicador de estado de carga para mostrar retroalimentación visual
  bool cargando = false;

  @override
  void initState() {
    super.initState();
    _verificarValidacion();
  }

  /// Verifica si ya hay una validación guardada en SharedPreferences.
  ///
  /// Este método se ejecuta al iniciar la pantalla y comprueba si existe
  /// información de validación previa en el almacenamiento local del dispositivo.
  /// Si encuentra datos válidos (is_valid = "True"), redirige automáticamente
  /// a la pantalla de login sin solicitar nuevamente el registro.
  ///
  /// El flujo contempla la verificación del estado de montaje del widget
  /// para evitar errores de navegación cuando el componente ya no está montado.
  Future<void> _verificarValidacion() async {
    final prefs = await SharedPreferences.getInstance();
    final storedData = prefs.getString('device_validation');

    if (storedData != null) {
      final data = jsonDecode(storedData);
      if (data["is_valid"] == "True") {
        // Ya está validado, ir directo a FormScreen
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  /// Obtiene el identificador único del dispositivo.
  ///
  /// Utiliza el plugin DeviceInfoPlus para recuperar el ID único del dispositivo
  /// según la plataforma en la que se ejecute la aplicación:
  /// - En Android: Retorna el ID único del dispositivo Android
  /// - En iOS: Retorna el identificador único para vendedor (IDFV)
  /// - En otras plataformas: Retorna "unknown"
  ///
  /// Este identificador se utiliza para el registro y validación del dispositivo
  /// en el servidor, funcionando como parte de la clave de autenticación.
  Future<String> _obtenerDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? "unknown";
    }
    return "unknown";
  }

  /// Obtiene el nombre legible del dispositivo.
  ///
  /// Recopila información sobre el modelo y fabricante del dispositivo para
  /// mostrar un nombre amigable en el sistema:
  /// - En Android: Combina el fabricante y modelo (ej. "Samsung Galaxy S21")
  /// - En iOS: Utiliza el nombre de la máquina del sistema operativo
  /// - En otras plataformas: Retorna "Unknown Device"
  ///
  /// Este nombre se envía al servidor durante el registro para identificar
  /// visualmente el dispositivo en el panel de administración.
  Future<String> _obtenerDeviceName() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return "${androidInfo.manufacturer} ${androidInfo.model}";
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      // Corregimos el operador nulo ya que utsname.machine no puede ser nulo
      return iosInfo.utsname.machine;
    }
    return "Unknown Device";
  }

  /// Registra la aplicación con el servidor backend mediante una API REST.
  ///
  /// Proceso completo de registro:
  /// 1. Valida que se haya ingresado un código IPS
  /// 2. Obtiene información del dispositivo (ID y nombre)
  /// 3. Envía petición POST al endpoint de generación de clave
  /// 4. Procesa la respuesta del servidor:
  ///    - Si es exitosa (201): Almacena localmente el código IPS, ID del dispositivo
  ///      y la clave generada por el servidor. Luego redirige a la pantalla de validación.
  ///    - Si falla: Muestra un mensaje de error apropiado.
  ///
  /// Durante el proceso se actualiza el estado de carga (cargando) para
  /// proporcionar retroalimentación visual al usuario.
  ///
  /// La función implementa manejo de errores para problemas de red, respuestas
  /// inesperadas del servidor y verifica el estado de montaje del widget para
  /// evitar actualizar el estado cuando el componente ya no está montado.
  Future<void> _registrarAplicacion() async {
    final codIPS = codIPSController.text.trim();
    if (codIPS.isEmpty) {
      await mostrarMensajeModal(context, 'Por favor ingresa el código IPS',
          exito: false);
      return;
    }

    final hasInternet = await NetworkHelper.hasInternet();
    if (!hasInternet) {
      await mostrarMensajeModal(
        context,
        'No hay conexión a internet, verifica tu red e intenta nuevamente.',
        exito: false,
      );
      return;
    }

    setState(() => cargando = true);

    try {
      final deviceId = await _obtenerDeviceId();
      final deviceName = await _obtenerDeviceName();

      final body = {
        "device_name": deviceName,
        "device_id": deviceId,
        "cod_ips": codIPS
      };

      final response = await http.post(
        Uri.parse("http://192.168.1.185:8000/api/v1/view_generate_key_device"),
        // Uri.parse(
        //     "https://b-rocky-intranet.onrender.com/api/v1/view_generate_key_device"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final generatedKey = data['clave'] ?? '';

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cod_ips', codIPS);
        await prefs.setString('device_id', deviceId);
        await prefs.setString('generated_key', generatedKey);
        await prefs.setString('id_device_backend', data["id_device"].toString());

        await mostrarMensajeModal(context,
            'Aplicación registrada. Solicite contraseña a su proveedor',
            exito: true);

        codIPSController.clear();

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const ValidarContrasenaScreen(),
          ),
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
    } finally {
      setState(() => cargando = false);
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

  /// Construye la interfaz de usuario para la pantalla de registro.
  ///
  /// Estructura de la UI:
  /// - Fondo con color azul corporativo
  /// - Contenedor central con bordes redondeados
  /// - Logo de la aplicación
  /// - Título y subtítulo explicativo
  /// - Campo de texto para ingresar el código IPS
  /// - Botón de acción "Registrar aplicación"
  /// - Indicador de carga durante el proceso de registro
  ///
  /// El diseño implementa:
  /// - Diseño adaptable a diferentes tamaños de pantalla mediante SingleChildScrollView
  /// - Retroalimentación visual durante la carga (spinner en botón)
  /// - Estilo visual consistente con la identidad de la aplicación
  /// - Manejo de estados para mostrar/ocultar indicador de progreso
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF007BFF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 400,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
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
                      const Text(
                        'Registro de IPS',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        "Ingrese su código de IPS para registrar su aplicación",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: codIPSController,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.business),
                          hintText: 'Ingrese su código',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: cargando ? null : _registrarAplicacion,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF007BFF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: cargando
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text('Registrar aplicación'),
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // const Text(
                //   "Rocky App • Versión 1.0",
                //   style: TextStyle(color: Colors.white, fontSize: 12),
                // ),
                const Text(
                  "Rocky • Versión 1.1",
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
