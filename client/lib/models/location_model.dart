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
  final String? photoBase64;

  LocationModel({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.photoBase64,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) =>
      _$LocationModelFromJson(json);
  Map<String, dynamic> toJson() => _$LocationModelToJson(this);
}
