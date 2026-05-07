// lib/database/db_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/ponto_model.dart';

class DbHelper {
  static final DbHelper _instance = DbHelper._internal();
  factory DbHelper() => _instance;
  DbHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'ponto_app.db');

    return openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // ─────────────────────────────────────────────────────────────
    //  SCHEMA
    //  tabela: pontos
    //  id        INTEGER  PK autoincrement
    //  dataHora  TEXT     ISO-8601 (UTC)
    //  data      TEXT     DD/MM/YYYY
    //  hora      TEXT     HH:MM
    //  nome      TEXT     nome do titular do comprovante
    //  nsr       TEXT     número sequencial do comprovante
    //  tipo      TEXT     'entrada' | 'saida' | 'pausa' | 'retorno'
    //  fotoPath  TEXT     caminho local da foto
    //  observacao TEXT    texto OCR / anotação
    // ─────────────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE pontos (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        dataHora   TEXT    NOT NULL,
        data       TEXT    NOT NULL,
        hora       TEXT    NOT NULL,
        nome       TEXT,
        nsr        TEXT,
        tipo       TEXT    NOT NULL,
        fotoPath   TEXT,
        observacao TEXT
      )
    ''');

    // Índice para acelerar queries por data
    await db.execute(
      'CREATE INDEX idx_pontos_dataHora ON pontos(dataHora)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE pontos ADD COLUMN data TEXT');
      await db.execute('ALTER TABLE pontos ADD COLUMN hora TEXT');
      await db.execute('ALTER TABLE pontos ADD COLUMN nome TEXT');
      await db.execute('ALTER TABLE pontos ADD COLUMN nsr TEXT');
    }
  }

  // ── INSERT ──────────────────────────────────────────────────────
  Future<int> inserirPonto(Ponto ponto) async {
    final db = await database;
    return db.insert(
      'pontos',
      ponto.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── UPDATE (adiciona foto depois) ───────────────────────────────
  Future<void> atualizarFoto(int id, String fotoPath) async {
    final db = await database;
    await db.update(
      'pontos',
      {'fotoPath': fotoPath},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── DELETE ──────────────────────────────────────────────────────
  Future<void> deletarPonto(int id) async {
    final db = await database;
    await db.delete('pontos', where: 'id = ?', whereArgs: [id]);
  }

  // ── QUERIES ─────────────────────────────────────────────────────

  /// Todos os pontos de um dia específico
  Future<List<Ponto>> pontosDoDia(DateTime dia) async {
    final db = await database;
    final inicio = DateTime(dia.year, dia.month, dia.day);
    final fim = inicio.add(const Duration(days: 1));

    final maps = await db.query(
      'pontos',
      where: 'dataHora >= ? AND dataHora < ?',
      whereArgs: [inicio.toIso8601String(), fim.toIso8601String()],
      orderBy: 'dataHora ASC',
    );
    return maps.map(Ponto.fromMap).toList();
  }

  /// Pontos da semana ISO (segunda → domingo)
  Future<List<Ponto>> pontosDaSemana(DateTime qualquerDiaDaSemana) async {
    final db = await database;
    final weekday = qualquerDiaDaSemana.weekday; // 1=seg, 7=dom
    final inicio = DateTime(
      qualquerDiaDaSemana.year,
      qualquerDiaDaSemana.month,
      qualquerDiaDaSemana.day,
    ).subtract(Duration(days: weekday - 1));
    final fim = inicio.add(const Duration(days: 7));

    final maps = await db.query(
      'pontos',
      where: 'dataHora >= ? AND dataHora < ?',
      whereArgs: [inicio.toIso8601String(), fim.toIso8601String()],
      orderBy: 'dataHora ASC',
    );
    return maps.map(Ponto.fromMap).toList();
  }

  /// Pontos do mês
  Future<List<Ponto>> pontosDoMes(int ano, int mes) async {
    final db = await database;
    final inicio = DateTime(ano, mes, 1);
    final fim = DateTime(ano, mes + 1, 1);

    final maps = await db.query(
      'pontos',
      where: 'dataHora >= ? AND dataHora < ?',
      whereArgs: [inicio.toIso8601String(), fim.toIso8601String()],
      orderBy: 'dataHora ASC',
    );
    return maps.map(Ponto.fromMap).toList();
  }

  /// Todos os pontos (histórico completo) — paginado
  Future<List<Ponto>> todosPontos({int limite = 100, int offset = 0}) async {
    final db = await database;
    final maps = await db.query(
      'pontos',
      orderBy: 'dataHora DESC',
      limit: limite,
      offset: offset,
    );
    return maps.map(Ponto.fromMap).toList();
  }

  /// Último ponto inserido
  Future<Ponto?> ultimoPonto() async {
    final db = await database;
    final maps = await db.query(
      'pontos',
      orderBy: 'dataHora DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Ponto.fromMap(maps.first);
  }
}
