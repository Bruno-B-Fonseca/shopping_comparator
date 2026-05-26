// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProductAdapter extends TypeAdapter<Product> {
  @override
  final int typeId = 0;

  @override
  Product read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Product(
      barcode: fields[0] as String,
      name: fields[1] as String,
      unit: fields[2] as String,
      manufacturer: fields[3] as String,
      photoUrl: fields[4] as String?,
      nutritionalInfo: fields[5] as String?,
      isVerified: fields[6] as bool,
      canonicalCategory: fields[7] as String?,
      updatedAt: fields[8] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Product obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.barcode)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.unit)
      ..writeByte(3)
      ..write(obj.manufacturer)
      ..writeByte(4)
      ..write(obj.photoUrl)
      ..writeByte(5)
      ..write(obj.nutritionalInfo)
      ..writeByte(6)
      ..write(obj.isVerified)
      ..writeByte(7)
      ..write(obj.canonicalCategory)
      ..writeByte(8)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Product _$ProductFromJson(Map<String, dynamic> json) => Product(
      barcode: json['barcode'] as String,
      name: json['name'] as String,
      unit: json['unit'] as String,
      manufacturer: json['manufacturer'] as String,
      photoUrl: json['photoUrl'] as String?,
      nutritionalInfo: json['nutritionalInfo'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
      canonicalCategory: json['canonicalCategory'] as String?,
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$ProductToJson(Product instance) => <String, dynamic>{
      'barcode': instance.barcode,
      'name': instance.name,
      'unit': instance.unit,
      'manufacturer': instance.manufacturer,
      'photoUrl': instance.photoUrl,
      'nutritionalInfo': instance.nutritionalInfo,
      'isVerified': instance.isVerified,
      'canonicalCategory': instance.canonicalCategory,
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
