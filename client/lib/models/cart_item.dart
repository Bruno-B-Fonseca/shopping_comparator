import 'package:hive/hive.dart';

part 'cart_item.g.dart';

@HiveType(typeId: 3)
class CartItem extends HiveObject {
  @HiveField(0)
  final String barcode;

  @HiveField(1)
  final double quantity;

  @HiveField(2)
  final double unitPrice;

  @HiveField(3)
  final DateTime addedAt;

  CartItem({
    required this.barcode,
    required this.quantity,
    required this.unitPrice,
    required this.addedAt,
  });

  double get total => quantity * unitPrice;
}
