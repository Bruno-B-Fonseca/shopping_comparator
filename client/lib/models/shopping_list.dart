import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'shopping_list_item.dart';

part 'shopping_list.g.dart';

@HiveType(typeId: 6)
@JsonSerializable()
class ShoppingList extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final List<ShoppingListItem> items;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final DateTime updatedAt;

  @HiveField(5)
  final String? color; // Cor para identificação na UI (hex)

  ShoppingList({
    required this.id,
    required this.name,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
    this.color,
  });

  factory ShoppingList.fromJson(Map<String, dynamic> json) =>
      _$ShoppingListFromJson(json);
  Map<String, dynamic> toJson() => _$ShoppingListToJson(this);

  ShoppingList copyWith({
    String? id,
    String? name,
    List<ShoppingListItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? color,
  }) {
    return ShoppingList(
      id: id ?? this.id,
      name: name ?? this.name,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      color: color ?? this.color,
    );
  }
}
