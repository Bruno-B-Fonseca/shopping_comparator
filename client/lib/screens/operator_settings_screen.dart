import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../providers/consent_provider.dart';
import '../services/storage_service.dart';
import '../services/image_service.dart';
import 'privacy_policy_screen.dart';

/// Tela para configuração das credenciais de Operador do Local.
/// Permite ao operador salvar a LocationID e a LocationPassword localmente.
class OperatorSettingsScreen extends ConsumerStatefulWidget {
  const OperatorSettingsScreen({super.key});

  @override
  ConsumerState<OperatorSettingsScreen> createState() =>
      _OperatorSettingsScreenState();
}

class _OperatorSettingsScreenState
    extends ConsumerState<OperatorSettingsScreen> {
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = ref.read(authProvider);
      _idController.text = auth.locationId ?? '';
      _passwordController.text = auth.locationPassword ?? '';
    });
  }

  Future<void> _saveCredentials() async {
    final id = _idController.text.trim();
    final password = _passwordController.text.trim();

    if (id.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, preencha o ID e a Senha')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final success = await ref.read(authProvider.notifier).verifyAndSetCredentials(
            id,
            password,
          );
          
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Credenciais validadas e salvas com sucesso!')),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Falha na autenticação: ID ou Senha inválidos para este servidor.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao conectar com o servidor: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final consent = ref.watch(consentProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SEÇÃO: Operador
            const Text(
              '👤 Configuração de Operador',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _idController,
              decoration: const InputDecoration(
                labelText: 'Location ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Location Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveCredentials,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Salvar Credenciais'),
            ),
            if (ref.watch(authProvider).isOperator)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: TextButton(
                  onPressed: () =>
                      ref.read(authProvider.notifier).clearCredentials(),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Limpar Credenciais'),
                ),
              ),
            if (ref.watch(authProvider).isOperator) ...[
              const SizedBox(height: 40),
              // SEÇÃO: Importação (Apenas Operador)
              const Text(
                '📥 Importação de Dados',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _importProductsJson,
                icon: const Icon(Icons.file_upload),
                label: const Text('Importar Produtos (JSON)'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
              const Text(
                'O arquivo deve conter uma lista de produtos. Produtos já existentes (mesmo barcode) serão pulados.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 40),

            // SEÇÃO: Privacidade e Consentimentos
            const Text(
              '🔒 Privacidade e Consentimentos',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            _buildConsentTile(
              title: '📍 Compartilhamento de Localização',
              subtitle:
                  'Permitir que sua localização seja usada para identificar estabelecimentos próximos',
              value: consent.locationConsent,
              onChanged: (value) async {
                await ref
                    .read(consentProvider.notifier)
                    .setLocationConsent(value);
              },
            ),
            const SizedBox(height: 12),
            _buildConsentTile(
              title: '🤖 Processamento de Imagens com IA',
              subtitle:
                  'Permitir que imagens de etiquetas sejam processadas por Google Gemini ou Ollama',
              value: consent.aiProcessingConsent,
              onChanged: (value) async {
                await ref
                    .read(consentProvider.notifier)
                    .setAiProcessingConsent(value);
              },
            ),
            const SizedBox(height: 24),

            // SEÇÃO: Dados
            const Text(
              '📊 Gerenciar Dados',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _showDeleteDataDialog,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Apagar histórico local'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _showResetConsentsDialog,
              icon: const Icon(Icons.refresh),
              label: const Text('Resetar consentimentos'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _showClearMapCacheDialog,
              icon: const Icon(Icons.map_outlined),
              label: const Text('Limpar cache de mapas'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PrivacyPolicyScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.policy),
              label: const Text('Ver Política de Privacidade'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsentTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch(
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importProductsJson() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final bytes = result.files.first.bytes;
      if (bytes == null) return;

      final content = utf8.decode(bytes);
      final dynamic jsonData = jsonDecode(content);

      if (jsonData is! List) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Formato inválido: o JSON deve ser uma lista de produtos.',
              ),
            ),
          );
        }
        return;
      }

      setState(() => _isLoading = true);
      int importedCount = 0;
      int skippedCount = 0;
      int imagesSynced = 0;

      final baseUrl = ImageService.baseUrl;

      for (var item in jsonData) {
        try {
          final Map<String, dynamic> itemMap = Map<String, dynamic>.from(item);
          final product = Product.fromJson(itemMap);

          // Verifica se já existe
          if (StorageService.products.containsKey(product.barcode)) {
            skippedCount++;
            continue;
          }

          // Tenta baixar a imagem externa para o MinIO local
          String? finalPhotoUrl = product.photoUrl;
          if (finalPhotoUrl != null &&
              finalPhotoUrl.isNotEmpty &&
              !finalPhotoUrl.startsWith(baseUrl) &&
              (finalPhotoUrl.startsWith('http://') ||
                  finalPhotoUrl.startsWith('https://'))) {
            try {
              debugPrint('Import: Baixando imagem externa -> $finalPhotoUrl');
              final response = await http
                  .get(Uri.parse(finalPhotoUrl))
                  .timeout(const Duration(seconds: 10));

              if (response.statusCode == 200) {
                final localUrl = await ImageService.uploadImage(
                  response.bodyBytes,
                );
                if (localUrl != null) {
                  finalPhotoUrl = localUrl;
                  imagesSynced++;
                }
              }
            } catch (imgErr) {
              debugPrint('Import: Erro ao baixar imagem para ${product.barcode}: $imgErr');
            }
          }

          final updatedProduct = Product(
            barcode: product.barcode,
            name: product.name,
            unit: product.unit,
            manufacturer: product.manufacturer,
            photoUrl: finalPhotoUrl,
            nutritionalInfo: product.nutritionalInfo,
          );

          await StorageService.products.put(
            updatedProduct.barcode,
            updatedProduct,
          );
          importedCount++;
        } catch (e) {
          debugPrint('Erro ao importar produto individual: $e');
        }
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Importação Concluída'),
            content: Text(
              'Sucesso: $importedCount produtos importados.\n'
              'Imagens Localizadas: $imagesSynced.\n'
              'Ignorados: $skippedCount produtos já existiam.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao importar arquivo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showDeleteDataDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('⚠️ Apagar Dados'),
        content: const Text(
          'Isso apagará seu histórico local (carrinho, preços, etc.). Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await StorageService.products.clear();
              await StorageService.prices.clear();
              await StorageService.cart.clear();
              await StorageService.locations.clear();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Histórico local apagado com sucesso'),
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Apagar tudo'),
          ),
        ],
      ),
    );
  }

  void _showResetConsentsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('🔄 Resetar Consentimentos'),
        content: const Text(
          'Seus consentimentos serão resetados. Você verá os diálogos de privacidade novamente na próxima ação.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(consentProvider.notifier).resetAllConsents();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Consentimentos resetados'),
                  ),
                );
              }
            },
            child: const Text('Resetar'),
          ),
        ],
      ),
    );
  }

  void _showClearMapCacheDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('🗺️ Limpar Cache de Mapas'),
        content: const Text(
          'Isso apagará todos os tiles de mapa baixados. Você precisará de internet para visualizar o mapa novamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await StorageService.mapTiles.clear();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cache de mapas limpo com sucesso'),
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Limpar Cache'),
          ),
        ],
      ),
    );
  }
}
