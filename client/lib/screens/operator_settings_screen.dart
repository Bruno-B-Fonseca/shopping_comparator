import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

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
    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).setCredentials(
            _idController.text.trim(),
            _passwordController.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Credenciais salvas com sucesso!')),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuração de Operador')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
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
                  onPressed: () => ref.read(authProvider.notifier).clearCredentials(),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Limpar Credenciais'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
