import 'package:flutter_test/flutter_test.dart';
import 'package:hasla_apka/util/password_generator.dart';

void main() {
  test('hasło ma żądaną długość i wszystkie rodzaje znaków', () {
    for (var i = 0; i < 200; i++) {
      final p = generatePassword(length: 12);
      expect(p.length, 12);
      expect(p, matches(RegExp('[a-z]')));
      expect(p, matches(RegExp('[A-Z]')));
      expect(p, matches(RegExp('[0-9]')));
      expect(p, matches(RegExp(r'[^a-zA-Z0-9]')));
    }
  });

  test('kolejne hasła się różnią', () {
    expect(List.generate(50, (_) => generatePassword()).toSet().length, 50);
  });

  test('za krótkie hasło jest odrzucane', () {
    expect(() => generatePassword(length: 4), throwsArgumentError);
  });
}
