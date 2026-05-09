# Shopping Comparator MVP — Agent Guide

**Purpose:** Collaborative shopping cart and price comparison PWA with real-time WebSocket sync and offline-first local storage.

**Tech Stack:** Flutter Web (Riverpod + Hive) + Dart WebSocket Server + Docker Compose + Nginx

---

## Quick Start (Development)

```bash
# Client (Flutter Web) — runs on http://localhost:port
cd client
flutter pub get
dart run build_runner build         # Code generation: models, adapters
flutter run -d chrome

# Server (WebSocket) — runs on ws://localhost:3000
cd server
dart pub get
dart run bin/server.dart

# Production (Docker)
docker-compose up -d --build        # Full stack at http://localhost:8080
# Set .env: NGROK_AUTHTOKEN (optional: CLOUDFLARE_TUNNEL_TOKEN)
```

---

## Architecture

```
client/                             # Flutter Web (PWA)
├── lib/
│   ├── main.dart                  # Hive init, Riverpod setup
│   ├── models/                    # Hive + JSON serializable
│   │   ├── product.dart (typeId: 0)
│   │   ├── location_model.dart (typeId: 1)
│   │   ├── price_update.dart (typeId: 2)
│   │   ├── cart_item.dart (typeId: 3)
│   │   └── chat_message.dart (typeId: 4)
│   ├── providers/                 # Riverpod state (singleton & StateNotifier)
│   │   ├── websocket_provider.dart
│   │   └── cart_provider.dart
│   ├── screens/                   # IndexedStack navigation (Scan, Cart, Compare, Chat)
│   ├── services/                  # Singletons (Storage, WebSocket, Location)
│   └── widgets/
│
server/                             # Dart WebSocket server
├── bin/server.dart                # Port-aware broadcaster
├── lib/server.dart                # Utilities
└── test/

docker-compose.yml                 # websocket + web-server + ngrok services
web-server/                        # Nginx + Flutter build
```

---

## Essential Conventions

### Hive Persistence
- **5 boxes:** `products`, `locations`, `prices`, `cart`, `messages`
- **TypeIds:** Sequential 0–4 (see models/ above). New models get next ID.
- **Pattern:** `@HiveType(typeId: N)` + field annotations + `build_runner build`
- **Access:** Use `StorageService.{box}` only—no direct Hive calls outside services.

### Riverpod Patterns
- **Singletons:** `Provider<T>` wrapping services (WebSocketService, StorageService)
- **State Lists:** `StateNotifierProvider<Notifier, List<T>>` (CartNotifier)
- **Real-Time:** `StreamProvider<T>` for WebSocket message streams
- **Usage:** `ConsumerStatefulWidget` / `ConsumerWidget` for screen access via `ref`

### Naming Conventions
- **Files:** `snake_case.dart`
- **Classes:** `PascalCase`
- **Methods:** `camelCase` (private: `_underscore`)
- **Providers:** `camelCaseProvider` suffix
- **Hive models:** Add `part 'file.g.dart';` + `build_runner build`

### Code Generation
After editing any model (Product, CartItem, etc.):
```bash
cd client
dart run build_runner build        # Regenerates .g.dart adapters
```

---

## Screens & Navigation

**HomeScreen** uses `IndexedStack` (4 tabs, state-preserving):
1. **ScanScreen** — Barcode input, product lookup, add to cart
2. **CartScreen** — View/edit items, price comparisons
3. **CompareScreen** — Price trends, location-based pricing
4. **ChatScreen** — Real-time messages via WebSocket

---

## WebSocket & Real-Time Sync

**Flow:**
1. User action in client (e.g., add item) → `cartProvider.notifier.addItem()`
2. Update local storage (`StorageService.cart.add()`)
3. Broadcast message via `WebSocketService.sendMessage()`
4. Server rebroadcasts to all clients
5. `webSocketMessagesProvider` stream updates listeners

**Server:** `bin/server.dart` reads `PORT` env (default 3000), tracks connections, broadcasts to all except sender.

**Auto-Reconnect:** WebSocketService polls every 5 seconds if disconnected.

---

## Common Development Tasks

| Task | Command |
|------|---------|
| Add new model | Create in `client/lib/models/`, add typeId, run `build_runner build` |
| Add state | Create `StateNotifierProvider` in `providers/` |
| Add screen | Create in `screens/`, add route in `HomeScreen.IndexedStack` |
| Add service | Create in `services/`, wrap with `Provider<T>` in a provider file |
| Lint | `dart analyze` or `flutter analyze` (both use `lints/recommended.yaml`) |
| Deploy | `docker-compose up -d --build` + `.env` with NGROK_AUTHTOKEN |

---

## Key Files & Entry Points

- **Client bootstrap:** `lib/main.dart` → StorageService.init → Riverpod → HomeScreen
- **Server bootstrap:** `bin/server.dart` → WebSocket listener on PORT
- **Web assets:** `web/` → hosted via Nginx at /
- **Nginx config:** `web-server/default.conf` (SPA routing)
- **Build config:** `pubspec.yaml` (both projects) + `docker-compose.yml`

---

## Tips for Immediate Productivity

1. **Models change often?** Always run `build_runner build` after editing models.
2. **Add item to cart?** Use `ref.read(cartProvider.notifier).addItem(item)` in ConsumerWidget.
3. **Listen to messages?** Use `webSocketMessagesProvider` as a StreamProvider dependency.
4. **New local box?** Add to StorageService, assign typeId to model, create provider if needed.
5. **Debugging WebSocket?** Check server logs (`dart run bin/server.dart`) and client console.
6. **Offline support?** Hive persists all boxes locally; sync happens when WebSocket connects.

---

## External Docs

- [Flutter docs](https://docs.flutter.dev/)
- [Riverpod docs](https://riverpod.dev/)
- [Hive docs](https://docs.hivedb.dev/)
- [Shelf docs](https://pub.dev/packages/shelf)
