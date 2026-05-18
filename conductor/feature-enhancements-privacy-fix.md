# Implementation Plan - Feature Enhancements & Privacy Fixes

This plan covers the implementation of several improvements requested by the user, including map fixes, search navigation, privacy enforcement, offline map cache, and Open Food Facts integration.

## 1. CompareScreen Improvements
- **Map Centering**: 
    - Add a `MapController` to `_CompareScreenState`.
    - Use `_mapController.move(_currentCenter, 15.0)` in `_initLocation` to programmatically center the map.
- **Product Filter (Combobox)**:
    - Add `_selectedBarcode` state variable.
    - Implement a `DropdownButton` in the `AppBar` or a floating overlay.
    - Options will include:
        - "Todos do Carrinho" (Default)
        - List of products currently in `StorageService.cart`.
    - Update `MarkerLayer` to filter markers:
        - If `_selectedBarcode` is set, show only prices for that barcode.
        - If null, show prices for all barcodes present in the cart.

## 2. ProductSearchScreen Navigation
- **Navigate to Scan**:
    - Add an `IconButton(icon: Icon(Icons.add_shopping_cart))` to `_ProductResultTile`.
    - When pressed, navigate to `ScanScreen(initialBarcode: item.product.barcode)`.
- **Update ScanScreen**:
    - Modify `ScanScreen` constructor to accept an optional `initialBarcode`.
    - In `initState`, if `initialBarcode` is provided, call `_lookupProduct(initialBarcode)`.

## 3. Privacy Enforcement in SyncService
- **Fix Sync Leak**:
    - Modify `SyncService._handleSyncRequest` to filter out private data.
    - Only send `location_registration` if `locationId` does NOT start with `private_`.
    - Only send `price_update` if `locationId` does NOT start with `private_`.
- **Double Check**: Ensure `ChatMessage` sync also respects location privacy if applicable.

## 4. Offline Map Tile Cache
- **Custom TileProvider**:
    - Create `HiveTileProvider` in `client/lib/services/map_tile_service.dart`.
    - It will check a new Hive box `map_tiles` for the requested tile (key: `z_x_y`).
    - If found, return the tile data.
    - If not found, fetch from OSM, store in Hive, and return.
- **Cache Management**: Add an option in `OperatorSettingsScreen` to "Limpar cache de mapas".

## 5. Open Food Facts (OFF) Integration
- **Server-Side (Metadata Service)**:
    - Update `server/lib/product_metadata_service.dart`.
    - Add a step to query `https://world.openfoodfacts.org/api/v2/product/[barcode].json`.
    - Extract `product_name`, `brands`, `quantity`, `image_url`, and `nutriments`.
    - Merge this data with the AI/Web search results.
- **Product Model Update**:
    - Add `photoUrl` and `nutritionalInfo` fields to `Product` model.
    - Run `build_runner` to update adapters and JSON logic.
- **UI Updates**:
    - Show product photo (avatar) in `_ProductResultTile` and `ScanScreen`.
    - Show nutritional summary in `_ProductResultTile` or a details modal.

## 6. Verification Plan
- **Map**: Verify "Center my location" button moves the map to the user's coordinates.
- **Search**: Verify clicking the cart icon on a search result leads to `ScanScreen` with the correct product loaded.
- **Privacy**: Use two browser sessions. Add a price at an "Unknown Location" in session A. Verify it DOES NOT appear in session B's map or search.
- **Offline Cache**: Turn off internet and verify map tiles already visited remain visible.
- **OFF**: Scan a known product (e.g., Coca-Cola) and verify it fetches the correct name, photo, and info without manual typing.

## Key Files
- `client/lib/models/product.dart`
- `client/lib/screens/compare_screen.dart`
- `client/lib/screens/product_search_screen.dart`
- `client/lib/screens/scan_screen.dart`
- `client/lib/services/sync_service.dart`
- `client/lib/services/storage_service.dart`
- `server/lib/product_metadata_service.dart`
