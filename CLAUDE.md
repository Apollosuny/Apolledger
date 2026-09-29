# Apolledge

iOS ledger app: SwiftUI, SwiftData, Swift Testing. See `README.md` for architecture and status.

## Conventions

- Language: code, comments and commit messages in English; user-facing strings in Vietnamese.
- Use the design system, not literals: `AppColors`, `AppTypography`, `AppSpacing`, `AppRadius`, `AppMotion`, and the components in `DesignSystem/Components`.
- Files are added to the Xcode project automatically (synchronized folders). Create files on disk; do not edit `project.pbxproj` for that.
- The app target is main-actor by default (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`). The test target is not: mark test suites and test doubles `@MainActor`.
- Wiring goes through `AppContainer` (composition root). Do not create services inside views. Previews use `AppContainer.preview()`.
- Secrets (tokens) go in `KeychainStore`. Non-sensitive settings go in `Preferences` with a typed `PreferenceKey`.
- Register each new SwiftData `@Model` in `PersistenceController.models`.
- Do not delete the SwiftData store to recover from a load failure: it may hold the user's only copy of their records.

## Auth and networking rules

- Login and refresh endpoints are `requiresAuth: false` and must use a client with no token provider, so a refresh can never re-enter the token provider.
- `AuthService.refresh` must throw `APIError.unauthorized` only when the refresh token itself is rejected. Connectivity or server errors must not end the session.
- `AuthTokenManager` is the single owner of the persisted session. Do not read or write `SessionStore` directly from other code.

## Testing

- Never run a full test suite. Always pass `-only-testing:ApolledgeTests/<Suite>` for the suites that cover the change.
- The unit test target requires an iOS 26.5 simulator. Use:

  ```sh
  xcodebuild test -project Apolledge.xcodeproj -scheme Apolledge \
    -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' \
    -only-testing:ApolledgeTests/<Suite>
  ```

- Shared doubles (`StubTransport`, `StubAuthService`, `AuthSession.fixture`) are in `ApolledgeTests/Support/`. Reuse them before writing new ones.
- Default arguments that construct `@MainActor` types do not compile in the test target. Take an optional parameter and create the value inside the function.

## Git

- The repo-local identity in `.git/config` (`apollo`) is the intended author. Do not override it with the global identity.
- The GitHub account for this repo is `Apollosuny`. The global default account may be a different one, so check `gh auth status` before pushing or opening a PR.
- No `Co-Authored-By` lines and no AI attribution in commits or PR descriptions.
