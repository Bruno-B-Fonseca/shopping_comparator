// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'price_update.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PriceUpdateAdapter extends TypeAdapter<PriceUpdate> {
  @override
  final int typeId = 2;

  @override
  PriceUpdate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PriceUpdate(
      barcode: fields[0] as String,
      locationId: fields[1] as String,
      price: fields[2] as double,
      timestamp: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, PriceUpdate obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.barcode)
      ..writeByte(1)
      ..write(obj.locationId)
      ..writeByte(2)
      ..write(obj.price)
      ..writeByte(3)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PriceUpdateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PriceUpdate _$PriceUpdateFromJson(Map<String, dynamic> json) => PriceUpdate(
      barcode: json['barcode'] as String,
      locationId: json['locationId'] as String,
      price: (json['price'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );

Map<String, dynamic> _$PriceUpdateToJson(PriceUpdate instance) =>
    <String, dynamic>{
      'barcode': instance.barcode,
      'locationId': instance.locationId,
      'price': instance.price,
      'timestamp': instance.timestamp.toIso8601String(),
    };
