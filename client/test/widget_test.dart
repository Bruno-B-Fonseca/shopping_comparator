// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:client/models/product.dart';
import 'package:client/models/location_model.dart';
import 'package:client/models/price_update.dart';
import 'package:client/models/cart_item.dart';
import 'package:client/models/chat_message.dart';
import 'package:client/main.dart';
import 'package:client/providers/websocket_provider.dart';
import 'package:client/services/websocket_service.dart';

// Mock WebSocketService that doesn't do anything
class MockWebSocketService extends WebSocketService {
  @override
  void connect(String url) {}
  @override
  void sendMessage(Map<String, dynamic> message) {}
  @override
  void dispose() {}
}

void main() {
  setUpAll(() async {
    // Initialize Hive for tests
    final tempDir = Directory.systemTemp.createTempSync();
    Hive.init(tempDir.path);
    
    // Register Adapters manually for test
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
  });

  testWidgets('App starts and displays home screen', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame, overriding the websocket provider
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          webSocketServiceProvider.overrideWithValue(MockWebSocketService()),
        ],
        child: const ShoppingComparatorApp(),
      ),
    );

    // Verify that the app starts without crashing
    expect(find.byType(ShoppingComparatorApp), findsOneWidget);
  });
}
