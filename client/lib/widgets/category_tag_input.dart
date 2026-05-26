import 'package:flutter/material.dart';

/// Um componente de entrada de texto que transforma sentenças em TAGS.
/// As tags são separadas por vírgula e exibidas em MAIÚSCULO.
class CategoryTagInput extends StatefulWidget {
  final String? initialValue;
  final Function(String) onChanged;

  const CategoryTagInput({
    super.key,
    this.initialValue,
    required this.onChanged,
  });

  @override
  State<CategoryTagInput> createState() => _CategoryTagInputState();
}

class _CategoryTagInputState extends State<CategoryTagInput> {
  final List<String> _tags = [];
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null && widget.initialValue!.isNotEmpty) {
      // Converte a string "A > B > C" para a lista ["A", "B", "C"]
      _tags.addAll(
        widget.initialValue!.split('>').map((s) => s.trim().toUpperCase()),
      );
    }
  }

  void _addTag(String value) {
    final cleanValue = value.trim().toUpperCase();
    if (cleanValue.isNotEmpty && !_tags.contains(cleanValue)) {
      setState(() {
        _tags.add(cleanValue);
        _controller.clear();
      });
      _notify();
    }
  }

  void _removeTag(int index) {
    setState(() {
      _tags.removeAt(index);
    });
    _notify();
  }

  void _notify() {
    // Converte de volta para o formato interno "A > B > C"
    widget.onChanged(_tags.join(' > '));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Categoria (separe níveis por vírgula)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _tags.asMap().entries.map((entry) {
                      return InputChip(
                        label: Text(entry.value, style: const TextStyle(fontSize: 12)),
                        onDeleted: () => _removeTag(entry.key),
                        deleteIconColor: Theme.of(context).colorScheme.error,
                        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                      );
                    }).toList(),
                  ),
                ),
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Ex: BEBIDAS, CERVEJAS',
                  border: InputBorder.none,
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 14),
                onChanged: (value) {
                  // Se digitar vírgula, transforma o que veio antes em tag
                  if (value.contains(',')) {
                    final parts = value.split(',');
                    for (var i = 0; i < parts.length - 1; i++) {
                      _addTag(parts[i]);
                    }
                    _controller.text = parts.last;
                  }
                },
                onSubmitted: (value) {
                  _addTag(value);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
