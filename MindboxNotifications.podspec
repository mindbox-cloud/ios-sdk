Pod::Spec.new do |spec|
  spec.name         = "MindboxNotifications"
  spec.version      = "2.14.0-rc"
  spec.summary      = "SDK for integration notifications with Mindbox"
  spec.description  = "This library allows you to integrate notifications and transfer them to Mindbox Marketing Cloud"
  spec.homepage     = "https://github.com/mindbox-cloud/ios-sdk"
  spec.license      = { :type => "CC BY-NC-ND 4.0", :file => "LICENSE.md" }
  spec.author       = { "Mindbox" => "ios-sdk@mindbox.ru" }
  spec.platform     = :ios, "12.0"
  spec.source       = { :git => "https://github.com/mindbox-cloud/ios-sdk.git", :tag => spec.version }
  spec.source_files  = "MindboxNotifications/**/*.{swift}", "SDKVersionProvider/**/*.{swift}"
  spec.exclude_files = "Classes/Exclude"
  spec.resource_bundles = { 
    'MindboxNotifications' => ['MindboxNotifications/**/*.xcprivacy'] 
  }
  spec.swift_version = "5"
  spec.dependency 'MindboxLogger', '2.14.0-rc'

end
