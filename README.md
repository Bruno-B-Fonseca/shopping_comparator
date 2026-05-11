# Shopping Comparator MVP

Collaborative shopping cart and price comparison web application.

## Features
- **Offline-first:** Local storage via Hive.
- **Collaborative:** Real-time price updates and chat via WebSockets.
- **Map View:** Visualization of local prices on OpenStreetMap.
- **PWA:** Can be installed on mobile and desktop.
- **Federated Network:** Connect to a federated network of WebSocket servers using a central Hub for distributed data synchronization.
- **MinIO Image Storage:** Scalable and performant image storage integrated for product images, replacing Base64 encoding.

## Tech Stack
- **Frontend:** Flutter Web + Riverpod + Hive.
- **Backend:** Dart + Shelf (WebSocket Server).
- **Infrastructure:** Docker Compose + Nginx + ngrok + MinIO.

## How to Run

### 1. Requirements
- Docker and Docker Compose.
- [ngrok](https://ngrok.com/) authtoken (for public access).

### 2. Setup
1. Copy `.env.example` to `.env`.
2. Edit `.env` and add your `NGROK_AUTHTOKEN`.

### 3. Deploy
```bash
docker-compose up -d --build
```

- **App:** http://localhost:8081
- **WebSocket:** ws://localhost:3000
- **ngrok status:** http://localhost:4040

## Development

### Client (Flutter)
```bash
cd client
flutter pub get
dart run build_runner build
flutter run -d chrome
```

### Server (Dart)
```bash
cd server
dart pub get
dart run bin/server.dart
```

## Federated Network (Beta)
The Shopping Comparator can now connect to a federated network of WebSocket servers using a central Hub.

### Network Architecture
- **Hub**: Acts as a central meeting point and message relay for different regions. It **must** have a stable, fixed public URL (e.g., using Cloudflare Tunnel or a dedicated VPS).
- **Local Servers**: Residential or local instances that connect to the Hub. These can use dynamic URLs (like ngrok) because they initiate the connection to the Hub.
- **Regions**: Data is synchronized primarily within the same region. Servers in different regions can subscribe to each other's topics via the Hub.

### Enabling Federation
Update your `docker-compose.yml` or local environment variables:

- `HUB_URL=ws://hub-url:3001`
- `REGION=your-region`
- `PUBLIC_WS_URL=ws://your-public-url:3000`

### Running with Federation
You can use `docker-compose-federated.yml` for a test setup:
```bash
docker-compose -f docker-compose-federated.yml up -d --build
```
