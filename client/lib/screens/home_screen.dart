import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/navigation_provider.dart';
import '../services/sync_service.dart';
import 'scan_screen.dart';
import 'cart_screen.dart';
import 'shopping_list_screen.dart';
import 'compare_screen.dart';
import 'product_search_screen.dart';
import 'establishments_screen.dart';
import 'operator_settings_screen.dart'; // Importação adicionada

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const List<Widget> _screens = [
    ScanScreen(),
    CartScreen(),
    ShoppingListScreen(),
    CompareScreen(),
    ProductSearchScreen(),
    EstablishmentsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(navigationProvider);

    // Mantém o serviço de sincronização global ativo
    ref.watch(syncServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Comparator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const OperatorSettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(index: selectedIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          ref.read(navigationProvider.notifier).state = index;
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
          NavigationDestination(icon: Icon(Icons.shopping_cart), label: 'Cart'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Listas'),
          NavigationDestination(icon: Icon(Icons.map), label: 'Compare'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Pesquisa'),
          NavigationDestination(icon: Icon(Icons.store), label: 'Locais'),
        ],
      ),
    );
  }
}
