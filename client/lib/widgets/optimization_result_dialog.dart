import 'package:client/providers/active_optimization_provider.dart';
import 'package:client/providers/navigation_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/optimization_result.dart';
import '../providers/optimization_provider.dart';

class OptimizationResultDialog extends ConsumerWidget {
  const OptimizationResultDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(optimizationProvider);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.auto_awesome, color: Colors.amber),
          SizedBox(width: 8),
          Text('Estratégia de Economia'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: state.isLoading
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Analisando preços na região...'),
                ],
              )
            : state.error != null
                ? Text('Erro: ${state.error}', style: const TextStyle(color: Colors.red))
                : state.result == null || state.result!.stores.isEmpty
                    ? const Text('Não encontramos preços suficientes para otimizar sua lista nesta região.')
                    : _buildResultList(context, state.result!),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
        if (state.result != null && state.result!.stores.isNotEmpty)
          ElevatedButton.icon(
            onPressed: () {
              // Define a otimização ativa para o mapa
              ref.read(activeOptimizationProvider.notifier).state = state.result;
              // Muda para a aba de Comparação (Mapa) - Index 3
              ref.read(navigationProvider.notifier).state = 3; 
              Navigator.pop(context);
            },
            icon: const Icon(Icons.directions),
            label: const Text('Ver Rota'),
          ),
      ],
    );
  }

  Widget _buildResultList(BuildContext context, OptimizationResult result) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resumo de Economia
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Economia Estimada',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    Text(
                      'R\$ ${result.estimatedSavings.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total da Cesta',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    Text(
                      'R\$ ${result.totalValue.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Onde comprar:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...result.stores.map((store) => _StoreCard(store: store)),
          if (result.missingItems.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Itens não localizados (${result.missingItems.length}):',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            Text(
              result.missingItems.map((i) => i.name).join(', '),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  final OptimizedStore store;
  const _StoreCard({required this.store});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: const Icon(Icons.store),
        title: Text(store.location.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${store.items.length} itens • Subtotal: R\$ ${store.subtotal.toStringAsFixed(2)}'),
        trailing: IconButton(
          icon: const Icon(Icons.navigation, color: Colors.blue),
          onPressed: () => _openMap(store.location.latitude, store.location.longitude),
          tooltip: 'Navegar para esta loja',
        ),
        children: store.items.map((item) => ListTile(
          dense: true,
          title: Text(item.listItem.name),
          trailing: Text('R\$ ${item.priceUpdate.price.toStringAsFixed(2)}'),
        )).toList(),
      ),
    );
  }

  Future<void> _openMap(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
