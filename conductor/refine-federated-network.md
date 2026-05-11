# Plan: Refine Federated Network v1.5

This plan aims to improve the stability, security, and testability of the federated network of the Shopping Comparator project.

## 1. Shared Protocol & Constants
**Objective**: Prevent divergences between Hub and Server.
- Create `hub/lib/protocol.dart` and `server/lib/protocol.dart` with shared constants.
- Replace literal strings with these constants in Hub and Server.

## 2. Heartbeat (Keep-alive)
**Objective**: Detect and remove inactive servers.
- **Hub**:
    - Add `lastHeartbeat` to `ServerInfo`.
    - Periodically send `ping` to active channels.
    - Remove servers that haven't responded with `pong` within 15 seconds.
    - Notify other servers in the same region about the removal via `peers_update`.
- **Server**:
    - Respond to `ping` with `pong`.

## 3. Hub Message Validation
**Objective**: Protect Hub against malformed or malicious messages.
- Implement `validateMessage` in Hub.
- Validate required fields based on message type.
- Validate topic format using regex: `^(region/[a-z0-9-]+|barcode/[0-9]+)$`.
- Limit payload size to < 2 KB.
- Send error messages for invalid requests.

## 4. Refine `peers_update`
**Objective**: Reduce unnecessary traffic.
- Send `peers_update` only during `register` and `unregister`/`timeout` events.
- Ensure only servers in the same region receive the update.

## 5. Deduplication with `messageId`
**Objective**: Prevent duplicate entries in the Flutter app.
- **Server**: Generate a UUID `messageId` for each published message if not present.
- **Hub**: Pass through `messageId`.
- **Client**: Update Hive models to include `messageId` and check for duplicates before storing.

## 6. Automated Hub Tests
**Objective**: Ensure zero regressions.
- Add `test` dependency to Hub.
- Create `hub/test/hub_test.dart` covering registration, relay, heartbeat, and validation.

## 7. Configuration & Documentation
**Objective**: Clarify Hub URL requirements.
- Update `.env.example` with comments about fixed Hub URL.
- Update `README.md` with "Network Architecture" section.
- Ensure `docker-compose.yml` reflects these changes.

## Verification
- Run Hub tests: `cd hub && dart test`.
- Manually test server disconnection and peer list updates.
- Verify deduplication by sending multiple identical price updates.
