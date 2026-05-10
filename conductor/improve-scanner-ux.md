# Plan: Improve Scanner UX - Auto-close on Detection

## Objective
Automatically close the camera scanner screen once a barcode is successfully detected, returning the user to the `ScanScreen` to provide immediate feedback.

## Key Files & Context
- `client/lib/screens/scan_screen.dart`: Contains the `_openScanner` method which pushes the `BarcodeScannerWidget`.

## Implementation Steps
1. **Modify `_openScanner`**: Update the `onDetect` callback in `client/lib/screens/scan_screen.dart` to call `Navigator.pop(context)` before processing the barcode with `_lookupProduct(barcode)`.
2. **Verification**: 
    - Perform static analysis with `analyze_files`.
    - Deploy to staging using `docker-compose up -d --build`.

## Verification & Testing
- Test the scanner functionality in the web environment (or mobile if applicable) to ensure the camera screen closes upon successful detection.
- Verify that the detected product information is correctly displayed on the `ScanScreen` after the pop.
