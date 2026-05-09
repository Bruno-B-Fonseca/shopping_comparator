# Shopping Comparator MVP - Implementation Plan

## Objective
Build a collaborative price comparison and shopping cart application with an offline-first architecture, real-time sync via WebSockets, and easy deployment via Docker.

## Key Files & Context
- **Root:** `shopping_comparator/`
- **Frontend:** `client/` (Flutter Web)
- **Backend:** `server/` (Dart WebSocket Server)
- **Infrastructure:** `docker-compose.yml`, `web-server/` (Nginx), `tunnel/` (ngrok)

## Implementation Steps

### Phase 1: Environment & Backend
1. **Initialize Workspace:** Create directory structure.
2. **WebSocket Server:**
   - Create `server/` Dart project.
   - Implement `shelf` based WebSocket server to broadcast messages (`price_update` and `chat_message`).
   - Create `server/Dockerfile`.

### Phase 2: Frontend Foundation (Offline-First)
3. **Initialize Client:**
   - Create Flutter Web project in `client/`.
   - Add dependencies: `riverpod`, `hive`, `flutter_map`, `web_socket_channel`, `geolocator`.
4. **Data Models:**
   - Implement Hive adapters for `Product`, `Location`, `PriceUpdate`, `CartItem`, and `ChatMessage`.
5. **Core Services:**
   - `StorageService`: Manage Hive boxes.
   - `WebSocketService`: Handle connection, reconnection, and message routing.
   - `LocationService`: Fetch current coordinates for map positioning and distance calculation.

### Phase 3: Core Features
6. **Scanning & Products:**
   - Manual barcode input screen.
   - Quick product registration (Offline-first).
7. **Shopping Cart:**
   - Add/Remove items.
   - Persistent state in Hive.
8. **Map & Comparison (The "Compare" Mode):**
   - Integrated `flutter_map` with OpenStreetMap.
   - Display nearby price updates as markers.
   - Real-time updates from WebSocket.
9. **Collaborative Chat:**
   - Group chat interface.
   - Structured price sharing (automatically updates the map).

### Phase 4: Infrastructure & Deployment
10. **Web Server:**
    - Nginx configuration to serve Flutter Web build.
    - `web-server/Dockerfile`.
11. **Orchestration:**
    - `docker-compose.yml` with `websocket`, `web`, and `ngrok` services.
    - Configure ngrok to expose the WebSocket port.

## Verification & Testing
- **Unit Tests:** Test Hive adapters and business logic (Cart, Price calculation).
- **Integration Tests:** Test WebSocket broadcast reliability.
- **Manual Verification:**
  - Verify offline functionality (add item to cart without network).
  - Verify real-time sync (two browser windows syncing chat/prices).
  - Verify map rendering and location markers.
