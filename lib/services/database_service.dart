import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

/// Servicio encargado de la gestión de pacientes para DOS bases:
/// - Rocky
/// - Sigires
///
/// Permite:
/// - Cargar ambos CSV al mismo tiempo.
/// - Mantener ambas listas en memoria.
/// - Actualizar status sin que se sobrescriban.
/// - Exportar cada base por separado.
class DatabaseService {
  // ===============================
  // ARCHIVOS
  // ===============================

  static File? _csvRocky;
  static File? _csvSigires;

  // ===============================
  // HEADERS
  // ===============================

  static List<String> _headersRocky = [];
  static List<String> _headersSigires = [];

  // ===============================
  // PACIENTES EN MEMORIA
  // ===============================

  static List<Map<String, String>> _pacientesRocky = [];
  static List<Map<String, String>> _pacientesSigires = [];

  // ===============================
  // GETTERS
  // ===============================

  static List<Map<String, String>> get pacientesRocky => _pacientesRocky;
  static List<Map<String, String>> get pacientesSigires => _pacientesSigires;

  // ===============================
  // CARGA ROCKY
  // ===============================

  static Future<bool> loadCsvRocky(File file) async {
    if (!file.existsSync()) {
      print("[DatabaseService] Archivo Rocky no existe.");
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ruta_csv_guardada', file.path);

    _csvRocky = file;
    return await _readCsv(file, isRocky: true);
  }

  // ===============================
  // CARGA SIGIRES
  // ===============================

  static Future<bool> loadCsvSigires(File file) async {
    if (!file.existsSync()) {
      print("[DatabaseService] Archivo Sigires no existe.");
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ruta_csv_guardada_sigires', file.path);

    _csvSigires = file;
    return await _readCsv(file, isRocky: false);
  }

  // ===============================
  // LECTURA CSV COMPARTIDA
  // ===============================

  static Future<bool> _readCsv(File file, {required bool isRocky}) async {
    List<String> rawLines = [];

    try {
      rawLines = await file.readAsLines(encoding: utf8);
      print("[CsvHelper] CSV leído con UTF-8");
    } catch (_) {
      rawLines = await file.readAsLines(encoding: latin1);
      print("[CsvHelper] CSV leído con Latin1");
    }

    if (rawLines.isEmpty) {
      print("[CsvHelper] Archivo vacío");
      return false;
    }

    final headerIndex = rawLines.indexWhere((line) {
      final clean = line
          .replaceAll(RegExp(r'^\ufeff'), '')
          .replaceAll(RegExp(r'\s+'), '')
          .toLowerCase();
      return clean.contains('numeroid');
    });

    if (headerIndex == -1) {
      print("[CsvHelper] No se encontró encabezado válido");
      return false;
    }

    final headers =
        rawLines[headerIndex].split(',').map((e) => e.trim()).toList();

    if (!headers.contains('status')) {
      headers.add('status');
    }

    final pacientes = <Map<String, String>>[];

    for (int i = headerIndex + 1; i < rawLines.length; i++) {
      final line = rawLines[i].trim();
      if (line.isEmpty) continue;

      final values = line.split(',');
      final paciente = <String, String>{};

      for (int j = 0; j < headers.length && j < values.length; j++) {
        paciente[headers[j]] = values[j].trim();
      }

      paciente.putIfAbsent('status', () => 'false');

      pacientes.add(paciente);
    }

    if (isRocky) {
      _headersRocky = headers;
      _pacientesRocky = pacientes;
      print("[CsvHelper] Rocky cargado: ${pacientes.length} pacientes");
    } else {
      _headersSigires = headers;
      _pacientesSigires = pacientes;
      print("[CsvHelper] Sigires cargado: ${pacientes.length} pacientes");
    }

    return pacientes.isNotEmpty;
  }

  // ===============================
  // ACTUALIZAR STATUS
  // ===============================

  static Future<void> updatePatientStatus(
      String numeroId, bool status,
      {required bool isRocky}) async {
    final pacientes = isRocky ? _pacientesRocky : _pacientesSigires;

    final index =
        pacientes.indexWhere((p) => p['NumeroId']?.trim() == numeroId.trim());

    if (index != -1) {
      pacientes[index]['status'] = status.toString();

      await _saveUpdatedCsv(isRocky: isRocky);
    }
  }

  // ===============================
  // GUARDAR CAMBIOS
  // ===============================

  static Future<void> _saveUpdatedCsv({required bool isRocky}) async {
    final file = isRocky ? _csvRocky : _csvSigires;
    final headers = isRocky ? _headersRocky : _headersSigires;
    final pacientes = isRocky ? _pacientesRocky : _pacientesSigires;

    if (file == null || headers.isEmpty) return;

    final buffer = StringBuffer();

    buffer.writeln(headers.join(','));

    for (var paciente in pacientes) {
      final values = headers.map((h) => paciente[h] ?? '').toList();
      buffer.writeln(values.join(','));
    }

    await file.writeAsString(buffer.toString());
  }

  // ===============================
  // EXPORTAR
  // ===============================

  static Future<String> exportCsv({required bool isRocky}) async {
    final headers = isRocky ? _headersRocky : _headersSigires;
    final pacientes = isRocky ? _pacientesRocky : _pacientesSigires;

    if (headers.isEmpty) return '';

    final directory = await getApplicationDocumentsDirectory();

    final now = DateTime.now();
    final fileName =
        '${isRocky ? "rocky" : "sigires"}_${now.year}${now.month}${now.day}_${now.hour}${now.minute}.csv';

    final exportFile = File('${directory.path}/$fileName');

    final buffer = StringBuffer();
    buffer.writeln(headers.join(','));

    for (var paciente in pacientes) {
      final values = headers.map((h) => paciente[h] ?? '').toList();
      buffer.writeln(values.join(','));
    }

    await exportFile.writeAsString(buffer.toString());

    return exportFile.path;
  }
}