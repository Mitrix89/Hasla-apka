import 'dart:math';

const _lower = 'abcdefghijkmnopqrstuvwxyz';
const _upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
const _digits = '23456789';
const _symbols = '!@#\$%&*?-_=+';

/// Generuje losowe, silne hasło. Zawsze zawiera małą i wielką literę, cyfrę i znak specjalny.
String generatePassword({int length = 18, Random? random}) {
  if (length < 8) throw ArgumentError.value(length, 'length', 'co najmniej 8 znaków');
  final rnd = random ?? Random.secure();
  const all = _lower + _upper + _digits + _symbols;
  String pick(String set) => set[rnd.nextInt(set.length)];
  final chars = <String>[pick(_lower), pick(_upper), pick(_digits), pick(_symbols)];
  while (chars.length < length) {
    chars.add(pick(all));
  }
  chars.shuffle(rnd);
  return chars.join();
}
