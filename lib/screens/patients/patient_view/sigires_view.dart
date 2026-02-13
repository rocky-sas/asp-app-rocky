import 'package:flutter/material.dart';

class SigiresView extends StatelessWidget {
  final Map<String, dynamic>? paciente;

  const SigiresView({super.key, required this.paciente});

  String valorSeguro(Map<String, dynamic>? data, String key) {
    return (data?[key]?.toString().trim().isNotEmpty ?? false)
        ? data![key].toString()
        : "No disponible";
  }

  @override
  Widget build(BuildContext context) {
    final p = paciente;

    if (p == null) {
      return const Center(child: Text("Sin información"));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const SizedBox(height: 10),

          buildCard(
            icon: Icons.person,
            title: "Nombre",
            content: valorSeguro(p, 'Nombre'),
          ),

          buildCard(
            icon: Icons.badge,
            title: "Identificación",
            content: valorSeguro(p, 'Identificacion'),
          ),

          buildCard(
            icon: Icons.phone,
            title: "Teléfono",
            content: valorSeguro(p, 'Telefono'),
          ),

          const SizedBox(height: 10),

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

          const SizedBox(height: 10),

          /// 🔽 ACTIVIDADES REALIZADAS
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 14),
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
                childrenPadding: const EdgeInsets.all(16),
                children: [

                  itemExamen("Citología", p["FechaCitologia"]),
                  itemExamen("Curso de vida", p["FechaCursoVida"]),
                  itemExamen("S. O. Mat. Fe", p["FechaSanOcu"]),
                  itemExamen("Hemograma jóvenes", p["FechaHemoJov"]),
                  itemExamen("Detartaje", p["FechaDetartaje"]),
                  itemExamen("Control placa", p["FechaControlPlaca"]),
                  itemExamen("Flúor", p["FechaFluor"]),
                  itemExamen("Paquete labs", p["FechaPaqLabs"]),
                  itemExamen("Sellantes", p["FechaSellantes"]),
                  itemExamen("Consulta odont.", p["FechaConsultaOdon"]),
                  itemExamen("Plan familiar", p["FechaPlanFami"]),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
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
      margin: const EdgeInsets.only(bottom: 8),
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

  /// 🔹 ITEM EXAMEN
  Widget itemExamen(String nombre, dynamic fecha) {
    final tieneFecha =
        fecha != null && fecha.toString().trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline,
              color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "$nombre: ${tieneFecha ? fecha.toString() : 'No realizado'}",
            ),
          ),
        ],
      ),
    );
  }
}
