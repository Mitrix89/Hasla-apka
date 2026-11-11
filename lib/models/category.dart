/// Kategoria haseł utworzona przez użytkownika (np. „Bank”, „Praca”).
class PasswordCategory {
  PasswordCategory({required this.id, required this.name, DateTime? updatedAt})
    : updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String name;
  final DateTime updatedAt;

  PasswordCategory rename(String name) => PasswordCategory(id: id, name: name);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'updatedAt': updatedAt.toUtc().toIso8601String()};

  factory PasswordCategory.fromJson(Map<String, dynamic> json) => PasswordCategory(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '')?.toLocal(),
  );
}
