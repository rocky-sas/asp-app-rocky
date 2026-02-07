import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

/// Servicio encargado de la gestión de pacientes a partir de un archivo CSV.
///
/// Esta clase proporciona métodos estáticos para:
/// - Cargar un archivo CSV con la información de pacientes.
/// - Leer el contenido del CSV (compatibilidad con UTF-8 y Latin1).
/// - Actualizar el estado (`status`) de un paciente.
/// - Guardar y sobrescribir los cambios en el CSV original.
/// - Exportar un nuevo archivo CSV con los pacientes actuales.
///
/// Los datos cargados se almacenan en memoria estática dentro de la clase
/// para facilitar el acceso desde otras partes de la aplicación.
class DatabaseService {
  static File? _csvFile;

  /// Lista en memoria de los pacientes cargados.
  ///
  /// Cada paciente es representado como un `Map<String, String>` con claves
  /// correspondientes a los encabezados del archivo CSV.
  static List<Map<String, String>> _pacientes = [];
  static List<String> _headers = [];

  /// Actualiza el estado (`status`) de un paciente por su [numeroId].
  ///
  /// Si el paciente es encontrado en la lista, se modifica su campo `status`
  /// con el valor de [status] y se guarda el cambio en el CSV original.
  static Future<void> updatePatientStatus(String numeroId, bool status) async {
    final index = _pacientes.indexWhere((p) => p['NumeroId'] == numeroId);
    if (index != -1) {
      _pacientes[index]['status'] = status.toString();
      await _saveUpdatedCsv();
    }
  }

  /// Exporta los pacientes actuales a un nuevo archivo CSV.
  ///
  /// - El archivo se guarda en el directorio externo privado de la aplicación.
  /// - El nombre del archivo incluye la fecha y hora actual para diferenciar versiones.
  ///
  /// Devuelve la ruta completa del archivo exportado, o un string vacío
  /// en caso de error.
  static Future<String> exportCsv() async {
    if (_csvFile == null || _headers.isEmpty) return '';

    try {
      // Obtener directorio privado de la app
      final directory = await getExternalStorageDirectory();
      if (directory == null)
        throw Exception("No se pudo obtener directorio externo");

      // Crear nombre de archivo con fecha y hora
      final now = DateTime.now();
      final fileName =
          'pacientes_${now.year}${now.month}${now.day}_${now.hour}${now.minute}.csv';
      final exportPath = '${directory.path}/$fileName';

      // Crear el nuevo archivo
      final exportFile = File(exportPath);

      final buffer = StringBuffer();
      // Escribir headers
      buffer.writeln(_headers.join(','));

      // Escribir datos
      for (var paciente in _pacientes) {
        final values =
            _headers.map((header) => paciente[header] ?? '').toList();
        buffer.writeln(values.join(','));
      }

      await exportFile.writeAsString(buffer.toString());
      return exportPath;
    } catch (e) {
      print('Error al exportar CSV: $e');
      return '';
    }
  }

  /// Guarda en el archivo CSV los cambios realizados en la lista de pacientes.
  ///
  /// Este método sobrescribe el archivo original con los datos actuales
  /// de [_pacientes].
  static Future<void> _saveUpdatedCsv() async {
    if (_csvFile == null || _headers.isEmpty) return;

    final buffer = StringBuffer();
    // Escribir headers
    buffer.writeln(_headers.join(','));

    // Escribir datos
    for (var paciente in _pacientes) {
      final values = _headers.map((header) => paciente[header] ?? '').toList();
      buffer.writeln(values.join(','));
    }

    await _csvFile!.writeAsString(buffer.toString());
  }

  /// Getter para acceder a la lista de pacientes cargados.
  static List<Map<String, String>> get pacientes => _pacientes;

  /// Carga un archivo CSV de pacientes y lo guarda como archivo actual.
  ///
  /// - Si el archivo no existe, devuelve `false`.
  /// - Si se carga correctamente, almacena la ruta en `SharedPreferences`
  ///   bajo la clave `'ruta_csv_guardada'` y devuelve `true`.
  static Future<bool> loadCsvFile(File file) async {
    if (!file.existsSync()) {
      print("[DatabaseService] El archivo no existe.");
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ruta_csv_guardada', file.path);

    print("[DatabaseService] 🧾 Tamaño del archivo leído: ${await file.length()} bytes");

    _csvFile = file;
    return await _readCsv(file);
  }

  /// Lee el contenido de un archivo CSV y lo carga en memoria.
  ///
  /// Compatibilidad:
  /// - Intenta primero con codificación UTF-8.
  /// - Si falla, intenta con Latin1.
  ///
  /// El método identifica el índice de encabezado buscando la columna `NumeroId`.
  /// Luego construye la lista de [_pacientes].
  ///
  /// Si no existe la columna `status`, se agrega automáticamente.
  ///
  /// Devuelve `true` si se cargaron pacientes correctamente.
  static Future<bool> _readCsv(File file) async {
    List<String> rawLines = [];

    try {
      rawLines = await file.readAsLines(encoding: utf8);
      print("[CsvHelper] CSV leído con UTF-8");
    } catch (e) {
      print("[CsvHelper] Error al leer con UTF-8: $e");
      print("[CsvHelper] Reintentando con Latin1...");
      try {
        rawLines = await file.readAsLines(encoding: latin1);
        print("[CsvHelper] CSV leído con Latin1");
      } catch (e2) {
        print("[CsvHelper] No se pudo leer el archivo ni con UTF-8 ni Latin1.");
        return false;
      }
    }

    print("[CsvHelper] Total líneas leídas: ${rawLines.length}");

    final headerIndex = rawLines.indexWhere((line) {
      final clean = line
          .replaceAll(RegExp(r'^\ufeff'), '') // elimina BOM si existe
          .replaceAll(RegExp(r'\s+'), '')
          .toLowerCase();
      return clean.contains('numeroid');
    });

    if (headerIndex == -1) {
      print("[CsvHelper] No se encontró encabezado válido");
      return false;
    }

    _headers = rawLines[headerIndex].split(',').map((e) => e.trim()).toList();

    // Verificar si existe el header 'status' y agregarlo si no existe
    if (!_headers.contains('status')) {
      _headers.add('status');
      print("[CsvHelper] Agregado header 'status'");
    }

    _pacientes = [];

    for (int i = headerIndex + 1; i < rawLines.length; i++) {
      final line = rawLines[i].trim();
      if (line.isEmpty) continue;

      final values = line.split(',');
      final paciente = <String, String>{};

      // Agregar los valores existentes
      for (int j = 0; j < values.length && j < _headers.length - 1; j++) {
        paciente[_headers[j]] = values[j].trim();
      }

      // Agregar o mantener el valor de status
      paciente['status'] = values.length >= _headers.length
          ? values[_headers.length - 1].trim()
          : 'false';

      _pacientes.add(paciente);
      print("[CsvHelper] Paciente agregado: $paciente");
    }

    print("[CsvHelper] Pacientes cargados: ${_pacientes.length}");
    return _pacientes.isNotEmpty;
  }
}
