# Plan: Onboarding LGPD Flow and Startup Null Check Fix

This plan aims to implement a professional onboarding flow for LGPD compliance and fix the "Null check operator" error occurring during application startup.

## Objective
- Implement a comprehensive `OnboardingScreen` for first-time users.
- Ensure LGPD compliance with explicit consent for Privacy, Location, and AI Processing.
- Fix the startup "Null check operator" error by delaying service initialization and hardening null-sensitive code.

## Key Files & Context
- `client/lib/main.dart`: App entry point and screen routing.
- `client/lib/screens/onboarding_screen.dart`: (New) Onboarding and consent screen.
- `client/lib/providers/consent_provider.dart`: Management of user consents.
- `client/lib/services/sync_service.dart`: Global synchronization service.
- `client/lib/services/location_service.dart`: Geolocation logic.
- `client/lib/screens/compare_screen.dart`: Map-based comparison screen.
- `client/lib/screens/establishments_screen.dart`: Establishment management screen.

## Implementation Steps

### 1. Hardening Services and Models
- [ ] **LocationService**: Add defensive checks and ensure it never throws null check errors even if permissions are in a weird state.
- [ ] **SyncService**: Ensure it doesn't initialize or listen to streams if consent isn't granted or if the connection is still being established.
- [ ] **Models**: Ensure `fromJson` and `toJson` are robust against missing fields.

### 2. Implementation of OnboardingScreen
- [ ] Create `client/lib/screens/onboarding_screen.dart`.
- [ ] Design a professional layout with:
  - Welcome message and logo.
  - Feature highlights.
  - Interactive Terms and Privacy section with checkboxes.
  - "Start" button enabled only after agreement.
- [ ] Integrate with `PrivacyPolicyScreen`.

### 3. Update App Entry Point (main.dart)
- [ ] Modify `ShoppingComparatorApp` to listen to `consentProvider`.
- [ ] Use a `Consumer` or `watch` to determine whether to show `OnboardingScreen` or `HomeScreen`.
- [ ] Remove the `showDialog` logic from `main.dart` as it's now handled by the onboarding screen.

### 4. Hardening UI Screens (Map Handling)
- [ ] **CompareScreen**: 
  - Ensure `_currentCenter` always has a default value.
  - Use safe access for `filteredPrices` markers.
  - Add loading state handling for map tiles.
- [ ] **EstablishmentsScreen**:
  - Make location-dependent logic safer.
  - Avoid unsafe null assertions on `_selectedPosition`.

### 5. SyncService Lifecycle Management
- [ ] Ensure `SyncService` is only initialized when `HomeScreen` is active.
- [ ] Add a "connectivity check" before sending initial `sync_request`.

## Verification & Testing
- [ ] **Fresh Start**: Clear browser cache/local storage and verify the onboarding flow appears.
- [ ] **Consent Flow**: Verify that accepting terms leads to `HomeScreen`.
- [ ] **Error Check**: Monitor console for "Null check operator" during startup.
- [ ] **Map Test**: Verify that the map loads correctly on both screens after consent.
- [ ] **Offline Behavior**: Verify that the app still works (offline mode) if the WebSocket connection is slow.
