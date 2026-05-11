import 'package:client/models/price_update.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../providers/websocket_provider.dart';
import '../services/storage_service.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final List<ChatMessage> _chatHistory = [];

  @override
  void initState() {
    super.initState();
    // Load local history
    _chatHistory.addAll(StorageService.messages.values.toList());
    _chatHistory.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final msg = ChatMessage(
      id: const Uuid().v4(),
      sender: 'User', // Local user name
      text: text,
      timestamp: DateTime.now(),
      messageId: const Uuid().v4(),
    );

    _addMessage(msg);
    
    // Envia no formato estruturado para o SyncService dos outros clientes
    ref.read(webSocketServiceProvider).sendMessage({
      'type': 'chat_message',
      'payload': msg.toJson(),
    });
    
    _messageController.clear();
  }

  void _addMessage(ChatMessage msg) {
    // Evita duplicatas se já estiver no histórico
    final msgId = msg.messageId ?? msg.id;
    if (_chatHistory.any((m) => (m.messageId ?? m.id) == msgId)) {
      return;
    }

    setState(() {
      _chatHistory.add(msg);
    });
    StorageService.messages.add(msg);

    // Se for um update de preço, salva também no box de preços
    if (msg.priceUpdate != null) {
      final priceUpdate = msg.priceUpdate!;
      // Garante que o PriceUpdate tenha o mesmo messageId da mensagem de chat
      final priceWithId = PriceUpdate(
        barcode: priceUpdate.barcode,
        locationId: priceUpdate.locationId,
        price: priceUpdate.price,
        timestamp: priceUpdate.timestamp,
        messageId: msg.messageId ?? msg.id,
      );

      StorageService.prices.put(
        '${priceWithId.barcode}_${priceWithId.locationId}',
        priceWithId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for incoming messages
    ref.listen(webSocketMessagesProvider, (previous, next) {
      next.whenData((data) {
        final String? type = data['type'];
        
        if (type == 'chat_message') {
          // Novo formato estruturado
          final msg = ChatMessage.fromJson(data['payload']);
          _addMessage(msg);
        } else if (type == null && data.containsKey('sender')) {
          // Compatibilidade com formato antigo
          final msg = ChatMessage.fromJson(data);
          _addMessage(msg);
        }
      });
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Group Chat')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _chatHistory.length,
              itemBuilder: (context, index) {
                final msg = _chatHistory[_chatHistory.length - 1 - index];
                final isMe = msg.sender == 'User';

                return Align(
                  alignment: isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isMe)
                          Text(
                            msg.sender,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        Text(msg.text),
                        if (msg.priceUpdate != null) ...[
                          const Divider(),
                          const Text(
                            'PRICE UPDATE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'R\$ ${msg.priceUpdate!.price.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                        Text(
                          '${msg.timestamp.hour}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
