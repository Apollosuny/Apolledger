# Apolledge

A personal ledger app for iOS, built with SwiftUI and SwiftData. UI copy is in Vietnamese.

## Status

All main screens run against the real backend (`apolledge-be`). The backend is the source of truth; SwiftData is not used for ledger data and can become an offline cache later.

| Area | State |
| --- | --- |
| Design system, Splash, Login, Register | Done |
| Auth session (Keychain, token refresh, sign-out) | Done, uses `RemoteAuthService` |
| Sổ, transaction detail, entry sheet | Done |
| Ngân sách, Báo cáo, Định kỳ | Done |
| Forgot password, wallet creation, receipts, tags, editing a standing order | Not built |

## Requirements

- Xcode 26.5
- The app targets iOS 18.6 and later.
- The unit test target currently inherits the project-level deployment target of iOS 26.5, so tests need an iOS 26.5 simulator (for example iPhone Air). An iOS 18.6 simulator can run the app but not the tests.

## Getting started

1. Open `Apolledge.xcodeproj`.
2. Select the `Apolledge` scheme and run.

The Debug build talks to a local backend. Start it from `../apolledge-be`:

```sh
cp src/main/resources/application-local.properties.example src/main/resources/application-local.properties  # first run: fill in the secrets
docker compose up -d postgres
SPRING_PROFILES_ACTIVE=local mvn spring-boot:run
```

Previews and tests use `MockLedgerService` and stubs, so they need no backend.

## Architecture

```
Apolledge/
├── App/            Entry point, composition root (AppContainer), AppEnvironment, AppSession, RootView
├── DesignSystem/   Tokens (colors, typography, spacing, radius, motion) and reusable components
├── Features/       One folder per screen or flow: Splash, Auth, Main, Ledger, Entry, Budget, Reports, Recurring
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
| Debug | `http://localhost:8080/api/v1` |
| Release | `https://api.apolledge.app/api/v1` |

The Release domain is still a placeholder. `localhost` only works on the simulator; a physical device needs the Mac's LAN address.

The API contract:

- JSON in camelCase, ISO-8601 dates with 0, 3 or 6 fractional digits.
- `POST auth/local` and `POST auth/local/register` return `{ accessToken, refreshToken, user: { id, username, ... } }`. A 409 on register means the username is taken.
- `POST auth/refresh` with `{ refreshToken }` returns `{ accessToken }`. A 400, 401 or 403 means the refresh token was rejected.
- `POST auth/logout` revokes every token of the user, on all devices.
- Error bodies look like `{ "code": "...", "message": "..." }`. Server messages are never shown to the user.
- Ledger endpoints are listed in `RemoteLedgerService`. Account icons are Material Symbols names, mapped to SF Symbols in `LedgerIcon`.

`RemoteAuthServiceTests` and `RemoteLedgerServiceTests` pin this contract. If the backend differs, change the code and those tests together.

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

1. Choose the production domain and deploy the backend.
2. Build the missing flows: forgot password (needs a backend endpoint), wallet creation, editing a standing order.
3. Add tests for the keychain migration (sessions saved before refresh tokens existed) and for `AuthTokenManager` when the session changes mid-refresh.
