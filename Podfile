# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

target 'PokoroWebApp' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for PokoroWebApp
  pod 'ESPProvision', '3.0.1'
  pod 'MBProgressHUD'

  target 'PokoroWebAppTests' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'PokoroWebAppUITests' do
    # Pods for testing
  end

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ENABLE_BITCODE'] = 'YES'
      config.build_settings['ARCHS'] = 'arm64'
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
    end
  end
end