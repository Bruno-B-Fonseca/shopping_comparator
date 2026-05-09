# Plan: Federated Network Implementation (Phase 1)

## Objective
Implement the Hub Registry & Relay to enable a federated network for the Shopping Comparator.

## Key Files & Context
- Project Root: `/home/bruno-fonseca/develop/projects/shopping_comparator`
- New Hub Directory: `hub/`
- Existing Server Directory: `server/`

## Implementation Steps

### Phase 1: Hub Implementation
1. Create `hub/pubspec.yaml` with necessary dependencies (`shelf`, `shelf_web_socket`, `uuid`).
2. Create `hub/bin/hub.dart`:
   - Initialize `shelf` handler for WebSocket.
   - Maintain a `topics` map (`Map<String, Set<WebSocketChannel>>`).
   - Maintain a `servers` list (`List<ServerInfo>`).
   - Implement `handleMessage` logic for `register`, `subscribe`, `publish`, `unregister`.
   - Implement `_broadcast` logic to relay messages to topic subscribers.
3. Create `hub/Dockerfile` and update `docker-compose.yml` to include the `hub` service.

### Phase 2: Server Local Modification
1. Update `server/pubspec.yaml` to include `web_socket_channel` and `uuid`.
2. Implement `ClusterService` in `server/lib/cluster_service.dart`:
   - Connect to `HUB_URL` via WebSocket.
   - Send `register` message on startup.
   - Handle incoming `relay` messages from Hub and broadcast them locally.
   - Implement local publish to Hub on user message reception.
3. Integrate `ClusterService` into `server/bin/server.dart`.
4. Update `server` to handle environment variables (`HUB_URL`, `REGION`, `SERVER_ID`).

## Verification & Testing
- Start `hub` service.
- Start multiple `server` instances with different regions.
- Verify registry: `server` registers, `hub` responds with `peers_update`.
- Verify relay: publish a message on `serverA` -> verify it is received by `serverB` via `hub`.
- Verify local broadcast: verify `serverA` relays message to local clients.

## Migration & Rollback
- If federation fails, `server` remains functional in standalone mode if `HUB_URL` is not provided.
- Rollback: simply revert changes to `server/bin/server.dart` and remove `hub/` directory.
