#
# Be sure to run `pod lib lint SuperTokensSession.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'SuperTokensSession'
  s.version          = "1.2.0"
  s.summary          = 'iOS SuperTokens SDK.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
SuperTokens SDK for iOS written in Swift. This SDK takes care of managing a session on the frontend side.
                       DESC

  s.homepage         = 'https://github.com/supertokens/supertokens-ios'
  s.license          = { :type => 'Apache 2.0', :file => 'LICENSE.md' }
  s.author           = { 'rishabhpoddar' => 'rishabh@supertokens.io' }
  s.source           = { :git => 'https://github.com/supertokens/supertokens-ios.git', :tag => "v#{s.version.to_s}" }

  s.ios.deployment_target = '8.0'

  s.source_files = 'SuperTokensSession/Classes/**/*'
  
  s.swift_versions = "4.0"

  # s.resource_bundles = {
  #   'SuperTokensSession' => ['SuperTokensSession/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
