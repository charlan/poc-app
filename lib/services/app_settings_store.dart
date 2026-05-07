// lib/services/app_settings_store.dart

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/abono_entry.dart';

class AppSettingsStore {
  static const _metaSemanalKey = 'meta_semanal_horas';
  static const _abonosKey = 'abonos_json';

  static const double metaSemanalHorasPadrao = 20;

  Future<double> lerMetaSemanalHoras() async {
    final p = await SharedPreferences.getInstance();
    return p.getDouble(_metaSemanalKey) ?? metaSemanalHorasPadrao;
  }

  Future<void> gravarMetaSemanalHoras(double horas) async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_metaSemanalKey, horas);
  }

  Future<List<AbonoEntry>> lerAbonos() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_abonosKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => AbonoEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> gravarAbonos(List<AbonoEntry> abonos) async {
    final p = await SharedPreferences.getInstance();
    final encoded =
        jsonEncode(abonos.map((a) => a.toJson()).toList(growable: false));
    await p.setString(_abonosKey, encoded);
  }

  Future<void> aplicarConfigBackup(Map<String, dynamic>? config) async {
    if (config == null) return;
    final h = config['metaSemanalHoras'];
    if (h is num) {
      await gravarMetaSemanalHoras(h.toDouble().clamp(1, 60));
    }
    final raw = config['abonos'];
    if (raw is List<dynamic>) {
      final list = <AbonoEntry>[];
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          try {
            list.add(AbonoEntry.fromJson(e));
          } catch (_) {}
        }
      }
      await gravarAbonos(list);
    }
  }
}
