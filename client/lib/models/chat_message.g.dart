// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChatMessageAdapter extends TypeAdapter<ChatMessage> {
  @override
  final int typeId = 4;

  @override
  ChatMessage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatMessage(
      id: fields[0] as String,
      sender: fields[1] as String,
      text: fields[2] as String,
      timestamp: fields[3] as DateTime,
      priceUpdate: fields[4] as PriceUpdate?,
      messageId: fields[5] as String?,
      locationId: fields[6] as String?,
      isOfficial: fields[7] as bool,
      isPromotion: fields[8] as bool,
      title: fields[9] as String?,
      description: fields[10] as String?,
      bannerUrl: fields[11] as String?,
      price: fields[12] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, ChatMessage obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.sender)
      ..writeByte(2)
      ..write(obj.text)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.priceUpdate)
      ..writeByte(5)
      ..write(obj.messageId)
      ..writeByte(6)
      ..write(obj.locationId)
      ..writeByte(7)
      ..write(obj.isOfficial)
      ..writeByte(8)
      ..write(obj.isPromotion)
      ..writeByte(9)
      ..write(obj.title)
      ..writeByte(10)
      ..write(obj.description)
      ..writeByte(11)
      ..write(obj.bannerUrl)
      ..writeByte(12)
      ..write(obj.price);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatMessage _$ChatMessageFromJson(Map<String, dynamic> json) => ChatMessage(
      id: json['id'] as String,
      sender: json['sender'] as String,
      text: json['text'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      priceUpdate: json['priceUpdate'] == null
          ? null
          : PriceUpdate.fromJson(json['priceUpdate'] as Map<String, dynamic>),
      messageId: json['messageId'] as String?,
      locationId: json['locationId'] as String?,
      isOfficial: json['isOfficial'] as bool? ?? false,
      isPromotion: json['isPromotion'] as bool? ?? false,
      title: json['title'] as String?,
      description: json['description'] as String?,
      bannerUrl: json['bannerUrl'] as String?,
      price: (json['price'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$ChatMessageToJson(ChatMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sender': instance.sender,
      'text': instance.text,
      'timestamp': instance.timestamp.toIso8601String(),
      'priceUpdate': instance.priceUpdate,
      'messageId': instance.messageId,
      'locationId': instance.locationId,
      'isOfficial': instance.isOfficial,
      'isPromotion': instance.isPromotion,
      'title': instance.title,
      'description': instance.description,
      'bannerUrl': instance.bannerUrl,
      'price': instance.price,
    };
