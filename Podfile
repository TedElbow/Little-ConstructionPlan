platform :ios, '16.0'

# Main app target = first target in project (excluding notifications). Podfile stays valid after renaming.
require 'xcodeproj'
xcodeproj_path = Dir.glob('*.xcodeproj').first
raise "No .xcodeproj found in #{Dir.pwd}. Run 'pod install' from the project root." unless xcodeproj_path
project = Xcodeproj::Project.open(xcodeproj_path)
app_targets = project.targets.reject { |t| t.name == 'notifications' }
raise "No app target found (only 'notifications'?). In Xcode TARGETS: put main app first, notifications second." if app_targets.empty?
MAIN_TARGET = app_targets.first.name

# Fix for Xcode 16 "Multiple commands produce" error
install! 'cocoapods', 
  :disable_input_output_paths => true,
  :deterministic_uuids => false

# Pods for both main app and notifications extension
abstract_target 'PodsShared' do
  use_frameworks!
  pod 'AppsFlyerFramework'
  pod 'Firebase/Core'
  pod 'Firebase/Messaging'
  pod 'Firebase/RemoteConfig'

  target MAIN_TARGET do
  end

  target 'notifications' do
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      # Set minimum iOS deployment target to 16.0 (required for SwiftUI + Charts)
      if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < 16.0
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
      end
      
      # Fix for Xcode 16: disable parallel building to avoid duplicate output errors
      config.build_settings['DISABLE_MANUAL_TARGET_ORDER_BUILD_WARNING'] = 'YES'
      
      # Fix sandbox error: disable user script sandboxing (more reliable than static linkage)
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
    end
  end
  
  # Disable parallel builds for Pods project to fix "Multiple commands produce" error
  installer.pods_project.build_configurations.each do |config|
    config.build_settings['DISABLE_MANUAL_TARGET_ORDER_BUILD_WARNING'] = 'YES'
  end
end