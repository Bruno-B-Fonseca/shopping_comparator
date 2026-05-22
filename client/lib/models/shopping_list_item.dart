import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'shopping_list_item.g.dart';

@HiveType(typeId: 5)
@JsonSerializable()
class ShoppingListItem extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String? barcode;

  @HiveField(2)
  final String? category; // Para itens genéricos (ex: "PADARIA > PAO")

  @HiveField(3)
  final String name;

  @HiveField(4)
  final double quantity;

  @HiveField(5)
  final bool isChecked;

  @HiveField(6)
  final DateTime createdAt;

  ShoppingListItem({
    required this.id,
    this.barcode,
    this.category,
    required this.name,
    this.quantity = 1.0,
    this.isChecked = false,
    required this.createdAt,
  });

  factory ShoppingListItem.fromJson(Map<String, dynamic> json) =>
      _$ShoppingListItemFromJson(json);
  Map<String, dynamic> toJson() => _$ShoppingListItemToJson(this);

  ShoppingListItem copyWith({
    String? id,
    String? barcode,
    String? category,
    String? name,
    double? quantity,
    bool? isChecked,
    DateTime? createdAt,
  }) {
    return ShoppingListItem(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      isChecked: isChecked ?? this.isChecked,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
