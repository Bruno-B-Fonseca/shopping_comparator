import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/consent_provider.dart';
import '../screens/privacy_policy_screen.dart';

class PrivacyConsentDialog extends ConsumerWidget {
  const PrivacyConsentDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      title: const Text('🔒 Sua Privacidade'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Esta aplicação funciona de forma DESCENTRALIZADA:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildPrivacyPoint(
              '📍 Localização',
              'Usada APENAS localmente para determinar se você está dentro de um estabelecimento. Seus dados são compartilhados com a rede SOMENTE se estiver dentro do local.',
            ),
            const SizedBox(height: 12),
            _buildPrivacyPoint(
              '🖥️ Armazenamento',
              'Tudo fica no seu dispositivo. Nenhum servidor central armazena seus dados pessoais.',
            ),
            const SizedBox(height: 12),
            _buildPrivacyPoint(
              '🤝 Rede P2P',
              'Os dados são compartilhados entre usuários de forma descentralizada. O servidor apenas retransmite mensagens.',
            ),
            const SizedBox(height: 12),
            _buildPrivacyPoint(
              '⚠️ Imagens',
              'Se você optar por usar IA para ler preços em etiquetas, as imagens serão processadas por Google Gemini ou Ollama.',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '✅ Você é 100% anônimo. Nenhuma conta, nenhuma identificação pessoal.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const PrivacyPolicyScreen(),
              ),
            );
          },
          child: const Text('Ler mais'),
        ),
        ElevatedButton(
          onPressed: () async {
            await ref
                .read(consentProvider.notifier)
                .setPrivacyAcknowledged(true);
            if (context.mounted) Navigator.pop(context, true);
          },
          child: const Text('Entendi, continuar'),
        ),
      ],
    );
  }

  Widget _buildPrivacyPoint(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
