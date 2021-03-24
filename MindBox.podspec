

Pod::Spec.new do |spec|

  spec.name         = "MindBox"
  
  spec.version      = "0.2.0"
  
  spec.summary      = "MindBox"

  spec.description  = "It is a nice sdk to make analytics"

  spec.homepage     = "https://github.com/mindbox-moscow/ios-sdk"

  spec.license      = { :type => "MindBox", :file => "LICENSE" }

  spec.author       = { "MindBox" => "ios-sdk@mindbox.ru" }

  spec.platform     = :ios, "10.0"

  spec.source       = { :git => "https://github.com/mindbox-moscow/ios-sdk.git", :tag => "#{spec.version}" }

  spec.source_files  = "MindBox/**/*.{swift}"

  spec.exclude_files = "Classes/Exclude"


  # ――― Resources ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  A list of resources included with the Pod. These are copied into the
  #  target bundle with a build phase script. Anything else will be cleaned.
  #  You can preserve files from being cleaned, please don't preserve
  #  non-essential files like tests, examples and documentation.
  #

  spec.resources = ["MindBox/**/*.xcdatamodeld"]


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
