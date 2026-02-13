String valorSeguro(Map<String, dynamic>? p, String key) {
  if (p == null) return "N/A";

  final value = p[key];

  if (value == null) return "N/A";

  final texto = value.toString().trim();

  if (texto.isEmpty) return "N/A";

  return texto;
}
