import 'dart:io';

/// Miejsce, w którym leży zaszyfrowany plik sejfu.
abstract class VaultStore {
  Future<String?> read();
  Future<void> write(String contents);
}

/// Sejf w pliku na dysku. Zapis jest atomowy: najpierw plik tymczasowy, potem podmiana,
/// więc przerwany zapis nie uszkodzi sejfu.
class FileVaultStore implements VaultStore {
  FileVaultStore(this.path);
  final String path;

  @override
  Future<String?> read() async {
    final file = File(path);
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  @override
  Future<void> write(String contents) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    final tmp = File('$path.tmp');
    await tmp.writeAsString(contents, flush: true);
    await tmp.rename(path);
  }
}

/// Sejf w pamięci, używany w testach.
class MemoryVaultStore implements VaultStore {
  String? contents;
  int writes = 0;

  @override
  Future<String?> read() async => contents;

  @override
  Future<void> write(String contents) async {
    this.contents = contents;
    writes++;
  }
}
