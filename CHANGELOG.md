# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.5.3] - 2026-08-07

### Fixes

- `signOut` now resolves its completion handler on a terminal session-expired response instead of leaving callers waiting indefinitely.
- Valid front tokens can replace malformed values already in storage without crashing.
- Malformed incoming front tokens are rejected before any session values are written, and corrupt stored front tokens no longer crash session reads.
- Stale responses, retries, and refresh cohorts can no longer mutate or reuse replacement-session credentials, including same-user session replacements.
- Documented that `getRefreshToken()` exposes a long-lived, ungated credential and clarified the best-effort cleanup contract for failed `installSession` calls.

## [0.5.2] - 2026-08-07

### Added

- `SuperTokens.installSession(accessToken:refreshToken:frontToken:antiCSRFToken:)` — install a session from tokens obtained out of band (e.g. a WKWebView/Hub flow) through the SDK's validated write path.
- `SuperTokens.clearSessionLocally()` — clear local session state (including in-memory caches) without a network sign-out.
- `SuperTokens.getRefreshToken()`, `SuperTokens.getFrontToken()`, `SuperTokens.getAntiCSRF()` — read-only getters for the current session's stored tokens, symmetric with `getAccessToken()`. No network.

### Fixes

- `installSession` now validates `frontToken` before writing anything, rejecting malformed values (including the `"remove"` sentinel) instead of storing them and crashing later.
- `installSession` now rejects empty `accessToken`/`refreshToken`/`frontToken` instead of silently deleting the corresponding stored token.
- `installSession` now clears any anti-CSRF token left over from a previous session when installing a new session without one.
- `installSession` and `clearSessionLocally` now invalidate older in-flight responses, preventing stale response headers from overwriting or recreating an out-of-band session.
- Session response updates are ordered and rollback clears the front-token session marker before access and refresh tokens.


## [0.5.1] - 2026-08-06

### Fixes

- Fixed a session teardown race that could trigger an unnecessary refresh request and 401 during sign-out.

## [0.5.0] - 2026-06-29

### Changes

- Session tokens are now stored in Keychain instead of UserDefaults. Existing UserDefaults values migrate on first read and are removed after a successful Keychain write.
- Added `keychainAccessGroup` to `SuperTokens.initialize(...)` for sharing sessions across app targets with Keychain Sharing entitlements.
- For app extensions or multiple targets, enable Keychain Sharing for each target and pass the same `keychainAccessGroup`. `userDefaultsSuiteName` no longer shares active session tokens after migration.
- Keychain write failures fail closed: the SDK treats the local session as missing and clears partial session state.

## [0.4.3] - 2025-03-26

### Changes

- Added new FDI version support: 4.1

## [0.4.2] - 2024-10-29

### Changes

- Added new FDI version support: 3.1, 4.0

## [0.4.1] - 2024-07-12

### Changes

- Removed redundant calls to `removeToken`

## [0.4.0] - 2024-06-05

### Changes

- Fixed the session refresh loop in all the request interceptors that occurred when an API returned a 401 response despite a valid session. Interceptors now attempt to refresh the session a maximum of ten times before throwing an error. The retry limit is configurable via the `maxRetryAttemptsForSessionRefresh` option.

## [0.3.2] - 2024-05-28

- Readds FDI 2.0 and 3.0 support

## [0.3.1] - 2024-05-28

- Adds FDI 2.0 and 3.0 support

## [0.3.0] - 2024-05-07

### Breaking change

The `shouldDoInterceptionBasedOnUrl` function now returns true:

- If `sessionTokenBackendDomain` is a valid subdomain of the URL's domain. This aligns with the behavior of browsers when sending cookies to subdomains.
- Even if the ports of the URL you are querying are different compared to the `apiDomain`'s port ot the `sessionTokenBackendDomain` port (as long as the hostname is the same, or a subdomain of the `sessionTokenBackendDomain`): https://github.com/supertokens/supertokens-website/issues/217

## [0.2.7] - 2024-03-14

- New FDI version support: 1.19
- Update test server to work with new node server versions

## [0.2.6] - 2023-09-13

- Adds 1.18 to the list of supported FDI versions

## [0.2.5] - 2023-09-13

- Fixes an issue where session tokens from network responses would not be consumed if they were not in lowercase (Credit: [mattanimation](https://github.com/mattanimation))
- Adds Swift Package Manager support (Credit: [mattanimation](https://github.com/mattanimation))

## [0.2.4] - 2023-07-31

- Updates supported FDI versions to include

## [0.2.3] - 2023-07-10

### Fixes

- Fixed an issue where the Authorization header was getting removed unnecessarily

## [0.2.2] - 2023-06-06

- Refactors session logic to delete access token and refresh token if the front token is removed. This helps with proxies that strip headers with empty values which would result in the access token and refresh token to persist after signout

## [0.2.1] - 2023-05-03

- Adds tests based on changes in the session management logic in the backend SDKs and SuperTokens core

## [0.2.0] - 2023-01-30

### Breaking Changes

- The SDK now only supports FDI version 1.16
- The backend SDK should be updated to a version supporting the header-based sessions!
  - supertokens-node: >= 13.0.0
  - supertokens-python: >= 0.12.0
  - supertokens-golang: >= 0.10.0
- Properties passed when calling SuperTokens.init have been renamed:
  - `cookieDomain` -> `sessionTokenBackendDomain`

### Added

- The SDK now supports managing sessions via headers (using `Authorization` bearer tokens) instead of cookies
- A new property has been added when calling SuperTokens.init: `tokenTransferMethod`. This can be used to configure whether the SDK should use cookies or headers for session management (`header` by default). Refer to https://supertokens.com/docs/thirdpartyemailpassword/common-customizations/sessions/token-transfer-method for more information

## [0.1.2] - 2022-11-29

- Fixes an issue with documentation generation

## [0.1.1] - 2022-11-29

- Added documentation generation

## [0.1.0] - 2022-10-17

- Adds support for using SuperTokens across app extensions (using App Groups)

## [0.0.1] - 2022-10-12

- Inial Release
