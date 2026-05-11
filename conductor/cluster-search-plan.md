# Plan: Cluster-wide Product Search

This plan enables real-time collaborative product discovery across the federated network.

## 1. Shared Protocol Update
- Add `msgProductRequest = 'product_request'` to `hub/lib/protocol.dart` and `server/lib/protocol.dart`.
- This message will contain the `barcode` being searched.

## 2. Hub Validation Update
- Update `_validateMessage` in `hub/bin/hub.dart` to support `product_request`.
- Ensure it validates the presence of the `barcode` or `payload` containing the barcode.

## 3. Client: SyncService (The Provider)
- Update `SyncService` to listen for `product_request` messages.
- If the requested barcode exists in the local Hive `products` box, broadcast a `product_registration` message containing the full product data.

## 4. Client: ScanScreen (The Requester)
- Modify `_lookupProduct`:
    - If not found in local Hive:
        - Set `_isSearching = true`.
        - Broadcast `product_request` with the barcode.
        - Start a timer (e.g., 2-3 seconds).
        - Listen for changes in the Hive box for that barcode.
        - If found during search, stop searching and display the product.
        - If timer expires without result, show the "Register Product" dialog.
- Add a "Searching cluster..." loading state to the UI.

## Verification
- Register a product on Device A.
- Ensure Device B (without that product) can find it by scanning/typing the barcode.
- Verify that the "Searching..." state appears and resolves correctly.
