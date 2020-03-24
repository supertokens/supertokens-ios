Pod::Spec.new do |spec|

  spec.name         = "SuperTokensSession"
  spec.version      = "1.0.1"
  spec.summary      = "SuperTokens session management implementation for iOS apps"
  spec.description  = "SuperTokens session management implementation for iOS apps."

  spec.homepage     = "https://supertokens.github.io/supertokens-ios"

  spec.license      = "Apache 2.0"

  spec.author       = { "SuperTokens" => "team@supertokens.io" }

  spec.platform     = :ios, "11.0"

  spec.source       = { :git => "https://github.com/supertokens/supertokens-ios.git", :tag => "v#{spec.version}" }

  spec.source_files  = "session/*.{h,m}", "session/*.swift", "session/utils/*.swift"
  spec.exclude_files = "testHelpers/" , "*/*.plist", "hooks/", ".travis.yml", "frontendDriverInterfaceSupported.json", "setup-pre-commit.sh"
  spec.swift_version = "4.0"

end
