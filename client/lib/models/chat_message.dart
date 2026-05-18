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

  @HiveField(5)
  final String? messageId;

  @HiveField(6)
  final String? locationId;

  @HiveField(7)
  final bool isOfficial;

  @HiveField(8)
  final bool isPromotion;

  @HiveField(9)
  final String? title;

  @HiveField(10)
  final String? description;

  @HiveField(11)
  final String? bannerUrl;

  @HiveField(12)
  final double? price;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.priceUpdate,
    this.messageId,
    this.locationId,
    this.isOfficial = false,
    this.isPromotion = false,
    this.title,
    this.description,
    this.bannerUrl,
    this.price,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);
  Map<String, dynamic> toJson() => _$ChatMessageToJson(this);
}
