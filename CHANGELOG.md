# Changelog

## [1.4.0] - 2026-05-20

### Added
- **Professional Onboarding Flow**: Implemented a comprehensive `OnboardingScreen` for first-time users, ensuring LGPD compliance through explicit consent for Privacy, Location, and AI Processing.
- **Shopping Cart Budget & Balance**: Users can now set a budget for their shopping cart, with real-time tracking of the total and remaining balance.
- **Offline Map Tile Cache**: Implemented `HiveTileProvider` to store OpenStreetMap tiles in a local Hive box, improving performance and allowing map visualization without an active internet connection for previously visited areas.
- **Image Proxy Service**: Added a `/proxy` endpoint in the backend to handle requests for external images (Open Food Facts, etc.), resolving CORS and Mixed Content issues in the Flutter Web environment.
- **Quantity Management**: Added increment/decrement controls for products in the shopping cart.
- **Operator Product Editing**: Authorized operators can now edit product metadata directly from the `ScanScreen`.

### Fixed
- **Startup Stability**: Fixed "Null check operator" crashes by hardening `LocationService` and `SyncService` and delaying WebSocket initialization until privacy consent is granted.
- **Web CORS/Security**: Resolved browser blocks when loading external assets by routing them through the internal proxy.
- **WebSocket Robustness**: Enhanced reconnection logic and message decoding safety.

## [1.3.0] - 2026-05-18

### Added
- **LGPD Compliance**: Implemented comprehensive data privacy features.
  - Mandatory privacy policy acknowledgment on startup.
  - Dedicated **Privacy Policy** screen accessible in-app.
  - Granular consent management for **Location Sharing** and **AI Image Processing**.
  - **AES-256 Encryption** for all local storage (Hive boxes) ensuring data security in rest.
  - Data management tools: "Apagar histórico local" and "Resetar consentimentos".
- **Hierarchical Federation**: Refined the federated network with secure authentication.
  - **HMAC-SHA256 signatures** for official messages between Cluster and Hub.
  - Support for cross-hub synchronization (upstream relay).
- **Technical Improvements**:
  - Enhanced Tesseract OCR processing with isolated temporary directories.
  - Improved logging for Hub and Cluster service debugging.
  - Flexible WebSocket messaging allowing unofficial chat content.

### Fixed
- Fixed Hub Dockerfile to properly include configuration secrets.
- Updated public tunnel URLs for development environments.
- Corrected race conditions in Tesseract temporary file cleanup.

## [1.2.0] - 2026-05-13

### Added
- **Automated AI Product Registration**: Products are now automatically registered when scanned.
  - Integration with **Ollama (Qwen)** for local, zero-cost metadata extraction.
  - Option to use **Gemini 1.5 Flash** as an alternative AI provider.
  - Automatic web searching for product details based on barcodes.
  - **Textual Focus**: Decision to focus on highly accurate textual data (name, unit, manufacturer) for better governance.
- **Backend AI Pipeline**: New services for search and AI extraction.
- **Frontend Automation**: Removed manual registration dialog; the app now waits for AI-driven WebSocket broadcasts.

### Removed
- **Product Images**: Removed all image-related functionality (storage, UI, and AI extraction) to streamline the application and ensure data governance.

## [1.1.0] - 2026-05-11

### Added
- **Real-time Synchronization**: Full synchronization of prices and locations across the cluster.
- **Serializable Models**: `LocationModel` now supports JSON serialization for federated sharing.
- **Reactive UI**: Implemented `ValueListenableBuilder` in `ScanScreen` for instantaneous price updates from WebSocket data.
- **Protocol Sanitization**: Automatic HTTP-to-HTTPS upgrade in `ImageService` to prevent Mixed Content errors on web.
- **Federated Network**: Support for multiple regions via a central Hub.
- **Cluster Service**: Internal service for message relaying between regions.
- **Image Storage**: Integration with MinIO for product photo storage.
- **Upload Endpoint**: API for uploading product photos directly to the server.
- **Empty State**: New widget for empty screens (Cart, etc.).
- **Dismissible Cart Items**: Ability to remove items from the shopping cart by swiping.

### Changed
- Improved Cart UI with product images and currency formatting.
- Updated server to use `shelf_router` for better endpoint management.
- Standardized product display across screens.
- Enhanced `ScanScreen` to capture and sync user location when adding items to cart.

### Fixed
- **Mixed Content**: Resolved browser blocking of image requests by preserving `X-Forwarded-Proto` in Nginx and sanitizing URLs in the client.
- **Price Loading**: Fixed bug where existing prices were not loaded into the UI during product lookups.
- Storage of product images with proper absolute URLs.
- WebSocket broadcasting efficiency.
