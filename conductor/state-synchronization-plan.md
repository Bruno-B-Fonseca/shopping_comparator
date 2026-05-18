# State Synchronization Plan

## Objective
Ensure that newly connected clients (anonymous or not) receive existing state data (Locations, Products, Prices) that were registered while they were offline.

## Background
Currently, data is only synchronized via real-time broadcasts. If a client connects after a location or product has been registered, it won't see that data until another broadcast happens or it manually searches for it.

## Proposed Solution
Implement a "Sync Request" flow:
1.  **Client-side**: Upon successful connection to the WebSocket, the client sends a `sync_request` message.
2.  **Server-side**: When the server receives a `sync_request`, it broadcasts this request to other connected clients (peers).
3.  **Peer-side (Proactive Sync)**: Connected clients that receive a `sync_request` can respond with their local data (Locations, etc.) using a `sync_response`. 
    - *Note*: Since Locations are critical and few, peers will broadcast their registered locations.
4.  **Client-side (Receipt)**: The requesting client receives the `sync_response` and populates its local Hive storage.

## Implementation Steps

### 1. Protocol Update (`server/lib/protocol.dart` and `hub/lib/protocol.dart`)
- Define `msgSyncRequest` = 'sync_request'.
- Define `msgSyncResponse` = 'sync_response'.

### 2. Client-side: Initiate Sync (`client/lib/services/websocket_service.dart`)
- After receiving `connection_established`, send a message with type `sync_request`.

### 3. Client-side: Handle Sync Requests and Responses (`client/lib/services/sync_service.dart`)
- Listen for `sync_request`: If received, the client (if it has data) can choose to broadcast its known locations.
- Listen for `sync_response` (or simply reuse `location_registration` messages sent as response): Ensure Hive is updated.

### 4. Server-side: Broadcast Sync (`server/bin/server.dart`)
- Ensure `sync_request` is broadcast to all local clients.
- (Optional) Relay `sync_request` to the Hub so other servers in the cluster can also respond.

## Verification
- Open Session A (Operator): Register a location.
- Open Session B (Anonymous): Verify the location list is initially empty (expected current behavior).
- Apply changes.
- Open Session B (Anonymous): Verify that upon connection, the location from Session A appears.
