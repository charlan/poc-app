// lib/services/backup_service.dart

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/db_helper.dart';
import '../models/ponto_model.dart';

class BackupImportResult {
  final int pontosImportados;
  final Map<String, dynamic>? config;

  BackupImportResult({required this.pontosImportados, this.config});
}

class BackupService {
  static const int exportVersion = 1;

  static Future<File> criarArquivoExportacao(
    DbHelper db, {
    Map<String, dynamic>? config,
  }) async {
    final pontos = await db.todosPontos();
    final list = <Map<String, dynamic>>[];
    for (final ponto in pontos) {
      final map = <String, dynamic>{
        'dataHora': ponto.dataHora.toIso8601String(),
        'data': ponto.data,
        'hora': ponto.hora,
        'nome': ponto.nome,
        'nsr': ponto.nsr,
        'tipo': ponto.tipo,
        'observacao': ponto.observacao,
      };
      final fp = ponto.fotoPath;
      if (fp != null && fp.isNotEmpty) {
        try {
          final f = File(fp);
          if (await f.exists()) {
            map['fotoBase64'] = base64Encode(await f.readAsBytes());
          }
        } catch (_) {
          // foto ilegível — exporta registro sem imagem
        }
      }
      list.add(map);
    }
    final jsonObj = <String, dynamic>{
      'appExportVersion': exportVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'pontos': list,
      if (config != null) 'config': config,
    };
    final dir = await getTemporaryDirectory();
    final file = File(
      p.join(
        dir.path,
        'ponto_backup_${DateTime.now().millisecondsSinceEpoch}.json',
      ),
    );
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(jsonObj),
    );
    return file;
  }

  /// Substitui todos os registros pelo conteúdo do backup.
  static Future<BackupImportResult> importarDeArquivo(File file, DbHelper db) async {
    final dynamic decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Arquivo de backup inválido.');
    }
    final configExtra = decoded['config'];
    final Map<String, dynamic>? configMap =
        configExtra is Map<String, dynamic> ? configExtra : null;

    final v = decoded['appExportVersion'];
    if (v != null && v is int && v != exportVersion) {
      throw FormatException('Versão de backup não suportada ($v).');
    }
    final rawPontos = decoded['pontos'];
    if (rawPontos is! List<dynamic>) {
      throw const FormatException('Backup sem lista de pontos.');
    }

    final docs = await getApplicationDocumentsDirectory();
    final fotosDir = Directory(p.join(docs.path, 'comprovantes'));
    await fotosDir.create(recursive: true);

    final ts = DateTime.now().millisecondsSinceEpoch;
    final parsed = <Ponto>[];
    for (var i = 0; i < rawPontos.length; i++) {
      final item = rawPontos[i];
      if (item is! Map<String, dynamic>) continue;
      final m = item;

      String? fotoPath;
      final b64 = m['fotoBase64'];
      if (b64 is String && b64.isNotEmpty) {
        try {
          final bytes = base64Decode(b64);
          fotoPath = p.join(fotosDir.path, 'comprovante_import_${ts}_$i.jpg');
          await File(fotoPath).writeAsBytes(bytes);
        } catch (_) {
          fotoPath = null;
        }
      }

      final dataHoraStr = m['dataHora'] as String?;
      final dataStr = m['data'] as String?;
      final horaStr = m['hora'] as String?;
      final tipoStr = m['tipo'] as String?;
      if (dataHoraStr == null ||
          dataStr == null ||
          horaStr == null ||
          tipoStr == null) {
        continue;
      }

      parsed.add(
        Ponto(
          dataHora: DateTime.parse(dataHoraStr),
          data: dataStr,
          hora: horaStr,
          nome: m['nome'] as String?,
          nsr: m['nsr'] as String?,
          tipo: tipoStr,
          fotoPath: fotoPath,
          observacao: m['observacao'] as String?,
        ),
      );
    }

    if (parsed.isEmpty && rawPontos.isNotEmpty) {
      throw const FormatException('Nenhum registro válido no backup.');
    }

    await db.limparTodosPontos();
    for (final ponto in parsed) {
      await db.inserirPonto(ponto);
    }
    return BackupImportResult(
      pontosImportados: parsed.length,
      config: configMap,
    );
  }
}
