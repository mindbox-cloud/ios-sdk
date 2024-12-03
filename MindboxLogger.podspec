Pod::Spec.new do |spec|
  spec.name         = "MindboxLogger"
  spec.version      = "2.11.2"
  spec.summary      = "SDK for utilities to work with Mindbox"
  spec.description  = "-"
  spec.homepage     = "https://github.com/mindbox-cloud/ios-sdk"
  spec.license      = { :type => "CC BY-NC-ND 4.0", :file => "LICENSE.md" }
  spec.author       = { "Mindbox" => "ios-sdk@mindbox.ru" }
  spec.platform     = :ios, "12.0"
  spec.source       = { :git => "https://github.com/mindbox-cloud/ios-sdk.git", :tag => "#{spec.version}" }
  spec.source_files  = "MindboxLogger/**/*.{swift}", "SDKVersionProvider/**/*.{swift}"
  spec.exclude_files = "Classes/Exclude"
  spec.resource_bundles = { 
   'MindboxLogger' => ["MindboxLogger/**/*.xcdatamodeld", 'MindboxLogger/**/*.xcprivacy']
  } 
  spec.swift_version = "5"

end
