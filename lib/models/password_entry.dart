/// Jedno zapisane hasło. Może być przypisane do aplikacji, strony albo obu naraz.
class PasswordEntry {
  PasswordEntry({
    required this.id,
    required this.name,
    this.username = '',
    this.password = '',
    List<String>? apps,
    List<String>? websites,
    this.note = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : apps = List.unmodifiable(apps ?? const []),
        websites = List.unmodifiable(websites ?? const []),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  final String id;
  final String name;
  final String username;
  final String password;

  /// Nazwy aplikacji (np. "Netflix") lub nazwy pakietów Androida (np. "com.netflix.mediaclient").
  final List<String> apps;

  /// Adresy stron (np. "netflix.com").
  final List<String> websites;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasApp => apps.isNotEmpty;
  bool get hasWebsite => websites.isNotEmpty;

  PasswordEntry copyWith({
    String? name,
    String? username,
    String? password,
    List<String>? apps,
    List<String>? websites,
    String? note,
    DateTime? updatedAt,
  }) {
    return PasswordEntry(
      id: id,
      name: name ?? this.name,
      username: username ?? this.username,
      password: password ?? this.password,
      apps: apps ?? this.apps,
      websites: websites ?? this.websites,
      note: note ?? this.note,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Czy wpis pasuje do wyszukiwanej frazy (nazwa, login, aplikacje, strony).
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) ||
        username.toLowerCase().contains(q) ||
        apps.any((a) => a.toLowerCase().contains(q)) ||
        websites.any((w) => w.toLowerCase().contains(q));
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'username': username,
        'password': password,
        'apps': apps,
        'websites': websites,
        'note': note,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory PasswordEntry.fromJson(Map<String, dynamic> json) {
    return PasswordEntry(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      apps: (json['apps'] as List?)?.cast<String>(),
      websites: (json['websites'] as List?)?.cast<String>(),
      note: json['note'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '')?.toLocal(),
    );
  }
}
