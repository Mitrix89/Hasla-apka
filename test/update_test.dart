import 'package:flutter_test/flutter_test.dart';
import 'package:hasla_apka/update/app_updater.dart';

Map<String, dynamic> _release({String tag = 'v1.3.0', bool prerelease = false}) => {
  'tag_name': tag,
  'draft': false,
  'prerelease': prerelease,
  'body':
      "## What's Changed\n"
      '* Aktualizacje w aplikacji by @Mitrix89 in https://github.com/Mitrix89/Hasla-apka/pull/5\n'
      '\n'
      '## New Contributors\n'
      '* @Mitrix89 made their first contribution in https://github.com/Mitrix89/Hasla-apka/pull/1\n'
      '\n'
      '**Full Changelog**: https://github.com/Mitrix89/Hasla-apka/compare/v1.2.0...v1.3.0',
  'assets': [
    {
      'name': 'HaslaApka-Setup-1.3.0.exe',
      'size': 1000,
      'browser_download_url':
          'https://github.com/Mitrix89/Hasla-apka/releases/download/v1.3.0/HaslaApka-Setup-1.3.0.exe',
      'digest': 'sha256:ABCDEF',
    },
    {
      'name': 'HaslaApka-1.3.0.apk',
      'size': 2000,
      'browser_download_url': 'https://github.com/Mitrix89/Hasla-apka/releases/download/v1.3.0/HaslaApka-1.3.0.apk',
    },
  ],
};

void main() {
  group('AppVersion', () {
    test('czyta różne zapisy', () {
      expect(AppVersion.tryParse('v1.2.3'), const AppVersion(1, 2, 3));
      expect(AppVersion.tryParse('1.2.3+4'), const AppVersion(1, 2, 3));
      expect(AppVersion.tryParse('2.0'), const AppVersion(2, 0, 0));
      expect(AppVersion.tryParse('najnowsza'), isNull);
    });

    test('porównuje liczbowo, nie jak tekst', () {
      expect(const AppVersion(1, 10, 0) > const AppVersion(1, 9, 9), isTrue);
      expect(const AppVersion(2, 0, 0) > const AppVersion(1, 99, 99), isTrue);
      expect(const AppVersion(1, 2, 0) > const AppVersion(1, 2, 0), isFalse);
    });
  });

  group('parseRelease', () {
    test('wybiera instalator dla Windows i APK dla Androida', () {
      final win = parseRelease(_release(), UpdatePlatform.windows)!;
      expect(win.fileName, 'HaslaApka-Setup-1.3.0.exe');
      expect(win.version, const AppVersion(1, 3, 0));
      expect(win.size, 1000);
      expect(win.sha256, 'abcdef');

      final android = parseRelease(_release(), UpdatePlatform.android)!;
      expect(android.fileName, 'HaslaApka-1.3.0.apk');
      expect(android.sha256, isNull);
    });

    test('pomija wersje testowe i wydania bez pliku dla platformy', () {
      expect(parseRelease(_release(prerelease: true), UpdatePlatform.android), isNull);
      final noApk = _release()..['assets'] = [(_release()['assets'] as List).first];
      expect(parseRelease(noApk, UpdatePlatform.android), isNull);
    });

    test('odrzuca adresy bez https', () {
      final json = _release();
      (json['assets'] as List)[1]['browser_download_url'] = 'http://example.com/a.apk';
      expect(parseRelease(json, UpdatePlatform.android), isNull);
    });
  });

  test('notatki bez linków i autorów', () {
    expect(cleanReleaseNotes(_release()['body'] as String), '• Aktualizacje w aplikacji');
  });
}
