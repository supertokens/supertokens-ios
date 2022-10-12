# Contributing

We're so excited you're interested in helping with SuperTokens! We are happy to help you get started, even if you don't have any previous open-source experience :blush:

## New to Open Source?
1. Take a look at [How to Contribute to an Open Source Project on GitHub](https://egghead.io/courses/how-to-contribute-to-an-open-source-project-on-github)
2. Go thorugh the [SuperTokens Code of Conduct](https://github.com/supertokens/supertokens-ios/blob/master/CODE_OF_CONDUCT.md)

## Where to ask Questions?
1. Check our [Github Issues](https://github.com/supertokens/supertokens-ios/issues) to see if someone has already answered your question.  
2. Join our community on [Discord](https://supertokens.io/discord) and feel free to ask us your questions  


## Development Setup  

### Prerequisites
- OS: macOS
- IDE: XCode
- NodeJS
- Java

### Project Setup
1. Please setup `supertokens-core` by following [this guide](https://github.com/supertokens/supertokens-core/blob/master/CONTRIBUTING.md#development-setup). If you are not contributing to `supertokens-core`, please skip  steps 1 & 4 under "Project Setup" section.
2. Clone the forked repository in the parent directory of the previously setup `supertokens-root`.  That is, `supertokens-ios` and `supertokens-root` should exist side by side within the same parent directory.
3. `cd supertokens-ios`
4. Add git pre-commit hooks
   ```
   ./setup-pre-commit.sh
   ```

## Modifying Code  
1. Open the `supertokens-ios` project in XCode by double clicking on `./Example/SuperTokensSession.xcworkspace`.
2. You can start modifying the code.

## Testing
1. Navigate to the `supertokens-root` repository
2. Start the testing environment
   ```
   ./startTestingEnv --wait
   ```
3. In a new terminal, navigate to the `supertokens-ios` repository.
4. Start a node server required for testing
   ```
   cd ./testHelpers/server/
   npm i -d
   npm i git+https://github.com:supertokens/supertokens-node.git
   cd ../..
   ./testHelpers/startServer ../supertokens-root
   ```
5. Open a new terminal in `supertokens-ios` and run all tests
   ```
   xcodebuild test -enableCodeCoverage YES -workspace Example/SuperTokensSession.xcworkspace -scheme SuperTokensSession-Example -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 12 Pro' ONLY_ACTIVE_ARCH=NO | xcpretty
   ```
   Alternatively, you can also run all tests via XCode. The tests are present in the `Example` project.
6. If all tests pass the output should be:

   <img src="https://github.com/supertokens/supertokens-logo/blob/master/images/supertokens-ios-tests-passing.png" alt="IOS tests passing" width="500px">


## Pull Request
1. Before submitting a pull request make sure all tests have passed
2. Reference the relevant issue or pull request and give a clear description of changes/features added when submitting a pull request

## SuperTokens Community
SuperTokens is made possible by a passionate team and a strong community of developers. If you have any questions or would like to get more involved in the SuperTokens community you can check out:
  - [Github Issues](https://github.com/supertokens/supertokens-ios/issues)
  - [Discord](https://supertokens.io/discord)
  - [Twitter](https://twitter.com/supertokensio)
  - or [email us](mailto:team@supertokens.io)
  
Additional resources you might find useful:
  - [SuperTokens Docs](https://supertokens.io/docs/community/getting-started/installation)
  - [Blog Posts](https://supertokens.io/blog/)
