# Apolledge

A personal ledger app for iOS, built with SwiftUI and SwiftData. UI copy is in Vietnamese.

## Status

Early development. The foundation is in place; product features are not.

| Area | State |
| --- | --- |
| Design system (tokens, base components) | Done |
| Splash, Login | Done |
| Auth session (Keychain, token refresh) | Done, runs against `MockAuthService` |
| Network, storage layers | Done, covered by unit tests |
| Backend integration | Not wired: `RemoteAuthService` exists but `AppContainer.live()` still uses the mock |
| Ledger tab ("Sổ") | Placeholder (shows the username and a sign-out button) |
| Domain models (transactions, categories, …) | Not started: `PersistenceController.models` is empty |

## Requirements

- Xcode 26.5
- The app targets iOS 18.6 and later.
- The unit test target currently inherits the project-level deployment target of iOS 26.5, so tests need an iOS 26.5 simulator (for example iPhone Air). An iOS 18.6 simulator can run the app but not the tests.

## Getting started

1. Open `Apolledge.xcodeproj`.
2. Select the `Apolledge` scheme and run.

Until the backend is available, sign in with any username and a password of at least 6 characters (`MockAuthService`).

## Architecture

```
Apolledge/
├── App/            Entry point, composition root (AppContainer), AppEnvironment, AppSession, RootView
├── DesignSystem/   Tokens (colors, typography, spacing, radius, motion) and reusable components
├── Features/       One folder per screen or flow: Splash, Auth/Login, Ledger
├── Models/         Plain data types shared across layers
└── Services/
    ├── Auth/       AuthService (mock and remote), AuthTokenManager, SessionStore
    ├── Network/    APIClient, Endpoint, APIError
    └── Storage/    KeychainStore, Preferences, PersistenceController (SwiftData)
```

### How the pieces fit

- **`AppContainer`** is the composition root. It builds the API client, token manager, session, preferences and SwiftData container once and injects them into the view tree. `AppContainer.preview()` provides an in-memory variant for SwiftUI previews.
- **`AppSession`** owns the authentication lifecycle (`launching`, `signedOut`, `signedIn`) and decides which top-level screen `RootView` shows.
- **`AuthTokenManager`** is the single owner of the persisted session. It refreshes tokens on demand for `APIClient`, and concurrent 401s share one refresh. If the refresh token is rejected, the session is cleared and `AppSession` signs the user out. A refresh that fails for connectivity reasons keeps the session.
- **`APIClient`** attaches the Bearer token to endpoints with `requiresAuth == true`. On a 401 it refreshes once and retries once. Unauthenticated endpoints (login, refresh) must go through a client with no token provider, otherwise a refresh could recurse.
- **Concurrency:** the app target uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so app types are main-actor isolated unless stated otherwise. The test target does not, so test suites are marked `@MainActor`.

### Environments

`AppEnvironment.current` picks the API base URL per build configuration:

| Build | Base URL |
| --- | --- |
| Debug | `https://api-dev.apolledge.app/v1` |
| Release | `https://api.apolledge.app/v1` |

These URLs are placeholders in code; confirm them against the real backend before switching off the mock.

The API contract currently assumed by the client:

- JSON in camelCase, ISO-8601 dates.
- `POST auth/login` with `{ username, password }` returns `{ userID, username, accessToken, refreshToken }`.
- `POST auth/refresh` with `{ refreshToken }` returns `{ accessToken, refreshToken }`. A 400, 401 or 403 means the refresh token was rejected.
- Error bodies look like `{ "code": "...", "message": "..." }`, both fields optional.

`RemoteAuthServiceTests` pins this contract. If the backend differs, change the code and those tests together.

## Testing

Tests use Swift Testing. Shared doubles live in `ApolledgeTests/Support/`.

Run only the suites that cover what you changed, not the whole target:

```sh
xcodebuild test \
  -project Apolledge.xcodeproj \
  -scheme Apolledge \
  -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' \
  -only-testing:ApolledgeTests/AppSessionTests \
  -only-testing:ApolledgeTests/RemoteAuthServiceTests
```

| Suite | Covers |
| --- | --- |
| `AppSessionTests` | Restore, sign-in, sign-out, session expiry |
| `RemoteAuthServiceTests` | Login and refresh request shape, error mapping |
| `URLSessionAPIClientTests` | Bearer token, refresh-and-retry, error mapping |
| `PreferencesTests`, `KeychainStoreTests`, `PersistenceControllerTests` | Storage layer |

## Design references

`Apolledge Design System.html` and `Apolledge UI Kit.html` are kept locally and are git-ignored because of their size. Ask the maintainer for a copy.

## Roadmap

1. Ledger tab: define the transaction and category models, register them in `PersistenceController.models`, and build the list screen.
2. Connect the real backend: switch `AppContainer.live()` to `RemoteAuthService` and confirm the API contract.
3. Add tests for the keychain migration (sessions saved before refresh tokens existed) and for `AuthTokenManager` when the session changes mid-refresh.
