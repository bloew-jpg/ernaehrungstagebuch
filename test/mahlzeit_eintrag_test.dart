import 'package:ernaehrungstagebuch/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MahlzeitEintrag', () {
    test('loads a legacy single essmotiv as a list', () {
      final mahlzeit = MahlzeitEintrag.fromJson({
        'minuten': 720,
        'hunger': -2,
        'essmotiv': 'H',
        'text': 'Mittagessen',
      });

      expect(mahlzeit.essmotive, ['H']);
    });

    test('serializes and loads multiple essmotive', () {
      final mahlzeit = MahlzeitEintrag(
        minutenSeitMitternacht: 720,
        hunger: -2,
        essmotive: ['E', 'F'],
        text: 'Mittagessen',
      );

      final geladen = MahlzeitEintrag.fromJson(mahlzeit.toJson());

      expect(geladen.essmotive, ['E', 'F']);
    });
  });
}
