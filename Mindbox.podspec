Pod::Spec.new do |spec|
  spec.name         = "Mindbox"
  spec.version      = "2.13.1"
  spec.summary      = "SDK for integration with Mindbox"
  spec.description  = "This library allows you to integrate data transfer to Mindbox Marketing Cloud"
  spec.homepage     = "https://github.com/mindbox-cloud/ios-sdk"
  spec.license      = { :type => "CC BY-NC-ND 4.0", :file => "LICENSE.md" }
  spec.author       = { "Mindbox" => "ios-sdk@mindbox.ru" }
  spec.platform     = :ios, "12.0"
  spec.source       = { :git => "https://github.com/mindbox-cloud/ios-sdk.git", :tag => spec.version }
  spec.source_files  = "Mindbox/**/*.{swift}", "SDKVersionProvider/**/*.{swift}"
  spec.exclude_files = "Classes/Exclude"
  spec.resource_bundles = { 
    'Mindbox' => ['Mindbox/**/*.xcassets', 'Mindbox/**/*.xcdatamodeld', 'Mindbox/**/*.xcprivacy']
  }
  spec.swift_version = "5"
  spec.dependency 'MindboxLogger', '2.13.1'
  
  # Добавляем AbMixer как vendored_framework
  spec.vendored_frameworks = 'Mindbox/AbMixer/AbMixer.xcframework'
  spec.preserve_paths = 'Mindbox/AbMixer/AbMixer.xcframework'
  spec.xcconfig = { 
    'FRAMEWORK_SEARCH_PATHS' => '$(PODS_ROOT)/Mindbox/Mindbox/AbMixer',
    'OTHER_LDFLAGS' => '-framework AbMixer'
  }
end
