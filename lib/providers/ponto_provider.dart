// lib/providers/ponto_provider.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../database/db_helper.dart';
import '../../models/ponto_model.dart';

class PontoProvider extends ChangeNotifier {
  final DbHelper _db = DbHelper();
  final ImagePicker _picker = ImagePicker();

  // ── Estado ──────────────────────────────────────────────────────
  List<Ponto> _pontosDoDia = [];
  List<Ponto> _pontosDaSemana = [];
  List<Ponto> _pontosDoMes = [];
  List<Ponto> _historico = [];
  bool _carregando = false;
  String? _erro;
  int? _ultimoPontoId; // para vincular foto ao último registro

  // ── Constante de negócio ─────────────────────────────────────────
  static const Duration metaSemanal = Duration(hours: 20);
  static const Duration metaDiaria = Duration(hours: 4);

  // Regex patterns melhorados para capturar dados com quebras de linha
  static final RegExp _regexNome = RegExp(
    r'NOME\s*[:\-]?\s*([A-Za-zÀ-ÿ\s]{3,100}?)(?=\s*(?:LOCAL|MODELO|CNPJ|PIS|NSR|DATA|HORA|AO:|CET|$))',
    caseSensitive: false,
  );
  static final RegExp _regexData =
      RegExp(r'DATA\s*[:\-]?\s*(\d{2}/\d{2}/\d{4})', caseSensitive: false);
  static final RegExp _regexHora =
      RegExp(r'HORA\s*[:\-]?\s*(\d{2}:\d{2})', caseSensitive: false);
  static final RegExp _regexNsr =
      RegExp(r'NSR\s*[:\-]?\s*([0-9A-Za-z\-]{3,30})', caseSensitive: false);

  // ── Getters ──────────────────────────────────────────────────────
  List<Ponto> get pontosDoDia => _pontosDoDia;
  List<Ponto> get pontosDaSemana => _pontosDaSemana;
  List<Ponto> get pontosDoMes => _pontosDoMes;
  List<Ponto> get historico => _historico;
  bool get carregando => _carregando;
  String? get erro => _erro;
  int? get ultimoPontoId => _ultimoPontoId;

  // ── Tipo do próximo ponto (lógica automática) ────────────────────
  String get proximoTipo {
    if (_pontosDoDia.isEmpty) return 'entrada';
    final ultimo = _pontosDoDia.last.tipo;
    switch (ultimo) {
      case 'entrada':
        return 'saida';
      case 'saida':
        return 'entrada'; // nova entrada (ex: retorno de almoço)
      case 'pausa':
        return 'retorno';
      case 'retorno':
        return 'pausa';
      default:
        return 'entrada';
    }
  }

  // ── Cálculo de horas trabalhadas ─────────────────────────────────

  /// Calcula horas de uma lista de pontos pareando entrada/saída
  Duration calcularHoras(List<Ponto> pontos) {
    Duration total = Duration.zero;
    Ponto? pendente;

    for (final p in pontos) {
      if (p.tipo == 'entrada' || p.tipo == 'retorno') {
        pendente = p;
      } else if ((p.tipo == 'saida' || p.tipo == 'pausa') &&
          pendente != null) {
        total += p.dataHora.difference(pendente.dataHora);
        pendente = null;
      }
    }

    // Se ainda tem entrada aberta, conta até agora
    if (pendente != null) {
      total += DateTime.now().difference(pendente.dataHora);
    }

    return total;
  }

  Duration get horasHoje => calcularHoras(_pontosDoDia);
  Duration get horasSemana => calcularHoras(_pontosDaSemana);
  Duration get horasMes => calcularHoras(_pontosDoMes);
  Duration get saldoHoje => horasHoje - metaDiaria;

  /// Banco de horas = horas trabalhadas na semana − meta de 20h
  Duration get bancoDaSemanaSaldo => horasSemana - metaSemanal;

  /// Banco acumulado total (mês)
  Duration get bancoDoMesSaldo {
    // Calcula quantas semanas tem no mês e multiplica a meta
    final hoje = DateTime.now();
    final diasNoMes = DateTime(hoje.year, hoje.month + 1, 0).day;
    final semanasNoMes = diasNoMes / 7;
    final metaMes = Duration(
      microseconds: (metaSemanal.inMicroseconds * semanasNoMes).round(),
    );
    return horasMes - metaMes;
  }

  /// Progresso semanal de 0.0 a 1.0 (pode ultrapassar 1.0)
  double get progressoSemanal {
    if (metaSemanal.inSeconds == 0) return 0;
    return horasSemana.inSeconds / metaSemanal.inSeconds;
  }

  /// Ponto está aberto (última batida foi entrada/retorno)
  bool get pontoAberto {
    if (_pontosDoDia.isEmpty) return false;
    final tipo = _pontosDoDia.last.tipo;
    return tipo == 'entrada' || tipo == 'retorno';
  }

  // ── Carregamento de dados ────────────────────────────────────────
  Future<void> carregarTodos() async {
    _setCarregando(true);
    try {
      final agora = DateTime.now();
      _pontosDoDia = await _db.pontosDoDia(agora);
      _pontosDaSemana = await _db.pontosDaSemana(agora);
      _pontosDoMes = await _db.pontosDoMes(agora.year, agora.month);
      _historico = await _db.todosPontos();
      _erro = null;
    } catch (e) {
      _erro = 'Erro ao carregar dados: $e';
    } finally {
      _setCarregando(false);
    }
  }

  // ── Registrar ponto ──────────────────────────────────────────────
  Future<void> registrarPonto({String? tipo, String? observacao}) async {
    _setCarregando(true);
    try {
      final agora = DateTime.now();
      final novoPonto = Ponto(
        dataHora: agora,
        data: DateFormat('dd/MM/yyyy').format(agora),
        hora: DateFormat('HH:mm').format(agora),
        tipo: tipo ?? proximoTipo,
        observacao: observacao,
      );
      final id = await _db.inserirPonto(novoPonto);
      _ultimoPontoId = id;
      await carregarTodos();
    } catch (e) {
      _erro = 'Erro ao registrar ponto: $e';
      notifyListeners();
    } finally {
      _setCarregando(false);
    }
  }

  // ── Câmera: tirar e salvar foto do comprovante ───────────────────
  Future<bool> _solicitarPermissaoCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      return true;
    } else if (status.isPermanentlyDenied) {
      // Usuário negou permanentemente, abrir configurações
      await openAppSettings();
      return false;
    } else {
      return false;
    }
  }

  Future<ComprovanteData?> capturarComprovante() async {
    try {
      // Solicitar permissão da câmera primeiro
      final permissaoConcedida = await _solicitarPermissaoCamera();
      if (!permissaoConcedida) {
        _erro = 'Permissão da câmera negada. Vá em Configurações > Apps > Permissões.';
        notifyListeners();
        return null;
      }

      final XFile? foto = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (foto == null) {
        _erro = 'Foto cancelada pelo usuário.';
        notifyListeners();
        return null;
      }

      final dir = await getApplicationDocumentsDirectory();
      await Directory(p.join(dir.path, 'comprovantes')).create(recursive: true);
      final nomeFoto = 'comprovante_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final destino = p.join(dir.path, 'comprovantes', nomeFoto);
      await File(foto.path).copy(destino);

      // Processar OCR
      final inputImage = InputImage.fromFilePath(destino);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final recognizedText = await textRecognizer.processImage(inputImage);
      textRecognizer.close();

      final textoExtraido = recognizedText.text;
      final dados = _extrairDadosOCR(textoExtraido);

      return ComprovanteData(
        fotoPath: destino,
        textoOCR: textoExtraido,
        nome: dados.nome,
        data: dados.data,
        hora: dados.hora,
        nsr: dados.nsr,
      );
    } catch (e, stackTrace) {
      _erro = 'Erro ao capturar comprovante: $e';
      debugPrint('Erro capturarComprovante: $e');
      debugPrint('StackTrace: $stackTrace');
      notifyListeners();
      return null;
    }
  }

  Future<void> registrarPontoComComprovante({
    required String nome,
    required String data,
    required String hora,
    required String nsr,
    required String fotoPath,
    String? observacao,
    String? tipo,
  }) async {
    _setCarregando(true);
    try {
      final dataHora = _criarDateTime(data, hora);
      final novoPonto = Ponto(
        dataHora: dataHora,
        data: data,
        hora: hora,
        nome: nome.isNotEmpty ? nome : null,
        nsr: nsr.isNotEmpty ? nsr : null,
        tipo: tipo ?? proximoTipo,
        fotoPath: fotoPath,
        observacao: observacao,
      );
      final id = await _db.inserirPonto(novoPonto);
      _ultimoPontoId = id;
      await carregarTodos();
    } catch (e) {
      _erro = 'Erro ao registrar ponto: $e';
      notifyListeners();
    } finally {
      _setCarregando(false);
    }
  }

  ComprovanteDados _extrairDadosOCR(String texto) {
    // Normalizar espaços em branco (quebras de linha, abas, múltiplos espaços)
    final textoNormalizado = texto.replaceAll(RegExp(r'\s+'), ' ');
    
    // Extrair dados com o texto normalizado
    var nomeRaw = _regexNome.firstMatch(textoNormalizado)?.group(1)?.trim() ?? '';
    // Remover espaços extras dentro do nome
    final nome = nomeRaw.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    final data = _regexData.firstMatch(textoNormalizado)?.group(1)?.trim() ??
        DateFormat('dd/MM/yyyy').format(DateTime.now());
    final hora = _regexHora.firstMatch(textoNormalizado)?.group(1)?.trim() ??
        DateFormat('HH:mm').format(DateTime.now());
    final nsr = _regexNsr.firstMatch(textoNormalizado)?.group(1)?.trim() ?? '';

    return ComprovanteDados(nome: nome, data: data, hora: hora, nsr: nsr);
  }

  DateTime _criarDateTime(String data, String hora) {
    try {
      return DateFormat('dd/MM/yyyy HH:mm').parseStrict('$data $hora');
    } catch (_) {
      return DateTime.now();
    }
  }



  Future<bool> testarPermissaoCamera() async {
    return await _solicitarPermissaoCamera();
  }

  String? get ultimaMensagemErro => _erro;

  /// Adicionar foto a ponto específico (pelo histórico)
  Future<void> adicionarFotoAoPonto(int pontoId) async {
    try {
      final XFile? foto = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (foto == null) return;

      final dir = await getApplicationDocumentsDirectory();
      final nomeFoto =
          'comprovante_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final destino = p.join(dir.path, 'comprovantes', nomeFoto);
      await Directory(p.join(dir.path, 'comprovantes'))
          .create(recursive: true);
      await File(foto.path).copy(destino);
      await _db.atualizarFoto(pontoId, destino);
      await carregarTodos();
    } catch (e) {
      _erro = 'Erro: $e';
      notifyListeners();
    }
  }

  // ── Deletar ponto ─────────────────────────────────────────────────
  Future<void> deletarPonto(int id) async {
    await _db.deletarPonto(id);
    await carregarTodos();
  }

  // ── Utilitários ──────────────────────────────────────────────────
  void _setCarregando(bool v) {
    _carregando = v;
    notifyListeners();
  }

  /// Formata Duration como "Xh Ym"
  static String formatarDuracao(Duration d) {
    final horas = d.inHours;
    final mins = d.inMinutes.remainder(60);
    if (d.isNegative) {
      return '-${(-horas).abs()}h ${(-mins).abs()}m';
    }
    return '${horas}h ${mins.toString().padLeft(2, '0')}m';
  }
}

class ComprovanteData {
  final String fotoPath;
  final String textoOCR;
  final String nome;
  final String data;
  final String hora;
  final String nsr;

  ComprovanteData({
    required this.fotoPath,
    required this.textoOCR,
    required this.nome,
    required this.data,
    required this.hora,
    required this.nsr,
  });
}

class ComprovanteDados {
  final String nome;
  final String data;
  final String hora;
  final String nsr;

  ComprovanteDados({
    required this.nome,
    required this.data,
    required this.hora,
    required this.nsr,
  });
}


