# Promotional Feed Implementation Plan (Formerly Chat)

## Objective
Transform the location-specific chat into a unidirectional "Promotional Feed" where operators can post official flyers (promotions) and users can only view them.

## Proposed Solution
1.  **Model Update (`client/lib/models/chat_message.dart`)**:
    *   Add fields: `isPromotion` (bool), `title` (String?), `description` (String?), `bannerUrl` (String?), `price` (double?).
    *   Update JSON serialization and Hive adapters.
2.  **UI Updates - Posting (`client/lib/screens/chat_screen.dart`)**:
    *   Restrict message input to **Operators** only.
    *   Add a "Post Promotion" button for operators that opens a form (Title, Description, Price, Image/Banner).
    *   Ensure messages are signed via `WebSocketService.sendAuthenticatedMessage`.
3.  **UI Updates - Rendering (`client/lib/screens/chat_screen.dart`)**:
    *   Render promotions as high-quality cards with banner images.
    *   Include an "Official" badge for signed messages.
    *   Remove text input field for common users.
4.  **Backend Verification (`server/bin/server.dart`)**:
    *   The server already validates HMAC signatures and sets `isOfficial: true`. Ensure this flows to the client.

## Implementation Steps

### 1. Update Model
- Modify `ChatMessage` class and run `build_runner`.

### 2. Refactor ChatScreen
- Add `PromotionForm` widget (internal or separate).
- Update the message list to use a `PromotionCard` for `isPromotion` messages.
- Add logic to check `authProvider.isOperator` for visibility of posting controls.

### 3. Synchronization
- No changes needed to `SyncService` as it already handles `chat_message` broadcasting.

## Verification
- Open App as Common User: Open Chat. Verify no text input is available.
- Open App as Operator: Open Chat. Use "Post Promotion" to upload a banner and title.
- Verify that Common User sees the promotion as a rich card instantly.
