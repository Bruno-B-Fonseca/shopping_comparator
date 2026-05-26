import 'package:flutter/material.dart';

/// Um componente que separa Informações Nutricionais em campos distintos
/// mas retorna uma única string formatada para persistência.
class NutritionalInfoInput extends StatefulWidget {
  final String? initialValue;
  final Function(String) onChanged;

  const NutritionalInfoInput({
    super.key,
    this.initialValue,
    required this.onChanged,
  });

  @override
  State<NutritionalInfoInput> createState() => _NutritionalInfoInputState();
}

class _NutritionalInfoInputState extends State<NutritionalInfoInput> {
  final _calController = TextEditingController();
  final _carbController = TextEditingController();
  final _protController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _parseInitialValue();
  }

  void _parseInitialValue() {
    final value = widget.initialValue ?? '';
    if (value.isEmpty) return;

    // Regex para extrair valores entre os separadores " | "
    final calMatch = RegExp(r'Calorias: ([^|]+)').firstMatch(value);
    final carbMatch = RegExp(r'Carboidratos: ([^|]+)').firstMatch(value);
    final protMatch = RegExp(r'Proteínas: ([^|]+)').firstMatch(value);

    if (calMatch != null) _calController.text = calMatch.group(1)!.trim();
    if (carbMatch != null) _carbController.text = carbMatch.group(1)!.trim();
    if (protMatch != null) _protController.text = protMatch.group(1)!.trim();
  }

  void _update() {
    final List<String> parts = [];
    if (_calController.text.isNotEmpty) {
      parts.add('Calorias: ${_calController.text.trim()}');
    }
    if (_carbController.text.isNotEmpty) {
      parts.add('Carboidratos: ${_carbController.text.trim()}');
    }
    if (_protController.text.isNotEmpty) {
      parts.add('Proteínas: ${_protController.text.trim()}');
    }
    
    widget.onChanged(parts.join(' | '));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Informações Nutricionais',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildField(
                controller: _calController,
                label: 'Calorias',
                hint: 'ex: 120kcal',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildField(
                controller: _carbController,
                label: 'Carbos',
                hint: 'ex: 20g',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildField(
                controller: _protController,
                label: 'Proteínas',
                hint: 'ex: 5g',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        labelStyle: const TextStyle(fontSize: 12),
        hintStyle: const TextStyle(fontSize: 10),
      ),
      style: const TextStyle(fontSize: 13),
      onChanged: (_) => _update(),
    );
  }
}
