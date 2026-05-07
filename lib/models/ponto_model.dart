// lib/models/ponto_model.dart

class Ponto {
  final int? id;
  final DateTime dataHora;
  final String data;
  final String hora;
  final String? nome;
  final String? nsr;
  final String tipo; // 'entrada' | 'saida' | 'pausa' | 'retorno'
  final String? fotoPath;
  final String? observacao;

  Ponto({
    this.id,
    required this.dataHora,
    required this.data,
    required this.hora,
    this.nome,
    this.nsr,
    required this.tipo,
    this.fotoPath,
    this.observacao,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dataHora': dataHora.toIso8601String(),
      'data': data,
      'hora': hora,
      'nome': nome,
      'nsr': nsr,
      'tipo': tipo,
      'fotoPath': fotoPath,
      'observacao': observacao,
    };
  }

  factory Ponto.fromMap(Map<String, dynamic> map) {
    return Ponto(
      id: map['id'] as int?,
      dataHora: DateTime.parse(map['dataHora'] as String),
      data: map['data'] as String,
      hora: map['hora'] as String,
      nome: map['nome'] as String?,
      nsr: map['nsr'] as String?,
      tipo: map['tipo'] as String,
      fotoPath: map['fotoPath'] as String?,
      observacao: map['observacao'] as String?,
    );
  }

  Ponto copyWith({
    int? id,
    DateTime? dataHora,
    String? data,
    String? hora,
    String? nome,
    String? nsr,
    String? tipo,
    String? fotoPath,
    String? observacao,
  }) {
    return Ponto(
      id: id ?? this.id,
      dataHora: dataHora ?? this.dataHora,
      data: data ?? this.data,
      hora: hora ?? this.hora,
      nome: nome ?? this.nome,
      nsr: nsr ?? this.nsr,
      tipo: tipo ?? this.tipo,
      fotoPath: fotoPath ?? this.fotoPath,
      observacao: observacao ?? this.observacao,
    );
  }
}

/// Agrupa pontos em pares entrada/saída para calcular períodos trabalhados
class PeriodoTrabalhado {
  final Ponto entrada;
  final Ponto? saida;

  PeriodoTrabalhado({required this.entrada, this.saida});

  Duration get duracao {
    if (saida == null) {
      return DateTime.now().difference(entrada.dataHora);
    }
    return saida!.dataHora.difference(entrada.dataHora);
  }

  bool get emAndamento => saida == null;
}
