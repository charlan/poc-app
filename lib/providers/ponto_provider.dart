// lib/providers/ponto_provider.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../../database/db_helper.dart';
import '../../models/abono_entry.dart';
import '../../models/ponto_model.dart';
import '../services/app_settings_store.dart';
import '../services/backup_service.dart';
import '../services/comprovante_image_storage.dart';

class PontoProvider extends ChangeNotifier {
  final DbHelper _db = DbHelper();
  final ImagePicker _picker = ImagePicker();
  final AppSettingsStore _settings = AppSettingsStore();

  // ── Estado ──────────────────────────────────────────────────────
  List<Ponto> _pontosDoDia = [];
  List<Ponto> _pontosDaSemana = [];
  List<Ponto> _pontosDoMes = [];
  List<Ponto> _historico = [];
  bool _carregando = false;
  String? _erro;
  int? _ultimoPontoId; // para vincular foto ao último registro

  double _metaSemanalHoras = AppSettingsStore.metaSemanalHorasPadrao;
  List<AbonoEntry> _abonos = [];

  /// Meta semanal configurável (padrão 20h).
  Duration get metaSemanal =>
      Duration(minutes: (_metaSemanalHoras * 60).round());

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

  double get metaSemanalHorasValor => _metaSemanalHoras;

  /// Ex.: `20` ou `20,5` para UI.
  String get metaSemanalHorasTexto {
    final h = _metaSemanalHoras;
    if ((h - h.round()).abs() < 1e-9) return '${h.round()}';
    return h.toStringAsFixed(1).replaceAll('.', ',');
  }

  List<AbonoEntry> get abonos => List.unmodifiable(_abonos);

  Duration get abonoHoje => _abonoNoDia(DateTime.now());

  Duration get horasHojeComAbono => horasHoje + abonoHoje;

  Duration get horasSemanaComAbono =>
      horasSemana + _abonoNaSemana(DateTime.now());

  Future<void> carregarConfiguracaoInicial() async {
    _metaSemanalHoras = await _settings.lerMetaSemanalHoras();
    _abonos = await _settings.lerAbonos();
    notifyListeners();
  }

  Future<void> definirMetaSemanalHoras(double horas) async {
    _metaSemanalHoras = horas.clamp(1, 60);
    await _settings.gravarMetaSemanalHoras(_metaSemanalHoras);
    notifyListeners();
  }

  Future<void> adicionarAbono(DateTime data, Duration horas) async {
    if (horas <= Duration.zero) return;
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final dia = AbonoEntry.normalizarDia(data);
    _abonos.add(AbonoEntry(id: id, data: dia, horas: horas));
    await _settings.gravarAbonos(_abonos);
    notifyListeners();
  }

  Future<void> removerAbono(String id) async {
    _abonos.removeWhere((a) => a.id == id);
    await _settings.gravarAbonos(_abonos);
    notifyListeners();
  }

  Duration _abonoNoDia(DateTime dia) {
    final key = AbonoEntry.normalizarDia(dia);
    return _abonos
        .where((a) => AbonoEntry.normalizarDia(a.data) == key)
        .fold(Duration.zero, (s, a) => s + a.horas);
  }

  Duration _abonoNaSemana(DateTime ref) {
    final weekday = ref.weekday;
    final inicio =
        DateTime(ref.year, ref.month, ref.day).subtract(Duration(days: weekday - 1));
    final fim = inicio.add(const Duration(days: 7));
    return _abonos.where((a) {
      final d = AbonoEntry.normalizarDia(a.data);
      return !d.isBefore(inicio) && d.isBefore(fim);
    }).fold(Duration.zero, (s, a) => s + a.horas);
  }

  Duration _abonoNoMes(int ano, int mes) {
    final inicio = DateTime(ano, mes, 1);
    final fim = DateTime(ano, mes + 1, 1);
    return _abonos.where((a) {
      final d = AbonoEntry.normalizarDia(a.data);
      return !d.isBefore(inicio) && d.isBefore(fim);
    }).fold(Duration.zero, (s, a) => s + a.horas);
  }

  Map<String, dynamic> _configParaBackup() => {
        'metaSemanalHoras': _metaSemanalHoras,
        'abonos': _abonos.map((e) => e.toJson()).toList(),
      };

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
  Duration get saldoHoje => horasHojeComAbono - metaDiaria;

  /// Banco da semana: pontos batidos + abonos da semana − meta semanal
  Duration get bancoDaSemanaSaldo => horasSemanaComAbono - metaSemanal;

  /// Banco acumulado total (mês)
  Duration get bancoDoMesSaldo {
    final hoje = DateTime.now();
    final diasNoMes = DateTime(hoje.year, hoje.month + 1, 0).day;
    final semanasNoMes = diasNoMes / 7;
    final metaMes = Duration(
      microseconds: (metaSemanal.inMicroseconds * semanasNoMes).round(),
    );
    return horasMes + _abonoNoMes(hoje.year, hoje.month) - metaMes;
  }

  /// Progresso semanal de 0.0 a 1.0 (pode ultrapassar 1.0)
  double get progressoSemanal {
    if (metaSemanal.inSeconds == 0) return 0;
    return horasSemanaComAbono.inSeconds / metaSemanal.inSeconds;
  }

  /// Ponto está aberto (última batida foi entrada/retorno)
  bool get pontoAberto {
    if (_pontosDoDia.isEmpty) return false;
    final tipo = _pontosDoDia.last.tipo;
    return tipo == 'entrada' || tipo == 'retorno';
  }

  // ── Carregamento de dados ────────────────────────────────────────
  /// Recarrega dia, semana, mês e histórico. Consultas rodam em paralelo.
  /// [indicadorCarregamento]: evita spinner global em atualizações pontuais (ex.: após salvar).
  Future<void> carregarTodos({bool indicadorCarregamento = true}) async {
    if (indicadorCarregamento) _setCarregando(true);
    try {
      final agora = DateTime.now();
      final bundled = await Future.wait<List<Ponto>>([
        _db.pontosDoDia(agora),
        _db.pontosDaSemana(agora),
        _db.pontosDoMes(agora.year, agora.month),
        _db.todosPontos(),
      ]);
      _pontosDoDia = bundled[0];
      _pontosDaSemana = bundled[1];
      _pontosDoMes = bundled[2];
      _historico = bundled[3];
      _erro = null;
    } catch (e) {
      _erro = 'Erro ao carregar dados: $e';
    } finally {
      if (indicadorCarregamento) {
        _setCarregando(false);
      } else {
        notifyListeners();
      }
    }
  }

  // ── Registrar ponto ──────────────────────────────────────────────
  Future<void> registrarPonto({String? tipo, String? observacao}) async {
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
      await carregarTodos(indicadorCarregamento: false);
    } catch (e) {
      _erro = 'Erro ao registrar ponto: $e';
      notifyListeners();
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

      final inputImage = InputImage.fromFilePath(foto.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final recognizedText = await textRecognizer.processImage(inputImage);
      textRecognizer.close();

      await ComprovanteImageStorage.salvarComprimido(
        sourcePath: foto.path,
        destinoPath: destino,
      );

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
      await carregarTodos(indicadorCarregamento: false);
    } catch (e) {
      _erro = 'Erro ao registrar ponto: $e';
      notifyListeners();
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
      await ComprovanteImageStorage.salvarComprimido(
        sourcePath: foto.path,
        destinoPath: destino,
      );
      await _db.atualizarFoto(pontoId, destino);
      await carregarTodos(indicadorCarregamento: false);
    } catch (e) {
      _erro = 'Erro: $e';
      notifyListeners();
    }
  }

  // ── Deletar ponto ─────────────────────────────────────────────────
  Future<void> deletarPonto(int id) async {
    await _db.deletarPonto(id);
    await carregarTodos(indicadorCarregamento: false);
  }

  // ── Backup (exportar / importar) ─────────────────────────────────
  Future<bool> exportarECompartilharBackup() async {
    try {
      _setCarregando(true);
      _erro = null;
      final file = await BackupService.criarArquivoExportacao(
        _db,
        config: _configParaBackup(),
      );
      await Share.shareXFiles(
        [
          XFile(
            file.path,
            mimeType: 'application/json',
            name: p.basename(file.path),
          ),
        ],
        subject: 'Backup Meu Ponto',
        text: 'Backup dos registros de ponto.',
      );
      return true;
    } catch (e) {
      _erro = 'Erro ao exportar: $e';
      notifyListeners();
      return false;
    } finally {
      _setCarregando(false);
    }
  }

  Future<int?> importarBackupSubstituindo(String caminhoArquivo) async {
    try {
      _setCarregando(true);
      _erro = null;
      final result =
          await BackupService.importarDeArquivo(File(caminhoArquivo), _db);
      await _settings.aplicarConfigBackup(result.config);
      await carregarConfiguracaoInicial();
      await carregarTodos(indicadorCarregamento: false);
      return result.pontosImportados;
    } catch (e) {
      _erro = 'Erro ao importar: $e';
      notifyListeners();
      return null;
    } finally {
      _setCarregando(false);
    }
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


