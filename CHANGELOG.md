# Changelog

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
