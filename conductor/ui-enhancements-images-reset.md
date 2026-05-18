# Implementation Plan - UI Enhancements: Product Images & Scan Reset

This plan covers adding a reset button to the ScanScreen and updating both Scan and Cart screens to display product images when available.

## 1. ScanScreen Enhancements
- **Reset Button**:
    - Add a `_resetScan` method to `_ScanScreenState` that:
        - Clears `_barcodeController`, `_priceController`, and resets `_qtyController` to '1'.
        - Sets `_currentProduct` to `null`.
        - Sets `_isSearchingCluster` to `false`.
    - Add an `IconButton` to the `AppBar.actions` that calls `_resetScan`. Use `Icons.refresh` or `Icons.clear_all`.
- **Product Image**:
    - Update the `ListTile` in the product details section.
    - Replace `leading: const CircleAvatar(child: Icon(Icons.shopping_bag))` with:
        - `CircleAvatar` using `backgroundImage: NetworkImage(ImageService.sanitizeUrl(_currentProduct!.photoUrl!))` if `photoUrl` is not null.
        - Fallback to `Icons.shopping_bag` icon if `photoUrl` is null.

## 2. CartScreen Enhancements
- **Product Avatar**:
    - Update the `ListTile` inside the `ListView.builder`.
    - Replace `leading: const Icon(Icons.shopping_bag)` with a `CircleAvatar`.
    - If `product?.photoUrl` is not null:
        - Use `backgroundImage: NetworkImage(ImageService.sanitizeUrl(product!.photoUrl!))`.
    - Otherwise, use `child: const Icon(Icons.shopping_bag)`.

## 3. Verification Plan
- **ScanScreen**:
    - Scan a product, then press the reset button. Verify all fields are cleared and the app returns to the "Empty State".
    - Scan a product with a photo (e.g., via Open Food Facts integration) and verify the photo appears in the card.
- **CartScreen**:
    - Add products to the cart.
    - Verify that products with photos show their avatars in the cart list, while others show the default bag icon.

## Key Files
- `client/lib/screens/scan_screen.dart`
- `client/lib/screens/cart_screen.dart`
- `client/lib/services/image_service.dart` (ensure imported)
