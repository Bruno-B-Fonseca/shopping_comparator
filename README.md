# Shopping Comparator MVP

A collaborative, decentralized shopping cart and price comparison ecosystem.

## Core Modules
- **Client (`client/`)**: Flutter Web PWA. Handles local storage (Hive), interactive maps, and the promotional feed.
- **Hub (`hub/`)**: Tiered Federation Server. Manages regional connections and bridges data to National Hubs.
- **Server (`server/`)**: Local WebSocket & Storage Proxy. Handles AI product extraction and MinIO image management.

## Key Features

### 1. Decentralized & Collaborative
- **Hierarchical Federation**: Servers connect to Regional Hubs, which can optionally link to a National Hub, creating a multi-tier data mesh.
- **Real-time Synchronization**: New sessions automatically request missing state (locations, products, prices, and promotions) from active peers via `sync_request`.
- **Offline-first Architecture**: All data is cached locally in Hive. Changes sync instantly when online.

### 2. Smart Price Collection
- **Geofenced Sharing**: Prices scanned within a registered establishment's area are shared with the community. 
- **Private Mode**: Scans performed outside registered areas are stored locally and kept private (prefixed with `private_`).
- **AI-Powered Extraction**: Automatic product metadata registration and price detection from images using Google Gemini or Ollama.

### 3. Promotional Feed (Formerly Chat)
- **Digital Flyer**: The chat is transformed into a unidirectional feed of official offers.
- **Operator-only Posting**: Only authorized operators can post promotions (signed with HMAC).
- **Rich Media**: Promotions include titles, descriptions, large banner images, and highlighted pricing.

### 4. Establishment Management
- **Interactive Map**: Operators define their market location using an integrated `flutter_map` with precise coordinate selection.
- **Geofence Visualization**: Dynamic visual feedback of the coverage perimeter directly on the map.
- **Unified Controls**: A single management card for operators to create or update their unique establishment.

## Infrastructure & Security

### Public Access (Cloudflare Tunnel)
The project uses **Cloudflare Tunnel (`cloudflared`)** for stable public access, bypassing traditional port forwarding and ngrok limits.
- **Dynamic Mode**: Generates a temporary `.trycloudflare.com` URL on startup.
- **Persistent Mode**: Use `CLOUDFLARE_TUNNEL_TOKEN` in `.env` for a fixed custom DNS.

### HMAC-SHA256 Security
Every official action (establishment registration, promotional post) is cryptographically signed.
- **Hub Level**: Validates signatures against `hub/config/secrets.json`.
- **Server Level**: Signs messages using `LOCATION_PASSWORD`.
- **Client Level**: Restricts UI management features to the matching `LOCATION_ID`.

## How to Run

### 1. Setup
1. Copy `.env.example` to `.env`.
2. (Optional) Create `hub/config/secrets.json` with authorized operators:
   ```json
   { "my-location-id": "my-secret-password" }
   ```

### 2. Deploy (Local + Hub)
```bash
docker-compose -f docker-compose-federated.yml up -d --build
```
- **App**: http://localhost:8081
- **Tunnel URL**: Run `docker compose logs tunnel` to find your public link.

## Development

### Client (Flutter)
```bash
cd client
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d chrome
```

### Hub & Server (Dart)
```bash
cd hub && dart pub get && dart run bin/hub.dart
cd server && dart pub get && dart run bin/server.dart
```
