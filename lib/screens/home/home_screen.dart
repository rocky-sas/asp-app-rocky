import 'package:flutter/material.dart';
import 'dart:io';
import 'package:rocky_offline_sdk/services/database_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rocky_offline_sdk/screens/home/database_import_screen.dart';
import 'package:rocky_offline_sdk/screens/patients/patient_search_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocky_offline_sdk/common/custom_modal.dart';

/// Pantalla principal de la aplicación que permite gestionar la base de datos de pacientes.
///
/// Esta pantalla es el punto central de la aplicación donde el usuario puede:
/// * Cargar una base de datos desde un archivo CSV externo
/// * Exportar la base de datos actual a un archivo CSV
/// * Acceder al módulo de búsqueda y gestión de pacientes
///
/// Características principales:
/// * Carga automática de la última base de datos utilizada al iniciar la aplicación
/// * Validación de la existencia y formato del archivo de base de datos
/// * Manejo de permisos de almacenamiento para importación/exportación
/// * Interfaz intuitiva con opciones claramente diferenciadas
/// * Almacenamiento persistente de la ruta del archivo CSV mediante SharedPreferences
///
/// Flujo de trabajo:
/// 1. Al iniciar, verifica si existe una base de datos previamente cargada
/// 2. Permite al usuario seleccionar entre cargar una nueva base de datos o acceder a la actual
/// 3. Realiza validaciones antes de permitir el acceso al módulo de pacientes
/// 4. Proporciona retroalimentación clara sobre el estado de las operaciones
class FormScreen extends StatefulWidget {
  @override
  _FormScreenState createState() => _FormScreenState();
}

/// Clave constante para almacenar la ruta del archivo CSV en SharedPreferences.
/// Esta clave se utiliza consistentemente en toda la aplicación para acceder
/// a la información de la ubicación del archivo de base de datos.
const String kRutaGuardadaKey = 'ruta_csv_guardada';
const String kRutaGuardadaKeySigires = 'ruta_csv_guardada_sigires';

/// Estado de la pantalla principal FormScreen que gestiona la lógica y UI
/// para la carga, validación y navegación de la base de datos de pacientes.
class _FormScreenState extends State<FormScreen> {
  /// Archivo CSV seleccionado que contiene la base de datos de pacientes.
  /// Este valor se mantiene en el estado para verificar si hay una base de datos cargada
  /// y facilitar su acceso en diferentes partes de la aplicación.
  File? archivoSeleccionado;

  @override
  void initState() {
    super.initState();
    _cargarRutaGuardada();
    _cargarRutaGuardadaSigires();
  }

  /// Intenta cargar la última base de datos utilizada desde SharedPreferences.
  ///
  /// Este método se ejecuta al iniciar la pantalla y verifica si existe una ruta
  /// guardada de una base de datos anterior. Si existe y el archivo está disponible,
  /// lo carga automáticamente.
  Future<void> _cargarRutaGuardada() async {
    final prefs = await SharedPreferences.getInstance();
    final rutaGuardada = prefs.getString(kRutaGuardadaKey);
    // print('[DEBUG] _cargarRutaGuardada: rutaGuardada = $rutaGuardada');

    if (rutaGuardada != null && rutaGuardada.isNotEmpty) {
      final archivo = File(rutaGuardada);
      final existe = await archivo.exists();
      // print('[DEBUG] _cargarRutaGuardada: archivo.exists = $existe');
      if (existe) {
        // print(
        //     '[DEBUG] _cargarRutaGuardada: Cargando archivo en DatabaseService.loadCsvFile');
        await DatabaseService.loadCsvFile(archivo);
        setState(() {
          archivoSeleccionado = archivo;
        });
      } else {
        print(
            '[DEBUG] _cargarRutaGuardada: El archivo no existe en la ruta guardada');
      }
    } else {
      print('[DEBUG] _cargarRutaGuardada: No hay ruta guardada');
    }
  }

  //Cargar base de datos de sigires
  Future<void> _cargarRutaGuardadaSigires() async {
    final prefs = await SharedPreferences.getInstance();
    final rutaGuardadaSigires = prefs.getString(kRutaGuardadaKeySigires);
    print('[DEBUG] _cargarRutaGuardada: rutaGuardada = $rutaGuardadaSigires');

    if (rutaGuardadaSigires != null && rutaGuardadaSigires.isNotEmpty) {
      final archivo = File(rutaGuardadaSigires);
      final existe = await archivo.exists();
      print('[DEBUG] _cargarRutaGuardada: archivo.exists = $existe');
      if (existe) {
        print(
            '[DEBUG] _cargarRutaGuardada: Cargando archivo en DatabaseService.loadCsvFile');
        await DatabaseService.loadCsvFile(archivo);
        setState(() {
          archivoSeleccionado = archivo;
        });
      } else {
        print(
            '[DEBUG] _cargarRutaGuardada: El archivo no existe en la ruta guardada');
      }
    } else {
      print('[DEBUG] _cargarRutaGuardada: No hay ruta guardada');
    }
  }

  /// Valida la existencia de la base de datos y navega a la pantalla de búsqueda de pacientes.
  ///
  /// Este método realiza una serie de validaciones antes de permitir el acceso
  /// al módulo de búsqueda de pacientes:
  /// 1. Verifica si existe una ruta almacenada en SharedPreferences
  /// 2. Comprueba si el archivo existe físicamente en el dispositivo
  /// 3. Intenta cargar el archivo CSV mediante DatabaseService
  /// 4. Verifica que el archivo contenga datos de pacientes válidos
  ///
  /// Si todas las validaciones son exitosas, actualiza el estado con el archivo seleccionado
  /// y navega a la pantalla de búsqueda de pacientes. En caso contrario, muestra
  /// mensajes de error apropiados mediante SnackBar.
  ///
  /// El método incluye registros de depuración extensivos para facilitar la
  /// identificación de problemas durante el proceso.
  Future<void> _validarYIngresar() async {
    final prefs = await SharedPreferences.getInstance();
    final ruta = prefs.getString(kRutaGuardadaKey);
    final rutaSigires = prefs.getString(kRutaGuardadaKeySigires);

    print("[DEBUG] Ruta Rocky: $ruta");
    print("[DEBUG] Ruta Sigires: $rutaSigires");

    final tieneRocky = ruta != null && ruta.isNotEmpty;
    final tieneSigires = rutaSigires != null && rutaSigires.isNotEmpty;

    if (!tieneRocky && !tieneSigires) {
      await mostrarMensajeModal(context,
          mensaje: "Primero debes cargar una base de datos.",
          titulo: "Error",
          tipo: TipoMensaje.error);
      return;
    }

    File? archivoRocky;
    File? archivoSigires;

    bool rockyValido = false;
    bool sigiresValido = false;

    if (tieneRocky) {
      archivoRocky = File(ruta!);
      rockyValido = await archivoRocky.exists();
      print("[DEBUG] Rocky existe: $rockyValido");
    }

    if (tieneSigires) {
      archivoSigires = File(rutaSigires!);
      sigiresValido = await archivoSigires.exists();
      print("[DEBUG] Sigires existe: $sigiresValido");
    }

    if (!rockyValido && !sigiresValido) {
      mostrarMensajeModal(context,
          mensaje: "Los archivos no existen en el dispositivo.",
          titulo: "Error",
          tipo: TipoMensaje.error);
      return;
    }

    if (rockyValido) {
      await DatabaseService.loadCsvFile(archivoRocky!);
    }

    if (sigiresValido) {
      await DatabaseService.loadCsvFile(archivoSigires!);
    }

    print("[DEBUG] Navegando a BuscarPacienteScreen");

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BuscarPacienteScreen(
          dbFileRocky: archivoRocky,
          dbFileSigires: archivoSigires,
        ),
      ),
    );
  }

  /// Construye la interfaz de usuario para la pantalla principal.
  ///
  /// Estructura de la UI:
  /// - Fondo con color azul corporativo
  /// - Contenedor central con bordes redondeados y sombra
  /// - Logo de la aplicación
  /// - Título descriptivo de la aplicación
  /// - Tres botones principales:
  ///   * "Cargar DB" para importar una nueva base de datos
  ///   * "Descargar CSV" para exportar la base de datos actual
  ///   * "Ingresar" para acceder al módulo de búsqueda de pacientes
  /// - Sección de advertencia sobre la vigencia de la base de datos
  /// - Información de versión de la aplicación
  ///
  /// El diseño implementa:
  /// - ScrollView para asegurar compatibilidad con diferentes tamaños de pantalla
  /// - Diseño visual consistente con la identidad corporativa
  /// - Diferenciación visual clara entre las distintas acciones disponibles
  /// - Elementos informativos para guiar al usuario
  ///

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF007BFF),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // const Text(
                //   'Aplicación profesional para la gestión y consulta de información médica de pacientes',
                //   style: TextStyle(fontSize: 14, color: Colors.white70),
                //   textAlign: TextAlign.center,
                // ),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 6)
                    ],
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 30),
                      Image.asset(
                        'assets/images/imagenInicio.png',
                        width: 80,
                        height: 80,
                      ),
                      const Text(
                        'Gestión de inasistencia a actividades de la Resolución No.3280',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      Text(
                        "Selecciona una opción para comenzar",
                        style: TextStyle(color: Colors.black),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.upload_file),
                        label: const Text("Cargar DB"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold, 
                          ),
                        ),
                        onPressed: () async {
                          print('[DEBUG] Botón Cargar DB presionado');
                          final ruta = await Navigator.push<String>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CargarBaseDatosScreen(),
                            ),
                          );

                          print(
                              '[DEBUG] Valor retornado de CargarBaseDatosScreen: $ruta');
                          if (ruta != null) {
                            final archivo = File(ruta);
                            final existe = await archivo.exists();
                            print(
                                '[DEBUG] Archivo retornado existe: $existe, path: ${archivo.path}');
                            if (existe) {
                              print(
                                  '[DEBUG] Llamando a DatabaseService.loadCsvFile');
                              await DatabaseService.loadCsvFile(archivo);
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setString(
                                  kRutaGuardadaKey, archivo.path);
                              setState(() {
                                archivoSeleccionado = archivo;
                              });
                            } else {
                              print(
                                  '[DEBUG] Archivo no encontrado tras selección');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text("Archivo no encontrado.")),
                              );
                            }
                          } else {
                            print(
                                '[DEBUG] No se retornó ruta desde CargarBaseDatosScreen');
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () async {
                          // Solicitar permisos antes de exportar
                          final status =
                              await Permission.manageExternalStorage.request();
                          final storageStatus =
                              await Permission.storage.request();
                          if (status.isGranted || storageStatus.isGranted) {
                            final csvPath = await DatabaseService.exportCsv();
                            if (csvPath.isNotEmpty) {
                              mostrarMensajeModal(
                                context,
                                mensaje:
                                    'El archivo CSV ha sido guardado en la carpeta de Descargas:\n\n$csvPath',
                                titulo: 'CSV Exportado Exitosamente',
                                tipo: TipoMensaje.exito,
                              );
                            } else {
                              mostrarMensajeModal(
                                context,
                                mensaje:
                                    'No se pudo exportar el archivo CSV. Intente nuevamente.',
                                titulo: 'Error al Exportar',
                                tipo: TipoMensaje.error,
                              );
                            }
                          } else {
                            mostrarMensajeModal(
                              context,
                              mensaje:
                                  'Debes otorgar permisos de almacenamiento para exportar el archivo.',
                              titulo: 'Permiso denegado',
                              tipo: TipoMensaje.error,
                            );
                          }
                        },
                        icon: const Icon(Icons.download),
                        label: const Text("Descargar CSV"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold, 
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _validarYIngresar,
                        icon: const Icon(Icons.login),
                        label: const Text("Buscar paciente"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blue,
                          side: const BorderSide(color: Colors.blue),
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold, 
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.warning,
                                    color: Colors.blue, size: 18),
                                SizedBox(width: 4),
                                Text(
                                  "Advertencia",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.only(left: 20),
                              child: Row(
                                children: [
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      "La base de datos podrá ser cargada únicamente el día de la importación.",
                                      style: TextStyle(color: Colors.black),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
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
