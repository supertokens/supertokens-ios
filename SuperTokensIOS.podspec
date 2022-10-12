#
# Be sure to run `pod lib lint SuperTokensSession.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'SuperTokensIOS'
  s.version          = "0.0.1"
  s.summary          = 'SuperTokens SDK for using login and session management functionality in iOS apps'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
SuperTokens SDK for iOS written in Swift. This SDK manages sessions for you and allows you to build login functionality easily.
                       DESC

  s.homepage         = 'https://github.com/supertokens/supertokens-ios'
  s.license          = { :type => 'Apache 2.0', :file => 'LICENSE.md' }
  s.author           = { 'rishabhpoddar' => 'rishabh@supertokens.io' }
  s.source           = { :git => 'https://github.com/supertokens/supertokens-ios.git', :tag => "v#{s.version}" }

  s.ios.deployment_target = '13.0'

  s.source_files = 'SuperTokensIOS/Classes/**/*'
  
  s.swift_versions = "5.0"
end
