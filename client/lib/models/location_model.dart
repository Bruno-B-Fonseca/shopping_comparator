import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'location_model.g.dart';

@HiveType(typeId: 1)
@JsonSerializable()
class LocationModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final double latitude;

  @HiveField(3)
  final double longitude;

  @HiveField(4)
  final String? logoUrl;

  @HiveField(5)
  final double? minLat;

  @HiveField(6)
  final double? maxLat;

  @HiveField(7)
  final double? minLong;

  @HiveField(8)
  final double? maxLong;

  @HiveField(9)
  final DateTime? updatedAt;

  LocationModel({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.logoUrl,
    this.minLat,
    this.maxLat,
    this.minLong,
    this.maxLong,
    this.updatedAt,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) =>
      _$LocationModelFromJson(json);
  Map<String, dynamic> toJson() => _$LocationModelToJson(this);

  /// Checks if a given coordinate is within the establishment perimeter.
  bool contains(double lat, double long) {
    if (minLat == null ||
        maxLat == null ||
        minLong == null ||
        maxLong == null) {
      return false;
    }
    return lat >= minLat! &&
        lat <= maxLat! &&
        long >= minLong! &&
        long <= maxLong!;
  }
}
