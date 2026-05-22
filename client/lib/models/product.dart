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

  @HiveField(4)
  final String? photoUrl;

  @HiveField(5)
  final String? nutritionalInfo;

  @HiveField(6)
  final bool isVerified;

  @HiveField(7)
  final String? canonicalCategory;

  Product({
    required this.barcode,
    required this.name,
    required this.unit,
    required this.manufacturer,
    this.photoUrl,
    this.nutritionalInfo,
    this.isVerified = false,
    this.canonicalCategory,
  });

  /// Verifica se o produto é local (artesanal/balança)
  bool get isLocal => barcode.startsWith('local:') || barcode.startsWith('2');

  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);
  Map<String, dynamic> toJson() => _$ProductToJson(this);
}
