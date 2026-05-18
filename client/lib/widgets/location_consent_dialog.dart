import 'package:flutter/material.dart';

class LocationConsentDialog extends StatelessWidget {
  final VoidCallback onAllow;
  final VoidCallback onDeny;

  const LocationConsentDialog({
    super.key,
    required this.onAllow,
    required this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('📍 Permissão de Localização'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A aplicação precisa de sua localização para:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildFeature(
              '✅ Identificar estabelecimentos próximos',
              'Mostra lojas, supermercados e padarias na sua região',
            ),
            const SizedBox(height: 12),
            _buildFeature(
              '✅ Compartilhamento inteligente',
              'Seus preços são compartilhados APENAS quando você está dentro de um estabelecimento',
            ),
            const SizedBox(height: 12),
            _buildFeature(
              '✅ Privacidade preservada',
              'Fora do estabelecimento, seus dados ficam locais e não são compartilhados',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🔒 Como sua privacidade é protegida:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Sua localização é processada LOCALMENTE no seu dispositivo\n'
                    '• Nenhum servidor central armazena seu histórico de localização\n'
                    '• Você permanece 100% anônimo',
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: onDeny,
          child: const Text('Agora não'),
        ),
        ElevatedButton(
          onPressed: onAllow,
          child: const Text('Permitir localização'),
        ),
      ],
    );
  }

  Widget _buildFeature(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}
