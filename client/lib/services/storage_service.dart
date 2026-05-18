import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/product.dart';
import '../models/location_model.dart';
import '../models/price_update.dart';
import '../models/cart_item.dart';
import '../models/chat_message.dart';

class StorageService {
  static Future<void> init() async {
    await Hive.initFlutter();

    // Register Adapters
    Hive.registerAdapter(ProductAdapter());
    Hive.registerAdapter(LocationModelAdapter());
    Hive.registerAdapter(PriceUpdateAdapter());
    Hive.registerAdapter(CartItemAdapter());
    Hive.registerAdapter(ChatMessageAdapter());

    // Open Boxes with fail-safe logic
    await _openBoxSafe<Product>('products');
    await _openBoxSafe<LocationModel>('locations');
    await _openBoxSafe<PriceUpdate>('prices');
    await _openBoxSafe<CartItem>('cart');
    await _openBoxSafe<ChatMessage>('messages');
  }

  static Future<void> _openBoxSafe<T>(String name) async {
    try {
      await Hive.openBox<T>(name);
    } catch (e) {
      // Se falhar ao abrir (provavelmente erro de versão/schema), limpa a box e tenta de novo
      debugPrint('StorageService: Erro ao abrir box "$name". Resetando dados... Error: $e');
      await Hive.deleteBoxFromDisk(name);
      await Hive.openBox<T>(name);
    }
  }

  // Getters for boxes
  static Box<Product> get products => Hive.box<Product>('products');
  static Box<LocationModel> get locations =>
      Hive.box<LocationModel>('locations');
  static Box<PriceUpdate> get prices => Hive.box<PriceUpdate>('prices');
  static Box<CartItem> get cart => Hive.box<CartItem>('cart');
  static Box<ChatMessage> get messages => Hive.box<ChatMessage>('messages');
}
