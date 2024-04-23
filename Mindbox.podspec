Pod::Spec.new do |spec|
  spec.name         = "Mindbox"
  spec.version      = "0.1.2"
  spec.summary      = "SDK for integration with Mindbox"
  spec.description  = "This library allows you to integrate data transfer to Mindbox Marketing Cloud"
  spec.homepage     = "https://github.com/mindbox-cloud/ios-sdk"
  spec.license      = { :type => "CC BY-NC-ND 4.0", :file => "LICENSE" }
  spec.author       = { "Mindbox" => "ios-sdk@mindbox.ru" }
  spec.platform     = :ios, "10.0"
  spec.source       = { :git => "https://github.com/mindbox-cloud/ios-sdk.git", :tag => spec.version }
  spec.source_files  = "Mindbox/**/*.{swift}", "SDKVersionProvider/**/*.{swift}"
  spec.exclude_files = "Classes/Exclude"
  spec.resource_bundles = { 
    'Mindbox' => ['Mindbox/**/*.xcassets', 'Mindbox/**/*.xcdatamodeld', 'Mindbox/**/*.xcprivacy']
  } 
  spec.swift_version = "5"
  spec.dependency 'MindboxLogger', '0.0.7'

end
