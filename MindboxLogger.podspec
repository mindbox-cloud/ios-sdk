Pod::Spec.new do |spec|
  spec.name         = "MindboxLogger"
  spec.version      = "0.0.1"
  spec.summary      = "SDK for integration notifications with Mindbox"
  spec.description  = "This library allows you to integrate notifications and transfer them to Mindbox Marketing Cloud"
  spec.homepage     = "https://github.com/mindbox-cloud/ios-sdk"
  spec.license      = { :type => "CC BY-NC-ND 4.0", :file => "LICENSE" }
  spec.author       = { "Mindbox" => "ios-sdk@mindbox.ru" }
  spec.platform     = :ios, "10.0"
  spec.source       = { :git => "https://github.com/mindbox-cloud/ios-sdk.git", :tag => spec.version }
  spec.source_files  = "MindboxLogger/**/*.{swift}", "SDKVersionProvider/**/*.{swift}"
  spec.exclude_files = "Classes/Exclude"
  spec.resources = ["MindboxLogger/**/*.xcdatamodeld"]
  spec.swift_version = "5"

end
