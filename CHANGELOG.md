# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.2] - 2023-06-06

- Refactors session logic to delete access token and refresh token if the front token is removed. This helps with proxies that strip headers with empty values which would result in the access token and refresh token to persist after signout

## [0.2.1] - 2023-05-03

- Adds tests based on changes in the session management logic in the backend SDKs and SuperTokens core

## [0.2.0] - 2023-01-30

### Breaking Changes

- The SDK now only supports FDI version 1.16
- The backend SDK should be updated to a version supporting the header-based sessions!
    -   supertokens-node: >= 13.0.0
    -   supertokens-python: >= 0.12.0
    -   supertokens-golang: >= 0.10.0
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