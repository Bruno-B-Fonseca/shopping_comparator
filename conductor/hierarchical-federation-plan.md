# Hierarchical Federation Plan (Hub-to-Hub)

## Objective
Enable a "Regional Hub" to connect to an "Upstream (National) Hub", creating a federated hierarchy where local price updates can reach a national level.

## Architecture
1.  **National Hub (L3)**: Central authority with a fixed URL. Stores regional hub secrets in `secrets.json`.
2.  **Regional Hub (L2)**: Connects to local servers (L1) AND connects to the National Hub as a client.
3.  **Local Servers (L1)**: Markets/Establishments connecting to their closest Regional Hub.

## Proposed Solution

### 1. Hub Upstream Client (`hub/bin/hub.dart`)
- Add support for environment variables: `UPSTREAM_HUB_URL`, `FEDERATION_ID`, `FEDERATION_PASSWORD`.
- Implement a client connection loop within the Hub process that uses HMAC authentication to register with the `UPSTREAM_HUB_URL`.

### 2. Message Bridging
- **Upward**: When a Regional Hub receives a `msgPublish` from a local server, it relays it to its connected local clients AND forwards it to the National Hub.
- **Downward**: When a Regional Hub receives a `msgRelay` from the National Hub, it broadcasts it to its local region.

### 3. Protocol Extension (`protocol.dart`)
- Ensure message signatures are preserved across tiers so the original source can be verified if needed.

## Implementation Steps

### Phase 1: Hub Client Logic
- Integrate `ClusterService`-like logic into `hub/bin/hub.dart` to handle upstream connection.
- Add reconnection logic for the upstream link.

### Phase 2: Bridging Logic
- Update `_handleMessage` in the Hub to detect if it should forward messages to the upstream hub.
- Prevent infinite loops (circular relaying) by adding a `hops` counter or `via` field in the protocol.

### Phase 3: Docker-Agnostic Configuration
- Ensure all parameters are passed via environment variables.

## Verification
- Run two Hubs (A and B).
- Connect Hub B (Regional) to Hub A (National).
- Connect a Server to Hub B.
- Register a location on the Server.
- Verify that a Client connected to Hub A (or another Regional Hub C) receives the location update.
