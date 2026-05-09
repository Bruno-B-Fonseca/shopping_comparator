# Changelog

## [1.1.0] - 2026-05-09

### Added
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

### Fixed
- Storage of product images with proper absolute URLs.
- WebSocket broadcasting efficiency.
