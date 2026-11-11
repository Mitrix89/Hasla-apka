import 'package:flutter/material.dart';

import '../app.dart';
import '../models/category.dart';
import '../theme.dart';
import '../widgets/category_picker.dart';

/// Lista kategorii haseł: dodawanie, zmiana nazwy i usuwanie.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  Future<void> _rename(BuildContext context, PasswordCategory c) async {
    final name = await askCategoryName(context, initial: c.name, title: 'Zmień nazwę');
    if (name == null || name == c.name || !context.mounted) return;
    await AppScope.of(context).vault.upsertCategory(c.rename(name));
  }

  Future<void> _delete(BuildContext context, PasswordCategory c, int count) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usunąć kategorię?'),
        content: Text(
          count == 0
              ? 'Kategoria „${c.name}” zostanie usunięta.'
              : 'Kategoria „${c.name}” zostanie usunięta. Hasła z niej ($count) zostaną w sejfie.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Anuluj')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await AppScope.of(context).vault.deleteCategory(c.id);
  }

  @override
  Widget build(BuildContext context) {
    final vault = AppScope.of(context).vault;
    return Scaffold(
      appBar: AppBar(title: const Text('Kategorie')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => createCategory(context),
        icon: const Icon(Icons.add),
        label: const Text('Nowa kategoria'),
      ),
      body: ListenableBuilder(
        listenable: vault,
        builder: (context, _) {
          final categories = vault.categories;
          if (categories.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Utwórz kategorie, np. „Bank” albo „Praca”, a potem w haśle użyj przycisku „Dodaj do”.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            );
          }
          final entries = vault.entries;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final (i, c) in categories.indexed) ...[
                      if (i > 0) const Divider(height: 1, color: Color(0xFFEEF0F4)),
                      Builder(
                        builder: (context) {
                          final count = entries.where((e) => e.categoryIds.contains(c.id)).length;
                          return ListTile(
                            leading: const Icon(Icons.folder_outlined, color: AppColors.passwords),
                            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(_countLabel(count)),
                            onTap: () => _rename(context, c),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Zmień nazwę',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _rename(context, c),
                                ),
                                IconButton(
                                  tooltip: 'Usuń',
                                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                                  onPressed: () => _delete(context, c, count),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _countLabel(int n) {
    if (n == 0) return 'Brak haseł';
    if (n == 1) return '1 hasło';
    final few = n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 12 || n % 100 > 14);
    return '$n ${few ? 'hasła' : 'haseł'}';
  }
}
