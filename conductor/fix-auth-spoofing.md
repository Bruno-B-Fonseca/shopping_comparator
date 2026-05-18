# Implementation Plan - Fix Critical Security Bug: Auth Spoofing

This plan addresses a severe security flaw where unauthorized clients could spoof "official" status for messages and operations.

## 1. Protocol Update
- **File**: `server/lib/protocol.dart` (and `hub/lib/protocol.dart` if they share it, but they seem to have separate copies or at least separate paths).
- **Changes**: Add `msgAuthVerifyRequest = 'auth_verify_request'` and `msgAuthVerifyResponse = 'auth_verify_response'`.

## 2. Server-side Fixes
- **File**: `server/bin/server.dart`
- **Sanitization**: 
    - Implement a global sanitization step for ALL incoming messages.
    - If `msg['payload']` contains `isOfficial`, it MUST be forced to `false` immediately.
- **Validation**:
    - For message types that *can* be official (`chat_message`, `promotion`, `product_registration`, `location_registration`, `price_update`):
        - Check for `signature`, `timestamp`, and `messageId`.
        - If valid signature is present (HMAC-SHA256 with `LOCATION_PASSWORD`):
            - Set `msg['isOfficial'] = true`.
            - ALSO set `msg['payload']['isOfficial'] = true` (to ensure clients receive the sanitized, verified flag).
        - If signature is missing or invalid:
            - Set `msg['isOfficial'] = false`.
            - Ensure `msg['payload']['isOfficial'] = false`.
            - If it was a `promotion` or other strictly official type, REJECT the message.
- **Verification Endpoint**:
    - Handle `auth_verify_request`:
        - Client sends a signed message (nonce or just a signed timestamp).
        - Server validates signature.
        - Returns `auth_verify_response` with `success: true/false`.

## 3. Client Service Improvements
- **File**: `client/lib/services/websocket_service.dart`
- **New Method**: `Future<bool> verifyCredentials(String id, String password)`
    - Generates a signature for a random `nonce`.
    - Sends `auth_verify_request`.
    - Returns a `Future` that completes when the response is received.

## 4. Client Provider Improvements
- **File**: `client/lib/providers/auth_provider.dart`
- **New Method**: `Future<bool> verifyAndSetCredentials(String id, String password)`
    - Calls `websocketService.verifyCredentials`.
    - If success, saves to `SharedPreferences` and updates state.
    - If fail, does NOT update state and returns `false`.

## 5. UI Updates
- **File**: `client/lib/screens/operator_settings_screen.dart`
- **Change**: `_saveCredentials` now calls `verifyAndSetCredentials`.
- **Feedback**: Show error Snackbar if verification fails.

## Verification Plan
1. **Malicious Client Test**: Attempt to send a `chat_message` with `payload: { "isOfficial": true }` manually via DevTools without a signature. Verify the server overwrites it to `false` before broadcasting.
2. **Incorrect Password Test**: Enter a wrong password in Settings. Verify that saving fails and operator features are NOT enabled.
3. **Correct Password Test**: Enter the correct password (matching `LOCATION_PASSWORD` env var). Verify it works and "Verified" icons appear.
4. **Official Registration Test**: Register a product. Verify other clients see it as "Official" only if signed correctly.
