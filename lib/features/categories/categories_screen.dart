import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/color_utils.dart';
import '../../models/category.dart';
import '../../providers/app_providers.dart';
import '../../widgets/sign_out_button.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final repo = ref.read(categoryRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Categories'), actions: const [SignOutButton()]),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: categoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return const Center(child: Text('No categories yet. Tap + to add one.'));
          }
          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return ListTile(
                leading: CircleAvatar(backgroundColor: colorFromHex(category.colorHex)),
                title: Text(category.name),
                onTap: () => _showCategoryDialog(context, ref, category: category),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => repo.deleteCategory(category.id),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Future<void> _showCategoryDialog(BuildContext context, WidgetRef ref, {Category? category}) {
    return showDialog(
      context: context,
      builder: (_) => _CategoryFormDialog(category: category),
    );
  }
}

class _CategoryFormDialog extends ConsumerStatefulWidget {
  final Category? category;

  const _CategoryFormDialog({this.category});

  @override
  ConsumerState<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends ConsumerState<_CategoryFormDialog> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.category?.name ?? '');
  late Color _color = widget.category != null
      ? colorFromHex(widget.category!.colorHex)
      : categoryColorPalette.first;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final repo = ref.read(categoryRepositoryProvider);
    final existing = widget.category;

    if (existing == null) {
      repo
          .addCategory(
            userId: ref.read(currentUserIdProvider),
            name: name,
            colorHex: colorToHex(_color),
          )
          .catchError((e) => ref.read(errorReporterProvider).report(e));
    } else {
      repo
          .updateCategory(Category(
            id: existing.id,
            userId: existing.userId,
            name: name,
            colorHex: colorToHex(_color),
            createdAt: existing.createdAt,
          ))
          .catchError((e) => ref.read(errorReporterProvider).report(e));
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.category == null ? 'New Category' : 'Edit Category'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name'),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categoryColorPalette.map((c) {
              final selected = c.toARGB32() == _color.toARGB32();
              return GestureDetector(
                onTap: () => setState(() => _color = c),
                child: CircleAvatar(
                  backgroundColor: c,
                  radius: 16,
                  child: selected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
