import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:rocky_offline_sdk/common/custom_modal.dart';
import 'package:intl/intl.dart';

/// Pantalla que permite cargar una base de datos de pacientes en formato CSV.
///
/// Esta clase controla todo el flujo de carga de archivos, incluyendo:
/// - Validación de la clave del dispositivo antes de permitir la carga.
/// - Selección de un archivo CSV mediante `file_picker`.
/// - Verificación de que el archivo seleccionado corresponda al MD5 esperado.
/// - Copia del archivo a la carpeta de documentos de la aplicación.
/// - Manejo de errores y retroalimentación visual para el usuario.
///
/// ### Seguridad
/// - Se valida la vigencia de la clave del dispositivo contra el backend.
/// - Se impone que el archivo cargado tenga el nombre correcto (MD5.csv).
/// - Se establece una fecha de expiración (8 días) para el archivo cargado.
class CargarBaseDatosScreen extends StatefulWidget {
  const CargarBaseDatosScreen({super.key});

  @override
  State<CargarBaseDatosScreen> createState() => _CargarBaseDatosScreenState();
}

class _CargarBaseDatosScreenState extends State<CargarBaseDatosScreen> {
  String? nombreArchivoDBRocky;
  String? nombreArchivoDBSIGIRES;
  String? rutaArchivoTemporalRocky;
  String? rutaArchivoTemporalSIGIRES;
  bool _isPickerActive = false;
  bool isLoading = false;

  Future<String?> generarMd5ParaFecha(DateTime fecha) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final codigoIPS = prefs.getString('cod_ips');

      if (codigoIPS == null) return null;

      final excel1900Start = DateTime(1900, 1, 1);

      final daysSince1900 = fecha.difference(excel1900Start).inDays + 2;

      final data = "$codigoIPS-$daysSince1900";

      final url = "https://b-rocky-intranet.onrender.com/api/v1/md5?data=$data";

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['md5'];
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Obtiene el hash MD5 esperado para la fecha actual y el código IPS almacenado.
  ///
  /// El MD5 se genera a partir de la concatenación `IPS-fecha` (donde la fecha
  /// se calcula según el sistema de fechas de Excel 1900).
  ///
  /// Retorna el valor MD5 como [String] o `null` si falla la operación.
  Future<String?> getExpectedMd5Hash() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final codigoIPS = prefs.getString('cod_ips');

      if (codigoIPS == null) {
        if (mounted) {
          mostrarMensajeModal(context,
              mensaje: "Por favor registre primero el código IPS",
              titulo: "Advertencia",
              tipo: TipoMensaje.info);
        }
        return null;
      }

      // Calcular días desde 1/1/1900 (sistema de fechas Excel 1900)
      final now = DateTime.now();
      final excel1900Start = DateTime(1900, 1, 1);
      final daysSince1900 = now.difference(excel1900Start).inDays +
          2; // +2 para coincidir con el sistema Excel
      final fecha = daysSince1900.toString();

      // Formar el string IPS-fecha
      final data = "$codigoIPS-$fecha";
      final url = "https://b-rocky-intranet.onrender.com/api/v1/md5?data=$data";

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final md5Value = responseData['md5'];

        return md5Value;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<String>> getMd5ValidosDosDias() async {
    final ahora = DateTime.now();

    final md5Hoy = await generarMd5ParaFecha(ahora);
    final md5Ayer =
        await generarMd5ParaFecha(ahora.subtract(Duration(days: 1)));

    final md5Anteayer =
        await generarMd5ParaFecha(ahora.subtract(Duration(days: 2)));

    return [
      if (md5Hoy != null) md5Hoy,
      if (md5Ayer != null) md5Ayer,
      if (md5Anteayer != null) md5Anteayer,
    ];
  }

  /// Verifica con el backend si la clave del dispositivo sigue vigente.
  ///
  /// Consulta el endpoint remoto con el `device_id` y la `key` almacenada en
  /// `SharedPreferences`. Si no son válidos o expiraron, se notifica al usuario.
  ///
  /// Retorna `true` si la clave está vigente, de lo contrario `false`.
  Future<bool> _verificarVigenciaClave() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('device_id');
    final key = prefs.getString('device_key');

    if (deviceId == null || key == null) {
      if (mounted) {
        mostrarMensajeModal(context,
            mensaje: "Por favor, valide primero el dispositivo",
            titulo: "Error",
            tipo: TipoMensaje.error);
      }
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse(
            "https://b-rocky-intranet.onrender.com/api/v1/validate_vilidity_key_device"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"device_id": deviceId, "key": key}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final isValid = data['is_valid']?.toString().toLowerCase() == "true";
        if (isValid) {
        } else if (mounted) {
          mostrarMensajeModal(context,
              mensaje:
                  data['mensaje'] ?? 'La clave del dispositivo ha expirado',
              titulo: "Clave expirada",
              tipo: TipoMensaje.error);
        }
        return isValid;
      }
      return false;
    } catch (e) {
      if (mounted) {
        mostrarMensajeModal(context,
            mensaje: "Error al verificar la vigencia de la clave",
            titulo: 'Error',
            tipo: TipoMensaje.error);
      }
      return false;
    }
  }

  /// Permite seleccionar un archivo `.csv` desde el sistema de archivos.
  ///
  /// Validaciones:
  /// - Verifica vigencia de la clave antes de continuar.
  /// - Obtiene el hash MD5 esperado desde el servidor.
  /// - El archivo debe tener extensión `.csv`.
  /// - El nombre del archivo debe coincidir con el MD5 esperado.
  ///
  /// Si es válido, guarda el nombre y la ruta temporal en variables de estado.
  Future<void> seleccionarArchivoRocky() async {
    if (_isPickerActive) {
      return;
    }

    setState(() {
      _isPickerActive = true;
    });

    FilePickerResult? result;

    try {
      // Primero verificar la vigencia de la clave
      final isValid = await _verificarVigenciaClave();
      if (!isValid) {
        return;
      }

      // Obtener el MD5 esperado
      final md5Validos = await getMd5ValidosDosDias();
      if (md5Validos == null) {
        return;
      }

      result = await FilePicker.platform.pickFiles(type: FileType.any);

      if (result != null && result.files.isNotEmpty) {
        final filePath = result.files.single.path!;
        final fileName = result.files.single.name;

        if (!fileName.toLowerCase().endsWith('.csv')) {
          if (mounted) {
            mostrarMensajeModal(context,
                mensaje: "El archivo debe tener extensión .csv",
                titulo: 'Error',
                tipo: TipoMensaje.error);
          }
          return;
        }

        final fileNameLower = fileName.toLowerCase();

        final esValido = md5Validos.any(
          (md5) => fileNameLower == "$md5.csv".toLowerCase(),
        );

        if (!esValido) {
          if (mounted) {
            mostrarMensajeModal(
              context,
              mensaje:
                  "El archivo no es válido para los últimos días permitidos.",
              titulo: 'Error',
              tipo: TipoMensaje.error,
            );
          }
          return;
        }

        setState(() {
          nombreArchivoDBRocky = fileName;
          rutaArchivoTemporalRocky = filePath;
        });
      }
    } catch (e) {
      print('Error al seleccionar archivo: $e');
      if (mounted) {
        mostrarMensajeModal(context,
            mensaje: "Error al seleccionar el archivo",
            titulo: 'Error',
            tipo: TipoMensaje.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickerActive = false;
        });
      }
    }
  }

  /// Permite seleccionar un archivo `.csv` desde el sistema de archivos para cargar datos de base de datos de sigires.
  Future<void> seleccionarArchivoSigires() async {
    if (_isPickerActive) {
      return;
    }

    setState(() {
      _isPickerActive = true;
    });

    FilePickerResult? result;

    try {
      // Primero verificar la vigencia de la clave
      final isValid = await _verificarVigenciaClave();
      if (!isValid) {
        return;
      }

      // Obtener el MD5 esperado
      // final expectedMd5 = await getExpectedMd5Hash();
      // if (expectedMd5 == null) {
      //   return;
      // }

      result = await FilePicker.platform.pickFiles(type: FileType.any);

      if (result != null && result.files.isNotEmpty) {
        final filePath = result.files.single.path!;
        final fileName = result.files.single.name;

        if (!fileName.toLowerCase().endsWith('.csv')) {
          if (mounted) {
            mostrarMensajeModal(context,
                mensaje: "El archivo debe tener extensión .csv",
                titulo: 'Error',
                tipo: TipoMensaje.error);
          }
          return;
        }

        // // El nombre del archivo debe ser exactamente el MD5 más la extensión .csv
        // final expectedFileName = '$expectedMd5.csv';

        // // Validar que el nombre del archivo coincida con el MD5 esperado
        // if (fileName.toLowerCase() != expectedFileName.toLowerCase()) {
        //   if (mounted) {
        //     await mostrarMensajeModal(context,
        //         "El nombre del archivo no es válido para la fecha actual. Asegúrate de que el archivo sea el correcto.",
        //         exito: false);
        //   }
        //   return;
        // }

        setState(() {
          nombreArchivoDBSIGIRES = fileName;
          rutaArchivoTemporalSIGIRES = filePath;
        });
      }
    } catch (e) {
      print('Error al seleccionar archivo: $e');
      if (mounted) {
        mostrarMensajeModal(context,
            mensaje: "Error al seleccionar el archivo",
            titulo: 'Error',
            tipo: TipoMensaje.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickerActive = false;
        });
      }
    }
  }

  /// Guarda el archivo seleccionado en la carpeta de documentos de la app.
  ///
  /// - Copia el archivo temporal a `mi_base_pacientes.csv` en el directorio
  ///   de documentos de la aplicación.
  /// - Almacena la ruta en `SharedPreferences`.
  /// - Define una fecha de expiración de 8 días desde el momento de carga.
  ///
  /// Retorna `true` si la operación fue exitosa, de lo contrario `false`.
  Future<bool> guardarArchivoSeleccionadoRocky() async {
    if (rutaArchivoTemporalRocky == null || nombreArchivoDBRocky == null) {
      mostrarMensajeModal(context,
          mensaje: "Primero selecciona un archivo válido",
          titulo: 'Error',
          tipo: TipoMensaje.error);
      return false;
    }
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final savedCsvPath = '${appDir.path}/mi_base_pacientes.csv';
      await File(rutaArchivoTemporalRocky!).copy(savedCsvPath);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ruta_csv_guardada', savedCsvPath);
      // Establecer la fecha de expiración (16 días desde hoy)
      final DateTime fechaExpiracion =
          DateTime.now().add(const Duration(days: 16));
      await prefs.setString(
          'expiration_date', fechaExpiracion.toIso8601String());
      String fechaFormateada = DateFormat('dd/MM/yyyy').format(DateTime.now());
      await prefs.setString('dateSaveDBRocky', fechaFormateada);

      return true;
    } catch (e) {
      debugPrint('Error al guardar el archivo: $e');
      if (!mounted) return false;
      mostrarMensajeModal(context,
          mensaje: "Error al guardar el archivo",
          titulo: 'Error',
          tipo: TipoMensaje.error);
      return false;
    }
  }

  // String _detectDelimiter(String line) {
  //   if (line.contains(';')) return ';';
  //   if (line.contains(',')) return ',';
  //   if (line.contains('\t')) return '\t';
  //   return ','; // por defecto
  // }

  Future<bool> guardarArchivoSeleccionadoSIGIRES() async {
    if (rutaArchivoTemporalSIGIRES == null || nombreArchivoDBSIGIRES == null) {
      await mostrarMensajeModal(context,
          mensaje: "Primero selecciona un archivo válido.",
          titulo: 'Error',
          tipo: TipoMensaje.error);
      return false;
    }
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final savedCsvPath = '${appDir.path}/mi_base_pacientesSigires.csv';
      await File(rutaArchivoTemporalSIGIRES!).copy(savedCsvPath); // Debug
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ruta_csv_guardada_sigires', savedCsvPath);
      // final file = File(savedCsvPath);
      // final lines = await file.readAsLines(encoding: latin1);

      // if (lines.isNotEmpty) {
      //   final delimiter = _detectDelimiter(lines[0]);

      //   final header = lines[0]
      //       .replaceAll('\uFEFF', '')
      //       .split(delimiter)
      //       .map((e) => e.trim())
      //       .toList();

      //   debugPrint("COLUMNAS ENCONTRADAS:");
      //   for (var col in header) {
      //     debugPrint(col);
      //   }
      // }

      // Establecer la fecha de expiración (30 días desde hoy)
      final DateTime fechaExpiracion =
          DateTime.now().add(const Duration(days: 30));
      await prefs.setString(
          'expiration_date_sigires', fechaExpiracion.toIso8601String());

      String fechaFormateada = DateFormat('dd/MM/yyyy').format(DateTime.now());
      await prefs.setString('dateSaveDBSigires', fechaFormateada);

      return true;
    } catch (e) {
      debugPrint('Error al guardar el archivo: $e');
      if (!mounted) return false;
      mostrarMensajeModal(context,
          mensaje: "Error al guardar el archivo",
          titulo: 'Error',
          tipo: TipoMensaje.error);
      return false;
    }
  }

  bool archivoSigiresCargado() {
    return nombreArchivoDBSIGIRES != null && rutaArchivoTemporalSIGIRES != null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF007BFF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Botón de volver
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    elevation: 4,
                  ),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text(
                    "Volver",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 10),

                // Card principal
                Card(
                  color: const Color(0xFFF0F8FF),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/imagenInicio.png',
                          width: 70,
                          height: 70,
                        ),

                        const SizedBox(height: 10),
                        const Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Cargar archivo de pacientes de Rocky",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Haga click sobre el clip para buscar la base de datos a cargar",
                                style: TextStyle(
                                    fontWeight: FontWeight.w100, fontSize: 15),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: seleccionarArchivoRocky,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(6),
                              color: Colors.white,
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.attach_file,
                                    color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    nombreArchivoDBRocky ??
                                        "Ningún archivo seleccionado",
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        const TextStyle(color: Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF007BFF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: isLoading
                                ? null
                                : () async {
                                    setState(() {
                                      isLoading = true;
                                    });
                                    try {
                                      if (nombreArchivoDBRocky != null &&
                                          rutaArchivoTemporalRocky != null) {
                                        final ok =
                                            await guardarArchivoSeleccionadoRocky();
                                        if (ok) {
                                          if (!mounted) return;

                                          await mostrarMensajeModal(
                                            context,
                                            mensaje:
                                                "Archivo CSV cargado correctamente",
                                            titulo: "Éxito",
                                            tipo: TipoMensaje.exito,
                                          );
                                          if (!mounted) return;

                                          final sigiresCargado =
                                              nombreArchivoDBSIGIRES != null &&
                                                  rutaArchivoTemporalSIGIRES !=
                                                      null;

                                          await mostrarMensajeModal(
                                            context,
                                            mensaje: sigiresCargado
                                                ? "La base de datos de SIGIRES ya está cargada. No olvide darle guardar."
                                                : "No olvide cargar la base de datos de SIGIRES si la necesita",
                                            titulo: "Información",
                                            tipo: TipoMensaje.info,
                                          );

                                          // if (!mounted) return;
                                          // Navigator.pop(context);
                                        }
                                      } else {
                                        mostrarMensajeModal(context,
                                            mensaje:
                                                "Primero selecciona un archivo válido",
                                            titulo: "Error",
                                            tipo: TipoMensaje.error);
                                      }
                                    } finally {
                                      if (mounted) {
                                        setState(() {
                                          isLoading = false;
                                        });
                                      }
                                    }
                                  },
                            child: isLoading
                                ? const SizedBox(
                                    // height: 18,
                                    // width:18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    "Cargar archivo CSV",
                                    style: TextStyle(fontSize: 13),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Cargar archivo de pacientes de SIGIRES",
                                style: TextStyle(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                        const Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Haga click sobre el clip para buscar la base de datos a cargar",
                                style: TextStyle(
                                    fontWeight: FontWeight.w100, fontSize: 15),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: seleccionarArchivoSigires,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(6),
                              color: Colors.white,
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.attach_file,
                                    color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    nombreArchivoDBSIGIRES ??
                                        "Ningún archivo seleccionado",
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        const TextStyle(color: Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // const SizedBox(height: 8),
                        // const Text(
                        //   "El archivo debe contener columnas como: numeroDocumento, tipoDocumento, nombres, birthday, edad, sexo, cursoVida, actividadesPendientes, laboratoriosPendientes",
                        //   style: TextStyle(fontSize: 12, color: Colors.black54),
                        // ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF007BFF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: isLoading
                                ? null
                                : () async {
                                    setState(() {
                                      isLoading = true;
                                    });
                                    try {
                                      if (nombreArchivoDBSIGIRES != null &&
                                          rutaArchivoTemporalSIGIRES != null) {
                                        final ok =
                                            await guardarArchivoSeleccionadoSIGIRES();
                                        if (ok) {
                                          if (!mounted) return;

                                          await mostrarMensajeModal(
                                            context,
                                            mensaje:
                                                "Archivo CSV cargado correctamente",
                                            titulo: "Éxito",
                                            tipo: TipoMensaje.exito,
                                          );

                                          if (mounted) {
                                            Navigator.pop(context); // ahora sí
                                          }
                                        }
                                      } else {
                                        mostrarMensajeModal(context,
                                            mensaje:
                                                "Primero selecciona un archivo válido",
                                            titulo: "Error",
                                            tipo: TipoMensaje.error);
                                      }
                                    } finally {
                                      if (mounted) {
                                        setState(() {
                                          isLoading = false;
                                        });
                                      }
                                    }
                                  },
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    "Cargar archivo CSV",
                                    style: TextStyle(fontSize: 13),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const SizedBox(
                  width: double.infinity,
                  child: const Text(
                    "Rocky • Versión 1.1",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
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
