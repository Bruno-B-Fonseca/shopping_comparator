import 'package:hive/hive.dart';

part 'product.g.dart';

@HiveType(typeId: 0)
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
  final String? photoBase64;

  Product({
    required this.barcode,
    required this.name,
    required this.unit,
    required this.manufacturer,
    this.photoBase64,
  });
}
