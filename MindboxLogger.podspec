Pod::Spec.new do |spec|
  spec.name         = "MindboxLogger"
  spec.version      = "0.0.6"
  spec.summary      = "SDK for utilities to work with Mindbox"
  spec.description  = "-"
  spec.homepage     = "https://github.com/mindbox-cloud/ios-sdk"
  spec.license      = { :type => "CC BY-NC-ND 4.0", :file => "LICENSE" }
  spec.author       = { "Mindbox" => "ios-sdk@mindbox.ru" }
  spec.platform     = :ios, "10.0"
  spec.source       = { :git => "https://github.com/mindbox-cloud/ios-sdk.git", :tag => "#{spec.version}-logger" }
  spec.source_files  = "MindboxLogger/**/*.{swift}", "SDKVersionProvider/**/*.{swift}"
  spec.exclude_files = "Classes/Exclude"
  spec.resource_bundles = { 
   'MindboxLogger' => ["MindboxLogger/**/*.xcdatamodeld"] 
  } 
  spec.swift_version = "5"

end
