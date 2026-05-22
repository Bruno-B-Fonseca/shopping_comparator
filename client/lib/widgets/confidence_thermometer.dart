import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/reputation_provider.dart';

class ConfidenceThermometer extends ConsumerStatefulWidget {
  const ConfidenceThermometer({super.key});

  @override
  ConsumerState<ConfidenceThermometer> createState() => _ConfidenceThermometerState();
}

class _ConfidenceThermometerState extends ConsumerState<ConfidenceThermometer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final score = ref.watch(reputationProvider);
    final colorScheme = Theme.of(context).colorScheme;

    String label;
    IconData icon;
    Color color;
    double progress;
    bool isHot = false;

    if (score < 10) {
      label = 'Colaborador Iniciante';
      icon = Icons.ac_unit;
      color = Colors.blue;
      progress = (score / 10).clamp(0.1, 1.0);
    } else if (score < 50) {
      label = 'Informante Local';
      icon = Icons.wb_sunny;
      color = Colors.orange;
      progress = (score / 50).clamp(0.1, 1.0);
    } else if (score < 100) {
      label = 'Vigilante de Preços';
      icon = Icons.local_fire_department;
      color = Colors.deepOrange;
      progress = (score / 100).clamp(0.1, 1.0);
      isHot = true;
    } else {
      label = 'Mestre da Economia';
      icon = Icons.whatshot;
      color = Colors.red;
      progress = 1.0;
      isHot = true;
    }

    return Card(
      elevation: isHot ? 4 : 1,
      shadowColor: isHot ? color.withAlpha(100) : null,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                ScaleTransition(
                  scale: isHot ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 16,
                          color: isHot ? color : null,
                        ),
                      ),
                      Text(
                        'Confiança da Rede: $score pontos',
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (score >= 100)
                  const Icon(Icons.star, color: Colors.amber, size: 24),
              ],
            ),
            const SizedBox(height: 12),
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: color.withAlpha(30),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                if (isHot)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withAlpha(0),
                            Colors.white.withAlpha(100),
                            Colors.white.withAlpha(0),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              score > 0 
                ? 'Sua fogueira esfria após 15 dias de inatividade. Continue colaborando!'
                : 'Sua reputação aumenta quando seus preços coincidem com notas fiscais oficiais.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
