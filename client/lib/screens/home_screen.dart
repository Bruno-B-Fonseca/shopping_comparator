import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/navigation_provider.dart';
import '../services/sync_service.dart';
import 'scan_screen.dart';
import 'cart_screen.dart';
import 'compare_screen.dart';
import 'chat_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const List<Widget> _screens = [
    ScanScreen(),
    CartScreen(),
    CompareScreen(),
    ChatScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(navigationProvider);
    
    // Mantém o serviço de sincronização global ativo
    ref.watch(syncServiceProvider);

    return Scaffold(
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
          NavigationDestination(icon: Icon(Icons.map), label: 'Compare'),
          NavigationDestination(icon: Icon(Icons.chat), label: 'Chat'),
        ],
      ),
    );
  }
}
