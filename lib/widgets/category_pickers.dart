import 'package:flutter/material.dart';

import '../core/color_utils.dart';
import '../models/category.dart';

class CategoryDropdown extends StatelessWidget {
  final List<Category> categories;
  final String? value;
  final ValueChanged<String?> onChanged;

  const CategoryDropdown({
    super.key,
    required this.categories,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Category (optional)'),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('None')),
        ...categories.map(
          (c) => DropdownMenuItem<String?>(
            value: c.id,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(radius: 6, backgroundColor: colorFromHex(c.colorHex)),
                const SizedBox(width: 8),
                Text(c.name),
              ],
            ),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class CategoryMultiSelect extends StatelessWidget {
  final List<Category> categories;
  final List<String> selectedIds;
  final ValueChanged<List<String>> onChanged;

  const CategoryMultiSelect({
    super.key,
    required this.categories,
    required this.selectedIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const Text('No categories yet.');
    }
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: categories.map((c) {
        final selected = selectedIds.contains(c.id);
        return FilterChip(
          label: Text(c.name),
          avatar: CircleAvatar(backgroundColor: colorFromHex(c.colorHex)),
          selected: selected,
          onSelected: (isSelected) {
            final next = [...selectedIds];
            if (isSelected) {
              next.add(c.id);
            } else {
              next.remove(c.id);
            }
            onChanged(next);
          },
        );
      }).toList(),
    );
  }
}

Category? categoryById(List<Category> categories, String? id) {
  if (id == null) return null;
  for (final c in categories) {
    if (c.id == id) return c;
  }
  return null;
}
