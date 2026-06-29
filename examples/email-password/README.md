# Email Password Example

This example shows email/password login with the SuperTokens iOS SDK.

It contains:

- `backend`: an Express backend using `supertokens-node`, EmailPassword, and Session.
- `ios`: a fresh UIKit app using the local `SuperTokensIOS` pod.

The backend connects to SuperTokens Core at `https://try.supertokens.com`.

## Demo Flow

1. Enter an email and password in the iOS app.
2. Tap **Sign up** to create a user or **Sign in** for an existing user.
3. The backend creates a SuperTokens session.
4. After login, the app shows local SDK session data and protected backend session data.

## Run The Backend

```bash
cd examples/email-password/backend
npm install
npm run dev
```

The backend listens on `http://localhost:3001` by default.

The backend logs each request as:

```text
GET /session -> 200 (12ms)
```

Useful environment variables:

```bash
PORT=3001
API_DOMAIN=http://localhost:3001
WEBSITE_DOMAIN=http://localhost:3001
```

## Run The iOS App

```bash
cd examples/email-password/ios
pod install
open EmailPassword.xcworkspace
```

Run the `EmailPassword` scheme on an iOS simulator.

The simulator connects to the backend via `http://127.0.0.1:3001`. Keep the backend running while using the app.

## What The App Demonstrates

- Email/password sign up and sign in.
- Session creation through the SuperTokens iOS SDK interceptor.
- Reading local session state with:
  - `SuperTokens.doesSessionExist()`
  - `SuperTokens.getUserId()`
  - `SuperTokens.getAccessTokenPayloadSecurely()`
  - `SuperTokens.getAccessToken()`
- Debugging where session tokens are stored. The app probes the expected Keychain service/accounts and shows whether each token item exists without printing token values.
- Testing automatic session refresh/retry. The **Test refresh retry** button calls a backend route that returns `401` once, causing the SDK to refresh the session and retry the original request.
- Calling a protected backend API.
- Updating the access token payload from the backend.
- Signing out with `SuperTokens.signOut`.

## Backend Endpoints

- `POST /auth/signup`: SuperTokens EmailPassword API that creates a user and session.
- `POST /auth/signin`: SuperTokens EmailPassword API that signs in and creates a session.
- `GET /session`: protected endpoint returning session details.
- `POST /session/custom-claim`: protected endpoint that updates the access token payload.
- `POST /debug/refresh-once/reset`: protected endpoint that resets the refresh retry demo state for the current session.
- `GET /debug/refresh-once`: protected endpoint that returns `401` on the first call for the current session and `200` on the retried call.
- `GET /public/config`: basic example configuration.

When **Test refresh retry** succeeds, backend logs should include this sequence:

```text
POST /debug/refresh-once/reset -> 200 (...ms)
GET /debug/refresh-once -> 401 (...ms)
POST /auth/session/refresh -> 200 (...ms)
GET /debug/refresh-once -> 200 (...ms)
```

The app also shows a local SDK debug log with refresh hooks/events, including `REFRESH_SESSION` when the SDK refreshes successfully.
