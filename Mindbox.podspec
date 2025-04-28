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

  # вот эта строка подключит ваш KMP-фреймворк
  spec.vendored_frameworks = 'abmixer.framework'
  spec.preserve_paths = 'abmixer.framework'
  spec.xcconfig = { 
    'FRAMEWORK_SEARCH_PATHS' => '$(PODS_ROOT)/Mindbox',
    'OTHER_LDFLAGS' => '-framework abmixer'
  }

  spec.pod_target_xcconfig = {
    'FRAMEWORK_SEARCH_PATHS' => '$(PODS_ROOT)/Mindbox',
    'OTHER_LDFLAGS' => '-framework abmixer'
  }

  spec.subspec 'AbMixer' do |ss|
    ss.source_files = 'KMP/CustomerAbMixer/abmixer/build/cocoapods/framework/AbMixer.framework/**/*.{h,m}'
  end
end
