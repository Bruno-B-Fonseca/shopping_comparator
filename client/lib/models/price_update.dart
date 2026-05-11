import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'price_update.g.dart';

@HiveType(typeId: 2)
@JsonSerializable()
class PriceUpdate extends HiveObject {
  @HiveField(0)
  final String barcode;

  @HiveField(1)
  final String locationId;

  @HiveField(2)
  final double price;

  @HiveField(3)
  final DateTime timestamp;

  @HiveField(4)
  final String? messageId;

  PriceUpdate({
    required this.barcode,
    required this.locationId,
    required this.price,
    required this.timestamp,
    this.messageId,
  });

  factory PriceUpdate.fromJson(Map<String, dynamic> json) =>
      _$PriceUpdateFromJson(json);
  Map<String, dynamic> toJson() => _$PriceUpdateToJson(this);
}
