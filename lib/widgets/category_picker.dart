import 'package:flutter/material.dart';

import '../app.dart';
import '../models/category.dart';
import '../theme.dart';
import '../util/ids.dart';

/// Pyta o nazwę kategorii. Zwraca null, gdy anulowano albo nazwa jest pusta.
Future<String?> askCategoryName(BuildContext context, {String initial = '', String title = 'Nowa kategoria'}) async {
  final controller = TextEditingController(text: initial);
  final value = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'np. Bank, Praca, Gry'),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Anuluj')),
        FilledButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Zapisz')),
      ],
    ),
  );
  controller.dispose();
  final name = value?.trim() ?? '';
  return name.isEmpty ? null : name;
}

/// Tworzy nową kategorię w sejfie i ją zwraca (albo istniejącą o tej samej nazwie).
Future<PasswordCategory?> createCategory(BuildContext context) async {
  final vault = AppScope.of(context).vault;
  final name = await askCategoryName(context);
  if (name == null) return null;
  for (final c in vault.categories) {
    if (c.name.toLowerCase() == name.toLowerCase()) return c;
  }
  final category = PasswordCategory(id: newId(), name: name);
  await vault.upsertCategory(category);
  return category;
}

/// Okno „Dodaj do”: wszystkie kategorie z zaznaczeniem. Zwraca nowy wybór albo null po anulowaniu.
Future<List<String>?> showCategoryPicker(BuildContext context, List<String> selected) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CategoryPickerSheet(initial: selected),
  );
}

class _CategoryPickerSheet extends StatefulWidget {
  const _CategoryPickerSheet({required this.initial});
  final List<String> initial;

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  late final Set<String> _selected = {...widget.initial};

  Future<void> _create() async {
    final c = await createCategory(context);
    if (c != null && mounted) setState(() => _selected.add(c.id));
  }

  @override
  Widget build(BuildContext context) {
    final vault = AppScope.of(context).vault;
    return ListenableBuilder(
      listenable: vault,
      builder: (context, _) {
        final categories = vault.categories;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text('Dodaj do', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                ),
                if (categories.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Text(
                      'Nie masz jeszcze kategorii. Utwórz pierwszą poniżej.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final c in categories)
                        CheckboxListTile(
                          value: _selected.contains(c.id),
                          title: Text(c.name),
                          secondary: const Icon(Icons.folder_outlined),
                          onChanged: (v) => setState(() => v == true ? _selected.add(c.id) : _selected.remove(c.id)),
                        ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.create_new_folder_outlined, color: AppColors.passwords),
                  title: const Text('Nowa kategoria', style: TextStyle(color: AppColors.passwords)),
                  onTap: _create,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Anuluj'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          // Kolejność jak na liście kategorii; pomija kategorie usunięte w międzyczasie.
                          onPressed: () => Navigator.of(context).pop([
                            for (final c in categories)
                              if (_selected.contains(c.id)) c.id,
                          ]),
                          child: const Text('Gotowe'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
