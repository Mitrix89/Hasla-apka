import 'package:flutter_test/flutter_test.dart';
import 'package:hasla_apka/import/google_csv.dart';

void main() {
  test('parser CSV obsługuje cudzysłowy, przecinki i nowe linie', () {
    const csv = 'a,b,c\r\n"x, y","He said ""hi""","linia1\nlinia2"\r\n';
    expect(parseCsv(csv), [
      ['a', 'b', 'c'],
      ['x, y', 'He said "hi"', 'linia1\nlinia2'],
    ]);
  });

  test('parser CSV usuwa BOM i puste linie', () {
    expect(parseCsv('﻿name,url\n\nn,u'), [
      ['name', 'url'],
      ['n', 'u'],
    ]);
  });

  test('niezamknięty cudzysłów to błąd', () {
    expect(() => parseCsv('a,"b'), throwsA(isA<CsvImportException>()));
  });

  test('eksport z Haseł Google', () {
    const csv = 'name,url,username,password,note\n'
        'netflix.com,https://www.netflix.com/login,jan@example.com,Kino!2026,\n'
        ',android://abc123==@com.vectra.app/,12345,"p,a""ss",profil rodzinny\n'
        'allegro.pl,https://allegro.pl/,jan,haslo,\n';
    final entries = parseGooglePasswordsCsv(csv);
    expect(entries.length, 3);

    expect(entries[0].name, 'netflix.com');
    expect(entries[0].websites, ['netflix.com']);
    expect(entries[0].apps, isEmpty);
    expect(entries[0].username, 'jan@example.com');
    expect(entries[0].password, 'Kino!2026');

    expect(entries[1].name, 'com.vectra.app');
    expect(entries[1].apps, ['com.vectra.app']);
    expect(entries[1].websites, isEmpty);
    expect(entries[1].password, 'p,a"ss');
    expect(entries[1].note, 'profil rodzinny');

    expect(entries.map((e) => e.id).toSet().length, 3);
  });

  test('plik bez wymaganych kolumn jest odrzucany', () {
    expect(() => parseGooglePasswordsCsv('foo,bar\n1,2'), throwsA(isA<CsvImportException>()));
    expect(() => parseGooglePasswordsCsv(''), throwsA(isA<CsvImportException>()));
  });

  test('adresy stron i aplikacji', () {
    expect(websiteFromUrl('https://www.netflix.com/login?x=1'), 'netflix.com');
    expect(websiteFromUrl('allegro.pl'), 'allegro.pl');
    expect(androidPackageFromUrl('android://HASH@com.netflix.mediaclient/'), 'com.netflix.mediaclient');
    expect(androidPackageFromUrl('https://netflix.com'), isNull);
  });
}
