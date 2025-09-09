import 'dart:async';
import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'package:rocky_offline_sdk/services/auth_service.dart';
import 'package:rocky_offline_sdk/services/database_service.dart';
import 'package:rocky_offline_sdk/utils/bluetooth_printer_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Pantalla de detalle de paciente con capacidades de impresión Bluetooth.
///
/// Esta pantalla muestra la información detallada de un paciente seleccionado y permite:
/// * Visualizar datos personales y demográficos del paciente
/// * Ver actividades y laboratorios pendientes según la Resolución 3280
/// * Imprimir la información mediante una impresora térmica Bluetooth
/// * Enviar la información por WhatsApp al paciente
/// * Gestionar la conexión con dispositivos Bluetooth
/// 
/// Características principales:
/// * Interfaz clara y organizada para visualizar todos los datos del paciente
/// * Manejo completo del ciclo de vida de conexiones Bluetooth
/// * Solicitud y gestión automática de permisos necesarios
/// * Impresión de comprobantes con formato personalizado
/// * Marcado automático del paciente como contactado en la base de datos
/// * Capacidad para enviar información por WhatsApp
/// 
/// El diseño implementa:
/// * Gestión de estados para mostrar progreso de acciones
/// * Manejo de errores y reconexión con dispositivos Bluetooth
/// * Retroalimentación visual clara sobre el estado de la conexión
class DetallePacienteScreen extends StatefulWidget {
  final Map<String, dynamic> paciente;

  const DetallePacienteScreen({Key? key, required this.paciente})
      : super(key: key);

  @override
  _DetallePacienteScreenState createState() => _DetallePacienteScreenState();
}

class _DetallePacienteScreenState extends State<DetallePacienteScreen>
    with WidgetsBindingObserver {
  /// Instancia del controlador Bluetooth para impresoras térmicas
  final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  
  /// Dispositivo Bluetooth seleccionado para la impresión
  BluetoothDevice? selectedPrinter;
  
  /// Bandera que indica si la conexión con el dispositivo Bluetooth falló
  bool _conexionFallida = false;
  
  /// Bandera que indica si hay una conexión activa con un dispositivo Bluetooth
  bool _bluetoothConectado = false;
  
  /// Bandera que indica si se está ejecutando un proceso de impresión
  bool _isPrinting = false;
  
  /// Suscripción al stream de cambios de estado del Bluetooth
  StreamSubscription<int?>? _btStateSubscription;

  /// Muestra un diálogo modal con dos acciones posibles.
  /// 
  /// Este método crea y presenta un diálogo modal con opciones de acciones
  /// primaria y secundaria, permitiendo al usuario tomar decisiones sobre
  /// operaciones relacionadas con el Bluetooth u otras funcionalidades.
  /// 
  /// Parámetros:
  /// - [context]: El BuildContext para mostrar el diálogo
  /// - [mensaje]: El texto detallado a mostrar en el diálogo
  /// - [titulo]: Título opcional para el diálogo
  /// - [accionPrimaria]: Función a ejecutar cuando se selecciona la acción primaria
  /// - [textoPrimario]: Texto para el botón de acción primaria
  /// - [textoSecundario]: Texto para el botón de acción secundaria
  /// - [mostrarIcono]: Indica si se debe mostrar un icono de Bluetooth
  ///
  /// Retorna un Future<bool?> que será true si el usuario selecciona la acción primaria,
  /// false si selecciona la acción secundaria, o null si cierra el diálogo sin seleccionar.
  Future<bool?> mostrarMensajeModalAcciones({
    required BuildContext context,
    required String mensaje,
    String? titulo,
    required Function() accionPrimaria,
    required String textoPrimario,
    required String textoSecundario,
    bool mostrarIcono = true,
  }) {
    return showDialog<bool>(
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
                  if (mostrarIcono) ...[
                    const Icon(
                      Icons.bluetooth,
                      color: Color(0xFF007BFF),
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (titulo != null) ...[
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    mensaje,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[200],
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(textoSecundario),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF007BFF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context, true);
                            accionPrimaria();
                          },
                          child: Text(textoPrimario),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Verifica el estado inicial de la conexión Bluetooth.
  /// 
  /// Este método se ejecuta al iniciar la pantalla y:
  /// 1. Comprueba si hay una conexión activa con una impresora Bluetooth
  /// 2. Configura un listener para detectar cambios en el estado del Bluetooth
  /// 3. Actualiza el estado de la UI según el estado de la conexión
  /// 4. Intenta reconectar automáticamente si hay una impresora seleccionada previamente
  ///
  /// El método maneja posibles errores durante la verificación y evita
  /// actualizar el estado si el widget ya no está montado.
  Future<void> _checkInitialBluetoothState() async {
    try {
      // Verificar la conexión actual
      final isConnected = await bluetooth.isConnected ?? false;

      // Inicializar el listener de estado del bluetooth
      _btStateSubscription?.cancel();
      _btStateSubscription = bluetooth.onStateChanged().listen((state) async {
        if (mounted) {
          // Verificar el estado real de la conexión
          final actuallyConnected = await bluetooth.isConnected ?? false;
          setState(() {
            _bluetoothConectado = actuallyConnected;
            _conexionFallida = !actuallyConnected;
          });
        }
      });

      if (mounted) {
        setState(() {
          _bluetoothConectado = isConnected;
          _conexionFallida = !isConnected;
        });
      }

      // Si no está conectado pero hay una impresora seleccionada, intentar reconectar
      if (!isConnected && selectedPrinter != null) {
        await _initBluetooth(mostrarDialogo: false);
      }
    } catch (e) {
      debugPrint("Error al verificar estado inicial del bluetooth: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    // Registrar este widget como observador del ciclo de vida de la aplicación
    WidgetsBinding.instance.addObserver(this);

    // Verificar estado inicial de la conexión
    _checkInitialBluetoothState();
  }

  @override
  void dispose() {
    // Cancelar la suscripción al stream de estado Bluetooth para evitar memory leaks
    _btStateSubscription?.cancel();
    // Eliminar este widget como observador del ciclo de vida
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Responde a cambios en el ciclo de vida de la aplicación.
  /// 
  /// Este método se llama automáticamente cuando cambia el estado del ciclo de vida
  /// de la aplicación. Es especialmente útil para gestionar la conexión Bluetooth
  /// cuando la aplicación pasa a segundo plano y vuelve a primer plano.
  /// 
  /// Cuando la aplicación vuelve a primer plano (resumed):
  /// 1. Verifica el estado actual de la conexión Bluetooth
  /// 2. Intenta reconectar con la impresora seleccionada si es necesario
  /// 3. Actualiza el estado de la UI según el resultado de la reconexión
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      // Verificar estado de conexión al volver a la app
      await _checkInitialBluetoothState();

      // Si no está conectado pero hay una impresora seleccionada, intentar reconectar
      if (!_bluetoothConectado && selectedPrinter != null) {
        await _initBluetooth(mostrarDialogo: false);
        final isConnected = await bluetooth.isConnected ?? false;
        if (mounted) {
          setState(() {
            _bluetoothConectado = isConnected;
            _conexionFallida = !isConnected;
          });
        }
      }
    }
  }

  /// Solicita los permisos necesarios para el funcionamiento de Bluetooth.
  ///
  /// Solicita los siguientes permisos:
  /// - Bluetooth (para comunicación general)
  /// - Bluetooth Connect (para establecer conexiones)
  /// - Bluetooth Scan (para buscar dispositivos)
  /// - Location (necesario en algunas versiones de Android para escaneo Bluetooth)
  ///
  /// @return Future que completa cuando finaliza la solicitud de permisos
  Future<void> pedirPermisosBluetooth() async {
    await Permission.bluetooth.request();
    await Permission.bluetoothConnect.request();
    await Permission.bluetoothScan.request();
    await Permission.location.request();
  }

  /// Inicializa la conexión Bluetooth y configura los dispositivos disponibles.
  /// 
  /// Este método realiza el proceso completo de conexión Bluetooth:
  /// 1. Verifica si ya existe una conexión activa
  /// 2. Solicita los permisos necesarios para Bluetooth
  /// 3. Comprueba la disponibilidad y estado del Bluetooth
  /// 4. Configura listeners para cambios de estado
  /// 5. Intenta reconectar con el dispositivo anteriormente seleccionado
  /// 6. Muestra un selector de dispositivos si es necesario
  /// 
  /// @param mostrarDialogo Si es true, permite mostrar un selector de dispositivos
  /// @return Future que completa cuando finaliza el proceso de inicialización
  Future<void> _initBluetooth({bool mostrarDialogo = true}) async {
    try {
      // Verificar conexión actual primero
      final isCurrentlyConnected = await bluetooth.isConnected ?? false;
      if (isCurrentlyConnected) {
        if (mounted) {
          setState(() {
            _bluetoothConectado = true;
            _conexionFallida = false;
          });
        }
        return;
      }

      // Solicitar permisos necesarios para el funcionamiento de Bluetooth
      await pedirPermisosBluetooth();

      // Verificar disponibilidad y estado del Bluetooth
      bool? isAvailable = await bluetooth.isAvailable;
      bool? isOn = await bluetooth.isOn;
      if (isAvailable != true) return;
      if (isOn != true) {
        AppSettings.openAppSettings(type: AppSettingsType.bluetooth);
        return;
      }

      _btStateSubscription?.cancel();
      _btStateSubscription = bluetooth.onStateChanged().listen((state) {
        if (mounted) {
          setState(() {
            _bluetoothConectado = (state == BlueThermalPrinter.CONNECTED);
            _conexionFallida = !_bluetoothConectado;
          });
        }
      });

      bool isConnected = await bluetooth.isConnected ?? false;

      if (!isConnected) {
        if (selectedPrinter != null) {
          // Intentar reconectar sin selector
          try {
            await bluetooth.connect(selectedPrinter!);
            await Future.delayed(const Duration(seconds: 2));
            isConnected = await bluetooth.isConnected ?? false;
            setState(() {
              _bluetoothConectado = isConnected;
              _conexionFallida = !isConnected;
            });
            if (isConnected) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Conexión Bluetooth exitosa")),
              );
            }
            return;
          } catch (e) {
            debugPrint("Error al reconectar impresora guardada: $e");
            selectedPrinter = null;
            setState(() {
              _bluetoothConectado = false;
              _conexionFallida = true;
            });
          }
        }

        // Si está permitido mostrar el selector y no hay impresora
        if (mostrarDialogo) {
          List<BluetoothDevice> devices = await bluetooth.getBondedDevices();
          if (devices.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("No hay dispositivos emparejados")),
              );
            }
            return;
          }

          selectedPrinter = await _seleccionarDispositivo(devices);
          if (selectedPrinter == null) return;

          try {
            await bluetooth.connect(selectedPrinter!);
            await Future.delayed(const Duration(seconds: 2));
          } catch (e) {
            debugPrint("Error al conectar impresora: $e");
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Conéctate a una impresora antes de imprimir."),
                ),
              );
            }
            return;
          }

          isConnected = await bluetooth.isConnected ?? false;
          setState(() {
            _bluetoothConectado = isConnected;
            _conexionFallida = !isConnected;
          });

          if (isConnected) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Conexión Bluetooth exitosa")),
            );
          }
        }
      } else {
        setState(() {
          _bluetoothConectado = true;
        });
      }
    } catch (e) {
      debugPrint("Error en _initBluetooth: $e");
    }
  }

  /// Muestra un diálogo para seleccionar un dispositivo Bluetooth de la lista disponible.
  ///
  /// Presenta una lista de dispositivos Bluetooth emparejados con el dispositivo,
  /// permitiendo al usuario seleccionar una impresora para conectarse.
  ///
  /// @param devices Lista de dispositivos Bluetooth emparejados disponibles
  /// @return Future que completa con el dispositivo seleccionado o null si se cancela
  Future<BluetoothDevice?> _seleccionarDispositivo(
    List<BluetoothDevice> devices,
  ) async {
    return await showDialog<BluetoothDevice>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            "Selecciona una impresora",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: devices.map((device) {
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: const Icon(Icons.print, color: Colors.blue),
                    title: Text(device.name ?? "Sin nombre"),
                    subtitle: Text(device.address ?? ""),
                    onTap: () {
                      Navigator.pop(context, device);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  /// Inicia el proceso de impresión de los datos del paciente.
  ///
  /// Este método realiza la siguiente secuencia de acciones:
  /// 1. Verifica si el Bluetooth está activado
  /// 2. Comprueba si hay una impresora conectada
  /// 3. Ofrece conectar una impresora si no hay ninguna
  /// 4. Formatea los datos del paciente para la impresión
  /// 5. Envía los datos formateados a la impresora térmica
  ///
  /// Se encarga de manejar casos como Bluetooth desactivado, impresora
  /// no conectada y errores durante la impresión.
  Future<void> _printPaciente() async {
    // Verificar si el Bluetooth está encendido
    bool? isOn = await bluetooth.isOn;
    if (isOn != true) {
      if (mounted) {
        mostrarMensajeModalAcciones(
          context: context,
          mensaje: 'El Bluetooth está apagado. ¿Desea activarlo?',
          titulo: 'Bluetooth Desactivado',
          accionPrimaria: () {
            Navigator.pop(context);
            AppSettings.openAppSettings(type: AppSettingsType.bluetooth);
          },
          textoPrimario: 'Activar',
          textoSecundario: 'Cancelar',
        );
      }
      return;
    }

    // Verificar si hay una impresora conectada
    bool isConnected = await bluetooth.isConnected ?? false;
    if (!isConnected) {
      if (mounted) {
        // Mostrar diálogo para conectar impresora
        bool? shouldConnect = await mostrarMensajeModalAcciones(
          context: context,
          titulo: 'Impresora no Conectada',
          mensaje: '¿Desea conectar una impresora?',
          accionPrimaria: () {},
          textoPrimario: 'Conectar',
          textoSecundario: 'Cancelar',
          mostrarIcono: false,
        );
        if (shouldConnect == true) {
          await _initBluetooth(mostrarDialogo: true);
          // Verificar de nuevo la conexión
          isConnected = await bluetooth.isConnected ?? false;
          if (!isConnected) return; // Si aún no está conectado, salir
        } else {
          return; // Si el usuario cancela, salir
        }
      }
    }

    final p = widget.paciente;
    // Formatea el sexo del paciente para la impresión (F o M)
    final sexoFormateado = (p['Sexo']?.toLowerCase() == 'f') ? 'F' : 'M';

    final printerHelper = BluetoothPrinterHelper(
      context: context,
      selectedPrinter: selectedPrinter,
    );

    await printerHelper.imprimirConSeguridadCustom((bluetooth) async {
      // Marcar el status como true en el CSV
      await DatabaseService.updatePatientStatus(
          widget.paciente['NumeroId'], true);

      bluetooth.printNewLine();
      bluetooth.printCustom("${p['name_ips'] ?? 'Desconocido'}", 1, 1);
      bluetooth.printCustom(
        "${p['name_municipality'] ?? 'N/A'} - ${p['name_department'] ?? 'N/A'}",
        1,
        1,
      );
      bluetooth.printNewLine();
      bluetooth.printCustom("ACTIVIDADES PENDIENTES RES.3280", 1, 1);
      bluetooth.printNewLine();
      bluetooth.printCustom("${p['Nombres']}", 1, 0);
      bluetooth.printCustom(
        "${p['TipoIdentificacion']}: ${p['NumeroId']}  NTO: ${p['FechaNto']}",
        1,
        0,
      );
      bluetooth.printCustom(
        "SEXO: $sexoFormateado    C.VIDA: ${p['CursoVida'] ?? 'Ninguna'}",
        1,
        0,
      );
      bluetooth.printCustom(
          normalizeText("EDAD: ${p['EdadAnos']}"), 1, 0);
      bluetooth.printNewLine();
      bluetooth.printCustom(
          normalizeText(
              "ACTIVIDADES: ${p['ActividadesPendientes'] ?? 'Ninguna'}"),
          1,
          0);
      bluetooth.printNewLine();
      bluetooth.printCustom(
          normalizeText(
              "LABORATORIOS: ${p['LaboratoriosPendientes'] ?? 'Ninguna'}"),
          1,
          0);

      bluetooth.printNewLine();
      final prefs = await SharedPreferences.getInstance();
      final phoneNumber = prefs.getString('phone_number') ?? 'Ninguno';
      bluetooth.printCustom(normalizeText("TEL CITAS: $phoneNumber"), 1, 0);
      bluetooth.printCustom(normalizeText("FECHA Y HORA CITA: "), 1, 0);
      bluetooth.printNewLine();
      bluetooth.printCustom(
          normalizeText("ROCKY S.A.S DERECHOS RESERVADOS"), 1, 0);

      for (int i = 0; i < 4; i++) {
        bluetooth.printNewLine();
      }
    });
  }

  /// Normaliza el texto reemplazando caracteres acentuados por sus equivalentes sin acento.
  /// 
  /// Este método es necesario porque algunas impresoras térmicas Bluetooth no 
  /// manejan correctamente los caracteres especiales o acentuados. Convierte
  /// caracteres como á, é, í, ó, ú, ñ a sus equivalentes sin acento (a, e, i, o, u, n).
  /// 
  /// @param input El texto original que puede contener caracteres acentuados
  /// @return El texto normalizado sin acentos
  String normalizeText(String input) {
    const replacements = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'Á': 'A',
      'É': 'E',
      'Í': 'I',
      'Ó': 'O',
      'Ú': 'U',
      'ñ': 'n',
      'Ñ': 'N',
      'ü': 'u',
      'Ü': 'U',
    };
    return input.split('').map((char) => replacements[char] ?? char).join();
  }

  String getFormattedText() {
    final p = widget.paciente;
    final sexoFormateado = (p['Sexo']?.toLowerCase() == 'f') ? 'F' : 'M';

    return """
${p['name_ips'] ?? 'Desconocido'}
${p['name_municipality'] ?? 'N/A'} - ${p['name_department'] ?? 'N/A'}

EVALUACION DE ACTIVIDADES PENDIENTES RES.3280

${p['TipoIdentificacion']}: ${p['NumeroId']}
${p['Nombres']}
TELEFONO: ${p['Telefono']}    SEXO: $sexoFormateado
EDAD: ${p['EdadAnos']}    NTO: ${p['FechaNto']}

CURSO DE VIDA: ${p['CursoVida'] ?? 'Ninguna'}

ACTIVIDADES: ${p['ActividadesPendientes'] ?? 'Ninguna'}

LABORATORIOS: ${p['LaboratoriosPendientes'] ?? 'Ninguna'}
""";
  }

  Future<void> _sendWhatsAppMessage() async {
    final phoneNumber = widget.paciente['Telefono']?.toString() ?? '';
    if (phoneNumber.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No hay número de teléfono disponible")),
        );
      }
      return;
    }

    final message = Uri.encodeComponent(getFormattedText());
    final url = "whatsapp://send?phone=$phoneNumber&text=$message";

    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
        // Marcar el status como true en el CSV después de abrir WhatsApp
        await DatabaseService.updatePatientStatus(
            widget.paciente['NumeroId'], true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No se pudo abrir WhatsApp")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al abrir WhatsApp: $e")),
        );
      }
    }
  }

  Widget buildCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32, color: Colors.blue),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black)),
                  const SizedBox(height: 6),
                  Text(content.isNotEmpty ? content : 'Sin datos',
                      style: const TextStyle(fontSize: 14)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.paciente;
    // No se usa actualmente, pero se podría utilizar en la UI para mostrar el sexo del paciente
    // final sexoFormateado = (p['Sexo']?.toLowerCase() == 'f') ? 'Femenino' : 'Masculino';

    return Scaffold(
      backgroundColor: const Color(0xFF007BFF),
      body: SafeArea(
        child: Column(
          children: [
            // Botón de regreso
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.arrow_back, color: Colors.black87),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.logout, color: Colors.black87),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
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
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/imagenInicio.png',
                              width: 80,
                              height: 80,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                (p['Nombres'] != null &&
                                        p['Nombres']
                                            .toString()
                                            .trim()
                                            .isNotEmpty)
                                    ? p['Nombres'].toString()
                                    : "N/A",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            // Primera columna
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Tipo y número de identificación
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: (p['TipoIdentificacion'] !=
                                                      null &&
                                                  p['TipoIdentificacion']
                                                      .toString()
                                                      .trim()
                                                      .isNotEmpty)
                                              ? p['TipoIdentificacion']
                                                  .toString()
                                              : "N/A",
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        TextSpan(
                                          text:
                                              " ${(p['NumeroId'] != null && p['NumeroId'].toString().trim().isNotEmpty) ? p['NumeroId'].toString() : "N/A"}",
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  // Edad
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        const TextSpan(
                                          text: "Edad: ",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        TextSpan(
                                          text: (p['EdadAnos'] != null &&
                                                  p['EdadAnos']
                                                      .toString()
                                                      .trim()
                                                      .isNotEmpty)
                                              ? p['EdadAnos'].toString()
                                              : "N/A",
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 4),
                                  // Sexo
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        const TextSpan(
                                          text: "Sexo: ",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        TextSpan(
                                          text:
                                              (p['Sexo']?.toLowerCase() == 'f')
                                                  ? 'F'
                                                  : 'M',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Segunda columna
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Fecha de nacimiento
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        const TextSpan(
                                          text: "Nto: ",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        TextSpan(
                                          text: (p['FechaNto'] != null &&
                                                  p['FechaNto']
                                                      .toString()
                                                      .trim()
                                                      .isNotEmpty)
                                              ? p['FechaNto'].toString()
                                              : "N/A",
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 4),
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        const TextSpan(
                                          text: "C.Vida: ",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        TextSpan(
                                          text: (p['CursoVida'] != null &&
                                                  p['CursoVida']
                                                      .toString()
                                                      .trim()
                                                      .isNotEmpty)
                                              ? p['CursoVida'].toString()
                                              : "N/A",
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 4),
                                  // Teléfono
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        const TextSpan(
                                          text: "Tel: ",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        TextSpan(
                                          text: (p['Telefono'] != null &&
                                                  p['Telefono']
                                                      .toString()
                                                      .trim()
                                                      .isNotEmpty)
                                              ? p['Telefono'].toString()
                                              : "N/A",
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        buildCard(
                          icon: Icons.task_alt,
                          title: "Actividades pendientes",
                          content: (p['ActividadesPendientes'] != null &&
                                  p['ActividadesPendientes']
                                      .toString()
                                      .trim()
                                      .isNotEmpty)
                              ? p['ActividadesPendientes'].toString()
                              : 'N/A',
                        ),
                        buildCard(
                          icon: Icons.biotech,
                          title: "Laboratorios pendientes",
                          content: (p['LaboratoriosPendientes'] != null &&
                                  p['LaboratoriosPendientes']
                                      .toString()
                                      .trim()
                                      .isNotEmpty)
                              ? p['LaboratoriosPendientes'].toString()
                              : 'N/A',
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isPrinting
                                ? null
                                : () async {
                                    setState(() {
                                      _isPrinting = true;
                                    });

                                    // Forzar a Flutter a renderizar el spinner antes de imprimir
                                    await Future.delayed(
                                        const Duration(milliseconds: 1000));

                                    try {
                                      await _printPaciente(); // IMPORTANTE: que sea async y espere todo
                                    } catch (_) {
                                      if (mounted) {
                                        showDialog(
                                          context: context,
                                          builder: (context) {
                                            return AlertDialog(
                                              title: const Text(
                                                  "Impresora no encontrada"),
                                              content: const Text(
                                                  "Conéctate a una impresora antes de imprimir."),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop(),
                                                  child: const Text("Cerrar"),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      }
                                    }

                                    if (mounted) {
                                      setState(() {
                                        _isPrinting = false;
                                      });
                                    }
                                  },
                            icon: _isPrinting
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.print),
                            label: Text(_isPrinting
                                ? 'Imprimiendo...'
                                : 'Imprimir información'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF007BFF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isPrinting
                                ? null
                                : () async {
                                    // Verificar estado actual antes de intentar reconectar
                                    final isConnected =
                                        await bluetooth.isConnected ?? false;
                                    if (isConnected && mounted) {
                                      setState(() {
                                        _bluetoothConectado = true;
                                        _conexionFallida = false;
                                      });
                                      return;
                                    }

                                    // Solo permitir reconexión si no hay conexión activa
                                    if (!_bluetoothConectado) {
                                      if (mounted) {
                                        setState(() {
                                          _conexionFallida = false;
                                        });
                                      }
                                      await _initBluetooth(
                                          mostrarDialogo: true);

                                      // Verificar el estado final de la conexión
                                      if (mounted) {
                                        final finalConnectionState =
                                            await bluetooth.isConnected ??
                                                false;
                                        setState(() {
                                          _bluetoothConectado =
                                              finalConnectionState;
                                          _conexionFallida =
                                              !finalConnectionState;
                                        });
                                      }
                                    }
                                  },
                            icon: _isPrinting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.refresh),
                            label: Text(_isPrinting
                                ? "Procesando..."
                                : "Reintentar conexión bluetooth"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _bluetoothConectado
                                  ? Colors.grey
                                  : Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _sendWhatsAppMessage,
                            icon: const Icon(Icons.share, color: Colors.white),
                            label: const Text("Enviar Información"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildExpandableCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Theme(
        data: ThemeData().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(icon, size: 32, color: Colors.blue),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.blue,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                content.isNotEmpty ? content : 'Sin datos',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
