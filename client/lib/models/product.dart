import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'product.g.dart';

@HiveType(typeId: 0)
@JsonSerializable()
class Product extends HiveObject {
  @HiveField(0)
  final String barcode;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String unit;

  @HiveField(3)
  final String manufacturer;

  Product({
    required this.barcode,
    required this.name,
    required this.unit,
    required this.manufacturer,
  });

  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);
  Map<String, dynamic> toJson() => _$ProductToJson(this);
}
