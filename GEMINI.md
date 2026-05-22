# Shopping Comparator

A collaborative shopping cart and price comparison web application (MVP). This project is built using a Dart-centric stack, with a Flutter Web frontend and a Dart Shelf-based backend.

## Project Overview

- **Objective**: Build a collaborative price comparison and shopping cart application with an offline-first architecture, real-time sync via WebSockets, and easy deployment via Docker.
- **Frontend (`client/`)**: Flutter Web application.
  - **State Management**: Riverpod (`flutter_riverpod`).
  - **Persistence**: Offline-first using Hive (`hive_flutter`).
  - **Maps**: Visualization using OpenStreetMap via `flutter_map`.
  - **Models**: JSON serialization and Hive adapters are generated using `build_runner`.
- **Backend (`server/`)**: Dart command-line application.
  - **Framework**: `shelf` for HTTP and `shelf_web_socket` for real-time communication.
  - **Functionality**: Simple message broadcasting to all connected clients.
- **Infrastructure**:
  - **Containerization**: Docker Compose manages the frontend (Nginx), backend (Dart), and ngrok for public tunneling.
  - **Proxy**: Nginx (`web-server/`) serves the Flutter Web build and proxies WebSocket requests.

## Tech Stack Summary

| Layer | Technology |
| :--- | :--- |
| **Frontend** | Flutter (Web), Riverpod, Hive, Flutter Map |
| **Backend** | Dart, Shelf, WebSockets |
| **Infrastructure** | Docker, Nginx, ngrok |

## Core Components

### Data Models (Hive)

- `Product`: Barcode, name, unit, manufacturer, photo.
- `Location`: Coordinates (Lat/Long).
- `PriceUpdate`: Product link, price, location, timestamp.
- `CartItem`: Product link, quantity, checked status.
- `ChatMessage`: User, text, timestamp, optional price update payload.

### Services

- `StorageService`: Manages Hive boxes and persistence.
- `WebSocketService`: Handles connection, reconnection, and message routing.
- `LocationService`: Fetches current coordinates for map positioning and distance calculation.

## Implementation Roadmap

### Phase 1: Environment & Backend

- Initialize workspace and directory structure.
- WebSocket server implementation (message broadcasting).
- Dockerization of the backend.

### Phase 2: Frontend Foundation (Offline-First)

- Initialize Flutter Web project.
- Implement Hive adapters for all data models.
- Set up core services (Storage, WebSocket, Location).

### Phase 3: Core Features

- Scanning & Product registration (offline-first).
- Shopping Cart management.
- Map & Comparison mode (markers for price updates).
- Collaborative Chat with price sharing.

### Phase 4: Infrastructure & Deployment

- Nginx setup to serve the web build.
- Full orchestration with Docker Compose.
- ngrok integration for public access.

## Getting Started

### Prerequisites

- Docker and Docker Compose
- Flutter SDK (for local development)
- Dart SDK

### Setup

1. Clone the repository.
2. Copy `.env.example` to `.env` and configure your `NGROK_AUTHTOKEN`.
3. Install dependencies:

    ```bash
    # Client
    cd client && flutter pub get
    # Server
    cd server && dart pub get
    # Hub
    cd hub && dart pub get
    ```

### Running with Docker

```bash
docker-compose up -d --build
```

- **App**: <http://localhost:8081>
- **WebSocket**: ws://localhost:3000
- **ngrok status**: <http://localhost:4040>

## Development Guide

### Client Development

- **Code Generation**: This project uses `build_runner` for Hive adapters and JSON serialization. Run this whenever you modify models:

  ```bash
  cd client
  dart run build_runner build --delete-conflicting-outputs
  ```

- **Running locally**:

  ```bash
  cd client
  flutter run -d chrome
  ```

### Server Development

- **Running locally**:

  ```bash
  cd server
  dart run bin/server.dart
  ```

### Federative Development

- **Running locally**:

  ```bash
  cd hub
  dart run bin/server.dart

```

## Project Structure

```text
/
├── client/           # Flutter Web application
│   ├── lib/
│   │   ├── models/   # Hive & JSON Models
│   │   ├── providers/# Riverpod Providers
│   │   ├── screens/  # UI Screens
│   │   ├── services/ # Logic (Storage, WebSockets, Location)
│   │   └── widgets/  # Reusable Widgets
├── hub/              # Dart Federative Server
├── server/           # Dart WebSocket Server
├── web-server/       # Nginx configuration for production/Docker
└── docker-compose.yml# Main orchestration file
```

## Design Decisions

### Federated Network Implementation

To enable a federated network for WebSocket servers, the following components were implemented:

- **Hub (Registry & Relay)**: A central service (`hub/`) responsible for managing server registrations, topic subscriptions, and relaying messages between servers. It uses `shelf` and `shelf_web_socket`.
- **ClusterService**: Implemented in the server (`server/lib/cluster_service.dart`) to connect to the Hub, register the server, handle incoming relayed messages, and publish local messages to the Hub.
- **Environment Variables**: Support for `HUB_URL`, `REGION`, and `PUBLIC_WS_URL` was added to configure federation.
- **Docker Integration**: The Hub service was added to `docker-compose.yml`.

### MinIO Image Storage Integration

To improve image handling, scalability, and performance, MinIO was integrated as the primary image storage service:

- **Objective**: Replace Base64 storage in Hive with external URLs, reducing data bloat and improving synchronization.
- **Backend Changes**: Added MinIO dependency, created interaction service, and implemented an upload route (`POST /products/upload-photo`). The API now provides image URLs.
- **Frontend Changes**: Refactored `Product` model to use `photoUrl` instead of `photoBase64`, implemented `ImageService`, and updated UI to display images via `Image.network`.
- **Infrastructure**: MinIO service added to `docker-compose.yml` with persistent volume mapping.

### Image Proxy & Map Caching

To ensure a seamless and robust user experience on the web, several architectural enhancements were made:

- **Image Proxy**: A backend proxy (`/proxy`) was implemented to fetch external images (like those from Open Food Facts). This bypasses browser CORS restrictions and avoids "Mixed Content" errors by serving all external assets over the app's secure connection.
- **Map Tile Caching**: To support offline usage and reduce API calls to OpenStreetMap, a `HiveTileProvider` was implemented. It caches map tiles in a local Hive box (`map_tiles`), enabling the map to function even without connectivity for cached regions.
- **Onboarding & Privacy**: Replaced the startup consent dialog with a full-screen `OnboardingScreen`. This ensures that all required LGPD consents (Privacy, Location, AI) are gathered before any sensitive services (like WebSocket or Location) are initialized, improving both security and application stability.

### Global Product Index (GPI) & Normalization

To ensure data integrity across the federated network, a Global Product Index was implemented:
- **Hub-side Validation**: The Hub now provides a `GpiService` that uses AI (Ollama/Gemini) to normalize product metadata (names, categories).
- **Canonical Categories**: Introduced a hierarchical category system to allow comparison of products across different establishments even without identical EANs (e.g., local bakery items).
- **Verification Badges**: Products and prices validated by the Hub or establishment operators receive "Verified" and "Official" badges in the UI.

### Bulk Price Update via NFC-e

To enable rapid and reliable data population, establishment operators can now update prices in batch:
- **Invoice Parsing**: A backend `InvoiceService` extracts product/price data from SEFAZ QR codes ephemerally.
- **Privacy First**: All PII (CPF, transaction IDs) is discarded in memory before any data is persisted or federated.
- **HMAC Security**: Bulk updates are signed with HMAC-SHA256 using the establishment's private password to prevent unauthorized price injections.

## Coding Conventions

- **Immutability**: Use `@JsonSerializable` and `Hive` for models. Prefer final fields.
- **State Management**: Use Riverpod providers to decouple logic from UI.
- **Service Layer**: Wrap external APIs (Hive, WebSockets, Geolocator) in service classes.
- **Styling**: Uses Material 3 with Google Fonts (Roboto).
- **Formatting**: Always run `dart format .` before committing changes.
