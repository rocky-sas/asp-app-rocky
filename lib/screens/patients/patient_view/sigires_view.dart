import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SigiresView extends StatelessWidget {
  final Map<String, dynamic>? paciente;

  const SigiresView({super.key, required this.paciente});

  String valorSeguro(Map<String, dynamic>? data, String key) {
    return (data?[key]?.toString().trim().isNotEmpty ?? false)
        ? data![key].toString()
        : "No disponible";
  }

  String tiempoTranscurrido(DateTime? fecha) {
    if (fecha == null) {
      return "No cargado";
    }
    final ahora = DateTime.now();

    int years = ahora.year - fecha.year;
    int months = ahora.month - fecha.month;
    int days = ahora.day - fecha.day;

    if (days < 0) {
      months--;
      final ultimoDiaMesAnterior = DateTime(ahora.year, ahora.month, 0).day;
      days += ultimoDiaMesAnterior;
    }

    if (months < 0) {
      years--;
      months += 12;
    }

    if (years > 0) {
      return "Hace $years año(s) y $months mes(es)";
    } else if (months > 0) {
      return "Hace $months mes(es) y $days día(s)";
    } else {
      return "Hace $days día(s)";
    }
  }

  DateTime? parseFecha(dynamic valor) {
    if (valor == null) return null;

    final fechaStr = valor.toString().trim();
    if (fechaStr.isEmpty) return null;

    try {
      if (fechaStr.contains('/')) {
        return DateFormat('dd/MM/yyyy').parse(fechaStr);
      }
      if (fechaStr.contains('-')) {
        return DateFormat('dd-MM-yyyy').parse(fechaStr);
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final p = paciente;
    final fechaValoracion = parseFecha(p?['VALORACION_INTERGRAL']);
    final fechaValorOdontologia = parseFecha(p?['VALORACION_ODONTOLOGIA']);
    final fechaFluor = parseFecha(p?['FLUOR']);
    final fechaPlaca = parseFecha(p?['PLACA']);
    final fechaDetartraje = parseFecha(p?['DETARTRAJE']);
    final fechaCitologia = parseFecha(p?['CITOLOGIA']);
    final fechaPrueba = parseFecha(p?['PRUEBA_ADN_VPH']);
    final fechaSOMF = parseFecha(p?['SOMF']);
    if (p == null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, color: Colors.grey),
              SizedBox(width: 8),
              Text(
                "Sin información",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
              SizedBox(height: 270),
            ],
          ),
        ),
      );
    }

    final sexo = p['SEXO']?.toString().toUpperCase().trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                  child: Text(valorSeguro(p, 'PRIMER_NOMBRE'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold))),
              const SizedBox(width: 10),
              Flexible(
                  child: Text(valorSeguro(p, 'SEGUNDO_NOMBRE'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold))),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                  child: Text(valorSeguro(p, 'PRIMER_APELLIDO'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold))),
              const SizedBox(width: 10),
              Flexible(
                  child: Text(valorSeguro(p, 'SEGUNDO_APELLIDO'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: valorSeguro(p, 'TIPO_ID'),
                            style: const TextStyle(),
                          ),
                          TextSpan(text: " ${valorSeguro(p, 'NUMERO_ID')}"),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text("Edad: ${valorSeguro(p, 'EDAD')}"),
                    const SizedBox(height: 4),
                    Text(valorSeguro(p, 'CURSO_VIDA')),
                  ],
                ),
              ),

              const SizedBox(width: 20), // espacio entre columnas

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Nto: ${valorSeguro(p, 'FECHA_NACIMIENTO')}"),
                    const SizedBox(height: 4),
                    Text("Tel: ${valorSeguro(p, 'TELEFONO')}"),
                    const SizedBox(height: 4),
                    Text(
                      "Sexo: ${(sexo == null || sexo.isEmpty) ? 'N/A' : (sexo == 'F' ? 'F' : 'M')}",
                    ),
                  ],
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 4),
              Center(
                child: Text(
                  "Régimen: ${valorSeguro(p, 'REGIMEN')}",
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          buildCard(
              icon: Icons.cloud_done_outlined,
              title: "Valoración integral",
              content: valorSeguro(p, 'VALORACION_INTERGRAL'),
              fechaCarga: fechaValoracion),
          buildCard(
              icon: Icons.cloud_done_outlined,
              title: "Valoración odontología",
              content: valorSeguro(p, 'VALORACION_ODONTOLOGIA'),
              fechaCarga: fechaValorOdontologia),
          buildCard(
              icon: Icons.cloud_done_outlined,
              title: "Aplicación de fluor",
              content: valorSeguro(p, 'FLUOR'),
              fechaCarga: fechaFluor),
          buildCard(
              icon: Icons.cloud_done_outlined,
              title: "Control placa",
              content: valorSeguro(p, 'PLACA'),
              fechaCarga: fechaPlaca),
          buildCard(
              icon: Icons.cloud_done_outlined,
              title: "Detartraje",
              content: valorSeguro(p, 'DETARTRAJE'),
              fechaCarga: fechaDetartraje),
          buildCard(
              icon: Icons.cloud_done_outlined,
              title: "Citología",
              content: valorSeguro(p, 'CITOLOGIA'),
              fechaCarga: fechaCitologia),
          buildCard(
              icon: Icons.cloud_done_outlined,
              title: "Prueba ADN-VPH",
              content: valorSeguro(p, 'PRUEBA_ADN_VPH'),
              fechaCarga: fechaPrueba),
          buildCard(
              icon: Icons.cloud_done_outlined,
              title: "Sangre oculta en heces",
              content: valorSeguro(p, 'SOMF'),
              fechaCarga: fechaSOMF),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget buildCard({
    required IconData icon,
    required String title,
    required String content,
    required DateTime? fechaCarga,
  }) {
    return Card(
      elevation: 5,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        isThreeLine: true,
        leading: Icon(icon, color: Colors.green[300]),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              content,
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              tiempoTranscurrido(fechaCarga),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
