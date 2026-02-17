import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RockyView extends StatelessWidget {
  final Map<String, dynamic>? paciente;

  const RockyView({super.key, required this.paciente});

  String valorSeguro(Map<String, dynamic>? data, String key) {
    return (data?[key]?.toString().trim().isNotEmpty ?? false)
        ? data![key].toString()
        : "No disponible";
  }

  String tiempoTranscurrido(DateTime fecha) {
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

  Widget itemExamen({
    required String nombre,
    required IconData icon,
    required DateTime? fecha,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.green[300]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  fecha != null
                      ? "Fecha: ${DateFormat('dd/MM/yyyy').format(fecha)}"
                      : "Fecha: N/A",
                  style: const TextStyle(fontSize: 13),
                ),
                if (fecha != null)
                  Text(
                    tiempoTranscurrido(fecha),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = paciente;

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
              SizedBox(height: 200),
            ],
          ),
        ),
      );
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

    final fechaCitologia = parseFecha(p['CitologiaAdnVph']);
    final fechaCitologiaPapa = parseFecha(p['CitologiaPapan']);
    final fechaConCursoVida = parseFecha(p['ConCursoVida']);
    final fechaSanOcuMatFe = parseFecha(p['SanOcuMatFe']);
    final fechaHemoHemaJov = parseFecha(p['SanOcuMatFe']);
    final fechaDetartraje = parseFecha(p['Detartraje']);
    final fechaConPlaca = parseFecha(p['ConPlaca']);
    final fechaFluor = parseFecha(p['Fluor']);
    final fechaPaqLabs = parseFecha(p['PaqLabs']);
    final fechaSellantes = parseFecha(p['Sellantes']);
    final fechaConsOdont = parseFecha(p['ConsOdont']);
    // final fechaPlanFami = parseFecha(p['PlanFami']);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildCard(
            icon: Icons.task_alt,
            title: "Actividades pendientes",
            content: valorSeguro(p, 'ActividadesPendientes'),
          ),
          buildCard(
            icon: Icons.biotech,
            title: "Laboratorios pendientes",
            content: valorSeguro(p, 'LaboratoriosPendientes'),
          ),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                leading: const Icon(
                  Icons.checklist,
                  color: Colors.blue,
                  size: 32,
                ),
                title: const Text(
                  "Actividades realizadas",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                childrenPadding: const EdgeInsets.all(10),
                children: [
                  itemExamen(
                    nombre: "Curso de vida",
                    icon: Icons.check_circle_outline,
                    fecha: fechaConCursoVida,
                  ),
                  itemExamen(
                    nombre: "Hemograma y hematocrito en jóvenes",
                    icon: Icons.check_circle_outline,
                    fecha: fechaHemoHemaJov,
                  ),
                  itemExamen(
                    nombre: "Paquete de laboratorios",
                    icon: Icons.check_circle_outline,
                    fecha: fechaPaqLabs,
                  ),
                  itemExamen(
                    nombre: "Citología Papanicolaou",
                    icon: Icons.check_circle_outline,
                    fecha: fechaCitologiaPapa,
                  ),
                  itemExamen(
                    nombre: "Citología ADN-VPH",
                    icon: Icons.check_circle_outline,
                    fecha: fechaCitologia,
                  ),
                  itemExamen(
                    nombre: "Sangre oculta en heces",
                    icon: Icons.check_circle_outline,
                    fecha: fechaSanOcuMatFe,
                  ),
                  itemExamen(
                    nombre: "Consulta odontológica",
                    icon: Icons.check_circle_outline,
                    fecha: fechaConsOdont,
                  ),
                  itemExamen(
                    nombre: "Control de placa",
                    icon: Icons.check_circle_outline,
                    fecha: fechaConPlaca,
                  ),
                  itemExamen(
                    nombre: "Aplicacion flúor",
                    icon: Icons.check_circle_outline,
                    fecha: fechaFluor,
                  ),
                  itemExamen(
                    nombre: "Sellantes",
                    icon: Icons.check_circle_outline,
                    fecha: fechaSellantes,
                  ),
                  itemExamen(
                    nombre: "Detartraje",
                    icon: Icons.check_circle_outline,
                    fecha: fechaDetartraje,
                  ),
                  // itemExamen(
                  //   nombre: "Plan familiar",
                  //   icon: Icons.check_circle_outline,
                  //   fecha: fechaPlanFami,
                  // ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  /// 🔹 CARD reutilizable
  Widget buildCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(content),
      ),
    );
  }
}
