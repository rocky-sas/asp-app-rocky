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






    final sexo = p['SEXO']?.toString().toUpperCase().trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    Text(
                      "Sexo: ${(sexo == null || sexo.isEmpty) ? 'N/A' : (sexo == 'F' ? 'F' : 'M')}",
                    ),
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
                    Text("R: ${valorSeguro(p, 'REGIMEN')}"),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          buildCard(
            icon: Icons.badge,
            title: "Control de placa bacteriana",
            content: valorSeguro(p, 'CONTROL_PLACA'),
          ),
          buildCard(
            icon: Icons.phone,
            title: "Control recién nacidos",
            content: valorSeguro(p, 'CONTROL_RN'),
          ),
          buildCard(
            icon: Icons.task_alt,
            title: "Consulta crecimiento y desarrollo",
            content: valorSeguro(p, 'CRECIMIENTO_DESARROLLO'),
          ),
          buildCard(
            icon: Icons.biotech,
            title: "Consulta joven primera vez",
            content: valorSeguro(p, 'CONSULTA_JOVEN'),
          ),
          buildCard(
            icon: Icons.biotech,
            title: "Consulta adulto primera vez",
            content: valorSeguro(p, 'CONSULTA_ADULTO'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget buildCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(content),
      ),
    );
  }
}
