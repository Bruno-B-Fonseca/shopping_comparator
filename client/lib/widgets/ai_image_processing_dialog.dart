import 'package:flutter/material.dart';

class AiImageProcessingDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const AiImageProcessingDialog({
    super.key,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('⚠️ Processamento de Imagem'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A imagem será enviada para processamento de IA:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildInfoBox(
              '🤖 Processador',
              'Google Gemini ou Ollama (conforme sua configuração)',
              Colors.orange.shade50,
            ),
            const SizedBox(height: 12),
            _buildInfoBox(
              '🔍 O que acontece',
              'A IA lerá o código de barras e o preço da etiqueta',
              Colors.blue.shade50,
            ),
            const SizedBox(height: 12),
            _buildInfoBox(
              '⚠️ Privacidade',
              'A imagem será processada por um serviço externo (Google/Ollama)',
              Colors.red.shade50,
            ),
            const SizedBox(height: 16),
            const Text(
              'Você tem certeza que deseja continuar?',
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: onConfirm,
          child: const Text('Enviar para IA'),
        ),
      ],
    );
  }

  Widget _buildInfoBox(String title, String description, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}
