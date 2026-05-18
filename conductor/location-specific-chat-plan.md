# Plan: Location-Specific Chat Rooms and Establishment Editing

This plan outlines the steps to refactor the general chat system into location-specific rooms and enhance the establishment management UI.

## Objective
- Refactor `ChatScreen` to support filtering by `locationId`.
- Update `ChatMessage` model to store `locationId`.
- Enhance `EstablishmentsScreen` with editing capabilities and direct access to establishment chats.

## Proposed Changes

### 1. Models
#### `client/lib/models/chat_message.dart`
- Add `locationId` (String?) field with `@HiveField(6)`.
- Update constructor and JSON serialization.

### 2. Services
#### `client/lib/services/sync_service.dart`
- No major logic changes needed, but ensure it handles the new field correctly (automatic if using generated JSON methods).

### 3. UI - Establishments Screen (`client/lib/screens/establishments_screen.dart`)
- Refactor the list item to include:
  - **Edit Button**: Opens a dialog to change the name and radius (recalculating the geofence).
  - **Chat Button**: Navigates to `ChatScreen` with the establishment's ID and name.
- Improve UI layout of the list items to accommodate more actions.

### 4. UI - Chat Screen (`client/lib/screens/chat_screen.dart`)
- Update constructor: `ChatScreen({super.key, required this.locationId, required this.locationName})`.
- Filter local history in `initState`: `_chatHistory.addAll(StorageService.messages.values.where((m) => m.locationId == widget.locationId))`.
- Update `_sendMessage`: Include `locationId: widget.locationId` in the `ChatMessage` constructor.
- Update `_addMessage`: Only add to `setState` if `msg.locationId == widget.locationId`.
- Update `AppBar`: Show "Chat: ${widget.locationName}".

## Implementation Plan

1. **Step 1: Model Update**
   - Modify `ChatMessage`.
   - Run `dart run build_runner build --delete-conflicting-outputs`.

2. **Step 2: Chat Screen Refactoring**
   - Update `ChatScreen` logic to handle location-based filtering.

3. **Step 3: Establishments Screen Enhancement**
   - Add edit functionality.
   - Add chat navigation.

4. **Step 4: Verification**
   - Test registration, editing, and separated chat rooms.

## Verification
- Register two different locations (e.g., "Market A" and "Market B").
- Send messages in "Market A" chat.
- Verify "Market B" chat is empty.
- Edit "Market A" name and verify it updates in the list.
