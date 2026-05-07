// lib/services/comprovante_image_storage.dart

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Salva comprovante como JPEG comprimido para economizar espaço em disco.
/// OCR deve rodar no arquivo temporário da câmera **antes** de chamar isto.
class ComprovanteImageStorage {
  ComprovanteImageStorage._();

  /// Qualidade JPEG final (0–100). ~72 mantém texto legível com bom ganho de espaço.
  static const int jpegQuality = 72;

  /// Limita o maior lado da imagem (px). Comprovantes não precisam de resolução de poster.
  static const int maxSidePx = 1680;

  /// Escreve [destinoPath] a partir de [sourcePath]. Em falha, copia o arquivo bruto.
  static Future<void> salvarComprimido({
    required String sourcePath,
    required String destinoPath,
  }) async {
    final parent = File(destinoPath).parent;
    await parent.create(recursive: true);

    try {
      final saida = await FlutterImageCompress.compressAndGetFile(
        sourcePath,
        destinoPath,
        quality: jpegQuality,
        minWidth: maxSidePx,
        minHeight: maxSidePx,
        format: CompressFormat.jpeg,
      );
      if (saida != null) {
        final len = await File(saida.path).length();
        if (len > 0) return;
      }
    } catch (e, st) {
      debugPrint('ComprovanteImageStorage: compressão falhou, usando cópia. $e');
      debugPrint('$st');
    }

    await File(sourcePath).copy(destinoPath);
  }
}
