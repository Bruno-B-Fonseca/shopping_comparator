import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'price_update.dart';

part 'chat_message.g.dart';

@HiveType(typeId: 4)
@JsonSerializable()
class ChatMessage extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String sender;

  @HiveField(2)
  final String text;

  @HiveField(3)
  final DateTime timestamp;

  @HiveField(4)
  final PriceUpdate? priceUpdate;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.priceUpdate,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);
  Map<String, dynamic> toJson() => _$ChatMessageToJson(this);
}
