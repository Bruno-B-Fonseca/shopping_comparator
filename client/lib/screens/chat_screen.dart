import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../providers/websocket_provider.dart';
import '../providers/auth_provider.dart';
import '../services/storage_service.dart';
import '../services/image_service.dart';
import '../widgets/product_image_picker.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String locationId;
  final String locationName;

  const ChatScreen({
    super.key,
    required this.locationId,
    required this.locationName,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final List<ChatMessage> _chatHistory = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    final history = StorageService.messages.values
        .where((m) => m.locationId == widget.locationId)
        .toList();
    history.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    setState(() {
      _chatHistory.clear();
      _chatHistory.addAll(history);
    });
  }

  void _addMessage(ChatMessage msg) {
    if (msg.locationId != widget.locationId) return;

    final msgId = msg.messageId ?? msg.id;
    if (_chatHistory.any((m) => (m.messageId ?? m.id) == msgId)) return;

    setState(() {
      _chatHistory.insert(0, msg);
    });
    StorageService.messages.add(msg);
  }

  void _showPromotionForm() {
    showDialog(
      context: context,
      builder: (context) => _PromotionForm(
        locationId: widget.locationId,
        onPost: (msg) {
          _addMessage(msg);
          ref.read(webSocketServiceProvider).sendAuthenticatedMessage({
            'type': 'chat_message',
            'payload': msg.toJson(),
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isOperator = auth.isOperator && auth.locationId == widget.locationId;

    ref.listen(webSocketMessagesProvider, (previous, next) {
      next.whenData((data) {
        if (data['type'] == 'chat_message' || data['type'] == 'relay') {
          final payload = data['type'] == 'relay'
              ? data['payload']['payload']
              : data['payload'];
          if (payload != null) {
            _addMessage(ChatMessage.fromJson(payload));
          }
        }
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.locationName),
        actions: [
          if (isOperator)
            IconButton(
              icon: const Icon(Icons.add_business),
              tooltip: 'Nova Promoção',
              onPressed: _showPromotionForm,
            ),
        ],
      ),
      body: _chatHistory.isEmpty
          ? const Center(
              child: Text('Nenhuma oferta postada ainda.'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _chatHistory.length,
              itemBuilder: (context, index) {
                final msg = _chatHistory[index];
                return _PromotionCard(message: msg);
              },
            ),
    );
  }
}

class _PromotionCard extends StatelessWidget {
  final ChatMessage message;

  const _PromotionCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (message.bannerUrl != null)
            Image.network(
              ImageService.sanitizeUrl(message.bannerUrl!),
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 200,
                color: colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.broken_image, size: 64),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        message.title ?? 'Promoção',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    if (message.isOfficial)
                      const Icon(Icons.verified, color: Colors.blue, size: 20),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  message.description ?? message.text,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (message.price != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'R\$ ${message.price!.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      Text(
                        'Postado em: ${_formatDate(message.timestamp)}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _PromotionForm extends StatefulWidget {
  final String locationId;
  final Function(ChatMessage) onPost;

  const _PromotionForm({required this.locationId, required this.onPost});

  @override
  State<_PromotionForm> createState() => _PromotionFormState();
}

class _PromotionFormState extends State<_PromotionForm> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  String? _bannerUrl;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova Promoção'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Descrição'),
              maxLines: 3,
            ),
            TextField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Preço (Opcional)',
                prefixText: 'R\$ ',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Banner: '),
                ProductImagePicker(
                  onImageUploaded: (url) => setState(() => _bannerUrl = url),
                ),
                if (_bannerUrl != null)
                  const Icon(Icons.check_circle, color: Colors.green),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_titleController.text.isEmpty) return;

            final msg = ChatMessage(
              id: const Uuid().v4(),
              sender: 'Operador',
              text: _descController.text,
              timestamp: DateTime.now(),
              messageId: const Uuid().v4(),
              locationId: widget.locationId,
              isOfficial: true,
              isPromotion: true,
              title: _titleController.text,
              description: _descController.text,
              bannerUrl: _bannerUrl,
              price: double.tryParse(_priceController.text),
            );

            widget.onPost(msg);
            Navigator.pop(context);
          },
          child: const Text('Postar'),
        ),
      ],
    );
  }
}
