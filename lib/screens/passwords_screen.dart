import 'package:flutter/material.dart';

import '../app.dart';
import '../models/password_entry.dart';
import '../theme.dart';
import '../widgets/letter_avatar.dart';
import 'import_screen.dart';
import 'password_edit_screen.dart';

enum PasswordFilter { all, apps, websites }

/// Lista haseł. Na szerokim ekranie (komputer) obok listy widać szczegóły wybranego hasła.
class PasswordsScreen extends StatefulWidget {
  const PasswordsScreen({super.key});

  static const wideLayoutWidth = 900.0;

  @override
  State<PasswordsScreen> createState() => _PasswordsScreenState();
}

class _PasswordsScreenState extends State<PasswordsScreen> {
  final _search = TextEditingController();
  PasswordFilter _filter = PasswordFilter.all;
  String? _selectedId;
  bool _creating = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<PasswordEntry> _visible(List<PasswordEntry> all) {
    return all.where((e) {
      if (!e.matches(_search.text)) return false;
      return switch (_filter) {
        PasswordFilter.all => true,
        PasswordFilter.apps => e.hasApp,
        PasswordFilter.websites => e.hasWebsite,
      };
    }).toList();
  }

  bool _isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= PasswordsScreen.wideLayoutWidth;

  void _open(PasswordEntry? entry) {
    if (_isWide(context)) {
      setState(() {
        _selectedId = entry?.id;
        _creating = entry == null;
      });
    } else {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => PasswordEditScreen(entryId: entry?.id)));
    }
  }

  Future<void> _openImport() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ImportScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final vault = AppScope.of(context).vault;
    final wide = _isWide(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hasła'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Więcej',
            onSelected: (v) {
              if (v == 'import') _openImport();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'import', child: Text('Importuj z Haseł Google')),
            ],
          ),
          IconButton(tooltip: 'Zablokuj', icon: const Icon(Icons.lock_outline), onPressed: vault.lock),
        ],
      ),
      floatingActionButton: wide
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _open(null),
              icon: const Icon(Icons.add),
              label: const Text('Dodaj hasło'),
            ),
      body: ListenableBuilder(
        listenable: vault,
        builder: (context, _) {
          final all = vault.entries;
          final list = _buildList(context, all, wide);
          if (!wide) return list;
          final selected = _selectedId == null ? null : vault.byId(_selectedId!);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 400, child: list),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 24, 24),
                  child: Card(
                    child: (selected == null && !_creating)
                        ? const Center(
                            child: Text('Wybierz hasło z listy', style: TextStyle(color: AppColors.muted)),
                          )
                        : PasswordForm(
                            key: ValueKey(selected?.id ?? 'new'),
                            entry: selected,
                            onSaved: (e) => setState(() {
                              _selectedId = e.id;
                              _creating = false;
                            }),
                            onDeleted: () => setState(() => _selectedId = null),
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(BuildContext context, List<PasswordEntry> all, bool wide) {
    final visible = _visible(all);
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, wide ? 8 : 16, 96),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Szukaj aplikacji, strony lub loginu',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Wyczyść',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(_search.clear),
                        ),
                ),
              ),
            ),
            if (wide) ...[
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _open(null),
                icon: const Icon(Icons.add),
                label: const Text('Dodaj'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final (f, label) in const [
              (PasswordFilter.all, 'Wszystkie'),
              (PasswordFilter.apps, 'Aplikacje'),
              (PasswordFilter.websites, 'Strony'),
            ])
              ChoiceChip(
                label: Text(label),
                selected: _filter == f,
                onSelected: (_) => setState(() => _filter = f),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (all.isEmpty)
          _EmptyState(onAdd: () => _open(null), onImport: _openImport)
        else if (visible.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Text('Nic nie znaleziono', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
          )
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (i, e) in visible.indexed) ...[
                  if (i > 0) const Divider(height: 1, color: Color(0xFFEEF0F4)),
                  ListTile(
                    selected: wide && e.id == _selectedId,
                    selectedTileColor: AppColors.passwordsSoft,
                    leading: LetterAvatar(e.name),
                    title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: e.username.isEmpty
                        ? null
                        : Text(e.username, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (e.hasApp) const KindTag.app(),
                        if (e.hasApp && e.hasWebsite) const SizedBox(width: 4),
                        if (e.hasWebsite) const KindTag.web(),
                      ],
                    ),
                    onTap: () => _open(e),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd, required this.onImport});
  final VoidCallback onAdd;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.key_outlined, size: 40, color: AppColors.passwords),
            const SizedBox(height: 12),
            const Text('Nie masz jeszcze haseł', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text(
              'Dodaj pierwsze hasło albo przenieś wszystkie z Haseł Google.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton(onPressed: onAdd, child: const Text('Dodaj hasło')),
                OutlinedButton(onPressed: onImport, child: const Text('Importuj z Google')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
