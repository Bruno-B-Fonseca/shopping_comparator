import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/product.dart';
import '../models/location_model.dart';
import '../models/price_update.dart';
import '../models/cart_item.dart';
import '../models/chat_message.dart';
import 'encryption_service.dart';

class StorageService {
  static Future<void> init() async {
    await Hive.initFlutter();

    // Obter ou criar chave de criptografia
    final encryptionKey = await EncryptionService.getOrCreateEncryptionKey();

    // Register Adapters
    Hive.registerAdapter(ProductAdapter());
    Hive.registerAdapter(LocationModelAdapter());
    Hive.registerAdapter(PriceUpdateAdapter());
    Hive.registerAdapter(CartItemAdapter());
    Hive.registerAdapter(ChatMessageAdapter());

    // Open Boxes com criptografia
    await _openBoxSafe<Product>('products', encryptionKey);
    await _openBoxSafe<LocationModel>('locations', encryptionKey);
    await _openBoxSafe<PriceUpdate>('prices', encryptionKey);
    await _openBoxSafe<CartItem>('cart', encryptionKey);
    await _openBoxSafe<ChatMessage>('messages', encryptionKey);
  }

  static Future<void> _openBoxSafe<T>(String name, List<int> encryptionKey) async {
    try {
      await Hive.openBox<T>(
        name,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );
    } catch (e) {
      debugPrint('StorageService: Erro ao abrir box "$name". Resetando dados... Error: $e');
      await Hive.deleteBoxFromDisk(name);
      await Hive.openBox<T>(
        name,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );
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
