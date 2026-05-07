// Widget smoke tests dependem de sqflite / prefs no dispositivo alvo.
// Aqui validamos utilitários estáveis do provider.

import 'package:flutter_test/flutter_test.dart';

import 'package:ponto_app/providers/ponto_provider.dart';

void main() {
  test('formatarDuracao formata horas e minutos', () {
    expect(
      PontoProvider.formatarDuracao(const Duration(hours: 2, minutes: 5)),
      '2h 05m',
    );
    expect(
      PontoProvider.formatarDuracao(const Duration(hours: -1, minutes: -30)),
      '-1h 30m',
    );
  });
}
