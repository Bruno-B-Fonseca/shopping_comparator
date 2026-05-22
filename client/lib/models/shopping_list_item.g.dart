// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shopping_list_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ShoppingListItemAdapter extends TypeAdapter<ShoppingListItem> {
  @override
  final int typeId = 5;

  @override
  ShoppingListItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ShoppingListItem(
      id: fields[0] as String,
      barcode: fields[1] as String?,
      category: fields[2] as String?,
      name: fields[3] as String,
      quantity: fields[4] as double,
      isChecked: fields[5] as bool,
      createdAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ShoppingListItem obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.barcode)
      ..writeByte(2)
      ..write(obj.category)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.quantity)
      ..writeByte(5)
      ..write(obj.isChecked)
      ..writeByte(6)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShoppingListItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ShoppingListItem _$ShoppingListItemFromJson(Map<String, dynamic> json) =>
    ShoppingListItem(
      id: json['id'] as String,
      barcode: json['barcode'] as String?,
      category: json['category'] as String?,
      name: json['name'] as String,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      isChecked: json['isChecked'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$ShoppingListItemToJson(ShoppingListItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'barcode': instance.barcode,
      'category': instance.category,
      'name': instance.name,
      'quantity': instance.quantity,
      'isChecked': instance.isChecked,
      'createdAt': instance.createdAt.toIso8601String(),
    };
