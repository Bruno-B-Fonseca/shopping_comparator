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
    );

    _addMessage(msg);
    ref.read(webSocketServiceProvider).sendMessage(msg.toJson());
    _messageController.clear();
  }

  void _addMessage(ChatMessage msg) {
    setState(() {
      _chatHistory.add(msg);
    });
    StorageService.messages.add(msg);

    // If it's a price update, save it to the prices box too
    if (msg.priceUpdate != null) {
      StorageService.prices.put(
        '${msg.priceUpdate!.barcode}_${msg.priceUpdate!.locationId}',
        msg.priceUpdate!,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for incoming messages
    ref.listen(webSocketMessagesProvider, (previous, next) {
      next.whenData((data) {
        final msg = ChatMessage.fromJson(data);
        // Avoid duplicates if we are the sender (simple check by ID)
        if (!_chatHistory.any((m) => m.id == msg.id)) {
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
                      color: isMe ? Colors.blue[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isMe)
                          Text(
                            msg.sender,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
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
                          style: const TextStyle(
                            fontSize: 8,
                            color: Colors.grey,
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
