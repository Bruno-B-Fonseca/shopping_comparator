import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔒 Política de Privacidade'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              '1. Apresentação',
              'O Shopping Comparator é uma aplicação de comparação de preços 100% descentralizada e anônima. Esta política descreve como seus dados são coletados, armazenados e processados.',
            ),
            _buildSection(
              '2. Quem é o Controlador de Dados?',
              '• Seu dispositivo: Você é o principal controlador dos seus dados locais\n'
              '• Operadores de Estabelecimentos: Controlam dados sobre a localização de suas lojas\n'
              '• A Plataforma: Opera como facilitadora de rede P2P descentralizada',
            ),
            _buildSection(
              '3. Quais Dados Coletamos?',
              'Dados Locais (ficam no seu dispositivo):\n'
              '✓ Carrinho de Compras\n'
              '✓ Preços\n'
              '✓ Histórico\n'
              '✗ Sua identificação pessoal\n\n'
              'Com Consentimento (você autoriza):\n'
              '✓ Localização - para identificar estabelecimentos\n'
              '✓ Imagens - para ler etiquetas com IA',
            ),
            _buildSection(
              '4. Como seus Dados são Armazenados?',
              'Local (seu dispositivo):\n'
              '• Armazenamento: Hive + AES256 (criptografado)\n'
              '• Acesso: Apenas sua aplicação\n'
              '• Sincronização: Automática com rede P2P\n\n'
              'Sincronização P2P:\n'
              '• Hub Server: Retransmite, não armazena\n'
              '• Encriptação: TLS (wss://)',
            ),
            _buildSection(
              '5. Quanto Tempo seus Dados são Retidos?',
              '• Carrinho e Preços: Mantidos enquanto a app existir\n'
              '• Hub Server: Não armazena (apenas retransmite)\n'
              '• Limpeza Manual: Você pode deletar em Configurações\n'
              '• Dados Privados: Não sincronizados quando fora de estabelecimento',
            ),
            _buildSection(
              '6. Seus Direitos (LGPD)',
              '✓ Acessar seus dados - tudo está no app\n'
              '✓ Deletar seus dados - botão em Configurações\n'
              '✓ Corrigir seus dados - edite direto no app\n'
              '✓ Opor-se - toggles em Configurações\n'
              '✓ Não sofrer discriminação - sem scoring',
            ),
            _buildSection(
              '7. Segurança',
              'Protegido:\n'
              '✓ Dados locais criptografados (AES256)\n'
              '✓ Sincronização via TLS\n'
              '✓ Assinatura HMAC de mensagens\n\n'
              'Recomendação: Use bloqueio de tela/biometria do SO',
            ),
            _buildSection(
              '8. Processamento Externo (IA)',
              'Google Gemini:\n'
              '• O quê: Imagens de etiquetas\n'
              '• Por quê: Extrair preço\n'
              '• Controle: Desabilite em Configurações\n\n'
              'Ollama (se configurado):\n'
              '• O quê: Imagens de etiquetas\n'
              '• Por quê: Extrair preço localmente',
            ),
            _buildSection(
              '9. Consentimento',
              '✓ Primeira abertura: Explicação completa\n'
              '✓ Primeira localização: Pede autorização\n'
              '✓ Primeira imagem: Avisa antes de enviar\n'
              '✓ Gerenciar: Vá em Configurações → Resetar Consentimentos',
            ),
            _buildSection(
              '10. Conformidade LGPD',
              '✓ Transparência: Você sabe o que é coletado\n'
              '✓ Consentimento: Dados sensíveis requerem autorização\n'
              '✓ Anonimidade: Sem identificação pessoal\n'
              '✓ Segurança: TLS + AES256\n'
              '✓ Direitos: Acesso, deleção, correção, oposição',
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: const Text(
                '✓ Esta aplicação está em conformidade com a Lei Geral de Proteção de Dados (LGPD - Lei 13.709/2018)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Color(0xFF1E88E5),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(fontSize: 12, height: 1.6),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
