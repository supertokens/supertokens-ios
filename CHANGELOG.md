# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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