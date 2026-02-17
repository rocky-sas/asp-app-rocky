import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Utilidad para trabajar con archivos CSV relacionados con pacientes.
///
/// Esta clase permite:
/// - Cargar archivos CSV en memoria.
/// - Buscar pacientes por su número de documento.
/// - Verificar si el archivo CSV ha expirado.
/// - Detectar automáticamente el delimitador de campos (coma o punto y coma).
///
/// Los métodos utilizan `latin1` como codificación predeterminada
/// para asegurar compatibilidad con archivos exportados de sistemas
/// que no usan UTF-8.
class CsvHelper {
  late List<List<dynamic>> _rows;

  CsvHelper._(this._rows);

  /// Carga un archivo CSV completo en memoria (modo tabla).
  ///
  /// - Detecta automáticamente el delimitador con [_detectDelimiter].
  /// - Convierte el contenido en una lista de filas.
  ///
  /// Ejemplo:
  /// ```dart
  /// final file = File('pacientes.csv');
  /// final helper = await CsvHelper.loadCsv(file);
  /// final expirado = helper.isCsvExpired();
  /// ```
  static Future<CsvHelper> loadCsv(File file) async {
    final raw = await file.readAsString(encoding: latin1);
    final delimiter = _detectDelimiter(raw);
    final csvTable =
        CsvToListConverter(fieldDelimiter: delimiter, eol: '\n').convert(raw);
    return CsvHelper._(csvTable);
  }

  /// Busca un paciente en el CSV por su número de documento [id].
  ///
  /// - Recorre el archivo hasta encontrar un encabezado que contenga `numeroid`.
  /// - Usa ese encabezado como referencia para mapear los campos.
  /// - Retorna un `Map<String, dynamic>` con los datos del paciente.
  /// - Si el paciente no existe o el archivo no es válido, retorna `null`.
  ///
  /// Además, enriquece los datos con información de IPS almacenada en
  /// `SharedPreferences` bajo la clave `'device_validation'`.
  ///
  /// Ejemplo:
  /// ```dart
  /// final paciente = await CsvHelper.getPacienteById("12345", File("pacientes.csv"));
  /// if (paciente != null) {
  ///   print("Paciente encontrado: ${paciente['Nombre']}");
  /// }
  /// ```
  static Future<Map<String, dynamic>?> getPacienteById(
      String id, File file) async {
    final lines = await file.readAsLines(encoding: latin1);
    String delimiter = ',';
    int headerIndex = -1;

    // Buscar encabezado de paciente (ya no asumimos que la IPS está en las primeras líneas)
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].toLowerCase().contains('numeroid')) {
        headerIndex = i;
        delimiter = _detectDelimiter(lines[i]);
        break;
      }
    }

    if (headerIndex == -1) {
      return null;
    }

    final headerFields =
        lines[headerIndex].split(delimiter).map((e) => e.trim()).toList();
    final idBuscado = id.trim();

    for (int i = headerIndex + 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final fields = line.split(delimiter).map((e) => e.trim()).toList();
      if (fields.isNotEmpty && fields[0] == idBuscado) {
        final Map<String, dynamic> paciente = {};

        // Añadir datos del paciente
        for (int j = 0; j < headerFields.length && j < fields.length; j++) {
          paciente[headerFields[j]] = fields[j];
        }

        // Cargar datos de IPS desde SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final deviceValidationJson = prefs.getString('device_validation');
        if (deviceValidationJson != null) {
          final data = jsonDecode(deviceValidationJson);
          paciente['name_ips'] = data['name_ips'] ?? '';
          paciente['name_municipality'] = data['name_municipality'] ?? '';
          paciente['name_department'] = data['name_department'] ?? '';
        }

        return paciente;
      }
    }

    return null;
  }

  static Future<Map<String, dynamic>?> getPacienteByIdSigires(
      String id, File file) async {
    final lines = await file.readAsLines(encoding: latin1);
    if (lines.isEmpty) return null;

    final delimiter = _detectDelimiter(lines[0]);

    final header = lines[0].split(delimiter).map((e) => e.trim()).toList();

    // Mapa con índice de cada columna
    int getIndex(String columnName) => header
        .indexWhere((h) => h.trim().toUpperCase() == columnName.toUpperCase());

    final indexNumeroId = getIndex('NUMERO_ID');

    if (indexNumeroId == -1) {
      print("❌ No existe columna NUMERO_ID");
      return null;
    }

    final idBuscado = id.trim();

    for (int i = 1; i < lines.length; i++) {
      final fields = lines[i].split(delimiter).map((e) => e.trim()).toList();

      if (fields.length > indexNumeroId && fields[indexNumeroId] == idBuscado) {
        final paciente = {
          "TIPO_ID": fields[getIndex('TIPO_ID')],
          "NUMERO_ID": fields[getIndex('NUMERO_ID')],
          "PRIMER_APELLIDO": fields[getIndex('PRIMER_APELLIDO')],
          "SEGUNDO_APELLIDO": fields[getIndex('SEGUNDO_APELLIDO')],
          "PRIMER_NOMBRE": fields[getIndex('PRIMER_NOMBRE')],
          "SEGUNDO_NOMBRE": fields[getIndex('SEGUNDO_NOMBRE')],
          "FECHA_NACIMIENTO": fields[getIndex('FECHA_NACIMIENTO')],
          "SEXO": fields[getIndex('SEXO')],
          "EDAD": fields[getIndex('EDAD')],
          "TELEFONO": fields[getIndex('TELEFONO')],
          "REGIMEN": fields[getIndex('REGIMEN')],
          "CONTROL_PLACA": fields[getIndex('Control de Placa Bacteriana')],
          "CONTROL_RN": fields[getIndex('Control Recién Nacido')],
          "CRECIMIENTO_DESARROLLO": fields[
              getIndex('Consulta de Crecimiento y Desarrollo Primera vez')],
          "CONSULTA_JOVEN": fields[getIndex('Consulta de Joven Primera vez')],
          "CONSULTA_ADULTO": fields[getIndex('Consulta de Adulto Primera vez')],
        };
        return paciente;
      }
    }

    return null;
  }

  /// Verifica si el archivo CSV cargado ha expirado.
  ///
  /// Se asume que en la **quinta columna** (`row[4]`) existe un valor que
  /// representa la fecha de expiración en formato `days since 1900-01-01`.
  ///
  /// - Si no encuentra una fila válida o no puede interpretar la fecha,
  ///   considera el CSV como expirado.
  /// - Devuelve `true` si el archivo ha caducado, `false` en caso contrario.
  ///
  /// Ejemplo:
  /// ```dart
  /// final helper = await CsvHelper.loadCsv(File("pacientes.csv"));
  /// if (helper.isCsvExpired()) {
  ///   print("⚠️ Archivo expirado");
  /// }
  /// ```
  bool isCsvExpired() {
    final ipsRow = _rows.firstWhere(
      (row) => row.length >= 5 && row[0].toString().trim() != "codIPS",
      orElse: () => [],
    );

    if (ipsRow.isEmpty) return true;

    final fechaExpiracionStr = ipsRow[4].toString().trim();
    final expiryDays = int.tryParse(fechaExpiracionStr);
    if (expiryDays == null) return true;

    final expiryDate = DateTime(1900, 1, 1).add(Duration(days: expiryDays - 2));
    return expiryDate.isBefore(DateTime.now());
  }

  /// Detecta automáticamente el delimitador más probable.
  ///
  /// - Cuenta el número de comas `,` y punto y comas `;` en la línea dada.
  /// - Retorna el delimitador con mayor frecuencia.
  ///
  /// Ejemplo:
  /// ```dart
  /// final delimiter = CsvHelper._detectDelimiter("id;nombre;edad");
  /// print(delimiter); // ";"
  /// ```
  static String _detectDelimiter(String line) {
    final commaCount = line.split(',').length;
    final semicolonCount = line.split(';').length;
    return commaCount >= semicolonCount ? ',' : ';';
  }
}
