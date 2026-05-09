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

    // Open Boxes
    await Hive.openBox<Product>('products');
    await Hive.openBox<LocationModel>('locations');
    await Hive.openBox<PriceUpdate>('prices');
    await Hive.openBox<CartItem>('cart');
    await Hive.openBox<ChatMessage>('messages');
  }

  // Getters for boxes
  static Box<Product> get products => Hive.box<Product>('products');
  static Box<LocationModel> get locations =>
      Hive.box<LocationModel>('locations');
  static Box<PriceUpdate> get prices => Hive.box<PriceUpdate>('prices');
  static Box<CartItem> get cart => Hive.box<CartItem>('cart');
  static Box<ChatMessage> get messages => Hive.box<ChatMessage>('messages');
}
