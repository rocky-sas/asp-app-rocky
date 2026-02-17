/// Pantalla de búsqueda de pacientes para la aplicación Rocky Offline SDK.
///
/// Este archivo implementa una interfaz de usuario para buscar pacientes en
/// la base de datos CSV por su número de identificación. Permite a los usuarios
/// de las instituciones de salud (IPS) encontrar rápidamente pacientes
/// registrados en el sistema y acceder a sus detalles clínicos.
///
/// La pantalla verifica la validez de la licencia antes de realizar búsquedas,
/// y redirige al usuario si la licencia ha expirado.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:rocky_offline_sdk/screens/patients/patient_details_screen.dart';
import 'package:rocky_offline_sdk/services/auth_service.dart';
import 'package:rocky_offline_sdk/services/expiration_service.dart';
import '../../utils/csv_helper.dart';
import 'package:rocky_offline_sdk/common/custom_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

/// Pantalla para buscar pacientes por número de identificación.
///
/// Esta pantalla permite al usuario buscar pacientes específicos en la base de datos
/// utilizando su número de identificación. Al encontrar un paciente, navega a
/// la pantalla de detalles del paciente para mostrar su información completa.
///
/// Requiere un archivo CSV [dbFile] que contiene la base de datos de pacientes.
class BuscarPacienteScreen extends StatefulWidget {
  /// Archivo CSV que contiene la base de datos de pacientes.
  final File? dbFileRocky;
  final File? dbFileSigires;

  /// Crea una nueva instancia de la pantalla de búsqueda de pacientes.
  ///
  /// Requiere un [dbFile] que es el archivo CSV con la base de datos de pacientes.
  const BuscarPacienteScreen({
    super.key,
    this.dbFileRocky,
    this.dbFileSigires,
  });

  @override
  State<BuscarPacienteScreen> createState() => _BuscarPacienteScreenState();
}

/// Estado para la pantalla de búsqueda de pacientes.
///
/// Gestiona la lógica de búsqueda, validación de entrada y navegación
/// a la pantalla de detalles cuando se encuentra un paciente.
class _BuscarPacienteScreenState extends State<BuscarPacienteScreen> {
  /// Controlador para el campo de texto donde se ingresa el número de identificación.
  final TextEditingController _controller = TextEditingController();

  /// Mensaje de error que se muestra cuando ocurre un problema durante la búsqueda.
  String? error;

  @override
  void initState() {
    super.initState();
    _checkExpiration();
    cargarDatos();
  }

  /// Verifica si la licencia de la aplicación ha expirado.
  ///
  /// Este método se ejecuta automáticamente al iniciar la pantalla.
  /// Si la licencia ha expirado, redirige al usuario a la pantalla de formulario
  /// para solicitar una nueva licencia.
  ///
  /// Utiliza [ExpirationService] para verificar el estado de la licencia.
  Future<void> _checkExpiration() async {
    final expired =
        await ExpirationService.verificarYMostrarExpiracion(context);

    if (!mounted) return;

    if (expired == true) {
      Navigator.pushReplacementNamed(context, '/form');
      mostrarMensajeModal(
        context,
        mensaje: "Las bases de datos de Rocky y Sigires han expirado.",
        titulo: "Base de datos expirada",
        tipo: TipoMensaje.error,
      );
    }
  }

  /// Busca un paciente por su número de identificación en la base de datos.
  ///
  /// Este método realiza el siguiente proceso:
  /// 1. Verifica que la licencia no haya expirado
  /// 2. Valida que se haya ingresado un número de identificación
  /// 3. Busca el paciente en la base de datos CSV
  /// 4. Si encuentra el paciente, navega a la pantalla de detalles
  /// 5. Si no lo encuentra o hay un error, muestra un mensaje apropiado
  ///
  /// La búsqueda se realiza utilizando [CsvHelper] para consultar el archivo CSV.
  void buscarPaciente() async {
    try {
      final expired =
          await ExpirationService.verificarYMostrarExpiracion(context);

      if (!mounted) return; // 🔥 IMPORTANTE

      if (expired) {
        return;
      }
    } catch (e) {
      debugPrint('Error checking expiration: $e');
      return;
    }

    final id = _controller.text.trim();
    if (id.isEmpty) {
      print('[BuscarPaciente] ID vacío');
      return;
    }

    // print('[BuscarPaciente] Buscando paciente con ID: $id');

    try {
      Map<String, dynamic>? pacienteRocky;
      Map<String, dynamic>? pacienteSigires;

      if (widget.dbFileRocky != null) {
        pacienteRocky =
            await CsvHelper.getPacienteById(id, widget.dbFileRocky!);
      }

      if (widget.dbFileSigires != null) {
        pacienteSigires =
            await CsvHelper.getPacienteByIdSigires(id, widget.dbFileSigires!);
      }

      if (pacienteRocky == null && pacienteSigires == null) {
        // print('[BuscarPaciente] No encontrado en ninguna base');
        setState(() {
          error = "Paciente no encontrado";
        });
        mostrarMensajeModal(
          context,
          mensaje: "Paciente no encontrado en las bases de datos cargadas.",
          titulo: "Error",
          tipo: TipoMensaje.error,
        );
        return;
      }

      setState(() {
        error = null;
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetallePacienteScreen(
            pacienteRocky: pacienteRocky,
            pacienteSIGIRES: pacienteSigires,
          ),
        ),
      );

      _controller.clear();
    } catch (e, stack) {
      // print('[BuscarPaciente][ERROR] $e');
      // print('[BuscarPaciente][STACK] $stack');
      setState(() {
        error = "Error al acceder a la base de datos";
      });
    }
  }

  /// Construye la interfaz de usuario para la pantalla de búsqueda de pacientes.
  ///
  /// La interfaz incluye:
  /// - Una barra superior con botones de navegación y cierre de sesión
  /// - Un logo de la aplicación
  /// - Un título y descripción de la funcionalidad
  /// - Un campo de texto para ingresar el número de identificación
  /// - Un botón para iniciar la búsqueda
  /// - Un área para mostrar mensajes de error si ocurren
  ///
  /// La UI está diseñada con un estilo consistente con el resto de la aplicación,
  /// utilizando el color azul principal (#007BFF) como tema.
  String? dateSaveDBSigires;
  String? dateSaveDBRocky;
  Future<void> cargarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      dateSaveDBSigires = prefs.getString("dateSaveDBSigires");
      dateSaveDBRocky = prefs.getString("dateSaveDBRocky");
    });
  }

  String calcularDias(String fecha) {
    DateTime fechaBD = DateFormat('dd/MM/yyyy').parse(fecha);
    int dias = DateTime.now().difference(fechaBD).inDays;

    if (dias == 0) return "(hoy)";
    if (dias == 1) return "(hace 1 día)";
    return "(hace $dias días)";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF007BFF),
      body: SafeArea(
        child: Column(
          children: [
            // AppBar personalizado
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
                      children: [
                        Image.asset(
                          'assets/images/imagenInicio.png',
                          width: 80,
                          height: 80,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Búsqueda de pacientes",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Ingresa el número de documento del paciente para buscar su información",
                          style: TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 24),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "Número de documento del paciente",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _controller,
                          keyboardType: TextInputType.text,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.person),
                            hintText: 'Ej: 1057000000, etc.',
                            hintStyle: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Presiona en buscar para filtrar la información del paciente",
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: buscarPaciente,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: const Color(0xFF007BFF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              "Buscar paciente",
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 16),
                          Text(error!,
                              style: const TextStyle(color: Colors.red)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                dateSaveDBRocky != null
                    ? "Fecha de cargue BD sistema: $dateSaveDBRocky ${calcularDias(dateSaveDBRocky!)}"
                    : "Fecha de cargue BD sistema: No disponible",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 4),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                dateSaveDBSigires != null
                    ? "Fecha de cargue BD SIGIRES: $dateSaveDBSigires ${calcularDias(dateSaveDBSigires!)}"
                    : "Fecha de cargue BD SIGIRES: No disponible",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              "Rocky • Versión 1.1",
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
