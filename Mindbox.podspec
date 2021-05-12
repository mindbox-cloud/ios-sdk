

Pod::Spec.new do |spec|

  spec.name         = "Mindbox"
  
  spec.version      = "1.0.2"
  
  spec.summary      = "Library for integration with Mindbox"

  spec.description  = "This library allows you to integrate data transfer to Mindbox Marketing Cloud"

  spec.homepage     = "https://github.com/mindbox-moscow/ios-sdk"

  spec.license      = { :type => "CC BY-NC-ND 4.0", :file => "LICENSE" }

  spec.author       = { "Mindbox" => "ios-sdk@mindbox.ru" }

  spec.platform     = :ios, "10.0"

  spec.source       = { :git => "https://github.com/mindbox-moscow/ios-sdk.git", :tag => spec.version }

  spec.source_files  = "Mindbox/**/*.{swift}"

  spec.exclude_files = "Classes/Exclude"


  # ――― Resources ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  A list of resources included with the Pod. These are copied into the
  #  target bundle with a build phase script. Anything else will be cleaned.
  #  You can preserve files from being cleaned, please don't preserve
  #  non-essential files like tests, examples and documentation.
  #

  spec.resources = ["Mindbox/**/*.xcdatamodeld"]


  # ――― Project Linking ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  Link your library with frameworks, or libraries. Libraries do not include
  #  the lib prefix of their name.
  #

  # ――― Project Settings ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  If your library depends on compiler flags you can set them in the xcconfig hash
  #  where they will only apply to your library. If you depend on other Podspecs
  #  you can include multiple dependencies to ensure it works.

  spec.swift_version = "5"
    
end
