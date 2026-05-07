// lib/models/abono_entry.dart

class AbonoEntry {
  final String id;
  /// Apenas data civil (hora ignorada na comparação).
  final DateTime data;
  final Duration horas;

  AbonoEntry({
    required this.id,
    required this.data,
    required this.horas,
  });

  Map<String, dynamic> toJson() {
    final d = DateTime(data.year, data.month, data.day);
    return {
      'id': id,
      'data':
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
      'minutos': horas.inMinutes,
    };
  }

  factory AbonoEntry.fromJson(Map<String, dynamic> m) {
    final raw = m['data'] as String;
    final parts = raw.split('-');
    final data = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    return AbonoEntry(
      id: m['id'] as String,
      data: data,
      horas: Duration(minutes: (m['minutos'] as num).toInt()),
    );
  }

  static DateTime normalizarDia(DateTime d) =>
      DateTime(d.year, d.month, d.day);
}
