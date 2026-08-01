// Test unitario del semáforo de resultado (v17) — RaceCard
// Usa datos REALES de las carreras del profile 1 para verificar la lógica.
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall/widgets/race_card.dart';
import 'package:heimdall/theme.dart';
import 'package:flutter/material.dart';

void main() {
  Map<String, dynamic> race({
    int? start,
    int? finish,
    int incidents = 0,
    bool dnf = false,
    bool dsq = false,
    bool dns = false,
  }) =>
      {
        'start_pos': start,
        'finish_pos': finish,
        'incidents': incidents,
        'dnf': dnf,
        'dsq': dsq,
        'dns': dns,
      };

  Color colorOf(Map<String, dynamic> r) => RaceCard(r: r, onTap: () {}).resultColor;

  group('Semáforo con datos reales (profile 1)', () {
    test('Road America P1->P2, 1 inc = VERDE (podio limpio)', () {
      expect(colorOf(race(start: 1, finish: 2, incidents: 1)), AppColors.green);
    });
    test('Road America P19->P18, 1 inc = AZUL (neutra, +1)', () {
      expect(colorOf(race(start: 19, finish: 18, incidents: 1)), AppColors.blue);
    });
    test('Road America P7->P4, 13 inc = ROJA (muchas incidencias)', () {
      expect(colorOf(race(start: 7, finish: 4, incidents: 13)), AppColors.red);
    });
    test('Road America P8->P10, 9 inc = ROJA (perdió 2)', () {
      expect(colorOf(race(start: 8, finish: 10, incidents: 9)), AppColors.red);
    });
    test('Knockhill P9->P13 = ROJA (perdió 4)', () {
      expect(colorOf(race(start: 9, finish: 13, incidents: 21)), AppColors.red);
    });
    test('Zandvoort P6->P7, 4 inc = AZUL', () {
      expect(colorOf(race(start: 6, finish: 7, incidents: 4)), AppColors.blue);
    });
    test('Zandvoort P12->P12, 20 inc = ROJA', () {
      expect(colorOf(race(start: 12, finish: 12, incidents: 20)), AppColors.red);
    });
    test('DNF = ROJA siempre', () {
      expect(colorOf(race(start: 1, finish: 5, incidents: 2, dnf: true)), AppColors.red);
    });
    test('DSQ = ROJA siempre', () {
      expect(colorOf(race(start: 1, finish: 5, incidents: 2, dsq: true)), AppColors.red);
    });
    test('Ganó 3 con 2 inc = VERDE', () {
      expect(colorOf(race(start: 10, finish: 7, incidents: 2)), AppColors.green);
    });
    test('Podio con 8 inc = AZUL (neutra, no llega a 10)', () {
      expect(colorOf(race(start: 2, finish: 3, incidents: 8)), AppColors.blue);
    });
    test('Podio con 12 inc = ROJA (incidencias)', () {
      expect(colorOf(race(start: 2, finish: 3, incidents: 12)), AppColors.red);
    });
    test('P4 sin gain, 0 inc = AZUL', () {
      expect(colorOf(race(start: 4, finish: 4, incidents: 0)), AppColors.blue);
    });
  });
}
